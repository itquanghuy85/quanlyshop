// NEW-09 (2026-09-20): app bị kill giữa transaction bán và bước tạo phiếu
// thu ⇒ đơn có, tồn trừ, không có phiếu thu. `reconcileSalesMissingPaymentIntent`
// quét và tạo bù cho các đơn TIỀN MẶT/CHUYỂN KHOẢN đơn giản còn thiếu.
import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/data/db_helper.dart';
import 'package:quanlyshop/services/app_session.dart';
import 'package:quanlyshop/services/payment_intent_service.dart';
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
    shopId = await AppSession.startOffline(shopName: 'Sale reconcile test');
    final db = await h.database;
    await db.delete('sales', where: "firestoreId LIKE 'sale_recon_%'");
    await db.delete(
      'payment_intents',
      where: "referenceId LIKE 'sale_recon_%'",
    );
  });
  tearDownAll(AppSession.debugReset);

  Future<int> insertSale(
    String fid, {
    String paymentMethod = 'TIỀN MẶT',
    int total = 200000,
    int cashAmount = 0,
    int transferAmount = 0,
    int isInstallment = 0,
  }) async {
    final db = await h.database;
    return db.insert('sales', {
      'firestoreId': fid,
      'customerName': 'KHÁCH VÃNG LAI',
      'walkInName': 'KHÁCH VÃNG LAI',
      'productNames': 'OP LUNG Y',
      'totalPrice': total,
      'totalCost': 50000,
      'paymentMethod': paymentMethod,
      'sellerName': 'CHỦ SHOP',
      'soldAt': 1789900000000,
      'isInstallment': isInstallment,
      'cashAmount': cashAmount,
      'transferAmount': transferAmount,
      'isSynced': 1,
      'deleted': 0,
      'shopId': shopId,
    });
  }

  Future<List<Map<String, dynamic>>> intentsFor(String saleRef) async {
    final db = await h.database;
    return db.query(
      'payment_intents',
      where: "referenceId = ? AND referenceType = 'sale'",
      whereArgs: [saleRef],
    );
  }

  test('đơn TIỀN MẶT thiếu phiếu thu ⇒ tạo bù đúng số tiền', () async {
    await insertSale('sale_recon_missing', total: 200000);
    await PaymentIntentService.reconcileSalesMissingPaymentIntent();
    final rows = await intentsFor('sale_recon_missing');
    expect(rows.length, 1);
    expect(rows.first['amount'], 200000);
    expect(rows.first['status'], 'COMPLETED');
  });

  test('đơn đã có phiếu thu ⇒ không tạo thêm (không trùng)', () async {
    await insertSale('sale_recon_has_intent', total: 150000);
    await PaymentIntentService.reconcileSalesMissingPaymentIntent();
    expect((await intentsFor('sale_recon_has_intent')).length, 1);
    // Chạy lại lần 2 (giả lập sync nhiều lần) — vẫn đúng 1
    await PaymentIntentService.reconcileSalesMissingPaymentIntent();
    expect((await intentsFor('sale_recon_has_intent')).length, 1);
  });

  test('đơn KẾT HỢP (cash + transfer) ⇒ bỏ qua, không tự suy luận', () async {
    await insertSale(
      'sale_recon_combined',
      total: 300000,
      cashAmount: 100000,
      transferAmount: 200000,
    );
    await PaymentIntentService.reconcileSalesMissingPaymentIntent();
    expect((await intentsFor('sale_recon_combined')).length, 0);
  });

  test('đơn CÔNG NỢ ⇒ bỏ qua (không phải tiền đã thu)', () async {
    await insertSale(
      'sale_recon_debt',
      total: 300000,
      paymentMethod: 'CÔNG NỢ',
    );
    await PaymentIntentService.reconcileSalesMissingPaymentIntent();
    expect((await intentsFor('sale_recon_debt')).length, 0);
  });

  test('đơn trả góp ⇒ bỏ qua (logic phiếu phức tạp hơn)', () async {
    await insertSale(
      'sale_recon_installment',
      total: 5000000,
      isInstallment: 1,
    );
    await PaymentIntentService.reconcileSalesMissingPaymentIntent();
    expect((await intentsFor('sale_recon_installment')).length, 0);
  });
}
