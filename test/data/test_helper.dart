import 'dart:io';
import 'dart:typed_data';

import 'package:envx/core/kdf.dart';
import 'package:envx/data/database.dart';
import 'package:envx/data/salt_store.dart';

/// 测试专用：每个用例独立临时目录，走「盐 sidecar + Argon2 派生 + 开库」全流程。
///
/// 测试里用 light 档位加速 KDF（方案档位的耗时已在 M1 实测），
/// 派生算法与盐的持久化流程与正式路径一致。
Future<EnvxDatabase> openTestDb(Directory dir, String password) async {
  final store = SaltStore(dir: dir);
  final salt = await store.loadOrCreate('app.db');
  final key = deriveKey(
    password: password,
    salt: salt,
    params: KdfParams.light,
  ).keyBytes;
  return openEnvxDatabase(dir: dir, key32: key);
}

/// 用指定密码在同一目录派生密钥（用于错 key / 重开库场景）。
Future<Uint8List> keyFor(Directory dir, String password) async {
  final store = SaltStore(dir: dir);
  final salt = await store.read('app.db');
  if (salt == null) throw StateError('salt 不存在');
  return deriveKey(
    password: password,
    salt: salt,
    params: KdfParams.light,
  ).keyBytes;
}

/// 字节子串扫描，避免只靠 UTF-8 解码漏判。
bool bytesContain(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}
