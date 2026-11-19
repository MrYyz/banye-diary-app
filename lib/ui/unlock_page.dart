import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:material_ui/material_ui.dart';
import 'package:envx/core/lock_runtime.dart';
import 'package:path_provider/path_provider.dart';

import '../core/kdf.dart';
import '../data/database.dart';
import '../data/salt_store.dart';
import 'screens/home_page.dart';
import 'theme.dart';

/// 丢给后台 isolate 的派生参数包。web 上没有真正 isolate，compute 会退化成同步执行。
class _KdfInput {
  const _KdfInput({
    required this.password,
    required this.salt,
    required this.params,
  });

  final String password;
  final Uint8List salt;
  final KdfParams params;
}

Uint8List _kdfDerive(_KdfInput input) => deriveKey(
      password: input.password,
      salt: input.salt,
      params: input.params,
    ).keyBytes;

/// 开锁页的四种状态。
///
/// `setFirst` / `confirmFirst` 只在「库里还没有盐」时出现 —— 那时输入的不是
/// 「密码」，而是在**设置**密码。所以必须两步确认：这个密码没有找回入口，
/// 手滑输错就等于把库锁死了。
enum _Phase { checking, setFirst, confirmFirst, unlock }

/// 开锁页：6 位数字密码 → 读/建盐 → Argon2id 派生 → 打开加密库。
///
/// 目录与 KDF 档位都可注入，方便 widget 测试用临时目录 + light 档跑全流程。
class UnlockPage extends StatefulWidget {
  const UnlockPage({
    super.key,
    this.dirProvider,
    this.kdfParams,
    this.onUnlocked,
    this.hint,
    this.onKey,
    this.onSkip,
  });

  /// 返回应用私有目录；默认走 [getApplicationSupportDirectory]。
  final Future<Directory> Function()? dirProvider;

  /// 派生参数；默认 [KdfParams.plan]。测试可传 [KdfParams.light]。
  final KdfParams? kdfParams;

  /// 开锁成功回调；不传则默认推入 [HomePage]。
  final void Function(EnvxDatabase db)? onUnlocked;

  /// 副标题文案；老库迁移时用来告诉用户「只输这一次」。
  final String? hint;

  /// 拿到原始密钥的回调。传了它就不再推首页，由调用方接管 ——
  /// 老库迁移需要在验证旧密码成功后用这把密钥去 rekey。
  final void Function(EnvxDatabase db, Uint8List key)? onKey;

  /// 旧密码库迁移时可以给一个「我就是没有/不想要这个密码」的出口。
  /// null 表示不提供（正常解锁页不显示）。
  final VoidCallback? onSkip;

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> {
  static const _pinLength = 6;

  _Phase _phase = _Phase.checking;
  String _pin = '';
  String? _pendingPin;
  bool _busy = false;
  String _status = '';
  Directory? _dir;

  @override
  void initState() {
    super.initState();
    _detect();
  }

  Future<Directory> _resolveDir() async {
    if (widget.dirProvider != null) return widget.dirProvider!();
    return getApplicationSupportDirectory();
  }

  /// 有盐 = 已经设过密码；没有盐 = 第一次用，现在进入「设置密码」流程。
  Future<void> _detect() async {
    try {
      final dir = await _resolveDir();
      final salt = await SaltStore(dir: dir).read('app.db');
      if (!mounted) return;
      setState(() {
        _dir = dir;
        _phase = salt == null ? _Phase.setFirst : _Phase.unlock;
        _status = salt == null ? '输满 6 位就生效' : '输入密码解锁';
      });
      // 检测期间用户可能已经输满 6 位（真实 IO 有时比手快），
      // 那时 _submit 还在 checking 分支空转，这里补一次，不丢输入。
      if (_pin.length == _pinLength) _submit();
    } catch (_) {
      // 目录读不出来不该卡在 checking：按日常解锁态处理，让用户能继续操作。
      if (!mounted) return;
      setState(() {
        _phase = _Phase.unlock;
        _status = '输入密码解锁';
      });
    }
  }

  void _tap(String digit) {
    if (_busy) return;
    if (_pin.length >= _pinLength) return;
    setState(() => _pin += digit);
    if (_pin.length == _pinLength) {
      _submit();
    }
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    switch (_phase) {
      case _Phase.setFirst:
        setState(() {
          _pendingPin = _pin;
          _pin = '';
          _phase = _Phase.confirmFirst;
          _status = '再输一次，确认是这个';
        });
        return;
      case _Phase.confirmFirst:
        if (_pendingPin != _pin) {
          setState(() {
            _pin = '';
            _pendingPin = null;
            _phase = _Phase.setFirst;
            _status = '两次不一致，重新设置';
          });
          return;
        }
        await _open(_pin, register: true);
        return;
      case _Phase.unlock:
        await _open(_pin);
        return;
      case _Phase.checking:
        return;
    }
  }

  /// [register] 为 true 时现生成盐并落盘 —— 只有两次输入一致才会走到这里，
  /// 中途退出不会留下半截注册。
  Future<void> _open(String pin, {bool register = false}) async {
    setState(() {
      _busy = true;
      _status = '正在打开…';
    });

    try {
      final dir = _dir ?? await _resolveDir();
      final Uint8List salt;
      if (register) {
        salt = randomSalt(16);
        await SaltStore(dir: dir).write('app.db', salt);
      } else {
        final existing = await SaltStore(dir: dir).read('app.db');
        if (existing == null) throw WrongKeyException('缺少盐文件');
        salt = existing;
      }

      final key = await compute(
        _kdfDerive,
        _KdfInput(
          password: pin,
          salt: salt,
          params: widget.kdfParams ?? KdfParams.plan,
        ),
      );
      final db = await openEnvxDatabase(dir: dir, key32: key);

      // 武装全局锁：之后无论停在哪一页，切后台都会被 LockGate 盖住。
      LockRuntime.arm(
        keyBytes: key,
        verifier: (pin) async {
          final probe = deriveKey(
            password: pin,
            salt: salt,
            params: widget.kdfParams ?? KdfParams.plan,
          ).keyBytes;
          return constantTimeEquals(probe, key);
        },
      );

      if (!mounted) return;
      if (widget.onKey != null) {
        widget.onKey!(db, key);
        return;
      }
      if (widget.onUnlocked != null) {
        widget.onUnlocked!(db);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => HomePage(
              db: db,
              dirProvider: widget.dirProvider,
              kdfParams: widget.kdfParams,
              keyBytes: key,
              justRegistered: register,
            ),
          ),
        );
      }
    } on WrongKeyException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pin = '';
        _phase = _Phase.unlock;
        _status = '密码不对';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pin = '';
        _status = register ? '设置失败，请重试' : '打开失败，请重试';
      });
    }
  }

  String get _subtitle {
    switch (_phase) {
      case _Phase.setFirst:
        return '第一次用，先给自己设一个 6 位密码';
      case _Phase.confirmFirst:
        return '再输一次，确认是这个密码';
      case _Phase.unlock:
      case _Phase.checking:
        return widget.hint ?? '你的心事，只留给自己';
    }
  }

  /// 状态行：忙时统一「正在打开…」，与下面的按钮状态一致。
  String get _statusText {
    if (_busy) return '正在打开…';
    if (_phase == _Phase.checking) return '正在检查…';
    return _status;
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusText;
    final isError = status == '密码不对' ||
        status == '两次不一致，重新设置' ||
        status.endsWith('失败，请重试');
    final isHint = _phase == _Phase.setFirst && status == '输满 6 位就生效';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Transform.rotate(
                angle: -3 * 3.14159265 / 180,
                child: SizedBox(
                  width: 168,
                  height: 120,
                  child: CustomPaint(painter: _EnvelopePainter()),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '信封日记',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.09,
                  color: EnvxColors.ink,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.05,
                  color: EnvxColors.ink3,
                ),
              ),
              if (widget.onSkip != null) ...[
                const SizedBox(height: 2),
                TextButton(
                  onPressed: widget.onSkip,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    '我没有这个密码，重新开始（旧内容会封存）',
                    style: TextStyle(
                      fontSize: 11.5,
                      letterSpacing: 0.02,
                      color: EnvxColors.ink3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ] else
                const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (i) {
                  final filled = i < _pin.length;
                  return Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 9.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? EnvxColors.mint700 : Colors.transparent,
                      border: Border.all(
                        color: filled
                            ? EnvxColors.mint700
                            : EnvxColors.ink3,
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
              const Spacer(flex: 1),
              _buildKeypad(),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isHint ? FontWeight.w400 : FontWeight.w700,
                    letterSpacing: 0.06,
                    color: isError || isHint
                        ? EnvxColors.ink2
                        : EnvxColors.mint700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    const colGap = 20.0;
    const rowGap = 13.0;
    final enabled = !_busy;

    Widget digitRow(List<String> keys) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < keys.length; i++) ...[
              if (i > 0) const SizedBox(width: colGap),
              _KeypadKey(
                label: keys[i],
                onTap: enabled ? () => _tap(keys[i]) : null,
              ),
            ],
          ],
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        digitRow(const ['1', '2', '3']),
        const SizedBox(height: rowGap),
        digitRow(const ['4', '5', '6']),
        const SizedBox(height: rowGap),
        digitRow(const ['7', '8', '9']),
        const SizedBox(height: rowGap),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _KeypadKey(
              ghost: true,
              onTap: null,
              child: const Icon(
                Icons.fingerprint_outlined,
                size: 26,
                color: EnvxColors.mint100,
              ),
            ),
            const SizedBox(width: colGap),
            _KeypadKey(
              label: '0',
              onTap: enabled ? () => _tap('0') : null,
            ),
            const SizedBox(width: colGap),
            _KeypadKey(
              ghost: true,
              onTap: enabled ? _backspace : null,
              child: const Icon(
                Icons.backspace_outlined,
                size: 22,
                color: EnvxColors.ink2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadKey extends StatelessWidget {
  const _KeypadKey({
    required this.onTap,
    this.label = '',
    this.child,
    this.ghost = false,
  });

  final String label;
  final Widget? child;
  final VoidCallback? onTap;
  final bool ghost;

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
                color: EnvxColors.paper,
                shape: BoxShape.circle,
                border: Border.all(color: EnvxColors.mint100, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: EnvxColors.mint100,
                    offset: Offset(0, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
        alignment: Alignment.center,
        child: child ??
            Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: EnvxColors.ink,
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

class _EnvelopePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, w - 8, h - 8),
      const Radius.circular(9),
    );
    canvas.drawRRect(body, Paint()..color = EnvxColors.paper);
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = EnvxColors.mint100,
    );

    final flap = Path()
      ..moveTo(4, 4)
      ..lineTo(w / 2, h / 2)
      ..lineTo(w - 4, 4);
    canvas.drawPath(
      flap,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = EnvxColors.mint100,
    );

    final seal = Offset(w / 2, h / 2);
    canvas.drawCircle(seal, 10.5, Paint()..color = EnvxColors.mint500);
    canvas.drawLine(
      seal.translate(-5, 0),
      seal.translate(5, 0),
      Paint()
        ..color = EnvxColors.paper
        ..strokeWidth = 1.8,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w / 2 - 32, h - 24, 64, 2),
        const Radius.circular(1),
      ),
      Paint()..color = EnvxColors.mint100,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
