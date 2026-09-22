// Sửa/tân trang sản phẩm trong kho trước khi bán (2026-09-22).
import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/data/db_helper.dart';
import 'package:quanlyshop/services/app_session.dart';
import 'package:quanlyshop/services/product_refurbish_service.dart';
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
    shopId = await AppSession.startOffline(shopName: 'Refurbish test');
    final db = await h.database;
    await db.delete('products', where: "firestoreId LIKE 'prod_refurb_%'");
    await db.delete('repair_parts', where: "firestoreId LIKE 'part_refurb_%'");
    await db.delete(
      'product_refurbish_items',
      where: "productFirestoreId LIKE 'prod_refurb_%'",
    );
  });
  tearDownAll(AppSession.debugReset);

  Future<int> insertProduct(String fid, {int cost = 3000000}) async {
    final db = await h.database;
    return db.insert('products', {
      'firestoreId': fid,
      'name': 'IPHONE BỂ KÍNH',
      'type': 'DIEN_THOAI',
      'cost': cost,
      'price': 0,
      'quantity': 1,
      'status': 1,
      'shopId': shopId,
      'isSynced': 1,
      'deleted': 0,
      'createdAt': 1,
      'updatedAt': 1,
      'refurbishCost': 0,
    });
  }

  Future<int> insertPart(String fid, {int qty = 5, int cost = 250000}) async {
    final db = await h.database;
    return db.insert('repair_parts', {
      'firestoreId': fid,
      'partName': 'PIN IPHONE X',
      'quantity': qty,
      'cost': cost,
      'shopId': shopId,
      'isSynced': 1,
      'deleted': 0,
    });
  }

  test('CÔNG NỢ đối tác: tạo nợ SHOP_OWES + cộng refurbishCost', () async {
    final productId = await insertProduct('prod_refurb_debt');
    final result = await ProductRefurbishService.addServiceOrOtherCost(
      productId: productId,
      productFirestoreId: 'prod_refurb_debt',
      description: 'Ép kính',
      partnerName: 'NCC ÉP KÍNH A',
      amount: 300000,
      paymentMethod: 'CÔNG NỢ',
    );
    expect(result.success, isTrue);
    expect(result.newRefurbishCost, 300000);

    final product = (await h.getProductById(productId))!;
    expect(product.refurbishCost, 300000);

    final debts = await (await h.database).query(
      'debts',
      where: "linkedId = ? AND linkedType = 'PRODUCT_REFURBISH'",
      whereArgs: ['prod_refurb_debt'],
    );
    expect(debts.length, 1);
    expect(debts.first['type'], 'SHOP_OWES');
    expect(debts.first['totalAmount'], 300000);
    expect(debts.first['personName'], 'NCC ÉP KÍNH A');
  });

  test('TIỀN MẶT: tạo expense + cộng refurbishCost, không tạo nợ', () async {
    final productId = await insertProduct('prod_refurb_cash');
    final result = await ProductRefurbishService.addServiceOrOtherCost(
      productId: productId,
      productFirestoreId: 'prod_refurb_cash',
      description: 'Công thợ sửa pan sạc mainboard',
      amount: 200000,
      paymentMethod: 'TIỀN MẶT',
    );
    expect(result.success, isTrue);

    final product = (await h.getProductById(productId))!;
    expect(product.refurbishCost, 200000);

    final expenses = await (await h.database).query(
      'expenses',
      where: 'title = ? AND amount = ?',
      whereArgs: ['Công thợ sửa pan sạc mainboard', 200000],
    );
    expect(expenses.length, 1);
    expect(expenses.first['category'], 'SỬA CHỮA/TÂN TRANG SP');

    final debts = await (await h.database).query(
      'debts',
      where: "linkedId = ? AND linkedType = 'PRODUCT_REFURBISH'",
      whereArgs: ['prod_refurb_cash'],
    );
    expect(debts, isEmpty);
  });

  test('Linh kiện kho phụ tùng: trừ tồn đúng, cộng đúng giá vốn linh kiện',
      () async {
    final productId = await insertProduct('prod_refurb_part');
    final partId = await insertPart('part_refurb_pin', qty: 5, cost: 250000);

    final result = await ProductRefurbishService.addPartCost(
      productId: productId,
      productFirestoreId: 'prod_refurb_part',
      partId: partId,
      source: 'repair_parts',
      partName: 'PIN IPHONE X',
      quantity: 1,
    );
    expect(result.success, isTrue);
    expect(result.newRefurbishCost, 250000);

    final product = (await h.getProductById(productId))!;
    expect(product.refurbishCost, 250000);

    final part = await h.getPartById(partId);
    expect(part!['quantity'], 4);
  });

  test('Linh kiện không đủ tồn → báo lỗi, không trừ kho, không cộng giá vốn',
      () async {
    final productId = await insertProduct('prod_refurb_part_short');
    final partId =
        await insertPart('part_refurb_short', qty: 1, cost: 250000);

    final result = await ProductRefurbishService.addPartCost(
      productId: productId,
      productFirestoreId: 'prod_refurb_part_short',
      partId: partId,
      source: 'repair_parts',
      partName: 'PIN IPHONE X',
      quantity: 5,
    );
    expect(result.success, isFalse);

    final product = (await h.getProductById(productId))!;
    expect(product.refurbishCost, 0);

    final part = await h.getPartById(partId);
    expect(part!['quantity'], 1);
  });

  test('3 khoản cộng dồn đúng (kịch bản bể kính + hư pin + pan sạc)',
      () async {
    final productId = await insertProduct('prod_refurb_combo', cost: 3000000);
    final partId = await insertPart('part_refurb_combo', qty: 3, cost: 250000);

    await ProductRefurbishService.addServiceOrOtherCost(
      productId: productId,
      productFirestoreId: 'prod_refurb_combo',
      description: 'Ép kính',
      partnerName: 'NCC ÉP KÍNH A',
      amount: 300000,
      paymentMethod: 'CÔNG NỢ',
    );
    await ProductRefurbishService.addPartCost(
      productId: productId,
      productFirestoreId: 'prod_refurb_combo',
      partId: partId,
      source: 'repair_parts',
      partName: 'PIN IPHONE X',
      quantity: 1,
    );
    await ProductRefurbishService.addServiceOrOtherCost(
      productId: productId,
      productFirestoreId: 'prod_refurb_combo',
      description: 'Sửa pan sạc mainboard',
      partnerName: 'NCC MAINBOARD B',
      amount: 200000,
      paymentMethod: 'CÔNG NỢ',
    );

    final product = (await h.getProductById(productId))!;
    // 300.000 + 250.000 + 200.000 = 750.000
    expect(product.refurbishCost, 750000);
    // Tổng giá vốn = giá nhập gốc + chi phí sửa (giữ tách riêng theo quyết
    // định 2026-09-22, không gộp thẳng vào cost).
    expect(product.cost + product.refurbishCost, 3750000);

    final history = await ProductRefurbishService.getHistory(productId);
    expect(history.length, 3);
  });
}
