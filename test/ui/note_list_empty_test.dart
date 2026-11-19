import 'dart:io';

import 'package:envx/ui/screens/note_list_page.dart';
import 'package:envx/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../data/test_helper.dart';

/// 用户实测反馈的第四条：空笔记本里右下角没有 +，等于进不去第一篇。
Future<void> _settle(WidgetTester tester, {int rounds = 10}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('空笔记本：右下角 + 在，空态文案叫「还没有笔记」',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dir = Directory.systemTemp.createTempSync('envx_empty_list_');
    final db = await tester.runAsync(() => openTestDb(dir, '123456'));
    addTearDown(() async {
      await db!.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    final nb = (await tester.runAsync(
      () => db!.notebooks.create(name: '日常碎片', color: 'sun'),
    ))!;

    await tester.pumpWidget(
      MaterialApp(
        theme: EnvxTheme.build(),
        home: NoteListPage(db: db!, notebook: nb),
      ),
    );
    await _settle(tester);

    expect(find.text('还没有笔记'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget,
        reason: '空本子里也得能点 + 写第一篇');
  });
}
