// Kịch bản test TOÀN BỘ số liệu tài chính — xem `test/FINANCE_FULL_SCENARIO.md`
// để đọc từng bước thao tác và cách tính tay ra từng con số kỳ vọng.
//
// Cách chạy: `flutter test test/finance_full_scenario_test.dart`
//
// Thiết kế:
// - `DBHelper` gọi `UserService` → FirebaseAuth nên không dùng được trong test.
//   Thay bằng `_ScenarioDb implements DBHelper` (noSuchMethod) chỉ cấp đúng
//   những truy vấn `FinanceV2DataService.loadSnapshot` cần — dữ liệu là bản
//   chụp mà các service GHI THẬT (xem chú thích từng fixture ↔ file service).
// - Cùng bộ dữ liệu đó đưa vào `DailyFinancialAnalysisService.analyze()`
//   (engine của Chốt quỹ / Báo cáo ngày / Home) để kiểm tách TM/CK và chốt quỹ.
// - Mọi kỳ vọng là SỐ CỨNG tính tay, không tái dùng công thức của app.

import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/data/db_helper.dart';
import 'package:quanlyshop/finance_v2/finance_v2_data_service.dart';
import 'package:quanlyshop/models/repair_model.dart';
import 'package:quanlyshop/models/repair_service_model.dart';
import 'package:quanlyshop/models/sale_order_model.dart';
import 'package:quanlyshop/services/daily_financial_analysis_service.dart';

// ---------------------------------------------------------------------------
// Mốc thời gian
// ---------------------------------------------------------------------------
final DateTime _day = DateTime(2026, 9, 10);
final int _dayStart = _day.millisecondsSinceEpoch;
final int _dayEnd = DateTime(2026, 9, 10, 23, 59, 59).millisecondsSinceEpoch;
int _at(int hour, [int minute = 0]) =>
    DateTime(2026, 9, 10, hour, minute).millisecondsSinceEpoch;
final int _aug15 = DateTime(2026, 8, 15, 10).millisecondsSinceEpoch;
final int _aug01 = DateTime(2026, 8, 1, 9).millisecondsSinceEpoch;

const _shop = 'shop_test';
const _tm = 'TIỀN MẶT';
const _ck = 'CHUYỂN KHOẢN';
const _cn = 'CÔNG NỢ';

// ---------------------------------------------------------------------------
// FIXTURES — bản chụp đúng những gì service ghi xuống SQLite
// ---------------------------------------------------------------------------

SaleOrder _sale({
  required String fid,
  required String customer,
  required String product,
  required int total,
  required int cost,
  int discount = 0,
  String method = _tm,
  int? soldAt,
  int cash = 0,
  int transfer = 0,
  bool installment = false,
  int down = 0,
  String? downMethod,
  int loan = 0,
  int loan2 = 0,
  String? bank,
  String? bank2,
  int? settledAt,
  int settlement = 0,
}) {
  return SaleOrder(
    id: fid.hashCode & 0xffff,
    firestoreId: fid,
    customerName: customer,
    phone: '0900000000',
    productNames: product,
    productImeis: '',
    totalPrice: total,
    totalCost: cost,
    discount: discount,
    paymentMethod: method,
    sellerName: 'NV',
    soldAt: soldAt ?? _at(9),
    cashAmount: cash,
    transferAmount: transfer,
    isInstallment: installment,
    downPayment: down,
    downPaymentMethod: downMethod,
    loanAmount: loan,
    loanAmount2: loan2,
    bankName: bank,
    bankName2: bank2,
    settlementReceivedAt: settledAt,
    settlementAmount: settlement,
    isSynced: true,
  );
}

/// Map cho `analyze()` — đúng các cột cash_closing_view đưa vào.
Map<String, dynamic> _saleMap(SaleOrder s) => {
      'paymentMethod': s.paymentMethod,
      'totalPrice': s.totalPrice,
      'discount': s.discount,
      'totalCost': s.totalCost,
      'isInstallment': s.isInstallment ? 1 : 0,
      'cashAmount': s.cashAmount,
      'transferAmount': s.transferAmount,
      'downPayment': s.downPayment,
      'downPaymentMethod': s.downPaymentMethod,
      'loanAmount': s.loanAmount,
      'loanAmount2': s.loanAmount2,
      'settlementAmount': s.settlementAmount,
      'settlementReceivedAt': s.settlementReceivedAt,
      'soldAt': s.soldAt,
    };

Repair _repair({
  required String fid,
  required String customer,
  required String model,
  required int price,
  int cost = 0,
  String method = _tm,
  List<RepairService> services = const [],
  bool costInFund = false,
  String? costMethod,
  int? costAt,
}) {
  return Repair(
    id: fid.hashCode & 0xffff,
    firestoreId: fid,
    customerName: customer,
    phone: '0900000000',
    model: model,
    issue: 'Lỗi',
    status: 4,
    price: price,
    cost: cost,
    paymentMethod: method,
    createdAt: _at(8),
    deliveredAt: _at(16),
    repairedBy: 'KTV',
    services: List.of(services),
    costRecordedInFund: costInFund,
    costPaymentMethod: costMethod,
    costRecordedAt: costAt,
    costRecordedAmount: costInFund ? cost : 0,
  );
}

Map<String, dynamic> _repairMap(Repair r) => {
      'price': r.price,
      'totalCost': r.totalCost,
      'paymentMethod': r.paymentMethod,
    };

/// `getRepairsCostFundByDateRange` — cột như db_helper.dart:5535.
Map<String, dynamic> _costFundRow(Repair r) => {
      'id': r.id,
      'firestoreId': r.firestoreId,
      'customerName': r.customerName,
      'model': r.model,
      'cost': r.cost,
      'costRecordedAmount': r.costRecordedAmount,
      'costPaymentMethod': r.costPaymentMethod,
      'costRecordedAt': r.costRecordedAt,
    };

/// `expenses` — như PaymentIntentService / StockEntryService ghi.
Map<String, dynamic> _expense({
  required String fid,
  required int amount,
  required String category,
  required String method,
  String type = 'CHI',
  String? title,
  int? date,
}) =>
    {
      'id': fid.hashCode & 0xffff,
      'firestoreId': fid,
      'amount': amount,
      'type': type,
      'category': category,
      'title': title ?? category,
      'paymentMethod': method,
      'date': date ?? _at(11),
      'createdAt': date ?? _at(11),
      'createdBy': 'NV',
      'shopId': _shop,
    };

/// `debts` — như `PaymentIntentService.createDebtRecord` ghi
/// (payment_intent_service.dart:424), `paidAmount` sau `updateDebtPaid`.
Map<String, dynamic> _debt({
  required String fid,
  required String type,
  required String person,
  required int total,
  required int paid,
  int? createdAt,
}) =>
    {
      'id': fid.hashCode & 0xffff,
      'firestoreId': fid,
      'type': type,
      'debtType': type,
      'personName': person,
      'totalAmount': total,
      'paidAmount': paid,
      'status': paid >= total ? 'PAID' : 'ACTIVE',
      'createdAt': createdAt ?? _at(9),
      'deleted': 0,
      'note': '',
    };

/// `debt_payments` JOIN `debts` — như `getDebtPaymentsForCashFlowByDateRange`
/// trả về (db_helper.dart:9768).
Map<String, dynamic> _debtPayment({
  required String fid,
  required String debtFid,
  required String debtType,
  required String person,
  required int amount,
  required String method,
  int? paidAt,
}) =>
    {
      'id': fid.hashCode & 0xffff,
      'firestoreId': fid,
      'debtFirestoreId': debtFid,
      'debtType': debtType,
      'resolvedDebtType': debtType,
      'debtPersonName': person,
      'amount': amount,
      'paymentMethod': method,
      'paidAt': paidAt ?? _at(14),
    };

/// `supplier_import_history` — 1 dòng / 1 mặt hàng, `referenceId` = mã phiếu
/// (stock_entry_service.dart:995).
Map<String, dynamic> _importRow({
  required String ref,
  required String supplier,
  required String product,
  required int qty,
  required int unitCost,
  required String method,
}) =>
    {
      'referenceId': ref,
      'supplierName': supplier,
      'productName': product,
      'quantity': qty,
      'costPrice': unitCost,
      'totalAmount': qty * unitCost,
      'paymentMethod': method,
      'importDate': _at(10),
    };

// ---------------------------------------------------------------------------
// BỘ DỮ LIỆU KỊCH BẢN
// ---------------------------------------------------------------------------
class _Scenario {
  // --- A. Bán hàng
  final s1 = _sale(fid: 'S1', customer: 'KHÁCH LẺ', product: 'Ốp lưng',
      total: 200000, cost: 120000);
  final s2 = _sale(fid: 'S2', customer: 'KH A', product: 'iPhone 15',
      total: 12000000, cost: 10000000, discount: 200000, method: _ck);
  final s3 = _sale(fid: 'S3', customer: 'KH B', product: 'Samsung S24',
      total: 5000000, cost: 4000000, method: 'KẾT HỢP',
      cash: 3000000, transfer: 2000000);
  final s4 = _sale(fid: 'S4', customer: 'KH A', product: 'Xiaomi 14',
      total: 3000000, cost: 2400000, method: _cn);
  final s5 = _sale(fid: 'S5', customer: 'KH B', product: 'Oppo Reno',
      total: 15000000, cost: 12500000, method: 'TRẢ GÓP',
      installment: true, down: 5000000, downMethod: _tm, loan: 10000000,
      bank: 'HD SAISON');
  final s6 = _sale(fid: 'S6', customer: 'KH A', product: 'Vivo V30',
      total: 20000000, cost: 17000000, method: 'TRẢ GÓP',
      installment: true, down: 4000000, downMethod: _ck,
      loan: 10000000, loan2: 6000000, bank: 'FE CREDIT', bank2: 'HOME CREDIT',
      settledAt: _at(15), settlement: 15500000);
  /// Bán 15/08, NH tất toán hôm nay — KHÔNG nằm trong `getSalesByDateRange`,
  /// chỉ về qua `getInstallmentSalesSettledBetween`.
  final s7 = _sale(fid: 'S7', customer: 'KH B', product: 'Realme 12',
      total: 10000000, cost: 8000000, method: 'TRẢ GÓP', soldAt: _aug15,
      installment: true, down: 2000000, downMethod: _tm, loan: 8000000,
      bank: 'HD SAISON', settledAt: _at(15, 30), settlement: 7800000);

  final salesReturn = <String, dynamic>{
    'id': 1,
    'firestoreId': 'RET1',
    'customerName': 'KH B',
    'salesOrderFirestoreId': 'S_OLD',
    'refundMethod': _tm,
    'totalReturnAmount': 150000,
    'totalReturnCost': 90000,
    'returnDate': _at(12),
  };

  // --- B. Sửa chữa
  final r1 = _repair(fid: 'R1', customer: 'KH A', model: 'iPhone 12',
      price: 800000, cost: 300000, costInFund: true, costMethod: _tm,
      costAt: _at(13));
  final r2 = _repair(fid: 'R2', customer: 'KH B', model: 'Samsung A54',
      price: 1500000, method: _ck, services: [
        RepairService(serviceName: 'Thay main', partnerId: 7,
            partnerFirestoreId: 'Z', partnerName: 'ĐỐI TÁC Z', cost: 900000,
            paymentMethod: _cn),
      ]);
  final r3 = _repair(fid: 'R3', customer: 'KH B', model: 'Oppo A57',
      price: 600000, cost: 200000, method: _cn, costInFund: true,
      costMethod: _ck, costAt: _at(13, 30));
  final r4 = _repair(fid: 'R4', customer: 'KHÁCH LẺ', model: 'Xiaomi Note',
      price: 250000, services: [
        RepairService(serviceName: 'Vệ sinh', cost: 50000),
      ]);
  final r5 = _repair(fid: 'R5', customer: 'KH A', model: 'Huawei P30',
      price: 1200000, services: [
        RepairService(serviceName: 'Ép kính', partnerId: 7,
            partnerFirestoreId: 'Z', partnerName: 'ĐỐI TÁC Z', cost: 700000,
            paymentMethod: _tm),
      ]);

  /// R5 trả đối tác ngay — payment_intent_service.dart:979..1023.
  final partnerPayment = <String, dynamic>{
    'id': 1,
    'firestoreId': 'rpp_p1',
    'partnerName': 'ĐỐI TÁC Z',
    'amount': 700000,
    'paymentMethod': _tm,
    'paidAt': _at(16, 5),
  };

  // --- C. Nhập hàng
  final imports = <Map<String, dynamic>>[
    _importRow(ref: 'se1', supplier: 'NCC X', product: 'Màn hình', qty: 5,
        unitCost: 400000, method: _tm),
    _importRow(ref: 'se1', supplier: 'NCC X', product: 'Pin', qty: 10,
        unitCost: 100000, method: _tm),
    _importRow(ref: 'se2', supplier: 'NCC Y', product: 'Ốp lưng', qty: 20,
        unitCost: 50000, method: _ck),
    _importRow(ref: 'se3', supplier: 'NCC X', product: 'iPhone 15', qty: 2,
        unitCost: 10000000, method: _cn),
    _importRow(ref: 'se4', supplier: 'NCC Y', product: 'Cáp sạc', qty: 10,
        unitCost: 50000, method: _cn),
  ];

  // --- D. expenses (chủ động + tự động)
  late final expenses = <Map<String, dynamic>>[
    _expense(fid: 'E1', amount: 1200000, category: 'ĐIỆN NƯỚC', method: _tm,
        title: 'Tiền điện tháng 8'),
    _expense(fid: 'E2', amount: 5000000, category: 'MẶT BẰNG', method: _ck,
        title: 'Tiền mặt bằng'),
    _expense(fid: 'inc_E3', amount: 300000, category: 'THU KHÁC', method: _tm,
        type: 'THU', title: 'Bán ve chai'),
    // tự động — stock_entry_service.dart:841
    _expense(fid: 'exp_stock_se1_1789000000000', amount: 3000000,
        category: 'NHẬP HÀNG', method: _tm, title: 'Nhập kho từ NCC X'),
    _expense(fid: 'exp_stock_se2_1789000000001', amount: 1000000,
        category: 'NHẬP HÀNG', method: _ck, title: 'Nhập kho từ NCC Y'),
    // tự động — payment_intent_service.dart:1006 (mirror của rpp_p1)
    _expense(fid: 'exp_partner_p1', amount: 700000, category: 'ĐỐI TÁC SỬA CHỮA',
        method: _tm, title: 'Trả đối tác Z: Huawei P30'),
  ];

  // --- Công nợ (trạng thái CUỐI ngày) + phiếu thu/trả
  final debts = <Map<String, dynamic>>[
    _debt(fid: 'D1', type: 'CUSTOMER_OWES', person: 'KH A', total: 3000000,
        paid: 1500000),
    _debt(fid: 'D2', type: 'SHOP_OWES', person: 'ĐỐI TÁC Z', total: 900000,
        paid: 400000),
    _debt(fid: 'D3', type: 'CUSTOMER_OWES', person: 'KH B', total: 600000,
        paid: 600000),
    _debt(fid: 'D4', type: 'SHOP_OWES', person: 'NCC X', total: 20000000,
        paid: 5000000),
    _debt(fid: 'D5', type: 'SHOP_OWES', person: 'NCC Y', total: 500000,
        paid: 500000),
    _debt(fid: 'D6', type: 'CUSTOMER_OWES', person: 'KH B', total: 2000000,
        paid: 0, createdAt: _aug01),
  ];
  final debtPayments = <Map<String, dynamic>>[
    _debtPayment(fid: 'dp1', debtFid: 'D1', debtType: 'CUSTOMER_OWES',
        person: 'KH A', amount: 1000000, method: _tm),
    _debtPayment(fid: 'dp2', debtFid: 'D2', debtType: 'SHOP_OWES',
        person: 'ĐỐI TÁC Z', amount: 400000, method: _ck),
    _debtPayment(fid: 'dp3', debtFid: 'D3', debtType: 'CUSTOMER_OWES',
        person: 'KH B', amount: 600000, method: _ck),
    _debtPayment(fid: 'dp4', debtFid: 'D4', debtType: 'SHOP_OWES',
        person: 'NCC X', amount: 5000000, method: _ck),
    _debtPayment(fid: 'dp5', debtFid: 'D5', debtType: 'SHOP_OWES',
        person: 'NCC Y', amount: 500000, method: _tm),
    _debtPayment(fid: 'dp6', debtFid: 'D1', debtType: 'CUSTOMER_OWES',
        person: 'KH A', amount: 500000, method: _ck),
  ];

  List<SaleOrder> get salesSoldToday => [s1, s2, s3, s4, s5, s6];
  List<SaleOrder> get settledToday => [s6, s7];
  List<Repair> get repairsDelivered => [r1, r2, r3, r4, r5];
  List<Repair> get costFundRepairs => [r1, r3];
}

// ---------------------------------------------------------------------------
// DBHelper giả — chỉ trả lời đúng các truy vấn của loadSnapshot
// ---------------------------------------------------------------------------
class _ScenarioDb implements DBHelper {
  _ScenarioDb(this.sc);
  final _Scenario sc;

  bool _inDay(int a, int b) => a <= _dayEnd && b >= _dayStart;

  @override
  Future<List<SaleOrder>> getSalesByDateRange(int startMs, int endMs) async =>
      _inDay(startMs, endMs) ? sc.salesSoldToday : const [];

  @override
  Future<List<SaleOrder>> getInstallmentSalesSettledBetween(
          int startMs, int endMs) async =>
      _inDay(startMs, endMs) ? sc.settledToday : const [];

  @override
  Future<List<Repair>> getDeliveredRepairsByDateRange(
          int startMs, int endMs) async =>
      _inDay(startMs, endMs) ? sc.repairsDelivered : const [];

  @override
  Future<List<Map<String, dynamic>>> getRepairsCostFundByDateRange(
          int startMs, int endMs) async =>
      _inDay(startMs, endMs)
          ? sc.costFundRepairs.map(_costFundRow).toList()
          : const [];

  @override
  Future<List<Map<String, dynamic>>> getExpensesByDateRange(
          int startMs, int endMs) async =>
      _inDay(startMs, endMs) ? sc.expenses : const [];

  @override
  Future<List<Map<String, dynamic>>> getRepairPartnerPaymentsByDateRange(
          int startMs, int endMs) async =>
      _inDay(startMs, endMs) ? [sc.partnerPayment] : const [];

  @override
  Future<List<Map<String, dynamic>>> getDebtPaymentsForCashFlowByDateRange(
          int startMs, int endMs) async =>
      _inDay(startMs, endMs) ? sc.debtPayments : const [];

  @override
  Future<List<Map<String, dynamic>>> getSalesReturnsByDateRange(
          int startMs, int endMs) async =>
      _inDay(startMs, endMs) ? [sc.salesReturn] : const [];

  @override
  Future<List<Map<String, dynamic>>> getAllImportHistoryByDateRange(
          int startMs, int endMs) async =>
      _inDay(startMs, endMs) ? sc.imports : const [];

  @override
  Future<List<Map<String, dynamic>>> getDebtsForFinanceSnapshot() async =>
      sc.debts;

  @override
  Future<List<Map<String, dynamic>>> getFinancialActivities({
    int? startDate,
    int? endDate,
    String? activityType,
    String? direction,
    String? searchQuery,
    int limit = 100,
    int offset = 0,
    String? shopId,
  }) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> getSuppliers() async => const [];
  @override
  Future<List<Map<String, dynamic>>> getRepairPartners() async => const [];
  @override
  Future<List<Map<String, dynamic>>> getCustomers() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'loadSnapshot gọi thêm truy vấn mới: ${invocation.memberName} — '
        'bổ sung vào _ScenarioDb và kịch bản.',
      );
}

// ---------------------------------------------------------------------------
// TESTS
// ---------------------------------------------------------------------------
void main() {
  final sc = _Scenario();

  group('Tài chính V2 — loadSnapshot (cash basis)', () {
    late FinanceV2Snapshot snap;

    setUpAll(() async {
      snap = await FinanceV2DataService(dbHelper: _ScenarioDb(sc))
          .loadSnapshot(start: _day, end: _day);
    });

    test('tiền vào: bán 49.150.000 + sửa 3.750.000 + thu nợ 2.100.000 + thu khác 300.000',
        () {
      expect(snap.incomeFromSales, 49150000, reason: 'bán hàng thực thu (đã trừ trả hàng 150k)');
      expect(snap.incomeFromRepairs, 3750000, reason: 'sửa chữa thực thu, loại R3 CÔNG NỢ');
      expect(snap.incomeOther, 300000, reason: 'thu khác KHÔNG gồm thu nợ');
      expect(snap.totalIn, 55300000);
    });

    test('tiền ra: 17.350.000 tách đúng 5 nhóm', () {
      expect(snap.operatingExpenseOut, 6200000, reason: 'chỉ E1 + E2');
      expect(snap.importExpenseOut, 4000000, reason: 'I1 + I2, KHÔNG gồm I3/I4 công nợ');
      expect(snap.partnerPaymentOut, 700000, reason: 'R5 trả đối tác trực tiếp');
      expect(snap.debtRepayOut, 5900000, reason: 'dp2 + dp4 + dp5');
      expect(snap.totalOut, 17350000);
      expect(snap.netCashflow, 37950000);
    });

    test('nhập kho có expense mirror KHÔNG bị cộng 2 lần (I1 hai dòng, I2 một dòng)',
        () {
      // Nếu canonical reference lệch → importExpenseOut sẽ là 8.000.000.
      expect(snap.importExpenseOut, 4000000);
      expect(snap.totalOut, 17350000);
    });

    test('trả đối tác trực tiếp: rpp_p1 + exp_partner_p1 chỉ tính 1 lần', () {
      final partnerTxns = snap.transactions
          .where((t) => t.amount == 700000 && !t.isIncome)
          .toList();
      expect(partnerTxns.length, 1);
      expect(partnerTxns.single.referenceId, 'exp_partner_p1');
      expect(partnerTxns.single.id, startsWith('expense_'));
    });

    test('vốn & lãi gộp theo tỉ lệ tiền thực thu', () {
      expect(snap.cogsFromSales, 41011667);
      expect(snap.cogsFromRepairs, 1950000);
      expect(snap.grossProfitFromSales, 8138333);
      expect(snap.grossProfitFromRepairs, 1800000);
      expect(snap.grossProfitTotal, 9938333);
      expect(snap.grossProfitTotal - snap.operatingExpenseOut, 3738333,
          reason: 'lãi sau chi vận hành — KHÔNG trừ vốn SC lần 2');
    });

    test('trả góp: cọc TM 5tr (S5), 2 NH tất toán trong ngày (S6), tất toán đơn kỳ trước (S7)',
        () {
      FinanceV2Txn txn(String fid) =>
          snap.transactions.singleWhere((t) => t.referenceId == fid);
      expect(txn('S5').amount, 5000000);
      expect(txn('S5').costAmount, 4166667);
      expect(txn('S6').amount, 19500000, reason: 'cọc 4tr + tất toán 15,5tr');
      expect(txn('S6').subtitle, contains('FE CREDIT, HOME CREDIT'));
      expect(txn('S7').amount, 7800000, reason: 'chỉ phần tất toán — cọc thuộc kỳ trước');
      expect(txn('S7').costAmount, 6240000);
    });

    test('đơn CÔNG NỢ (S4, R3) không tạo dòng tiền — chỉ phiếu thu mới tạo', () {
      expect(snap.transactions.where((t) => t.referenceId == 'S4'), isEmpty);
      // R3 chỉ được có dòng CHI vốn LK ghi sổ quỹ, không có dòng THU
      expect(
        snap.transactions.where((t) => t.referenceId == 'R3' && t.isIncome),
        isEmpty,
      );
      final collects =
          snap.transactions.where((t) => t.type == 'DEBT_COLLECT').toList();
      expect(collects.map((t) => t.amount).toList()..sort(),
          [500000, 600000, 1000000]);
    });

    test('công nợ cuối ngày: phải thu 3.500.000, phải trả 15.500.000', () {
      expect(snap.receivableTotal, 3500000);
      expect(snap.payableTotal, 15500000);
      expect(snap.receivables.map((d) => d.id).toSet(), {'D1', 'D6'});
      expect(snap.payables.map((d) => d.id).toSet(), {'D2', 'D4'});
      expect(snap.receivables.singleWhere((d) => d.id == 'D1').remaining, 1500000);
      expect(snap.payables.singleWhere((d) => d.id == 'D4').remaining, 15000000);
      expect(snap.debtAging.values.fold<int>(0, (a, b) => a + b), 3500000,
          reason: 'aging chỉ gom phải thu');
    });

    test('trả hàng S8: hiện dòng REFUND 150.000, trừ thẳng doanh thu/vốn', () {
      final ret = snap.transactions.singleWhere((t) => t.type == 'REFUND');
      expect(ret.amount, 150000);
      expect(ret.costAmount, 90000);
      expect(ret.isIncome, isFalse);
    });

    test('sổ giao dịch: đủ 26 dòng, mọi dòng đều trong ngày D', () {
      // 6 bán (S4 CN không có dòng) + 4 sửa (R3 CN không có) + 1 mirror R4
      // + 2 vốn LK ghi sổ + 6 expenses + 6 phiếu nợ + 1 trả hàng = 26.
      // rpp_p1 bị khử vì đã có expense mirror.
      final ids = snap.transactions.map((t) => t.id).toList();
      expect(ids.where((i) => i.startsWith('sale_')).length, 6);
      expect(ids.where((i) => i.startsWith('repair_') && !i.startsWith('repair_cost_')).length, 4);
      expect(ids.where((i) => i.startsWith('repair_cost_')).length, 1);
      expect(ids.where((i) => i.startsWith('parts_cost_')).length, 2);
      expect(ids.where((i) => i.startsWith('expense_')).length, 6);
      expect(ids.where((i) => i.startsWith('debtpay_')).length, 6);
      expect(ids.where((i) => i.startsWith('partner_payment_')).length, 0);
      expect(ids.where((i) => i.startsWith('ret_')).length, 1);
      expect(snap.transactionCount, 26);
      for (final t in snap.transactions) {
        expect(t.createdAt, inInclusiveRange(_dayStart, _dayEnd),
            reason: '${t.id} (${t.referenceId}) nằm ngoài ngày D');
      }
    });

    test('tổng dòng thu trong sổ = totalIn, tổng dòng chi (trừ REFUND) = totalOut', () {
      final inSum = snap.transactions
          .where((t) => t.isIncome)
          .fold<int>(0, (a, t) => a + t.amount);
      final outSum = snap.transactions
          .where((t) => !t.isIncome && t.type != 'REFUND')
          .fold<int>(0, (a, t) => a + t.amount);
      // REFUND đã trừ thẳng vào incomeFromSales nên totalIn = inSum − 150.000
      expect(inSum - 150000, snap.totalIn);
      expect(outSum, snap.totalOut);
    });
  });

  group('Chốt quỹ / Báo cáo ngày — DailyFinancialAnalysisService', () {
    late DailyFinancialAnalysis a;

    setUpAll(() {
      a = DailyFinancialAnalysisService.analyze(
        sales: sc.salesSoldToday.map(_saleMap).toList(),
        settlementSales: sc.settledToday.map(_saleMap).toList(),
        repairs: sc.repairsDelivered.map(_repairMap).toList(),
        expenses: sc.expenses,
        debtPayments: sc.debtPayments,
        supplierPayments: const [], // SupplierPaymentService không còn được gọi
        repairPartnerPayments: [sc.partnerPayment],
        supplierImports: sc.imports,
        repairPartsCostFundRows: sc.costFundRepairs.map(_costFundRow).toList(),
        salesReturns: [sc.salesReturn],
        enableRepair: true,
      );
    });

    test('tiền mặt vào 11.750.000 · ngân hàng vào 43.700.000', () {
      expect(a.cashIn, 11750000);
      expect(a.bankIn, 43700000);
    });

    test('ngân hàng ra 11.600.000', () {
      expect(a.bankOut, 11600000);
    });

    test('tiền mặt ra 5.850.000 (nhập kho I1 nhiều dòng không được cộng thêm)',
        () {
      expect(a.cashOut, 5850000);
    });

    test('chốt quỹ: TM cuối 15.900.000 · NH cuối 52.100.000', () {
      const cashStart = 10000000;
      const bankStart = 20000000;
      expect(cashStart + a.cashIn - a.cashOut, 15900000);
      expect(bankStart + a.bankIn - a.bankOut, 52100000);
    });

    test('phân rã thu chi', () {
      expect(a.saleIncome, 28850000, reason: 'accrual: gồm S4 CN, trừ trả hàng');
      expect(a.settlementIncome, 23300000);
      expect(a.repairIncome, 4350000, reason: 'gồm R3 CN');
      expect(a.debtCollected, 2100000);
      expect(a.miscIncome, 300000);
      expect(a.expenseOut, 6200000, reason: 'chi vận hành thuần');
      expect(a.importOut, 4000000);
      expect(a.supplierPaid, 5900000);
      expect(a.partnerPaid, 0, reason: 'rpp_p1 đã tính ở expense mirror');
      expect(a.repairPartsCostFund, 500000);
      expect(a.refundOut, 150000);
    });

    test('vốn & lợi nhuận ròng ngày', () {
      expect(a.saleCost, 43996667);
      expect(a.repairCost, 2150000);
      expect(a.netProfit, 4453333);
    });
  });

  group('Đối chiếu chéo hai engine', () {
    late FinanceV2Snapshot snap;
    late DailyFinancialAnalysis a;

    setUpAll(() async {
      snap = await FinanceV2DataService(dbHelper: _ScenarioDb(sc))
          .loadSnapshot(start: _day, end: _day);
      a = DailyFinancialAnalysisService.analyze(
        sales: sc.salesSoldToday.map(_saleMap).toList(),
        settlementSales: sc.settledToday.map(_saleMap).toList(),
        repairs: sc.repairsDelivered.map(_repairMap).toList(),
        expenses: sc.expenses,
        debtPayments: sc.debtPayments,
        supplierPayments: const [],
        repairPartnerPayments: [sc.partnerPayment],
        supplierImports: sc.imports,
        repairPartsCostFundRows: sc.costFundRepairs.map(_costFundRow).toList(),
        salesReturns: [sc.salesReturn],
        enableRepair: true,
      );
    });

    test('dòng tiền ròng V2 = (TM vào + NH vào) − (TM ra + NH ra) + dịch vụ nội bộ R4',
        () {
      // Khác biệt cố ý duy nhất: V2 hiện mirror 50.000 dịch vụ nội bộ (R4)
      // là tiền ra; Chốt quỹ không (xem FINANCE_FULL_SCENARIO.md §4).
      expect(a.totalIn - a.totalOut, snap.netCashflow + 50000);
    });

    test('chi vận hành, nhập hàng, trả nợ NCC khớp nhau', () {
      expect(a.expenseOut, snap.operatingExpenseOut);
      expect(a.importOut, snap.importExpenseOut);
      expect(a.supplierPaid, snap.debtRepayOut);
      expect(a.debtCollected, 2100000);
    });

    test('bất biến công nợ: paidAmount = Σ phiếu thu/trả từng khoản', () {
      final paidByDebt = <String, int>{};
      for (final p in sc.debtPayments) {
        paidByDebt.update(p['debtFirestoreId'] as String,
            (v) => v + (p['amount'] as int),
            ifAbsent: () => p['amount'] as int);
      }
      for (final d in sc.debts) {
        expect(d['paidAmount'], paidByDebt[d['firestoreId']] ?? 0,
            reason: '${d['firestoreId']}');
        expect((d['paidAmount'] as int) <= (d['totalAmount'] as int), isTrue);
      }
    });
  });

  group('NGHI VẤN — kỳ vọng đúng nghiệp vụ, đang skip chờ xác nhận', () {
    late FinanceV2Snapshot snap;
    setUpAll(() async {
      snap = await FinanceV2DataService(dbHelper: _ScenarioDb(sc))
          .loadSnapshot(start: _day, end: _day);
    });

    test('FINDING-1: đơn góp đã tất toán phải ghi ĐỦ vốn (phí NH không làm giảm vốn)',
        () {
      FinanceV2Txn txn(String fid) =>
          snap.transactions.singleWhere((t) => t.referenceId == fid);
      // S6: nhận 19,5tr / 20tr, vốn thật 17tr → V2 hiện 16.575.000 (thiếu 425.000)
      expect(txn('S6').costAmount, 17000000);
      // S7: kỳ này nhận 7,8tr, kỳ trước đã ghi vốn theo cọc 2tr/10tr = 1,6tr
      // → phần còn lại phải là 6.400.000 (V2 hiện 6.240.000, thiếu 160.000)
      expect(txn('S7').costAmount, 6400000);
    }, skip: 'Chờ chủ shop chốt: vốn đơn góp tất toán tính đủ hay theo tỉ lệ tiền nhận');
  });
}
