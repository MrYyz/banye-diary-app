import 'dart:io';

import 'package:envx/ui/screens/envelope_editor_page.dart';
import 'package:envx/ui/screens/home_page.dart';
import 'package:envx/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../data/test_helper.dart';

/// 空态路径：点页面中间的空态区域就该拉起新建，建好后问要不要马上写第一篇。
/// 右下角的 + 已经按用户要求去掉 —— 首页只留中间这一处入口。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('空态点中间区域：直接新建笔记本，建好立刻问是否现在写第一篇',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dir = Directory.systemTemp.createTempSync('envx_home_empty_');
    final db = await tester.runAsync(() => openTestDb(dir, '123456'));
    addTearDown(() async {
      await db!.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    await tester.pumpWidget(
      MaterialApp(theme: EnvxTheme.build(), home: HomePage(db: db!)),
    );
    await _settle(tester);

    expect(find.text('还没有笔记本'), findsOneWidget);

    // 首页不该再有右下角 +：入口收到页面中间的空态里。
    expect(find.byType(FloatingActionButton), findsNothing,
        reason: '用户要求去掉首页右下角 +，新建只走中间空态');

    await tester.tap(find.text('还没有笔记本'));
    await _settle(tester);

    // 点空态必须直接弹新建框
    expect(find.byType(AlertDialog), findsOneWidget,
        reason: '空态点 + 应拉起新建笔记本对话框，而不是只弹一句提示');
    expect(find.text('新建笔记本'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '卡路里');
    await tester.tap(find.text('完成'));
    await _settle(tester);

    // 建好后立刻问要不要写第一篇
    expect(find.text('「卡路里」建好了'), findsOneWidget);
    expect(find.text('现在写第一篇笔记吗？'), findsOneWidget);

    await tester.tap(find.text('现在写'));
    await _settle(tester);

    // 选「现在写」应直接进编辑页
    expect(find.byType(EnvelopeEditorPage), findsOneWidget,
        reason: '选「现在写」应落在信封编辑页');
  });
}
