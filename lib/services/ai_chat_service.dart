import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../utils/vietnamese_utils.dart';
import 'ai_knowledge_service.dart';
import 'repair_vocabulary_service.dart';

// ── AI Action ──────────────────────────────────────────────────────────────────

enum AiActionType {
  openLatestRepair,
  openLatestSale,
  viewDebts,
  viewDebtPayable,
  viewStock,
  openSalesTab,
  openRepairsTab,
  createRepairFromChat,
  createSaleFromChat,
  createStockFromChat,
}

class AiAction {
  final String label;
  final IconData icon;
  final AiActionType type;
  final String? payload;
  const AiAction({required this.label, required this.icon, required this.type, this.payload});
}

// ── Quick response ──────────────────────────────────────────────────────────────

class AiQuickResponse {
  final String text;
  final List<AiAction> actions;
  final List<(String, IconData)> followUpChips;
  const AiQuickResponse(this.text, {this.actions = const [], this.followUpChips = const []});
}

// ── Intent clarification ────────────────────────────────────────────────────────

class AiIntentSuggestion {
  final String label;
  final String query; // query sent to _send() when tapped
  final IconData icon;
  const AiIntentSuggestion({required this.label, required this.query, required this.icon});
}

class AiClarifyResponse {
  final String prompt;
  final List<AiIntentSuggestion> suggestions;
  const AiClarifyResponse(this.prompt, {required this.suggestions});
}

// ── Stats snapshot ─────────────────────────────────────────────────────────────

class AiChatStats {
  // Today — totals (sales + delivered repairs)
  final int salesToday;           // số đơn bán hàng
  final int revenueToday;         // tổng doanh thu (bán + sửa giao)
  final int profitToday;          // tổng lợi nhuận

  // Today — breakdown
  final int saleRevenueToday;     // doanh thu bán hàng
  final int repairRevenueToday;   // doanh thu sửa chữa (đã giao)
  final int deliveredRepairsToday; // số đơn sửa đã giao hôm nay

  // Repairs all statuses today (for count + pending list)
  final int repairsToday;

  /// Đơn sửa chưa giao (status < 4) trên TOÀN BỘ lịch sử — không chỉ đơn tạo
  /// hôm nay. Trước đây chỉ đếm trong ngày nên bỏ sót đơn tồn của hôm trước.
  final int repairsPending;

  /// Trong [repairsPending], số đơn đã tồn từ hôm trước trở về trước.
  final int repairsOverdue;

  /// Trong [repairsPending]: còn phải làm (status 1–2). Cùng định nghĩa với thẻ
  /// "CẦN XỬ LÝ" ở Trang chủ để hai nơi không đá nhau.
  final int repairsInProgress;

  /// Trong [repairsPending]: đã sửa xong, chờ khách đến lấy (status 3).
  final int repairsAwaitingPickup;

  // Stock
  final int stockCount;
  final int stockQuantity;
  final int stockCapital;
  final int phoneStockCount;
  final int phoneStockQuantity;
  final int phoneStockCapital;
  final int accessoryStockCount;
  final int accessoryStockQuantity;
  final int accessoryStockCapital;
  final int partStockCount;
  final int partStockQuantity;
  final int partStockCapital;

  // Debts
  final int debtReceivable;
  final int debtPayable;

  // Monthly totals
  final int salesThisMonth;
  final int saleRevenueThisMonth;
  final int repairRevenueThisMonth;
  final int revenueThisMonth;     // tổng tháng
  final int profitThisMonth;
  final int repairsThisMonth;

  // Yearly totals
  final int salesThisYear;
  final int saleRevenueThisYear;
  final int repairRevenueThisYear;
  final int revenueThisYear;
  final int profitThisYear;
  final int repairsThisYear;

  // Detail lists
  final List<String> repairSummaries;

  /// Tóm tắt các đơn CHƯA GIAO (mọi ngày), dùng cho câu "đơn đang chờ".
  final List<String> pendingRepairSummaries;

  final List<String> topDebtorLines;

  /// Tra cứu nợ phải thu theo tên khách (tên gốc → số còn nợ). Chỉ dùng cục bộ
  /// cho quick-answer "khách X nợ bao nhiêu" — KHÔNG gửi lên cloud.
  final Map<String, int> debtorLookup;

  const AiChatStats({
    this.salesToday = 0,
    this.revenueToday = 0,
    this.profitToday = 0,
    this.saleRevenueToday = 0,
    this.repairRevenueToday = 0,
    this.deliveredRepairsToday = 0,
    this.repairsToday = 0,
    this.repairsPending = 0,
    this.repairsOverdue = 0,
    this.repairsInProgress = 0,
    this.repairsAwaitingPickup = 0,
    this.stockCount = 0,
    this.stockQuantity = 0,
    this.stockCapital = 0,
    this.phoneStockCount = 0,
    this.phoneStockQuantity = 0,
    this.phoneStockCapital = 0,
    this.accessoryStockCount = 0,
    this.accessoryStockQuantity = 0,
    this.accessoryStockCapital = 0,
    this.partStockCount = 0,
    this.partStockQuantity = 0,
    this.partStockCapital = 0,
    this.debtReceivable = 0,
    this.debtPayable = 0,
    this.salesThisMonth = 0,
    this.saleRevenueThisMonth = 0,
    this.repairRevenueThisMonth = 0,
    this.revenueThisMonth = 0,
    this.profitThisMonth = 0,
    this.repairsThisMonth = 0,
    this.salesThisYear = 0,
    this.saleRevenueThisYear = 0,
    this.repairRevenueThisYear = 0,
    this.revenueThisYear = 0,
    this.profitThisYear = 0,
    this.repairsThisYear = 0,
    this.repairSummaries = const [],
    this.pendingRepairSummaries = const [],
    this.topDebtorLines = const [],
    this.debtorLookup = const {},
  });

  Map<String, dynamic> toJson() => {
        'salesToday': salesToday,
        'revenueToday': revenueToday,
        'profitToday': profitToday,
        'saleRevenueToday': saleRevenueToday,
        'repairRevenueToday': repairRevenueToday,
        'deliveredRepairsToday': deliveredRepairsToday,
        'repairsToday': repairsToday,
        'repairsPending': repairsPending,
        'repairsOverdue': repairsOverdue,
        'repairsInProgress': repairsInProgress,
        'repairsAwaitingPickup': repairsAwaitingPickup,
        'stockCount': stockCount,
        'stockQuantity': stockQuantity,
        'stockCapital': stockCapital,
        'phoneStockCount': phoneStockCount,
        'phoneStockQuantity': phoneStockQuantity,
        'phoneStockCapital': phoneStockCapital,
        'accessoryStockCount': accessoryStockCount,
        'accessoryStockQuantity': accessoryStockQuantity,
        'accessoryStockCapital': accessoryStockCapital,
        'partStockCount': partStockCount,
        'partStockQuantity': partStockQuantity,
        'partStockCapital': partStockCapital,
        'debtReceivable': debtReceivable,
        'debtPayable': debtPayable,
        'salesThisMonth': salesThisMonth,
        'saleRevenueThisMonth': saleRevenueThisMonth,
        'repairRevenueThisMonth': repairRevenueThisMonth,
        'revenueThisMonth': revenueThisMonth,
        'profitThisMonth': profitThisMonth,
        'repairsThisMonth': repairsThisMonth,
        'salesThisYear': salesThisYear,
        'saleRevenueThisYear': saleRevenueThisYear,
        'repairRevenueThisYear': repairRevenueThisYear,
        'revenueThisYear': revenueThisYear,
        'profitThisYear': profitThisYear,
        'repairsThisYear': repairsThisYear,
        'repairSummaries': repairSummaries,
        'topDebtorLines': topDebtorLines,
      };
}

// ── Service ────────────────────────────────────────────────────────────────────

/// AI assistant service.
///
/// Fast path: answers simple stat queries locally (no network).
/// Cloud path: calls `chatAssistant` Firebase Cloud Function (DeepSeek API,
///   key stored exclusively in Google Secret Manager — never in the app).
class AiChatService {
  AiChatService._();
  static final AiChatService instance = AiChatService._();

  static const _region = 'asia-southeast1';

  FirebaseFunctions get _fn =>
      FirebaseFunctions.instanceFor(region: _region);

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<AiChatStats> getTodayStats() async {
    final db = DBHelper();
    final now = DateTime.now();

    final dayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final dayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;

    final monthStart = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final monthEnd = DateTime(now.year, now.month + 1, 1)
        .subtract(const Duration(seconds: 1))
        .millisecondsSinceEpoch;

    final yearStart = DateTime(now.year, 1, 1).millisecondsSinceEpoch;
    final yearEnd = DateTime(now.year + 1, 1, 1)
        .subtract(const Duration(seconds: 1))
        .millisecondsSinceEpoch;

    final results = await Future.wait([
      db.getSalesByDateRange(dayStart, dayEnd),                    // [0] sales hôm nay
      db.getRepairsByCreatedAtRange(dayStart, dayEnd),             // [1] tất cả đơn sửa hôm nay
      db.getInventoryBreakdownSummary(),                           // [2] tồn kho breakdown
      db.getDebtsForFinanceSnapshot(),                             // [3] công nợ
      db.getSalesByDateRange(monthStart, monthEnd),                 // [4] sales tháng
      db.getRepairsByCreatedAtRange(monthStart, monthEnd),         // [5] đơn sửa tháng
      db.getDeliveredRepairsByDateRange(dayStart, dayEnd),         // [6] đã giao hôm nay
      db.getDeliveredRepairsByDateRange(monthStart, monthEnd),     // [7] đã giao tháng
      db.getSalesByDateRange(yearStart, yearEnd),                   // [8] sales năm
      db.getRepairsByCreatedAtRange(yearStart, yearEnd),           // [9] đơn sửa năm
      db.getDeliveredRepairsByDateRange(yearStart, yearEnd),       // [10] đã giao năm
      db.getPendingRepairCounts(dayStart),                          // [11] đơn chưa giao (mọi ngày)
      db.getPendingRepairs(),                                       // [12] vài đơn chưa giao gần nhất
    ]);

    final sales = results[0] as List;
    final repairs = results[1] as List;
    final inventory = results[2] as Map<String, int>;
    final debts = results[3] as List<Map<String, dynamic>>;
    final salesMonth = results[4] as List;
    final repairsMonth = results[5] as List;
    final deliveredRepairs = results[6] as List;
    final deliveredRepairsMonth = results[7] as List;
    final salesYear = results[8] as List;
    final repairsYear = results[9] as List;
    final deliveredRepairsYear = results[10] as List;
    final pendingCounts = results[11] as Map<String, int>;
    final pendingRepairs = results[12] as List;

    // ── Doanh thu bán hàng ──
    int saleRevenue = 0, saleProfit = 0;
    for (final s in sales) {
      final fp = (s.finalPrice as num?)?.toInt() ?? 0;
      final tc = (s.totalCost as num?)?.toInt() ?? 0;
      saleRevenue += fp;
      saleProfit += fp - tc;
    }

    // ── Doanh thu sửa chữa (chỉ đơn đã giao) ──
    int repairRevenue = 0, repairProfit = 0;
    for (final r in deliveredRepairs) {
      final price = (r.price as num?)?.toInt() ?? 0;
      final cost = (r.totalCost as num?)?.toInt() ?? 0;
      repairRevenue += price;
      repairProfit += price - cost;
    }

    // ── Monthly sales ──
    int saleRevenueMonth = 0, profitMonth = 0;
    for (final s in salesMonth) {
      final fp = (s.finalPrice as num?)?.toInt() ?? 0;
      final tc = (s.totalCost as num?)?.toInt() ?? 0;
      saleRevenueMonth += fp;
      profitMonth += fp - tc;
    }

    // ── Monthly repair revenue ──
    int repairRevenueMonth = 0, repairProfitMonth = 0;
    for (final r in deliveredRepairsMonth) {
      final price = (r.price as num?)?.toInt() ?? 0;
      final cost = (r.totalCost as num?)?.toInt() ?? 0;
      repairRevenueMonth += price;
      repairProfitMonth += price - cost;
    }

    // ── Yearly sales ──
    int saleRevenueYear = 0, saleProfitYear = 0;
    for (final s in salesYear) {
      final fp = (s.finalPrice as num?)?.toInt() ?? 0;
      final tc = (s.totalCost as num?)?.toInt() ?? 0;
      saleRevenueYear += fp;
      saleProfitYear += fp - tc;
    }

    // ── Yearly repair revenue ──
    int repairRevenueYear = 0, repairProfitYear = 0;
    for (final r in deliveredRepairsYear) {
      final price = (r.price as num?)?.toInt() ?? 0;
      final cost = (r.totalCost as num?)?.toInt() ?? 0;
      repairRevenueYear += price;
      repairProfitYear += price - cost;
    }

    // ── Đơn sửa: list hôm nay (mọi trạng thái) + list chưa giao (mọi ngày) ──
    const statusLabel = {1: 'Mới nhận', 2: 'Đang sửa', 3: 'Xong chờ lấy', 4: 'Đã giao'};
    String summarize(dynamic r, {int? ageDays}) {
      final status = (r.status as num?)?.toInt() ?? 0;
      final model = (r.model as String?)?.trim() ?? '';
      final issue = (r.issue as String?)?.trim() ?? '';
      final name = (r.customerName as String?)?.trim() ?? '';
      final price = (r.price as num?)?.toInt() ?? 0;
      final statusStr = statusLabel[status] ?? 'Không rõ';
      return [
        if (model.isNotEmpty) model,
        if (issue.isNotEmpty) issue else 'chưa ghi lỗi',
        if (name.isNotEmpty) name,
        if (price > 0) fmt(price),
        '($statusStr${ageDays != null && ageDays > 0 ? ', tồn $ageDays ngày' : ''})',
      ].join(' - ');
    }

    final repairSummaries = [for (final r in repairs) summarize(r)];

    // Đơn chưa giao lấy từ truy vấn riêng — KHÔNG lọc theo ngày tạo, nên đơn
    // tồn của những hôm trước vẫn được đếm và liệt kê.
    final pending = pendingCounts['total'] ?? 0;
    final pendingOverdue = pendingCounts['overdue'] ?? 0;
    final pendingRepairSummaries = <String>[];
    for (final r in pendingRepairs) {
      final createdAt = (r.createdAt as num?)?.toInt() ?? 0;
      int ageDays = 0;
      if (createdAt > 0) {
        final c = DateTime.fromMillisecondsSinceEpoch(createdAt);
        ageDays = DateTime(now.year, now.month, now.day)
            .difference(DateTime(c.year, c.month, c.day))
            .inDays;
      }
      pendingRepairSummaries.add(summarize(r, ageDays: ageDays));
    }

    // ── Công nợ — same classification as Finance V2 ──
    // Payable types: SHOP_OWES, OTHER_SHOP_OWES, OWED, REPAIR_PARTNER
    // Everything else (CUSTOMER_OWES, etc.) = receivable
    int debtReceivable = 0, debtPayable = 0;
    final debtorMap = <String, int>{};
    const payableTypes = {'SHOP_OWES', 'OTHER_SHOP_OWES', 'OWED', 'REPAIR_PARTNER'};
    for (final d in debts) {
      final total = d['totalAmount'] as int? ?? 0;
      final paid = d['paidAmount'] as int? ?? 0;
      final remaining = total - paid;
      if (remaining <= 0) continue;
      final type = (d['type'] as String? ?? 'CUSTOMER_OWES').toString();
      final isPayable = payableTypes.contains(type);
      if (isPayable) {
        debtPayable += remaining;
      } else {
        debtReceivable += remaining;
        final name = (d['personName'] as String?)?.trim() ?? 'Không rõ';
        debtorMap[name] = (debtorMap[name] ?? 0) + remaining;
      }
    }

    final sortedDebtors = debtorMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topDebtorLines = sortedDebtors
        .take(5)
        .map((e) => '${e.key}: **${fmt(e.value)}**')
        .toList();

    return AiChatStats(
      salesToday: sales.length,
      revenueToday: saleRevenue + repairRevenue,
      profitToday: saleProfit + repairProfit,
      saleRevenueToday: saleRevenue,
      repairRevenueToday: repairRevenue,
      deliveredRepairsToday: deliveredRepairs.length,
      repairsToday: repairs.length,
      repairsPending: pending,
      repairsOverdue: pendingOverdue,
      repairsInProgress: pendingCounts['inProgress'] ?? 0,
      repairsAwaitingPickup: pendingCounts['awaitingPickup'] ?? 0,
      pendingRepairSummaries: pendingRepairSummaries,
      stockCount: inventory['totalItems'] ?? 0,
      stockQuantity: inventory['totalQty'] ?? 0,
      stockCapital: inventory['totalCapital'] ?? 0,
      phoneStockCount: inventory['phoneItems'] ?? 0,
      phoneStockQuantity: inventory['phoneQty'] ?? 0,
      phoneStockCapital: inventory['phoneCapital'] ?? 0,
      accessoryStockCount: inventory['accessoryItems'] ?? 0,
      accessoryStockQuantity: inventory['accessoryQty'] ?? 0,
      accessoryStockCapital: inventory['accessoryCapital'] ?? 0,
      partStockCount: inventory['partItems'] ?? 0,
      partStockQuantity: inventory['partQty'] ?? 0,
      partStockCapital: inventory['partCapital'] ?? 0,
      debtReceivable: debtReceivable,
      debtPayable: debtPayable,
      salesThisMonth: salesMonth.length,
      saleRevenueThisMonth: saleRevenueMonth,
      repairRevenueThisMonth: repairRevenueMonth,
      revenueThisMonth: saleRevenueMonth + repairRevenueMonth,
      profitThisMonth: profitMonth + repairProfitMonth,
      repairsThisMonth: repairsMonth.length,
      salesThisYear: salesYear.length,
      saleRevenueThisYear: saleRevenueYear,
      repairRevenueThisYear: repairRevenueYear,
      revenueThisYear: saleRevenueYear + repairRevenueYear,
      profitThisYear: saleProfitYear + repairProfitYear,
      repairsThisYear: repairsYear.length,
      repairSummaries: repairSummaries.take(20).toList(),
      topDebtorLines: topDebtorLines,
      debtorLookup: debtorMap,
    );
  }

  // ── Fast local answers ────────────────────────────────────────────────────

  static const _kViewDebtsAction = AiAction(
    label: 'Xem công nợ',
    icon: Icons.account_balance_wallet_outlined,
    type: AiActionType.viewDebts,
  );
  static const _kViewStockAction = AiAction(
    label: 'Xem kho',
    icon: Icons.inventory_2_outlined,
    type: AiActionType.viewStock,
  );
  static const _kOpenLatestRepairAction = AiAction(
    label: 'Mở đơn gần nhất',
    icon: Icons.build_circle_outlined,
    type: AiActionType.openLatestRepair,
  );
  static const _kOpenLatestSaleAction = AiAction(
    label: 'Mở hóa đơn bán',
    icon: Icons.receipt_long_outlined,
    type: AiActionType.openLatestSale,
  );
  static const _kViewDebtPayableAction = AiAction(
    label: 'Xem nợ NCC',
    icon: Icons.store_outlined,
    type: AiActionType.viewDebtPayable,
  );
  static const _kOpenSalesTabAction = AiAction(
    label: 'Mở tab Bán hàng',
    icon: Icons.point_of_sale_outlined,
    type: AiActionType.openSalesTab,
  );
  static const _kOpenRepairsTabAction = AiAction(
    label: 'Mở tab Sửa chữa',
    icon: Icons.build_outlined,
    type: AiActionType.openRepairsTab,
  );

  // Expand common synonyms before intent matching so short / variant phrasing works.
  static String _expandSynonyms(String normalized) {
    const synonyms = <String, String>{
      // ── Viết tắt phổ biến ──────────────────────────────────────────────────
      ' dt ': ' doanh thu ',
      ' ln ': ' loi nhuan ',
      ' bh ': ' ban hang ',
      ' ds ': ' don sua ',
      ' db ': ' don ban ',
      ' kh ': ' khach hang ',
      ' ncc ': ' nha cung cap ',
      // ── Tiếng Anh ──────────────────────────────────────────────────────────
      'bill': 'hoa don ban',
      'invoice': 'hoa don ban',
      'receipt': 'hoa don ban',
      'inventory': 'ton kho',
      'stock': 'ton kho',
      'revenue': 'doanh thu',
      'profit': 'loi nhuan',
      'supplier': 'nha cung cap',
      'customer': 'khach hang',
      'order': 'don',
      'repair': 'sua chua',
      'sale': 'ban hang',
      'debt': 'cong no',
      'report': 'bao cao',
      'summary': 'tom tat',
      'pending': 'dang cho',
      'today': 'hom nay',
      'week': 'tuan nay',
      'month': 'thang nay',
      'year': 'nam nay',
      // ── Gần nhất ───────────────────────────────────────────────────────────
      'moi nhat': 'gan nhat',
      'gan day': 'gan nhat',
      'vua roi': 'gan nhat',
      'cuoi cung': 'gan nhat',
      'vua xong': 'gan nhat',
      'vua tao': 'gan nhat',
      'moi tao': 'gan nhat',
      // ── Đơn bán nói tắt ────────────────────────────────────────────────────
      'ban gan': 'don ban gan nhat',
      'ban moi': 'don ban gan nhat',
      'hoa don': 'don ban gan nhat',
      'don vua ban': 'don ban gan nhat',
      'ban vua xong': 'don ban gan nhat',
      // ── Đơn sửa nói tắt ────────────────────────────────────────────────────
      'sua gan': 'don sua gan nhat',
      'sua moi': 'don sua gan nhat',
      'don vua sua': 'don sua gan nhat',
      'may vua sua': 'don sua gan nhat',
      // ── Nợ ────────────────────────────────────────────────────────────────
      'no ai': 'ai no nhieu nhat',
      'ai no': 'ai no nhieu nhat',
      'khach no': 'thu no khach',
      'no khach': 'thu no khach',
      'no ncc': 'tra no ncc',
      'nha cung cap': 'ncc',
      'owe': 'cong no',
      'phai thu': 'thu no khach',
      'phai tra': 'tra no ncc',
      // ── Linh kiện ─────────────────────────────────────────────────────────
      'linh phu': 'linh kien',
      'phu tung': 'linh kien',
      'spare part': 'linh kien',
      // ── Doanh thu / tài chính nói tắt ────────────────────────────────────
      'thu ve': 'doanh thu',
      'tien vao': 'doanh thu',
      'bao nhieu tien': 'doanh thu',
      'ket qua': 'tai chinh',
      'hom nay the nao': 'tai chinh',
      'hom nay sao': 'tai chinh',
      'ngay hom nay': 'hom nay',
      'buoi nay': 'hom nay',
      'sang nay': 'hom nay',
      'chieu nay': 'hom nay',
      'ngay nay': 'hom nay',
      'hien tai': 'hom nay',
      // ── Lợi nhuận ─────────────────────────────────────────────────────────
      'loi duoc': 'loi nhuan',
      'lai duoc': 'loi nhuan',
      'loi nhieu khong': 'loi nhuan',
      // ── Tạo đơn nói tắt ───────────────────────────────────────────────────
      'muon ban': 'tao don ban',
      'co khach mua': 'tao don ban',
      'khach mua': 'tao don ban',
      'ban may': 'tao don ban',
      'xuat may': 'tao don ban',
      'co khach sua': 'tao don sua',
      'khach mang may den': 'tao don sua',
      'nhan may': 'tao don sua',
      'may bi hong': 'tao don sua',
      'may bi loi': 'tao don sua',
      'may hong': 'tao don sua',
      'them don': 'tao don',
      // ── Kho ───────────────────────────────────────────────────────────────
      'con hang': 'ton kho',
      'hang con khong': 'ton kho',
      'het hang': 'ton kho',
      'con may cai': 'ton kho',
      // ── Thời gian ─────────────────────────────────────────────────────────
      'bay gio': 'hom nay',
      'luc nay': 'hom nay',
      'tuan nay': 'thang nay',   // fallback: tuần → tháng (stats chưa có weekly)
      'tuan nay roi': 'thang nay',
      't2': 'thu 2', 't3': 'thu 3', 't4': 'thu 4',
      't5': 'thu 5', 't6': 'thu 6', 't7': 'thu 7',
      // ── Phản hồi / tương tác ──────────────────────────────────────────────
      'ok ban': 'cam on',
      'ok roi': 'cam on',
      'duoc roi': 'cam on',
      'hieu roi': 'cam on',
    };
    String result = normalized;
    for (final e in synonyms.entries) {
      result = result.replaceAll(e.key, e.value);
    }
    return result;
  }

  bool _isFinanceQuery(String n) => _has(n, [
    'doanh thu', 'loi nhuan', 'tai chinh', 'cong no', 'chi phi',
    'no phai thu', 'no phai tra', 'thu chi', 'tong ket', 'bao cao',
    'thang nay', 'nam nay', 'tong hop',
    'on khong', 'tot khong', 'sao roi', 'ra sao', 'nhu the nao',
    'hom nay the nao', 'ket qua hom nay', 'tong ket hom nay', 'bao cao nhanh',
    'ban hang hom nay', 'don ban hom nay', 'sua chua hom nay', 'don sua hom nay',
  ]) || n.trim() == 'bao nhieu' || n.trim() == 'may';

  AiQuickResponse? quickAnswer(String question, AiChatStats stats, {
    String? lastIntent,
    bool canViewFinance = true,
  }) {
    final raw = VietnameseUtils.normalize(question.toLowerCase());
    final n = RepairVocabularyService.instance.preprocessQuery(_expandSynonyms(raw));

    if (!canViewFinance && _isFinanceQuery(n)) {
      return const AiQuickResponse(
        'Bạn không có quyền xem dữ liệu tài chính.\n'
        'Liên hệ quản lý để được cấp quyền xem doanh thu, lợi nhuận, công nợ.',
      );
    }

    // ── Câu hỏi cực ngắn / nói tắt ──────────────────────────────────────────

    // "bao nhiêu" / "mấy" / "được không" → tổng hợp nhanh hôm nay
    if (n.trim() == 'bao nhieu' || n.trim() == 'may' ||
        _has(n, ['bao nhieu do', 'duoc bao nhieu', 'ban duoc chua', 'co gi chua'])) {
      final buf = StringBuffer('Hôm nay: bán **${stats.salesToday} đơn** '
          '(${AiChatService.fmt(stats.saleRevenueToday)})');
      if (stats.repairsPending > 0) buf.write(', **${stats.repairsPending} đơn sửa** chưa giao');
      buf.write('.');
      return AiQuickResponse(
        buf.toString(),
        followUpChips: const [
          ('Chi tiết doanh thu', Icons.trending_up_rounded),
          ('Lợi nhuận', Icons.attach_money_rounded),
          ('Đơn đang chờ', Icons.pending_actions_rounded),
        ],
      );
    }

    // "thêm đơn" / "tạo đơn" → clarify sửa hay bán
    if (_has(n, ['tao don', 'them don', 'tao moi', 'muon tao']) &&
        !_has(n, ['sua', 'ban', 'kho', 'hang'])) {
      return const AiQuickResponse(
        'Bạn muốn tạo đơn gì?',
        actions: [
          AiAction(label: 'Đơn sửa chữa', icon: Icons.build_circle_rounded, type: AiActionType.openRepairsTab),
          AiAction(label: 'Đơn bán hàng', icon: Icons.point_of_sale_rounded, type: AiActionType.openSalesTab),
        ],
        followUpChips: [
          ('Nhập kho mới', Icons.add_box_rounded),
        ],
      );
    }

    // "xem" / "mở" + không có ngữ cảnh → clarify
    if (_has(n, ['xem gi', 'mo gi', 'xem cai gi', 'cho xem', 'mo ra']) &&
        !_has(n, ['don', 'kho', 'no', 'tai chinh', 'bao cao'])) {
      return const AiQuickResponse(
        'Bạn muốn xem gì?',
        followUpChips: [
          ('Doanh thu hôm nay', Icons.trending_up_rounded),
          ('Đơn sửa gần nhất', Icons.build_circle_rounded),
          ('Tồn kho', Icons.inventory_2_rounded),
          ('Công nợ', Icons.account_balance_wallet_rounded),
        ],
      );
    }

    // Tồn kho theo loại / tổng kho
    final asksPhoneStock = _has(n, ['dien thoai', 'kho dien thoai']);
    final asksAccessoryStock = _has(n, ['phu kien', 'kho phu kien']);
    final asksPartStock = _has(n, ['linh kien', 'kho linh kien']);
    final asksCombinedStock = asksAccessoryStock && asksPartStock;
    final asksGeneralStock = _has(n, ['ton kho', 'hang con', 'kiem kho', 'so luong hang']) ||
        _has(n, ['con khong', 'co khong', 'het chua', 'con bao nhieu', 'con may', 'co san khong', 'da het']);

    if (asksPhoneStock && !asksAccessoryStock && !asksPartStock) {
      return AiQuickResponse(
        _stockSection(
          title: 'Kho điện thoại',
          items: stats.phoneStockCount,
          quantity: stats.phoneStockQuantity,
          capital: stats.phoneStockCapital,
        ),
        actions: const [_kViewStockAction],
        followUpChips: const [
          ('Tồn kho hiện tại', Icons.inventory_2_rounded),
          ('Kho phụ kiện', Icons.headphones_rounded),
          ('Kho linh kiện', Icons.memory_rounded),
        ],
      );
    }

    if (asksAccessoryStock && !asksPartStock && !asksPhoneStock) {
      return AiQuickResponse(
        _stockSection(
          title: 'Kho phụ kiện',
          items: stats.accessoryStockCount,
          quantity: stats.accessoryStockQuantity,
          capital: stats.accessoryStockCapital,
        ),
        actions: const [_kViewStockAction],
        followUpChips: const [
          ('Tồn kho hiện tại', Icons.inventory_2_rounded),
          ('Kho điện thoại', Icons.phone_android_rounded),
          ('Kho linh kiện', Icons.memory_rounded),
        ],
      );
    }

    if (asksPartStock && !asksAccessoryStock && !asksPhoneStock) {
      return AiQuickResponse(
        _stockSection(
          title: 'Kho linh kiện',
          items: stats.partStockCount,
          quantity: stats.partStockQuantity,
          capital: stats.partStockCapital,
        ),
        actions: const [_kViewStockAction],
        followUpChips: const [
          ('Tồn kho hiện tại', Icons.inventory_2_rounded),
          ('Kho điện thoại', Icons.phone_android_rounded),
          ('Kho phụ kiện', Icons.headphones_rounded),
        ],
      );
    }

    if (asksCombinedStock) {
      return AiQuickResponse(
        [
          _stockSection(
            title: 'Kho linh kiện',
            items: stats.partStockCount,
            quantity: stats.partStockQuantity,
            capital: stats.partStockCapital,
          ),
          '',
          _stockSection(
            title: 'Kho phụ kiện',
            items: stats.accessoryStockCount,
            quantity: stats.accessoryStockQuantity,
            capital: stats.accessoryStockCapital,
          ),
        ].join('\n'),
        actions: const [_kViewStockAction],
        followUpChips: const [
          ('Tồn kho hiện tại', Icons.inventory_2_rounded),
          ('Kho điện thoại', Icons.phone_android_rounded),
        ],
      );
    }

    if (asksGeneralStock) {
      return AiQuickResponse(
        _stockOverview(stats),
        actions: const [_kViewStockAction],
        followUpChips: const [
          ('Sắp hết hàng', Icons.warning_amber_rounded),
          ('Kho linh kiện', Icons.memory_rounded),
          ('Nhập kho mới', Icons.add_box_rounded),
        ],
      );
    }

    // "ổn không" / "tốt không" / "được không" → tóm tắt
    if (_has(n, ['on khong', 'tot khong', 'the nao', 'sao roi',
                  'ra sao', 'nhu the nao', 'co van de gi khong'])) {
      final ok = stats.repairsPending == 0 && stats.debtReceivable < 1000000;
      final buf = StringBuffer(ok
          ? 'Hôm nay ổn! '
          : 'Có một số điểm cần chú ý: ');
      if (stats.repairsPending > 0) buf.write('**${stats.repairsPending} đơn sửa** chưa giao. ');
      if (stats.debtReceivable > 0) buf.write('Nợ phải thu: **${AiChatService.fmt(stats.debtReceivable)}**. ');
      buf.write('Doanh thu hôm nay: **${AiChatService.fmt(stats.revenueToday)}**.');
      return AiQuickResponse(
        buf.toString(),
        followUpChips: const [
          ('Chi tiết tài chính', Icons.summarize_rounded),
          ('Đơn đang chờ', Icons.pending_actions_rounded),
        ],
      );
    }

    // "nhanh" / "tóm tắt" / "brief" → quick summary
    if (_has(n, ['nhanh', 'tom tat', 'brief', 'ngon', 'ngan gon', 'chot', 'diem qua'])) {
      return AiQuickResponse(
        '**Hôm nay:**  ${stats.salesToday} đơn bán · '
        '${stats.repairsToday} đơn sửa · '
        'DT ${AiChatService.fmt(stats.revenueToday)} · '
        'LN ${AiChatService.fmt(stats.profitToday)}'
        '${stats.repairsPending > 0 ? ' · ⏳ ${stats.repairsPending} chưa giao' : ''}',
        followUpChips: const [
          ('Chi tiết', Icons.info_outline_rounded),
          ('Tháng này', Icons.calendar_month_rounded),
        ],
      );
    }

    // Hướng dẫn / trợ giúp
    if (_has(n, ['huong dan', 'tro giup', 'giup toi', 'ban co the', 'lam gi duoc',
                  'chuc nang', 'ho tro', 'dung duoc gi', 'biet gi', 'hoi gi duoc',
                  'noi nhu the nao', 'cach hoi', 'vi du',
                  // Cách hỏi tự nhiên khác của cùng một ý — trước đây không khớp
                  // nên người dùng không có đường nào thấy được năng lực của AI.
                  'lam duoc gi', 'lam duoc nhung gi', 'lam nhung gi', 'giup duoc gi',
                  'kha nang', 'biet lam gi', 'co the lam gi'])) {
      // Lưu ý: `_buildMsgText` của bong bóng chat CHỈ hiểu `**đậm**`. Dùng
      // `*nghiêng*` hay `_nghiêng_` sẽ hiện ra dấu sao/gạch dưới thô.
      return const AiQuickResponse(
        'Mình không chỉ trả lời — mình **làm hộ** được luôn. '
        'Bấm nút 🎤 để nói thay vì gõ.\n\n'
        '**🛠️ LÀM HỘ BẠN** (mình mở sẵn form, điền sẵn nội dung)\n'
        '• "Tạo đơn sửa iPhone 15 Pro thay màn cho Minh 0912345678"\n'
        '• "Tạo đơn bán Samsung A55 giá 6 triệu"\n'
        '• "Nhập kho mới 10 pin iPhone 13"\n\n'
        '**📊 TRA SỐ LIỆU** (trả lời ngay, không cần mạng)\n'
        '• "Hôm nay bán được bao nhiêu?" · "Lợi nhuận tháng này?"\n'
        '• "Đơn nào đang chờ?" · "Tồn kho linh kiện"\n'
        '• "Ai nợ nhiều nhất?" · "Khách Minh nợ bao nhiêu?"\n\n'
        '**📂 MỞ NHANH MÀN HÌNH**\n'
        '• "Mở đơn sửa gần nhất" · "Xem công nợ" · "Vào kho hàng"\n\n'
        '**📚 CHỈ CÁCH LÀM** (hỏi bất kỳ tính năng nào của app)\n'
        '• "Làm sao chốt quỹ?" · "Miễn nợ ở đâu?"\n'
        '• "Trả góp ngân hàng là gì?"\n\n'
        'Bấm **📚 Tất cả tính năng** để xem toàn bộ danh mục.',
        followUpChips: [
          ('Tạo đơn sửa', Icons.build_circle_rounded),
          ('Đơn đang chờ', Icons.pending_actions_rounded),
          ('📚 Tất cả tính năng', Icons.apps_rounded),
        ],
      );
    }

    // "Hôm nay thế nào" / tổng kết nhanh
    if (_has(n, ['hom nay the nao', 'ket qua hom nay', 'hom nay on khong',
                  'ngay hom nay nhu the nao', 'tong ket hom nay', 'bao cao nhanh'])) {
      final buf = StringBuffer('**Tóm tắt hôm nay:**\n');
      buf.writeln('• Bán hàng: **${stats.salesToday} đơn** — ${fmt(stats.saleRevenueToday)}');
      if (stats.deliveredRepairsToday > 0) {
        buf.writeln('• Sửa chữa giao: **${stats.deliveredRepairsToday} đơn** — ${fmt(stats.repairRevenueToday)}');
      }
      buf.writeln('• Tổng doanh thu: **${fmt(stats.revenueToday)}** | LN: **${fmt(stats.profitToday)}**');
      if (stats.repairsPending > 0) {
        buf.writeln('• Đơn sửa chưa giao: **${stats.repairsPending} đơn**');
      }
      return AiQuickResponse(
        buf.toString(),
        followUpChips: const [
          ('Tháng này', Icons.calendar_month_rounded),
          ('Công nợ', Icons.account_balance_wallet_rounded),
          ('Đơn đang chờ', Icons.pending_actions_rounded),
        ],
      );
    }

    // Nhập kho mới (từ chat)
    if (_has(n, ['nhap kho moi', 'nhap hang moi', 'them hang vao kho',
                  'nhap linh kien moi', 'bo sung kho', 'hang moi ve'])) {
      final rest = _contentAfterKeyword(n, [
        'nhap kho moi', 'nhap hang moi', 'them hang vao kho',
        'nhap linh kien moi', 'bo sung kho', 'hang moi ve',
      ]);
      final hasPayload = rest.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length >= 2;
      if (hasPayload) {
        return AiQuickResponse(
          'Nhập kho nhanh — AI sẽ điền thông tin từ mô tả:',
          actions: [AiAction(
            label: 'Mở form nhập kho',
            icon: Icons.add_box_rounded,
            type: AiActionType.createStockFromChat,
            payload: question,
          )],
        );
      }
      return const AiQuickResponse(
        'Chuyển sang màn hình **Kho hàng** để nhập hàng mới:',
        actions: [_kViewStockAction],
      );
    }

    // Đơn sửa đang chờ (pending)
    if (_has(n, ['don dang cho', 'may dang sua', 'chua xong', 'dang xu ly',
                  'cho xu ly', 'don chua giao', 'may chua lay'])) {
      if (stats.repairsPending == 0) {
        return const AiQuickResponse(
          'Hiện không có đơn sửa nào đang chờ xử lý. Tất cả đã được giao!',
          actions: [_kOpenLatestRepairAction],
        );
      }
      final pending = stats.pendingRepairSummaries
          .take(5)
          .map((s) => '• $s')
          .join('\n');
      final breakdown = <String>[
        if (stats.repairsInProgress > 0) '${stats.repairsInProgress} đang xử lý',
        if (stats.repairsAwaitingPickup > 0)
          '${stats.repairsAwaitingPickup} xong chờ khách lấy',
      ];
      final overdueNote = stats.repairsOverdue > 0
          ? '\n\n⚠️ Trong đó **${stats.repairsOverdue} đơn** tồn từ hôm trước.'
          : '';
      // "Chưa giao" chứ không phải "chờ xử lý" — xem ghi chú ở
      // DBHelper.getPendingRepairCounts.
      return AiQuickResponse(
        'Đang có **${stats.repairsPending} đơn** chưa giao'
        '${breakdown.isEmpty ? '' : ' (${breakdown.join(' · ')})'}:\n'
        '$pending$overdueNote',
        actions: const [_kOpenLatestRepairAction],
        followUpChips: const [
          ('Tạo đơn sửa mới', Icons.add_circle_outline_rounded),
          ('Sửa chữa hôm nay', Icons.today_rounded),
        ],
      );
    }

    // Tạo đơn bán — if user described the sale inline, open AI sheet pre-filled
    if (_has(n, ['tao don ban', 'them don ban', 'ban hang moi'])) {
      final rest = _contentAfterKeyword(n, ['tao don ban', 'them don ban', 'ban hang moi']);
      final hasPayload = rest.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length >= 2;
      if (hasPayload) {
        return AiQuickResponse(
          'Tạo đơn bán nhanh — AI sẽ điền thông tin từ mô tả của bạn:',
          actions: [AiAction(
            label: 'Mở form bán hàng',
            icon: Icons.point_of_sale_rounded,
            type: AiActionType.createSaleFromChat,
            payload: question,
          )],
          followUpChips: const [
            ('Doanh thu hôm nay', Icons.trending_up_rounded),
            ('Đơn bán gần nhất', Icons.receipt_long_rounded),
          ],
        );
      }
      return const AiQuickResponse(
        'Chuyển sang màn hình **Bán hàng** để tạo đơn bán mới:',
        actions: [_kOpenSalesTabAction],
      );
    }

    // Tạo đơn sửa — if user described the repair inline, open AI sheet pre-filled
    if (_has(n, ['tao don sua', 'them don sua', 'tiep nhan sua'])) {
      final rest = _contentAfterKeyword(n, ['tao don sua', 'them don sua', 'tiep nhan sua']);
      final hasPayload = rest.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length >= 2;
      if (hasPayload) {
        return AiQuickResponse(
          'Tạo đơn sửa nhanh — AI sẽ điền thông tin từ mô tả của bạn:',
          actions: [AiAction(
            label: 'Mở form sửa chữa',
            icon: Icons.build_circle_rounded,
            type: AiActionType.createRepairFromChat,
            payload: question,
          )],
          followUpChips: const [
            ('Đơn sửa hôm nay', Icons.today_rounded),
            ('Đơn đang chờ', Icons.pending_actions_rounded),
          ],
        );
      }
      return const AiQuickResponse(
        'Chuyển sang màn hình **Sửa chữa** để tiếp nhận máy mới:',
        actions: [_kOpenRepairsTabAction],
      );
    }

    // Context continuation: "gần nhất" alone → use lastIntent to resolve
    if (_has(n, ['gan nhat']) && !_has(n, ['ban', 'sua', 'don'])) {
      if (lastIntent == 'sale') {
        return const AiQuickResponse(
          'Mở hóa đơn bán hàng gần nhất:',
          actions: [_kOpenLatestSaleAction],
        );
      }
      if (lastIntent == 'repair') {
        return const AiQuickResponse(
          'Mở đơn sửa chữa gần nhất:',
          actions: [_kOpenLatestRepairAction],
        );
      }
    }

    // Tổng hợp tài chính
    if (_has(n, ['tai chinh', 'tong hop', 'tom tat', 'bao cao', 'tong ket']) &&
        !_has(n, ['nam nay', 'nam'])) {
      final buf = StringBuffer();
      buf.writeln('**Hôm nay:**');
      buf.writeln('• Bán hàng: **${stats.salesToday} đơn** — ${fmt(stats.saleRevenueToday)}');
      buf.writeln('• Sửa chữa giao: **${stats.deliveredRepairsToday} đơn** — ${fmt(stats.repairRevenueToday)}');
      buf.writeln('• Doanh thu: **${fmt(stats.revenueToday)}** | LN: **${fmt(stats.profitToday)}**');
      buf.writeln('• Đơn sửa chưa giao: **${stats.repairsPending} đơn**');
      buf.writeln();
      buf.writeln('**Tháng này:**');
      buf.writeln('• Bán hàng: **${stats.salesThisMonth} đơn** (${fmt(stats.saleRevenueThisMonth)})');
      buf.writeln('• Sửa chữa: **${stats.repairsThisMonth} đơn** (${fmt(stats.repairRevenueThisMonth)})');
      buf.writeln('• Doanh thu: **${fmt(stats.revenueThisMonth)}** | LN: **${fmt(stats.profitThisMonth)}**');
      buf.writeln();
      buf.writeln('**Năm nay:**');
      buf.writeln('• Bán hàng: **${stats.salesThisYear} đơn** (${fmt(stats.saleRevenueThisYear)})');
      buf.writeln('• Sửa chữa: **${stats.repairsThisYear} đơn** (${fmt(stats.repairRevenueThisYear)})');
      buf.writeln('• Doanh thu: **${fmt(stats.revenueThisYear)}** | LN: **${fmt(stats.profitThisYear)}**');
      buf.writeln();
      buf.write('• Công nợ phải thu: **${fmt(stats.debtReceivable)}** | Phải trả: **${fmt(stats.debtPayable)}**');
      return AiQuickResponse(
        buf.toString(),
        actions: const [_kViewDebtsAction],
        followUpChips: const [
          ('Đơn sửa đang chờ', Icons.pending_actions_rounded),
          ('Ai nợ nhiều nhất', Icons.person_rounded),
          ('Tồn kho', Icons.inventory_2_rounded),
        ],
      );
    }

    // Năm nay
    if (_has(n, ['nam nay', 'doanh thu nam', 'thong ke nam', 'nam ${DateTime.now().year}'])) {
      final buf = StringBuffer('**Năm ${DateTime.now().year}:**\n');
      buf.writeln('• Bán hàng: **${stats.salesThisYear} đơn** — ${fmt(stats.saleRevenueThisYear)}');
      buf.writeln('• Sửa chữa đã giao: **${stats.repairsThisYear} đơn** — ${fmt(stats.repairRevenueThisYear)}');
      buf.writeln('• Tổng doanh thu: **${fmt(stats.revenueThisYear)}**');
      buf.write('• Lợi nhuận: **${fmt(stats.profitThisYear)}**');
      return AiQuickResponse(
        buf.toString(),
        followUpChips: const [
          ('Tháng này', Icons.calendar_month_rounded),
          ('Hôm nay', Icons.today_rounded),
          ('Lợi nhuận', Icons.trending_up_rounded),
        ],
      );
    }

    // Tháng này (chi tiết)
    if (_has(n, ['thang nay', 'doanh thu thang', 'ban hang thang', 'sua chua thang']) &&
        !_has(n, ['nam nay'])) {
      final buf = StringBuffer('**Tháng ${DateTime.now().month}/${DateTime.now().year}:**\n');
      buf.writeln('• Bán hàng: **${stats.salesThisMonth} đơn** — ${fmt(stats.saleRevenueThisMonth)}');
      buf.writeln('• Sửa chữa đã giao: **${stats.repairsThisMonth} đơn** — ${fmt(stats.repairRevenueThisMonth)}');
      buf.writeln('• Tổng doanh thu: **${fmt(stats.revenueThisMonth)}**');
      buf.write('• Lợi nhuận: **${fmt(stats.profitThisMonth)}**');
      return AiQuickResponse(
        buf.toString(),
        followUpChips: const [
          ('Hôm nay', Icons.today_rounded),
          ('Năm nay', Icons.bar_chart_rounded),
          ('Lợi nhuận', Icons.trending_up_rounded),
        ],
      );
    }

    // Bán hàng hôm nay
    if (_has(n, ['ban hang hom nay', 'don ban hom nay', 'so don ban hom nay'])) {
      if (stats.salesToday == 0) {
        return const AiQuickResponse(
          'Hôm nay chưa có đơn bán nào.',
          actions: [_kOpenLatestSaleAction],
          followUpChips: [
            ('Tạo đơn bán', Icons.add_shopping_cart_rounded),
            ('Doanh thu tháng này', Icons.calendar_month_rounded),
          ],
        );
      }
      return AiQuickResponse(
        'Hôm nay bán **${stats.salesToday} đơn**, doanh thu **${fmt(stats.saleRevenueToday)}**.',
        actions: const [_kOpenLatestSaleAction],
        followUpChips: const [
          ('Tạo đơn bán', Icons.add_shopping_cart_rounded),
          ('Lợi nhuận', Icons.trending_up_rounded),
          ('Tháng này', Icons.calendar_month_rounded),
        ],
      );
    }

    // Sửa chữa hôm nay
    if (_has(n, ['sua chua hom nay', 'don sua hom nay', 'so don sua hom nay'])) {
      return AiQuickResponse(
        'Hôm nay nhận **${stats.repairsToday} đơn sửa**. '
        'Đã giao: **${stats.deliveredRepairsToday}**, chưa giao: **${stats.repairsPending}**. '
        'Doanh thu sửa chữa: **${fmt(stats.repairRevenueToday)}**.',
        actions: const [_kOpenLatestRepairAction],
        followUpChips: const [
          ('Tạo đơn sửa', Icons.add_circle_outline_rounded),
          ('Đơn đang chờ', Icons.pending_actions_rounded),
          ('Sửa chữa tháng này', Icons.calendar_month_rounded),
        ],
      );
    }

    // Doanh thu hôm nay
    if (_has(n, ['doanh thu', 'ban duoc', 'thu duoc', 'ban hang']) &&
        !_has(n, ['gom', 'nhung', 'nao', 'chi tiet', 'danh sach', 'thang', 'nam'])) {
      if (stats.revenueToday == 0 && stats.salesToday == 0 && stats.deliveredRepairsToday == 0) {
        return AiQuickResponse(
          'Hôm nay chưa có doanh thu — chưa có đơn bán hoặc đơn sửa nào hoàn thành.\n'
          '${stats.repairsPending > 0 ? "Đang có **${stats.repairsPending} đơn sửa** chưa giao." : ""}',
          followUpChips: const [
            ('Tạo đơn bán', Icons.point_of_sale_rounded),
            ('Tạo đơn sửa', Icons.build_circle_rounded),
            ('Doanh thu tháng này', Icons.calendar_month_rounded),
          ],
        );
      }
      final buf = StringBuffer();
      if (stats.salesToday > 0) {
        buf.write('Bán hàng: **${stats.salesToday} đơn** (${fmt(stats.saleRevenueToday)}). ');
      }
      if (stats.deliveredRepairsToday > 0) {
        buf.write('Sửa chữa giao: **${stats.deliveredRepairsToday} đơn** (${fmt(stats.repairRevenueToday)}). ');
      }
      buf.write('Tổng: **${fmt(stats.revenueToday)}** | LN: **${fmt(stats.profitToday)}**.');
      return AiQuickResponse(
        buf.toString(),
        followUpChips: const [
          ('Tháng này', Icons.calendar_month_rounded),
          ('Lợi nhuận', Icons.trending_up_rounded),
          ('Đơn sửa', Icons.build_circle_rounded),
        ],
      );
    }

    // Tồn kho hàng hoá
    if (_has(n, ['ton kho', 'hang con', 'kiem kho', 'so luong hang']) &&
        !_has(n, ['linh kien', 'phu kien'])) {
      return AiQuickResponse(
        _stockOverview(stats),
        actions: const [_kViewStockAction],
        followUpChips: const [
          ('Sắp hết hàng', Icons.warning_amber_rounded),
          ('Kho linh kiện', Icons.memory_rounded),
          ('Nhập kho mới', Icons.add_box_rounded),
        ],
      );
    }

    // Kho linh kiện / phụ kiện
    if (_has(n, ['linh kien', 'phu kien', 'kho linh', 'linh phu kien'])) {
      return AiQuickResponse(
        [
          _stockSection(
            title: 'Kho linh kiện',
            items: stats.partStockCount,
            quantity: stats.partStockQuantity,
            capital: stats.partStockCapital,
          ),
          '',
          _stockSection(
            title: 'Kho phụ kiện',
            items: stats.accessoryStockCount,
            quantity: stats.accessoryStockQuantity,
            capital: stats.accessoryStockCapital,
          ),
        ].join('\n'),
        actions: const [_kViewStockAction],
        followUpChips: const [
          ('Linh kiện sắp hết', Icons.warning_amber_rounded),
          ('Nhập linh kiện mới', Icons.add_box_rounded),
          ('Tồn kho hàng hoá', Icons.inventory_2_rounded),
        ],
      );
    }

    // Đơn bán gần nhất
    if (_has(n, ['don ban gan nhat', 'hoa don ban gan', 'don ban moi nhat',
                  'mo don ban', 'xem don ban'])) {
      return const AiQuickResponse(
        'Mở hóa đơn bán hàng gần nhất:',
        actions: [_kOpenLatestSaleAction],
        followUpChips: [
          ('Tạo đơn bán mới', Icons.add_shopping_cart_rounded),
          ('Doanh thu hôm nay', Icons.trending_up_rounded),
        ],
      );
    }

    // Đơn sửa gần nhất
    if (_has(n, ['don sua gan nhat', 'don sua moi nhat', 'mo don sua',
                  'xem don sua gan nhat'])) {
      return const AiQuickResponse(
        'Mở đơn sửa chữa gần nhất:',
        actions: [_kOpenLatestRepairAction],
        followUpChips: [
          ('Tạo đơn sửa mới', Icons.add_circle_outline_rounded),
          ('Đơn đang chờ', Icons.pending_actions_rounded),
        ],
      );
    }

    // Đơn sửa danh sách chi tiết
    if (_has(n, ['gom nhung don', 'don nao', 'nhung don', 'don hom nay',
                  'danh sach don', 'co nhung don gi'])) {
      if (stats.repairSummaries.isEmpty) {
        return const AiQuickResponse('Hôm nay chưa có đơn sửa nào.');
      }
      final lines = stats.repairSummaries
          .asMap()
          .entries
          .map((e) => '${e.key + 1}. ${e.value}')
          .join('\n');
      return AiQuickResponse(
        'Đơn sửa hôm nay (${stats.repairsToday} đơn):\n$lines',
        actions: const [_kOpenLatestRepairAction],
      );
    }

    // Đơn sửa tổng quát
    if (_has(n, ['don sua', 'sua may', 'sua chua', 'dang sua', 'cho lay'])) {
      final answer = StringBuffer(
          'Hôm nay nhận **${stats.repairsToday} đơn sửa** mới. '
          'Đã giao: **${stats.deliveredRepairsToday} đơn**, '
          'chưa giao: **${stats.repairsPending} đơn**.');
      if (stats.repairsPending > 0) {
        final pending = stats.repairSummaries
            .where((s) =>
                s.contains('Đang sửa') ||
                s.contains('Mới nhận') ||
                s.contains('Xong chờ'))
            .take(5)
            .map((s) => '• $s')
            .join('\n');
        if (pending.isNotEmpty) answer.write('\n$pending');
      }
      return AiQuickResponse(
        answer.toString(),
        actions: const [_kOpenLatestRepairAction],
        followUpChips: const [
          ('Tạo đơn sửa', Icons.add_circle_outline_rounded),
          ('Sửa chữa tháng này', Icons.calendar_month_rounded),
        ],
      );
    }

    // Thu nợ khách
    if (_has(n, ['thu no khach', 'thu no', 'khach no tien', 'khach chua tra'])) {
      if (stats.debtReceivable == 0) {
        return const AiQuickResponse('Shop hiện không có khách nào đang nợ tiền.');
      }
      final buf = StringBuffer(
          'Tổng công nợ phải thu: **${fmt(stats.debtReceivable)}**.');
      if (stats.topDebtorLines.isNotEmpty) {
        buf.write('\n\nKhách nợ cao nhất:\n'
            '${stats.topDebtorLines.take(3).map((l) => '• $l').join('\n')}');
      }
      return AiQuickResponse(
        buf.toString(),
        actions: const [_kViewDebtsAction],
        followUpChips: const [
          ('Ai nợ nhiều nhất', Icons.person_rounded),
          ('Nợ NCC', Icons.store_rounded),
        ],
      );
    }

    // Trả nợ NCC / nhà cung cấp
    if (_has(n, ['tra no ncc', 'tra no nha cung cap', 'no ncc',
                  'cong no ncc', 'nha cung cap'])) {
      if (stats.debtPayable == 0) {
        return const AiQuickResponse(
          'Hiện không có nợ nhà cung cấp nào đang chờ.',
          followUpChips: [
            ('Công nợ khách', Icons.account_balance_wallet_rounded),
            ('Tổng hợp tài chính', Icons.summarize_rounded),
          ],
        );
      }
      return AiQuickResponse(
        'Công nợ phải trả NCC: **${fmt(stats.debtPayable)}**.\n'
        'Vào mục Nhà cung cấp để ghi thanh toán.',
        actions: const [_kViewDebtPayableAction],
        followUpChips: const [
          ('Ai nợ mình nhiều nhất', Icons.person_rounded),
        ],
      );
    }

    // "khách <tên> nợ bao nhiêu" — tra một khách cụ thể trong nợ phải thu.
    // Chỉ trả lời khi tách được tên và khớp ít nhất 1 khách; nếu không → null.
    if (stats.debtorLookup.isNotEmpty &&
        _has(n, ['no bao nhieu', 'no tien', 'con no', 'no chua', 'no gi']) &&
        !_has(n, [
          'ai no', 'no ai', 'con no ai', 'ai dang no', 'ai con no',
          'top no', 'nhieu nhat', 'it nhat', 'tong no', 'ncc', 'nha cung cap',
        ])) {
      var namePart = n;
      for (final kw in [
        'khach hang', 'khach', 'con no bao nhieu', 'no bao nhieu tien',
        'no bao nhieu', 'con no', 'no tien', 'no chua tra', 'no chua',
        'bao nhieu', 'no gi khong', 'no gi', 'hien tai', 'bay gio',
        'tien', 'la', 'cua', 'thi', 'con', 'no',
      ]) {
        namePart = namePart.replaceAll(kw, ' ');
      }
      const nameStop = {
        'ai', 'khong', 'gi', 'nao', 'the', 'shop', 'minh', 'toi', 'ban',
        'hien', 'tai', 'nay', 'do', 'kia',
      };
      final nameTokens = namePart
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 2 && !nameStop.contains(w))
          .toList();
      if (nameTokens.isNotEmpty) {
        final matches = <String, int>{};
        stats.debtorLookup.forEach((name, remaining) {
          final nn = VietnameseUtils.normalize(name);
          if (nameTokens.any((t) => nn.contains(t))) matches[name] = remaining;
        });
        if (matches.length == 1) {
          final e = matches.entries.first;
          return AiQuickResponse(
            '**${e.key}** đang nợ **${fmt(e.value)}**.',
            actions: const [_kViewDebtsAction],
            followUpChips: const [
              ('Ai nợ nhiều nhất', Icons.person_rounded),
              ('Tổng công nợ', Icons.account_balance_wallet_rounded),
            ],
          );
        }
        if (matches.length > 1) {
          final lines = (matches.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .take(6)
              .map((e) => '• ${e.key}: **${fmt(e.value)}**')
              .join('\n');
          return AiQuickResponse(
            'Có mấy khách khớp:\n$lines',
            actions: const [_kViewDebtsAction],
          );
        }
      }
    }

    // Ai nợ nhiều nhất
    if (_has(n, ['ai no nhieu nhat', 'no ai nhieu', 'top no',
                  'no nhieu nhat', 'ai no tien nhieu'])) {
      if (stats.topDebtorLines.isEmpty) {
        return const AiQuickResponse('Shop hiện chưa có khách nào đang nợ tiền.');
      }
      return AiQuickResponse(
        'Khách nợ cao nhất:\n'
        '${stats.topDebtorLines.map((l) => '• $l').join('\n')}',
        actions: const [_kViewDebtsAction],
      );
    }

    // Công nợ tổng
    if (_has(n, ['cong no', 'khach no', 'no chua tra'])) {
      final answer = StringBuffer(
          'Công nợ phải thu: **${fmt(stats.debtReceivable)}**\n'
          'Công nợ phải trả NCC: **${fmt(stats.debtPayable)}**.');
      if (stats.topDebtorLines.isNotEmpty) {
        answer.write(
            '\n\nTop khách nợ:\n'
            '${stats.topDebtorLines.take(3).map((l) => '• $l').join('\n')}');
      }
      return AiQuickResponse(
        answer.toString(),
        actions: [_kViewDebtsAction, if (stats.debtPayable > 0) _kViewDebtPayableAction],
        followUpChips: const [
          ('Ai nợ nhiều nhất', Icons.person_rounded),
          ('Nợ NCC', Icons.store_rounded),
          ('Tổng hợp tài chính', Icons.summarize_rounded),
        ],
      );
    }

    // Lợi nhuận
    if (_has(n, ['loi nhuan', 'lai bao nhieu', 'loi bao nhieu'])) {
      return AiQuickResponse(
        'Lợi nhuận hôm nay: **${fmt(stats.profitToday)}** '
        '(bán hàng + sửa chữa đã giao).',
        followUpChips: const [
          ('Tháng này', Icons.calendar_month_rounded),
          ('Năm nay', Icons.bar_chart_rounded),
          ('Doanh thu hôm nay', Icons.trending_up_rounded),
        ],
      );
    }

    // Chào hỏi
    if (_has(n, ['xin chao', 'hello', 'chao ban', 'chao ai', 'ban la ai',
                  'hey', 'hi ', 'alo', 'co ai o day khong', 'may la ai',
                  'minh la ai', 'gioi thieu', 'ban ten gi', 'ai vay'])) {
      return const AiQuickResponse(
        'Xin chào! Mình là **AI Trợ Lý** của shop — hỏi gì cũng được!\n\n'
        'Thử ngay: "Hôm nay bán được bao nhiêu?"\n'
        'Hoặc: "Tạo đơn sửa iPhone 15 cho Minh 0912..."',
        followUpChips: [
          ('Tóm tắt hôm nay', Icons.today_rounded),
          ('Đơn đang chờ', Icons.pending_actions_rounded),
          ('✨ AI làm được gì?', Icons.auto_awesome_rounded),
        ],
      );
    }

    // Cảm ơn / phản hồi tích cực
    if (_has(n, ['cam on', 'thank', 'tuyet', 'gioi lam', 'tot lam', 'hay day', 'xong roi', 'duoc roi'])) {
      return const AiQuickResponse(
        'Không có gì! Cần gì cứ hỏi mình nhé.',
        followUpChips: [
          ('Tổng hợp tài chính', Icons.summarize_rounded),
          ('Tạo đơn sửa', Icons.build_circle_rounded),
        ],
      );
    }

    // Kiểm tra lợi nhuận tháng / năm cụ thể
    if (_has(n, ['loi nhuan thang', 'lai thang', 'loi thang nay'])) {
      return AiQuickResponse(
        'Lợi nhuận tháng ${DateTime.now().month}/${DateTime.now().year}: '
        '**${fmt(stats.profitThisMonth)}**\n'
        '(Bán hàng + sửa chữa đã giao)',
        followUpChips: const [
          ('Năm nay', Icons.bar_chart_rounded),
          ('Hôm nay', Icons.today_rounded),
        ],
      );
    }

    if (_has(n, ['loi nhuan nam', 'lai nam nay', 'loi nam nay'])) {
      return AiQuickResponse(
        'Lợi nhuận năm ${DateTime.now().year}: **${fmt(stats.profitThisYear)}**\n'
        '(Bán hàng + sửa chữa đã giao)',
        followUpChips: const [
          ('Tháng này', Icons.calendar_month_rounded),
          ('Doanh thu năm', Icons.bar_chart_rounded),
        ],
      );
    }

    // Số đơn / bao nhiêu đơn
    if (_has(n, ['bao nhieu don', 'may don', 'so don', 'dem don'])) {
      return AiQuickResponse(
        'Hôm nay:\n'
        '• Bán hàng: **${stats.salesToday} đơn**\n'
        '• Sửa chữa nhận: **${stats.repairsToday} đơn** (chưa giao: ${stats.repairsPending}, đã giao: ${stats.deliveredRepairsToday})',
        followUpChips: const [
          ('Tháng này', Icons.calendar_month_rounded),
          ('Chi tiết đơn sửa', Icons.list_alt_rounded),
        ],
      );
    }

    return null;
  }

  // ── Progressive Intent Clarification ─────────────────────────────────────────
  //
  // Called when quickAnswer() returns null.  If the input is short/ambiguous
  // but maps to a known domain, return clarification chips instead of going
  // straight to cloud AI.

  AiClarifyResponse? detectAmbiguousIntent(String question) {
    final raw = VietnameseUtils.normalize(question.toLowerCase().trim());
    final n = RepairVocabularyService.instance.preprocessQuery(_expandSynonyms(raw));
    final words = n.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordCount = words.length;

    // Only fire for short (≤ 4 words) inputs — longer ones are likely specific enough
    if (wordCount > 4) return null;

    // Guard: already contains a specific qualifier → quickAnswer or cloud handles it
    if (_has(n, [
      'hom nay', 'thang nay', 'nam nay', 'gan nhat', 'moi nhat',
      'tao', 'them', 'mo', 'kiem tra', 'bao nhieu', 'danh sach',
      'tong', 'chi tiet', 'nhieu nhat', 'it nhat', 'sap het',
      'dang cho', 'dang sua', 'da giao', 'chua tra',
      'thu no', 'tra no', 'linh kien', 'phu kien',
    ])) { return null; }

    // ── Domain: bán hàng ──
    if (_has(n, ['ban', 'hang ban', 'dat hang', 'order', 'don hang']) &&
        !_has(n, ['tra no', 'ncc', 'linh kien', 'phu kien', 'san pham', 'phong ban', 'ban be'])) {
      return const AiClarifyResponse(
        'Bạn muốn:',
        suggestions: [
          AiIntentSuggestion(label: 'Tạo đơn bán', query: 'tạo đơn bán', icon: Icons.add_shopping_cart_rounded),
          AiIntentSuggestion(label: 'Đơn bán gần nhất', query: 'đơn bán gần nhất', icon: Icons.receipt_long_rounded),
          AiIntentSuggestion(label: 'Doanh thu hôm nay', query: 'doanh thu hôm nay', icon: Icons.trending_up_rounded),
          AiIntentSuggestion(label: 'Bán hàng tháng này', query: 'bán hàng tháng này', icon: Icons.calendar_month_rounded),
          AiIntentSuggestion(label: 'Sản phẩm bán chạy', query: 'sản phẩm bán chạy nhất', icon: Icons.star_rounded),
        ],
      );
    }

    // ── Domain: sửa chữa ──
    if (_has(n, ['sua', 'don sua', 'sua chua', 'tiep nhan', 'bao hanh', 'sua may', 'don dien thoai']) &&
        !_has(n, ['nha', 'sach', 'sua kho', 'sua gi'])) {
      return const AiClarifyResponse(
        'Bạn muốn:',
        suggestions: [
          AiIntentSuggestion(label: 'Tạo đơn sửa', query: 'tạo đơn sửa', icon: Icons.add_circle_outline_rounded),
          AiIntentSuggestion(label: 'Đơn sửa hôm nay', query: 'sửa chữa hôm nay', icon: Icons.today_rounded),
          AiIntentSuggestion(label: 'Đơn đang chờ', query: 'đơn sửa đang chờ', icon: Icons.pending_actions_rounded),
          AiIntentSuggestion(label: 'Đơn sửa gần nhất', query: 'đơn sửa gần nhất', icon: Icons.build_circle_rounded),
          AiIntentSuggestion(label: 'Sửa chữa tháng này', query: 'sửa chữa tháng này', icon: Icons.calendar_today_rounded),
        ],
      );
    }

    // ── Domain: kho ──
    if (_has(n, ['kho', 'ton kho', 'hang hoa', 'san pham', 'linh kien', 'inventory', 'stock']) &&
        !_has(n, ['nhap kho', 'xuat kho', 'lich su nhap', 'thu kho'])) {
      return const AiClarifyResponse(
        'Bạn muốn:',
        suggestions: [
          AiIntentSuggestion(label: 'Tồn kho hiện tại', query: 'tồn kho hiện tại', icon: Icons.inventory_2_rounded),
          AiIntentSuggestion(label: 'Sản phẩm sắp hết', query: 'sản phẩm sắp hết hàng', icon: Icons.warning_amber_rounded),
          AiIntentSuggestion(label: 'Kho linh kiện', query: 'kho linh kiện', icon: Icons.memory_rounded),
          AiIntentSuggestion(label: 'Lịch sử nhập kho', query: 'lịch sử nhập kho', icon: Icons.history_rounded),
          AiIntentSuggestion(label: 'Nhà cung cấp', query: 'nhà cung cấp', icon: Icons.store_rounded),
        ],
      );
    }

    // ── Domain: nợ / công nợ ──
    if (_has(n, ['no', 'cong no', 'no phai thu', 'khach no', 'thu no', 'tra no', 'debt']) &&
        !_has(n, ['ngoai no', 'nhap no', 'ton kho', 'ba no'])) {
      return const AiClarifyResponse(
        'Bạn muốn:',
        suggestions: [
          AiIntentSuggestion(label: 'Khách nợ nhiều nhất', query: 'ai nợ nhiều nhất', icon: Icons.person_rounded),
          AiIntentSuggestion(label: 'Tổng công nợ', query: 'tổng công nợ', icon: Icons.account_balance_wallet_rounded),
          AiIntentSuggestion(label: 'Nợ nhà cung cấp', query: 'nợ nhà cung cấp', icon: Icons.store_rounded),
          AiIntentSuggestion(label: 'Khoản phải thu', query: 'thu nợ khách', icon: Icons.south_rounded),
          AiIntentSuggestion(label: 'Khoản phải trả', query: 'trả nợ NCC', icon: Icons.north_rounded),
        ],
      );
    }

    // ── Domain: tài chính / thống kê ──
    if (_has(n, ['tai chinh', 'thong ke', 'bao cao', 'doanh thu', 'tien', 'thu nhap',
                  'loi nhuan', 'doanh so', 'so sanh', 'tong hop', 'finance', 'revenue'])) {
      return const AiClarifyResponse(
        'Bạn muốn:',
        suggestions: [
          AiIntentSuggestion(label: 'Hôm nay', query: 'doanh thu hôm nay', icon: Icons.today_rounded),
          AiIntentSuggestion(label: 'Tháng này', query: 'tài chính tháng này', icon: Icons.calendar_month_rounded),
          AiIntentSuggestion(label: 'Năm nay', query: 'năm nay', icon: Icons.bar_chart_rounded),
          AiIntentSuggestion(label: 'Tổng hợp', query: 'tổng hợp tài chính', icon: Icons.summarize_rounded),
          AiIntentSuggestion(label: 'Lợi nhuận', query: 'lợi nhuận', icon: Icons.trending_up_rounded),
        ],
      );
    }

    // ── Domain: NCC / nhà cung cấp ──
    if (_has(n, ['ncc', 'nha cung cap'])) {
      return const AiClarifyResponse(
        'Bạn muốn:',
        suggestions: [
          AiIntentSuggestion(label: 'Nợ nhà cung cấp', query: 'nợ nhà cung cấp', icon: Icons.money_off_rounded),
          AiIntentSuggestion(label: 'Danh sách NCC', query: 'danh sách nhà cung cấp', icon: Icons.list_rounded),
          AiIntentSuggestion(label: 'NCC nợ nhiều nhất', query: 'nhà cung cấp nào nợ nhiều nhất', icon: Icons.trending_up_rounded),
        ],
      );
    }

    // ── Domain: linh kiện / phụ kiện ──
    if (_has(n, ['linh kien', 'phu kien'])) {
      return const AiClarifyResponse(
        'Bạn muốn:',
        suggestions: [
          AiIntentSuggestion(label: 'Tồn kho linh kiện', query: 'tồn kho linh kiện', icon: Icons.memory_rounded),
          AiIntentSuggestion(label: 'Linh kiện sắp hết', query: 'linh kiện sắp hết', icon: Icons.warning_amber_rounded),
          AiIntentSuggestion(label: 'Nhập linh kiện', query: 'nhập linh kiện mới', icon: Icons.add_box_rounded),
        ],
      );
    }

    // ── Domain: thương hiệu (iPhone, Samsung…) ──
    for (final brand in RepairVocabularyService.kBrands) {
      if (n.contains(brand)) {
        return AiClarifyResponse(
          'Bạn muốn:',
          suggestions: [
            AiIntentSuggestion(label: 'Tìm trong kho', query: 'tồn kho $brand', icon: Icons.search_rounded),
            AiIntentSuggestion(label: 'Tạo đơn sửa', query: 'tạo đơn sửa $brand', icon: Icons.build_rounded),
            AiIntentSuggestion(label: 'Đơn bán gần nhất', query: 'đơn bán $brand gần nhất', icon: Icons.receipt_rounded),
          ],
        );
      }
    }

    return null;
  }

  bool _has(String n, List<String> keywords) =>
      keywords.any((k) => n.contains(VietnameseUtils.normalize(k)));

  // Returns normalized text after stripping first matched keyword, empty if nothing left.
  static String _contentAfterKeyword(String norm, List<String> keywords) {
    for (final kw in keywords) {
      final nkw = VietnameseUtils.normalize(kw);
      if (norm.contains(nkw)) return norm.replaceFirst(nkw, '').trim();
    }
    return '';
  }

  // ── Cloud AI ──────────────────────────────────────────────────────────────

  // ── Prompt sanitizer ─────────────────────────────────────────────────────
  // Strips characters that could be used for prompt injection.
  static String _sanitize(String s) {
    // Remove HTML/XML tags
    var out = s.replaceAll(RegExp(r'<[^>]*>'), '');
    // Remove backtick blocks
    out = out.replaceAll('`', "'");
    // Strip template-injection chars: {, }, $
    out = out.replaceAll('{', '(').replaceAll('}', ')').replaceAll('\$', '');
    // Collapse multiple newlines — prevent multi-line role override injection
    out = out.replaceAll(RegExp(r'\n{2,}'), '\n');
    // Strip common prompt override patterns (case-insensitive)
    out = out.replaceAll(RegExp(r'(system|assistant|human|user)\s*:', caseSensitive: false), '');
    // Limit length to 1000 chars
    if (out.length > 1000) out = out.substring(0, 1000);
    return out.trim();
  }

  static List<String> _sanitizeList(List<String> items) =>
      items.map(_sanitize).toList();

  Future<(String?, String?)> askAI(
    String question,
    AiChatStats stats,
    List<Map<String, String>> history, {
    String? role,
  }) async {
    try {
      final callable = _fn.httpsCallable(
        'chatAssistant',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
      );
      // Sanitize user-controlled strings before sending to LLM
      final safeQuestion = _sanitize(question);
      // Kiến thức tính năng liên quan (offline, nội dung của app — an toàn).
      final knowledge = AiKnowledgeService.instance
          .buildCloudContext(question, role: role);
      final safeHistory = history
          .map((m) => {
                'role': m['role'] ?? '',
                'content': _sanitize(m['content'] ?? ''),
              })
          .toList();
      // Trim payload to reduce token cost:
      // - repairSummaries: send max 5 (not 20), sanitize customer names
      // - topDebtorLines: send max 3, sanitize
      // - history already limited to 8 by caller
      final trimmedStats = {
        ...stats.toJson(),
        'repairSummaries': _sanitizeList(
          (stats.repairSummaries).take(5).toList(),
        ),
        'topDebtorLines': _sanitizeList(
          (stats.topDebtorLines).take(3).toList(),
        ),
      };
      final res = await callable.call({
        'question': safeQuestion,
        'stats': trimmedStats,
        'history': safeHistory,
        if (knowledge.isNotEmpty) 'knowledge': knowledge,
        if (role != null && role.isNotEmpty) 'role': role,
      });
      final data = res.data as Map<Object?, Object?>;
      final answer = data['answer'] as String?;
      if (answer == null || answer.isEmpty) {
        return (null, 'Mình chưa trả lời được câu này. Thử hỏi lại với cách diễn đạt khác nhé.');
      }
      return (answer, null);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        return (null, 'Đang bận — bạn thử lại sau vài giây nhé.');
      }
      if (e.code == 'unauthenticated') {
        return (null, 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
      }
      return (null, 'Mình chưa hiểu câu này. Thử hỏi: "doanh thu hôm nay", "đơn đang chờ", "công nợ", "tạo đơn sửa"...\nHoặc bấm **Hướng dẫn** để xem ví dụ.');
    } catch (_) {
      return (null, 'Mất kết nối. Kiểm tra internet và thử lại.');
    }
  }

  // ── Format helpers ────────────────────────────────────────────────────────

  static String fmt(int amount) {
    if (amount == 0) return '0đ';
    if (amount >= 1000000) {
      final m = amount / 1000000;
      return '${m % 1 == 0 ? m.toInt() : m.toStringAsFixed(1)}tr';
    }
    final raw = amount.toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = raw.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buf.write('.');
      buf.write(raw[i]);
      count++;
    }
    return '${buf.toString().split('').reversed.join()}đ';
  }

  static String fmtCount(int amount) {
    final raw = amount.toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = raw.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buf.write('.');
      buf.write(raw[i]);
      count++;
    }
    return buf.toString().split('').reversed.join();
  }

  static String _stockSection({
    required String title,
    required int items,
    required int quantity,
    required int capital,
  }) {
    return [
      '$title:',
      '${fmtCount(items)} mặt hàng',
      'Sản phẩm tồn: ${fmtCount(quantity)}',
      'Giá vốn ${fmt(capital)}',
    ].join('\n');
  }

  static String _stockOverview(AiChatStats stats) {
    return [
      _stockSection(
        title: 'Kho điện thoại',
        items: stats.phoneStockCount,
        quantity: stats.phoneStockQuantity,
        capital: stats.phoneStockCapital,
      ),
      '',
      _stockSection(
        title: 'Kho phụ kiện',
        items: stats.accessoryStockCount,
        quantity: stats.accessoryStockQuantity,
        capital: stats.accessoryStockCapital,
      ),
      '',
      _stockSection(
        title: 'Kho linh kiện',
        items: stats.partStockCount,
        quantity: stats.partStockQuantity,
        capital: stats.partStockCapital,
      ),
      '',
      _stockSection(
        title: 'Tồn kho hiện tại',
        items: stats.stockCount,
        quantity: stats.stockQuantity,
        capital: stats.stockCapital,
      ),
    ].join('\n');
  }
}
