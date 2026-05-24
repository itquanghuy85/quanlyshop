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
    final start =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59)
        .millisecondsSinceEpoch;

    final results = await Future.wait([
      db.getSalesByDateRange(start, end),
      db.getRepairsByCreatedAtRange(start, end),
      db.getInventorySummary(),
      db.getDebtsForFinanceSnapshot(),
    ]);

    final sales = results[0] as List;
    final repairs = results[1] as List;
    final inventory = results[2] as Map<String, int>;
    final debts = results[3] as List<Map<String, dynamic>>;

    int revenue = 0, profit = 0;
    for (final s in sales) {
      final fp = s.finalPrice as int? ?? 0;
      final tc = s.totalCost as int? ?? 0;
      revenue += fp;
      profit += fp - tc;
    }

    int pending = 0;
    for (final r in repairs) {
      if ((r.status as int? ?? 0) < 4) pending++;
    }

    int debtReceivable = 0, debtPayable = 0;
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
      } else {
        debtPayable += remaining;
      }
    }

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
    );
  }

  // ── Fast local answers ────────────────────────────────────────────────────

  /// Returns a ready-made answer for simple stat queries, or null if the
  /// question requires cloud AI.
  String? quickAnswer(String question, AiChatStats stats) {
    final n = VietnameseUtils.normalize(question.toLowerCase());

    if (_has(n, ['doanh thu', 'ban duoc', 'thu duoc', 'ban hang'])) {
      return 'Hôm nay bán được **${stats.salesToday} đơn**, doanh thu **${_fmt(stats.revenueToday)}**, lợi nhuận **${_fmt(stats.profitToday)}**.';
    }
    if (_has(n, ['ton kho', 'hang con', 'kiem kho', 'so luong hang'])) {
      return 'Tồn kho hiện tại: **${stats.stockCount} sản phẩm**, giá vốn **${_fmt(stats.stockCapital)}**.';
    }
    if (_has(n, ['cong no', 'no', 'khach no', 'thu no'])) {
      return 'Công nợ phải thu: **${_fmt(stats.debtReceivable)}**\n'
          'Công nợ phải trả: **${_fmt(stats.debtPayable)}**.';
    }
    if (_has(n, ['don sua', 'sua may', 'sua chua', 'dang sua', 'cho lay'])) {
      return 'Hôm nay nhận **${stats.repairsToday} đơn sửa** mới.\n'
          'Đang sửa chưa giao: **${stats.repairsPending} đơn**.';
    }
    if (_has(n, ['loi nhuan', 'lai', 'profit'])) {
      return 'Lợi nhuận hôm nay: **${_fmt(stats.profitToday)}**.';
    }
    if (_has(n, ['xin chao', 'hello', 'hi', 'chao'])) {
      return 'Chào bạn! Tôi là AI Trợ Lý của shop. Bạn có thể hỏi tôi về:\n'
          '• Doanh thu / lợi nhuận hôm nay\n'
          '• Tồn kho hiện tại\n'
          '• Công nợ khách hàng\n'
          '• Đơn sửa đang chờ\n'
          '• Hoặc bất kỳ câu hỏi nào về shop!';
    }
    return null;
  }

  bool _has(String n, List<String> keywords) =>
      keywords.any((k) => n.contains(VietnameseUtils.normalize(k)));

  // ── Cloud AI ──────────────────────────────────────────────────────────────

  /// Returns (answer, errorMessage).
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
        return (null, 'AI không trả lời. Hãy thử lại.');
      }
      return (answer, null);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        return (null, 'Đã đạt giới hạn AI hôm nay. Thử lại sau.');
      }
      return (null, 'Lỗi AI: ${e.message}');
    } catch (_) {
      return (null, 'Không kết nối được AI. Kiểm tra mạng và thử lại.');
    }
  }

  // ── Format helpers ────────────────────────────────────────────────────────

  static String _fmt(int amount) {
    if (amount == 0) return '0đ';
    if (amount >= 1000000) {
      final m = amount / 1000000;
      final s = m % 1 == 0 ? '${m.toInt()}' : m.toStringAsFixed(1);
      return '${s}tr';
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
