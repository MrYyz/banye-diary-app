import 'dart:io';

import 'package:envx/ui/unlock_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// 临时目录必须用同步 API 建：在 `testWidgets` 的 fake-async 区里
/// `await Directory.createTemp()` 这类真实 IO 的续延不会被推进，
/// 用例会永远挂着。同理，页面自己发起的异步读盘要靠 runAsync 带一轮。
Directory _tempDir(String tag, {bool seeded = false}) {
  final dir = Directory.systemTemp.createTempSync('envx_$tag');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  if (seeded) {
    File('${dir.path}/app.db.salt')
        .writeAsBytesSync(List<int>.filled(16, 7));
  }
  return dir;
}

/// 带几轮真实等待，让 `_detect()` 里的读盘完成并重建界面。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('首次打开：引导设置密码，而不是问要密码', (WidgetTester tester) async {
    final dir = _tempDir('unlock_first');

    await tester.pumpWidget(
      MaterialApp(home: UnlockPage(dirProvider: () async => dir)),
    );
    await _settle(tester);

    expect(find.text('信封日记'), findsOneWidget);
    expect(find.text('第一次用，先给自己设一个 6 位密码'), findsOneWidget);
    expect(find.text('输满 6 位就生效'), findsOneWidget);

    // 点三个键：不满 6 位不该进入确认态
    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('3'));
    await tester.pump();

    expect(find.text('输满 6 位就生效'), findsOneWidget);
  });

  testWidgets('已有盐：显示日常解锁态', (WidgetTester tester) async {
    final dir = _tempDir('unlock_again', seeded: true);

    await tester.pumpWidget(
      MaterialApp(home: UnlockPage(dirProvider: () async => dir)),
    );
    await _settle(tester);

    expect(find.text('输入密码解锁'), findsOneWidget);
    expect(find.text('你的心事，只留给自己'), findsOneWidget);
  });

  testWidgets('390 宽度下键盘与标题水平居中', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dir = _tempDir('unlock_layout');
    await tester.pumpWidget(
      MaterialApp(home: UnlockPage(dirProvider: () async => dir)),
    );
    await _settle(tester);

    final c1 = tester.getCenter(find.text('1'));
    final c3 = tester.getCenter(find.text('3'));
    // 两端键必须关于屏幕中线对称，否则就是键盘溢出
    expect(c1.dx + c3.dx, closeTo(390, 2),
        reason: '1 与 3 应关于 x=195 对称，实际 c1=${c1.dx}, c3=${c3.dx}');

    final title = tester.getCenter(find.text('信封日记'));
    expect(title.dx, closeTo(195, 2));

    // 最右边的键不能顶出屏幕
    final rightEdge = tester.getBottomRight(find.text('3'));
    expect(rightEdge.dx, lessThan(390));
  });
}
