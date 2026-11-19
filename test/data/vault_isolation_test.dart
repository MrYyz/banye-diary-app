import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:envx/core/kdf.dart';
import 'package:envx/data/database.dart';
import 'package:envx/data/salt_store.dart';

/// M4 隐藏区的数据层验收：
/// 1) vault.db 与 app.db 各自独立的盐、独立的密钥、独立的文件；
/// 2) 两边的笔记本互不可见；
/// 3) 用错密码开对方的库，抛 WrongKeyException。
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('envx_vault_');
  });

  tearDown(() {
    dir.deleteSync(recursive: true);
  });

  test('两个库密码与数据完全隔离，互开都失败', () async {
    final salts = SaltStore(dir: dir);
    final appSalt = await salts.loadOrCreate('app.db');
    final vaultSalt = await salts.loadOrCreate('vault.db');

    expect(appSalt, isNot(equals(vaultSalt)), reason: '两个库不能共用盐');

    final appKey = deriveKey(
      password: '111111',
      salt: appSalt,
      params: KdfParams.light,
    ).keyBytes;
    final vaultKey = deriveKey(
      password: '222222',
      salt: vaultSalt,
      params: KdfParams.light,
    ).keyBytes;

    final app = await openEnvxDatabase(dir: dir, key32: appKey);
    final vault = await openEnvxDatabase(
      dir: dir,
      key32: vaultKey,
      fileName: 'vault.db',
    );

    await app.notebooks.create(name: '明面上的', color: 'sun');
    await vault.notebooks.create(name: '不肯给人看的', color: 'mint');

    final appNames = (await app.notebooks.all()).map((b) => b.name).toList();
    final vaultNames = (await vault.notebooks.all()).map((b) => b.name).toList();
    expect(appNames, ['明面上的']);
    expect(vaultNames, ['不肯给人看的']);

    await app.close();
    await vault.close();

    // 主密码开不了隐藏库
    await expectLater(
      openEnvxDatabase(dir: dir, key32: appKey, fileName: 'vault.db'),
      throwsA(isA<WrongKeyException>()),
    );
    // 隐藏密码也开不了主库
    await expectLater(
      openEnvxDatabase(dir: dir, key32: vaultKey),
      throwsA(isA<WrongKeyException>()),
    );
  });

  test('盘上四个文件各自存在：两个库 + 两个盐 sidecar', () async {
    final salts = SaltStore(dir: dir);
    final appSalt = await salts.loadOrCreate('app.db');
    final vaultSalt = await salts.loadOrCreate('vault.db');

    final appKey = deriveKey(
      password: '111111',
      salt: appSalt,
      params: KdfParams.light,
    ).keyBytes;
    final vaultKey = deriveKey(
      password: '222222',
      salt: vaultSalt,
      params: KdfParams.light,
    ).keyBytes;

    final app = await openEnvxDatabase(dir: dir, key32: appKey);
    final vault = await openEnvxDatabase(
      dir: dir,
      key32: vaultKey,
      fileName: 'vault.db',
    );
    await app.close();
    await vault.close();

    for (final name in ['app.db', 'app.db.salt', 'vault.db', 'vault.db.salt']) {
      expect(
        File('${dir.path}/$name').existsSync(),
        isTrue,
        reason: '$name 应该存在',
      );
    }
  });
}
