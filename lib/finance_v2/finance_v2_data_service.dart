import 'package:flutter/foundation.dart' show visibleForTesting;
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import '../services/user_service.dart';
import 'finance_v2_cache.dart';

enum FinanceV2Aggregation { day, month, year }

class FinanceV2MetricCard {
  final String label;
  final int amount;
  final int? previousAmount; // For period comparison

  const FinanceV2MetricCard({
    required this.label,
    required this.amount,
    this.previousAmount,
  });

  /// Calculate % change: positive = increase, negative = decrease
  /// Returns null if no previous amount
  double? get percentChange {
    if (previousAmount == null || previousAmount == 0) return null;
    return ((amount - previousAmount!) / previousAmount!) * 100;
  }
}

class FinanceV2Txn {
  final String id;
  final int createdAt;
  final String type;
  final String title;
  final String subtitle;
  final int amount;
  final bool isIncome;
  final String? avatarUrl;
  final String? actorName;
  final String? paymentMethod;
  final String? referenceId;
  final String? customerName;
  final String? itemName;
  final int? costAmount;
  final int? grossProfit;

  const FinanceV2Txn({
    required this.id,
    required this.createdAt,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isIncome,
    this.avatarUrl,
    this.actorName,
    this.paymentMethod,
    this.referenceId,
    this.customerName,
    this.itemName,
    this.costAmount,
    this.grossProfit,
  });
}

class FinanceV2DebtItem {
  final String id;
  final String type;
  final String name;
  final int total;
  final int paid;
  final int remaining;
  final String? avatarUrl;
  final int createdAt;
  final String? phone;

  /// Ghi chú của khoản nợ — chính là chỗ ghi "nợ từ đâu": *"Nợ nhập IPHONE
  /// 15PROMAX…"*, *"Vốn linh kiện: …"*, *"Nợ mua máy: …"*. Trước đây snapshot
  /// bỏ trường này, nên tab Nợ chỉ hiện được tên + số tiền, mở ra không biết
  /// khoản đó phát sinh vì việc gì.
  final String? note;

  const FinanceV2DebtItem({
    required this.id,
    required this.type,
    required this.name,
    required this.total,
    required this.paid,
    required this.remaining,
    this.avatarUrl,
    required this.createdAt,
    this.phone,
    this.note,
  });
}

class FinanceV2PeriodBucket {
  final String key;
  final String label;
  final int totalIn;
  final int totalOut;
  final int txCount;

  const FinanceV2PeriodBucket({
    required this.key,
    required this.label,
    required this.totalIn,
    required this.totalOut,
    required this.txCount,
  });

  int get net => totalIn - totalOut;
}

class FinanceV2CategoryStat {
  final String label;
  final int amount;

  const FinanceV2CategoryStat({required this.label, required this.amount});
}

class FinanceV2Snapshot {
  final int totalIn;
  final int totalOut;

  /// Tiền ra thuần (không tính trả nợ NCC, nhập hàng, TT đối tác)
  final int operatingExpenseOut;

  /// Tiền trả nợ nhà cung cấp / đối tác (SHOP_OWES)
  final int debtRepayOut;

  /// Tiền thanh toán đối tác sửa chữa (repair_partner_payments)
  final int partnerPaymentOut;

  /// Tiền nhập hàng (supplier_import_history + chi phí nhập)
  final int importExpenseOut;
  final int receivableTotal;
  final int payableTotal;
  final int netCashflow;

  /// Doanh thu BÁN HÀNG — ACCRUAL: cộng đủ `finalPrice` của mọi đơn bán trong
  /// kỳ (bound theo `soldAt`), gồm cả CÔNG NỢ / TRẢ GÓP / KẾT HỢP, trừ hoàn
  /// trả. Ghi nhận ngay NGÀY BÁN, không phụ thuộc ngày khách trả tiền — cùng
  /// một công thức với Sale List (`finalPrice - totalCost`) và Chốt quỹ.
  /// Muốn xem TIỀN THỰC THU dùng [cashFromSales].
  final int incomeFromSales;

  /// Doanh thu SỬA CHỮA — ACCRUAL: cộng đủ `repair.price` của mọi đơn đã giao
  /// trong kỳ (gồm cả CÔNG NỢ), trừ hoàn trả. Ghi nhận ngay NGÀY GIAO.
  /// Muốn xem TIỀN THỰC THU dùng [cashFromRepairs].
  final int incomeFromRepairs;

  /// Tiền bán hàng THỰC THU trong kỳ (cash basis) — đúng con số cũ của
  /// `incomeFromSales` trước khi chuyển sang accrual, để bảng "Cơ cấu tiền thu
  /// vào", Excel "Tiền bán hàng đã thu" và thẻ "Tiền bán" trên Home giữ nguyên
  /// ý nghĩa TIỀN VÀO.
  final int cashFromSales;

  /// Tiền sửa chữa THỰC THU trong kỳ (cash basis).
  final int cashFromRepairs;

  /// Tiền THU NỢ khách hàng trong kỳ (cash basis) — bản chất là tiền vào từ
  /// các đơn CÔNG NỢ, tách khỏi [incomeOther] để không lẫn "thu khác".
  final int debtCollectIn;
  final int cogsFromSales;
  final int cogsFromRepairs;
  final int grossProfitFromSales;
  final int grossProfitFromRepairs;
  final int grossProfitTotal;
  final int incomeOther;
  final int transactionCount;
  final int avgIncomePerTransaction;
  final int previousTotalIn;
  final int previousTotalOut;
  final int previousNetCashflow;
  final int previousCashFromSales;
  final int previousCashFromRepairs;
  final int previousCogsFromSales;
  final int previousCogsFromRepairs;
  final int previousGrossProfitFromSales;
  final int previousGrossProfitFromRepairs;
  final List<FinanceV2MetricCard> dashboardCards;
  final List<FinanceV2CategoryStat> topExpenseCategories;
  final List<FinanceV2Txn> transactions;
  final List<FinanceV2DebtItem> receivables;
  final List<FinanceV2DebtItem> payables;
  final List<FinanceV2PeriodBucket> byDay;
  final List<FinanceV2PeriodBucket> byMonth;
  final List<FinanceV2PeriodBucket> byYear;
  final List<Map<String, dynamic>> auditLogs;
  final Map<String, int>
  debtAging; // {'0-30': 1000000, '30-60': 500000, '>60': 2000000}

  const FinanceV2Snapshot({
    required this.totalIn,
    required this.totalOut,
    required this.operatingExpenseOut,
    required this.debtRepayOut,
    this.partnerPaymentOut = 0,
    this.importExpenseOut = 0,
    required this.receivableTotal,
    required this.payableTotal,
    required this.netCashflow,
    required this.incomeFromSales,
    required this.incomeFromRepairs,
    this.cashFromSales = 0,
    this.cashFromRepairs = 0,
    this.debtCollectIn = 0,
    required this.cogsFromSales,
    required this.cogsFromRepairs,
    required this.grossProfitFromSales,
    required this.grossProfitFromRepairs,
    required this.grossProfitTotal,
    required this.incomeOther,
    required this.transactionCount,
    required this.avgIncomePerTransaction,
    required this.previousTotalIn,
    required this.previousTotalOut,
    required this.previousNetCashflow,
    this.previousCashFromSales = 0,
    this.previousCashFromRepairs = 0,
    required this.previousCogsFromSales,
    required this.previousCogsFromRepairs,
    required this.previousGrossProfitFromSales,
    required this.previousGrossProfitFromRepairs,
    required this.dashboardCards,
    required this.topExpenseCategories,
    required this.transactions,
    required this.receivables,
    required this.payables,
    required this.byDay,
    required this.byMonth,
    required this.byYear,
    required this.auditLogs,
    required this.debtAging,
  });

  List<FinanceV2PeriodBucket> buckets(FinanceV2Aggregation aggregation) {
    switch (aggregation) {
      case FinanceV2Aggregation.day:
        return byDay;
      case FinanceV2Aggregation.month:
        return byMonth;
      case FinanceV2Aggregation.year:
        return byYear;
    }
  }

  /// Get total debt aging amount (sum of all aging buckets)
  int get totalDebtAging {
    return (debtAging['0-30'] ?? 0) +
        (debtAging['30-60'] ?? 0) +
        (debtAging['>60'] ?? 0);
  }
}

class FinanceV2DataService {
  final DBHelper _db;

  FinanceV2DataService({DBHelper? dbHelper}) : _db = dbHelper ?? DBHelper();

  String _canonicalImportReference(String? rawReference) {
    var value = (rawReference ?? '').trim();
    if (value.isEmpty) return value;
    value = value.replaceFirst(RegExp(r'^exp_stock_'), '');
    value = value.replaceFirst(RegExp(r'^exp_quick_part_'), '');
    value = value.replaceFirst(RegExp(r'^stock_'), '');
    value = value.replaceFirst(RegExp(r'_\d{10,}$'), '');
    return value;
  }

  bool _isImportExpense(Map<String, dynamic> expense) {
    final title = (expense['title'] ?? '').toString().toUpperCase();
    final category = (expense['category'] ?? '').toString().toUpperCase();
    return category.contains('NHẬP') ||
        category.contains('LINH KIỆN') ||
        // Chi phí sửa/tân trang SP trong kho (2026-09-22) đã cộng vào
        // `products.refurbishCost` ⇒ về sau ra lãi qua giá vốn lúc bán —
        // coi như vốn hàng (capitalized) để không trừ lãi 2 lần.
        category.contains('TÂN TRANG') ||
        title.contains('NHẬP') ||
        category.contains('PURCHASE');
  }

  /// Tiền THỰC NHẬN của một đơn trả góp rơi vào khoảng [startMs, endMs].
  ///
  /// Trước đây mọi nơi tính `downPayment + settlementAmount` trên danh sách đơn
  /// **bound theo `soldAt`**, sai cả hai chiều:
  /// - đơn bán TRONG kỳ nhưng ngân hàng trả tiền SAU kỳ ⇒ ghi nhận SỚM;
  /// - đơn bán TRƯỚC kỳ, ngân hàng trả tiền TRONG kỳ ⇒ BỎ SÓT.
  ///
  /// Đo trên shop thật 06/09/2026: cửa sổ 30 ngày bỏ sót **59.660.000đ** của 5
  /// đơn bán đầu tháng 8 mà ngân hàng trả ngày 19/08.
  ///
  /// Quy tắc đúng theo cash basis: cọc tính theo ngày BÁN, phần tất toán tính
  /// theo ngày NHẬN TIỀN — mỗi khoản vào đúng kỳ tiền thật về.
  @visibleForTesting
  static int installmentCashIn(SaleOrder sale, int startMs, int endMs) {
    var received = 0;
    if (sale.soldAt >= startMs && sale.soldAt <= endMs) {
      received += sale.downPayment;
    }
    final settledAt = sale.settlementReceivedAt;
    if (settledAt != null && settledAt >= startMs && settledAt <= endMs) {
      received += sale.settlementAmount;
    }
    return received;
  }

  /// Gộp đơn tất toán-trong-kỳ vào danh sách đơn bán-trong-kỳ, khử trùng theo
  /// `firestoreId` (rơi về `id` khi chưa đồng bộ).
  List<SaleOrder> _mergeSettlementSales(
    List<SaleOrder> sales,
    List<SaleOrder> settled,
  ) {
    if (settled.isEmpty) return sales;
    String keyOf(SaleOrder s) {
      final fid = (s.firestoreId ?? '').trim();
      return fid.isNotEmpty ? fid : 'local_${s.id}';
    }

    final seen = sales.map(keyOf).toSet();
    final merged = List<SaleOrder>.from(sales);
    for (final s in settled) {
      if (seen.add(keyOf(s))) merged.add(s);
    }
    return merged;
  }

  /// `shopId` hiện tại, an toàn khi không có Firebase (test): trả `null` ⇒
  /// [FinanceV2Cache] không cache, mỗi lần gọi tính lại từ DB stub.
  static String? _safeShopId() {
    try {
      return UserService.getShopIdSync();
    } catch (_) {
      return null;
    }
  }

  /// Nạp snapshot cho khoảng kỳ. Có [FinanceV2Cache] phía trước: cùng shop +
  /// cùng kỳ + chưa bị sự kiện nghiệp vụ làm bẩn mảng đang cần ([needs]) thì
  /// trả bản trong bộ nhớ, KHÔNG chạm SQLite. [forceRefresh] (kéo để làm mới)
  /// bỏ qua cache.
  Future<FinanceV2Snapshot> loadSnapshot({
    DateTime? start,
    DateTime? end,
    DateTime? previousStart,
    DateTime? previousEnd,
    bool forceRefresh = false,
    Set<FinanceSection> needs = const {
      FinanceSection.cash,
      FinanceSection.profit,
      FinanceSection.debt,
      FinanceSection.transactions,
    },
  }) async {
    final now = DateTime.now();
    final rangeStart = DateTime(
      (start ?? DateTime(now.year, now.month, 1)).year,
      (start ?? DateTime(now.year, now.month, 1)).month,
      (start ?? DateTime(now.year, now.month, 1)).day,
    );
    final rangeEnd = DateTime(
      (end ?? now).year,
      (end ?? now).month,
      (end ?? now).day,
      23,
      59,
      59,
    );

    final startMs = rangeStart.millisecondsSinceEpoch;
    final endMs = rangeEnd.millisecondsSinceEpoch;
    final periodMs = endMs - startMs + 1;

    // Tính khoảng kỳ trước: ưu tiên tham số truyền vào, nếu không thì dùng độ dài tương đương
    final int previousStartMs;
    final int previousEndMs;
    if (previousStart != null && previousEnd != null) {
      previousStartMs = DateTime(
        previousStart.year,
        previousStart.month,
        previousStart.day,
      ).millisecondsSinceEpoch;
      previousEndMs = DateTime(
        previousEnd.year,
        previousEnd.month,
        previousEnd.day,
        23,
        59,
        59,
      ).millisecondsSinceEpoch;
    } else {
      previousEndMs = startMs - 1;
      previousStartMs = previousEndMs - periodMs + 1;
    }

    final cacheKey = FinanceV2Cache.key(
      shopId: _safeShopId(),
      startMs: startMs,
      endMs: endMs,
      previousStartMs: previousStartMs,
      previousEndMs: previousEndMs,
    );
    if (!forceRefresh) {
      final cached = FinanceV2Cache.get(cacheKey, needs: needs);
      if (cached != null) return cached;
    }

    // Start all reads simultaneously so sqflite can pipeline them.
    final salesF = _db.getSalesByDateRange(startMs, endMs);
    final repairsF = _db.getDeliveredRepairsByDateRange(startMs, endMs);
    final expensesF = _db.getExpensesByDateRange(startMs, endMs);
    final repairPartnerPaymentsF = _db.getRepairPartnerPaymentsByDateRange(startMs, endMs);
    final debtPaymentsF = _db.getDebtPaymentsForCashFlowByDateRange(startMs, endMs);
    final salesReturnsF = _db.getSalesReturnsByDateRange(startMs, endMs);
    final importHistoryF = _db.getAllImportHistoryByDateRange(startMs, endMs);
    final debtsF = _db.getOutstandingDebtsForFinanceSnapshot();
    final activitiesF = _db.getFinancialActivities(startDate: startMs, endDate: endMs, limit: 500);
    final costFundRepairsF = _db.getRepairsCostFundByDateRange(startMs, endMs);
    // Đơn trả góp NHẬN tiền tất toán trong kỳ — có thể đã bán từ rất lâu nên
    // không nằm trong `salesF` (bound theo soldAt). Xem `_installmentCashIn`.
    final settledF = _db.getInstallmentSalesSettledBetween(startMs, endMs);
    final previousSettledF =
        _db.getInstallmentSalesSettledBetween(previousStartMs, previousEndMs);
    final previousSalesF = _db.getSalesByDateRange(previousStartMs, previousEndMs);
    final previousRepairsF = _db.getDeliveredRepairsByDateRange(previousStartMs, previousEndMs);
    final previousExpensesF = _db.getExpensesByDateRange(previousStartMs, previousEndMs);
    final previousRepairPartnerPaymentsF = _db.getRepairPartnerPaymentsByDateRange(previousStartMs, previousEndMs);
    final previousDebtPaymentsF = _db.getDebtPaymentsForCashFlowByDateRange(previousStartMs, previousEndMs);
    final suppliersF = _db.getSuppliers();
    final partnersF = _db.getRepairPartners();
    final customersF = _db.getCustomers();

    // Collect results (all DB work started above in parallel)
    // `*InPeriod` = đơn bán bound theo soldAt — nguồn tính ACCRUAL (doanh thu/
    // giá vốn ghi nhận ngay ngày bán). `sales` = bản gộp thêm đơn tất toán
    // trong kỳ, chỉ dùng cho các khoản TIỀN THỰC VÀO — không được cộng doanh
    // thu lần nữa từ những đơn đã bán từ trước đó.
    final salesInPeriod = await salesF;
    final sales = _mergeSettlementSales(salesInPeriod, await settledF);
    final repairs = await repairsF;
    final expenses = await expensesF;
    final repairPartnerPayments = await repairPartnerPaymentsF;
    final debtPayments = await debtPaymentsF;
    final salesReturns = await salesReturnsF;
    final importHistory = await importHistoryF;
    final debts = await debtsF;
    final activities = await activitiesF;
    final costFundRepairs = await costFundRepairsF;
    final previousSalesInPeriod = await previousSalesF;
    final previousSales =
        _mergeSettlementSales(previousSalesInPeriod, await previousSettledF);
    final previousRepairs = await previousRepairsF;
    final previousExpenses = await previousExpensesF;
    final previousRepairPartnerPayments = await previousRepairPartnerPaymentsF;
    final previousDebtPayments = await previousDebtPaymentsF;
    final suppliers = await suppliersF;
    final partners = await partnersF;
    final customers = await customersF;

    // Phiếu thu nợ gắn với đơn CÔNG NỢ (`debts.linkedId` = `sale_…` / `rep_…`).
    // [2026-09-24] KHÔNG còn cộng vào doanh thu/giá vốn: doanh thu đã được ghi
    // nhận đầy đủ từ ngày BÁN (accrual), thu nợ thuần là TIỀN VÀO → rơi vào
    // `extraIn + debtCollectIn` ("Thu nợ KH"). Vẫn tra lô để hiển thị tên đơn
    // trong dòng giao dịch, không cộng số liệu.
    final linkedIds = <String>{};
    for (final p in [...debtPayments, ...previousDebtPayments]) {
      final linked = (p['linkedDebtLinkedId'] ?? '').toString().trim();
      if (linked.isNotEmpty) linkedIds.add(linked);
    }
    final linkedSales = await _db.getSalesByFirestoreIds(linkedIds);
    final linkedRepairs = await _db.getRepairsByFirestoreIds(linkedIds);

    final supplierAvatarByName = <String, String>{};
    final supplierPhoneByName = <String, String>{};
    for (final row in suppliers) {
      final key = _normalizeName(row['name']);
      if (key.isEmpty) continue;
      final avatar = (row['avatarUrl'] ?? '').toString();
      final phone = (row['phone'] ?? '').toString();
      if (avatar.isNotEmpty) supplierAvatarByName[key] = avatar;
      if (phone.isNotEmpty) supplierPhoneByName[key] = phone;
    }

    final partnerAvatarByName = <String, String>{};
    final partnerPhoneByName = <String, String>{};
    for (final row in partners) {
      final key = _normalizeName(row['name']);
      if (key.isEmpty) continue;
      final avatar = (row['avatarUrl'] ?? '').toString();
      final phone = (row['phone'] ?? '').toString();
      if (avatar.isNotEmpty) partnerAvatarByName[key] = avatar;
      if (phone.isNotEmpty) partnerPhoneByName[key] = phone;
    }

    final customerAvatarByName = <String, String>{};
    final customerPhoneByName = <String, String>{};
    for (final row in customers) {
      final key = _normalizeName(row['name']);
      if (key.isEmpty) continue;
      final avatar = (row['avatarUrl'] ?? '').toString();
      final phone = (row['phone'] ?? '').toString();
      if (avatar.isNotEmpty) customerAvatarByName[key] = avatar;
      if (phone.isNotEmpty) customerPhoneByName[key] = phone;
    }

    int saleIn = 0;
    int repairIn = 0;
    int expenseOut = 0;
    int importExpenseOut = 0;
    int partnerPaymentOut = 0; // TT đối tác sửa chữa — tách riêng để hiển thị
    // Vốn sửa chữa đã được tính vào `repairCogs` lúc giao máy nhưng vẫn phải
    // hiện là tiền RA trong sổ quỹ (`repair_cost_*` dịch vụ nội bộ và
    // `parts_cost_*` linh kiện ghi sổ quỹ). Gom riêng để LOẠI khỏi
    // `operatingExpenseOut`, nếu không "lãi sau chi phí" trừ vốn SC 2 lần
    // (1 lần ở lãi gộp, 1 lần ở chi vận hành) — khớp cách
    // DailyFinancialAnalysisService không đưa repairPartsCostFund vào netProfit.
    int repairCostMirrorOut = 0;
    int debtRepayOut =
        0; // Trả nợ NCC/đối tác (SHOP_OWES) — tách riêng để hiển thị
    int extraIn = 0;
    int debtCollectIn = 0; // Thu nợ KH — tracked separately so incomeOther excludes it
    int repairCogs = 0; // vốn SC theo TIỀN — chỉ dùng cho cơ cấu chi phí

    // ── ACCRUAL: kết quả kinh doanh, ghi nhận ngay ngày bán / ngày giao ──
    int saleAccrualRevenue = 0;
    int saleAccrualCogs = 0;
    int previousSaleAccrualRevenue = 0;
    int previousSaleAccrualCogs = 0;
    int repairAccrualRevenue = 0;
    int repairAccrualCogs = 0;
    int previousRepairAccrualRevenue = 0;
    int previousRepairAccrualCogs = 0;

    // Đơn bán TRONG kỳ (bound theo soldAt) — không gộp đơn tất toán: doanh
    // thu của đơn đó đã thuộc kỳ nó bán, gộp vào đây là cộng 2 lần.
    for (final SaleOrder sale in salesInPeriod) {
      if (sale.finalPrice > 0) saleAccrualRevenue += sale.finalPrice;
      if (sale.totalCost > 0) saleAccrualCogs += sale.totalCost;
    }
    for (final SaleOrder sale in previousSalesInPeriod) {
      if (sale.finalPrice > 0) previousSaleAccrualRevenue += sale.finalPrice;
      if (sale.totalCost > 0) previousSaleAccrualCogs += sale.totalCost;
    }

    final transactions = <FinanceV2Txn>[];

    for (final SaleOrder sale in sales) {
      final bool isCongNo = sale.paymentMethod.toUpperCase() == 'CÔNG NỢ';
      final installmentBanks = <String>[];
      final bank1 = (sale.bankName ?? '').trim();
      final bank2 = (sale.bankName2 ?? '').trim();
      if (bank1.isNotEmpty) installmentBanks.add(bank1);
      if (bank2.isNotEmpty && bank2.toUpperCase() != bank1.toUpperCase()) {
        installmentBanks.add(bank2);
      }
      final paymentSummary = sale.isInstallment
          ? 'TRẢ GÓP${installmentBanks.isNotEmpty ? ' · NH: ${installmentBanks.join(', ')}' : ''}'
          : sale.paymentMethod;
      final bool isKetHop = sale.paymentMethod.toUpperCase() == 'KẾT HỢP';
      final int actualPaid;
      if (sale.isInstallment) {
        actualPaid = installmentCashIn(sale, startMs, endMs);
      } else if (isCongNo) {
        actualPaid = 0;
      } else if (isKetHop && (sale.cashAmount + sale.transferAmount) > 0) {
        actualPaid = sale.cashAmount + sale.transferAmount;
      } else {
        actualPaid = sale.finalPrice;
      }

      if (actualPaid > 0) {
        // Vốn gắn với DÒNG TIỀN này chỉ dùng để hiển thị trên dòng giao dịch
        // (cột vốn/lãi của từng khoản tiền). Doanh thu + giá vốn của tab Lãi
        // tính riêng theo ACCRUAL ở trên — không lấy từ đây.
        int recognizedCost = 0;
        if (sale.totalCost > 0) {
          final costDenominator =
              (isKetHop && (sale.cashAmount + sale.transferAmount) > 0)
              ? actualPaid
              : sale.finalPrice;
          if (costDenominator > 0) {
            recognizedCost = ((sale.totalCost * actualPaid) / costDenominator)
                .round();
          } else {
            recognizedCost = sale.totalCost;
          }
          if (recognizedCost < 0) recognizedCost = 0;
        }
        saleIn += actualPaid;
        // Đơn góp bán TRƯỚC kỳ nhưng NH tất toán TRONG kỳ (về qua
        // `getInstallmentSalesSettledBetween`): tiền vào là khoản tất toán nên
        // dòng sổ phải mang ngày NHẬN TIỀN — gắn `soldAt` sẽ đẩy dòng ra ngoài
        // kỳ, biểu đồ theo ngày/tháng lệch dù tổng vẫn đúng.
        final soldInRange = sale.soldAt >= startMs && sale.soldAt <= endMs;
        final txnAt = soldInRange
            ? sale.soldAt
            : (sale.settlementReceivedAt ?? sale.soldAt);
        transactions.add(
          FinanceV2Txn(
            id: 'sale_${sale.id ?? sale.firestoreId ?? sale.soldAt}',
            createdAt: txnAt,
            type: 'SALE',
            title: sale.productNames.trim().isNotEmpty
                ? sale.productNames.trim()
                : 'Sản phẩm bán lẻ',
            subtitle:
                'Khách: ${sale.customerName.isNotEmpty ? sale.customerName : 'Khách lẻ'}'
                '${paymentSummary.isNotEmpty ? ' · $paymentSummary' : ''}',
            amount: actualPaid,
            isIncome: true,
            avatarUrl: customerAvatarByName[_normalizeName(sale.customerName)],
            actorName: sale.sellerName.trim().isEmpty ? null : sale.sellerName,
            paymentMethod: sale.paymentMethod,
            referenceId: sale.firestoreId ?? sale.id?.toString(),
            customerName: sale.customerName,
            itemName: sale.productNames,
            costAmount: recognizedCost,
            grossProfit: actualPaid - recognizedCost,
          ),
        );
      }
    }

    for (final Repair repair in repairs) {
      final amount = repair.price;
      final repairCost = repair.totalCost > 0 ? repair.totalCost : 0;
      final bool isCongNo = repair.paymentMethod.toUpperCase() == 'CÔNG NỢ';
      // ACCRUAL: đơn đã giao trong kỳ ghi nhận đủ doanh thu + giá vốn ngay
      // ngày GIAO, kể cả CÔNG NỢ. `repair.price` đã gồm cả phần chênh lệch sửa
      // giá sau giao → phiếu thu nợ REPAIR_PRICE_ADJUST không được cộng thêm
      // (tránh ghi nhận 2 lần).
      if (amount > 0) repairAccrualRevenue += amount;
      if (repairCost > 0) repairAccrualCogs += repairCost;
      if (amount > 0) {
        if (!isCongNo) {
          repairIn += amount;
          // Vốn sửa chữa theo TIỀN — chỉ dùng cho cơ cấu chi phí.
          repairCogs += repairCost;
          // Sổ giao dịch = TIỀN: đơn CÔNG NỢ chưa thu nên không có dòng tiền.
          transactions.add(
            FinanceV2Txn(
              id: 'repair_${repair.id ?? repair.firestoreId ?? repair.createdAt}',
              createdAt: repair.deliveredAt ?? repair.createdAt,
              type: 'REPAIR',
              title: repair.customerName,
              subtitle:
                  'Sửa ${repair.model.isNotEmpty ? repair.model : 'thiết bị'}'
                  '${repair.issue.isNotEmpty ? ' · ${repair.issue}' : ''}'
                  '${repair.paymentMethod.isNotEmpty ? ' · ${repair.paymentMethod}' : ''}',
              amount: amount,
              isIncome: true,
              avatarUrl:
                  customerAvatarByName[_normalizeName(repair.customerName)],
              actorName:
                  (repair.repairedBy ?? repair.createdBy ?? '').trim().isEmpty
                  ? null
                  : (repair.repairedBy ?? repair.createdBy ?? '').trim(),
              paymentMethod: repair.paymentMethod,
              referenceId: repair.firestoreId ?? repair.id?.toString(),
              customerName: repair.customerName,
              itemName: repair.model,
              costAmount: repairCost,
              grossProfit: amount - repairCost,
            ),
          );
        }
      }
      // Chi phí linh kiện/dịch vụ nội bộ (service không qua đối tác, partnerId == null)
      // Đây là chi phí nhân công/linh kiện tự ghi trong đơn sửa, không trùng với repair_partner_payments
      final nonPartnerCost = repair.services
          .where((s) => s.partnerId == null)
          .fold<int>(0, (sum, s) => sum + s.cost);
      if (nonPartnerCost > 0) {
        expenseOut += nonPartnerCost;
        repairCostMirrorOut += nonPartnerCost;
        transactions.add(
          FinanceV2Txn(
            id: 'repair_cost_${repair.id ?? repair.firestoreId ?? repair.createdAt}',
            createdAt: repair.deliveredAt ?? repair.createdAt,
            type: 'EXPENSE',
            title: 'Giá vốn: ${repair.customerName}',
            subtitle:
                'Chi phí sửa ${repair.model.isNotEmpty ? repair.model : "thiết bị"}'
                '${repair.issue.isNotEmpty ? " · ${repair.issue}" : ""}',
            amount: nonPartnerCost,
            isIncome: false,
            avatarUrl:
                customerAvatarByName[_normalizeName(repair.customerName)],
            actorName:
                (repair.repairedBy ?? repair.createdBy ?? '').trim().isEmpty
                ? null
                : (repair.repairedBy ?? repair.createdBy ?? '').trim(),
            referenceId: repair.firestoreId ?? repair.id?.toString(),
          ),
        );
      }
    }

    for (final e in expenses) {
      final amount = _toInt(e['amount']);
      final type = (e['type'] ?? 'CHI').toString().toUpperCase();
      final ts = _toInt(e['date']) > 0
          ? _toInt(e['date'])
          : _toInt(e['createdAt']);
      final title = (e['title'] ?? e['category'] ?? 'Giao dịch').toString();
      final isIncome = type == 'THU';
      if (isIncome) {
        extraIn += amount;
      } else {
        expenseOut += amount;
        if (_isImportExpense(e)) {
          importExpenseOut += amount;
        } else if ((e['firestoreId'] ?? '').toString().startsWith('exp_partner_')) {
          partnerPaymentOut += amount;
        }
      }
      transactions.add(
        FinanceV2Txn(
          id: 'expense_${e['id'] ?? e['firestoreId'] ?? ts}',
          createdAt: ts,
          type: isIncome ? 'INCOME' : 'EXPENSE',
          title: title.isEmpty ? (isIncome ? 'Khoản thu' : 'Khoản chi') : title,
          subtitle:
              '${isIncome ? 'Thu phát sinh' : 'Chi phát sinh'}'
              '${(e['category'] ?? '').toString().trim().isNotEmpty ? ' · ${(e['category'] ?? '').toString().trim()}' : ''}'
              '${(e['paymentMethod'] ?? '').toString().trim().isNotEmpty ? ' · ${(e['paymentMethod'] ?? '').toString().trim()}' : ''}',
          amount: amount,
          isIncome: isIncome,
          actorName: (e['createdBy'] ?? '').toString().trim().isEmpty
              ? null
              : (e['createdBy'] ?? '').toString().trim(),
          paymentMethod: (e['paymentMethod'] ?? '').toString(),
          referenceId: (e['firestoreId'] ?? e['id'] ?? '').toString(),
        ),
      );
    }

    // Chi phí linh kiện SC đã ghi sổ quỹ (costRecordedInFund = 1)
    // Dùng repairs table (costRecordedAt in range) thay vì financial_activity_log
    // để luôn lấy giá trị mới nhất và tránh trùng lặp khi user ghi lại nhiều lần.
    for (final r in costFundRepairs) {
      final amount = _toInt(r['costRecordedAmount']) > 0
          ? _toInt(r['costRecordedAmount'])
          : _toInt(r['cost']);
      if (amount <= 0) continue;
      final ts = _toInt(r['costRecordedAt']);
      final method = (r['costPaymentMethod'] ?? 'TIỀN MẶT').toString();
      final customerName = (r['customerName'] ?? '').toString().trim();
      final model = (r['model'] ?? '').toString().trim();
      expenseOut += amount;
      repairCostMirrorOut += amount;
      transactions.add(
        FinanceV2Txn(
          id: 'parts_cost_${r['firestoreId'] ?? r['id'] ?? ts}',
          createdAt: ts,
          type: 'EXPENSE',
          title: 'Vốn linh kiện${customerName.isNotEmpty ? ": $customerName" : ""}',
          subtitle:
              'Chi linh kiện SC${model.isNotEmpty ? " · $model" : ""} · $method',
          amount: amount,
          isIncome: false,
          paymentMethod: method,
          customerName: customerName.isNotEmpty ? customerName : null,
          itemName: model.isNotEmpty ? model : null,
          referenceId: (r['firestoreId'] ?? '').toString(),
        ),
      );
    }

    // Bổ sung thanh toán nhập hàng từ supplier_import_history mà chưa có expense record
    // tương ứng → đảm bảo snap.totalOut nhất quán với activity_log IMPORT entries.
    final representedImportKeys = <String>{};
    for (final e in expenses) {
      if (!_isImportExpense(e)) continue;
      final ref = _canonicalImportReference(
        (e['firestoreId'] ?? e['id'] ?? '').toString(),
      );
      if (ref.isNotEmpty) {
        representedImportKeys.add(ref);
      }
    }
    final importAggTotals = <String, int>{};
    final importAggMethods = <String, String>{};
    for (final item in importHistory) {
      final rawRef =
          (item['referenceId'] ?? item['firestoreId'] ?? item['id'] ?? '')
              .toString()
              .trim();
      final key = rawRef.isNotEmpty
          ? _canonicalImportReference(rawRef)
          : '${(item['supplierName'] ?? '').toString()}|${(item['importDate'] ?? item['createdAt'] ?? 0)}';
      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
      final costPrice = _toInt(item['costPrice']);
      final totalAmt = _toInt(item['totalAmount']) > 0
          ? _toInt(item['totalAmount'])
          : costPrice * (qty > 0 ? qty : 1);
      importAggTotals[key] = (importAggTotals[key] ?? 0) + totalAmt;
      importAggMethods.putIfAbsent(
        key,
        () => (item['paymentMethod'] ?? '').toString().toUpperCase(),
      );
    }
    for (final entry in importAggTotals.entries) {
      final method = importAggMethods[entry.key] ?? '';
      if (method == 'CÔNG NỢ') continue; // Debt-based import: no cash outflow
      final amount = entry.value;
      if (amount <= 0) continue;
      // Skip when already represented by an import expense with same canonical reference.
      if (representedImportKeys.contains(entry.key)) continue;
      expenseOut += amount;
      importExpenseOut += amount;
    }

    final expenseFirestoreIds = <String>{
      ...expenses
          .map((e) => (e['firestoreId'] ?? '').toString().trim())
          .where((id) => id.isNotEmpty),
    };
    for (final p in repairPartnerPayments) {
      final paymentFid = (p['firestoreId'] ?? '').toString().trim();
      if (paymentFid.isEmpty) continue;

      final expectedExpenseFid = paymentFid.startsWith('rpp_')
          ? 'exp_partner_${paymentFid.substring(4)}'
          : 'exp_partner_$paymentFid';
      if (expenseFirestoreIds.contains(expectedExpenseFid)) {
        continue;
      }

      final amount = _toInt(p['amount']);
      if (amount <= 0) continue;
      final ts = _toInt(p['paidAt']);
      final partnerName = (p['partnerName'] ?? '').toString().trim();
      final method = (p['paymentMethod'] ?? '').toString().trim();

      expenseOut += amount;
      partnerPaymentOut += amount;
      transactions.add(
        FinanceV2Txn(
          id: 'partner_payment_${p['id'] ?? paymentFid}',
          createdAt: ts,
          type: 'EXPENSE',
          title: partnerName.isEmpty
              ? 'Thanh toán đối tác sửa chữa'
              : partnerName,
          subtitle:
              'Chi đối tác sửa chữa${method.isNotEmpty ? ' · $method' : ''}',
          amount: amount,
          isIncome: false,
          paymentMethod: method,
          referenceId: paymentFid,
        ),
      );
    }

    for (final p in debtPayments) {
      final amount = _toInt(p['amount']);
      if (amount <= 0) continue;
      final resolvedType =
          (p['resolvedDebtType'] ?? p['debtType'] ?? 'CUSTOMER_OWES')
              .toString();
      // SHOP_OWES / OTHER_SHOP_OWES / OWED = cửa hàng nợ → trả nợ = tiền ra
      final isShopOwes =
          resolvedType == 'SHOP_OWES' ||
          resolvedType == 'OTHER_SHOP_OWES' ||
          resolvedType == 'OWED';
      final isIncome = !isShopOwes; // Thu nợ từ khách = tiền vào
      final name = (p['debtPersonName'] ?? '').toString().trim();
      final ts = _toInt(p['paidAt']);
      final method = (p['paymentMethod'] ?? '').toString().trim();

      _LinkedRevenue? linked;
      if (isIncome) {
        // [2026-09-24] Thu nợ KHÁCH = TIỀN VÀO thuần, luôn vào "Thu nợ KH".
        // Doanh thu / giá vốn của đơn CÔNG NỢ đã ghi nhận đủ từ ngày bán /
        // ngày giao (accrual) → cộng thêm ở đây là tính 2 lần (đó là lỗi
        // `incomeFromSales` phình lên khi khách trả nợ). `linked` chỉ còn
        // dùng để hiện tên đơn trong dòng giao dịch.
        linked = _linkedRevenueOf(p, amount, linkedSales, linkedRepairs);
        extraIn += amount;
        debtCollectIn += amount;
      } else {
        expenseOut += amount;
        debtRepayOut += amount; // Ghi nhận riêng phần trả nợ NCC/đối tác
      }

      transactions.add(
        FinanceV2Txn(
          id: 'debtpay_${p['id'] ?? p['firestoreId'] ?? ts}',
          createdAt: ts,
          type: isIncome ? 'DEBT_COLLECT' : 'DEBT_PAY',
          title: name.isNotEmpty ? name : (isIncome ? 'Thu nợ' : 'Trả nợ'),
          subtitle: isIncome
              ? 'Thu nợ${linked != null ? ' ${linked.isSale ? 'bán hàng' : 'sửa chữa'}' : ''}'
                    '${method.isNotEmpty ? ' · $method' : ''}'
              : 'Trả nợ${method.isNotEmpty ? ' · $method' : ''}',
          amount: amount,
          isIncome: isIncome,
          paymentMethod: method,
          referenceId: (p['debtFirestoreId'] ?? p['firestoreId'] ?? '')
              .toString(),
          itemName: linked?.itemName,
          // Phiếu thu nợ là dòng TIỀN, không phải dòng doanh thu → không gán
          // vốn/lãi ở đây (vốn/lãi nằm ở đơn bán/đơn sửa theo accrual).
          costAmount: null,
          grossProfit: null,
        ),
      );
    }

    int previousSaleIn = 0;
    int previousRepairIn = 0;
    int previousExtraIn = 0;
    int previousExpenseOut = 0;

    for (final SaleOrder sale in previousSales) {
      final bool isCongNo = sale.paymentMethod.toUpperCase() == 'CÔNG NỢ';
      final bool prevIsKetHop = sale.paymentMethod.toUpperCase() == 'KẾT HỢP';
      final int actualPaid;
      if (sale.isInstallment) {
        actualPaid = installmentCashIn(sale, previousStartMs, previousEndMs);
      } else if (isCongNo) {
        actualPaid = 0;
      } else if (prevIsKetHop && (sale.cashAmount + sale.transferAmount) > 0) {
        actualPaid = sale.cashAmount + sale.transferAmount;
      } else {
        actualPaid = sale.finalPrice;
      }

      if (actualPaid > 0) {
        // TIỀN bán hàng kỳ trước. Vốn/lãi kỳ trước tính theo ACCRUAL ở trên
        // (`previousSaleAccrualRevenue` / `previousSaleAccrualCogs`).
        previousSaleIn += actualPaid;
      }
    }

    for (final Repair repair in previousRepairs) {
      if (repair.price > 0) {
        // ACCRUAL kỳ trước — cùng cách với kỳ hiện tại.
        previousRepairAccrualRevenue += repair.price;
        if (repair.totalCost > 0) {
          previousRepairAccrualCogs += repair.totalCost;
        }
        if (repair.paymentMethod.toUpperCase() != 'CÔNG NỢ') {
          previousRepairIn += repair.price;
        }
      }
      final prevNonPartnerCost = repair.services
          .where((s) => s.partnerId == null)
          .fold<int>(0, (sum, s) => sum + s.cost);
      if (prevNonPartnerCost > 0) {
        previousExpenseOut += prevNonPartnerCost;
      }
    }

    for (final p in previousDebtPayments) {
      final amount = _toInt(p['amount']);
      if (amount <= 0) continue;
      final resolvedType =
          (p['resolvedDebtType'] ?? p['debtType'] ?? 'CUSTOMER_OWES')
              .toString();
      final isShopOwes =
          resolvedType == 'SHOP_OWES' ||
          resolvedType == 'OTHER_SHOP_OWES' ||
          resolvedType == 'OWED';
      if (isShopOwes) {
        previousExpenseOut += amount;
      } else {
        // Thu nợ KH = tiền vào thuần — doanh thu kỳ trước đã ghi nhận đủ từ
        // ngày bán/ngày giao (accrual), không cộng lại (xem kỳ hiện tại).
        previousExtraIn += amount;
      }
    }

    for (final e in previousExpenses) {
      final amount = _toInt(e['amount']);
      final type = (e['type'] ?? 'CHI').toString().toUpperCase();
      if (type == 'THU') {
        previousExtraIn += amount;
      } else {
        previousExpenseOut += amount;
      }
    }

    final previousExpenseFirestoreIds = <String>{
      ...previousExpenses
          .map((e) => (e['firestoreId'] ?? '').toString().trim())
          .where((id) => id.isNotEmpty),
    };
    for (final p in previousRepairPartnerPayments) {
      final paymentFid = (p['firestoreId'] ?? '').toString().trim();
      if (paymentFid.isEmpty) continue;
      final expectedExpenseFid = paymentFid.startsWith('rpp_')
          ? 'exp_partner_${paymentFid.substring(4)}'
          : 'exp_partner_$paymentFid';
      if (previousExpenseFirestoreIds.contains(expectedExpenseFid)) {
        continue;
      }
      final amount = _toInt(p['amount']);
      if (amount > 0) {
        previousExpenseOut += amount;
      }
    }

    int receivableTotal = 0;
    int payableTotal = 0;
    final receivables = <FinanceV2DebtItem>[];
    final payables = <FinanceV2DebtItem>[];

    for (final d in debts) {
      final total = _toInt(d['totalAmount']);
      final paid = _toInt(d['paidAmount']);
      final remaining = total - paid;
      if (remaining <= 0) continue;

      final debtType = (d['type'] ?? 'CUSTOMER_OWES').toString();
      final isPayable =
          debtType == 'SHOP_OWES' ||
          debtType == 'OTHER_SHOP_OWES' ||
          debtType == 'OWED' ||
          debtType == 'REPAIR_PARTNER';

      final item = FinanceV2DebtItem(
        id: (d['firestoreId'] ?? d['id'] ?? debtType).toString(),
        type: debtType,
        name: (d['personName'] ?? d['partnerName'] ?? 'Không rõ').toString(),
        total: total,
        paid: paid,
        remaining: remaining,
        avatarUrl: isPayable
            ? (supplierAvatarByName[_normalizeName(
                    (d['personName'] ?? d['partnerName']).toString(),
                  )] ??
                  partnerAvatarByName[_normalizeName(
                    (d['personName'] ?? d['partnerName']).toString(),
                  )])
            : customerAvatarByName[_normalizeName(
                (d['personName'] ?? d['partnerName']).toString(),
              )],
        createdAt: _toInt(d['createdAt']),
        note: (d['note'] ?? '').toString().trim().isEmpty
            ? null
            : (d['note'] ?? '').toString().trim(),
        phone: isPayable
            ? (supplierPhoneByName[_normalizeName(
                    (d['personName'] ?? d['partnerName']).toString(),
                  )] ??
                  partnerPhoneByName[_normalizeName(
                    (d['personName'] ?? d['partnerName']).toString(),
                  )])
            : customerPhoneByName[_normalizeName(
                (d['personName'] ?? d['partnerName']).toString(),
              )],
      );

      if (isPayable) {
        payableTotal += remaining;
        payables.add(item);
      } else {
        receivableTotal += remaining;
        receivables.add(item);
      }
    }

    // Trả hàng (sales_returns) — chỉ phương thức tiền mặt/CK mới ảnh hưởng dòng tiền.
    // [2026-09-20 BUG-09] Dòng tiền trình bày GROSS như Sổ quỹ: tiền bán vẫn
    // là "Tiền vào", tiền hoàn là "Tiền ra" (refundOut). Lãi vẫn tính NET
    // (doanh thu − hoàn, vốn − vốn thu hồi). Trước đây trừ thẳng vào saleIn
    // ⇒ tab Tiền "vào 1,6 / ra 0" trong khi Sổ quỹ "thu 1,72 / chi 0,12".
    int refundOut = 0;
    int refundRevenue = 0;
    int refundCost = 0;
    for (final ret in salesReturns) {
      final method = (ret['refundMethod'] as String? ?? 'TIỀN MẶT')
          .toString()
          .trim()
          .toUpperCase();
      final amount = _toInt(ret['totalReturnAmount']);
      if (amount <= 0) continue;
      final cost = _toInt(ret['totalReturnCost']);

      // ACCRUAL: trả hàng HUỶ doanh thu + thu hồi giá vốn của lần bán, với
      // MỌI hình thức hoàn (gồm cả CÔNG NỢ). Bỏ qua hoàn CÔNG NỢ thì lãi gộp
      // bị dương giả (doanh thu vẫn đứng, vốn không thu hồi).
      refundRevenue += amount;
      refundCost += cost;

      // Sổ giao dịch = TIỀN: hoàn CÔNG NỢ chỉ giảm nợ, không có tiền ra nên
      // không xuất hiện ở đây (tab Giao dịch / biểu đồ theo ngày).
      if (method == 'CÔNG NỢ') continue;
      // [2026-09-20 BUG-09] Dòng tiền trình bày GROSS như Sổ quỹ: tiền bán vẫn
      // là "Tiền vào", tiền hoàn là "Tiền ra" (refundOut).
      refundOut += amount;

      // Hiện trả hàng trong tab Giao dịch để dễ audit (isIncome=false → Chi).
      final retCustomer =
          (ret['customerName'] as String? ?? '').trim();
      transactions.add(
        FinanceV2Txn(
          id: 'ret_${ret['firestoreId'] as String? ?? ret['id']}',
          createdAt: _toInt(ret['returnDate']),
          type: 'REFUND',
          title: retCustomer.isNotEmpty ? retCustomer : 'Khách lẻ',
          subtitle: 'Hoàn tiền trả hàng',
          amount: amount,
          isIncome: false,
          paymentMethod: method,
          customerName: retCustomer.isNotEmpty ? retCustomer : null,
          referenceId: ret['salesOrderFirestoreId'] as String?,
          costAmount: cost,
        ),
      );
    }

    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final totalIn = saleIn + repairIn + extraIn;
    final totalOut = expenseOut + refundOut;
    // ── ACCRUAL — Kết quả kinh doanh (tab Lãi): doanh thu / giá vốn NET sau
    // hoàn trả, ghi nhận theo ngày bán / ngày giao cho mọi hình thức thanh
    // toán. ──
    final saleRevenueNet =
        (saleAccrualRevenue - refundRevenue).clamp(0, saleAccrualRevenue);
    final saleCogsNet = (saleAccrualCogs - refundCost).clamp(0, saleAccrualCogs);
    // ── CASH — tiền THỰC thu trong kỳ: giữ đúng con số cũ của
    // incomeFromSales / incomeFromRepairs cho bảng cơ cấu tiền thu vào. ──
    final cashFromSales = (saleIn - refundOut).clamp(0, saleIn);
    final cashFromRepairs = repairIn;
    final operatingExpenseOut =
        expenseOut -
        debtRepayOut -
        importExpenseOut -
        partnerPaymentOut -
        repairCostMirrorOut; // chi vận hành thuần, loại trả nợ NCC, nhập hàng, TT đối tác, vốn SC đã nằm trong COGS
    final netCashflow = totalIn - totalOut;
    // Lãi gộp bán hàng theo ACCRUAL — nhất quán với incomeFromSales
    final grossProfitFromSales = saleRevenueNet - saleCogsNet;
    // Lãi gộp sửa chữa theo ACCRUAL — nhất quán với incomeFromRepairs
    final grossProfitFromRepairs =
        repairAccrualRevenue - repairAccrualCogs;
    final grossProfitTotal = grossProfitFromSales + grossProfitFromRepairs;
    final previousCashFromSales = previousSaleIn;
    final previousCashFromRepairs = previousRepairIn;
    final previousTotalIn = previousSaleIn + previousRepairIn + previousExtraIn;
    final previousTotalOut = previousExpenseOut;
    final previousNetCashflow = previousTotalIn - previousTotalOut;
    final previousGrossProfitFromSales =
        previousSaleAccrualRevenue - previousSaleAccrualCogs;
    // Lãi gộp sửa chữa kỳ trước theo ACCRUAL
    final previousGrossProfitFromRepairs =
        previousRepairAccrualRevenue - previousRepairAccrualCogs;
    final incomeTxCount = transactions.where((t) => t.isIncome).length;
    final avgIncomePerTransaction = incomeTxCount > 0
        ? (totalIn ~/ incomeTxCount)
        : 0;

    final Map<String, int> expenseByCategory = {};
    for (final e in expenses) {
      final type = (e['type'] ?? 'CHI').toString().toUpperCase();
      if (type == 'THU') continue;
      if (_isImportExpense(e)) continue;
      final category = (e['category'] ?? 'Khác').toString().trim();
      final amount = _toInt(e['amount']);
      final key = category.isEmpty ? 'Khác' : category;
      expenseByCategory[key] = (expenseByCategory[key] ?? 0) + amount;
    }
    int partnerPaymentsForCategory = 0;
    for (final p in repairPartnerPayments) {
      final paymentFid = (p['firestoreId'] ?? '').toString().trim();
      if (paymentFid.isEmpty) continue;
      final expectedExpenseFid = paymentFid.startsWith('rpp_')
          ? 'exp_partner_${paymentFid.substring(4)}'
          : 'exp_partner_$paymentFid';
      if (expenseFirestoreIds.contains(expectedExpenseFid)) {
        continue;
      }
      final amount = _toInt(p['amount']);
      if (amount <= 0) continue;
      partnerPaymentsForCategory += amount;
      expenseByCategory['Đối tác sửa chữa'] =
          (expenseByCategory['Đối tác sửa chữa'] ?? 0) + amount;
    }
    // Linh kiện sửa chữa = vốn SC (cash) − chi phí đối tác được ghi riêng
    // Dùng repairCogs thay vì repair.services vì services thường không được load đầy đủ từ local DB
    final linhKienCost = repairCogs - partnerPaymentsForCategory;
    if (linhKienCost > 0) {
      expenseByCategory['Linh kiện sửa chữa'] = linhKienCost;
    }
    final topExpenseCategories =
        expenseByCategory.entries
            .map((e) => FinanceV2CategoryStat(label: e.key, amount: e.value))
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    final cards = <FinanceV2MetricCard>[
      FinanceV2MetricCard(
        label: 'Tiền vào',
        amount: totalIn,
        previousAmount: previousTotalIn,
      ),
      FinanceV2MetricCard(
        label: 'Tiền ra',
        amount: totalOut,
        previousAmount: previousTotalOut,
      ),
      FinanceV2MetricCard(label: 'Phải thu', amount: receivableTotal),
      FinanceV2MetricCard(label: 'Phải trả', amount: payableTotal),
      FinanceV2MetricCard(
        label: 'Dòng tiền ròng',
        amount: netCashflow,
        previousAmount: previousNetCashflow,
      ),
    ];

    final byDay = _buildBuckets(transactions, 'day');
    final byMonth = _buildBuckets(transactions, 'month');
    final byYear = _buildBuckets(transactions, 'year');

    // Calculate debt aging (khách nợ / phải thu only)
    final debtAging = <String, int>{'0-30': 0, '30-60': 0, '>60': 0};
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final d in debts) {
      final total = _toInt(d['totalAmount']);
      final paid = _toInt(d['paidAmount']);
      final remaining = total - paid;
      if (remaining <= 0) continue;

      final debtType = (d['type'] ?? 'CUSTOMER_OWES').toString();
      // Only count receivables (khách nợ), not payables
      if (debtType != 'CUSTOMER_OWES' && debtType != 'CUSTOMER_DEPOSIT')
        continue;

      final createdAt = _toInt(d['createdAt']);
      final daysSinceCreation = ((nowMs - createdAt) / (1000 * 60 * 60 * 24))
          .floor();

      if (daysSinceCreation <= 30) {
        debtAging['0-30'] = (debtAging['0-30'] ?? 0) + remaining;
      } else if (daysSinceCreation <= 60) {
        debtAging['30-60'] = (debtAging['30-60'] ?? 0) + remaining;
      } else {
        debtAging['>60'] = (debtAging['>60'] ?? 0) + remaining;
      }
    }

    final snapshot = FinanceV2Snapshot(
      totalIn: totalIn,
      totalOut: totalOut,
      operatingExpenseOut: operatingExpenseOut,
      debtRepayOut: debtRepayOut,
      partnerPaymentOut: partnerPaymentOut,
      importExpenseOut: importExpenseOut,
      receivableTotal: receivableTotal,
      payableTotal: payableTotal,
      netCashflow: netCashflow,
      incomeFromSales: saleRevenueNet,
      incomeFromRepairs: repairAccrualRevenue,
      cashFromSales: cashFromSales,
      cashFromRepairs: cashFromRepairs,
      debtCollectIn: debtCollectIn,
      cogsFromSales: saleCogsNet,
      cogsFromRepairs: repairAccrualCogs,
      grossProfitFromSales: grossProfitFromSales,
      grossProfitFromRepairs: grossProfitFromRepairs,
      grossProfitTotal: grossProfitTotal,
      incomeOther: extraIn - debtCollectIn,
      transactionCount: transactions.length,
      avgIncomePerTransaction: avgIncomePerTransaction,
      previousTotalIn: previousTotalIn,
      previousTotalOut: previousTotalOut,
      previousNetCashflow: previousNetCashflow,
      previousCashFromSales: previousCashFromSales,
      previousCashFromRepairs: previousCashFromRepairs,
      previousCogsFromSales: previousSaleAccrualCogs,
      previousCogsFromRepairs: previousRepairAccrualCogs,
      previousGrossProfitFromSales: previousGrossProfitFromSales,
      previousGrossProfitFromRepairs: previousGrossProfitFromRepairs,
      dashboardCards: cards,
      topExpenseCategories: topExpenseCategories.toList(),
      transactions: transactions,
      receivables: receivables,
      payables: payables,
      byDay: byDay,
      byMonth: byMonth,
      byYear: byYear,
      auditLogs: activities,
      debtAging: debtAging,
    );
    FinanceV2Cache.put(cacheKey, snapshot);
    return snapshot;
  }

  List<FinanceV2PeriodBucket> _buildBuckets(
    List<FinanceV2Txn> txns,
    String mode,
  ) {
    final bucketMap = <String, _BucketAcc>{};
    for (final tx in txns) {
      final dt = DateTime.fromMillisecondsSinceEpoch(tx.createdAt);
      late final String key;
      late final String label;
      if (mode == 'year') {
        key = '${dt.year}';
        label = '${dt.year}';
      } else if (mode == 'month') {
        final m = dt.month.toString().padLeft(2, '0');
        key = '${dt.year}-$m';
        label = '$m/${dt.year}';
      } else {
        final m = dt.month.toString().padLeft(2, '0');
        final d = dt.day.toString().padLeft(2, '0');
        key = '${dt.year}-$m-$d';
        label = '$d/$m';
      }
      final acc = bucketMap.putIfAbsent(key, () => _BucketAcc(label: label));
      if (tx.isIncome) {
        acc.totalIn += tx.amount;
      } else {
        acc.totalOut += tx.amount;
      }
      acc.txCount += 1;
    }

    final keys = bucketMap.keys.toList()..sort();
    return keys.map((k) {
      final acc = bucketMap[k]!;
      return FinanceV2PeriodBucket(
        key: k,
        label: acc.label,
        totalIn: acc.totalIn,
        totalOut: acc.totalOut,
        txCount: acc.txCount,
      );
    }).toList();
  }

  String _normalizeName(dynamic input) {
    final text = (input ?? '').toString().trim().toUpperCase();
    if (text.isEmpty) return '';
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// Doanh thu/vốn ghi nhận từ MỘT phiếu thu nợ của đơn bán / đơn sửa CÔNG NỢ.
class _LinkedRevenue {
  final bool isSale;
  final int cost;
  final String itemName;
  const _LinkedRevenue({
    required this.isSale,
    required this.cost,
    required this.itemName,
  });
}

/// Tra đơn bán / đơn sửa CÔNG NỢ mà một phiếu thu nợ gắn vào
/// (`debts.linkedId` = `sale_…` / `rep_…`).
///
/// [2026-09-24] CHỈ dùng để hiển thị tên đơn trong dòng giao dịch — KHÔNG còn
/// cộng doanh thu / giá vốn: tab Lãi đã tính ACCRUAL, ghi nhận đủ từ ngày bán
/// / ngày giao, nên thu nợ thuần là TIỀN VÀO ("Thu nợ KH"). Giữ tên + dạng hàm
/// cũ để không phải đổi chỗ gọi. Không gắn được đơn thì trả null như cũ.
_LinkedRevenue? _linkedRevenueOf(
  Map<String, dynamic> payment,
  int amount,
  Map<String, SaleOrder> sales,
  Map<String, Repair> repairs,
) {
  final linked = (payment['linkedDebtLinkedId'] ?? '').toString().trim();
  if (linked.isEmpty || amount <= 0) return null;
  final sale = sales[linked];
  if (sale != null) {
    if (sale.paymentMethod.toUpperCase() != 'CÔNG NỢ') return null;
    final price = sale.finalPrice > 0 ? sale.finalPrice : sale.totalPrice;
    final cost = (sale.totalCost > 0 && price > 0)
        ? ((sale.totalCost * amount) / price).round()
        : 0;
    return _LinkedRevenue(
      isSale: true,
      cost: cost < 0 ? 0 : cost,
      itemName: sale.productNames,
    );
  }
  final repair = repairs[linked];
  if (repair != null) {
    // [NEW-02] Nợ chênh lệch sửa giá sau giao (linkedType REPAIR_PRICE_ADJUST)
    // là doanh thu sửa chữa dù đơn gốc thu TIỀN MẶT; vốn vẫn theo tỉ lệ.
    final isPriceAdjust =
        (payment['linkedDebtLinkedType'] ?? '').toString() ==
        'REPAIR_PRICE_ADJUST';
    if (!isPriceAdjust && repair.paymentMethod.toUpperCase() != 'CÔNG NỢ') {
      return null;
    }
    final price = repair.price;
    final cost = (repair.totalCost > 0 && price > 0)
        ? ((repair.totalCost * amount) / price).round()
        : 0;
    return _LinkedRevenue(
      isSale: false,
      cost: cost < 0 ? 0 : cost,
      itemName: repair.model,
    );
  }
  return null;
}

class _BucketAcc {
  final String label;
  int totalIn = 0;
  int totalOut = 0;
  int txCount = 0;

  _BucketAcc({required this.label});
}
