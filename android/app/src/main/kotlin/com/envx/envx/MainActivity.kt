package com.envx.envx

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 只有一个职责：让 Dart 侧能把 FLAG_SECURE 开起来。
 *
 * 开了之后系统层面就不许截屏 / 录屏 / 任务切换预览 —— 应用内部的遮挡
 * 管不住系统截屏，这一项必须落在 window 上。
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "envx/window"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> {
                    val on = call.arguments as? Boolean ?: true
                    if (on) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
