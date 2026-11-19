import 'dart:io';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import 'package:envx/core/kdf.dart';
import 'package:envx/core/kdf_isolate.dart';
import 'package:envx/data/database.dart';
import 'package:envx/data/salt_store.dart';
import 'package:envx/ui/screens/vault_gate_page.dart' show kVaultFileName;
import 'package:envx/ui/theme.dart';
import 'package:envx/ui/widgets/pin_keypad.dart';

const Color _bg = EnvxColors.ink;
const Color _key = Color(0xFF2A3D37);
const Color _keyEdge = Color(0xFF3A514A);

enum _Step { verify, newPin, confirm }

/// 改隐藏区密码。
///
/// 三步：验旧密码 → 输新密码 → 再输一次。
/// 技术上不是"换个密码字符串"，而是给 vault.db 换一把数据密钥
/// （`PRAGMA rekey`），再把盐换成新的，旧密码从此派生不出这把密钥。
///
/// 成功返回 true。rekey 失败时原库原样保留、原密码仍然有效，
/// 这是 `rekey_test.dart` 里那条"拿错旧密钥不会破坏原库"保证的。
class ChangeVaultPinPage extends StatefulWidget {
  const ChangeVaultPinPage({
    super.key,
    required this.dir,
    this.kdfParams,
    this.derive,
  });

  final Directory dir;
  final KdfParams? kdfParams;

  /// 测试注入点：widget test 的 fake-async 区里 compute 不返回，
  /// 所以加密派生允许被替换。
  final Future<Uint8List> Function(
    String password,
    Uint8List salt,
    KdfParams params,
  )? derive;

  @override
  State<ChangeVaultPinPage> createState() => _ChangeVaultPinPageState();
}

class _ChangeVaultPinPageState extends State<ChangeVaultPinPage> {
  static const _pinLength = 6;

  _Step _step = _Step.verify;
  String _pin = '';
  String _newPin = '';
  Uint8List? _oldKey;
  bool _busy = false;
  bool _failed = false;
  String _status = '先确认是本人：输现在的隐藏密码';

  KdfParams get _params => widget.kdfParams ?? KdfParams.plan;

  Future<Uint8List> _derive(String password, Uint8List salt) {
    final override = widget.derive;
    if (override != null) return override(password, salt, _params);
    return deriveKeyInBackground(
      password: password,
      salt: salt,
      params: _params,
    );
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
    final entered = _pin;
    switch (_step) {
      case _Step.verify:
        await _verify(entered);
        return;
      case _Step.newPin:
        setState(() {
          _newPin = entered;
          _pin = '';
          _step = _Step.confirm;
          _failed = false;
          _status = '新密码再输一次';
        });
        return;
      case _Step.confirm:
        if (entered != _newPin) {
          setState(() {
            _pin = '';
            _newPin = '';
            _step = _Step.newPin;
            _failed = true;
            _status = '两次不一致，重新输新密码';
          });
          return;
        }
        await _apply(entered);
        return;
    }
  }

  Future<void> _verify(String pin) async {
    setState(() {
      _busy = true;
      _failed = false;
      _status = '正在核对…';
    });
    try {
      final salt = await SaltStore(dir: widget.dir).read(kVaultFileName);
      if (salt == null) {
        throw const FileSystemException('隐藏区还没有设置过密码');
      }
      final key = await _derive(pin, salt);
      // 打开一次做探针：密码不对在这里抛 WrongKeyException。
      final probe = await openEnvxDatabase(
        dir: widget.dir,
        key32: key,
        fileName: kVaultFileName,
      );
      await probe.close();

      if (!mounted) return;
      setState(() {
        _busy = false;
        _oldKey = key;
        _pin = '';
        _step = _Step.newPin;
        _status = '输新密码（6 位数字）';
      });
    } on WrongKeyException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pin = '';
        _failed = true;
        _status = '密码不对';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pin = '';
        _failed = true;
        _status = '核对失败，请重试';
      });
    }
  }

  Future<void> _apply(String pin) async {
    final oldKey = _oldKey;
    if (oldKey == null) {
      setState(() {
        _step = _Step.verify;
        _pin = '';
        _failed = true;
        _status = '状态丢失，请重新来一次';
      });
      return;
    }

    setState(() {
      _busy = true;
      _failed = false;
      _status = '正在换钥匙…';
    });

    Uint8List? newSalt;
    try {
      newSalt = randomSalt(16);
      final newKey = await _derive(pin, newSalt);
      await rekeyEnvxDatabase(
        dir: widget.dir,
        oldKey32: oldKey,
        newKey32: newKey,
        fileName: kVaultFileName,
      );
      // rekey 成功才换盐。顺序反了会让"新盐 + 旧库"这种半截状态打开失败。
      await SaltStore(dir: widget.dir).write(kVaultFileName, newSalt);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pin = '';
        _newPin = '';
        _step = _Step.verify;
        _failed = true;
        _status = '换钥匙失败，原密码仍然有效';
      });
    }
  }

  String get _title {
    switch (_step) {
      case _Step.verify:
        return '改隐藏区密码';
      case _Step.newPin:
        return '设一个新密码';
      case _Step.confirm:
        return '再输一次\n确认是这个';
    }
  }

  String get _subtitle {
    switch (_step) {
      case _Step.verify:
        return '隐藏区的东西不在主密码下面';
      case _Step.newPin:
        return '改完旧密码立刻作废，信件一封不少';
      case _Step.confirm:
        return '确认后旧的隐藏密码就再也打不开了';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
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
                      key: const ValueKey('change-pin-back'),
                      onTap: () => Navigator.of(context).pop(false),
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Center(
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            size: 16,
                            color: EnvxColors.paper,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      '改密码',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.6,
                        color: EnvxColors.ink3,
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
                  border: Border.all(color: _keyEdge, width: 1),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.key_outlined,
                  size: 32,
                  color: EnvxColors.mint500,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                _title,
                key: const ValueKey('change-pin-title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  height: 1.45,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                  color: EnvxColors.paper,
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
                  color: EnvxColors.ink3,
                ),
              ),
              const SizedBox(height: 26),
              PinDots(
                filled: _pin.length,
                activeColor: EnvxColors.mint500,
                idleBorder: EnvxColors.ink2,
              ),
              const Spacer(flex: 1),
              PinKeypad(
                enabled: !_busy,
                onDigit: _tap,
                onBackspace: _backspace,
                leadingIcon: Icons.visibility_off_outlined,
                onLeading: () => setState(() {
                  _status = '这里只能输密码，没有别的入口';
                }),
                keyColor: _key,
                keyBorder: _keyEdge,
                digitColor: EnvxColors.paper,
                backspaceColor: EnvxColors.ink3,
                leadingColor: EnvxColors.mint500,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  _status,
                  key: const ValueKey('change-pin-status'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        _failed ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: 0.6,
                    color: _failed
                        ? const Color(0xFFF2B8C0)
                        : EnvxColors.mint500,
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
