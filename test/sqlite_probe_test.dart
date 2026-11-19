import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('sqlite3 原生库可加载并能读写', () {
    final db = sqlite3.openInMemory();
    db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT) STRICT');
    db.execute("INSERT INTO t (v) VALUES ('信封日记')");
    final rows = db.select('SELECT id, v FROM t');
    expect(rows.length, 1);
    expect(rows.first['v'], '信封日记');

    // ignore: avoid_print
    print(
      'sqlite3 version=${sqlite3.version.libVersion} '
      'sourceId=${sqlite3.version.sourceId}',
    );
    db.close();
  });
}
