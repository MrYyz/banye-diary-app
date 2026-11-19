import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../core/kdf.dart';
import '../../core/settings.dart';
import '../../core/theme_runtime.dart';
import '../../data/database.dart';
import '../../data/notebook_transfer.dart';
import '../../data/schema.dart';
import '../theme.dart';
import '../widgets/cover.dart';
import '../widgets/empty_state.dart';
import 'envelope_editor_page.dart';
import '../widgets/time_fmt.dart';
import 'vault_gate_page.dart';

class NoteListPage extends StatefulWidget {
  const NoteListPage({
    super.key,
    required this.db,
    required this.notebook,
    this.embedded = false,
    this.dir,
    this.kdfParams,
    this.mainDb,
    this.fromVault = false,
  });

  final EnvxDatabase db;
  final Notebook notebook;

  /// 主库数据目录。有它才能在菜单里把本子搬进隐藏区（隐藏区是另一个库文件）。
  final Directory? dir;
  final KdfParams? kdfParams;

  /// 本子在隐藏区时，主库句柄 —— 用来「取消隐藏」搬回去。
  final EnvxDatabase? mainDb;

  /// 本页展示的是隐藏区里的本子。
  final bool fromVault;

  /// 平板双栏的右栏用。内嵌时不要返回箭头、标题左对齐、不自己出 FAB
  /// （FAB 由外层统一放在整页右下）。
  final bool embedded;

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  List<Note> _notes = [];
  List<Note> _filtered = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final notes = await widget.db.notes.list(widget.notebook.id);
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List.of(_notes);
      return;
    }
    _filtered = _notes.where((n) {
      final title = (n.title ?? '').toLowerCase();
      final body = (n.body ?? '').toLowerCase();
      return title.contains(q) || body.contains(q);
    }).toList();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _query = value;
        _applyFilter();
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _debounce?.cancel();
    setState(() {
      _query = '';
      _applyFilter();
    });
  }

  Future<void> _openEditor({Note? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EnvelopeEditorPage(
          db: widget.db,
          notebook: widget.notebook,
          note: existing,
          dir: widget.dir,
        ),
      ),
    );
    if (saved == true) await _reload();
  }

  Future<void> _togglePin(Note note) async {
    await widget.db.notes.togglePinned(note.id);
    await _reload();
  }

  Future<void> _deleteNote(Note note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EnvxColors.paper,
        title: const Text('删除这封信？'),
        content: const Text('删掉后不可恢复。'),
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
    await widget.db.notes.delete(note.id);
    await _reload();
  }

  void _noteMenu(Note note) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                note.pinned == 1
                    ? Icons.push_pin_outlined
                    : Icons.push_pin,
                color: EnvxColors.ink2,
              ),
              title: Text(note.pinned == 1 ? '取消置顶' : '置顶'),
              onTap: () {
                Navigator.of(context).pop();
                _togglePin(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: EnvxColors.ink2),
              title: const Text('删除'),
              onTap: () {
                Navigator.of(context).pop();
                _deleteNote(note);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 把本子搬进隐藏区，或从隐藏区搬回来。
  ///
  /// 隐藏区是独立库文件（独立密钥），所以「隐藏」是真搬数据，不是打个标记。
  Future<void> _toggleHidden() async {
    if (widget.fromVault) {
      final main = widget.mainDb;
      if (main == null) {
        _toast('主区没连上，暂时移不回去');
        return;
      }
      try {
        final result = await moveNotebook(
          from: widget.db,
          to: main,
          notebookId: widget.notebook.id,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        _toast('「${result.name}」已移回我的${SettingsRuntime.value.noun}');
      } on Object {
        _toast('移回失败，东西还在隐藏区');
      }
      return;
    }

    final dir = widget.dir;
    if (dir == null) {
      _toast('数据目录不可用，暂时隐藏不了');
      return;
    }
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
        notebookId: widget.notebook.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      _toast('「${result.name}」已移进隐藏区');
    } on Object {
      _toast('隐藏失败，本子还在原地');
    } finally {
      await vaultDb.close();
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _notebookMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: EnvxColors.ink2),
              title: const Text('重命名笔记本'),
              onTap: () => Navigator.of(context).pop('rename'),
            ),
            ListTile(
              leading: Icon(
                widget.fromVault
                    ? Icons.lock_open_outlined
                    : Icons.visibility_off_outlined,
                color: EnvxColors.ink2,
              ),
              title: Text(widget.fromVault ? '取消隐藏' : '隐藏这个笔记本'),
              subtitle: Text(
                widget.fromVault
                    ? '整个本子搬回「我的笔记本」'
                    : '整个本子搬进隐藏区，要第二个密码才打得开',
              ),
              onTap: () => Navigator.of(context).pop('hide'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: EnvxColors.ink2),
              title: const Text('删除笔记本'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'hide') {
      await _toggleHidden();
      return;
    }
    if (action == 'rename') {
      final controller = TextEditingController(text: widget.notebook.name);
      final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: EnvxColors.paper,
          title: const Text('重命名'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  const Text('取消', style: TextStyle(color: EnvxColors.ink2)),
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
      if (name == null || name.isEmpty) return;
      await widget.db.notebooks.rename(widget.notebook.id, name);
      if (mounted) setState(() {});
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: EnvxColors.paper,
          title: const Text('删除这个笔记本？'),
          content: const Text('里面的信会一起删掉，不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child:
                  const Text('取消', style: TextStyle(color: EnvxColors.ink2)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child:
                  const Text('删除', style: TextStyle(color: EnvxColors.ink2)),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await widget.db.notebooks.delete(widget.notebook.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    return Scaffold(
      floatingActionButton: widget.embedded
          ? null
          : FloatingActionButton(
              onPressed: () => _openEditor(),
              backgroundColor: ThemeRuntime.value.accent,
              child: const Icon(Icons.add, color: EnvxColors.paper),
            ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  if (widget.embedded)
                    const SizedBox(width: 12)
                  else
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back,
                          size: 18, color: EnvxColors.ink),
                    ),
                  Expanded(
                    child: Text(
                      widget.notebook.name,
                      textAlign: widget.embedded
                          ? TextAlign.left
                          : TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.05,
                        color: EnvxColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _notebookMenu,
                    icon: const Icon(Icons.more_vert,
                        size: 18, color: EnvxColors.ink),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
              child: _SearchBox(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                onClear: _clearSearch,
              ),
            ),
            Expanded(child: _buildBody(searching)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool searching) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_notes.isEmpty) {
      return const EmptyState(
        title: '还没有笔记',
        subtitle: '点右下角 + 写第一篇',
      );
    }
    if (_filtered.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: '没有找到相关的信',
        subtitle: '换个词试试，或检查是否写错了字',
      );
    }
    if (searching) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 6, bottom: 24),
        itemCount: _filtered.length,
        itemBuilder: (context, i) => _row(_filtered[i], i),
      );
    }
    final groups = <String, List<Note>>{};
    for (final n in _filtered) {
      groups.putIfAbsent(TimeFmt.groupOf(n.updatedAt), () => []).add(n);
    }
    const order = ['今天', '上周', '更早'];
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final g in order)
          if (groups.containsKey(g)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 19, 20, 6),
              child: Text(
                g,
                style: const TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 0.12,
                  color: EnvxColors.ink3,
                ),
              ),
            ),
            for (var i = 0; i < groups[g]!.length; i++)
              _row(groups[g]![i], i),
          ],
      ],
    );
  }

  Widget _row(Note note, int index) {
    final title = (note.title == null || note.title!.isEmpty)
        ? '无标题'
        : note.title!;
    final preview = (note.body ?? '').split('\n').first.trim();
    return GestureDetector(
      onTap: () => _openEditor(existing: note),
      onLongPress: () => _noteMenu(note),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: EnvxColors.mint100, width: 1),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: EnvelopeCover(
                colorKey: widget.notebook.color,
                index: index,
                radius: 8,
                sealRadius: 4,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.02,
                      color: EnvxColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview.isEmpty ? '暂无正文' : preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.02,
                      color: EnvxColors.ink3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              TimeFmt.rowTime(note.updatedAt),
              style: const TextStyle(
                fontSize: 10.5,
                letterSpacing: 0.02,
                color: EnvxColors.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: EnvxColors.paper,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: EnvxColors.mint100, width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, size: 15, color: EnvxColors.ink3),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 12, color: EnvxColors.ink),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '搜索这个笔记本',
                hintStyle: TextStyle(fontSize: 12, color: EnvxColors.ink3),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox(width: 12);
              return IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 16, color: EnvxColors.ink3),
              );
            },
          ),
        ],
      ),
    );
  }
}
