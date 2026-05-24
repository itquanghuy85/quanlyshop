import 'package:cloud_functions/cloud_functions.dart';

import '../data/db_helper.dart';
import '../utils/vietnamese_utils.dart';

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

    final results = await Future.wait([
      db.getSalesByDateRange(dayStart, dayEnd),                    // [0] sales hôm nay
      db.getRepairsByCreatedAtRange(dayStart, dayEnd),             // [1] tất cả đơn sửa hôm nay (để đếm + list)
      db.getInventorySummary(),                                     // [2] tồn kho
      db.getDebtsForFinanceSnapshot(),                             // [3] công nợ
      db.getSalesByDateRange(monthStart, monthEnd),                 // [4] sales tháng
      db.getRepairsByCreatedAtRange(monthStart, monthEnd),         // [5] đơn sửa tháng (đếm)
      db.getDeliveredRepairsByDateRange(dayStart, dayEnd),         // [6] đơn sửa ĐÃ GIAO hôm nay (tính doanh thu)
      db.getDeliveredRepairsByDateRange(monthStart, monthEnd),     // [7] đơn sửa ĐÃ GIAO tháng
    ]);

    final sales = results[0] as List;
    final repairs = results[1] as List;           // tất cả đơn sửa (mọi trạng thái)
    final inventory = results[2] as Map<String, int>;
    final debts = results[3] as List<Map<String, dynamic>>;
    final salesMonth = results[4] as List;
    final repairsMonth = results[5] as List;      // tất cả đơn sửa tháng
    final deliveredRepairs = results[6] as List;  // đơn sửa đã giao hôm nay
    final deliveredRepairsMonth = results[7] as List; // đã giao tháng

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

    // ── Công nợ ──
    int debtReceivable = 0, debtPayable = 0;
    final debtorMap = <String, int>{};
    for (final d in debts) {
      final total = d['totalAmount'] as int? ?? 0;
      final paid = d['paidAmount'] as int? ?? 0;
      final remaining = total - paid;
      if (remaining <= 0) continue;
      final type = (d['type'] as String? ?? '').toUpperCase();
      final debtType = (d['debtType'] as String? ?? '').toUpperCase();
      if (type == 'RECEIVABLE' ||
          debtType == 'PHAI_THU' ||
          type.contains('THU')) {
        debtReceivable += remaining;
        final name = (d['personName'] as String?)?.trim() ?? 'Không rõ';
        debtorMap[name] = (debtorMap[name] ?? 0) + remaining;
      } else {
        debtPayable += remaining;
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
      repairSummaries: repairSummaries.take(20).toList(),
      topDebtorLines: topDebtorLines,
    );
  }

  // ── Fast local answers ────────────────────────────────────────────────────

  String? quickAnswer(String question, AiChatStats stats) {
    final n = VietnameseUtils.normalize(question.toLowerCase());

    // Tổng hợp tài chính
    if (_has(n, ['tai chinh', 'tong hop', 'tom tat', 'bao cao', 'tong ket'])) {
      final buf = StringBuffer();
      buf.writeln('**Tóm tắt tài chính hôm nay:**');
      if (stats.salesToday > 0) {
        buf.writeln('• Bán hàng: **${stats.salesToday} đơn** — ${fmt(stats.saleRevenueToday)}');
      }
      if (stats.deliveredRepairsToday > 0) {
        buf.writeln('• Sửa chữa đã giao: **${stats.deliveredRepairsToday} đơn** — ${fmt(stats.repairRevenueToday)}');
      }
      buf.writeln('• Tổng doanh thu: **${fmt(stats.revenueToday)}**');
      buf.writeln('• Lợi nhuận: **${fmt(stats.profitToday)}**');
      buf.writeln('• Đơn sửa đang chờ: **${stats.repairsPending} đơn**');
      buf.writeln();
      buf.writeln('**Tháng này:**');
      buf.writeln('• Bán hàng: ${stats.salesThisMonth} đơn (${fmt(stats.saleRevenueThisMonth)})');
      buf.writeln('• Sửa chữa: ${stats.repairsThisMonth} đơn (${fmt(stats.repairRevenueThisMonth)})');
      buf.writeln('• Tổng doanh thu: **${fmt(stats.revenueThisMonth)}** | Lợi nhuận: **${fmt(stats.profitThisMonth)}**');
      buf.writeln();
      buf.write('• Công nợ phải thu: **${fmt(stats.debtReceivable)}**');
      buf.write(' | Phải trả: **${fmt(stats.debtPayable)}**');
      return buf.toString();
    }

    // Tháng này
    if (_has(n, ['thang nay', 'doanh thu thang']) &&
        !_has(n, ['gom', 'chi tiet', 'danh sach'])) {
      return 'Tháng này: bán hàng **${stats.salesThisMonth} đơn** (${fmt(stats.saleRevenueThisMonth)}), '
          'sửa chữa giao **${fmt(stats.repairRevenueThisMonth)}**. '
          'Tổng doanh thu **${fmt(stats.revenueThisMonth)}**, '
          'lợi nhuận **${fmt(stats.profitThisMonth)}**.';
    }

    // Doanh thu hôm nay
    if (_has(n, ['doanh thu', 'ban duoc', 'thu duoc', 'ban hang']) &&
        !_has(n, ['gom', 'nhung', 'nao', 'chi tiet', 'danh sach', 'thang'])) {
      final buf = StringBuffer();
      if (stats.saleRevenueToday > 0 || stats.salesToday > 0) {
        buf.write('Bán hàng: **${stats.salesToday} đơn** (${fmt(stats.saleRevenueToday)}). ');
      }
      if (stats.repairRevenueToday > 0 || stats.deliveredRepairsToday > 0) {
        buf.write('Sửa chữa giao: **${stats.deliveredRepairsToday} đơn** (${fmt(stats.repairRevenueToday)}). ');
      }
      buf.write('Tổng doanh thu: **${fmt(stats.revenueToday)}**, lợi nhuận: **${fmt(stats.profitToday)}**.');
      return buf.toString();
    }

    // Tồn kho
    if (_has(n, ['ton kho', 'hang con', 'kiem kho', 'so luong hang'])) {
      return 'Tồn kho hiện tại: **${stats.stockCount} sản phẩm**, '
          'giá vốn **${fmt(stats.stockCapital)}**.';
    }

    // Đơn sửa danh sách chi tiết
    if (_has(n, ['gom nhung don', 'don nao', 'nhung don', 'don hom nay',
                  'danh sach don', 'co nhung don gi'])) {
      if (stats.repairSummaries.isEmpty) {
        return 'Hôm nay chưa có đơn sửa nào.';
      }
      final lines = stats.repairSummaries
          .asMap()
          .entries
          .map((e) => '${e.key + 1}. ${e.value}')
          .join('\n');
      return 'Đơn sửa hôm nay (${stats.repairsToday} đơn):\n$lines';
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
      return answer.toString();
    }

    // Ai nợ nhiều nhất
    if (_has(n, ['ai no nhieu nhat', 'no ai nhieu', 'top no',
                  'no nhieu nhat', 'ai no tien nhieu'])) {
      if (stats.topDebtorLines.isEmpty) {
        return 'Hiện không có công nợ phải thu nào.';
      }
      return 'Top khách nợ nhiều nhất:\n'
          '${stats.topDebtorLines.map((l) => '• $l').join('\n')}';
    }

    // Công nợ tổng
    if (_has(n, ['cong no', 'khach no', 'thu no', 'no chua tra'])) {
      final answer = StringBuffer(
          'Công nợ phải thu: **${fmt(stats.debtReceivable)}**\n'
          'Công nợ phải trả: **${fmt(stats.debtPayable)}**.');
      if (stats.topDebtorLines.isNotEmpty) {
        answer.write(
            '\n\nTop khách nợ:\n'
            '${stats.topDebtorLines.take(3).map((l) => '• $l').join('\n')}');
      }
      return answer.toString();
    }

    // Lợi nhuận
    if (_has(n, ['loi nhuan', 'lai bao nhieu', 'loi bao nhieu'])) {
      return 'Lợi nhuận hôm nay: **${fmt(stats.profitToday)}** '
          '(bán hàng + sửa chữa đã giao).';
    }

    // Chào hỏi
    if (_has(n, ['xin chao', 'hello', 'chao ban', 'chao ai', 'ban la ai'])) {
      return 'Xin chào! Tôi là **AI Trợ Lý** của shop. Bạn có thể hỏi tôi:\n'
          '• Doanh thu hôm nay (bán hàng + sửa chữa đã giao)\n'
          '• Tổng hợp tài chính / tháng này\n'
          '• Tồn kho hiện tại\n'
          '• Công nợ & ai nợ nhiều nhất\n'
          '• Đơn sửa đang chờ\n'
          '• Bất kỳ câu hỏi nào về shop!';
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
        return (null, 'AI không trả lời được. Hãy thử lại sau.');
      }
      return (answer, null);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        return (null, 'Đã đạt giới hạn câu hỏi AI. Thử lại sau 1 phút.');
      }
      if (e.code == 'unauthenticated') {
        return (null, 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
      }
      return (null, 'AI hiện không trả lời được câu hỏi này. Thử hỏi cách khác hoặc dùng chip gợi ý.');
    } catch (_) {
      return (null, 'Mất kết nối mạng. Kiểm tra internet và thử lại.');
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
