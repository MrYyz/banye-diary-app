import 'dart:io';

/// 插图目录的孤儿文件清理。
///
/// 背景：删一封信时 `attachment` 表记录会随外键级联消失，但
/// `envx_photos/` 里的图片文件不会跟着删 —— 用得越久，磁盘上堆的
/// 无用大图越多。
///
/// 两条保守规则，都是为了不误删：
/// 1. 只删「不在 attachment 表里」的文件；
/// 2. 最近 [gracePeriod] 内改动过的一律跳过 —— 用户可能正在编辑一封信、
///    图已经落盘但还没点完成，这时它还没进表，按规则 1 会被当场删掉。
///
/// 传进来的是「列出所有已登记路径」的函数而不是数据库本身，
/// 这样清理逻辑可以脱离真库单测。
class PhotoJanitor {
  PhotoJanitor({
    required this.photosDir,
    required this.registeredPaths,
    this.gracePeriod = const Duration(minutes: 10),
  });

  final Directory photosDir;

  /// 通常是 `db.attachments.allPaths`。
  final Future<List<String>> Function() registeredPaths;

  final Duration gracePeriod;

  /// 返回删掉的文件数。目录不存在时返回 0，不创建。
  Future<int> sweep({DateTime Function()? now}) async {
    if (!await photosDir.exists()) return 0;

    final keep = <String>{};
    for (final path in await registeredPaths()) {
      keep.add(path);
      keep.add(_normalize(path));
    }

    final current = (now ?? DateTime.now)();
    var removed = 0;

    await for (final entity in photosDir.list(followLinks: false)) {
      if (entity is! File) continue;
      final normalized = _normalize(entity.path);
      if (keep.contains(entity.path) || keep.contains(normalized)) continue;

      final stat = await entity.stat();
      if (current.difference(stat.modified).abs() < gracePeriod) continue;

      try {
        await entity.delete();
        removed++;
      } on FileSystemException {
        // 文件被占用（例如正显示着）就跳过，下次再来。
      }
    }
    return removed;
  }

  /// 表里存的是绝对路径，但 Windows 上分隔符与大小写都可能不统一，
  /// 比对前统一成小写正斜杠。
  String _normalize(String path) =>
      path.replaceAll('\\', '/').toLowerCase();
}
