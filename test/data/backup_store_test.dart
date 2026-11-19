import 'dart:io';

import 'package:envx/data/backup_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// 整库备份/恢复。
///
/// 用临时目录模拟 App 私有目录与外部目录，不碰真机数据。
void main() {
  late Directory support;
  late Directory photos;
  late Directory target;
  late BackupStore store;

  setUp(() {
    support = Directory.systemTemp.createTempSync('envx_bk_sup_');
    photos = Directory.systemTemp.createTempSync('envx_bk_pho_');
    target = Directory.systemTemp.createTempSync('envx_bk_tgt_');
    store = BackupStore(
      supportDir: support,
      photosDir: photos,
      targetDir: target,
    );
  });

  tearDown(() {
    for (final d in [support, photos, target]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  void put(String name, String text) {
    File('${support.path}/$name').writeAsStringSync(text);
  }

  test('备份把库、盐、设备密钥、设置与插图都拷进去', () async {
    put('app.db', 'db-bytes');
    put('app.db.salt', 'salt-bytes');
    put('app.db.devicekey', 'key-bytes');
    put('settings.json', '{}');
    put('photo_spots.json', '{}');
    File('${support.path}/app.db.tmp').writeAsStringSync('half-written');
    File('${photos.path}/p1.jpg').writeAsBytesSync([1, 2, 3]);

    final info = await store.create(now: DateTime(2026, 11, 18, 17, 30));

    expect(info.name, '20261118-173000');
    final dest = Directory(info.path);
    expect(File('${dest.path}/app.db').existsSync(), isTrue);
    expect(File('${dest.path}/app.db.salt').existsSync(), isTrue);
    expect(File('${dest.path}/app.db.devicekey').existsSync(), isTrue);
    expect(File('${dest.path}/photo_spots.json').existsSync(), isTrue);
    // 写一半的临时文件不能进备份
    expect(File('${dest.path}/app.db.tmp').existsSync(), isFalse);
    expect(File('${dest.path}/photos/p1.jpg').existsSync(), isTrue);
    expect(info.bytes, greaterThan(0));
  });

  test('list 按时间倒序，能读到份数与大小', () async {
    await store.create(now: DateTime(2026, 11, 18, 9, 0, 0));
    await store.create(now: DateTime(2026, 11, 18, 17, 0, 0));
    final list = await store.list();
    expect(list.length, 2);
    expect(list.first.name.startsWith('20261118-1700'), isTrue);
    expect(list.first.sizeText.isNotEmpty, isTrue);
  });

  test('恢复会把现存的库改名封存，不删除', () async {
    put('app.db', 'old-db');
    final info = await store.create(now: DateTime(2026, 11, 18, 8, 0, 0));

    // 备份之后又写了新内容
    put('app.db', 'new-db');

    await store.restore(info, now: DateTime(2026, 11, 18, 18, 0, 0));

    expect(
      File('${support.path}/app.db').readAsStringSync(),
      'old-db',
      reason: '恢复后应是备份里的内容',
    );
    final left = support
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('.before-restore-'))
        .toList();
    expect(left.length, greaterThanOrEqualTo(1), reason: '旧库要留一份');
    expect(left.first.readAsStringSync(), 'new-db');
  });

  test('空目录也能备份，不抛异常', () async {
    final info = await store.create(now: DateTime(2026, 11, 18, 7, 0, 0));
    expect(Directory(info.path).existsSync(), isTrue);
    expect((await store.list()).length, 1);
  });
}
