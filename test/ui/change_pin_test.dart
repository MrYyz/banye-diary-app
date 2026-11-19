import 'dart:io';
import 'dart:typed_data';

import 'package:envx/core/kdf.dart';
import 'package:envx/data/database.dart';
import 'package:envx/data/salt_store.dart';
import 'package:envx/ui/screens/change_vault_pin_page.dart';
import 'package:envx/ui/screens/vault_gate_page.dart' show kVaultFileName;
import 'package:envx/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _oldPin = '111111';
const _newPin = '222222';

/// widget test 的 fake-async 区推不动 compute，这里换成同步派生
/// （Argon2 light 一档在桌面约百毫秒，够快）。
Future<Uint8List> _fastDerive(
  String password,
  Uint8List salt,
  KdfParams params,
) async =>
    deriveKey(password: password, salt: salt, params: KdfParams.light).keyBytes;

Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (final ch in pin.split('')) {
    await tester.tap(find.text(ch));
    await tester.pump();
  }
}

Future<void> _settle(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 40; i++) {
    if (done()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump();
  }
}

void main() {
    testWidgets('改密码：错旧密码挡住、两次不一致挡住、成功后旧密码失效',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dir = Directory.systemTemp.createTempSync('envx_change_pin_');
    addTearDown(() => dir.deleteSync(recursive: true));

    // 先建一个用 _oldPin 加密的隐藏库，放一封信进去。
    // 建库是真 IO，必须走 runAsync：fake-async 区里 dir.exists() 永不返回。
    final saltStore = SaltStore(dir: dir);
    String nbId = '';
    await tester.runAsync(() async {
      final salt = await saltStore.loadOrCreate(kVaultFileName);
      final oldKey = deriveKey(
        password: _oldPin,
        salt: salt,
        params: KdfParams.light,
      ).keyBytes;
      final seeded = await openEnvxDatabase(
        dir: dir,
        key32: oldKey,
        fileName: kVaultFileName,
      );
      final nb = await seeded.notebooks.create(name: '不给任何人看');
      nbId = nb.id;
      await seeded.notes.create(
        notebookId: nb.id,
        title: '那件事',
        body: '只有我知道。',
      );
      await seeded.close();
    });

    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: EnvxTheme.build(),
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav
        .push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => ChangeVaultPinPage(
              dir: dir,
              kdfParams: KdfParams.light,
              derive: _fastDerive,
            ),
          ),
        )
        .then((value) => result = value);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('改隐藏区密码'), findsOneWidget);

    // 1) 旧密码输错：挡住，且不改任何东西。
    await _enterPin(tester, '999999');
    await _settle(tester, () => find.text('密码不对').evaluate().isNotEmpty);
    expect(find.text('密码不对'), findsOneWidget, reason: '错旧密码必须挡住');

    // 2) 输对旧密码：进入"设新密码"。
    await _enterPin(tester, _oldPin);
    await _settle(
      tester,
      () => find.text('设一个新密码').evaluate().isNotEmpty,
    );
    expect(find.text('设一个新密码'), findsOneWidget);

    // 3) 新密码第一次 + 第二次输不同的：退回重输。
    await _enterPin(tester, _newPin);
    await tester.pump();
    await _enterPin(tester, '333333');
    await tester.pump();
    expect(find.text('两次不一致，重新输新密码'), findsOneWidget);
    expect(find.text('设一个新密码'), findsOneWidget, reason: '应退回第一步');

    // 4) 两次一致：执行换钥匙并返回 true。
    await _enterPin(tester, _newPin);
    await tester.pump();
    await _enterPin(tester, _newPin);
    await _settle(tester, () => result == true);
    expect(result, isTrue, reason: '成功后应返回 true');

    // 5) 数据层复核：旧密码打不开，新密码能读回那封信。
    String freshBody = '';
    var staleRejected = false;
    await tester.runAsync(() async {
      final newSalt = (await saltStore.read(kVaultFileName))!;
      final staleKey = deriveKey(
        password: _oldPin,
        salt: newSalt,
        params: KdfParams.light,
      ).keyBytes;
      try {
        final stale = await openEnvxDatabase(
          dir: dir,
          key32: staleKey,
          fileName: kVaultFileName,
        );
        await stale.close();
      } on WrongKeyException {
        staleRejected = true;
      }

      final freshKey = deriveKey(
        password: _newPin,
        salt: newSalt,
        params: KdfParams.light,
      ).keyBytes;
      final reopened = await openEnvxDatabase(
        dir: dir,
        key32: freshKey,
        fileName: kVaultFileName,
      );
      final notes = await reopened.notes.list(nbId);
      freshBody = notes.isEmpty ? '' : (notes.first.body ?? '');
      await reopened.close();
    });

    expect(staleRejected, isTrue, reason: '旧密码在新盐下必须打不开');
    expect(freshBody, '只有我知道。', reason: '新密码应能读回原信件');
  });
}
