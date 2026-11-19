import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/notebook_transfer.dart';
import '../../data/photo_janitor.dart';

import '../../core/kdf.dart';
import '../../core/settings.dart';
import '../../core/theme_runtime.dart';
import '../../data/database.dart';
import '../../data/schema.dart';
import '../../core/window_secure.dart';
import '../theme.dart';
import '../widgets/cover.dart';
import '../widgets/empty_state.dart';
import 'envelope_editor_page.dart';
import '../widgets/time_fmt.dart';
import 'note_list_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'vault_gate_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.db,
    this.dirProvider,
    this.kdfParams,
    this.keyBytes,
    this.keyVerifier,
    this.justRegistered = false,
  });

  final EnvxDatabase db;

  /// 当前库密钥。只有它存在时「切后台立即上锁」才敢启用 ——
  /// 没有比对依据就只能把界面盖住，那不成锁。
  final Uint8List? keyBytes;

  /// 覆盖默认的密码校验。默认实现要读盐 + isolate 派生，而 widget test 的
  /// fake-async 区里 compute 不返回，所以留一个纯 CPU 的注入点给测试。
  final Future<bool> Function(String pin)? keyVerifier;

  /// 应用私有目录；隐藏区要在这里建/开 vault.db。
  final Future<Directory> Function()? dirProvider;

  /// KDF 档位，测试可传 light。
  final KdfParams? kdfParams;

  /// 本次是不是刚在开锁页设完密码（首次使用）。首页补一句确认提示。
  final bool justRegistered;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Notebook> _nbs = [];

  /// 数据目录缓存：嵌入式列表页要把它递给「隐藏这个笔记本」，而 build 里不能 await。
  Directory? _dataDir;
  List<int> _counts = [];
  List<int> _lastUpdated = [];
  int _totalNotes = 0;
  bool _loading = true;

  /// 平板双栏时左栏高亮的那一本；手机端恒为 0。
  int _selIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _reload();
    unawaited(_sweepOrphanPhotos());
    if (widget.justRegistered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _snack('密码已设好，只有你自己知道');
      });
    }
  }

  /// 启动时清一次插图目录：删信会级联删掉附件记录，但文件还留在盘上。
  /// 失败一律吞掉 —— 清理是后台杂务，不该挡住用户看日记。
  Future<void> _sweepOrphanPhotos() async {
    try {
      // 隐藏区是独立库，主库看不到那边的附件记录。一旦有笔记本被移进隐藏区，
      // 它的图片在主库眼里就成了「没人认领」，会被当垃圾删掉。
      // 所以只要 vault.db 还在，就放弃这次清理 —— 宁可多占点空间也不误删。
      final dir = await _resolveDataDir();
      if (dir != null && await File('${dir.path}/vault.db').exists()) return;

      final docs = await getApplicationDocumentsDirectory();
      final janitor = PhotoJanitor(
        photosDir: Directory('${docs.path}/envx_photos'),
        registeredPaths: widget.db.attachments.allPaths,
      );
      await janitor.sweep();
    } on Object {
      // 忽略
    }
  }

  // 切后台的遮挡已上移到 App 级的 LockGate（MaterialApp.builder），
  // 因为 push 出去的页面盖在首页之上，页内锁盖不住它们。

  /// 目录拿不到时返回 null：测试环境没有 platform channel，
  /// 生产上也可能失败，都不该让主流程崩掉。
  Future<Directory?> _resolveDataDir() async {
    try {
      if (widget.dirProvider != null) return await widget.dirProvider!();
      return await getApplicationSupportDirectory();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadSettings() async {
    final dir = await _resolveDataDir();
    if (dir == null) return;
    _dataDir = dir;
    final loaded = await SettingsStore(dir: dir).load();
    SettingsRuntime.value = loaded;
    ThemeRuntime.apply(loaded.themeKey);
    // 开锁进主区是每次冷启动都会走到的唯一入口，截屏保护挂在这里，
    // 就不会因为「用户从没进过设置页」而漏掉。
    await applyScreenshotProtectFrom(loaded);
  }

  Future<void> _reload() async {
    final nbs = await widget.db.notebooks.all();
    final counts = <int>[];
    final last = <int>[];
    var total = 0;
    for (final nb in nbs) {
      final c = await widget.db.notebooks.countNotes(nb.id);
      counts.add(c);
      total += c;
      final notes = await widget.db.notes.list(nb.id);
      last.add(notes.isEmpty ? 0 : notes.first.updatedAt);
    }
    if (!mounted) return;
    setState(() {
      _nbs = nbs;
      _counts = counts;
      _lastUpdated = last;
      _totalNotes = total;
      _loading = false;
    });
  }

  String get _noun => SettingsRuntime.value.noun;
  String get _title => SettingsRuntime.value.title;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openNotebook(Notebook nb) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteListPage(
          db: widget.db,
          notebook: nb,
          dir: _dataDir,
          kdfParams: widget.kdfParams,
        ),
      ),
    );
    await _reload();
  }

  Future<String?> _nameDialog({String? initial}) async {
    final controller = TextEditingController(text: initial ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EnvxColors.paper,
        title: Text(initial == null ? '新建$_noun' : '重命名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            // 后面紧跟中文，花括号去掉会被当成标识符的一部分。
            hintText: '${_noun}名字', // ignore: unnecessary_brace_in_string_interps
            hintStyle: const TextStyle(color: EnvxColors.ink3),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消', style: TextStyle(color: EnvxColors.ink2)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('完成',
                style: TextStyle(color: EnvxColors.mint700)),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<Notebook?> _newNotebook() async {
    final name = await _nameDialog();
    if (name == null || name.isEmpty) return null;
    final color = CoverPalette.keys[_nbs.length % CoverPalette.keys.length];
    final created = await widget.db.notebooks.create(name: name, color: color);
    await _reload();
    return created;
  }

  Future<void> _rename(Notebook nb) async {
    final name = await _nameDialog(initial: nb.name);
    if (name == null || name.isEmpty) return;
    await widget.db.notebooks.rename(nb.id, name);
    await _reload();
  }

  Future<void> _cycleColor(Notebook nb) async {
    await widget.db.notebooks.setColor(
      nb.id,
      CoverPalette.nextKey(nb.color),
    );
    await _reload();
  }

  Future<void> _delete(Notebook nb) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EnvxColors.paper,
        title: Text('删除这个$_noun？'),
        content: Text('「${nb.name}」里的笔记会一起删掉，不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消', style: TextStyle(color: EnvxColors.ink2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: EnvxColors.ink2)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.db.notebooks.delete(nb.id);
    await _reload();
  }

  void _cardMenu(Notebook nb) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: EnvxColors.ink2),
              title: const Text('重命名'),
              onTap: () {
                Navigator.of(context).pop();
                _rename(nb);
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined, color: EnvxColors.ink2),
              title: const Text('换封面色'),
              onTap: () {
                Navigator.of(context).pop();
                _cycleColor(nb);
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined,
                  color: EnvxColors.ink2),
              title: const Text('移到隐藏区'),
              subtitle: const Text('整个本子搬进独立库，要第二个密码才打得开'),
              onTap: () {
                Navigator.of(context).pop();
                _moveToVault(nb);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: EnvxColors.ink2),
              title: const Text('删除'),
              onTap: () {
                Navigator.of(context).pop();
                _delete(nb);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 把一个笔记本整个搬进隐藏区。
  ///
  /// 隐藏区是独立加密库（独立文件、独立密钥），所以「隐藏」是真的搬数据：
  /// 先过第二密码拿到库句柄，搬完在调用方手里关掉它。
  Future<void> _moveToVault(Notebook nb) async {
    final dir = await _resolveDataDir();
    if (dir == null) {
      _snack('数据目录不可用，暂时移不了');
      return;
    }
    if (!mounted) return;
    final vaultDb = await Navigator.of(context).push<EnvxDatabase>(
      MaterialPageRoute<EnvxDatabase>(
        builder: (_) => VaultGatePage(
          dir: dir,
          kdfParams: widget.kdfParams,
          returnDb: true,
        ),
      ),
    );
    if (vaultDb == null || !mounted) return;
    try {
      final result = await moveNotebook(
        from: widget.db,
        to: vaultDb,
        notebookId: nb.id,
      );
      await _reload();
      _snack('「${result.name}」已移进隐藏区，${result.noteCount} 篇笔记一起搬走了');
    } on Object {
      _snack('移动失败，$_noun 还在原处');
    } finally {
      await vaultDb.close();
    }
  }

  /// 空态下点 + 不该只弹一句提示：把新建流程直接拉起来，
  /// 建好之后再问要不要马上写第一笔记。
  Future<void> _newNote() async {
    if (_nbs.isEmpty) {
      final created = await _newNotebook();
      if (created == null || !mounted) return;
      final writeNow = await _askWriteNow(created);
      if (writeNow != true || !mounted) return;
      await _openEditor(created);
      return;
    }
    final idx = _selIndex.clamp(0, _nbs.length - 1);
    await _openEditor(_nbs[idx]);
  }

  Future<bool?> _askWriteNow(Notebook nb) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EnvxColors.paper,
        title: Text('「${nb.name}」建好了'),
        content: const Text('现在写第一篇笔记吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('等一下', style: TextStyle(color: EnvxColors.ink2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                const Text('现在写', style: TextStyle(color: EnvxColors.mint700)),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(Notebook nb) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EnvelopeEditorPage(
          db: widget.db,
          notebook: nb,
          dir: _dataDir,
        ),
      ),
    );
    if (saved == true) await _reload();
  }

  Future<void> _openSettings() async {
    final Directory? maybe = await _resolveDataDir();
    if (maybe == null) {
      _snack('设置暂时打不开：数据目录不可用');
      return;
    }
    final Directory dir = maybe;
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          dir: dir,
          kdfParams: widget.kdfParams,
          db: widget.db,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _openVault() async {
    final dir = widget.dirProvider != null
        ? await widget.dirProvider!()
        : await getApplicationSupportDirectory();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VaultGatePage(
          dir: dir,
          kdfParams: widget.kdfParams,
          mainDb: widget.db,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // ≥720 走平板双栏（06 屏）：左栏 266 常驻笔记本列表，右栏是该本的信。
            if (width >= 720) return _buildTablet(width);
            final pad = width >= 600 ? 24.0 : 20.0;
            final columns = width >= 840
                ? 4
                : width >= 600
                    ? 3
                    : 2;
            const spacing = 12.0;
            final cardWidth =
                (width - pad * 2 - spacing * (columns - 1)) / columns;
            final ratio = cardWidth / 158;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        TimeFmt.dateLine(TimeFmt.now()),
                        style: const TextStyle(
                          fontSize: 11.5,
                          letterSpacing: 0.06,
                          color: EnvxColors.ink3,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SearchPage(
              db: widget.db,
              dir: _dataDir,
              kdfParams: widget.kdfParams,
            ),
                              ),
                            ),
                            icon: const Icon(Icons.search,
                                size: 18, color: EnvxColors.ink),
                          ),
                          IconButton(
                            onPressed: _openSettings,
                            icon: const Icon(Icons.settings_outlined,
                                size: 18, color: EnvxColors.ink),
                            tooltip: '设置',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.05,
                      color: EnvxColors.ink,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_nbs.length} 个$_noun · $_totalNotes 笔记',
                    style: const TextStyle(
                      fontSize: 11.5,
                      letterSpacing: 0.03,
                      color: EnvxColors.ink3,
                    ),
                  ),
                  const SizedBox(height: 19),
                  _HiddenBar(onTap: _openVault),
                  const SizedBox(height: 13),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_nbs.isEmpty)
                    SizedBox(
                      height: 320,
                      // 没有右下角 + 了，空态整块就是新建入口。
                      child: GestureDetector(
                        onTap: _newNote,
                        behavior: HitTestBehavior.opaque,
                        child: EmptyState(
                          title: '还没有$_noun',
                          subtitle: '点这里，新建第一个$_noun',
                        ),
                      ),
                    )
                  else
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: columns,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      childAspectRatio: ratio,
                      children: [
                        for (var i = 0; i < _nbs.length; i++)
                          _nbCard(i, _nbs[i]),
                        _NewNotebookCard(onTap: _newNotebook, noun: _noun),
                      ],
                    ),
                  const SizedBox(height: 96),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTablet(double width) {
    final idx = _nbs.isEmpty ? -1 : _selIndex.clamp(0, _nbs.length - 1);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 266, child: _sideRail(idx)),
        Container(width: 1, color: EnvxColors.mint100),
        Expanded(
          child: idx < 0
              ? EmptyState(
                  title: '还没有$_noun',
                  subtitle: '在左边点「新建$_noun」',
                )
              : NoteListPage(
                  key: ValueKey('nb-${_nbs[idx].id}'),
                  db: widget.db,
                  notebook: _nbs[idx],
                  embedded: true,
                  dir: _dataDir,
                  kdfParams: widget.kdfParams,
                ),
        ),
      ],
    );
  }

  Widget _sideRail(int idx) {
    return ColoredBox(
      color: const Color(0xFFF5FAF9),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          TimeFmt.dateLine(TimeFmt.now()),
                          style: const TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.06,
                            color: EnvxColors.ink3,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SearchPage(
              db: widget.db,
              dir: _dataDir,
              kdfParams: widget.kdfParams,
            ),
                          ),
                        ),
                        icon: const Icon(Icons.search,
                            size: 17, color: EnvxColors.ink),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 30, minHeight: 30),
                      ),
                      IconButton(
                        onPressed: _openSettings,
                        icon: const Icon(Icons.settings_outlined,
                            size: 17, color: EnvxColors.ink),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 30, minHeight: 30),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.05,
                      color: EnvxColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_nbs.length} 个$_noun · $_totalNotes 笔记',
                    style: const TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.03,
                      color: EnvxColors.ink3,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _HiddenBar(onTap: _openVault),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    for (var i = 0; i < _nbs.length; i++)
                      _railItem(i, _nbs[i], idx == i),
                    _railNew(),
                  ],
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: EnvxColors.mint100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '共 $_totalNotes 笔记 · 全部存本机',
              style: const TextStyle(
                fontSize: 10.5,
                letterSpacing: 0.03,
                color: EnvxColors.ink2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _railItem(int i, Notebook nb, bool active) {
    final meta = _counts[i] == 0 ? '还没有笔记' : '${_counts[i]} 笔记';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => setState(() => _selIndex = i),
        onLongPress: () => _cardMenu(nb),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: active ? EnvxColors.mint100 : const Color(0x00FFFFFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: EnvelopeCover(
                  colorKey: nb.color,
                  index: i,
                  radius: 8,
                  sealRadius: 4,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nb.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  active ? FontWeight.w800 : FontWeight.w600,
                              letterSpacing: 0.02,
                              color: EnvxColors.ink,
                            ),
                          ),
                        ),
                        _MoreDot(onTap: () => _cardMenu(nb)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.02,
                        color: EnvxColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _railNew() {
    return GestureDetector(
      onTap: _newNotebook,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EnvxColors.mint100, width: 1.5),
        ),
        child: Text(
          '+ 新建$_noun',
          style: TextStyle(
            fontSize: 11.5,
            letterSpacing: 0.04,
            color: EnvxColors.mint700,
          ),
        ),
      ),
    );
  }

  Widget _nbCard(int i, Notebook nb) {
    final meta = _counts[i] == 0
        ? '还没有笔记'
        : '${_counts[i]} 笔记 · ${TimeFmt.relative(_lastUpdated[i])}';
    return GestureDetector(
      onTap: () => _openNotebook(nb),
      onLongPress: () => _cardMenu(nb),
      child: Container(
        height: 158,
        decoration: BoxDecoration(
          color: EnvxColors.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: EnvxColors.mint100, width: 1),
          boxShadow: const [
            BoxShadow(
              color: EnvxColors.mint100,
              offset: Offset(0, 2),
              blurRadius: 0,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 92,
              width: double.infinity,
              child: EnvelopeCover(
                colorKey: nb.color,
                index: i,
                radius: 16,
                sealRadius: 6.5,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          nb.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.03,
                            color: EnvxColors.ink,
                          ),
                        ),
                      ),
                      _MoreDot(onTap: () => _cardMenu(nb)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.03,
                      color: EnvxColors.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 卡片/侧栏行上的「⋯」：长按太隐蔽，给一个看得见、点得到的入口。
/// 点它等于长按 —— 同一个 `_cardMenu`，包括「移到隐藏区」。
class _MoreDot extends StatelessWidget {
  const _MoreDot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const Padding(
        padding: EdgeInsets.all(3),
        child: Icon(Icons.more_horiz, size: 15, color: EnvxColors.ink3),
      ),
    );
  }
}

/// 隐藏区入口条：M2 没有 vault.db，不展示假数量，右侧只留「需密码」。
class _HiddenBar extends StatelessWidget {
  const _HiddenBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ThemeRuntime.value.accent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: Color(0x26FFFFFF),
                child: Icon(Icons.lock_outline,
                    size: 16, color: EnvxColors.paper),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '隐藏区',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.04,
                        color: EnvxColors.paper,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '需密码',
                      style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.03,
                        color: Color(0xBDFBFDFC),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: EnvxColors.paper),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewNotebookCard extends StatelessWidget {
  const _NewNotebookCard({required this.onTap, required this.noun});

  final VoidCallback onTap;
  final String noun;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedCardPainter(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('+',
                style: TextStyle(
                  fontSize: 23,
                  height: 1,
                  color: EnvxColors.mint700,
                )),
            const SizedBox(height: 8),
            Text(
              '新建$noun',
              style: const TextStyle(
                fontSize: 11.5,
                letterSpacing: 0.04,
                color: EnvxColors.mint700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 虚线描边卡片（新建笔记本入口）。
class _DashedCardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      Paint()..color = EnvxColors.mist,
    );
    final paint = Paint()
      ..color = EnvxColors.mint100
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dash = 6.0;
    const gap = 5.0;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    for (var start = 0.0; start < metric.length; start += dash + gap) {
      final segment = metric.extractPath(start, start + dash);
      canvas.drawPath(segment, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
