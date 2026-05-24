import 'package:cloud_functions/cloud_functions.dart';

import '../data/db_helper.dart';
import '../utils/vietnamese_utils.dart';

// ── Stats snapshot ─────────────────────────────────────────────────────────────

class AiChatStats {
  final int salesToday;
  final int revenueToday;
  final int profitToday;
  final int repairsToday;
  final int repairsPending;
  final int stockCount;
  final int stockCapital;
  final int debtReceivable;
  final int debtPayable;

  // Monthly aggregates
  final int salesThisMonth;
  final int revenueThisMonth;
  final int profitThisMonth;
  final int repairsThisMonth;

  // Detail lists for "gồm những đơn nào" / "ai nợ nhiều nhất"
  final List<String> repairSummaries;
  final List<String> topDebtorLines;

  const AiChatStats({
    this.salesToday = 0,
    this.revenueToday = 0,
    this.profitToday = 0,
    this.repairsToday = 0,
    this.repairsPending = 0,
    this.stockCount = 0,
    this.stockCapital = 0,
    this.debtReceivable = 0,
    this.debtPayable = 0,
    this.salesThisMonth = 0,
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
        'repairsToday': repairsToday,
        'repairsPending': repairsPending,
        'stockCount': stockCount,
        'stockCapital': stockCapital,
        'debtReceivable': debtReceivable,
        'debtPayable': debtPayable,
        'salesThisMonth': salesThisMonth,
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

    // Today range
    final dayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final dayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;

    // Month range
    final monthStart = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final monthEnd = DateTime(now.year, now.month + 1, 1)
        .subtract(const Duration(seconds: 1))
        .millisecondsSinceEpoch;

    final results = await Future.wait([
      db.getSalesByDateRange(dayStart, dayEnd),
      db.getRepairsByCreatedAtRange(dayStart, dayEnd),
      db.getInventorySummary(),
      db.getDebtsForFinanceSnapshot(),
      db.getSalesByDateRange(monthStart, monthEnd),
      db.getRepairsByCreatedAtRange(monthStart, monthEnd),
    ]);

    final sales = results[0] as List;
    final repairs = results[1] as List;
    final inventory = results[2] as Map<String, int>;
    final debts = results[3] as List<Map<String, dynamic>>;
    final salesMonth = results[4] as List;
    final repairsMonth = results[5] as List;

    // Today aggregates
    int revenue = 0, profit = 0;
    for (final s in sales) {
      final fp = s.finalPrice as int? ?? 0;
      final tc = s.totalCost as int? ?? 0;
      revenue += fp;
      profit += fp - tc;
    }

    // Monthly aggregates
    int revenueMonth = 0, profitMonth = 0;
    for (final s in salesMonth) {
      final fp = s.finalPrice as int? ?? 0;
      final tc = s.totalCost as int? ?? 0;
      revenueMonth += fp;
      profitMonth += fp - tc;
    }

    int pending = 0;
    final repairSummaries = <String>[];
    const statusLabel = {1: 'Mới nhận', 2: 'Đang sửa', 3: 'Xong chờ lấy', 4: 'Đã giao'};
    for (final r in repairs) {
      final status = r.status as int? ?? 0;
      if (status < 4) pending++;
      final model = (r.model as String?)?.trim() ?? '';
      final issue = (r.issue as String?)?.trim() ?? '';
      final name = (r.customerName as String?)?.trim() ?? '';
      final statusStr = statusLabel[status] ?? 'Không rõ';
      final summary = [
        if (model.isNotEmpty) model,
        if (issue.isNotEmpty) issue else 'chưa ghi lỗi',
        if (name.isNotEmpty) name,
        '($statusStr)',
      ].join(' - ');
      repairSummaries.add(summary);
    }

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
      revenueToday: revenue,
      profitToday: profit,
      repairsToday: repairs.length,
      repairsPending: pending,
      stockCount: inventory['totalQty'] ?? 0,
      stockCapital: inventory['totalCapital'] ?? 0,
      debtReceivable: debtReceivable,
      debtPayable: debtPayable,
      salesThisMonth: salesMonth.length,
      revenueThisMonth: revenueMonth,
      profitThisMonth: profitMonth,
      repairsThisMonth: repairsMonth.length,
      repairSummaries: repairSummaries.take(20).toList(),
      topDebtorLines: topDebtorLines,
    );
  }

  // ── Fast local answers ────────────────────────────────────────────────────

  String? quickAnswer(String question, AiChatStats stats) {
    final n = VietnameseUtils.normalize(question.toLowerCase());

    // Tổng hợp tài chính (ưu tiên check trước vì overlap keywords)
    if (_has(n, ['tai chinh', 'tong hop', 'tom tat', 'bao cao', 'tong ket'])) {
      final buf = StringBuffer();
      buf.writeln('**Tóm tắt tài chính hôm nay:**');
      buf.writeln('• Doanh thu: **${fmt(stats.revenueToday)}** (${stats.salesToday} đơn)');
      buf.writeln('• Lợi nhuận: **${fmt(stats.profitToday)}**');
      buf.writeln('• Đơn sửa: **${stats.repairsToday}** mới, **${stats.repairsPending}** chưa giao');
      buf.writeln();
      buf.writeln('**Tháng này:**');
      buf.writeln('• Doanh thu: **${fmt(stats.revenueThisMonth)}** (${stats.salesThisMonth} đơn)');
      buf.writeln('• Lợi nhuận: **${fmt(stats.profitThisMonth)}**');
      buf.writeln('• Đơn sửa: **${stats.repairsThisMonth}** đơn');
      buf.writeln();
      buf.write('• Công nợ phải thu: **${fmt(stats.debtReceivable)}**');
      buf.write(' | Phải trả: **${fmt(stats.debtPayable)}**');
      return buf.toString();
    }

    // Tháng này
    if (_has(n, ['thang nay', 'thang nay the nao', 'thang', 'doanh thu thang'])) {
      return 'Tháng này bán được **${stats.salesThisMonth} đơn**, '
          'doanh thu **${fmt(stats.revenueThisMonth)}**, '
          'lợi nhuận **${fmt(stats.profitThisMonth)}**. '
          'Đơn sửa chữa: **${stats.repairsThisMonth} đơn**.';
    }

    // Doanh thu hôm nay
    if (_has(n, ['doanh thu', 'ban duoc', 'thu duoc', 'ban hang']) &&
        !_has(n, ['gom', 'nhung', 'nao', 'chi tiet', 'danh sach', 'thang'])) {
      return 'Hôm nay bán được **${stats.salesToday} đơn**, '
          'doanh thu **${fmt(stats.revenueToday)}**, '
          'lợi nhuận **${fmt(stats.profitToday)}**.';
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
          'Hôm nay nhận **${stats.repairsToday} đơn sửa** mới.\n'
          'Đang sửa chưa giao: **${stats.repairsPending} đơn**.');
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
    if (_has(n, ['ai no nhieu nhat', 'no ai nhieu', 'top no', 'ai no nhieu',
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
      return 'Lợi nhuận hôm nay: **${fmt(stats.profitToday)}**.';
    }

    // Chào hỏi
    if (_has(n, ['xin chao', 'hello', 'chao ban', 'chao ai', 'ban la ai'])) {
      return 'Xin chào! Tôi là **AI Trợ Lý** của shop. Bạn có thể hỏi tôi:\n'
          '• Doanh thu / lợi nhuận hôm nay hoặc tháng này\n'
          '• Tổng hợp tài chính\n'
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
