// NEW-05 (2026-09-20): tồn kho không bao giờ âm khi bán local-first.
import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/data/db_helper.dart';
import 'package:quanlyshop/models/product_model.dart';
import 'package:quanlyshop/services/app_session.dart';
import 'package:quanlyshop/services/sale_stock_guard.dart';
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
    shopId = await AppSession.startOffline(shopName: 'Stock guard test');
    final db = await h.database;
    await db.delete('products', where: "firestoreId LIKE 'prod_guard_%'");
  });
  tearDownAll(AppSession.debugReset);

  test('deductProductQuantity không cho tồn xuống dưới 0 (lưới an toàn)', () async {
    final db = await h.database;
    final id = await db.insert('products', {
      'name': 'QA GUARD', 'type': 'PHU_KIEN', 'quantity': 18, 'status': 1,
      'cost': 1, 'price': 2, 'shopId': shopId, 'isSynced': 1, 'deleted': 0,
      'createdAt': 1, 'updatedAt': 1, 'firestoreId': 'prod_guard_test',
    });
    await h.deductProductQuantity(id, 5);
    var row = (await db.query('products', where: 'id = ?', whereArgs: [id])).first;
    expect(row['quantity'], 13);
    expect(row['status'], 1);

    await h.deductProductQuantity(id, 120); // vượt tồn (kịch bản NEW-05)
    row = (await db.query('products', where: 'id = ?', whereArgs: [id])).first;
    expect(row['quantity'], 0, reason: 'chặn ở 0, không âm');
    expect(row['status'], 0);
    expect(row['isSynced'], 0);

    await h.deductProductQuantity(id, 1); // đã 0 vẫn không âm
    row = (await db.query('products', where: 'id = ?', whereArgs: [id])).first;
    expect(row['quantity'], 0);
  });

  test('SaleStockGuard.shortages: chặn vượt tồn (kể cả cộng dồn 2 dòng), IMEI = 1', () async {
    final db = await h.database;
    final id = await db.insert('products', {
      'name': 'QA CAP', 'type': 'PHU_KIEN', 'quantity': 18, 'status': 1,
      'cost': 1, 'price': 2, 'shopId': shopId, 'isSynced': 1, 'deleted': 0,
      'createdAt': 1, 'updatedAt': 1, 'firestoreId': 'prod_guard_cap',
    });
    final phoneId = await db.insert('products', {
      'name': 'QA PHONE', 'type': 'DIEN_THOAI', 'quantity': 1, 'status': 1, 'imei': 'IMEI1',
      'cost': 1, 'price': 2, 'shopId': shopId, 'isSynced': 1, 'deleted': 0,
      'createdAt': 1, 'updatedAt': 1, 'firestoreId': 'prod_guard_phone',
    });
    // Bản trong bộ nhớ cố tình sai (quantity 999) — guard phải đọc lại SQLite.
    final stale = Product(id: id, name: 'QA CAP', type: 'PHU_KIEN', quantity: 999, createdAt: 1);
    final phone = Product(id: phoneId, name: 'QA PHONE', type: 'DIEN_THOAI', quantity: 1, status: 1, createdAt: 1);

    expect(await SaleStockGuard.shortages(h, [{'product': stale, 'quantity': 18}]), isEmpty);
    expect(await SaleStockGuard.shortages(h, [{'product': stale, 'quantity': 120}]),
        ['QA CAP (còn: 18, cần: 120)']);
    // 2 dòng cùng SP 10 + 10 = 20 > 18
    expect(await SaleStockGuard.shortages(h, [
      {'product': stale, 'quantity': 10}, {'product': stale, 'quantity': 10},
    ]), ['QA CAP (còn: 18, cần: 20)']);
    expect(await SaleStockGuard.shortages(h, [{'product': phone, 'quantity': 1}]), isEmpty);
    // Máy đã bán (status 0) ⇒ còn 0
    await db.update('products', {'status': 0, 'quantity': 0}, where: 'id = ?', whereArgs: [phoneId]);
    expect(await SaleStockGuard.shortages(h, [{'product': phone, 'quantity': 1}]),
        ['QA PHONE (còn: 0, cần: 1)']);

    expect(SaleStockGuard.maxSellable(Product(name: 'x', type: 'PHU_KIEN', quantity: 7, createdAt: 1)), 7);
    expect(SaleStockGuard.maxSellable(Product(name: 'x', type: 'PHU_KIEN', quantity: -3, createdAt: 1)), 0);
    expect(SaleStockGuard.maxSellable(Product(name: 'x', type: 'DIEN_THOAI', quantity: 1, status: 1, createdAt: 1)), 1);
    expect(SaleStockGuard.maxSellable(Product(name: 'x', type: 'DIEN_THOAI', quantity: 1, status: 0, createdAt: 1)), 0);
  });
}
