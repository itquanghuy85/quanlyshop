import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The web build's sqlite3.wasm is compiled without double-quoted string
/// literals, so `x != ""` fails there with "no such column" while Android and
/// desktop SQLite silently accept it. SQL must compare against ''.
void main() {
  sqfliteFfiInit();

  test('empty-string comparisons use single quotes and run on strict SQLite', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE products(id INTEGER PRIMARY KEY, shopId TEXT, localImagePath TEXT, images TEXT, deleted INTEGER, firestoreId TEXT, isSynced INTEGER)',
    );
    await db.insert('products', {'shopId': 's', 'localImagePath': '/a.jpg', 'images': '', 'deleted': 0, 'firestoreId': 'f1', 'isSynced': 0});
    await db.insert('products', {'shopId': 's', 'localImagePath': '', 'images': '', 'deleted': 0, 'firestoreId': '', 'isSynced': 0});

    final pending = await db.rawQuery(
      "SELECT * FROM products WHERE shopId = ? AND localImagePath IS NOT NULL AND localImagePath != '' AND (images IS NULL OR images = '') AND (deleted = 0 OR deleted IS NULL)",
      ['s'],
    );
    expect(pending.length, 1);

    final updated = await db.rawUpdate(
      "UPDATE products SET isSynced = 1 WHERE firestoreId IS NOT NULL AND firestoreId != ''",
    );
    expect(updated, 1);

    final withId = await db.query('products', where: "firestoreId IS NOT NULL AND firestoreId != ''");
    expect(withId.length, 1);

    await db.close();
  });
}
