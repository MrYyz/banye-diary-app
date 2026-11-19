import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'pin_keypad.dart';

/// 切回前台时的遮挡层：整页盖住主区，输对开锁密码才放行。
///
/// 它只把界面挡住，不关数据库、不清内存里的密钥 —— 挡的是「切出去再回来
/// 被人顺手翻到内容」，不是物理接触下的取证。真要防后者得靠系统级
/// FLAG_SECURE + 关库重开，那是后面的事。
class RelockLayer extends StatefulWidget {
  const RelockLayer({
    super.key,
    required this.onSubmit,
    required this.onUnlocked,
  });

  /// 返回 true 表示密码正确。
  final Future<bool> Function(String pin) onSubmit;

  final VoidCallback onUnlocked;

  @override
  State<RelockLayer> createState() => _RelockLayerState();
}

class _RelockLayerState extends State<RelockLayer> {
  static const _pinLength = 6;

  String _pin = '';
  bool _busy = false;
  String _status = '输入开锁密码继续';

  void _tap(String digit) {
    if (_busy || _pin.length >= _pinLength) return;
    setState(() => _pin += digit);
    if (_pin.length == _pinLength) _submit();
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _status = '正在核对…';
    });

    final ok = await widget.onSubmit(_pin);

    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _busy = false;
      _pin = '';
      _status = '密码不对';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            const Spacer(flex: 3),
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                color: EnvxColors.mint100,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.lock_outline,
                size: 28,
                color: EnvxColors.mint700,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '已上锁',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.07,
                color: EnvxColors.ink,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _status,
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.05,
                color: _status == '密码不对'
                    ? EnvxColors.ink2
                    : EnvxColors.ink3,
              ),
            ),
            const SizedBox(height: 22),
            PinDots(filled: _pin.length),
            const Spacer(flex: 1),
            PinKeypad(
              onDigit: _tap,
              onBackspace: _backspace,
              enabled: !_busy,
              leadingIcon: Icons.lock_outline,
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
