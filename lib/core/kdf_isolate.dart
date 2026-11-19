import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

import 'kdf.dart';

/// 丢给后台 isolate 的派生参数包。
///
/// web 上没有真正 isolate，`compute` 会退化成同步执行，行为仍然正确。
class KdfInput {
  const KdfInput({
    required this.password,
    required this.salt,
    required this.params,
  });

  final String password;
  final Uint8List salt;
  final KdfParams params;
}

/// isolate 入口，必须是顶层函数。
Uint8List kdfDerive(KdfInput input) => deriveKey(
      password: input.password,
      salt: input.salt,
      params: input.params,
    ).keyBytes;

/// 统一走 isolate，别在 UI 线程里同步跑 Argon2。
Future<Uint8List> deriveKeyInBackground({
  required String password,
  required Uint8List salt,
  KdfParams params = KdfParams.plan,
}) {
  return compute(
    kdfDerive,
    KdfInput(password: password, salt: salt, params: params),
  );
}
