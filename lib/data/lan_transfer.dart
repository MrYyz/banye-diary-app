/// 局域网互传的协议层：把一个笔记本打包成 `.envxpack` JSON，再在另一端还原。
///
/// 设计取舍（M8）：
/// - 只传「一个笔记本」，不传整个库 —— 用户的心智是"把这本寄过去"，而不是全量同步。
/// - 图片用 base64 内嵌，单张上限 6 MB；超了跳过并在结果里如实报告，不静默丢。
/// - 不做内容加密，靠「同一 WiFi + 6 位配对码 + 摘要校验」。这是局域网自建的合理等级；
///   要跨公网必须换 TLS/端到端加密，那属于云同步范畴，前期不做。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:hashlib/hashlib.dart';
import 'package:path_provider/path_provider.dart';

import 'database.dart';
import 'schema.dart';

/// 单张图片的体积上限。
const int kMaxPhotoBytes = 6 * 1024 * 1024;

/// 包版本。以后改结构必须升版本，旧版本收到就拒绝而不是猜。
const int kPackVersion = 1;

/// 6 位数字配对码。
String newPairCode() {
  final r = Random.secure();
  return List<int>.generate(6, (_) => r.nextInt(10)).join();
}

/// 解析用户手输的「IP:端口」，例如 `192.168.1.5:39481`。
///
/// 存在的理由：有些路由器会把多播/广播隔离掉，两端互相发现不了 ——
/// UDP 收不到包不等于连不上，HTTP 直连照样能通。所以给一条手动通道。
///
/// 返回 null 表示格式不对。端口只接受 1–65535，避免用户把配对码
/// 之类的东西误填进端口位。
({String host, int port})? parseManualEndpoint(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final colon = s.lastIndexOf(':');
  if (colon <= 0 || colon == s.length - 1) return null;
  final host = s.substring(0, colon).trim();
  final portText = s.substring(colon + 1).trim();
  if (host.isEmpty) return null;
  // 只接受 IPv4 或主机名，避免把带冒号的 IPv6 拆错（那要 [::1]:80 写法）
  if (host.contains(':')) return null;
  final port = int.tryParse(portText);
  if (port == null || port < 1 || port > 65535) return null;
  return (host: host, port: port);
}

/// 校验配对码。用等长比较，避免早退泄露前缀。
bool codeMatches(String expected, String actual) {
  if (expected.length != actual.length) return false;
  var diff = 0;
  for (var i = 0; i < expected.length; i++) {
    diff |= expected.codeUnitAt(i) ^ actual.codeUnitAt(i);
  }
  return diff == 0;
}

/// 打包结果：JSON 字符串 + 实际带上的图片数 + 被跳过的图片数。
class PackResult {
  const PackResult({
    required this.json,
    required this.photoCount,
    required this.skippedPhotos,
    required this.noteCount,
  });

  final String json;
  final int photoCount;
  final int skippedPhotos;
  final int noteCount;

  int get bytes => json.length;
}

/// 把一个笔记本连同它的信与插图打成 JSON。
Future<PackResult> buildPack({
  required EnvxDatabase db,
  required Notebook notebook,
}) async {
  final notes = await db.notes.list(notebook.id);
  var photoCount = 0;
  var skipped = 0;

  final notePayloads = <Map<String, Object?>>[];
  for (final note in notes) {
    final attachments = await db.attachments.listFor(note.id);
    final photos = <Map<String, Object?>>[];
    for (final att in attachments) {
      try {
        final file = File(att.path);
        if (!file.existsSync()) {
          skipped++;
          continue;
        }
        final len = file.lengthSync();
        if (len > kMaxPhotoBytes) {
          skipped++;
          continue;
        }
        final bytes = file.readAsBytesSync();
        photos.add({
          'name': att.path.split(Platform.pathSeparator).last,
          'b64': base64Encode(bytes),
          'sha256': sha256.hex(bytes),
        });
        photoCount++;
      } on Object {
        skipped++;
      }
    }
    notePayloads.add({
      'title': note.title,
      'body': note.body ?? '',
      'createdAt': note.createdAt,
      'updatedAt': note.updatedAt,
      'pinned': note.pinned,
      'photos': photos,
    });
  }

  final payload = {
    'version': kPackVersion,
    'notebook': {'name': notebook.name, 'color': notebook.color},
    'notes': notePayloads,
  };

  return PackResult(
    json: jsonEncode(payload),
    photoCount: photoCount,
    skippedPhotos: skipped,
    noteCount: notePayloads.length,
  );
}

/// 解析一个包。结构不对直接抛 [FormatException]，不做"尽力恢复"。
class EnvxPack {
  EnvxPack({
    required this.notebookName,
    required this.notebookColor,
    required this.notes,
  });

  final String notebookName;
  final String? notebookColor;
  final List<PackNote> notes;

  int get photoCount => notes.fold(0, (sum, n) => sum + n.photos.length);
}

class PackNote {
  PackNote({
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    required this.pinned,
    required this.photos,
  });

  final String? title;
  final String body;
  final int createdAt;
  final int updatedAt;
  final int pinned;
  final List<PackPhoto> photos;
}

class PackPhoto {
  PackPhoto({required this.name, required this.bytes, required this.sha256});

  final String name;
  final List<int> bytes;
  final String sha256;
}

EnvxPack parsePack(String json) {
  final raw = jsonDecode(json);
  if (raw is! Map<String, Object?>) {
    throw const FormatException('包不是对象');
  }
  final version = raw['version'];
  if (version != kPackVersion) {
    throw FormatException('包版本不支持：$version');
  }
  final nb = raw['notebook'];
  if (nb is! Map<String, Object?>) {
    throw const FormatException('缺 notebook');
  }
  final name = nb['name'];
  if (name is! String || name.isEmpty) {
    throw const FormatException('notebook.name 无效');
  }
  final color = nb['color'] as String?;

  final rawNotes = raw['notes'];
  if (rawNotes is! List) throw const FormatException('notes 不是数组');

  final notes = <PackNote>[];
  for (final item in rawNotes) {
    if (item is! Map<String, Object?>) {
      throw const FormatException('notes 元素无效');
    }
    final photos = <PackPhoto>[];
    final rawPhotos = item['photos'];
    if (rawPhotos is List) {
      for (final p in rawPhotos) {
        if (p is! Map<String, Object?>) continue;
        final b64 = p['b64'];
        if (b64 is! String) continue;
        final sha = p['sha256'];
        photos.add(PackPhoto(
          name: (p['name'] as String?) ?? 'photo.jpg',
          bytes: base64Decode(b64),
          sha256: sha is String ? sha : '',
        ));
      }
    }
    notes.add(PackNote(
      title: item['title'] as String?,
      body: (item['body'] as String?) ?? '',
      createdAt: (item['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (item['updatedAt'] as num?)?.toInt() ?? 0,
      pinned: (item['pinned'] as num?)?.toInt() ?? 0,
      photos: photos,
    ));
  }

  return EnvxPack(
    notebookName: name,
    notebookColor: color,
    notes: notes,
  );
}

/// 导入结果，用于给用户一句实话。
class ImportResult {
  const ImportResult({
    required this.notebookId,
    required this.noteCount,
    required this.photoCount,
    required this.badPhotos,
  });

  final String notebookId;
  final int noteCount;
  final int photoCount;

  /// 摘要对不上、被拒绝落盘的图片数。
  final int badPhotos;
}

/// 把解析好的包写进本地库。
///
/// 图片先写文件再用绝对路径入 attachment 表；摘要对不上的一律不写（宁可少一张图，也不留坏数据）。
Future<ImportResult> applyPack({
  required EnvxDatabase db,
  required EnvxPack pack,
  required String photosDir,
}) async {
  final notebook = await db.notebooks.create(
    name: pack.notebookName,
    color: pack.notebookColor,
  );

  var photoCount = 0;
  var badPhotos = 0;

  final dir = Directory(photosDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final nowMs = DateTime.now().millisecondsSinceEpoch;

  for (final note in pack.notes) {
    final created = await db.notes.createImported(
      notebookId: notebook.id,
      title: note.title,
      body: note.body,
      createdAt: note.createdAt > 0 ? note.createdAt : nowMs,
      updatedAt: note.updatedAt > 0 ? note.updatedAt : nowMs,
      pinned: note.pinned,
    );

    final paths = <String>[];
    for (final photo in note.photos) {
      if (photo.sha256.isNotEmpty) {
        final actual = sha256.hex(photo.bytes);
        if (actual != photo.sha256) {
          badPhotos++;
          continue;
        }
      }
      final safeName = photo.name.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final path = '$photosDir${Platform.pathSeparator}'
          '${DateTime.now().millisecondsSinceEpoch}_$safeName';
      try {
        await File(path).writeAsBytes(photo.bytes, flush: true);
        paths.add(path);
        photoCount++;
      } on Object {
        badPhotos++;
      }
    }
    if (paths.isNotEmpty) {
      await db.attachments.replaceFor(created.id, paths);
    }
  }

  return ImportResult(
    notebookId: notebook.id,
    noteCount: pack.notes.length,
    photoCount: photoCount,
    badPhotos: badPhotos,
  );
}

/// 默认插图目录（与 M6-C 的落盘位置保持一致）。
Future<String> defaultPhotosDir() async {
  final base = await getApplicationDocumentsDirectory();
  return '${base.path}${Platform.pathSeparator}photos';
}
