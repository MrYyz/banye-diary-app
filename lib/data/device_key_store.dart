import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// 免密码模式下的主库数据密钥。
///
/// 用户没设「访问密码」时库仍然要加密 —— 否则手机里的 db 文件被拷走就全裸。
/// 这时密钥用随机 32 字节，落在应用私有目录，由系统沙箱保护。用户后来在设置页
/// 设了访问密码，就用 `PRAGMA rekey` 就地换成密码派生的密钥，数据一行不动。
class DeviceKeyStore {
  DeviceKeyStore({required this.dir});

  /// 应用私有目录（测试注入临时目录）。
  final Directory dir;

  File get _file => File('${dir.path}/app.db.devicekey');
  File get _tmp => File('${_file.path}.tmp');

  /// 只读，不生成。不存在或长度异常返回 null。
  Future<Uint8List?> read() async {
    if (!await _file.exists()) return null;
    final bytes = await _file.readAsBytes();
    if (bytes.length != 32) return null;
    return Uint8List.fromList(bytes);
  }

  /// 有则读，无则生成 32 字节随机密钥并原子落盘。
  Future<Uint8List> loadOrCreate() async {
    final existing = await read();
    if (existing != null) return existing;
    final key = randomKey32();
    await write(key);
    return key;
  }

  /// 显式写入。设/取消访问密码后要同步这把密钥。
  Future<void> write(Uint8List key) async {
    if (key.length != 32) throw ArgumentError('设备密钥必须是 32 字节');
    if (!await dir.exists()) await dir.create(recursive: true);

    await _tmp.writeAsBytes(key, flush: true);
    if (await _file.exists()) await _file.delete();
    await _tmp.rename(_file.path);
  }

  /// 删掉设备密钥（已切到密码模式时调用，避免两把钥匙并存）。
  Future<void> reset() async {
    for (final f in [_file, _tmp]) {
      if (await f.exists()) await f.delete();
    }
  }
}

/// 32 字节随机密钥，直接当 sqlite3mc 的 raw key 用。
Uint8List randomKey32() {
  final rnd = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(32, (_) => rnd.nextInt(256)),
  );
}
