import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:hashlib/hashlib.dart';

/// 密钥派生参数。三档都保留着，方便在真机上换档重测。
class KdfParams {
  const KdfParams({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
  });

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  /// 方案定稿档：Argon2id m=64MiB, t=3, p=4
  static const plan =
      KdfParams(memoryKiB: 65536, iterations: 3, parallelism: 4);

  /// 折中档：内存不减，轮数减半
  static const medium =
      KdfParams(memoryKiB: 65536, iterations: 2, parallelism: 2);

  /// 轻档：内存砍到 32MiB，留给低端机
  static const light =
      KdfParams(memoryKiB: 32768, iterations: 2, parallelism: 2);

  String get label => 'm=${memoryKiB}KiB t=$iterations p=$parallelism';

  @override
  String toString() => label;
}

/// 派生结果，连带把耗时也带回来——M1 要的就是这个数。
class KdfResult {
  const KdfResult(this.keyBytes, this.elapsed);

  final Uint8List keyBytes;
  final Duration elapsed;

  int get millis => elapsed.inMilliseconds;

  /// 界面要用的判断：超过 1.5 秒就该降档。
  bool get tooSlow => elapsed.inMilliseconds > 1500;
}

/// 用密码派生一把 32 字节的库密钥。
///
/// 注意：这里刻意不把结果缓存进任何持久化存储，密钥只活在调用方内存里。
KdfResult deriveKey({
  required String password,
  required Uint8List salt,
  KdfParams params = KdfParams.plan,
}) {
  final sw = Stopwatch()..start();
  final digest = Argon2(
    salt: salt,
    type: Argon2Type.argon2id,
    hashLength: 32,
    iterations: params.iterations,
    parallelism: params.parallelism,
    memorySizeKB: params.memoryKiB,
  ).convert(utf8.encode(password));
  sw.stop();
  return KdfResult(Uint8List.fromList(digest.bytes), sw.elapsed);
}

/// 16 字节随机盐。两个库各生成一次，之后跟库文件绑定存放。
Uint8List randomSalt([int length = 16]) {
  final r = Random.secure();
  return Uint8List.fromList(List<int>.generate(length, (_) => r.nextInt(256)));
}

/// 常量时间比较，避免密码校验被时序侧信道利用。
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
