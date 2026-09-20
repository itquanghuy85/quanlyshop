// BUG-07 (2026-09-20): hoàn kho linh kiện theo khoá cloud trong snapshot,
// đúng dòng kể cả khi Kho phụ tùng có 2 dòng trùng tên.
import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/data/db_helper.dart';
import 'package:quanlyshop/models/part_used_detail_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('restorePartQuantityByDetail ưu tiên partFirestoreId, fallback tên', () async {
    final helper = DBHelper();
    final db = await helper.database;
    await db.delete('repair_parts', where: "partName = 'QA MAN TRUNG'");
    final now = DateTime.now().millisecondsSinceEpoch;
    final idA = await db.insert('repair_parts', {
      'firestoreId': 'part_dup_A', 'partName': 'QA MAN TRUNG', 'quantity': 1,
      'cost': 10, 'price': 20, 'shopId': 'S', 'isSynced': 1, 'deleted': 0,
      'createdAt': now, 'updatedAt': now,
    });
    final idB = await db.insert('repair_parts', {
      'firestoreId': 'part_dup_B', 'partName': 'QA MAN TRUNG', 'quantity': 1,
      'cost': 10, 'price': 20, 'shopId': 'S', 'isSynced': 1, 'deleted': 0,
      'createdAt': now, 'updatedAt': now,
    });

    // Snapshot có khoá cloud dòng B ⇒ cộng đúng dòng B.
    final ok = await helper.restorePartQuantityByDetail(
      const PartUsedDetail(
        name: 'QA MAN TRUNG', partFirestoreId: 'part_dup_B',
        source: 'repair_parts', cost: 10, qty: 2,
      ),
      'QA MAN TRUNG',
      2,
    );
    expect(ok, isTrue);
    final qA = (await db.query('repair_parts', where: 'id = ?', whereArgs: [idA])).first['quantity'];
    final qB = (await db.query('repair_parts', where: 'id = ?', whereArgs: [idB])).first['quantity'];
    expect(qB, 3, reason: 'dòng B (khoá cloud) phải +2');
    expect(qA, 1, reason: 'dòng A trùng tên không được đụng');
    // isSynced=0 để lượt sync đẩy lên (không có mạng trong test)
    final synced = (await db.query('repair_parts', where: 'id = ?', whereArgs: [idB])).first['isSynced'];
    expect(synced, 0);

    // Snapshot cũ (không khoá) ⇒ rơi về tên: dòng đầu tiên (A) như hành vi cũ.
    final ok2 = await helper.restorePartQuantityByName('QA MAN TRUNG', 1);
    expect(ok2, isTrue);
    final qA2 = (await db.query('repair_parts', where: 'id = ?', whereArgs: [idA])).first['quantity'];
    expect(qA2, 2);

    // Serialize round-trip giữ khoá mới, đơn cũ (không field) vẫn đọc được.
    final m = const PartUsedDetail(name: 'x', partFirestoreId: 'p1', source: 'repair_parts', cost: 1).toMap();
    expect(m['partFirestoreId'], 'p1');
    expect(m['source'], 'repair_parts');
    final old = PartUsedDetail.fromMap({'name': 'y', 'productId': 5, 'cost': 1, 'qty': 1});
    expect(old.partFirestoreId, isNull);
    expect(old.source, isNull);
  });
}
