import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 一份整库备份。
///
/// 备份目录里就是 App 私有目录的完整快照：加密库、盐 sidecar、设备密钥、
/// 排版设置、photo_spots.json，外加 `photos/`（插图）。
///
/// 为什么连设备密钥一起备份：库是加密的，只备 db 不备 key，换台机器就再也
/// 打不开。代价是备份目录本身**等同明文**，所以 UI 上必须写明「含密钥，别外传」。
class BackupInfo {
  const BackupInfo({
    required this.name,
    required this.path,
    required this.bytes,
    required this.at,
  });

  /// 目录名，形如 `20261118-1730-45`。
  final String name;
  final String path;
  final int bytes;
  final DateTime at;

  String get sizeText {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  String get label {
    final b = StringBuffer()
      ..write('${at.year}-${_two(at.month)}-${_two(at.day)} ')
      ..write('${_two(at.hour)}:${_two(at.minute)}')
      ..write(' · $sizeText');
    return b.toString();
  }
}

String _two(int v) => v.toString().padLeft(2, '0');

class BackupStore {
  BackupStore({
    required this.supportDir,
    required this.photosDir,
    this.targetDir,
  });

  /// App 私有目录（app.db / *.salt / devicekey / settings.json 都在这）。
  final Directory supportDir;

  /// 插图目录（documents/photos）。
  final Directory photosDir;

  /// 备份落在哪。null 时自动挑：Android 优先 App 外部目录（可在文件管理器里
  /// 拷出来），拿不到就退到 documents。
  final Directory? targetDir;

  static const _skipSuffix = ['.tmp', '-journal', '-shm', '-wal'];

  Future<Directory> root() async {
    final base = targetDir ??
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}envx-backup');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 打一份新备份，返回它的信息。
  ///
  /// 只做文件复制：调用方应在没有写入的时候调用（本 App 的写都是用户操作触发，
  /// 备份入口是设置页的按钮，天然空闲）。sqlite 的空闲文件在没有写事务时是一致的。
  Future<BackupInfo> create({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final r = await root();
    final name = '${at.year}${_two(at.month)}${_two(at.day)}-'
        '${_two(at.hour)}${_two(at.minute)}${_two(at.second)}';
    final dest = Directory('${r.path}${Platform.pathSeparator}$name');
    if (await dest.exists()) await dest.delete(recursive: true);
    await dest.create(recursive: true);

    await _copyFiles(supportDir, dest);
    if (await photosDir.exists()) {
      await _copyFiles(photosDir, Directory('${dest.path}/photos'));
    }

    final files = await _allFiles(dest);
    var bytes = 0;
    for (final f in files) {
      bytes += await f.length();
    }
    await File('${dest.path}/manifest.json').writeAsString(
      jsonEncode({
        'app': 'envx',
        'createdAt': at.toIso8601String(),
        'bytes': bytes,
        'hasVault': await File('${supportDir.path}/vault.db').exists(),
      }),
      flush: true,
    );

    return BackupInfo(
      name: name,
      path: dest.path,
      bytes: bytes,
      at: at,
    );
  }

  Future<List<BackupInfo>> list() async {
    final r = await root();
    if (!await r.exists()) return const [];
    final out = <BackupInfo>[];
    for (final e in await r.list().toList()) {
      if (e is! Directory) continue;
      final files = await _allFiles(e);
      if (files.isEmpty) continue;
      var bytes = 0;
      for (final f in files) {
        bytes += await f.length();
      }
      final name = e.path.split(Platform.pathSeparator).last;
      out.add(BackupInfo(
        name: name,
        path: e.path,
        bytes: bytes,
        at: await e.stat().then((s) => s.modified),
      ));
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }

  /// 从备份还原到 App 私有目录。
  ///
  /// **调用方必须先关掉数据库**（drift 连接持有文件句柄，Windows 上 rename 会失败）。
  /// 现存的库会改名封存成 `*.before-restore-<时间戳>`，不删——恢复错了还能救回来。
  Future<void> restore(BackupInfo info, {DateTime? now}) async {
    final src = Directory(info.path);
    if (!await src.exists()) throw StateError('备份目录不存在');
    final stamp = _stamp(now ?? DateTime.now());

    // 1. 把当前库封存
    for (final f in supportDir.listSync(recursive: false)) {
      if (f is! File) continue;
      if (f.path.contains('.before-restore-')) continue;
      final name = f.path.split(Platform.pathSeparator).last;
      if (!name.endsWith('.db') &&
          !name.endsWith('.salt') &&
          !name.endsWith('.devicekey') &&
          name != 'settings.json' &&
          name != 'photo_spots.json') {
        continue;
      }
      await f.rename('${f.path}.before-restore-$stamp');
    }

    // 2. 备份拷回去（photos 单独走）
    for (final f in src.listSync(recursive: false)) {
      if (f is! File) continue;
      final name = f.path.split(Platform.pathSeparator).last;
      if (name == 'manifest.json') continue;
      await f.copy('${supportDir.path}${Platform.pathSeparator}$name');
    }
    final photos = Directory('${src.path}/photos');
    if (await photos.exists()) {
      if (!await photosDir.exists()) await photosDir.create(recursive: true);
      for (final f in photos.listSync(recursive: false)) {
        if (f is! File) continue;
        final name = f.path.split(Platform.pathSeparator).last;
        await f.copy('${photosDir.path}${Platform.pathSeparator}$name');
      }
    }
  }

  Future<void> delete(BackupInfo info) async {
    final d = Directory(info.path);
    if (await d.exists()) await d.delete(recursive: true);
  }

  Future<void> _copyFiles(Directory from, Directory to) async {
    if (!await to.exists()) await to.create(recursive: true);
    await for (final e in from.list(recursive: false)) {
      if (e is! File) continue;
      final name = e.path.split(Platform.pathSeparator).last;
      if (_skipSuffix.any(name.endsWith)) continue;
      await e.copy('${to.path}${Platform.pathSeparator}$name');
    }
  }

  Future<List<File>> _allFiles(Directory dir) async {
    final out = <File>[];
    await for (final e in dir.list(recursive: true)) {
      if (e is File) out.add(e);
    }
    return out;
  }

  String _stamp(DateTime t) =>
      '${t.year}${_two(t.month)}${_two(t.day)}-'
      '${_two(t.hour)}${_two(t.minute)}${_two(t.second)}';
}
