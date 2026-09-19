// PLAN_OFFLINE_FIRST step 4/5 — the SQLite re-tag helpers used by
// ClaimService (no Firebase involved). Real SQLite via sqflite_common_ffi.
import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/data/db_helper.dart';
import 'package:quanlyshop/services/app_session.dart';
import 'package:quanlyshop/services/claim_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('retagLocalOwner + retagShopId rewrite offline rows', () async {
    SharedPreferences.setMockInitialValues({});
    AppSession.debugReset();
    AppSession.debugIgnoreFirebaseUser = true;
    AppSession.debugForceOfflineFlag = true;
    final localShop = await AppSession.startOffline(shopName: 'Retag test');
    const cloudShop = 'cloud_shop_retag_test';
    const uid = 'uid_retag_test';

    final db = await DBHelper().database;
    final now = DateTime.now().millisecondsSinceEpoch;
    // The FFI database persists between runs — start from a clean slate.
    await db.delete('customers', where: 'phone = ?', whereArgs: ['0900000777']);
    await db.delete('repair_parts', where: 'partName = ?', whereArgs: ['RETAG PART']);
    // Leftover row of the TARGET shop with the same UNIQUE(shopId, phone) key:
    // the local row must win (UPDATE OR REPLACE), not abort the re-tag.
    await db.insert('customers', {
      'firestoreId': 'cust_leftover_$now',
      'name': 'LEFTOVER',
      'phone': '0900000777',
      'shopId': cloudShop,
      'createdAt': now,
      'isSynced': 1,
    });
    await db.insert('customers', {
      'firestoreId': 'cust_retag_$now',
      'name': 'RETAG',
      'phone': '0900000777',
      'shopId': localShop,
      'createdAt': now,
      'isSynced': 0,
    });
    await db.insert('repair_parts', {
      'firestoreId': 'part_retag_$now',
      'partName': 'RETAG PART',
      'quantity': 1,
      'cost': 1,
      'price': 2,
      'shopId': localShop,
      'createdBy': AppSession.localOwnerUid,
      'createdAt': now,
      'updatedAt': now,
      'isSynced': 0,
      'deleted': 0,
    });

    final ownerCells = await ClaimService.retagLocalOwner(uid);
    expect(ownerCells, greaterThanOrEqualTo(1));
    final part = (await db.query(
      'repair_parts',
      where: 'firestoreId = ?',
      whereArgs: ['part_retag_$now'],
    )).first;
    expect(part['createdBy'], uid);

    final rows = await ClaimService.retagShopId(from: localShop, to: cloudShop);
    expect(rows, greaterThanOrEqualTo(2));
    final cust = (await db.query(
      'customers',
      where: 'firestoreId = ?',
      whereArgs: ['cust_retag_$now'],
    )).first;
    expect(cust['shopId'], cloudShop);
    expect(cust['name'], 'RETAG');
    expect(
      (await db.query(
        'customers',
        where: 'shopId = ? AND phone = ?',
        whereArgs: [cloudShop, '0900000777'],
      )).length,
      1,
      reason: 'leftover replaced by the local row',
    );
    expect(
      (await db.query('customers', where: 'shopId = ?', whereArgs: [localShop]))
          .length,
      0,
    );

    await AppSession.rebindOfflineShopId(cloudShop);
    expect(AppSession.offlineShopId, cloudShop);
    expect(AppSession.ownsShop(cloudShop), isTrue);
    expect(AppSession.ownsShop(localShop), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppSession.prefLastSyncedShopId), cloudShop);
    AppSession.debugReset();
  });
}
