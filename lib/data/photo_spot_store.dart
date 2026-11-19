import 'dart:convert';
import 'dart:io';

/// 一张插图在信纸上的摆法。
///
/// 语义对齐 Word 的环绕方式：
/// - [inline] 嵌入型（单独一行）：占正文流的一行，文字自然绕开，**永不遮挡文字**。
/// - [above] 浮于文字上方：压在最上层，会挡住字，是用户主动选择的排版。
/// - [below] 衬于文字下方：垫在正文下面，文字压在图上照常可读，图变成底纹。
enum PhotoWrap {
  inline,
  above,
  below,
}

/// 一张插图的位置（单位 dp，原点 = 信纸左上角）。
class PhotoSpot {
  const PhotoSpot({
    required this.x,
    required this.y,
    this.wrap = PhotoWrap.inline,
  });

  final double x;
  final double y;
  final PhotoWrap wrap;

  PhotoSpot copyWith({double? x, double? y, PhotoWrap? wrap}) => PhotoSpot(
        x: x ?? this.x,
        y: y ?? this.y,
        wrap: wrap ?? this.wrap,
      );
}

/// 插图摆法的存档。
///
/// 为什么不用数据库：`attachment` 表只有 path/mime/尺寸，加坐标列要跑一次
/// schema 迁移 + codegen，而用户手机上已经有 version 1 的库，迁移失败的代价
/// 是打不开日记。位置只是一张“贴纸怎么摆”的图纸，丢了最多整齐重排，
/// 不该冒这个险，所以单独放一个 json。
class PhotoSpotStore {
  PhotoSpotStore({required this.dir});

  final Directory dir;

  File get _file => File('${dir.path}/photo_spots.json');

  Future<Map<String, Map<String, PhotoSpot>>> loadAll() async {
    try {
      if (!await _file.exists()) return {};
      final raw = jsonDecode(await _file.readAsString());
      if (raw is! Map) return {};
      final out = <String, Map<String, PhotoSpot>>{};
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final spots = <String, PhotoSpot>{};
        for (final p in value.entries) {
          final v = p.value;
          if (v is! List || v.length < 2) continue;
          final wrapIdx = v.length >= 3 ? (v[2] as num).toInt() : 0;
          spots[p.key.toString()] = PhotoSpot(
            x: (v[0] as num).toDouble(),
            y: (v[1] as num).toDouble(),
            wrap: wrapIdx >= 0 && wrapIdx < PhotoWrap.values.length
                ? PhotoWrap.values[wrapIdx]
                : PhotoWrap.inline,
          );
        }
        if (spots.isNotEmpty) out[entry.key.toString()] = spots;
      }
      return out;
    } on Object {
      return {};
    }
  }

  Future<void> save(String noteId, Map<String, PhotoSpot> spots) async {
    final all = await loadAll();
    if (spots.isEmpty) {
      all.remove(noteId);
    } else {
      all[noteId] = spots;
    }
    if (!await dir.exists()) await dir.create(recursive: true);
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({
        for (final e in all.entries)
          e.key: {
            for (final s in e.value.entries)
              s.key: [
                double.parse(s.value.x.toStringAsFixed(2)),
                double.parse(s.value.y.toStringAsFixed(2)),
                s.value.wrap.index,
              ],
          },
      }),
      flush: true,
    );
    if (await _file.exists()) await _file.delete();
    await tmp.rename(_file.path);
  }
}
