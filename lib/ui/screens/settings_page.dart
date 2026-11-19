import 'package:flutter/services.dart' show SystemNavigator;
import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../core/kdf.dart';
import '../../core/window_secure.dart';
import '../../data/backup_store.dart';
import '../../data/database.dart';
import '../../data/lan_transfer.dart';
import '../../core/settings.dart';
import '../../core/theme_runtime.dart';
import '../theme.dart';
import '../widgets/cover.dart';
import 'change_vault_pin_page.dart';
import 'lan_transfer_page.dart';

/// 07 屏 · 设置。
/// 四组卡片按界面稿顺序：安全 / 数据 / 外观 / 关于。
/// 卡片底色 #FFFFFF、外框 #D8E8E3、圆角 13、行高 13/14、行间分隔线 #F0F7F4。
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.dir,
    this.kdfParams,
    this.db,
  });

  final Directory dir;

  /// 打开局域网互传时需要它；为 null 时那一行保持占位提示。
  final EnvxDatabase? db;
  final KdfParams? kdfParams;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _cardLine = Color(0xFFD8E8E3);
  static const _rowLine = Color(0xFFF0F7F4);
  static const _swOff = Color(0xFFDDE9E5);

  AppSettings _s = const AppSettings();
  bool _hasVault = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = SettingsStore(dir: widget.dir);
    final loaded = await store.load();
    final hasVault = await File('${widget.dir.path}/vault.db').exists();
    if (!mounted) return;
    setState(() {
      _s = loaded;
      _hasVault = hasVault;
    });
    SettingsRuntime.value = loaded;
    ThemeRuntime.apply(loaded.themeKey);
    _refreshBackupCount();
    // 进设置页也同步一次：万一有路径没走到首页的挂点，这里补上。
    await applyScreenshotProtectFrom(loaded);
  }

  Future<void> _set(AppSettings next) async {
    final prevSecure = _s.screenshotProtect;
    setState(() => _s = next);
    SettingsRuntime.value = next;
    ThemeRuntime.apply(next.themeKey);
    await SettingsStore(dir: widget.dir).save(next);
    // 只有这个开关需要立即落到系统层，其余开关都只是存状态。
    if (next.screenshotProtect != prevSecure) {
      await applyScreenshotProtect(next.screenshotProtect);
    }
  }

  String _restoreSub = '选一份备份还原';
  int _backupCount = 0;

  Future<BackupStore> _backupStore() async {
    final photos = Directory(await defaultPhotosDir());
    return BackupStore(supportDir: widget.dir, photosDir: photos);
  }

  Future<void> _refreshBackupCount() async {
    try {
      final list = await (await _backupStore()).list();
      if (!mounted) return;
      setState(() {
        _backupCount = list.length;
        _restoreSub = list.isEmpty ? '还没有备份' : '本机 $_backupCount 份，选一份还原';
      });
    } on Object {
      // 测试环境没有 path_provider 插件，探测备份份数会抛 MissingPluginException；
      // 这里静默跳过，副标保持默认文案。
    }
  }

  Future<void> _doBackup() async {
    BackupStore? store;
    try {
      store = await _backupStore();
      final info = await store.create();
      await _refreshBackupCount();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: EnvxColors.paper,
          title: const Text('备份好了'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${info.sizeText} · ${info.name}'),
              const SizedBox(height: 10),
              SelectableText(
                info.path,
                style: const TextStyle(fontSize: 12, color: EnvxColors.ink3),
              ),
              const SizedBox(height: 10),
              const Text(
                '这个目录里有解密的钥匙，整份拷走能换机恢复；但别发给别人。',
                style: TextStyle(fontSize: 12, color: EnvxColors.ink3),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: EnvxColors.paper,
          title: const Text('备份失败'),
          content: Text('$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('好'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openRestore() async {
    final store = await _backupStore();
    final list = await store.list();
    if (!mounted) return;
    if (list.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: EnvxColors.paper,
          title: const Text('还没有备份'),
          content: const Text('先点「立即备份」存一份，再来这里还原。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('好'),
            ),
          ],
        ),
      );
      return;
    }

    final chosen = await showModalBottomSheet<BackupInfo>(
      context: context,
      backgroundColor: EnvxColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选一份备份',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: EnvxColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              for (final b in list)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    b.label,
                    style: const TextStyle(fontSize: 14, color: EnvxColors.ink),
                  ),
                  subtitle: Text(
                    b.name,
                    style: const TextStyle(
                      fontSize: 11,
                      color: EnvxColors.ink3,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(b),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EnvxColors.paper,
        title: const Text('用这份备份覆盖现在的内容？'),
        content: const Text(
          '现在的数据会先改名封存（不会删），恢复完成后请你重新打开 App。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      // 先松手：drift 连接持着文件句柄，不关掉 rename 会失败。
      await widget.db?.close();
      await store.restore(chosen);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: EnvxColors.paper,
          title: const Text('恢复完成'),
          content: const Text('请重新打开「信封日记」，内容就是这份备份里的了。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                SystemNavigator.pop();
              },
              child: const Text('退出 App'),
            ),
          ],
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: EnvxColors.paper,
          title: const Text('恢复失败'),
          content: Text('$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('好'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openLan() async {
    final db = widget.db;
    if (db == null) {
      _later('局域网互传');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LanTransferPage(db: db, dir: widget.dir),
      ),
    );
  }

  Future<void> _openChangeVaultPin() async {
    if (!_hasVault) {
      _later('隐藏区密码');
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ChangeVaultPinPage(
          dir: widget.dir,
          kdfParams: widget.kdfParams,
        ),
      ),
    );
    if (!mounted || changed != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('隐藏密码已更换，旧密码立刻失效'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _coverSchemeLabel {
    if (_s.coverScheme == CoverPalette.kCustomKey) return '自定义';
    for (final scheme in CoverPalette.schemes) {
      if (scheme.key == _s.coverScheme) return scheme.label;
    }
    return CoverPalette.schemes.first.label;
  }

  String get _themeLabel => ThemeRuntime.value.label;

  /// 「首页标题」—— 只改名词部分，标题永远是「我的 + 名词」。
  Future<void> _pickNoun() async {
    final controller = TextEditingController(text: _s.noun);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EnvxColors.paper,
        title: const Text('我的后面叫什么'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: '笔记本'),
            ),
            const SizedBox(height: 10),
            Text(
              '首页标题会变成「我的${controller.text.trim().isEmpty ? '笔记本' : controller.text.trim()}」，'
              '下面的数量也跟着换成同一个说法。',
              style: const TextStyle(fontSize: 11, color: EnvxColors.ink3),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消', style: TextStyle(color: EnvxColors.ink2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('保存', style: TextStyle(color: EnvxColors.mint700)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    final noun = result.trim().isEmpty ? kDefaultNoun : result.trim();
    await _set(_s.copyWith(noun: noun));
  }

  Future<void> _pickCoverScheme() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: EnvxColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                '信封配色',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.04,
                  color: EnvxColors.ink,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '换的是信封封面的三套颜色，已有的笔记本会一起换，不用逐个改。',
                style: TextStyle(fontSize: 11, color: EnvxColors.ink3),
              ),
            ),
            for (final scheme in CoverPalette.schemes)
              ListTile(
                onTap: () => Navigator.of(context).pop(scheme.key),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final key in CoverPalette.keys)
                      Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: scheme.colors[key],
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: scheme.accents[key]!),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  scheme.label,
                  style: const TextStyle(fontSize: 13.5, color: EnvxColors.ink),
                ),
                trailing: scheme.key == _s.coverScheme
                    ? Icon(
                        Icons.check,
                        size: 18,
                        color: ThemeRuntime.value.accent,
                      )
                    : null,
              ),
            // 第五行：自定义。点进去逐槽挑色，挑完立刻生效。
            ListTile(
              onTap: () => Navigator.of(context).pop(CoverPalette.kCustomKey),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < CoverPalette.keys.length; i++)
                    Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Color(
                          i < _s.customCover.length
                              ? _s.customCover[i]
                              : kDefaultCustomCover[i],
                        ),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0x33000000)),
                      ),
                    ),
                ],
              ),
              title: const Text(
                '自定义',
                style: TextStyle(fontSize: 13.5, color: EnvxColors.ink),
              ),
              trailing: _s.coverScheme == CoverPalette.kCustomKey
                  ? Icon(
                      Icons.check,
                      size: 18,
                      color: ThemeRuntime.value.accent,
                    )
                  : null,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return;
    if (picked == CoverPalette.kCustomKey) {
      await _set(_s.copyWith(coverScheme: CoverPalette.kCustomKey));
      if (!mounted) return;
      await _pickCustomCover();
      return;
    }
    if (picked == _s.coverScheme) return;
    await _set(_s.copyWith(coverScheme: picked));
  }

  /// 三色自定义：sun / sky / blush 三个槽位各点一个色，点完立即写设置、立即生效。
  Future<void> _pickCustomCover() async {
    final values = List<int>.from(_s.customCover);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: EnvxColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
                  child: Text(
                    '自定义信封三色',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.04,
                      color: EnvxColors.ink,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: Text(
                    '三色按顺序分给第 1、2、3 个出现的本子，之后按这个循环。',
                    style: TextStyle(fontSize: 11, color: EnvxColors.ink3),
                  ),
                ),
                for (var slot = 0; slot < CoverPalette.keys.length; slot++)
                  _customSlotRow(
                    slot,
                    values,
                    (picked) async {
                      values[slot] = picked;
                      setSheetState(() {});
                      await _set(
                        _s.copyWith(
                          coverScheme: CoverPalette.kCustomKey,
                          customCover: List<int>.from(values),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _customSlotRow(
    int slot,
    List<int> values,
    void Function(int) onPick,
  ) {
    const labels = ['第一色', '第二色', '第三色'];
    final selected = slot < values.length ? values[slot] : -1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labels[slot],
            style: const TextStyle(fontSize: 11.5, color: EnvxColors.ink3),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in CoverPalette.swatches)
                GestureDetector(
                  onTap: () => onPick(v),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(v),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: v == selected
                            ? ThemeRuntime.value.accent
                            : const Color(0x22000000),
                        width: v == selected ? 2 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 主题色：只换强调色，正文和信纸保持原样。
  Future<void> _pickTheme() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: EnvxColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                '主题色',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.04,
                  color: EnvxColors.ink,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '换的是强调色：按钮、隐藏区入口、开关。正文与信纸不动，只保阅读。',
                style: TextStyle(fontSize: 11, color: EnvxColors.ink3),
              ),
            ),
            for (final preset in kThemePresets)
              ListTile(
                onTap: () => Navigator.of(context).pop(preset.key),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: preset.accent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: preset.soft,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
                title: Text(
                  preset.label,
                  style: const TextStyle(fontSize: 13.5, color: EnvxColors.ink),
                ),
                trailing: preset.key == ThemeRuntime.value.key
                    ? Icon(
                        Icons.check,
                        size: 18,
                        color: ThemeRuntime.value.accent,
                      )
                    : null,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await _set(_s.copyWith(themeKey: picked));
  }

  void _later(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$what 后续版本提供'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnvxColors.mist,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              // 平板上一行会被拉到 1000 宽，读起来像横条；这里把内容限宽居中。
              // 双栏重排是 M6 的事，现在先不做布局分叉。
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final extra = constraints.maxWidth > 600
                      ? (constraints.maxWidth - 600) / 2
                      : 0.0;
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: extra),
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 28),
                      children: [
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 5, 20, 0),
                    child: Text(
                      '设置',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.07,
                        color: EnvxColors.ink,
                      ),
                    ),
                  ),
                  _group('安全'),
                  _card([
                    _linkRow(
                      '隐藏区密码',
                      _hasVault ? '已设置 · 可修改' : '未设置',
                      _openChangeVaultPin,
                    ),
                    _switchRow(
                      '切到后台立即上锁',
                      _s.lockOnBackground,
                      (v) => _set(_s.copyWith(lockOnBackground: v)),
                    ),
                    _switchRow(
                      '截屏与录屏保护',
                      _s.screenshotProtect,
                      (v) => _set(_s.copyWith(screenshotProtect: v)),
                    ),
                  ]),
                  _group('数据'),
                  _card([
                    _linkRow(
                      '立即备份',
                      '整库 + 插图，存到本机备份目录',
                      _doBackup,
                    ),
                    _linkRow('从备份恢复', _restoreSub, _openRestore),
                    _linkRow('局域网互传', '仅同一 WiFi', _openLan),
                  ]),
                  _group('外观'),
                  _card([
                    _linkRow('首页标题', _s.title, _pickNoun),
                    _switchRow(
                      '信纸横线',
                      _s.paperLines,
                      (v) => _set(_s.copyWith(paperLines: v)),
                    ),
                    _linkRow('信封配色', _coverSchemeLabel, _pickCoverScheme),
                    _linkRow('主题色', _themeLabel, _pickTheme),
                  ]),
                  _group('关于'),
                  _card([
                    _row('数据存放位置', value: '仅本机'),
                    _row('版本', value: '1.0.1'),
                  ]),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
            color: EnvxColors.ink,
            tooltip: '返回',
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _group(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 7),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          color: EnvxColors.ink3,
          letterSpacing: 0.14,
        ),
      ),
    );
  }

  Widget _card(List<Widget> rows) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardLine),
        borderRadius: BorderRadius.circular(13),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: i == rows.length - 1
                      ? null
                      : const Border(
                          bottom: BorderSide(color: _rowLine),
                        ),
                ),
                child: rows[i],
              ),
          ],
        ),
      ),
    );
  }

  Widget _rowLabel(String key, {String? value}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            key,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.02,
              color: EnvxColors.ink,
            ),
          ),
        ),
        if (value != null)
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: EnvxColors.ink3,
              letterSpacing: 0.02,
            ),
          ),
      ],
    );
  }

  Widget _row(String key, {String? value}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: _rowLabel(key, value: value),
    );
  }

  Widget _switchRow(
    String key,
    bool on,
    void Function(bool) onChanged, {
    String? sub,
  }) {
    return InkWell(
      onTap: () => onChanged(!on),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                key,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.02,
                  color: EnvxColors.ink,
                ),
              ),
            ),
            // 副标跟在开关前面、与右侧其他行的取值对齐，
            // 压到标题下面会把它挤成两行，看着像正文而不是状态。
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: EnvxColors.ink3,
                    letterSpacing: 0.02,
                  ),
                ),
              ),
            _Sw(
              on: on,
              offColor: _swOff,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkRow(String key, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                key,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.02,
                  color: EnvxColors.ink,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                color: EnvxColors.ink3,
                letterSpacing: 0.02,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: EnvxColors.ink3,
            ),
          ],
        ),
      ),
    );
  }
}

/// 界面稿里的开关：38×22、圆角 11、开态 mint500、关态 #DDE9E5，
/// 白色圆点 16、左右各留 3。
class _Sw extends StatelessWidget {
  const _Sw({
    required this.on,
    required this.offColor,
    required this.onChanged,
  });

  final bool on;
  final Color offColor;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!on),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 38,
        height: 22,
        decoration: BoxDecoration(
          color: on ? ThemeRuntime.value.soft : offColor,
          borderRadius: BorderRadius.circular(11),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
