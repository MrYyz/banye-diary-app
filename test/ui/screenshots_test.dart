import 'dart:io';
import 'dart:ui' as ui;

import 'package:envx/core/kdf.dart';
import 'package:envx/data/database.dart';
import 'package:envx/data/photo_spot_store.dart';
import 'package:envx/data/salt_store.dart';
import 'package:envx/ui/screens/change_vault_pin_page.dart';
import 'package:envx/ui/screens/envelope_editor_page.dart';
import 'package:envx/ui/screens/home_page.dart';
import 'package:envx/ui/screens/lan_transfer_page.dart';
import 'package:envx/ui/screens/note_list_page.dart';
import 'package:envx/ui/screens/search_page.dart';
import 'package:envx/ui/theme.dart';
import 'package:envx/ui/screens/settings_page.dart';
import 'package:envx/ui/screens/vault_gate_page.dart';
import 'package:envx/ui/screens/vault_home_page.dart';
import 'package:envx/ui/unlock_page.dart';
import 'package:envx/ui/widgets/sticker_photo.dart';
import 'package:envx/ui/widgets/time_fmt.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// M2 UI 截图证据：两套尺寸（手机 390×844 / 平板 1024×1366），
/// 覆盖开锁、首页、笔记列表、搜索有结果、搜索无结果、空态。
///
/// 三条硬约束（都是踩坑换来的，改动前先读）：
/// 1. 截图只走官方 golden 路径 matchesGoldenFile。自己调
///    RenderRepaintBoundary.toImage 在 fake-async 区里会等帧不返回，
///    表现为测试停在用例名上、CPU 归零，看着像死锁。
/// 2. 建库 / seed / 页面查询全是真实 IO，必须包进 tester.runAsync。
///    直接在 testWidgets 的 body 里 await 会永久挂住。
/// 3. 不用 pumpAndSettle：页面 loading 态里的无限转圈会让它等到超时。

const _letterBody = '最后一道大题我明明会做，却在收尾的时候把负号丢了。'
    '收卷铃响的时候，我盯着那道题看了很久，脑子里一片空白。\n\n'
    '走出考场，走廊里全是别人对答案的声音。我没敢凑过去，直接从后门绕到操场。\n\n'
    '放学路上一直在想这件事，越想越气。风把校服吹得鼓起来，也没有让我好受一点。\n\n'
    '不过回家后妈妈什么也没问，只是把切好的苹果放在我桌上，说了句“先吃点东西”。'
    '我突然就不那么气了。\n\n'
    '下次收尾之前，检查两遍吧。';

const _sizes = [
  ('phone', 390.0, 844.0),
  ('tablet', 1024.0, 1366.0),
];

/// 截图用例默认不跑，避免污染常规测试：
/// 笔记列表 / 搜索页会显示笔记的创建时刻（17:01 这种），
/// 每次运行时间不同，golden 像素比对必然漂移失败，与代码正确性无关。
/// 出图时用：ENVX_SHOTS=1 flutter test --update-goldens test/ui/screenshots_test.dart
final bool _shotsEnabled = Platform.environment['ENVX_SHOTS'] == '1';

String? _fontFamily;

/// 截图里所有"现在"都钉在这一刻，否则跨天 / 跨小时 golden 必红。
final DateTime _fixedNow = DateTime(2026, 11, 17, 23, 4);
final int _fixedNowMs = _fixedNow.millisecondsSinceEpoch;

Future<String?> _loadChineseFont() async {
  const candidates = [
    r'C:\Windows\Fonts\msyh.ttc',
    r'C:\Windows\Fonts\simhei.ttf',
    r'C:\Windows\Fonts\simsun.ttc',
    r'C:\Windows\Fonts\Deng.ttf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    try {
      final bytes = await file.readAsBytes();
      await ui.loadFontFromList(bytes, fontFamily: 'EnvXChinese');
      return 'EnvXChinese';
    } catch (_) {
      continue;
    }
  }
  return null;
}

/// test 环境不会自动带 MaterialIcons，缺了它所有 Icon 都渲染成方块。
Future<void> _loadIconFont() async {
  final exeCacheRoot =
      File(Platform.resolvedExecutable).parent.parent.parent.path;
  final candidates = <String>[
    if ((Platform.environment['FLUTTER_ROOT'] ?? '').isNotEmpty)
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '$exeCacheRoot/artifacts/material_fonts/MaterialIcons-Regular.otf',
    r'D:\APP\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    try {
      await ui.loadFontFromList(
        await file.readAsBytes(),
        fontFamily: 'MaterialIcons',
      );
      return;
    } catch (_) {
      continue;
    }
  }
}

Future<EnvxDatabase> _openDb(Directory dir, String password) async {
  final salt = await SaltStore(dir: dir).loadOrCreate('app.db');
  final key = deriveKey(
    password: password,
    salt: salt,
    params: KdfParams.light,
  ).keyBytes;
  return openEnvxDatabase(dir: dir, key32: key, clock: () => _fixedNowMs);
}

Future<void> _seed(EnvxDatabase db) async {
  final nb1 = await db.notebooks.create(name: '日常碎片', color: 'sun');
  await db.notebooks.create(name: '数学错题', color: 'sky');
  await db.notebooks.create(name: '读书摘抄', color: 'blush');

  await db.notes.create(
    notebookId: nb1.id,
    title: '今天数学考砸了',
    body: '最后一道大题我明明会做，收尾时把负号丢了',
  );
  await db.notes.create(
    notebookId: nb1.id,
    title: '周五要不要去看那部电影',
    body: '听说片尾有彩蛋，我查了场次是七点半',
  );
  await db.notes.create(
    notebookId: nb1.id,
    title: '关于那件小事',
    body: '其实我早就没生气了，只是不知道怎么开口',
  );
  await db.notes.create(
    notebookId: nb1.id,
    title: '课间十分钟',
    body: '走廊的窗户今天特别亮，像被谁擦过',
  );
}

Widget _app(Widget home, GlobalKey boundaryKey) {
  final base = EnvxTheme.build();
  final theme = _fontFamily == null
      ? base
      : base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: _fontFamily),
          primaryTextTheme:
              base.primaryTextTheme.apply(fontFamily: _fontFamily),
        );
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: RepaintBoundary(key: boundaryKey, child: home),
  );
}

/// 真实 IO 全部走 runAsync，并在回到 fake-async 区后补一帧。
Future<void> _settleWithIo(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _shoot(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name,
) async {
  // flutter_test 默认把阴影画成实心黑，FAB 会顶一圈粗黑边。
  // 这是全局 debug 变量，只能在用例内临时改、截完立刻复原 —
  // 留在 setUpAll 里改会被收尾的不变量检查判失败。
  debugDisableShadows = false;
  try {
    await _settleWithIo(tester);
    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('goldens/$name.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

/// 弹窗（底部菜单、配色选择）挂在 Overlay 上，页面自身的 RepaintBoundary
/// 抓不到，所以这类截图直接抓 Overlay 的 render object。
Future<void> _shootOverlay(WidgetTester tester, String name) async {
  debugDisableShadows = false;
  try {
    await _settleWithIo(tester);
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/$name.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

/// 起一个临时库，seed 可选；teardown 里关库并删目录，避免 Windows 文件锁。
Future<EnvxDatabase> _bootDb(
  WidgetTester tester,
  String tag, {
  bool seed = true,
}) async {
  final dir = Directory.systemTemp.createTempSync('envx_shot_${tag}_');
  final db = await tester.runAsync(() async {
    final opened = await _openDb(dir, '123456');
    if (seed) await _seed(opened);
    return opened;
  });
  addTearDown(() async {
    await db!.close();
    dir.deleteSync(recursive: true);
  });
  return db!;
}

void _setSurface(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    await _loadIconFont();
    _fontFamily = await _loadChineseFont();
  });

  setUp(() => TimeFmt.overrideNow = _fixedNow);
  tearDown(() => TimeFmt.overrideNow = null);

  for (final (tag, w, h) in _sizes) {
    group('$tag ${w}x$h', () {
      testWidgets('开锁页', (tester) async {
        _setSurface(tester, w, h);
        final dir = Directory.systemTemp.createTempSync('envx_shot_unlock_');
        EnvxDatabase? db;
        addTearDown(() async {
          await db?.close();
          dir.deleteSync(recursive: true);
        });

        final key = GlobalKey();
        await tester.pumpWidget(
          _app(
            UnlockPage(
              dirProvider: () async => dir,
              kdfParams: KdfParams.light,
              onUnlocked: (opened) => db = opened,
            ),
            key,
          ),
        );
        await _shoot(tester, key, 'unlock_$tag');
      });

      testWidgets('首页：3 个笔记本', (tester) async {
        _setSurface(tester, w, h);
        final db = await _bootDb(tester, 'home');

        final key = GlobalKey();
        await tester.pumpWidget(_app(HomePage(db: db), key));
        await _shoot(tester, key, 'home_$tag');
      });

      testWidgets('笔记列表：4 封信', (tester) async {
        _setSurface(tester, w, h);
        final db = await _bootDb(tester, 'notes');
        final notebooks =
            (await tester.runAsync(() => db.notebooks.all()))!;

        final key = GlobalKey();
        await tester.pumpWidget(
          _app(NoteListPage(db: db, notebook: notebooks.first), key),
        );
        await _shoot(tester, key, 'notes_$tag');
      });

      testWidgets('搜索：有结果', (tester) async {
        _setSurface(tester, w, h);
        final db = await _bootDb(tester, 'hit');

        final key = GlobalKey();
        await tester.pumpWidget(_app(SearchPage(db: db), key));
        await tester.enterText(find.byType(TextField).first, '数学');
        await _shoot(tester, key, 'search_hit_$tag');
      });

      testWidgets('搜索：无结果', (tester) async {
        _setSurface(tester, w, h);
        final db = await _bootDb(tester, 'miss');

        final key = GlobalKey();
        await tester.pumpWidget(_app(SearchPage(db: db), key));
        await tester.enterText(find.byType(TextField).first, '不存在的词xyz');
        await _shoot(tester, key, 'search_miss_$tag');
      });

      testWidgets('空态：无笔记本', (tester) async {
        _setSurface(tester, w, h);
        final db = await _bootDb(tester, 'empty', seed: false);

        final key = GlobalKey();
        await tester.pumpWidget(_app(HomePage(db: db), key));
        await _shoot(tester, key, 'empty_home_$tag');
      });

      testWidgets('信封编辑页', (tester) async {
        _setSurface(tester, w, h);
        final db = await _bootDb(tester, 'editor');
        final notebooks =
            (await tester.runAsync(() => db.notebooks.all()))!;
        final notes = (await tester.runAsync(
          () => db.notes.list(notebooks.first.id),
        ))!;
        final nb = notebooks.first;
        final note = notes.first;

        await tester.runAsync(
          () => db.notes.save(note.id, body: _letterBody),
        );
        final fresh =
            (await tester.runAsync(() => db.notes.get(note.id)))!;

        final key = GlobalKey();
        await tester.pumpWidget(
          _app(EnvelopeEditorPage(db: db, notebook: nb, note: fresh), key),
        );
        await _shoot(tester, key, 'editor_$tag');
      });

      testWidgets('信封编辑页：带插图', (tester) async {
        _setSurface(tester, w, h);
        final db = await _bootDb(tester, 'editor_photo');
        final notebooks =
            (await tester.runAsync(() => db.notebooks.all()))!;
        final notes = (await tester.runAsync(
          () => db.notes.list(notebooks.first.id),
        ))!;
        final id = notes.first.id;
        final fresh = (await tester.runAsync(() async {
          await db.notes.save(id, body: _letterBody);
          return db.notes.get(id);
        }))!;
        final photo = File('${Directory.current.path}/M1-开锁页.png');
        expect(photo.existsSync(), isTrue, reason: '缺测试插图 M1-开锁页.png');

        // 在真实事件循环里手动解码，再按路径注入给页面。
        // 不走 Image.file 的异步解码：headless golden 里那个 future 不完成，
        // 只能拿到空白白边（M3 报告第五节第 2 条）。
        final bytes = (await tester.runAsync(() => photo.readAsBytes()))!;
        final codec =
            (await tester.runAsync(() => ui.instantiateImageCodec(bytes)))!;
        final frame = (await tester.runAsync(() => codec.getNextFrame()))!;

        final key = GlobalKey();
        await tester.pumpWidget(
          _app(
            EnvelopeEditorPage(
              db: db,
              notebook: notebooks.first,
              note: fresh,
              initialPhotos: [photo],
              decodedPhotos: {photo.path: frame.image},
            ),
            key,
          ),
        );
        // 解码已同步注入（走 RawImage），推一帧把开封动效走完即可。
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await _shoot(tester, key, 'editor_photo_$tag');
      });

      testWidgets('编辑页：排版面板', (tester) async {
        _setSurface(tester, w, h);
        final db = await _bootDb(tester, 'editor_sheet');
        final notebooks =
            (await tester.runAsync(() => db.notebooks.all()))!;
        final notes = (await tester.runAsync(
          () => db.notes.list(notebooks.first.id),
        ))!;
        final fresh = (await tester.runAsync(() async {
          await db.notes.save(notes.first.id, body: _letterBody);
          return db.notes.get(notes.first.id);
        }))!;

        final key = GlobalKey();
        await tester.pumpWidget(
          _app(
            EnvelopeEditorPage(
              db: db,
              notebook: notebooks.first,
              note: fresh,
            ),
            key,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(
          find.byKey(const ValueKey('editor-typography')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await _shootOverlay(tester, 'editor_sheet_$tag');
      });

      testWidgets('编辑页：图衬在文字下方', (tester) async {
        _setSurface(tester, w, h);
        final db = await _bootDb(tester, 'editor_wrap');
        final notebooks =
            (await tester.runAsync(() => db.notebooks.all()))!;
        final notes = (await tester.runAsync(
          () => db.notes.list(notebooks.first.id),
        ))!;
        final id = notes.first.id;
        final fresh = (await tester.runAsync(() async {
          await db.notes.save(id, body: _letterBody);
          return db.notes.get(id);
        }))!;
        final photo = File('${Directory.current.path}/M1-开锁页.png');
        expect(photo.existsSync(), isTrue);

        final bytes = (await tester.runAsync(() => photo.readAsBytes()))!;
        final codec =
            (await tester.runAsync(() => ui.instantiateImageCodec(bytes)))!;
        final frame = (await tester.runAsync(() => codec.getNextFrame()))!;

        // 把这张图摆在正文中段，环绕方式 = 衬在文字下方。
        final key = GlobalKey();
        await tester.pumpWidget(
          _app(
            EnvelopeEditorPage(
              db: db,
              notebook: notebooks.first,
              note: fresh,
              initialPhotos: [photo],
              decodedPhotos: {photo.path: frame.image},
              initialSpots: {
                photo.path: const PhotoSpot(
                  x: 96,
                  y: 300,
                  wrap: PhotoWrap.below,
                ),
              },
            ),
            key,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await _shoot(tester, key, 'editor_wrap_$tag');
      });

      testWidgets('贴纸插图（已解码图）', (tester) async {
        _setSurface(tester, w, h);
        final photo = File('${Directory.current.path}/M1-开锁页.png');
        expect(photo.existsSync(), isTrue);

        final bytes = (await tester.runAsync(() => photo.readAsBytes()))!;
        final codec =
            (await tester.runAsync(() => ui.instantiateImageCodec(bytes)))!;
        final frame = (await tester.runAsync(() => codec.getNextFrame()))!;

        final key = GlobalKey();
        await tester.pumpWidget(
          _app(
            Container(
              color: const Color(0xFFDDEEE8),
              padding: const EdgeInsets.all(40),
              alignment: Alignment.topLeft,
              child: StickerPhoto(file: photo, decoded: frame.image),
            ),
            key,
          ),
        );
        await _shoot(tester, key, 'sticker_$tag');
      });

      testWidgets('隐藏区：设置密码', (tester) async {
        _setSurface(tester, w, h);
        final dir = Directory.systemTemp.createTempSync('envx_shot_vgate_');
        addTearDown(() => dir.deleteSync(recursive: true));

        final key = GlobalKey();
        await tester.pumpWidget(
          _app(VaultGatePage(dir: dir, kdfParams: KdfParams.light), key),
        );
        // _detect 查一次文件是否存在，是真实 IO。
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump();
        await _shoot(tester, key, 'vault_gate_$tag');
      });

      testWidgets('隐藏区：2 个本子', (tester) async {
        _setSurface(tester, w, h);
        final dir = Directory.systemTemp.createTempSync('envx_shot_vhome_');
        final db = (await tester.runAsync(() async {
          final salt = await SaltStore(dir: dir).loadOrCreate('vault.db');
          final key = deriveKey(
            password: '222222',
            salt: salt,
            params: KdfParams.light,
          ).keyBytes;
          final opened = await openEnvxDatabase(
            dir: dir,
            key32: key,
            fileName: 'vault.db',
          );
          final nb1 = await opened.notebooks.create(name: '不给任何人看');
          await opened.notebooks.create(name: '那件事', color: 'blush');
          await opened.notes.create(
            notebookId: nb1.id,
            title: '其实我一直没忘',
            body: '只是不再提',
          );
          await opened.notes.create(
            notebookId: nb1.id,
            title: '那天晚上的雨',
            body: '下得很大',
          );
          return opened;
        }))!;
        addTearDown(() async {
          await db.close();
          dir.deleteSync(recursive: true);
        });

        final key = GlobalKey();
        await tester.pumpWidget(_app(VaultHomePage(db: db), key));
        await _shoot(tester, key, 'vault_home_$tag');
      });

      testWidgets('局域网互传', (tester) async {
        _setSurface(tester, w, h);
        final dir = Directory.systemTemp.createTempSync('envx_shot_lan_');
        final db = (await tester.runAsync(() async {
          final opened = await _openDb(dir, '123456');
          await _seed(opened);
          return opened;
        }))!;
        addTearDown(() async {
          await db.close();
          dir.deleteSync(recursive: true);
        });

        final key = GlobalKey();
        await tester.pumpWidget(
          // 配对码钉死，否则每次随机、golden 必然漂移。
          _app(LanTransferPage(
        db: db,
        dir: dir,
        code: '482915',
        localAddr: '192.168.1.7:39481',
      ), key),
        );
        // _boot 会真起 HTTP + UDP 服务，是真实 IO，必须进真实事件循环。
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 600)),
        );
        await tester.pump();
        await _shoot(tester, key, 'lan_transfer_$tag');
      });
      testWidgets('设置页', (tester) async {
        _setSurface(tester, w, h);
        final dir = Directory.systemTemp.createTempSync('envx_shot_set_');
        addTearDown(() => dir.deleteSync(recursive: true));

        // 先真建一个隐藏区库，让「隐藏区密码」这一行显示真实状态，
        // 否则截出来是「未设置」，和实际设备上的样子不一致。
        await tester.runAsync(() async {
          final salt = await SaltStore(dir: dir).loadOrCreate('vault.db');
          final key = deriveKey(
            password: '222222',
            salt: salt,
            params: KdfParams.light,
          ).keyBytes;
          final db = await openEnvxDatabase(
            dir: dir,
            key32: key,
            fileName: 'vault.db',
          );
          await db.close();
        });

        final key = GlobalKey();
        await tester.pumpWidget(_app(SettingsPage(dir: dir), key));
        // 设置页要先读一次 settings.json，是真实 IO。
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump();
        await _shoot(tester, key, 'settings_$tag');
      });

      testWidgets('首页：笔记本长按菜单', (tester) async {
        _setSurface(tester, w, h);
        final db = await _bootDb(tester, 'menu');

        final key = GlobalKey();
        await tester.pumpWidget(_app(HomePage(db: db), key));
        await _settleWithIo(tester);

        // 长按一张卡片，拉起「换封面色 / 移到隐藏区 / 删除」菜单。
        await tester.longPress(find.text('日常碎片').first);
        await _shootOverlay(tester, 'menu_$tag');
      });

      testWidgets('设置页：信封配色', (tester) async {
        _setSurface(tester, w, h);
        final dir = Directory.systemTemp.createTempSync('envx_shot_scheme_');
        addTearDown(() => dir.deleteSync(recursive: true));

        final key = GlobalKey();
        await tester.pumpWidget(_app(SettingsPage(dir: dir), key));
        // 先等 settings.json 读完，否则点不动那几行。
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump();

        await tester.tap(find.text('信封配色'));
        await _shootOverlay(tester, 'scheme_$tag');
      });

      testWidgets('改隐藏区密码：第一步', (tester) async {
        _setSurface(tester, w, h);
        final dir = Directory.systemTemp.createTempSync('envx_shot_changepin_');
        addTearDown(() => dir.deleteSync(recursive: true));

        final key = GlobalKey();
        await tester.pumpWidget(
          _app(
            ChangeVaultPinPage(dir: dir, kdfParams: KdfParams.light),
            key,
          ),
        );
        await _shoot(tester, key, 'change_pin_$tag');
      });
    }, skip: !_shotsEnabled);
  }

  // 平板是横屏主姿态（1024×1366 竖屏看不出来真实观感）：
  // 单独给互传页出一张横屏图，只这一屏，不进上面的 _sizes 循环。
  testWidgets('局域网互传：平板横屏', (tester) async {
    _setSurface(tester, 1366, 1024);
    final dir = Directory.systemTemp.createTempSync('envx_shot_lanls_');
    final db = (await tester.runAsync(() async {
      final opened = await _openDb(dir, '123456');
      await _seed(opened);
      return opened;
    }))!;
    addTearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    final key = GlobalKey();
    await tester.pumpWidget(
      _app(LanTransferPage(
        db: db,
        dir: dir,
        code: '482915',
        localAddr: '192.168.1.7:39481',
      ), key),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 600)),
    );
    await tester.pump();
    await _shoot(tester, key, 'lan_transfer_landscape');
  }, skip: !_shotsEnabled);
}
