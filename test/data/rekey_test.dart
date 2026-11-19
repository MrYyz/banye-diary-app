import 'dart:io';

import 'package:envx/core/kdf.dart';
import 'package:envx/data/database.dart';
import 'package:envx/data/salt_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// 改隐藏区密码的技术底座：`PRAGMA rekey` 能不能在同一文件上换密钥，
/// 且数据一行不丢。这条不成立，就不能做「修改密码」这个功能。
void main() {
  test('rekey 后旧密钥打不开、新密钥能读回原来的信件', () async {
    final dir = Directory.systemTemp.createTempSync('envx_rekey_');
    addTearDown(() => dir.deleteSync(recursive: true));

    final saltStore = SaltStore(dir: dir);
    final oldSalt = await saltStore.loadOrCreate('vault.db');
    final oldKey = deriveKey(
      password: '111111',
      salt: oldSalt,
      params: KdfParams.light,
    ).keyBytes;

    // 建库并写入一封，留下可验证的数据。
    final created = await openEnvxDatabase(
      dir: dir,
      key32: oldKey,
      fileName: 'vault.db',
    );
    final nb = await created.notebooks.create(name: '不给任何人看');
    await created.notes.create(
      notebookId: nb.id,
      title: '那件事',
      body: '写在这里，只有我知道。',
    );
    await created.close();

    // 换密码：新盐 + 新密码派生新密钥。
    final newSalt = randomSalt(16);
    final newKey = deriveKey(
      password: '222222',
      salt: newSalt,
      params: KdfParams.light,
    ).keyBytes;

    await rekeyEnvxDatabase(
      dir: dir,
      oldKey32: oldKey,
      newKey32: newKey,
      fileName: 'vault.db',
    );
    await saltStore.write('vault.db', newSalt);

    // 旧密钥现在必须打不开。
    await expectLater(
      openEnvxDatabase(dir: dir, key32: oldKey, fileName: 'vault.db'),
      throwsA(isA<WrongKeyException>()),
    );

    // 新密钥能打开，且数据还在。
    final reopened = await openEnvxDatabase(
      dir: dir,
      key32: newKey,
      fileName: 'vault.db',
    );
    addTearDown(reopened.close);
    final notebooks = await reopened.notebooks.all();
    expect(notebooks.length, 1);
    expect(notebooks.first.name, '不给任何人看');
    final notes = await reopened.notes.list(notebooks.first.id);
    expect(notes.length, 1);
    expect(notes.first.body, '写在这里，只有我知道。');
  });

  test('拿错旧密钥去 rekey 会失败，且不会破坏原库', () async {
    final dir = Directory.systemTemp.createTempSync('envx_rekey_bad_');
    addTearDown(() => dir.deleteSync(recursive: true));

    final salt = await SaltStore(dir: dir).loadOrCreate('vault.db');
    final realKey = deriveKey(
      password: '111111',
      salt: salt,
      params: KdfParams.light,
    ).keyBytes;

    final db = await openEnvxDatabase(
      dir: dir,
      key32: realKey,
      fileName: 'vault.db',
    );
    await db.notebooks.create(name: '留着');
    await db.close();

    final wrongKey = deriveKey(
      password: '999999',
      salt: salt,
      params: KdfParams.light,
    ).keyBytes;
    final anotherKey = randomSalt(32);

    await expectLater(
      rekeyEnvxDatabase(
        dir: dir,
        oldKey32: wrongKey,
        newKey32: anotherKey,
        fileName: 'vault.db',
      ),
      throwsA(isA<WrongKeyException>()),
    );

    // 原库仍能用原密钥打开，数据没被动过。
    final reopened = await openEnvxDatabase(
      dir: dir,
      key32: realKey,
      fileName: 'vault.db',
    );
    addTearDown(reopened.close);
    expect((await reopened.notebooks.all()).first.name, '留着');
  });
}
