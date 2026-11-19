import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:envx/core/settings.dart';
import 'package:envx/core/window_secure.dart';

/// 截屏保护这条线的测试只做一件事：确认它真的把「开/关」发到了平台侧，
/// 且在该跳过的环境里不炸。
///
/// 效果本身（截屏是否黑屏）只能在真机上肉眼验，代码层测不到，
/// 所以这里不假装测到了 —— 只固定住调用契约。
void main() {
  const channel = MethodChannel('envx/window');

  late List<MethodCall> calls;

  void mockPlatform(TestWidgetsFlutterBinding binding) {
    calls = <MethodCall>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('打开时向平台发 setSecure(true)', () async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    mockPlatform(binding);
    await applyScreenshotProtect(true, android: true);
    expect(calls.length, 1);
    expect(calls.single.method, 'setSecure');
    expect(calls.single.arguments, true);
  });

  test('关闭时向平台发 setSecure(false)', () async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    mockPlatform(binding);
    await applyScreenshotProtect(false, android: true);
    expect(calls.single.method, 'setSecure');
    expect(calls.single.arguments, false);
  });

  test('按设置同步：取的是 screenshotProtect 字段', () async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    mockPlatform(binding);
    await applyScreenshotProtectFrom(
      const AppSettings(screenshotProtect: false),
    );
    // host 平台不走通道，所以这里断言的是"不发"而不是"发 null"
    expect(calls, isEmpty);
  });

  test('非安卓平台静默跳过，不发任何调用', () async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    mockPlatform(binding);
    await applyScreenshotProtect(true, android: false);
    expect(calls, isEmpty);
  });

  test('平台侧没接时抛 MissingPluginException 也被吞掉', () async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException('no handler');
    });
    // 不抛出去：设置页不能因为一个开关就崩
    await applyScreenshotProtect(true, android: true);
  });
}
