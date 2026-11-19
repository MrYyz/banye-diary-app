import 'dart:io';
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/kdf.dart';
import '../../data/database.dart';
import '../../data/schema.dart';
import '../theme.dart';
import '../widgets/cover.dart';
import '../widgets/empty_state.dart';
import '../widgets/time_fmt.dart';
import 'note_list_page.dart';

/// 全局搜索：跨笔记本标题 + 正文 LIKE（走 [NoteRepo.search]）。
/// 输入即搜，debounce 200ms；空串返回空表（契约 4.8）。
class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.db,
    this.dir,
    this.kdfParams,
  });

  final EnvxDatabase db;

  /// 进入笔记本后要能「隐藏这个笔记本」，那一步需要数据目录。
  final Directory? dir;
  final KdfParams? kdfParams;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;

  List<Notebook> _notebooks = [];
  List<Note> _results = [];
  String _query = '';
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _loadNotebooks();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadNotebooks() async {
    _notebooks = await widget.db.notebooks.all();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () => _run(value));
  }

  Future<void> _run(String value) async {
    final q = value.trim();
    final results = q.isEmpty ? <Note>[] : await widget.db.notes.search(q);
    if (!mounted) return;
    setState(() {
      _query = value;
      _results = results;
      _searched = true;
    });
  }

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    setState(() {
      _query = '';
      _results = [];
    });
  }

  Notebook? _notebookOf(String id) {
    for (final nb in _notebooks) {
      if (nb.id == id) return nb;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back,
                        size: 18, color: EnvxColors.ink),
                  ),
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: EnvxColors.paper,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: EnvxColors.mint100, width: 1),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          const Icon(Icons.search,
                              size: 15, color: EnvxColors.ink3),
                          const SizedBox(width: 9),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              onChanged: _onChanged,
                              style: const TextStyle(
                                  fontSize: 12, color: EnvxColors.ink),
                              decoration: const InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: '搜索所有信',
                                hintStyle: TextStyle(
                                    fontSize: 12, color: EnvxColors.ink3),
                              ),
                            ),
                          ),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _controller,
                            builder: (context, value, _) {
                              if (value.text.isEmpty) {
                                return const SizedBox(width: 12);
                              }
                              return IconButton(
                                onPressed: _clear,
                                icon: const Icon(Icons.close,
                                    size: 16, color: EnvxColors.ink3),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(searching)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool searching) {
    if (!_searched || _query.trim().isEmpty) {
      return const EmptyState(
        icon: Icons.search,
        title: '输入关键词',
        subtitle: '搜索所有信',
      );
    }
    if (_results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: '没有找到相关的信',
        subtitle: '换个词试试，或检查是否写错了字',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 24),
      itemCount: _results.length,
      itemBuilder: (context, i) => _row(_results[i], i),
    );
  }

  Widget _row(Note note, int index) {
    final title = (note.title == null || note.title!.isEmpty)
        ? '无标题'
        : note.title!;
    final preview = (note.body ?? '').split('\n').first.trim();
    final nb = _notebookOf(note.notebookId);
    return GestureDetector(
      onTap: () {
        if (nb == null) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => NoteListPage(
              db: widget.db,
              notebook: nb,
              dir: widget.dir,
              kdfParams: widget.kdfParams,
              mainDb: widget.db,
            ),
          ),
        );
      },
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
                colorKey: nb?.color,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  TimeFmt.rowTime(note.updatedAt),
                  style: const TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.02,
                    color: EnvxColors.ink3,
                  ),
                ),
                if (nb != null)
                  Text(
                    nb.name,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: EnvxColors.ink3,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
