import 'dart:io';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../core/kdf.dart';
import '../core/lock_runtime.dart';
import '../data/database.dart';
import '../data/device_key_store.dart';
import '../data/salt_store.dart';
import 'screens/home_page.dart';
import 'unlock_page.dart';

/// 启动决策页。
///
/// 用户明确反馈过：没设过密码却被拦在密码页上是不可接受的。所以这里分两种情况：
/// - **没有盐 sidecar**（从未设过访问密码）→ 用设备随机密钥开库，直接进首页。
/// - **有盐**（老版本建的库，密钥由密码派生）→ 走一次解锁页拿到旧密钥，
///   就地 `rekey` 成设备密钥并删掉盐，之后同样不再要密码。数据一行不动。
///
/// 想让 App 打开时要密码，是设置页里的可选项（访问密码），不在这里强加。
class BootstrapPage extends StatefulWidget {
  const BootstrapPage({super.key, this.dirProvider, this.kdfParams});

  final Future<Directory> Function()? dirProvider;
  final KdfParams? kdfParams;

  @override
  State<BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends State<BootstrapPage> {
  static const _mistBg = Color(0xFFEDF6F3);

  bool _ready = false;
  bool _migrating = false;
  String? _error;
  Directory? _dir;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<Directory> _resolveDir() async {
    if (widget.dirProvider != null) return widget.dirProvider!();
    return getApplicationSupportDirectory();
  }

  Future<void> _boot() async {
    try {
      final dir = await _resolveDir();
      _dir = dir;

      final hasPin = await SaltStore(dir: dir).read('app.db') != null;
      if (hasPin) {
        if (!mounted) return;
        setState(() {
          _ready = true;
          _migrating = true;
        });
        return;
      }

      final key = await DeviceKeyStore(dir: dir).loadOrCreate();
      final db = await openEnvxDatabase(dir: dir, key32: key);

      // 免密模式：只有密钥、没有校验器，所以 LockRuntime.armed 为假，
      // 「切后台立即上锁」不会生效 —— 那需要一个能验的密码做前提。
      LockRuntime.keyBytes = key;

      if (!mounted) {
        await db.close();
        return;
      }
      _enterHome(db, key);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _error = '打开失败：$e';
      });
    }
  }

  void _enterHome(EnvxDatabase db, Uint8List key) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HomePage(
          db: db,
          dirProvider: widget.dirProvider,
          kdfParams: widget.kdfParams,
          keyBytes: key,
        ),
      ),
    );
  }

  /// 老库迁移：旧密码已验证通过，拿到旧密钥后换成设备密钥。
  Future<void> _migrate(EnvxDatabase oldDb, Uint8List oldKey) async {
    final dir = _dir;
    if (dir == null) return;

    final deviceKey = await DeviceKeyStore(dir: dir).loadOrCreate();
    EnvxDatabase? fresh;

    try {
      await oldDb.close();
      await rekeyEnvxDatabase(
        dir: dir,
        oldKey32: oldKey,
        newKey32: deviceKey,
      );
      // rekey 成功才删盐：删早了就再也派生不出旧密钥。
      await SaltStore(dir: dir).reset('app.db');
      fresh = await openEnvxDatabase(dir: dir, key32: deviceKey);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _migrating = false;
        _error = '转换失败，请重试。你的笔记没有丢。';
      });
      return;
    }

    LockRuntime.disarm();
    if (!mounted) {
      await fresh.close();
      return;
    }
    _enterHome(fresh, deviceKey);
  }

  /// 不输旧密码时的逃生门。
  ///
  /// 旧库的钥匙是从密码派生的 —— 没有密码就真的打不开，这不是偷懒，是密钥学的硬约束。
  /// 所以这里不假装「跳过验证」，而是把旧库连同盐一起改名封存（`app.db.legacy-<时间戳>`），
  /// 再用本机随机钥匙开一个空库。一个字节都不删，想起密码以后还能找回。
  Future<void> _skipLegacy() async {
    final dir = _dir;
    if (dir == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBFDFC),
        title: const Text('不输密码，直接开始？'),
        content: const Text(
          '旧内容打不开，是因为它的钥匙由你当年那个密码派生，这个绕不过去。\n\n'
          '继续的话：旧库会被改名封存（不删除），App 用本机钥匙开一个空库。'
          '以后想起密码，文件还在原目录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('算了，我输密码'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('封存并重新开始'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final dbFile = File('${dir.path}/app.db');
    final saltFile = File('${dir.path}/app.db.salt');
    try {
      if (await dbFile.exists()) {
        await dbFile.rename('${dbFile.path}.legacy-$stamp');
      }
      if (await saltFile.exists()) {
        await saltFile.rename('${saltFile.path}.legacy-$stamp');
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _migrating = false;
        _error = '旧库封存失败：$e';
      });
      return;
    }

    try {
      final key = await DeviceKeyStore(dir: dir).loadOrCreate();
      final db = await openEnvxDatabase(dir: dir, key32: key);
      LockRuntime.keyBytes = key;
      if (!mounted) {
        await db.close();
        return;
      }
      _enterHome(db, key);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _migrating = false;
        _error = '打开新库失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_migrating) {
      return UnlockPage(
        dirProvider: widget.dirProvider,
        kdfParams: widget.kdfParams,
        hint: '输一次你之前设的 6 位密码，之后打开就不用再输了',
        // 不在这里 push 首页：UnlockPage 只负责把库打开并交出来。
        onUnlocked: (_) {},
        onKey: _migrate,
        onSkip: _skipLegacy,
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _mistBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          ),
        ),
      );
    }

    if (!_ready) {
      return const Scaffold(
        backgroundColor: _mistBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return const SizedBox.shrink();
  }
}
