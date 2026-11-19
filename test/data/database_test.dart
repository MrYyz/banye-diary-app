import 'dart:convert';
import 'dart:io';

import 'package:envx/core/kdf.dart';
import 'package:envx/data/database.dart';
import 'package:envx/data/salt_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helper.dart';

void main() {
  group('开库与落盘', () {
    test('建库并落盘：app.db 与 sidecar 盐文件都在磁盘上', () async {
      final dir = Directory.systemTemp.createTempSync('envx_m2_disk_');
      EnvxDatabase? db;
      try {
        db = await openTestDb(dir, 'pw-disk');
        await db.notebooks.create(name: '日记簿');

        expect(File('${dir.path}/app.db').existsSync(), isTrue);
        expect(File('${dir.path}/app.db.salt').existsSync(), isTrue);

        final salt = await SaltStore(dir: dir).read('app.db');
        expect(salt, hasLength(16));
      } finally {
        await db?.close();
        dir.deleteSync(recursive: true);
      }
    });

    test('错 key 打开抛 WrongKeyException', () async {
      final dir = Directory.systemTemp.createTempSync('envx_m2_wrong_');
      EnvxDatabase? db;
      try {
        db = await openTestDb(dir, 'right-password');
        await db.notebooks.create(name: 'x');
        await db.close();
        db = null;

        final wrongKey = await keyFor(dir, 'wrong-password-2026');
        await expectLater(
          () => openEnvxDatabase(dir: dir, key32: wrongKey),
          throwsA(isA<WrongKeyException>()),
        );
      } finally {
        await db?.close();
        dir.deleteSync(recursive: true);
      }
    });

    test('盐持久化：关库重开同盐同密码仍可读', () async {
      final dir = Directory.systemTemp.createTempSync('envx_m2_persist_');
      EnvxDatabase? db1;
      try {
        final store = SaltStore(dir: dir);
        final salt1 = await store.loadOrCreate('app.db');
        final key1 = deriveKey(
          password: 'persist-pw',
          salt: salt1,
          params: KdfParams.light,
        ).keyBytes;

        db1 = await openEnvxDatabase(dir: dir, key32: key1);
        await db1.notebooks.create(name: '留下来的本子');
        await db1.close();
        db1 = null;

        final salt2 = await store.read('app.db');
        expect(salt2, isNotNull);
        expect(constantTimeEquals(salt1, salt2!), isTrue,
            reason: '重开库必须读到同一份盐');

        final key2 = deriveKey(
          password: 'persist-pw',
          salt: salt2,
          params: KdfParams.light,
        ).keyBytes;
        final db2 = await openEnvxDatabase(dir: dir, key32: key2);
        try {
          final all = await db2.notebooks.all();
          expect(all.map((n) => n.name), contains('留下来的本子'));
        } finally {
          await db2.close();
        }
      } finally {
        await db1?.close();
        dir.deleteSync(recursive: true);
      }
    });

    test('磁盘文件里搜不到明文（UTF-8 解码 + 原始字节双扫）', () async {
      final dir = Directory.systemTemp.createTempSync('envx_m2_plain_');
      const secretTitle = '只写给自己看的标题ABC123';
      const secretBody = '这段正文绝不允许以明文出现在库文件里';
      EnvxDatabase? db;
      try {
        db = await openTestDb(dir, 'pw-plain');
        final nb = await db.notebooks.create(name: '隐藏簿');
        await db.notes.create(
          notebookId: nb.id,
          title: secretTitle,
          body: secretBody,
        );
        await db.close();
        db = null;

        final raw = File('${dir.path}/app.db').readAsBytesSync();
        final decoded = utf8.decode(raw, allowMalformed: true);
        expect(decoded.contains(secretTitle), isFalse,
            reason: '解码文本里不应出现标题明文');
        expect(decoded.contains(secretBody), isFalse,
            reason: '解码文本里不应出现正文明文');
        expect(bytesContain(raw, utf8.encode(secretTitle)), isFalse,
            reason: '原始字节里不应出现标题 UTF-8 编码');
        expect(bytesContain(raw, utf8.encode(secretBody)), isFalse,
            reason: '原始字节里不应出现正文 UTF-8 编码');
      } finally {
        await db?.close();
        dir.deleteSync(recursive: true);
      }
    });
  });
}
