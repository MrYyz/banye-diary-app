import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:hashlib/hashlib.dart';

import 'schema.dart';

/// 16 字节 `Random.secure` 生成 32 位小写 hex id，与 M1 的 randomSalt 风格一致。
String _newId() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

int _nowMs() => DateTime.now().millisecondsSinceEpoch;

abstract class NotebookRepo {
  /// sort 升序， createdAt 升序。
  Future<List<Notebook>> all();

  Future<Notebook> create({required String name, String? color});

  /// 跨库搬运用：连封面色、排序位、创建时间一起写，别把老本子刷成「刚刚」。
  Future<Notebook> createImported({
    required String name,
    String? color,
    int sort,
    required int createdAt,
  });

  Future<void> rename(String id, String newName);

  Future<void> setColor(String id, String? color);

  /// 删除本子，同时级联删掉该本子下所有笔记（依赖外键 ON）。
  Future<void> delete(String id);

  Future<int> countNotes(String notebookId);
}

abstract class NoteRepo {
  /// pinned 降序， updatedAt 降序。
  Future<List<Note>> list(String notebookId);

  Future<Note?> get(String id);

  Future<Note> create({
    required String notebookId,
    String? title,
    String body = '',
  });

  /// 导入用：连创建/更新时间和置顶位一起写。
  /// 局域网互传还原一封旧信时必须走这个，否则时间会被刷成"刚刚"，
  /// 导入后所有信会挤在同一天。
  Future<Note> createImported({
    required String notebookId,
    String? title,
    String body = '',
    required int createdAt,
    required int updatedAt,
    int pinned = 0,
  });

  /// 更新正文/标题；传入 null 的字段保持不变。save 自动刷 updatedAt。
  Future<void> save(String id, {String? title, String? body});

  Future<void> togglePinned(String id);

  Future<void> delete(String id);

  /// 标题 + 正文 LIKE，忽略大小写；空串返回空表。
  Future<List<Note>> search(String query);
}

/// 一封信里的插图。M3 当初只放内存，重启就丢；M6-C 接回 attachment 表。
abstract class AttachmentRepo {
  /// 按 path 升序 = 按落盘时间升序（文件名前缀是毫秒时间戳）。
  Future<List<Attachment>> listFor(String noteId);

  /// 用给定路径集合整体覆盖这封信的附件记录：先清旧，再逐条写入。
  Future<void> replaceFor(String noteId, List<String> paths);

  Future<int> countFor(String noteId);

  /// 全库所有插图路径，供孤儿文件清理对照。
  Future<List<String>> allPaths();
}

class AttachmentRepoImpl implements AttachmentRepo {
  AttachmentRepoImpl(this._db);

  final EnvxSchema _db;

  @override
  Future<List<Attachment>> listFor(String noteId) {
    return (_db.select(_db.attachmentTable)
          ..where((t) => t.noteId.equals(noteId))
          ..orderBy([(t) => OrderingTerm.asc(t.path)]))
        .get();
  }

  @override
  Future<void> replaceFor(String noteId, List<String> paths) async {
    await (_db.delete(_db.attachmentTable)
          ..where((t) => t.noteId.equals(noteId)))
        .go();
    for (final path in paths) {
      var sha = '';
      try {
        sha = sha256.hex(await File(path).readAsBytes());
      } on Object {
        // 文件读不出来不该让保存失败，记个空摘要即可。
        sha = '';
      }
      await _db.into(_db.attachmentTable).insert(
            AttachmentTableCompanion(
              id: Value(_newId()),
              noteId: Value(noteId),
              path: Value(path),
              sha256: Value(sha),
            ),
          );
    }
  }

  @override
  Future<List<String>> allPaths() async {
    final rows = await (_db.select(_db.attachmentTable)
          ..orderBy([(t) => OrderingTerm.asc(t.path)]))
        .get();
    return rows.map((r) => r.path).toList();
  }

  @override
  Future<int> countFor(String noteId) async {
    final rows = await listFor(noteId);
    return rows.length;
  }
}

class NotebookRepoImpl implements NotebookRepo {
  NotebookRepoImpl(this._db, {this.clock});

  final EnvxSchema _db;

  /// 测试注入固定时刻用；为 null 时走真实时钟。
  final int Function()? clock;

  int _now() => clock?.call() ?? _nowMs();

  @override
  Future<List<Notebook>> all() {
    return (_db.select(_db.notebookTable)
          ..orderBy([
            (t) => OrderingTerm.asc(t.sort),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
  }

  @override
  Future<Notebook> create({required String name, String? color}) async {
    final id = _newId();
    await _db.into(_db.notebookTable).insert(
          NotebookTableCompanion(
            id: Value(id),
            name: Value(name),
            color: Value(color),
            createdAt: Value(_now()),
          ),
        );
    return (await _byId(id))!;
  }

  @override
  Future<Notebook> createImported({
    required String name,
    String? color,
    int sort = 0,
    required int createdAt,
  }) async {
    final id = _newId();
    await _db.into(_db.notebookTable).insert(
          NotebookTableCompanion(
            id: Value(id),
            name: Value(name),
            color: Value(color),
            sort: Value(sort),
            createdAt: Value(createdAt),
          ),
        );
    return (await _byId(id))!;
  }

  @override
  Future<void> rename(String id, String newName) {
    return (_db.update(_db.notebookTable)
          ..where((t) => t.id.equals(id)))
        .write(NotebookTableCompanion(name: Value(newName)));
  }

  @override
  Future<void> setColor(String id, String? color) {
    return (_db.update(_db.notebookTable)
          ..where((t) => t.id.equals(id)))
        .write(NotebookTableCompanion(color: Value(color)));
  }

  @override
  Future<void> delete(String id) {
    return (_db.delete(_db.notebookTable)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<int> countNotes(String notebookId) async {
    final count = _db.noteTable.id.count();
    final query = _db.selectOnly(_db.noteTable)
      ..addColumns([count])
      ..where(_db.noteTable.notebookId.equals(notebookId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<Notebook?> _byId(String id) {
    return (_db.select(_db.notebookTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }
}

class NoteRepoImpl implements NoteRepo {
  NoteRepoImpl(this._db, {this.clock});

  final EnvxSchema _db;

  /// 测试注入固定时刻用；为 null 时走真实时钟。
  final int Function()? clock;

  int _now() => clock?.call() ?? _nowMs();

  @override
  Future<List<Note>> list(String notebookId) {
    return (_db.select(_db.noteTable)
          ..where((t) => t.notebookId.equals(notebookId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.pinned),
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .get();
  }

  @override
  Future<Note?> get(String id) {
    return (_db.select(_db.noteTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<Note> create({
    required String notebookId,
    String? title,
    String body = '',
  }) async {
    final id = _newId();
    final now = _now();
    await _db.into(_db.noteTable).insert(
          NoteTableCompanion(
            id: Value(id),
            notebookId: Value(notebookId),
            title: Value(title),
            body: Value(body),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return (await get(id))!;
  }

  @override
  Future<void> save(String id, {String? title, String? body}) {
    return (_db.update(_db.noteTable)..where((t) => t.id.equals(id))).write(
      NoteTableCompanion(
        title: title == null ? const Value.absent() : Value(title),
        body: body == null ? const Value.absent() : Value(body),
        updatedAt: Value(_now()),
      ),
    );
  }

  @override
  Future<Note> createImported({
    required String notebookId,
    String? title,
    String body = '',
    required int createdAt,
    required int updatedAt,
    int pinned = 0,
  }) async {
    final id = _newId();
    await _db.into(_db.noteTable).insert(
          NoteTableCompanion(
            id: Value(id),
            notebookId: Value(notebookId),
            title: Value(title),
            body: Value(body),
            createdAt: Value(createdAt),
            updatedAt: Value(updatedAt),
            pinned: Value(pinned),
          ),
        );
    return (await get(id))!;
  }

  @override
  Future<void> togglePinned(String id) async {
    final note = await get(id);
    if (note == null) return;
    final next = note.pinned == 1 ? 0 : 1;
    await (_db.update(_db.noteTable)..where((t) => t.id.equals(id)))
        .write(NoteTableCompanion(pinned: Value(next)));
  }

  @override
  Future<void> delete(String id) {
    return (_db.delete(_db.noteTable)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<List<Note>> search(String query) async {
    if (query.trim().isEmpty) return [];
    return (_db.select(_db.noteTable)
          ..where((t) => t.title.contains(query) | t.body.contains(query)))
        .get();
  }
}
