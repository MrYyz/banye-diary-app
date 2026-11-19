import 'dart:io';

import 'package:envx/core/kdf.dart';
import 'package:envx/data/database.dart';
import 'package:envx/data/salt_store.dart';
import 'package:envx/data/schema.dart';
import 'package:envx/ui/screens/envelope_editor_page.dart';
import 'package:envx/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// M3 信封编辑页的行为验收（不参与截图，常规 flutter test 就会跑）。
///
/// 建库是真实 IO，必须在 tester.runAsync 里进行；fake-async 区里直接
/// await 会永久挂住（M2 已经踩过一次）。

late Directory _dir;
late EnvxDatabase _db;

Future<void> _boot() async {
  _dir = Directory.systemTemp.createTempSync('envx_editor_');
  final salt = await SaltStore(dir: _dir).loadOrCreate('app.db');
  final key = deriveKey(
    password: '123456',
    salt: salt,
    params: KdfParams.light,
  ).keyBytes;
  _db = await openEnvxDatabase(dir: _dir, key32: key);
}

Widget _shell(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: EnvxTheme.build(),
      home: child,
    );

/// 带一层 Navigator 的宿主：编辑页 pop 时不会撞到「最后一页不能 pop」。
Widget _host(EnvxDatabase db, Notebook notebook, Note? note) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: EnvxTheme.build(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EnvelopeEditorPage(
                  db: db,
                  notebook: notebook,
                  note: note,
                ),
              ),
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(_boot);

  tearDown(() async {
    await _db.close();
    _dir.deleteSync(recursive: true);
  });

  testWidgets('正文行盒严格 28（横线才对得上）', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final seeded = await tester.runAsync(() async {
      final nb = await _db.notebooks.create(name: '日常碎片', color: 'sun');
      final note = await _db.notes.create(
        notebookId: nb.id,
        title: '今天数学考砸了',
        body: '第一行\n第二行\n第三行\n第四行',
      );
      return (nb, note);
    });
    final (nb, note) = seeded!;

    await tester.pumpWidget(
      _shell(EnvelopeEditorPage(db: _db, notebook: nb, note: note)),
    );
    await tester.pump();

    // 第二个 TextField 是正文；4 行 × 28 = 112。
    final body = tester.getSize(find.byType(TextField).at(1));
    expect(
      body.height,
      closeTo(112, 1.0),
      reason: '正文行盒不是 28，信纸横线会与文字错位',
    );

    // 标题行盒 21 × 1.5 = 31.5。
    final title = tester.getSize(find.byType(TextField).at(0));
    expect(title.height, closeTo(31.5, 1.0));
  });

  testWidgets('点返回写回库并退回列表', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final nb = (await tester.runAsync(
      () => _db.notebooks.create(name: '日常碎片', color: 'sun'),
    ))!;

    await tester.pumpWidget(_host(_db, nb, null));
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField).at(0), '新标题');
    await tester.enterText(find.byType(TextField).at(1), '新正文第一行');
    // 「完成」已从顶栏删掉：返回即保存，用返回箭头走同一条落盘路径。
    await tester.tap(find.byKey(const ValueKey('editor-back')));
    await tester.pump();
    // 落库是真实 IO，给它一点真实时间。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    final saved = (await tester.runAsync(() => _db.notes.list(nb.id)))!;
    expect(saved.length, 1);
    expect(saved.first.title, '新标题');
    expect(saved.first.body, '新正文第一行');
  });

  testWidgets('停手就自动落盘，不必点任何按钮', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final nb = (await tester.runAsync(
      () => _db.notebooks.create(name: '日常碎片', color: 'sun'),
    ))!;

    await tester.pumpWidget(_host(_db, nb, null));
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField).at(0), '自动保存');
    await tester.enterText(find.byType(TextField).at(1), '停手就落盘');
    // 输入停下 700ms 触发落盘。
    await tester.pump(const Duration(milliseconds: 800));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();

    final saved = (await tester.runAsync(() => _db.notes.list(nb.id)))!;
    expect(saved.length, 1, reason: '停手 700ms 应已经建好这一篇');
    expect(saved.first.title, '自动保存');
    expect(saved.first.body, '停手就落盘');
  });

  testWidgets('改完直接返回：内容已存，不再问「放弃」', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final seeded = await tester.runAsync(() async {
      final nb = await _db.notebooks.create(name: '日常碎片', color: 'sun');
      final note = await _db.notes.create(
        notebookId: nb.id,
        title: '旧标题',
        body: '旧正文',
      );
      return (nb, note);
    });
    final (nb, note) = seeded!;

    await tester.pumpWidget(_host(_db, nb, note));
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField).at(1), '改了一行');
    await tester.tap(find.byKey(const ValueKey('editor-back')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();

    expect(find.text('放弃这次修改？'), findsNothing,
        reason: '内容已经实时保存，不该再问要不要放弃');

    final saved = (await tester.runAsync(() => _db.notes.list(nb.id)))!;
    expect(saved.first.body, contains('改了一行'));
  });
}
