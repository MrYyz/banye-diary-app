import 'database.dart';
import 'schema.dart';

/// 一次跨库搬运的结果。
class TransferResult {
  const TransferResult({
    required this.name,
    required this.noteCount,
    required this.photoCount,
  });

  final String name;
  final int noteCount;
  final int photoCount;
}

/// 把一个笔记本连同它下面的全部笔记、附件记录，从 [from] 搬到 [to]，
/// 搬成功后从 [from] 删除本源。
///
/// 隐藏区是独立库（独立文件、独立密钥），所以「隐藏一个笔记本」不是打个标记，
/// 是真的要把数据搬到另一个加密库里。
///
/// 图片文件本身不搬：两个库共用同一个 `envx_photos` 目录，搬的只是
/// `attachment` 表里那几行指向关系。搬的过程中任何一步失败都会把目标侧
/// 已建的本子删掉（级联清笔记），不留半个副本。
Future<TransferResult> moveNotebook({
  required EnvxDatabase from,
  required EnvxDatabase to,
  required String notebookId,
}) async {
  final books = await from.notebooks.all();
  Notebook? src;
  for (final book in books) {
    if (book.id == notebookId) {
      src = book;
      break;
    }
  }
  if (src == null) throw StateError('笔记本不存在');

  final notes = await from.notes.list(notebookId);
  final target = await to.notebooks.createImported(
    name: src.name,
    color: src.color,
    sort: src.sort,
    createdAt: src.createdAt,
  );

  var photoCount = 0;
  try {
    for (final note in notes) {
      final attachments = await from.attachments.listFor(note.id);
      final copied = await to.notes.createImported(
        notebookId: target.id,
        title: note.title,
        body: note.body ?? '',
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        pinned: note.pinned,
      );
      if (attachments.isNotEmpty) {
        await to.attachments.replaceFor(
          copied.id,
          attachments.map((a) => a.path).toList(),
        );
        photoCount += attachments.length;
      }
    }
  } on Object {
    // 目标侧删干净再抛，避免留下一个残缺副本。
    await to.notebooks.delete(target.id);
    rethrow;
  }

  await from.notebooks.delete(notebookId);
  return TransferResult(
    name: src.name,
    noteCount: notes.length,
    photoCount: photoCount,
  );
}
