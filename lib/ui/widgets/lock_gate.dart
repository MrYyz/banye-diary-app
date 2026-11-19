import 'package:material_ui/material_ui.dart';

import '../../core/lock_runtime.dart';
import '../../core/settings.dart';
import '../theme.dart';
import 'relock_layer.dart';

/// App 级锁门：挂在 `MaterialApp.builder` 上，切到后台时把**整个 App**
/// 盖成锁屏，而不是只盖首页。
///
/// 为什么必须放在这一层：锁原来挂在首页内部，用户从首页点进笔记列表、
/// 编辑器、隐藏区之后，这些页面是 push 上去的独立路由，盖在首页之上。
/// 切出去再回来，锁屏在首页里头，上面还压着内容页 —— 等于没锁。
///
/// 三条判定与 M6 的首页锁一致：未解锁（[LockRuntime.armed] 为假）不锁、
/// 设置里关掉不锁、只有 `paused` / `hidden` 才锁（`inactive` 会在下拉通知栏
/// 时频繁触发，锁上会很烦）。
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 相册 / 文件选择器是 App 自己拉起来的外部界面，不算「离开」。
    if (LockRuntime.inExternalUi) return;
    if (!LockRuntime.armed) return;
    if (!SettingsRuntime.value.lockOnBackground) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (!_locked) setState(() => _locked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verify = LockRuntime.verifier;
    if (!_locked || verify == null) return widget.child;

    // 必须是"盖在上面"，不能替换 child：builder 里把 Navigator 换掉会
    // 卸载整棵路由树，解锁后用户会回到一个只有首页的空 App。
    return Stack(
      children: [
        widget.child,
        // 先挡下层（点不到下面的按钮/列表），再叠锁屏本身。
        // 注意不能给整块加 AbsorbPointer —— 那会把锁屏里的数字键一起吃掉。
        if (_locked)
          const Positioned.fill(
            child: ModalBarrier(color: Colors.transparent, dismissible: false),
          ),
        if (_locked)
          Positioned.fill(
            child: Scaffold(
              backgroundColor: EnvxColors.mist,
              body: RelockLayer(
                onSubmit: verify,
                onUnlocked: () => setState(() => _locked = false),
              ),
            ),
          ),
      ],
    );
  }
}
