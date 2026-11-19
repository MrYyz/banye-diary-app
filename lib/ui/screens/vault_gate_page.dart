import 'dart:io';

import 'package:material_ui/material_ui.dart';

import 'package:envx/core/kdf.dart';
import 'package:envx/core/kdf_isolate.dart';
import 'package:envx/data/database.dart';
import 'package:envx/data/salt_store.dart';
import 'package:envx/ui/screens/vault_home_page.dart';
import 'package:envx/ui/widgets/pin_keypad.dart';

/// 隐藏库文件名。与 app.db 完全独立：独立文件、独立盐、独立密码。
const String kVaultFileName = 'vault.db';

const Color _vaultBg = Color(0xFF1E2E29);
const Color _vaultKey = Color(0xFF2A3D37);
const Color _vaultKeyEdge = Color(0xFF3A514A);
const Color _vaultInk = Color(0xFFFBFDFC);
const Color _vaultDim = Color(0xFF8BA49C);

enum _Phase { checking, unlock, setFirst, confirmFirst }

/// 隐藏区密码门。
///
/// 首次进入引导设第二密码（两次输入），之后每次进入都要输。
/// 密码与主密码无关：不同的库文件、不同的盐、不同的 Argon2 派生结果，
/// 主密码开不了它，忘了也只能清掉（没有找回）。
class VaultGatePage extends StatefulWidget {
  const VaultGatePage({
    super.key,
    required this.dir,
    this.kdfParams,
    this.returnDb = false,
    this.mainDb,
  });

  final Directory dir;
  final KdfParams? kdfParams;

  /// true 时验证通过后不跳转，而是把打开的库 `pop` 回调用方。
  /// 主区「移到隐藏区」需要拿到这个句柄去写数据，用完由调用方 close。
  final bool returnDb;

  /// 主区库句柄。隐藏区里「移回我的笔记本」要写到主库，所以一路传下去。
  final EnvxDatabase? mainDb;

  @override
  State<VaultGatePage> createState() => _VaultGatePageState();
}

class _VaultGatePageState extends State<VaultGatePage> {
  static const _pinLength = 6;

  _Phase _phase = _Phase.checking;
  String _pin = '';
  String? _pendingPin;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _detect();
  }

  Future<void> _detect() async {
    final exists = await File('${widget.dir.path}/$kVaultFileName').exists();
    if (!mounted) return;
    setState(() {
      _phase = exists ? _Phase.unlock : _Phase.setFirst;
      _status = exists ? '输入隐藏密码' : '先给隐藏区设一个密码';
    });
  }

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
    switch (_phase) {
      case _Phase.setFirst:
        setState(() {
          _pendingPin = _pin;
          _pin = '';
          _phase = _Phase.confirmFirst;
          _status = '再输一次确认';
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
        await _open(_pin);
        return;
      case _Phase.unlock:
        await _open(_pin);
        return;
      case _Phase.checking:
        return;
    }
  }

  Future<void> _open(String pin) async {
    setState(() {
      _busy = true;
      _status = '正在打开…';
    });

    try {
      final salt = await SaltStore(dir: widget.dir).loadOrCreate(kVaultFileName);
      final key = await deriveKeyInBackground(
        password: pin,
        salt: salt,
        params: widget.kdfParams ?? KdfParams.plan,
      );
      final db = await openEnvxDatabase(
        dir: widget.dir,
        key32: key,
        fileName: kVaultFileName,
      );

      if (!mounted) return;
      if (widget.returnDb) {
        // 交给调用方，由它负责 close —— 这里不能 push 页面。
        Navigator.of(context).pop(db);
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => VaultHomePage(db: db, mainDb: widget.mainDb),
        ),
      );
    } on WrongKeyException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pin = '';
        _status = '密码不对';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pin = '';
        _status = '打开失败，请重试';
      });
    }
  }

  String get _title {
    switch (_phase) {
      case _Phase.setFirst:
      case _Phase.confirmFirst:
        return '给隐藏区\n设一个密码';
      case _Phase.unlock:
        return '隐藏区';
      case _Phase.checking:
        return '隐藏区';
    }
  }

  String get _subtitle {
    switch (_phase) {
      case _Phase.setFirst:
        return '和开锁密码完全独立，忘了我也找不回来';
      case _Phase.confirmFirst:
        return '刚才那个，再输一次';
      case _Phase.unlock:
        return '这里的东西，不在主密码下面';
      case _Phase.checking:
        return '正在检查…';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _vaultBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    GestureDetector(
                      key: const ValueKey('vault-back'),
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Center(
                          child: CustomPaint(
                            size: Size(10, 18),
                            painter: _VaultChevron(),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      '隐藏区',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.6,
                        color: _vaultDim,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF243630),
                  border: Border.all(color: _vaultKeyEdge, width: 1),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.lock_outline,
                  size: 34,
                  color: Color(0xFF3AAFA0),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  height: 1.45,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                  color: _vaultInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  letterSpacing: 0.6,
                  color: _vaultDim,
                ),
              ),
              const SizedBox(height: 26),
              PinDots(
                filled: _pin.length,
                activeColor: const Color(0xFF3AAFA0),
                idleBorder: const Color(0xFF4E6760),
              ),
              const Spacer(flex: 1),
              PinKeypad(
                enabled: !_busy && _phase != _Phase.checking,
                onDigit: _tap,
                onBackspace: _backspace,
                leadingIcon: Icons.visibility_off_outlined,
                onLeading: () => setState(() {
                  _status = '隐藏区不支持指纹，只能输密码';
                }),
                keyColor: _vaultKey,
                keyBorder: _vaultKeyEdge,
                digitColor: _vaultInk,
                backspaceColor: _vaultDim,
                leadingColor: const Color(0xFF3AAFA0),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  _busy ? '正在打开…' : _status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: _status == '密码不对' || _status.isEmpty
                        ? FontWeight.w400
                        : FontWeight.w600,
                    letterSpacing: 0.6,
                    color: _status == '密码不对'
                        ? const Color(0xFFF2B8C0)
                        : const Color(0xFF3AAFA0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaultChevron extends CustomPainter {
  const _VaultChevron();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _vaultInk
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * 0.62, 0)
      ..lineTo(size.width * 0.38, size.height / 2)
      ..lineTo(size.width * 0.62, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _VaultChevron oldDelegate) => false;
}
