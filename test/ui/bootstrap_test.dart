import 'dart:io';

import 'package:envx/ui/bootstrap_page.dart';
import 'package:envx/ui/screens/home_page.dart';
import 'package:envx/ui/theme.dart';
import 'package:envx/ui/unlock_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// 用户实测反馈的第一条：第一次打开就要输密码，可密码根本没人设过。
/// 没有盐（= 从没设过访问密码）时必须直接进「我的笔记本」。
Future<void> _settle(WidgetTester tester, {int rounds = 14}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('从没设过密码：开机直接进我的笔记本，不出现解锁页',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dir = Directory.systemTemp.createTempSync('envx_boot_free_');
    addTearDown(() {
      // 首页还握着库文件句柄，Windows 上可能删不掉；删不掉就留给系统临时目录。
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: EnvxTheme.build(),
        home: BootstrapPage(dirProvider: () async => dir),
      ),
    );
    await _settle(tester);

    expect(find.byType(UnlockPage), findsNothing,
        reason: '没设过访问密码，就不该拿密码页拦人');
    expect(find.byType(HomePage), findsOneWidget,
        reason: '免密时应直接落在「我的笔记本」页');
  });
}
