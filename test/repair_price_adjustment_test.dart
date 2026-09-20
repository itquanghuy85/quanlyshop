// NEW-02 (2026-09-20): sửa giá đơn sửa ĐÃ GIAO ⇒ công nợ chênh lệch 2 chiều,
// idempotent khi sửa nhiều lần / trả về giá cũ.
import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/data/db_helper.dart';
import 'package:quanlyshop/services/repair_price_adjustment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  SharedPreferences.setMockInitialValues({});

  Future<Map<String, dynamic>?> debt(DBHelper h, String id) =>
      h.getDebtByFirestoreId(id);

  test('đơn chưa giao: không tạo nợ', () async {
    final h = DBHelper();
    final r = await RepairPriceAdjustmentService.applyDeliveredPriceChange(
      repairFirestoreId: 'rep_t_open',
      status: 3,
      newPrice: 900,
      customerName: 'A',
      phone: '0900000000',
      model: 'X', shopIdOverride: 'S',
    );
    expect(r, isNull);
    expect(await debt(h, RepairPriceAdjustmentService.customerAdjId('rep_t_open')), isNull);
  });

  test('giao TIỀN MẶT 500: tăng → khách nợ thêm; sửa tiếp không trùng; về giá cũ đóng nợ; giảm → shop nợ khách',
      () async {
    final h = DBHelper();
    final db = await h.database;
    const fid = 'rep_t_cash';
    await db.delete('payment_intents', where: "referenceId = ?", whereArgs: [fid]);
    await db.delete('debts', where: "linkedId = ?", whereArgs: [fid]);
    await h.insertPaymentIntent({
      'intentId': 'pi_direct_repair_service_$fid', 'type': 'REPAIR_SERVICE',
      'amount': 500, 'status': 'COMPLETED', 'referenceId': fid, 'referenceType': 'repair',
      'createdAt': 1, 'paymentMethod': 'TIỀN MẶT',
    });
    final custId = RepairPriceAdjustmentService.customerAdjId(fid);
    final shopId = RepairPriceAdjustmentService.shopAdjId(fid);
    Future<RepairPriceAdjustmentResult?> apply(int p) =>
        RepairPriceAdjustmentService.applyDeliveredPriceChange(
          repairFirestoreId: fid, status: 4, newPrice: p,
          customerName: 'A', phone: '0900000001', model: 'X', shopIdOverride: 'S',
        );

    // 500 → 600: khách còn thiếu 100
    var r = await apply(600);
    expect(r!.collected, 500);
    expect(r.outstanding, 100);
    var d = await debt(h, custId);
    expect(d!['totalAmount'], 100);
    expect(d['status'], 'ACTIVE');
    expect(d['linkedType'], 'REPAIR_PRICE_ADJUST');
    expect(await debt(h, shopId), isNull);

    // 600 → 700: cùng 1 khoản nợ, tổng 200 (không tạo nợ thứ 2)
    r = await apply(700);
    expect(r!.outstanding, 200);
    d = await debt(h, custId);
    expect(d!['totalAmount'], 200);
    final cnt = (await db.rawQuery(
      "SELECT COUNT(*) c FROM debts WHERE linkedId = ? AND (deleted = 0 OR deleted IS NULL)", [fid])).first['c'];
    expect(cnt, 1, reason: 'chỉ 1 nợ điều chỉnh');

    // khách trả 50 trên nợ điều chỉnh → collected 550
    await h.updateDebt({'id': d['id'], 'paidAmount': 50});
    // 700 → 500 (về giá gốc): khách đã trả 550 > 500 ⇒ dư 50 ⇒ shop nợ khách 50,
    // nợ khách-nợ đóng (total = paid 50, PAID)
    r = await apply(500);
    expect(r!.collected, 550);
    expect(r.outstanding, -50);
    d = await debt(h, custId);
    expect(d!['status'], 'PAID');
    expect(d['totalAmount'], 50);
    var sdebt = await debt(h, shopId);
    expect(sdebt!['type'], 'SHOP_OWES');
    expect(sdebt['totalAmount'], 50);
    expect(sdebt['status'], 'ACTIVE');

    // 500 → 550: outstanding 0 ⇒ shop-nợ đóng & xoá mềm (chưa trả gì)
    r = await apply(550);
    expect(r!.outstanding, 0);
    sdebt = await debt(h, shopId);
    expect(sdebt == null || (sdebt['deleted'] as num) == 1, isTrue);

    // 550 → 400: giảm 150 ⇒ shop nợ khách 150 (bản ghi cũ được mở lại, không trùng)
    r = await apply(400);
    expect(r!.outstanding, -150);
    sdebt = await debt(h, shopId);
    expect(sdebt!['totalAmount'], 150);
    expect(sdebt['deleted'], 0);
    expect(sdebt['status'], 'ACTIVE');
    final cnt2 = (await db.rawQuery(
      "SELECT COUNT(*) c FROM debts WHERE linkedId = ? AND firestoreId LIKE 'debt_adj_shop_%'", [fid])).first['c'];
    expect(cnt2, 1);
  });

  test('giao CÔNG NỢ 500 (đã trả 200): tăng → tổng nợ = giá mới; giảm dưới đã trả → nợ = đã trả + shop nợ phần dư',
      () async {
    final h = DBHelper();
    final db = await h.database;
    const fid = 'rep_t_debt';
    await db.delete('debts', where: "linkedId = ?", whereArgs: [fid]);
    await h.insertDebt({
      'firestoreId': 'debt_delivery_$fid', 'type': 'CUSTOMER_OWES', 'debtType': 'CUSTOMER_OWES',
      'personName': 'B', 'phone': '0900000002', 'totalAmount': 500, 'paidAmount': 200,
      'status': 'ACTIVE', 'createdAt': 1, 'linkedId': fid, 'shopId': 'S', 'isSynced': 1, 'deleted': 0,
    });
    Future<RepairPriceAdjustmentResult?> apply(int p) =>
        RepairPriceAdjustmentService.applyDeliveredPriceChange(
          repairFirestoreId: fid, status: 4, newPrice: p,
          customerName: 'B', phone: '0900000002', model: 'Y', shopIdOverride: 'S',
        );
    var r = await apply(600);
    var d = await debt(h, 'debt_delivery_$fid');
    expect(d!['totalAmount'], 600);
    expect(d['status'], 'ACTIVE');
    expect(r!.deliveryDebtId, 'debt_delivery_$fid');
    expect(await debt(h, RepairPriceAdjustmentService.customerAdjId(fid)), isNull);

    r = await apply(150); // dưới số đã trả 200
    d = await debt(h, 'debt_delivery_$fid');
    expect(d!['totalAmount'], 200, reason: 'không thấp hơn đã trả');
    expect(d['status'], 'PAID');
    final s = await debt(h, RepairPriceAdjustmentService.shopAdjId(fid));
    expect(s!['totalAmount'], 50);
    expect(s['status'], 'ACTIVE');

    r = await apply(500); // về giá cũ
    d = await debt(h, 'debt_delivery_$fid');
    expect(d!['totalAmount'], 500);
    expect(d['status'], 'ACTIVE');
    final s2 = await debt(h, RepairPriceAdjustmentService.shopAdjId(fid));
    expect(s2 == null || (s2['deleted'] as num) == 1, isTrue);
  });
}
