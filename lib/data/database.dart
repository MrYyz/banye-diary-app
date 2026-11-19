import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

import 'repos.dart';
import 'schema.dart';

/// 密钥不对，或加密库打不开。异常文本里不带任何密钥信息。
class WrongKeyException implements Exception {
  WrongKeyException([this.message = '无法打开加密数据库']);

  final String message;

  @override
  String toString() => 'WrongKeyException: $message';
}

/// 已打开的应用数据库，对外只暴露三个仓库与关闭方法。
class EnvxDatabase {
  EnvxDatabase._(
    this._schema,
    this._raw,
    this.notebooks,
    this.notes,
    this.attachments,
  );

  final EnvxSchema _schema;
  final Database _raw;
  final NotebookRepo notebooks;
  final NoteRepo notes;
  final AttachmentRepo attachments;

  /// 关闭 drift 连接并释放底层 sqlite3 句柄。
  ///
  /// 底层连接由本类持有并负责关闭（drift 侧不连带关闭），
  /// 即使 drift 关闭过程抛异常，也会在 finally 里释放原生句柄，
  /// 避免 Windows 上文件句柄泄漏锁住临时库文件。
  Future<void> close() async {
    try {
      await _schema.close();
    } finally {
      _raw.close();
    }
  }
}

/// 就地更换加密库的密钥（sqlite3mc 的 `PRAGMA rekey`）。
///
/// 同一文件从 oldKey32 换成 newKey32，数据一行不动。调用方负责在成功后
/// 同步更新盐 sidecar，否则新密码派生不出新密钥。
///
/// 旧密钥不对时抛 [WrongKeyException]；rekey 本身失败抛 [SqliteException]。
/// 无论成败都会释放原生句柄，避免 Windows 文件锁。
Future<void> rekeyEnvxDatabase({
  required Directory dir,
  required Uint8List oldKey32,
  required Uint8List newKey32,
  String fileName = 'app.db',
}) async {
  final path = '${dir.path}/$fileName';
  if (!await File(path).exists()) throw WrongKeyException('库文件不存在');

  final raw = sqlite3.open(path);
  try {
    final oldHex = _hexOf(oldKey32);
    final newHex = _hexOf(newKey32);
    raw.execute("PRAGMA key = \"x'$oldHex'\";");
    // 探针：密钥不对时这里就会抛 file is not a database。
    raw.select('SELECT count(*) FROM sqlite_master');
    raw.execute("PRAGMA rekey = \"x'$newHex'\";");
    raw.select('SELECT count(*) FROM sqlite_master');
  } on SqliteException {
    throw WrongKeyException();
  } finally {
    raw.close();
  }
}

String _hexOf(Uint8List key32) =>
    key32.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// 打开（必要时创建）加密库。
///
/// - 原生库走 sqlite3mc（pubspec hooks 配置，不在此重复设置）。
/// - 密钥以 raw key 形式注入：`PRAGMA key = "x'<64位hex>'"`，不做二次 KDF。
/// - 开库即 `PRAGMA foreign_keys = ON`。
/// - `PRAGMA key` 本身不报错，密钥不对要到第一次读才抛
///   "file is not a database"，所以这里在 setup 阶段做一次探针查询，
///   失败映射成 [WrongKeyException]，避免错误密钥一路飘到 UI 才炸。
Future<EnvxDatabase> openEnvxDatabase({
  required Directory dir,
  required Uint8List key32,
  String fileName = 'app.db',
  int Function()? clock,
}) async {
  // 主区 app.db 与隐藏区 vault.db 是两个独立的 sqlite3 连接，
  // 各自持有自己的 Database 句柄，不存在共用 QueryExecutor 的竞态。
  // drift 那条「EnvxSchema 被创建多次」只是 debug 期提示，这里是误报。
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  if (!await dir.exists()) await dir.create(recursive: true);

  final path = '${dir.path}/$fileName';
  final raw = sqlite3.open(path);

  try {
    raw.execute("PRAGMA key = \"x'${_hexOf(key32)}'\";");
    raw.execute('PRAGMA foreign_keys = ON;');

    // 探针：错密钥在这里才会暴露。
    raw.select('SELECT count(*) FROM sqlite_master');
  } on SqliteException {
    raw.close();
    throw WrongKeyException();
  }

  final schema = EnvxSchema(
    NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
  );

  return EnvxDatabase._(
    schema,
    raw,
    NotebookRepoImpl(schema, clock: clock),
    NoteRepoImpl(schema, clock: clock),
    AttachmentRepoImpl(schema),
  );
}
