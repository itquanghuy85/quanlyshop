// PLAN_OFFLINE_FIRST step 3b — stock-in (nhập kho) in the OFFLINE session.
//
// Runs against real SQLite (sqflite_common_ffi) and WITHOUT Firebase: the
// offline branch of StockEntryService must produce the same local rows the
// online path leaves behind after its Firestore transaction + sync:
// products / repair_parts / expenses|debts / import_orders(+items) /
// supplier_import_history — all with client ids and isSynced = 0.
import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/data/db_helper.dart';
import 'package:quanlyshop/models/stock_entry_model.dart';
import 'package:quanlyshop/services/app_session.dart';
import 'package:quanlyshop/services/offline_stock_entry_store.dart';
import 'package:quanlyshop/services/stock_entry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late String shopId;
  final db = DBHelper();
  final service = StockEntryService();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    AppSession.debugReset();
    AppSession.debugIgnoreFirebaseUser = true;
    AppSession.debugForceOfflineFlag = true;
    shopId = await AppSession.startOffline(shopName: 'Offline stock test');
    await OfflineStockEntryStore.clear();
    expect(AppSession.isOffline, isTrue);
    expect(AppSession.syncEnabled, isFalse);
    await db.insertSupplier({
      'name': 'NCC OFFLINE',
      'phone': '0900000001',
      'shopId': shopId,
      'firestoreId': 'sup_offline_test',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'isSynced': 0,
    });
  });

  tearDownAll(AppSession.debugReset);

  StockEntry buildEntry({required String paymentMethod}) {
    return StockEntry(
      shopId: shopId,
      status: StockEntryStatus.draft,
      entryType: StockEntryType.staging,
      supplierId: 'sup_offline_test',
      supplierName: 'NCC OFFLINE',
      paymentMethod: paymentMethod,
      items: [
        StockEntryItem(
          name: 'IPHONE 11',
          quantity: 2,
          cost: 3000000,
          price: 4000000,
          productType: 'DIEN_THOAI',
          capacity: '64GB',
          color: 'ĐEN',
          brand: 'APPLE',
        ),
        StockEntryItem(
          name: 'CÁP SẠC OFF',
          quantity: 5,
          cost: 50000,
          price: 90000,
          productType: 'PHU_KIEN',
        ),
        StockEntryItem(
          name: 'MÀN IP11 OFF',
          quantity: 3,
          cost: 20000,
          price: 60000,
          productType: 'LINH_KIEN',
          model: 'IP11',
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> rows(String table, [String extra = '']) {
    return db.database.then(
      (d) => d.query(table, where: 'shopId = ? $extra', whereArgs: [shopId]),
    );
  }

  test('draft → pending list → confirm writes every local table', () async {
    final draft = await service.saveDraft(buildEntry(paymentMethod: 'TIỀN MẶT'));
    expect(draft, isNotNull);
    expect(draft!.firestoreId, startsWith('se_'));

    final pending = await service.getPendingEntries();
    expect(pending.map((e) => e.firestoreId), contains(draft.firestoreId));

    final ok = await service.confirmEntry(draft.firestoreId!);
    expect(ok, isTrue);

    // Entry marked confirmed in the offline store, no longer pending.
    final stored = await service.getEntry(draft.firestoreId!);
    expect(stored!.status, StockEntryStatus.confirmed);
    expect(stored.locked, isTrue);
    expect(
      (await service.getPendingEntries()).map((e) => e.firestoreId),
      isNot(contains(draft.firestoreId)),
    );

    // Products: 2 phone rows (batch) + 1 accessory row, all local-only.
    final products = await rows('products');
    final phones = products.where((p) => p['type'] == 'DIEN_THOAI').toList();
    expect(phones.length, 2);
    for (final p in phones) {
      expect(p['quantity'], 1);
      expect(p['cost'], 3000000);
      expect((p['imei'] as String), startsWith('PENDING_'));
      expect(p['isSynced'], 0);
      expect((p['firestoreId'] as String), startsWith('prod_'));
      expect((p['name'] as String), contains('IPHONE 11 64GB ĐEN'));
    }
    final acc = products.firstWhere((p) => p['name'] == 'CÁP SẠC OFF');
    expect(acc['quantity'], 5);
    expect(acc['cost'], 50000);
    expect(acc['isSynced'], 0);

    // Repair part
    final parts = await rows('repair_parts');
    expect(parts.length, 1);
    expect(parts.first['partName'], 'MÀN IP11 OFF');
    expect(parts.first['quantity'], 3);
    expect(parts.first['cost'], 20000);
    expect((parts.first['firestoreId'] as String), startsWith('part_'));
    expect(parts.first['isSynced'], 0);

    // Expense (TIỀN MẶT) = 2*3,000,000 + 5*50,000 + 3*20,000 = 6,310,000
    final expenses = await rows('expenses');
    expect(expenses.length, 1);
    expect(expenses.first['amount'], 6310000);
    expect(expenses.first['category'], 'NHẬP HÀNG');
    expect(expenses.first['isSynced'], 0);

    // Import order + items
    final orders = await rows('import_orders');
    expect(orders.length, 1);
    expect(orders.first['totalAmount'], 6310000);
    expect(orders.first['paymentStatus'], 'PAID');
    expect(orders.first['isSynced'], 0);
    expect((orders.first['firestoreId'] as String), startsWith('imp_'));
    final items = await rows('import_order_items');
    expect(items.length, 3);
    expect(items.every((i) => i['isSynced'] == 0), isTrue);

    // Supplier import history
    final hist = await rows('supplier_import_history');
    expect(hist.length, 3);
  });

  test('second confirm merges accessory / part with weighted cost', () async {
    final entry = buildEntry(paymentMethod: 'CÔNG NỢ').copyWith(
      items: [
        StockEntryItem(
          name: 'CÁP SẠC OFF',
          quantity: 5,
          cost: 70000,
          price: 90000,
          productType: 'PHU_KIEN',
        ),
        StockEntryItem(
          name: 'MÀN IP11 OFF',
          quantity: 3,
          cost: 40000,
          price: 60000,
          productType: 'LINH_KIEN',
          model: 'IP11',
        ),
      ],
    );
    final draft = await service.saveDraft(entry);
    expect(await service.confirmEntry(draft!.firestoreId!), isTrue);

    final acc = (await rows('products'))
        .where((p) => p['name'] == 'CÁP SẠC OFF')
        .toList();
    expect(acc.length, 1, reason: 'must merge, not duplicate');
    expect(acc.first['quantity'], 10);
    expect(acc.first['cost'], 60000); // (5*50k + 5*70k) / 10

    final parts = await rows('repair_parts');
    expect(parts.length, 1);
    expect(parts.first['quantity'], 6);
    expect(parts.first['cost'], 30000); // (3*20k + 3*40k) / 6

    // CÔNG NỢ → debt instead of expense: 5*70k + 3*40k = 470,000
    final debts = await rows('debts');
    expect(debts.length, 1);
    expect(debts.first['totalAmount'], 470000);
    expect(debts.first['type'], 'SHOP_OWES');
    expect((await rows('expenses')).length, 1, reason: 'no new expense');
    final orders = await rows('import_orders');
    expect(orders.length, 2);
    expect(
      orders.where((o) => o['paymentStatus'] == 'DEBT').length,
      1,
    );
  });

  test('cancel removes a draft, cannot cancel confirmed', () async {
    final draft = await service.saveDraft(buildEntry(paymentMethod: 'TIỀN MẶT'));
    expect(await service.cancelEntry(draft!.firestoreId!), isTrue);
    expect(await service.getEntry(draft.firestoreId!), isNull);

    final confirmed = (await OfflineStockEntryStore.confirmed(shopId: shopId));
    expect(confirmed, isNotEmpty);
    expect(await service.cancelEntry(confirmed.first.firestoreId!), isFalse);
  });
}
