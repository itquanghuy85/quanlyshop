// [2026-09-24] BẤT BIẾN ACCRUAL — "đồng nhất công thức lãi sang dồn tích".
//
// Chạy: `flutter test test/finance_accrual_invariants_test.dart`
//
// Trục chính của 2 nhóm đổi sau:
//   1. FinanceV2Snapshot: `incomeFrom*` / `cogsFrom*` / `grossProfit*` là
//      ACCRUAL (ghi theo ngày bán / ngày giao, mọi PTTT). `cashFrom*` giữ
//      đúng con số TIỀN cũ của bảng "Cơ cấu tiền thu vào".
//   2. DailyFinancialAnalysisService: `saleIncome` / `saleCost` là ACCRUAL;
//      `saleCash` là TIỀN bán thuần; `settlementIncome` là TIỀN tất toán NH
//      và KHÔNG còn cộng vào doanh thu / lãi.

import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/data/db_helper.dart';
import 'package:quanlyshop/finance_v2/finance_v2_data_service.dart';
import 'package:quanlyshop/models/repair_model.dart';
import 'package:quanlyshop/models/repair_service_model.dart';
import 'package:quanlyshop/models/sale_order_model.dart';
import 'package:quanlyshop/services/daily_financial_analysis_service.dart';

final DateTime _day = DateTime(2026, 9, 10);
final int _dayStart = _day.millisecondsSinceEpoch;
final int _dayEnd = DateTime(2026, 9, 10, 23, 59, 59).millisecondsSinceEpoch;
int _at(int hour, [int minute = 0]) =>
    DateTime(2026, 9, 10, hour, minute).millisecondsSinceEpoch;

const _tm = 'TIỀN MẶT';
const _cn = 'CÔNG NỢ';

SaleOrder _sale({
  required String fid,
  required int total,
  required int cost,
  String method = _tm,
  int? soldAt,
  int cash = 0,
  int transfer = 0,
  bool installment = false,
  int down = 0,
  String? downMethod,
  int loan = 0,
  int loan2 = 0,
  int? settledAt,
  int settlement = 0,
}) =>
    SaleOrder(
      id: fid.hashCode & 0xffff,
      firestoreId: fid,
      customerName: 'KH',
      phone: '0900000000',
      productNames: fid,
      productImeis: '',
      totalPrice: total,
      totalCost: cost,
      discount: 0,
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
      settlementReceivedAt: settledAt,
      settlementAmount: settlement,
      isSynced: true,
    );

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
  required int price,
  int cost = 0,
  String method = _tm,
  List<RepairService> services = const [],
}) =>
    Repair(
      id: fid.hashCode & 0xffff,
      firestoreId: fid,
      customerName: 'KH',
      phone: '0900000000',
      model: fid,
      issue: 'Lỗi',
      status: 4,
      price: price,
      cost: cost,
      paymentMethod: method,
      createdAt: _at(8),
      deliveredAt: _at(16),
      repairedBy: 'KTV',
      services: List.of(services),
    );

Map<String, dynamic> _repairMap(Repair r) => {
      'price': r.price,
      'totalCost': r.totalCost,
      'paymentMethod': r.paymentMethod,
    };

Map<String, dynamic> _debtPayment({
  required String fid,
  required String debtFid,
  required int amount,
  String method = _tm,
  String? linkedId,
}) =>
    {
      'id': fid.hashCode & 0xffff,
      'firestoreId': fid,
      'debtFirestoreId': debtFid,
      'debtType': 'CUSTOMER_OWES',
      'resolvedDebtType': 'CUSTOMER_OWES',
      'debtPersonName': 'KH',
      'amount': amount,
      'paymentMethod': method,
      'paidAt': _at(14),
      if (linkedId != null) 'linkedDebtLinkedId': linkedId,
    };

Map<String, dynamic> _debt({
  required String fid,
  required int total,
  required int paid,
}) =>
    {
      'id': fid.hashCode & 0xffff,
      'firestoreId': fid,
      'type': 'CUSTOMER_OWES',
      'debtType': 'CUSTOMER_OWES',
      'personName': 'KH',
      'totalAmount': total,
      'paidAmount': paid,
      'status': paid >= total ? 'PAID' : 'ACTIVE',
      'createdAt': _at(9),
      'deleted': 0,
      'note': '',
    };

// ---------------------------------------------------------------------------
// Bộ dữ liệu cố định cho cả 2 engine
// ---------------------------------------------------------------------------

/// Bán trong ngày: CÔNG NỢ + TRẢ GÓP + KẾT HỢP (thu thiếu) + TIỀN MẶT.
final _sales = <SaleOrder>[
  _sale(fid: 'C1', total: 3000000, cost: 2400000, method: _cn),
  _sale(
    fid: 'C2',
    total: 15000000,
    cost: 12000000,
    method: 'TRẢ GÓP',
    installment: true,
    down: 5000000,
    downMethod: _tm,
    loan: 10000000,
  ),
  // KẾT HỢP chỉ thu 3/5 triệu — phần còn lại ghi nợ.
  _sale(
    fid: 'C3',
    total: 5000000,
    cost: 4000000,
    method: 'KẾT HỢP',
    cash: 2000000,
    transfer: 1000000,
  ),
  _sale(fid: 'C4', total: 1000000, cost: 600000),
];

final _repairs = <Repair>[
  _repair(fid: 'P1', price: 500000, cost: 200000),
  _repair(fid: 'P2', price: 800000, cost: 300000, method: _cn),
];

final _returns = <Map<String, dynamic>>[
  {
    'id': 1,
    'firestoreId': 'RET1',
    'refundMethod': _tm,
    'totalReturnAmount': 100000,
    'totalReturnCost': 60000,
    'returnDate': _at(12),
  },
];

final _debts = <Map<String, dynamic>>[
  _debt(fid: 'D1', total: 3000000, paid: 700000),
  _debt(fid: 'D2', total: 300000, paid: 300000),
];

/// dp1 gắn đơn CÔNG NỢ C1, dp2 không gắn — cả hai phải là TIỀN thu nợ như nhau.
List<Map<String, dynamic>> _debtPayments({bool link = false}) => [
      _debtPayment(fid: 'dp1', debtFid: 'D1', amount: 700000, linkedId: link ? 'C1' : null),
      _debtPayment(fid: 'dp2', debtFid: 'D2', amount: 300000),
    ];

// ---------------------------------------------------------------------------
// DBHelper giả — chỉ đủ cho loadSnapshot
// ---------------------------------------------------------------------------
class _AccrualDb implements DBHelper {
  _AccrualDb({this.linkDebt = false});

  /// dp1 có gắn `linkedDebtLinkedId` hay không (đổi giữa 2 lần gọi snapshot).
  final bool linkDebt;

  bool _inDay(int a, int b) => a <= _dayEnd && b >= _dayStart;

  @override
  Future<List<SaleOrder>> getSalesByDateRange(int startMs, int endMs) async =>
      _inDay(startMs, endMs) ? _sales : const [];

  @override
  Future<List<SaleOrder>> getInstallmentSalesSettledBetween(
          int startMs, int endMs) async =>
      const [];

  @override
  Future<List<Repair>> getDeliveredRepairsByDateRange(
          int startMs, int endMs) async =>
      _inDay(startMs, endMs) ? _repairs : const [];

  @override
  Future<List<Map<String, dynamic>>> getRepairsCostFundByDateRange(
          int startMs, int endMs) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> getExpensesByDateRange(
          int startMs, int endMs) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> getRepairPartnerPaymentsByDateRange(
          int startMs, int endMs) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> getDebtPaymentsForCashFlowByDateRange(
          int startMs, int endMs) async =>
      _inDay(startMs, endMs) ? _debtPayments(link: linkDebt) : const [];

  @override
  Future<List<Map<String, dynamic>>> getSalesReturnsByDateRange(
          int startMs, int endMs) async =>
      _inDay(startMs, endMs) ? _returns : const [];

  @override
  Future<List<Map<String, dynamic>>> getAllImportHistoryByDateRange(
          int startMs, int endMs) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> getDebtsForFinanceSnapshot() async =>
      _debts;

  @override
  Future<List<Map<String, dynamic>>> getOutstandingDebtsForFinanceSnapshot() async =>
      _debts;

  @override
  Future<Map<String, SaleOrder>> getSalesByFirestoreIds(
    Iterable<String> firestoreIds,
  ) async =>
      const {};

  @override
  Future<Map<String, Repair>> getRepairsByFirestoreIds(
    Iterable<String> firestoreIds,
  ) async =>
      const {};

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
        'loadSnapshot gọi truy vấn mới: ${invocation.memberName}',
      );
}

Future<FinanceV2Snapshot> _snapshot({bool linkDebt = false}) =>
    FinanceV2DataService(dbHelper: _AccrualDb(linkDebt: linkDebt))
        .loadSnapshot(start: _day, end: _day);

DailyFinancialAnalysis _analyze({
  List<Map<String, dynamic>> sales = const [],
  List<Map<String, dynamic>> settlementSales = const [],
  List<Map<String, dynamic>> repairs = const [],
  List<Map<String, dynamic>> salesReturns = const [],
}) =>
    DailyFinancialAnalysisService.analyze(
      sales: sales,
      settlementSales: settlementSales,
      repairs: repairs,
      expenses: const [],
      debtPayments: const [],
      supplierPayments: const [],
      repairPartnerPayments: const [],
      supplierImports: const [],
      repairPartsCostFundRows: const [],
      salesReturns: salesReturns,
      enableRepair: true,
    );

void main() {
  group('A. FinanceV2 — doanh thu/vốn ACCRUAL, tách khỏi dòng tiền', () {
    late FinanceV2Snapshot s;

    setUpAll(() async {
      s = await _snapshot();
    });

    test('A1 doanh thu bán đủ 23.900.000 — kể cả CÔNG NỢ, trả góp, KẾT HỢP thu thiếu',
        () {
      // 3tr (CN) + 15tr (trả góp) + 5tr (KẾT HỢP) + 1tr (TM) − trả hàng 100k.
      expect(s.incomeFromSales, 23900000);
    });

    test('A2 giá vốn bán đủ 18.940.000 — không còn tính theo tỉ lệ tiền thu',
        () {
      // 2,4tr + 12tr + 4tr + 0,6tr − trả hàng 60k.
      expect(s.cogsFromSales, 18940000);
      expect(s.grossProfitFromSales, 4960000);
    });

    test('A3 tiền bán thực thu 8.900.000 — CON SỐ CŨ, dùng cho cơ cấu tiền thu',
        () {
      // C1 (CN) 0 + cọc C2 5tr + C3 đã thu 3tr + C4 1tr − hoàn 100k.
      expect(s.cashFromSales, 8900000);
      // Bằng nhau ⇒ doanh thu "đã thu" không còn là khái niệm nửa vời.
      expect(s.cashFromSales, isNot(s.incomeFromSales));
    });

    test('A4 sửa chữa: CN vẫn vào doanh thu, không vào tiền', () {
      expect(s.incomeFromRepairs, 1300000, reason: 'P1 500k + P2 (CN) 800k');
      expect(s.cogsFromRepairs, 500000, reason: '200k + 300k (CN)');
      expect(s.cashFromRepairs, 500000, reason: 'chỉ P1');
    });

    test('A5 dòng thu nợ là TIỀN, không cộng doanh thu (kể cả khi gắn đơn)', () async {
      expect(s.debtCollectIn, 1000000, reason: 'dp1 700k + dp2 300k');
      expect(s.incomeOther, 0, reason: 'incomeOther đã loại thu nợ');

      final linked = await _snapshot(linkDebt: true);
      expect(linked.totalIn, s.totalIn);
      expect(linked.incomeFromSales, s.incomeFromSales,
          reason: 'doanh thu C1 đã ghi đủ từ ngày bán, không cộng thêm 700k');
      expect(linked.cogsFromSales, s.cogsFromSales);
      expect(linked.grossProfitTotal, s.grossProfitTotal);
      expect(linked.debtCollectIn, s.debtCollectIn);

      final rows = linked.transactions
          .where((t) => t.type == 'DEBT_COLLECT' && t.referenceId == 'D1')
          .toList();
      expect(rows, isNotEmpty);
      expect(rows.map((t) => t.costAmount), everyElement(isNull),
          reason: 'dòng TIỀN không được để lộ giá vốn (CLAUDE.md §9)');
    });

    test('A6 bất biến: cộng đủ các mục TIỀN = tổng tiền vào (trừ phần hoàn)', () {
      // 8.9tr + 0,5tr + 1tr + 0 = 10,4tr ; totalIn = 10,5tr − refundOut 100k.
      expect(
        s.cashFromSales + s.cashFromRepairs + s.debtCollectIn + s.incomeOther,
        s.totalIn - 100000,
      );
    });

    test('A7 hoàn hàng trừ doanh thu/vốn với MỌI PTTT', () async {
      // RET1 refundMethod = TIỀN MẶT → đã nằm trong A1/A2.
      expect(s.incomeFromSales, 24000000 - 100000);
      expect(s.cogsFromSales, 19000000 - 60000);
      final cnReturn = await FinanceV2DataService(
        dbHelper: _AccrualDb(),
      ).loadSnapshot(start: _day, end: _day);
      expect(cnReturn.transactions.where((t) => t.type == 'REFUND'), isNotEmpty);
    });
  });

  group('B. DailyFinancialAnalysisService — accrual + tách tiền', () {
    test('B1 trả góp: doanh thu/vốn ĐỦ ngay, TIỀN chỉ là cọc', () {
      final r = _analyze(sales: [_saleMap(_sales[1])]);
      expect(r.saleIncome, 15000000);
      expect(r.saleCost, 12000000);
      expect(r.saleProfit, 3000000);
      expect(r.saleCash, 5000000);
      expect(r.cashIn, 5000000);
    });

    test('B2 KẾT HỢP thu thiếu: lãi bằng đơn trả hết tiền, tiền chỉ tính phần thu',
        () {
      final r = _analyze(sales: [_saleMap(_sales[2])]);
      expect(r.saleIncome, 5000000);
      expect(r.saleCost, 4000000);
      expect(r.saleCash, 3000000);
      expect(r.cashIn, 2000000);
      expect(r.bankIn, 1000000);
    });

    test('B3 CÔNG NỢ: đủ doanh thu/vốn, không có dòng tiền', () {
      final r = _analyze(sales: [_saleMap(_sales[0])]);
      expect(r.saleIncome, 3000000);
      expect(r.saleCost, 2400000);
      expect(r.saleCash, 0);
      expect(r.totalIn, 0);
    });

    test('B4 tất toán NH trong CÙNG kỳ bán: giá vốn chỉ tính 1 lần', () {
      // Đơn bán + đơn tất toán cùng xuất hiện (S bán hôm nay, NH trả hôm nay).
      final r = _analyze(
        sales: [_saleMap(_sales[1])],
        settlementSales: [
          _saleMap(
            _sale(
              fid: 'C2S',
              total: 15000000,
              cost: 12000000,
              method: 'TRẢ GÓP',
              installment: true,
              down: 5000000,
              loan: 10000000,
              settledAt: _at(15),
              settlement: 10000000,
            ),
          ),
        ],
      );
      expect(r.saleCost, 12000000, reason: 'KHÔNG cộng thêm remainRatio');
      expect(r.saleIncome, 15000000);
      expect(r.settlementIncome, 10000000, reason: 'tiền tất toán vẫn hiện riêng');
      expect(r.saleCash, 5000000, reason: 'saleCash không gồm tất toán NH');
      expect(r.bankIn, 10000000);
    });

    test('B5 lãi không cộng tiền tất toán (tránh double-count doanh thu)', () {
      final r = _analyze(
        sales: [_saleMap(_sales[1])],
        settlementSales: [
          _saleMap(
            _sale(
              fid: 'C2S',
              total: 15000000,
              cost: 12000000,
              method: 'TRẢ GÓP',
              installment: true,
              down: 5000000,
              loan: 10000000,
              settledAt: _at(15),
              settlement: 10000000,
            ),
          ),
        ],
      );
      expect(r.saleProfit, r.saleIncome - r.saleCost);
      expect(r.netProfit, r.saleIncome - r.saleCost);
    });

    test('B6 hoàn CÔNG NỢ: huỷ doanh thu/vốn nhưng không tạo dòng tiền', () {
      final r = _analyze(salesReturns: _returns.map((e) => {
            ...e,
            'refundMethod': _cn,
          }).toList());
      expect(r.saleIncome, -100000);
      expect(r.saleCost, -60000);
      expect(r.refundOut, 0);
      expect(r.cashOut, 0);
      expect(r.saleCash, 0);
    });

    test('B7 hoàn TIỀN MẶT: vừa trừ doanh thu vừa có tiền ra', () {
      final r = _analyze(salesReturns: _returns);
      expect(r.saleIncome, -100000);
      expect(r.saleCost, -60000);
      expect(r.refundOut, 100000);
      expect(r.cashOut, 100000);
      expect(r.saleCash, -100000);
    });

    test('B8 bán đủ 4 PTTT trong ngày: 2 engine cho cùng 1 lãi gộp', () async {
      final a = _analyze(
        sales: _sales.map(_saleMap).toList(),
        repairs: _repairs.map(_repairMap).toList(),
        salesReturns: _returns,
      );
      final s = await _snapshot();
      expect(a.saleIncome, s.incomeFromSales,
          reason: 'cùng công thức finalPrice − trả hàng');
      expect(a.saleCost, s.cogsFromSales);
      expect(a.repairIncome, s.incomeFromRepairs);
      expect(a.repairCost, s.cogsFromRepairs);
    });
  });
}
