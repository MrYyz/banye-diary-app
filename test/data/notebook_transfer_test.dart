import 'dart:io';
import 'dart:typed_data';

import 'package:envx/core/kdf.dart';
import 'package:envx/data/database.dart';
import 'package:envx/data/notebook_transfer.dart';
import 'package:envx/data/salt_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// 按文件名开一个独立加密库（app.db / vault.db 各有各的盐与密码）。
Future<EnvxDatabase> _open(Directory dir, String fileName, String password) async {
  final Uint8List salt =
      await SaltStore(dir: dir).loadOrCreate(fileName);
  final key = deriveKey(
    password: password,
    salt: salt,
    params: KdfParams.light,
  ).keyBytes;
  return openEnvxDatabase(dir: dir, key32: key, fileName: fileName);
}

void main() {
  test('整个笔记本搬进隐藏库：笔记、附件、封面色、创建时间都跟着走', () async {
    final dir = Directory.systemTemp.createTempSync('envx_move_');
    final photo = File('${dir.path}/photo_1.jpg')
      ..writeAsBytesSync(<int>[1, 2, 3, 4]);
    final main = await _open(dir, 'app.db', '111111');
    final vault = await _open(dir, 'vault.db', '222222');

    try {
      final nb = await main.notebooks.create(name: '卡路里', color: 'sun');
      final breakfast = await main.notes.create(
        notebookId: nb.id,
        title: '早餐',
        body: '两个蛋一杯奶',
      );
      await main.notes.create(notebookId: nb.id, title: '午餐', body: '');
      await main.attachments.replaceFor(breakfast.id, [photo.path]);

      // 换一个时间点，验证搬迁保的是原始时间而不是「刚刚」。
      final originalCreatedAt = nb.createdAt;

      final result = await moveNotebook(
        from: main,
        to: vault,
        notebookId: nb.id,
      );

      expect(result.name, '卡路里');
      expect(result.noteCount, 2);
      expect(result.photoCount, 1);

      final moved = await vault.notebooks.all();
      expect(moved.length, 1);
      expect(moved.first.name, '卡路里');
      expect(moved.first.color, 'sun');
      expect(moved.first.createdAt, originalCreatedAt);
      expect(await vault.notebooks.countNotes(moved.first.id), 2);

      final notes = await vault.notes.list(moved.first.id);
      expect(notes.map((n) => n.title), containsAll(<String>['早餐', '午餐']));

      final kept = notes.firstWhere((n) => n.title == '早餐');
      expect(kept.body, '两个蛋一杯奶');
      final atts = await vault.attachments.listFor(kept.id);
      expect(atts.map((a) => a.path), contains(photo.path),
          reason: '插图记录要跟着笔记一起搬，否则隐藏区里打开是空图');

      // 源库必须干净：本子、笔记都没了（笔记靠外键级联删）。
      expect(await main.notebooks.all(), isEmpty);
      expect(await main.notes.list(nb.id), isEmpty);
      expect(await main.attachments.allPaths(), isEmpty);
    } finally {
      await main.close();
      await vault.close();
      dir.deleteSync(recursive: true);
    }
  });

  test('从隐藏库搬回主库：内容原样回来', () async {
    final dir = Directory.systemTemp.createTempSync('envx_move_back_');
    final main = await _open(dir, 'app.db', '111111');
    final vault = await _open(dir, 'vault.db', '222222');

    try {
      final nb = await vault.notebooks.create(name: '不想被看到', color: 'blush');
      await vault.notes.create(
        notebookId: nb.id,
        title: '深夜',
        body: '只写给自己',
      );

      final back = await moveNotebook(from: vault, to: main, notebookId: nb.id);

      expect(back.noteCount, 1);
      final books = await main.notebooks.all();
      expect(books.length, 1);
      expect(books.first.name, '不想被看到');
      expect(await main.notebooks.countNotes(books.first.id), 1);
      expect(await vault.notebooks.all(), isEmpty);
    } finally {
      await main.close();
      await vault.close();
      dir.deleteSync(recursive: true);
    }
  });

  test('笔记本不存在时直接抛错，不留下空本子', () async {
    final dir = Directory.systemTemp.createTempSync('envx_move_missing_');
    final main = await _open(dir, 'app.db', '111111');
    final vault = await _open(dir, 'vault.db', '222222');

    try {
      await expectLater(
        moveNotebook(from: main, to: vault, notebookId: 'no-such-id'),
        throwsStateError,
      );
      expect(await vault.notebooks.all(), isEmpty);
    } finally {
      await main.close();
      await vault.close();
      dir.deleteSync(recursive: true);
    }
  });
}
