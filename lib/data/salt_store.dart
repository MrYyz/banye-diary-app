import 'dart:io';
import 'dart:typed_data';

import '../core/kdf.dart';

/// 库文件旁边的盐 sidecar。
///
/// 盐不能放进加密库的 meta 表：读 meta 需要密钥，派生密钥又需要盐，
/// 鸡生蛋。所以每个库文件配一个 `<dbFileName>.salt`，16 字节二进制，
/// 先写 `.tmp` 再 rename 覆盖，避免半截文件。
///
/// 类以「库文件名」为参数，app.db 与将来的 vault.db 复用同一套实现。
class SaltStore {
  SaltStore({required this.dir});

  /// 应用私有目录（测试注入临时目录）。
  final Directory dir;

  File _saltFile(String dbFileName) => File('${dir.path}/$dbFileName.salt');
  File _tmpFile(String dbFileName) => File('${dir.path}/$dbFileName.salt.tmp');

  /// 有盐读盐，无盐生成 16 字节随机盐并原子落盘。
  Future<Uint8List> loadOrCreate(String dbFileName) async {
    final existing = await read(dbFileName);
    if (existing != null) return existing;

    final salt = randomSalt(16);
    await write(dbFileName, salt);
    return salt;
  }

  /// 显式写入指定盐。改密码换密钥时用：
  /// 新密码要用新盐派生，旧盐必须被覆盖掉。
  Future<void> write(String dbFileName, Uint8List salt) async {
    if (salt.length != 16) {
      throw ArgumentError('盐必须是 16 字节');
    }
    if (!await dir.exists()) await dir.create(recursive: true);

    final tmp = _tmpFile(dbFileName);
    await tmp.writeAsBytes(salt, flush: true);

    final target = _saltFile(dbFileName);
    if (await target.exists()) await target.delete();
    await tmp.rename(target.path);
  }

  /// 只读，不生成。文件不存在或长度异常时返回 null。
  Future<Uint8List?> read(String dbFileName) async {
    final file = _saltFile(dbFileName);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length != 16) return null;
    return Uint8List.fromList(bytes);
  }

  /// 删盐（配合删库），否则下次会拿旧盐去配新库。
  Future<void> reset(String dbFileName) async {
    for (final file in [_saltFile(dbFileName), _tmpFile(dbFileName)]) {
      if (await file.exists()) await file.delete();
    }
  }
}
