import 'package:material_ui/material_ui.dart';

import 'package:envx/core/settings.dart';
import 'package:envx/data/database.dart';
import 'package:envx/data/notebook_transfer.dart';
import 'package:envx/data/schema.dart';
import 'package:envx/ui/screens/note_list_page.dart';
import 'package:envx/ui/theme.dart';

/// 隐藏区主页：只列隐藏笔记本，不显示主区任何内容。
///
/// 这里的 db 是 vault.db 的实例，与主区 app.db 完全隔离 ——
/// 即使主区被解开，也看不到这里的信封。
class VaultHomePage extends StatefulWidget {
  const VaultHomePage({super.key, required this.db, this.mainDb});

  final EnvxDatabase db;

  /// 主区库。用于把隐藏的笔记本移回主区；为 null 时该入口只给提示。
  final EnvxDatabase? mainDb;

  @override
  State<VaultHomePage> createState() => _VaultHomePageState();
}

class _VaultHomePageState extends State<VaultHomePage> {
  List<Notebook> _books = const [];
  Map<String, int> _counts = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final books = await widget.db.notebooks.all();
    final counts = <String, int>{};
    for (final book in books) {
      counts[book.id] = await widget.db.notebooks.countNotes(book.id);
    }
    if (!mounted) return;
    setState(() {
      _books = books;
      _counts = counts;
      _loading = false;
    });
  }

  /// 把一个隐藏本子整个搬回主区。搬完这个本子在隐藏区就不存在了。
  Future<void> _moveOut(Notebook book) async {
    final main = widget.mainDb;
    if (main == null) {
      _snack('主区没有连接，暂时移不回去');
      return;
    }
    try {
      final result = await moveNotebook(
        from: widget.db,
        to: main,
        notebookId: book.id,
      );
      await _reload();
      _snack('「${result.name}」已移回我的${SettingsRuntime.value.noun}');
    } on Object {
      _snack('移回失败，东西还在隐藏区');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _rowMenu(Notebook book) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lock_open_outlined,
                  color: EnvxColors.ink2),
              title: const Text('移回我的笔记本'),
              subtitle: const Text('整个本子连同里面的笔记一起搬出去'),
              onTap: () {
                Navigator.of(context).pop();
                _moveOut(book);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createBook() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EnvxColors.paper,
        title: const Text('新建隐藏本子'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '比如：不给任何人看'),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('建'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    await widget.db.notebooks.create(name: name, color: 'mint');
    await _reload();
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _books.isEmpty
                      ? _empty()
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _books.length,
                          itemBuilder: (context, i) => _row(_books[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            GestureDetector(
              key: const ValueKey('vault-home-back'),
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: Icon(
                    Icons.chevron_left,
                    size: 26,
                    color: EnvxColors.ink,
                  ),
                ),
              ),
            ),
            const Expanded(
              child: Text(
                '隐藏区',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.4,
                  color: EnvxColors.ink,
                ),
              ),
            ),
            GestureDetector(
              key: const ValueKey('vault-home-new'),
              onTap: _createBook,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: Icon(
                    Icons.add,
                    size: 22,
                    color: EnvxColors.mint700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 32,
            color: EnvxColors.ink3.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 14),
          const Text(
            '这里还是空的',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: EnvxColors.ink2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '点右上角加一个本子，放不想被翻到的东西',
            style: TextStyle(fontSize: 12, color: EnvxColors.ink3),
          ),
        ],
      ),
    );
  }

  Widget _row(Notebook book) {
    final count = _counts[book.id] ?? 0;
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => NoteListPage(
              db: widget.db,
              notebook: book,
              fromVault: true,
              mainDb: widget.mainDb,
            ),
          ),
        );
        await _reload();
      },
      onLongPress: () => _rowMenu(book),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: EnvxColors.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EnvxColors.mint100, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: EnvxColors.mint100,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.mail_outline,
                size: 17,
                color: EnvxColors.mint700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                book.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.28,
                  color: EnvxColors.ink,
                ),
              ),
            ),
            Text(
              '$count 笔记',
              style: const TextStyle(fontSize: 11, color: EnvxColors.ink3),
            ),
            const SizedBox(width: 2),
            // 长按太隐蔽：和主区的卡片一样给一个看得见的入口，
            // 点它等于长按 —— 同一个菜单，含「移回我的笔记本」。
            GestureDetector(
              onTap: () => _rowMenu(book),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(
                  Icons.more_horiz,
                  size: 15,
                  color: EnvxColors.ink3,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: EnvxColors.ink3,
            ),
          ],
        ),
      ),
    );
  }
}
