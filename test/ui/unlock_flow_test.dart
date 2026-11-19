import 'dart:io';

import 'package:envx/core/kdf.dart';
import 'package:envx/data/database.dart';
import 'package:envx/ui/theme.dart';
import 'package:envx/ui/unlock_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../data/test_helper.dart';

/// 开锁流程的行为验收：首次建库、正确密码重开、错误密码回落。
///
/// 建库 / 开库是真实 IO，KDF 还经 compute 丢到后台 isolate；在 flutter_test
/// 的 fake-async 区里，这些续延要一轮「runAsync 真实等待 + pump 补帧」才推进
/// 一格，所以不能用固定时长死等，要轮询到回调触发或错误状态落定。
/// 目录经 dirProvider 注入临时目录，KDF 走 light 档，算法与盐流程同正式路径。

Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (final ch in pin.split('')) {
    await tester.tap(find.text(ch));
    await tester.pump();
  }
}

bool _shown(WidgetTester tester, String text) =>
    find.text(text).evaluate().length == 1;

/// 轮询推进开锁链路；直到开锁回调触发、或落到错误状态为止，最多 25 轮。
Future<void> _settleFlow(WidgetTester tester, bool Function() unlocked) async {
  for (var i = 0; i < 25; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
    if (unlocked()) return;
    if (_shown(tester, '密码不对') || _shown(tester, '打开失败，请重试')) return;
  }
}

Future<Widget> _shell(
  Directory dir,
  void Function(EnvxDatabase db)? onUnlocked,
) async {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: EnvxTheme.build(),
    home: UnlockPage(
      dirProvider: () async => dir,
      kdfParams: KdfParams.light,
      onUnlocked: onUnlocked,
    ),
  );
}

void main() {
  testWidgets('首次启动：无盐建库成功，回调触发并落盘 app.db 与 salt',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('envx_flow_first_');
    EnvxDatabase? unlocked;
    var calls = 0;
    addTearDown(() async {
      await unlocked?.close();
      dir.deleteSync(recursive: true);
    });

    await tester.pumpWidget(await _shell(dir, (db) {
      unlocked = db;
      calls++;
    }));
    await tester.pump();

    // 首次是「设置密码」：第一遍输完先落到确认态，再输一遍同样的才注册。
    // 没有找回入口，这一步是防手滑的唯一屏障。
    await _enterPin(tester, '123456');
    await _settleFlow(
        tester, () => _shown(tester, '再输一次，确认是这个'));
    await _enterPin(tester, '123456');
    await _settleFlow(tester, () => calls > 0);

    expect(calls, 1, reason: '首次建库成功后 onUnlocked 应被调用一次');
    expect(unlocked, isNotNull);
    expect(File('${dir.path}/app.db').existsSync(), isTrue,
        reason: '目录里应出现加密库 app.db');
    expect(File('${dir.path}/app.db.salt').existsSync(), isTrue,
        reason: '目录里应出现盐 sidecar app.db.salt');
  });

  testWidgets('已有库 + 正确密码：盐与密钥链路打通，能读回上次写入的数据',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('envx_flow_ok_');
    await tester.runAsync(() async {
      final seeded = await openTestDb(dir, '654321');
      await seeded.notebooks.create(name: '旧本子', color: 'sky');
      await seeded.close();
    });

    EnvxDatabase? unlocked;
    var calls = 0;
    addTearDown(() async {
      await unlocked?.close();
      dir.deleteSync(recursive: true);
    });

    await tester.pumpWidget(await _shell(dir, (db) {
      unlocked = db;
      calls++;
    }));
    await tester.pump();

    await _enterPin(tester, '654321');
    await _settleFlow(tester, () => calls > 0);

    expect(calls, 1, reason: '正确密码应开锁成功并回调一次');
    expect(unlocked, isNotNull);

    final names = await tester.runAsync(
      () async => unlocked!.notebooks.all().then(
            (list) => list.map((n) => n.name).toList(),
          ),
    );
    expect(names, contains('旧本子'),
        reason: '重开库后应读回上次写入的笔记本，证明盐 + 派生密钥链路正确');
  });

  testWidgets('已有库 + 错误密码：提示密码不对、清空输入、不跳转、不崩',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('envx_flow_bad_');
    await tester.runAsync(() async {
      final seeded = await openTestDb(dir, '111111');
      await seeded.notebooks.create(name: '保密本子', color: 'blush');
      await seeded.close();
    });

    EnvxDatabase? unlocked;
    var calls = 0;
    addTearDown(() async {
      await unlocked?.close();
      dir.deleteSync(recursive: true);
    });

    await tester.pumpWidget(await _shell(dir, (db) {
      unlocked = db;
      calls++;
    }));
    await tester.pump();

    await _enterPin(tester, '222222');
    await _settleFlow(tester, () => calls > 0);

    // 界面出现错误提示
    expect(find.text('密码不对'), findsOneWidget);

    // 不回调、不跳转，仍停在开锁页
    expect(calls, 0);
    expect(unlocked, isNull);
    expect(find.text('信封日记'), findsOneWidget);

    // 输入被清空：六个圆点没有 mint700 填充的已填点
    final filled = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == EnvxColors.mint700)
        .length;
    expect(filled, 0, reason: '错误密码后六位输入应被全部清空');
  });
}
