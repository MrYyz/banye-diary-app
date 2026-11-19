import 'dart:io';

import 'package:envx/data/photo_janitor.dart';
import 'package:flutter_test/flutter_test.dart';

/// 插图孤儿文件清理：只删没登记过的、且已经"凉"了的文件。
void main() {
  test('删掉表里没有的旧文件，保留已登记的与刚写入的', () async {
    final root = Directory.systemTemp.createTempSync('envx_janitor_');
    addTearDown(() => root.deleteSync(recursive: true));
    final photos = Directory('${root.path}/envx_photos')..createSync();

    final kept = File('${photos.path}/111_kept.jpg')..writeAsBytesSync([1]);
    final orphanOld = File('${photos.path}/222_orphan.jpg')
      ..writeAsBytesSync([2]);
    final orphanFresh = File('${photos.path}/333_fresh.jpg')
      ..writeAsBytesSync([3]);

    // 把两个孤儿文件的修改时间推到 2 小时前，模拟"早就没用了"。
    final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
    for (final f in [orphanOld, orphanFresh]) {
      await f.setLastModified(twoHoursAgo);
    }

    final janitor = PhotoJanitor(
      photosDir: photos,
      registeredPaths: () async => [kept.path],
    );

    // 让"新鲜"那个文件是刚刚写的，另一个是旧的。
    await orphanFresh.setLastModified(DateTime.now());

    final removed = await janitor.sweep();

    expect(removed, 1, reason: '只该删掉那个又旧又没登记的');
    expect(await kept.exists(), isTrue, reason: '已登记的不能删');
    expect(await orphanOld.exists(), isFalse, reason: '旧的孤儿文件应被清掉');
    expect(await orphanFresh.exists(), isTrue, reason: '刚写入的一律跳过');
  });

  test('目录不存在时返回 0，不报错也不创建目录', () async {
    final root = Directory.systemTemp.createTempSync('envx_janitor_none_');
    addTearDown(() => root.deleteSync(recursive: true));
    final missing = Directory('${root.path}/nope');

    final janitor = PhotoJanitor(
      photosDir: missing,
      registeredPaths: () async => const [],
    );

    expect(await janitor.sweep(), 0);
    expect(await missing.exists(), isFalse);
  });

  test('路径分隔符与大小写不同也算已登记，不会误删', () async {
    final root = Directory.systemTemp.createTempSync('envx_janitor_case_');
    addTearDown(() => root.deleteSync(recursive: true));
    final photos = Directory('${root.path}/envx_photos')..createSync();
    final file = File('${photos.path}/444_photo.jpg')..writeAsBytesSync([4]);
    await file.setLastModified(
      DateTime.now().subtract(const Duration(hours: 3)),
    );

    final janitor = PhotoJanitor(
      photosDir: photos,
      // 故意用反斜杠 + 大写，模拟 Windows 上路径写法不统一。
      registeredPaths: () async => [file.path.replaceAll('/', r'\').toUpperCase()],
    );

    expect(await janitor.sweep(), 0);
    expect(await file.exists(), isTrue);
  });
}
