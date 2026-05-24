import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../utils/vietnamese_utils.dart';

// ── AI Action ──────────────────────────────────────────────────────────────────

enum AiActionType {
  openLatestRepair,
  openLatestSale,
  viewDebts,
  viewDebtPayable,
  viewStock,
  openSalesTab,
  openRepairsTab,
}

class AiAction {
  final String label;
  final IconData icon;
  final AiActionType type;
  const AiAction({required this.label, required this.icon, required this.type});
}

// ── Quick response ──────────────────────────────────────────────────────────────

class AiQuickResponse {
  final String text;
  final List<AiAction> actions;
  const AiQuickResponse(this.text, {this.actions = const []});
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
  final int repairsPending;

  // Stock
  final int stockCount;
  final int stockCapital;

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
  final List<String> topDebtorLines;

  const AiChatStats({
    this.salesToday = 0,
    this.revenueToday = 0,
    this.profitToday = 0,
    this.saleRevenueToday = 0,
    this.repairRevenueToday = 0,
    this.deliveredRepairsToday = 0,
    this.repairsToday = 0,
    this.repairsPending = 0,
    this.stockCount = 0,
    this.stockCapital = 0,
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
    this.topDebtorLines = const [],
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
        'stockCount': stockCount,
        'stockCapital': stockCapital,
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
      db.getInventorySummary(),                                     // [2] tồn kho
      db.getDebtsForFinanceSnapshot(),                             // [3] công nợ
      db.getSalesByDateRange(monthStart, monthEnd),                 // [4] sales tháng
      db.getRepairsByCreatedAtRange(monthStart, monthEnd),         // [5] đơn sửa tháng
      db.getDeliveredRepairsByDateRange(dayStart, dayEnd),         // [6] đã giao hôm nay
      db.getDeliveredRepairsByDateRange(monthStart, monthEnd),     // [7] đã giao tháng
      db.getSalesByDateRange(yearStart, yearEnd),                   // [8] sales năm
      db.getRepairsByCreatedAtRange(yearStart, yearEnd),           // [9] đơn sửa năm
      db.getDeliveredRepairsByDateRange(yearStart, yearEnd),       // [10] đã giao năm
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

    // ── Đơn sửa: đếm + list (mọi trạng thái) ──
    int pending = 0;
    final repairSummaries = <String>[];
    const statusLabel = {1: 'Mới nhận', 2: 'Đang sửa', 3: 'Xong chờ lấy', 4: 'Đã giao'};
    for (final r in repairs) {
      final status = (r.status as num?)?.toInt() ?? 0;
      if (status < 4) pending++;
      final model = (r.model as String?)?.trim() ?? '';
      final issue = (r.issue as String?)?.trim() ?? '';
      final name = (r.customerName as String?)?.trim() ?? '';
      final price = (r.price as num?)?.toInt() ?? 0;
      final statusStr = statusLabel[status] ?? 'Không rõ';
      final summary = [
        if (model.isNotEmpty) model,
        if (issue.isNotEmpty) issue else 'chưa ghi lỗi',
        if (name.isNotEmpty) name,
        if (price > 0) fmt(price),
        '($statusStr)',
      ].join(' - ');
      repairSummaries.add(summary);
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
      stockCount: inventory['totalQty'] ?? 0,
      stockCapital: inventory['totalCapital'] ?? 0,
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
      'bill': 'hoa don ban',
      'invoice': 'hoa don ban',
      'receipt': 'hoa don ban',
      'moi nhat': 'gan nhat',
      'gan day': 'gan nhat',
      'ban gan': 'don ban gan nhat',
      'ban moi': 'don ban gan nhat',
      'xem ban': 'don ban gan nhat',
      'sua gan': 'don sua gan nhat',
      'sua moi': 'don sua gan nhat',
      'xem sua': 'don sua gan nhat',
      'no ai': 'ai no nhieu nhat',
      'no ncc': 'tra no ncc',
      'nha cung cap': 'ncc',
      'supplier': 'ncc',
      'inventory': 'ton kho',
      'stock': 'ton kho',
      'revenue': 'doanh thu',
      'profit': 'loi nhuan',
      'linh phu': 'linh kien',
      'phu tung': 'linh kien',
    };
    String result = normalized;
    for (final e in synonyms.entries) {
      result = result.replaceAll(e.key, e.value);
    }
    return result;
  }

  AiQuickResponse? quickAnswer(String question, AiChatStats stats, {String? lastIntent}) {
    final raw = VietnameseUtils.normalize(question.toLowerCase());
    final n = _expandSynonyms(raw);

    // Tạo đơn bán → switch to sales tab
    if (_has(n, ['tao don ban', 'them don ban', 'ban hang moi'])) {
      return const AiQuickResponse(
        'Chuyển sang màn hình **Bán hàng** để tạo đơn bán mới:',
        actions: [_kOpenSalesTabAction],
      );
    }

    // Tạo đơn sửa → switch to repairs tab
    if (_has(n, ['tao don sua', 'them don sua', 'tiep nhan sua'])) {
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
      buf.writeln('• Đơn sửa chờ xử lý: **${stats.repairsPending} đơn**');
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
      return AiQuickResponse(buf.toString(), actions: const [_kViewDebtsAction]);
    }

    // Năm nay
    if (_has(n, ['nam nay', 'doanh thu nam', 'thong ke nam', 'nam ${DateTime.now().year}'])) {
      final buf = StringBuffer('**Năm ${DateTime.now().year}:**\n');
      buf.writeln('• Bán hàng: **${stats.salesThisYear} đơn** — ${fmt(stats.saleRevenueThisYear)}');
      buf.writeln('• Sửa chữa đã giao: **${stats.repairsThisYear} đơn** — ${fmt(stats.repairRevenueThisYear)}');
      buf.writeln('• Tổng doanh thu: **${fmt(stats.revenueThisYear)}**');
      buf.write('• Lợi nhuận: **${fmt(stats.profitThisYear)}**');
      return AiQuickResponse(buf.toString());
    }

    // Tháng này (chi tiết)
    if (_has(n, ['thang nay', 'doanh thu thang', 'ban hang thang', 'sua chua thang']) &&
        !_has(n, ['nam nay'])) {
      final buf = StringBuffer('**Tháng ${DateTime.now().month}/${DateTime.now().year}:**\n');
      buf.writeln('• Bán hàng: **${stats.salesThisMonth} đơn** — ${fmt(stats.saleRevenueThisMonth)}');
      buf.writeln('• Sửa chữa đã giao: **${stats.repairsThisMonth} đơn** — ${fmt(stats.repairRevenueThisMonth)}');
      buf.writeln('• Tổng doanh thu: **${fmt(stats.revenueThisMonth)}**');
      buf.write('• Lợi nhuận: **${fmt(stats.profitThisMonth)}**');
      return AiQuickResponse(buf.toString());
    }

    // Bán hàng hôm nay
    if (_has(n, ['ban hang hom nay', 'don ban hom nay', 'so don ban hom nay'])) {
      if (stats.salesToday == 0) {
        return const AiQuickResponse('Hôm nay chưa có đơn bán nào.', actions: [_kOpenLatestSaleAction]);
      }
      return AiQuickResponse(
        'Hôm nay bán **${stats.salesToday} đơn**, doanh thu **${fmt(stats.saleRevenueToday)}**.',
        actions: const [_kOpenLatestSaleAction],
      );
    }

    // Sửa chữa hôm nay
    if (_has(n, ['sua chua hom nay', 'don sua hom nay', 'so don sua hom nay'])) {
      return AiQuickResponse(
        'Hôm nay nhận **${stats.repairsToday} đơn sửa**. '
        'Đã giao: **${stats.deliveredRepairsToday}**, đang chờ: **${stats.repairsPending}**. '
        'Doanh thu sửa chữa: **${fmt(stats.repairRevenueToday)}**.',
        actions: const [_kOpenLatestRepairAction],
      );
    }

    // Doanh thu hôm nay
    if (_has(n, ['doanh thu', 'ban duoc', 'thu duoc', 'ban hang']) &&
        !_has(n, ['gom', 'nhung', 'nao', 'chi tiet', 'danh sach', 'thang', 'nam'])) {
      final buf = StringBuffer();
      buf.write('Bán hàng: **${stats.salesToday} đơn** (${fmt(stats.saleRevenueToday)}). ');
      if (stats.deliveredRepairsToday > 0) {
        buf.write('Sửa chữa giao: **${stats.deliveredRepairsToday} đơn** (${fmt(stats.repairRevenueToday)}). ');
      }
      buf.write('Tổng doanh thu: **${fmt(stats.revenueToday)}**, lợi nhuận: **${fmt(stats.profitToday)}**.');
      return AiQuickResponse(buf.toString());
    }

    // Tồn kho hàng hoá
    if (_has(n, ['ton kho', 'hang con', 'kiem kho', 'so luong hang']) &&
        !_has(n, ['linh kien', 'phu kien'])) {
      return AiQuickResponse(
        'Tồn kho hiện tại: **${stats.stockCount} sản phẩm**, '
        'giá vốn **${fmt(stats.stockCapital)}**.',
        actions: const [_kViewStockAction],
      );
    }

    // Kho linh kiện / phụ kiện
    if (_has(n, ['linh kien', 'phu kien', 'kho linh', 'linh phu kien'])) {
      return AiQuickResponse(
        'Kho linh kiện & phụ kiện: **${stats.stockCount} mặt hàng** '
        '(giá vốn **${fmt(stats.stockCapital)}**).',
        actions: const [_kViewStockAction],
      );
    }

    // Đơn bán gần nhất
    if (_has(n, ['don ban gan nhat', 'hoa don ban gan', 'don ban moi nhat',
                  'mo don ban', 'xem don ban'])) {
      return const AiQuickResponse(
        'Mở hóa đơn bán hàng gần nhất:',
        actions: [_kOpenLatestSaleAction],
      );
    }

    // Đơn sửa gần nhất
    if (_has(n, ['don sua gan nhat', 'don sua moi nhat', 'mo don sua',
                  'xem don sua gan nhat'])) {
      return const AiQuickResponse(
        'Mở đơn sửa chữa gần nhất:',
        actions: [_kOpenLatestRepairAction],
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
          'đang chờ: **${stats.repairsPending} đơn**.');
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
      );
    }

    // Trả nợ NCC / nhà cung cấp
    if (_has(n, ['tra no ncc', 'tra no nha cung cap', 'no ncc',
                  'cong no ncc', 'nha cung cap'])) {
      final buf = StringBuffer(
          'Công nợ phải trả NCC: **${fmt(stats.debtPayable)}**.');
      if (stats.debtPayable == 0) {
        return const AiQuickResponse('Shop hiện không có nợ nhà cung cấp nào đang chờ.');
      }
      buf.write('\nVào mục Nhà cung cấp để ghi thanh toán.');
      return AiQuickResponse(
        buf.toString(),
        actions: const [_kViewDebtPayableAction],
      );
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
      );
    }

    // Lợi nhuận
    if (_has(n, ['loi nhuan', 'lai bao nhieu', 'loi bao nhieu'])) {
      return AiQuickResponse(
        'Lợi nhuận hôm nay: **${fmt(stats.profitToday)}** '
        '(bán hàng + sửa chữa đã giao).',
      );
    }

    // Chào hỏi
    if (_has(n, ['xin chao', 'hello', 'chao ban', 'chao ai', 'ban la ai'])) {
      return const AiQuickResponse(
        'Xin chào! Em là **AI Trợ Lý** của shop.\n'
        'Anh có thể hỏi em về:\n'
        '• Doanh thu / lợi nhuận hôm nay, tháng này\n'
        '• Tồn kho, kho linh kiện\n'
        '• Công nợ phải thu / phải trả NCC\n'
        '• Đơn sửa đang chờ, đơn bán gần nhất',
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
    final n = _expandSynonyms(raw);
    final words = n.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordCount = words.length;

    // Only fire for short (≤ 3 words) inputs — longer ones are likely specific
    if (wordCount > 3) return null;

    // Guard: already contains a specific qualifier → quickAnswer or cloud handles it
    if (_has(n, [
      'hom nay', 'thang nay', 'nam nay', 'gan nhat', 'moi nhat',
      'tao', 'them', 'mo', 'kiem tra', 'bao nhieu', 'danh sach',
      'tong', 'chi tiet', 'nhieu nhat', 'it nhat', 'sap het',
      'dang cho', 'dang sua', 'da giao', 'chua tra',
    ])) { return null; }

    // ── Domain: bán hàng ──
    if (_has(n, ['ban']) &&
        !_has(n, ['tra no', 'ncc', 'linh kien', 'phu kien', 'san pham'])) {
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
    if (_has(n, ['sua']) && !_has(n, ['nha', 'may sua', 'sach'])) {
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
    if (_has(n, ['kho']) && !_has(n, ['nhap kho', 'xuat kho', 'lich su'])) {
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
    if (_has(n, ['no', 'cong no']) &&
        !_has(n, ['ngoai no', 'tro no', 'nhap no', 'ton kho'])) {
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
    if (_has(n, ['tai chinh', 'thong ke', 'bao cao', 'doanh thu'])) {
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
    const brands = ['iphone', 'samsung', 'xiaomi', 'oppo', 'vivo', 'realme', 'nokia', 'huawei'];
    for (final brand in brands) {
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

  // ── Cloud AI ──────────────────────────────────────────────────────────────

  Future<(String?, String?)> askAI(
    String question,
    AiChatStats stats,
    List<Map<String, String>> history,
  ) async {
    try {
      final callable = _fn.httpsCallable(
        'chatAssistant',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final res = await callable.call({
        'question': question,
        'stats': stats.toJson(),
        'history': history.take(10).toList(),
      });
      final data = res.data as Map<Object?, Object?>;
      final answer = data['answer'] as String?;
      if (answer == null || answer.isEmpty) {
        return (null, 'Em chưa trả lời được. Anh thử hỏi lại nhé.');
      }
      return (answer, null);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        return (null, 'Đã đạt giới hạn câu hỏi AI trong phút này. Thử lại sau nhé.');
      }
      if (e.code == 'unauthenticated') {
        return (null, 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
      }
      return (null, 'Em chưa hiểu câu hỏi này. Anh thử hỏi về: doanh thu, tồn kho, đơn sửa, công nợ...');
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
}
