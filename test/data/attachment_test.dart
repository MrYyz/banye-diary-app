import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'test_helper.dart';

Future<File> _writePhoto(Directory dir, String name, String content) async {
  final f = File('${dir.path}/$name');
  await f.writeAsString(content);
  return f;
}

Future<Directory> _photosDir(Directory root) async {
  final d = Directory('${root.path}/photos');
  if (!await d.exists()) await d.create(recursive: true);
  return d;
}

void main() {
  test('插图按落盘顺序读回，sha256 有值', () async {
    final dir = await Directory.systemTemp.createTemp('envx_att_');
    final db = await openTestDb(dir, 'pin');
    try {
      final nb = await db.notebooks.create(name: '本一');
      final note = await db.notes.create(notebookId: nb.id, title: '带图');
      final pd = await _photosDir(dir);
      final a = await _writePhoto(pd, '1000_a.jpg', 'aaa');
      final b = await _writePhoto(pd, '2000_b.jpg', 'bbb');

      // 故意倒序传入，读回应按文件名里的时间戳升序。
      await db.attachments.replaceFor(note.id, [b.path, a.path]);
      final rows = await db.attachments.listFor(note.id);

      expect(rows.length, 2);
      expect(rows.map((r) => r.path).toList(), [a.path, b.path]);
      expect(rows.every((r) => r.sha256.length == 64), isTrue);
      expect(await db.attachments.countFor(note.id), 2);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });

  test('重新打开库后插图仍在（重启恢复）', () async {
    final dir = await Directory.systemTemp.createTemp('envx_att2_');
    final pd = await _photosDir(dir);
    final a = await _writePhoto(pd, '3000_a.jpg', 'ppp');
    final b = await _writePhoto(pd, '4000_b.jpg', 'qqq');
    final paths = [a.path, b.path];

    final db1 = await openTestDb(dir, 'pin');
    final nb = await db1.notebooks.create(name: '本二');
    final note = await db1.notes.create(notebookId: nb.id, title: '重启');
    await db1.attachments.replaceFor(note.id, paths);
    await db1.close();

    final db2 = await openTestDb(dir, 'pin');
    try {
      final rows = await db2.attachments.listFor(note.id);
      expect(rows.map((r) => r.path).toList(), paths);
    } finally {
      await db2.close();
      await dir.delete(recursive: true);
    }
  });

  test('清空插图后表里不留记录', () async {
    final dir = await Directory.systemTemp.createTemp('envx_att3_');
    final db = await openTestDb(dir, 'pin');
    try {
      final nb = await db.notebooks.create(name: '本三');
      final note = await db.notes.create(notebookId: nb.id, title: '删图');
      final pd = await _photosDir(dir);
      final a = await _writePhoto(pd, '5000_a.jpg', 'rrr');
      await db.attachments.replaceFor(note.id, [a.path]);
      expect((await db.attachments.listFor(note.id)).length, 1);

      await db.attachments.replaceFor(note.id, const []);
      expect((await db.attachments.listFor(note.id)).isEmpty, isTrue);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });

  test('删掉这封信时附件级联清理', () async {
    final dir = await Directory.systemTemp.createTemp('envx_att4_');
    final db = await openTestDb(dir, 'pin');
    try {
      final nb = await db.notebooks.create(name: '本四');
      final note = await db.notes.create(notebookId: nb.id, title: '连坐');
      final pd = await _photosDir(dir);
      final a = await _writePhoto(pd, '6000_a.jpg', 'sss');
      await db.attachments.replaceFor(note.id, [a.path]);
      expect(await db.attachments.countFor(note.id), 1);

      await db.notes.delete(note.id);
      expect(await db.attachments.countFor(note.id), 0);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });
}
