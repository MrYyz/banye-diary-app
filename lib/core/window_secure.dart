import 'dart:io';

import 'package:flutter/services.dart';

import 'settings.dart';

const MethodChannel _channel = MethodChannel('envx/window');

/// 安卓侧 FLAG_SECURE 开关。
///
/// 打开后：截屏得到黑屏、录屏同样是黑屏、任务切换时的预览图也看不见。
/// 这是「不让有心人看到」这条诉求里唯一必须落到系统层的一项 ——
/// 应用内部再怎么遮挡，系统截屏也不受控件控制。
///
/// 非安卓平台一律静默跳过：桌面端和（未来的）iOS 走各自的实现，
/// 这里返回而不是抛错，免得设置页因为一个不支持的开关而崩。
///
/// [android] 只给测试用：host 平台的 [Platform.isAndroid] 恒为 false，
/// 不给入口就没法验证真正发出去的方法名和参数。
Future<void> applyScreenshotProtect(bool on, {bool? android}) async {
  final isAndroid = android ?? Platform.isAndroid;
  if (!isAndroid) return;
  try {
    await _channel.invokeMethod<void>('setSecure', on);
  } on MissingPluginException {
    // 平台侧没接（例如在没有 MainActivity 的测试壳里）：静默跳过。
    // 这个开关的效果本来就只能在真机上看见，测试环境拿不到不算失败。
  }
}

/// 按当前设置同步一次。设置页载入、开关变化、开锁进入主区时都调它，
/// 保证任何一条进入路径都不会漏掉 FLAG_SECURE。
Future<void> applyScreenshotProtectFrom(AppSettings s) =>
    applyScreenshotProtect(s.screenshotProtect);
