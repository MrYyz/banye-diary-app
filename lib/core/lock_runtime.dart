import 'dart:typed_data';

/// 全局锁的运行时状态。
///
/// 开锁成功后由 [UnlockPage] 写入，供 [MaterialApp.builder] 外面的
/// [LockGate] 在切后台时遮挡整个 App —— 不管当前停在哪一页
/// （首页、笔记列表、编辑器、隐藏区），都一起被盖住。
///
/// 之前锁只挂在首页内部，push 出去的页面盖在它上面，
/// 切回来照样能看见内容，这是真漏洞。
class LockRuntime {
  const LockRuntime._();

  /// 当前会话的数据密钥；为 null 表示还没解锁，不锁。
  static Uint8List? keyBytes;

  /// 校验开锁密码；由 UnlockPage 用同一把盐与 KDF 档位构造。
  static Future<bool> Function(String pin)? verifier;

  static bool get armed => keyBytes != null && verifier != null;

  static void arm({
    required Uint8List keyBytes,
    required Future<bool> Function(String pin) verifier,
  }) {
    LockRuntime.keyBytes = keyBytes;
    LockRuntime.verifier = verifier;
  }

  /// 退出登录 / 关库时清掉，避免拿旧密钥比对。
  static void disarm() {
    keyBytes = null;
    verifier = null;
  }

  /// 当前是否有 App 自己拉起的外部界面（相册、文件选择器…）。
  ///
  /// 这些 Activity 会让 App 短暂进入 paused。若照常判定，用户选完图回来只会
  /// 看到「已上锁」，图也没插进正文 —— 这不是安全，是误伤。调用方在拉起前后
  /// 成对调用 [beginExternalUi] / [endExternalUi] 把这段时间豁免掉。
  static int _externalUi = 0;

  static bool get inExternalUi => _externalUi > 0;

  static void beginExternalUi() => _externalUi++;

  static void endExternalUi() {
    if (_externalUi > 0) _externalUi--;
  }
}
