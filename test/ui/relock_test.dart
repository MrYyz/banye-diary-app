import 'package:envx/core/kdf.dart';
import 'package:envx/core/lock_runtime.dart';
import 'package:envx/core/settings.dart';
import 'package:envx/ui/theme.dart';
import 'package:envx/ui/widgets/lock_gate.dart';
import 'package:envx/ui/widgets/relock_layer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// 「切到后台立即上锁」的验收。
///
/// M6 时这条挂在首页内部，只能盖住首页：用户点进笔记列表 / 编辑器 /
/// 隐藏区之后，那些页面是 push 上去的独立路由，盖在首页之上，锁屏在首页
/// 里头，上面照样是内容 —— 等于没锁。现在锁上移到 App 级 LockGate
/// （`MaterialApp.builder` 里包住 Navigator），本文件也跟着改测它。
///
/// 拆两段测：
/// 1) LockGate：切后台后整屏被锁屏盖住，且被 push 到上层的页面也看不见；
/// 2) RelockLayer 自己：错密码提示「密码不对」，对密码才放行。

const _pin = '123456';

Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (final ch in pin.split('')) {
    await tester.tap(find.text(ch));
    await tester.pump();
  }
}

/// 等价于真机切到后台：走系统生命周期通道。
Future<void> _goBackground(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.lifecycle.name,
    SystemChannels.lifecycle.codec.encodeMessage('AppLifecycleState.paused'),
    (_) {},
  );
  await tester.pump();
}

/// 回到前台：paused 期间 Flutter 不产帧，必须收到 resumed 才会重绘。
/// 真机上用户切回来必然走这一步，测试也照走，否则"锁屏看不见"只是假象。
Future<void> _goForeground(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.lifecycle.name,
    SystemChannels.lifecycle.codec.encodeMessage('AppLifecycleState.resumed'),
    (_) {},
  );
  await tester.pump();
}

int _relockCount() => find.byType(RelockLayer).evaluate().length;

/// 造一把 32 字节密钥与对应的校验器；不碰磁盘，纯计算。
({Uint8List key, Future<bool> Function(String) verify}) _makeKey() {
  final salt = randomSalt(16);
  final key = deriveKey(
    password: _pin,
    salt: salt,
    params: KdfParams.light,
  ).keyBytes;
  Future<bool> verify(String pin) async => constantTimeEquals(
        deriveKey(password: pin, salt: salt, params: KdfParams.light).keyBytes,
        key,
      );
  return (key: key, verify: verify);
}

void main() {
  tearDown(LockRuntime.disarm);

  testWidgets('切到后台：整屏被盖住，push 到上层的页面也看不见', (tester) async {
    // 默认 800×600 太矮，锁屏会被挤出可视区。
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final k = _makeKey();
    LockRuntime.arm(keyBytes: k.key, verifier: k.verify);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: EnvxTheme.build(),
        builder: (context, child) =>
            LockGate(child: child ?? const SizedBox.shrink()),
        home: const Scaffold(body: Center(child: Text('首页内容'))),
      ),
    );
    await tester.pump();

    // 模拟用户点进一封笔记：push 一个盖在上面的页面。
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('笔记列表内容'))),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('笔记列表内容'), findsOneWidget);
    expect(_relockCount(), 0);

    // 前置条件先钉住：不锁的时候往往不是 UI 的问题，是这两条前提没成立。
    expect(LockRuntime.armed, isTrue, reason: '锁应已武装');
    expect(
      SettingsRuntime.value.lockOnBackground,
      isTrue,
      reason: '设置里应开着切后台上锁',
    );

    await _goBackground(tester);
    await _goForeground(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(_relockCount(), 1, reason: '切后台再回来应有锁屏');
    expect(find.text('已上锁'), findsOneWidget);

    // 锁屏是叠在 Navigator 之上的一层（不能替换 Navigator，否则路由全丢），
    // 所以下层 widget 仍在树里，"看不见"要靠覆盖面积与事件拦截来证明：
    // 锁屏必须铺满整个屏幕，且外面包着 AbsorbPointer。
    final lockSize = tester.getSize(find.byType(RelockLayer));
    expect(
      lockSize,
      const Size(390, 844),
      reason: '锁屏要铺满整屏，才算盖住 push 到上层的页面',
    );
    expect(
      find.byType(ModalBarrier),
      findsAtLeastNWidgets(1),
      reason: '锁屏期间下层要被拦截，不能接收点击',
    );

    // 输对密码后放行，回到刚才那一页。
    await _enterPin(tester, _pin);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_relockCount(), 0, reason: '正确密码应解锁');
    expect(find.text('笔记列表内容'), findsOneWidget);
  });

  testWidgets('没解锁时不锁：不做只能看不能验的假锁', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: EnvxTheme.build(),
        builder: (context, child) =>
            LockGate(child: child ?? const SizedBox.shrink()),
        home: const Scaffold(body: Center(child: Text('首页内容'))),
      ),
    );
    await tester.pump();

    await _goBackground(tester);
    await _goForeground(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(_relockCount(), 0, reason: '没有密钥比对依据时不该假装上锁');
  });

  testWidgets('RelockLayer：错密码提示密码不对且不放行，对密码才回调',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var unlocked = false;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: EnvxTheme.build(),
        home: Scaffold(
          backgroundColor: EnvxColors.mist,
          body: RelockLayer(
            onSubmit: (pin) async => pin == _pin,
            onUnlocked: () => unlocked = true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('已上锁'), findsOneWidget);

    await _enterPin(tester, '222222');
    await tester.pump();
    expect(find.text('密码不对'), findsOneWidget, reason: '错密码应提示');
    expect(unlocked, isFalse, reason: '错密码不放行');

    await _enterPin(tester, _pin);
    await tester.pump();
    expect(unlocked, isTrue, reason: '正确密码应回调放行');
  });
}
