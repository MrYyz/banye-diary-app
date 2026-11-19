import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// M1 的加密验收：写入用密码加密、错密码必须打不开、磁盘上不能出现明文。
void main() {
  const secret = '这是只该我看得到的内容';
  const rightPw = 'correct-horse-battery';
  const wrongPw = 'wrong-password-2026';

  test('加密库三项验收', () {
    final dir = Directory.systemTemp.createTempSync('envx_enc_');
    final path = '${dir.path}/vault.db';

    // 1. 用正确密码建库并写入
    final writer = sqlite3.open(path);
    writer.execute("PRAGMA key = '$rightPw';");
    writer.execute('CREATE TABLE note (id INTEGER PRIMARY KEY, body TEXT)');
    writer.execute("INSERT INTO note (body) VALUES ('$secret')");
    writer.close();

    // 2. 磁盘上不能有明文，否则加密形同虚设
    final raw = File(path).readAsBytesSync();
    final decoded = utf8.decode(raw, allowMalformed: true);
    expect(decoded.contains(secret), isFalse, reason: '密文文件里不应出现明文');

    // 3. 错误密码必须失败
    final wrong = sqlite3.open(path);
    wrong.execute("PRAGMA key = '$wrongPw';");
    expect(
      () => wrong.select('SELECT * FROM note'),
      throwsA(anything),
      reason: '错误密码必须读不出数据',
    );
    wrong.close();

    // 4. 正确密码能读回原值
    final reader = sqlite3.open(path);
    reader.execute("PRAGMA key = '$rightPw';");
    final rows = reader.select('SELECT body FROM note');
    expect(rows.length, 1);
    expect(rows.first['body'], secret);
    reader.close();

    dir.deleteSync(recursive: true);
  });

  test('raw key 形式可用，避免 SQLCipher 二次 KDF', () {
    final dir = Directory.systemTemp.createTempSync('envx_raw_');
    final path = '${dir.path}/raw.db';

    // 模拟 Argon2 派生出的 32 字节密钥
    final hex = List<int>.generate(32, (i) => (i * 11 + 7) % 256)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final zeroHex = List<String>.filled(64, '0').join();

    final w = sqlite3.open(path);
    w.execute("PRAGMA key = \"x'$hex'\";");
    w.execute('CREATE TABLE t (v TEXT)');
    w.execute("INSERT INTO t VALUES ('raw-secret')");
    w.close();

    final bad = sqlite3.open(path);
    bad.execute("PRAGMA key = \"x'$zeroHex'\";");
    expect(() => bad.select('SELECT * FROM t'), throwsA(anything),
        reason: '错误的原始密钥必须读不出数据');
    bad.close();

    final ok = sqlite3.open(path);
    ok.execute("PRAGMA key = \"x'$hex'\";");
    expect(ok.select('SELECT v FROM t').first['v'], 'raw-secret');
    ok.close();

    dir.deleteSync(recursive: true);
  });
}
