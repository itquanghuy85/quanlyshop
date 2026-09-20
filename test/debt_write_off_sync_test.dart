// NEW-08 (2026-09-20): miễn nợ / xoá mềm nợ phải lên cloud.
//  (1) writeOffDebt xếp hàng SyncOrchestrator (delete ⇒ soft delete cloud).
//  (2) syncAllToCloud lấy thêm nợ deleted=1 AND isSynced=0 (đã có firestoreId)
//      qua DBHelper.getUnsyncedDeletedDebts để dọn các khoản kẹt trước đây.
import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/data/db_helper.dart';
import 'package:quanlyshop/services/app_session.dart';
import 'package:quanlyshop/services/data_reconciliation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late String shopId;
  final h = DBHelper();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    AppSession.debugReset();
    AppSession.debugIgnoreFirebaseUser = true;
    AppSession.debugForceOfflineFlag = true;
    shopId = await AppSession.startOffline(shopName: 'Write-off test');
    final db = await h.database;
    await db.delete('debts', where: "firestoreId LIKE 'debt_wo_%'");
    await db.delete('sync_queue', where: "firestoreId LIKE 'debt_wo_%'");
  });
  tearDownAll(AppSession.debugReset);

  Future<int> insertDebt(String fid, {int deleted = 0, int isSynced = 1}) =>
      h.insertDebt({
        'firestoreId': fid,
        'type': 'CUSTOMER_OWES',
        'debtType': 'CUSTOMER_OWES',
        'personName': 'WO',
        'phone': '0900000009',
        'totalAmount': 100,
        'paidAmount': 0,
        'status': 'ACTIVE',
        'createdAt': 1,
        'updatedAt': 1,
        'shopId': shopId,
        'deleted': deleted,
        'isSynced': isSynced,
      });

  test('writeOffDebt: xoá mềm local + xếp hàng delete lên cloud', () async {
    final id = await insertDebt('debt_wo_1');
    await DataReconciliationService.writeOffDebt(
      id,
      reason: 'khó đòi',
      personName: 'WO',
    );
    final row = (await h.getDebtById(id))!;
    expect(row['deleted'], 1);
    expect(row['isSynced'], 0);
    expect((row['note'] as String).contains('Miễn nợ: khó đòi'), isTrue);

    final db = await h.database;
    final q = await db.query(
      'sync_queue',
      where: "firestoreId = ? AND entityType = 'debt'",
      whereArgs: ['debt_wo_1'],
    );
    expect(q.length, 1, reason: 'phải có đúng 1 mục hàng đợi');
    expect(q.first['operation'], 'delete');
    expect(q.first['entityId'], id);
  });

  test('getUnsyncedDeletedDebts: chỉ nợ deleted=1, isSynced=0, có firestoreId',
      () async {
    final stuck = await insertDebt('debt_wo_stuck', deleted: 1, isSynced: 0);
    await insertDebt('debt_wo_synced', deleted: 1, isSynced: 1); // đã lên cloud
    await insertDebt('debt_wo_alive', deleted: 0, isSynced: 0); // getAllDebts lo
    final db = await h.database;
    await db.insert('debts', {
      'firestoreId': null, // chưa từng lên cloud ⇒ không có gì để xoá
      'type': 'CUSTOMER_OWES', 'personName': 'WO-nofid', 'totalAmount': 1,
      'paidAmount': 0, 'status': 'ACTIVE', 'createdAt': 1, 'updatedAt': 1,
      'shopId': shopId, 'deleted': 1, 'isSynced': 0,
    });

    final rows = await h.getUnsyncedDeletedDebts();
    final ids = rows.map((r) => r['firestoreId']).toList();
    expect(ids, contains('debt_wo_stuck'));
    expect(ids, contains('debt_wo_1')); // từ test trên, chưa sync
    expect(ids, isNot(contains('debt_wo_synced')));
    expect(ids, isNot(contains('debt_wo_alive')));
    expect(rows.every((r) => r['firestoreId'] != null), isTrue);
    expect(rows.firstWhere((r) => r['id'] == stuck)['deleted'], 1);
    await db.delete('debts', where: "personName LIKE 'WO%'");
  });
}
