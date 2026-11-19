import 'dart:io';

import 'package:envx/core/kdf.dart';
import 'package:envx/data/database.dart';
import 'package:envx/data/salt_store.dart';
import 'package:envx/ui/screens/envelope_editor_page.dart';
import 'package:envx/ui/screens/home_page.dart';
import 'package:envx/ui/screens/note_list_page.dart';
import 'package:envx/ui/screens/settings_page.dart';
import 'package:envx/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// 平板横屏体检。
///
/// 安卓平板的主姿态是横屏（1366×1024、1280×800 最常见），而界面稿里
/// 06 屏给的是 900×576。当前布局按「宽度 ≥720 走双栏」伸缩，理论上
/// 都覆盖，但宽高比一变最容易出的问题是 RenderFlex 溢出 ——
/// 这种错误在 widget test 里会直接判失败，比肉眼看截图靠谱。
///
/// 这里只断言"不炸"：不比对像素（像素由 screenshots_test 的 26 张守着）。
const _pin = '123456';

Future<EnvxDatabase> _openDb(WidgetTester tester, Directory dir) async {
  final db = await tester.runAsync(() async {
    final salt = await SaltStore(dir: dir).loadOrCreate('app.db');
    final key = deriveKey(
      password: _pin,
      salt: salt,
      params: KdfParams.light,
    ).keyBytes;
    final opened = await openEnvxDatabase(dir: dir, key32: key);
    final nb = await opened.notebooks.create(name: '日常碎片', color: 'sun');
    await opened.notebooks.create(name: '数学错题', color: 'sky');
    await opened.notebooks.create(name: '读书摘抄', color: 'blush');
    for (var i = 0; i < 4; i++) {
      await opened.notes.create(
        notebookId: nb.id,
        title: '第 ${i + 1} 封：今天的事',
        body: '这条正文写得长一点，用来把行盒撑到接近两行，'
            '看看横屏窄高度下会不会溢出。',
      );
    }
    return opened;
  });
  return db!;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  const sizes = [
    ('1366x1024', 1366.0, 1024.0),
    ('1280x800', 1280.0, 800.0),
    ('900x576', 900.0, 576.0),
  ];

  for (final (tag, w, h) in sizes) {
    group('横屏 $tag', () {
      testWidgets('首页不溢出', (tester) async {
        tester.view.physicalSize = Size(w, h);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final dir = Directory.systemTemp.createTempSync('envx_land_${tag}_');
        final db = await _openDb(tester, dir);
        addTearDown(() async {
          await db.close();
          dir.deleteSync(recursive: true);
        });

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: EnvxTheme.build(),
            home: HomePage(db: db, dirProvider: () async => dir),
          ),
        );
        await _settle(tester);
        expect(find.text('我的笔记本'), findsOneWidget);
      });

      testWidgets('笔记列表不溢出', (tester) async {
        tester.view.physicalSize = Size(w, h);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final dir = Directory.systemTemp.createTempSync('envx_landl_${tag}_');
        final db = await _openDb(tester, dir);
        addTearDown(() async {
          await db.close();
          dir.deleteSync(recursive: true);
        });

        final notebooks = (await tester.runAsync(() => db.notebooks.all()))!;
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: EnvxTheme.build(),
            home: NoteListPage(db: db, notebook: notebooks.first),
          ),
        );
        await _settle(tester);
        expect(find.text('日常碎片'), findsWidgets);
      });

      testWidgets('编辑页不溢出', (tester) async {
        tester.view.physicalSize = Size(w, h);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final dir = Directory.systemTemp.createTempSync('envx_lande_${tag}_');
        final db = await _openDb(tester, dir);
        addTearDown(() async {
          await db.close();
          dir.deleteSync(recursive: true);
        });

        final notebooks = (await tester.runAsync(() => db.notebooks.all()))!;
        final notes = (await tester.runAsync(
          () => db.notes.list(notebooks.first.id),
        ))!;
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: EnvxTheme.build(),
            home: EnvelopeEditorPage(
              db: db,
              notebook: notebooks.first,
              note: notes.first,
            ),
          ),
        );
        await _settle(tester);
        expect(find.byKey(const ValueKey('editor-back')), findsOneWidget);
      });

      testWidgets('设置页不溢出', (tester) async {
        tester.view.physicalSize = Size(w, h);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final dir = Directory.systemTemp.createTempSync('envx_lands_${tag}_');
        addTearDown(() => dir.deleteSync(recursive: true));

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: EnvxTheme.build(),
            home: SettingsPage(dir: dir),
          ),
        );
        await _settle(tester);
        expect(find.text('设置'), findsWidgets);
      });
    });
  }
}
