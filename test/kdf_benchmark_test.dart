import 'dart:typed_data';

import 'package:envx/core/kdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M1 实测：Argon2id 三档耗时与派生正确性', () {
    final salt = Uint8List.fromList(
      List<int>.generate(16, (i) => (i * 7 + 3) % 256),
    );
    const pw = 'envx-bench-2026';

    // 同输入必须得到同输出，否则换机恢复就废了
    final a = deriveKey(password: pw, salt: salt, params: KdfParams.light);
    final b = deriveKey(password: pw, salt: salt, params: KdfParams.light);
    expect(constantTimeEquals(a.keyBytes, b.keyBytes), isTrue,
        reason: '相同密码与盐必须派生出相同密钥');

    // 换密码要换密钥
    final c =
        deriveKey(password: '${pw}x', salt: salt, params: KdfParams.light);
    expect(constantTimeEquals(a.keyBytes, c.keyBytes), isFalse,
        reason: '密码变化必须改变密钥');

    // 换盐也要换密钥
    final d =
        deriveKey(password: pw, salt: randomSalt(), params: KdfParams.light);
    expect(constantTimeEquals(a.keyBytes, d.keyBytes), isFalse,
        reason: '盐变化必须改变密钥');

    // 正式档位计时：第一遍预热，第二遍取数
    for (final p in [KdfParams.plan, KdfParams.medium, KdfParams.light]) {
      deriveKey(password: pw, salt: salt, params: p);
      final r = deriveKey(password: pw, salt: salt, params: p);
      // ignore: avoid_print
      print(
        'KDF ${p.label} -> ${r.millis} ms '
        '(key ${r.keyBytes.length}B, tooSlow=${r.tooSlow})',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
