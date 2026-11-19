import 'dart:io';

import 'package:envx/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helper.dart';

void main() {
  group('笔记本仓库', () {
    test('建笔记本：落库后 all() 读回名称与颜色', () async {
      final dir = Directory.systemTemp.createTempSync('envx_m2_nb_');
      EnvxDatabase? db;
      try {
        db = await openTestDb(dir, 'pw-nb');
        final nb = await db.notebooks.create(name: '工作', color: 'mint');
        expect(nb.id, hasLength(32));
        expect(nb.name, '工作');
        expect(nb.color, 'mint');

        final all = await db.notebooks.all();
        expect(all, hasLength(1));
        expect(all.first.id, nb.id);
      } finally {
        await db?.close();
        dir.deleteSync(recursive: true);
      }
    });

    test('改名：rename 后名称更新', () async {
      final dir = Directory.systemTemp.createTempSync('envx_m2_rename_');
      EnvxDatabase? db;
      try {
        db = await openTestDb(dir, 'pw-rename');
        final nb = await db.notebooks.create(name: '旧名字');
        await db.notebooks.rename(nb.id, '新名字');

        final all = await db.notebooks.all();
        expect(all.single.name, '新名字');
      } finally {
        await db?.close();
        dir.deleteSync(recursive: true);
      }
    });

    test('级联删：删笔记本后其下笔记一并清空', () async {
      final dir = Directory.systemTemp.createTempSync('envx_m2_cascade_');
      EnvxDatabase? db;
      try {
        db = await openTestDb(dir, 'pw-cascade');
        final nb = await db.notebooks.create(name: '待删簿');
        await db.notes.create(notebookId: nb.id, title: '笔记一');
        await db.notes.create(notebookId: nb.id, title: '笔记二');
        expect(await db.notebooks.countNotes(nb.id), 2);

        await db.notebooks.delete(nb.id);

        expect(await db.notebooks.countNotes(nb.id), 0);
        expect(await db.notes.list(nb.id), isEmpty);
      } finally {
        await db?.close();
        dir.deleteSync(recursive: true);
      }
    });
  });

  group('笔记仓库', () {
    test('建笔记并读回一致：标题、正文、所属本子全部匹配', () async {
      final dir = Directory.systemTemp.createTempSync('envx_m2_note_');
      EnvxDatabase? db;
      try {
        db = await openTestDb(dir, 'pw-note');
        final nb = await db.notebooks.create(name: '簿');
        final created = await db.notes.create(
          notebookId: nb.id,
          title: '第一篇',
          body: '正文内容',
        );

        expect(created.id, hasLength(32));
        final fetched = await db.notes.get(created.id);
        expect(fetched, isNotNull);
        expect(fetched!.title, '第一篇');
        expect(fetched.body, '正文内容');
        expect(fetched.notebookId, nb.id);
        expect(fetched.createdAt, greaterThan(0));
        expect(fetched.updatedAt, greaterThan(0));
      } finally {
        await db?.close();
        dir.deleteSync(recursive: true);
      }
    });

    test('改正文并刷 updatedAt：正文更新且 updatedAt 变大', () async {
      final dir = Directory.systemTemp.createTempSync('envx_m2_touch_');
      EnvxDatabase? db;
      try {
        db = await openTestDb(dir, 'pw-touch');
        final nb = await db.notebooks.create(name: '簿');
        final note = await db.notes.create(
          notebookId: nb.id,
          title: '标题',
          body: '旧正文',
        );
        final before = note.updatedAt;

        await Future.delayed(const Duration(milliseconds: 250));
        await db.notes.save(note.id, body: '新正文');

        final fetched = await db.notes.get(note.id);
        expect(fetched!.body, '新正文');
        expect(fetched.updatedAt, greaterThan(before));
      } finally {
        await db?.close();
        dir.deleteSync(recursive: true);
      }
    });

    test('删除：删后 get 返回 null', () async {
      final dir = Directory.systemTemp.createTempSync('envx_m2_del_');
      EnvxDatabase? db;
      try {
        db = await openTestDb(dir, 'pw-del');
        final nb = await db.notebooks.create(name: '簿');
        final note = await db.notes.create(notebookId: nb.id, title: '要删');

        await db.notes.delete(note.id);

        expect(await db.notes.get(note.id), isNull);
      } finally {
        await db?.close();
        dir.deleteSync(recursive: true);
      }
    });

    test('搜索：标题/正文命中、无关词不命中、空串返回空表、忽略大小写',
        () async {
      final dir = Directory.systemTemp.createTempSync('envx_m2_search_');
      EnvxDatabase? db;
      try {
        db = await openTestDb(dir, 'pw-search');
        final nb = await db.notebooks.create(name: '簿');
        await db.notes.create(
          notebookId: nb.id,
          title: '月光下的散步',
          body: '沿着河堤走了很久',
        );
        await db.notes.create(
          notebookId: nb.id,
          title: 'Hello World',
          body: '英文标题笔记',
        );
        await db.notes.create(
          notebookId: nb.id,
          title: '菜谱',
          body: '番茄炒蛋的做法',
        );

        final hitTitle = await db.notes.search('月光');
        expect(hitTitle, hasLength(1));
        expect(hitTitle.single.title, '月光下的散步');

        final hitBody = await db.notes.search('河堤');
        expect(hitBody, hasLength(1));

        final hitCase = await db.notes.search('hello');
        expect(hitCase, hasLength(1));
        expect(hitCase.single.title, 'Hello World');

        final miss = await db.notes.search('不存在的关键词');
        expect(miss, isEmpty);

        final empty = await db.notes.search('');
        expect(empty, isEmpty);
      } finally {
        await db?.close();
        dir.deleteSync(recursive: true);
      }
    });

    test('置顶排序：置顶在前；未置顶按 updatedAt 降序', () async {
      final dir = Directory.systemTemp.createTempSync('envx_m2_pin_');
      EnvxDatabase? db;
      try {
        db = await openTestDb(dir, 'pw-pin');
        final nb = await db.notebooks.create(name: '簿');

        final early = await db.notes.create(
          notebookId: nb.id,
          title: '早写的一篇',
        );
        await Future.delayed(const Duration(milliseconds: 250));
        final late = await db.notes.create(
          notebookId: nb.id,
          title: '晚写的一篇',
        );

        // 未置顶：晚写的排前面
        var list = await db.notes.list(nb.id);
        expect(list.map((n) => n.id), [late.id, early.id]);

        // 置顶早写的一篇：它排到最前
        await db.notes.togglePinned(early.id);
        list = await db.notes.list(nb.id);
        expect(list.map((n) => n.id), [early.id, late.id]);

        // 再切回未置顶
        await db.notes.togglePinned(early.id);
        list = await db.notes.list(nb.id);
        expect(list.map((n) => n.id), [late.id, early.id]);
      } finally {
        await db?.close();
        dir.deleteSync(recursive: true);
      }
    });
  });
}
