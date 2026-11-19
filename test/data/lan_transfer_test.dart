import 'dart:io';

import 'package:envx/data/database.dart';
import 'package:envx/data/lan_transfer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hashlib/hashlib.dart';

import 'test_helper.dart';

void main() {
  late Directory dir;
  late EnvxDatabase db;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('envx_lan_');
    db = await openTestDb(dir, 'pw');
  });

  tearDown(() async {
    await db.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('配对码', () {
    test('6 位数字', () {
      for (var i = 0; i < 20; i++) {
        final code = newPairCode();
        expect(code.length, 6);
        expect(int.tryParse(code), isNotNull);
      }
    });

    test('相等才通过，差一位就否', () {
      expect(codeMatches('123456', '123456'), isTrue);
      expect(codeMatches('123456', '123457'), isFalse);
      expect(codeMatches('123456', '12345'), isFalse);
      expect(codeMatches('123456', '1234567'), isFalse);
      expect(codeMatches('000000', ''), isFalse);
    });
  });

  group('打包与解析', () {
    test('笔记正文、时间、置顶往返一致', () async {
      final nbRepo = db.notebooks;
      final noteRepo = db.notes;
      final nb = await nbRepo.create(name: '日常碎片', color: 'mint');
      final n1 = await noteRepo.create(
        notebookId: nb.id,
        title: '今天数学考砸了',
        body: '第 3 题看错条件。',
      );
      await noteRepo.togglePinned(n1.id);
      await noteRepo.create(notebookId: nb.id, title: '晚饭', body: '番茄炒蛋');

      final pack = await buildPack(db: db, notebook: nb);
      expect(pack.noteCount, 2);
      expect(pack.photoCount, 0);

      final parsed = parsePack(pack.json);
      expect(parsed.notebookName, '日常碎片');
      expect(parsed.notebookColor, 'mint');
      expect(parsed.notes.length, 2);

      final pinned = parsed.notes.firstWhere((n) => n.title == '今天数学考砸了');
      expect(pinned.body, '第 3 题看错条件。');
      expect(pinned.pinned, 1);
      expect(pinned.createdAt, greaterThan(0));
    });

    test('插图以 base64 带上并保留摘要', () async {
      final nbRepo = db.notebooks;
      final noteRepo = db.notes;
      final attachRepo = db.attachments;
      final nb = await nbRepo.create(name: '带图的本');
      final note = await noteRepo.create(notebookId: nb.id, title: '一张图');

      final photo = File('${dir.path}/p.jpg')
        ..writeAsBytesSync(List<int>.generate(64, (i) => i * 3 % 256));
      await attachRepo.replaceFor(note.id, [photo.path]);

      final pack = await buildPack(db: db, notebook: nb);
      expect(pack.photoCount, 1);
      expect(pack.skippedPhotos, 0);

      final parsed = parsePack(pack.json);
      expect(parsed.photoCount, 1);
      final ph = parsed.notes.first.photos.first;
      expect(ph.bytes.length, 64);
      expect(ph.sha256, sha256.hex(photo.readAsBytesSync()));
    });

    test('文件不存在的插图被跳过并计数', () async {
      final nbRepo = db.notebooks;
      final noteRepo = db.notes;
      final attachRepo = db.attachments;
      final nb = await nbRepo.create(name: '孤儿图');
      final note = await noteRepo.create(notebookId: nb.id, title: '图没了');
      await attachRepo.replaceFor(note.id, ['${dir.path}/nope.jpg']);

      final pack = await buildPack(db: db, notebook: nb);
      expect(pack.photoCount, 0);
      expect(pack.skippedPhotos, 1);
    });

    test('版本不对直接拒绝', () {
      expect(
        () => parsePack('{"version":99,"notebook":{"name":"x"},"notes":[]}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('结构坏掉直接拒绝，不瞎猜', () {
      expect(() => parsePack('[]'), throwsA(isA<FormatException>()));
      expect(
        () => parsePack('{"version":1,"notes":[]}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parsePack('{"version":1,"notebook":{"name":""},"notes":[]}'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('落库', () {
    test('导入后成为独立笔记本，时间保留', () async {
      final nbRepo = db.notebooks;
      final noteRepo = db.notes;
      final nb = await nbRepo.create(name: '寄出去的本', color: 'sky');
      final note = await noteRepo.create(
        notebookId: nb.id,
        title: '一封信',
        body: '正文',
      );

      final pack = await buildPack(db: db, notebook: nb);
      final parsed = parsePack(pack.json);

      final photosDir = '${dir.path}/imported_photos';
      final result = await applyPack(db: db, pack: parsed, photosDir: photosDir);

      expect(result.noteCount, 1);
      final all = await nbRepo.all();
      expect(all.length, 2);
      final imported = all.firstWhere((n) => n.id == result.notebookId);
      expect(imported.name, '寄出去的本');

      final notes = await noteRepo.list(imported.id);
      expect(notes.length, 1);
      expect(notes.first.title, '一封信');
      expect(notes.first.body, '正文');
      // 时间必须还原，否则导入的信会全部挤到"刚刚"。
      expect(notes.first.createdAt, note.createdAt);
      expect(notes.first.updatedAt, note.updatedAt);
    });

    test('图片落盘且能被 listFor 读到', () async {
      final nbRepo = db.notebooks;
      final noteRepo = db.notes;
      final attachRepo = db.attachments;
      final nb = await nbRepo.create(name: '带图寄出');
      final note = await noteRepo.create(notebookId: nb.id, title: '有图');
      final photo = File('${dir.path}/a.png')
        ..writeAsBytesSync(List<int>.generate(32, (i) => 255 - i));
      await attachRepo.replaceFor(note.id, [photo.path]);

      final parsed = parsePack((await buildPack(db: db, notebook: nb)).json);
      final photosDir = '${dir.path}/imported_photos';
      final result = await applyPack(db: db, pack: parsed, photosDir: photosDir);

      expect(result.photoCount, 1);
      expect(result.badPhotos, 0);

      final notes = await noteRepo.list(result.notebookId);
      final attached = await attachRepo.listFor(notes.first.id);
      expect(attached.length, 1);
      expect(File(attached.first.path).existsSync(), isTrue);
      expect(attached.first.path, contains('imported_photos'));
    });

    test('摘要对不上的图被拒绝落盘', () async {
      final nbRepo = db.notebooks;
      final nb = await nbRepo.create(name: '坏图');
      final good = await buildPack(db: db, notebook: nb);

      // 手工改造：加一张摘要错误的图。
      final tampered = good.json.replaceFirst(
        '"notes":[]',
        '"notes":[{"title":"x","body":"y","createdAt":0,"updatedAt":0,"pinned":0,'
            '"photos":[{"name":"bad.png","b64":"AAAA","sha256":"deadbeef"}]}]',
      );
      final parsed = parsePack(tampered);
      final result = await applyPack(
        db: db,
        pack: parsed,
        photosDir: '${dir.path}/imported_photos',
      );
      expect(result.photoCount, 0);
      expect(result.badPhotos, 1);
    });
  });
  group('手动地址解析', () {
    test('标准写法', () {
      final r = parseManualEndpoint('192.168.1.5:39481');
      expect(r, isNotNull);
      expect(r!.host, '192.168.1.5');
      expect(r.port, 39481);
    });

    test('前后空格与端口边界', () {
      expect(parseManualEndpoint('  10.0.0.2:80  ')?.port, 80);
      expect(parseManualEndpoint('10.0.0.2:1')?.port, 1);
      expect(parseManualEndpoint('10.0.0.2:65535')?.port, 65535);
    });

    test('端口越界或不是数字一律拒绝', () {
      expect(parseManualEndpoint('10.0.0.2:0'), isNull);
      expect(parseManualEndpoint('10.0.0.2:65536'), isNull);
      expect(parseManualEndpoint('10.0.0.2:abc'), isNull);
      expect(parseManualEndpoint('10.0.0.2:'), isNull);
    });

    test('缺端口、空串、只给端口都拒绝', () {
      expect(parseManualEndpoint('10.0.0.2'), isNull);
      expect(parseManualEndpoint(''), isNull);
      expect(parseManualEndpoint(':8080'), isNull);
      expect(parseManualEndpoint('   '), isNull);
    });

    test('带冒号的 IPv6 明确拒绝（要 [::1]:80 写法才行）', () {
      expect(parseManualEndpoint('fe80::1:8080'), isNull);
    });
  });
}