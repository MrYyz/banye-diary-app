import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// 6 位数字键盘。开锁页与隐藏区密码页共用同一份尺寸与间距
/// （66×66 键、列距 20、行距 13 —— M1 实测调过，不要各自改）。
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
    this.leadingIcon = Icons.fingerprint_outlined,
    this.onLeading,
    this.keyColor = EnvxColors.paper,
    this.keyBorder = EnvxColors.mint100,
    this.digitColor = EnvxColors.ink,
    this.backspaceColor = EnvxColors.ink2,
    this.leadingColor = EnvxColors.mint700,
  });

  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final bool enabled;
  final IconData leadingIcon;
  final VoidCallback? onLeading;

  /// 隐藏区用深底浅键，所以颜色可换。
  final Color keyColor;
  final Color keyBorder;
  final Color digitColor;
  final Color backspaceColor;
  final Color leadingColor;

  static const double _colGap = 20;
  static const double _rowGap = 13;

  Widget _row(List<Widget> keys) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) const SizedBox(width: _colGap),
            keys[i],
          ],
        ],
      );

  Widget _digit(String d) => PinKey(
        label: d,
        onTap: enabled ? () => onDigit(d) : null,
        color: keyColor,
        border: keyBorder,
        textColor: digitColor,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row([_digit('1'), _digit('2'), _digit('3')]),
        const SizedBox(height: _rowGap),
        _row([_digit('4'), _digit('5'), _digit('6')]),
        const SizedBox(height: _rowGap),
        _row([_digit('7'), _digit('8'), _digit('9')]),
        const SizedBox(height: _rowGap),
        _row([
          PinKey(
            ghost: true,
            onTap: enabled ? onLeading : null,
            child: Icon(leadingIcon, size: 26, color: leadingColor),
          ),
          _digit('0'),
          PinKey(
            ghost: true,
            onTap: enabled ? onBackspace : null,
            child: Icon(Icons.backspace_outlined, size: 22, color: backspaceColor),
          ),
        ]),
      ],
    );
  }
}

class PinKey extends StatelessWidget {
  const PinKey({
    super.key,
    required this.onTap,
    this.label = '',
    this.child,
    this.ghost = false,
    this.color = EnvxColors.paper,
    this.border = EnvxColors.mint100,
    this.textColor = EnvxColors.ink,
  });

  final String label;
  final Widget? child;
  final VoidCallback? onTap;
  final bool ghost;
  final Color color;
  final Color border;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Container(
        width: 66,
        height: 66,
        decoration: ghost
            ? null
            : BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: border,
                    offset: const Offset(0, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
        alignment: Alignment.center,
        child: child ??
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
      ),
    );
  }
}

/// 简单按压反馈，不做花哨动画。
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _down = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: _down ? 0.94 : 1,
        child: widget.child,
      ),
    );
  }
}

/// 6 个密码圆点。颜色可换，隐藏区用浅色。
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.filled,
    this.length = 6,
    this.activeColor = EnvxColors.mint700,
    this.idleBorder = EnvxColors.ink3,
  });

  final int filled;
  final int length;
  final Color activeColor;
  final Color idleBorder;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final on = i < filled;
        return Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 9.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? activeColor : Colors.transparent,
            border: Border.all(color: on ? activeColor : idleBorder, width: 1.5),
          ),
        );
      }),
    );
  }
}
