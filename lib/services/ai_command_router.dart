import '../models/ai_command_result.dart';
import '../utils/vietnamese_utils.dart';

/// Pure intent-detection service — no side effects, no BuildContext.
/// Navigation is handled by [AiCommandBar] after receiving the result.
class AiCommandRouterService {
  AiCommandRouterService._();

  static String _n(String text) => VietnameseUtils.normalize(text.trim());

  static bool _has(String norm, List<String> keywords) =>
      keywords.any((kw) => norm.contains(_n(kw)));

  /// Strips the leading intent keyword from [raw] and returns the remainder,
  /// or null if nothing meaningful is left.
  static String? _strip(String raw, List<String> prefixes) {
    final lower = raw.toLowerCase().trim();
    for (final p in prefixes) {
      if (lower.startsWith(p.toLowerCase())) {
        final rest = raw.substring(p.length).trim();
        return rest.isEmpty ? null : rest;
      }
    }
    return null;
  }

  /// Detect [AiCommandIntent] from free-form Vietnamese voice/text.
  static AiCommandResult detect(String rawText) {
    final n = _n(rawText);

    // ── Stock check (before stock entry to avoid "nhập kho" → stockEntry conflict) ──
    if (_has(n, ['kiem kho', 'ton kho', 'hang ton', 'kiem tra kho', 'xem ton kho'])) {
      return AiCommandResult(intent: AiCommandIntent.stockCheck, rawText: rawText);
    }

    // ── Stock entry ─────────────────────────────────────────────────────────────────
    if (_has(n, ['nhap kho', 'nhap hang', 'nhan hang', 'them kho'])) {
      final payload = _strip(rawText, [
        'nhập kho', 'nhập hàng', 'nhận hàng', 'thêm kho',
      ]);
      return AiCommandResult(
          intent: AiCommandIntent.stockEntry, rawText: rawText, payload: payload);
    }

    // ── Finance ──────────────────────────────────────────────────────────────────────
    if (_has(n, ['tai chinh tuan', 'thu chi tuan', 'doanh thu tuan', 'bao cao tuan'])) {
      return AiCommandResult(intent: AiCommandIntent.viewFinanceWeek, rawText: rawText);
    }
    if (_has(n, ['tai chinh thang', 'thu chi thang', 'doanh thu thang', 'bao cao thang'])) {
      return AiCommandResult(intent: AiCommandIntent.viewFinanceMonth, rawText: rawText);
    }
    if (_has(n, [
      'tai chinh hom nay', 'thu chi hom nay', 'doanh thu hom nay',
      'tai chinh ngay', 'tai chinh', 'bao cao tai chinh', 'thu chi',
    ])) {
      return AiCommandResult(intent: AiCommandIntent.viewFinanceToday, rawText: rawText);
    }

    // ── Customer ─────────────────────────────────────────────────────────────────────
    if (_has(n, ['tim khach', 'khach hang', 'xem khach', 'danh sach khach', 'quan ly khach'])) {
      return AiCommandResult(intent: AiCommandIntent.findCustomer, rawText: rawText);
    }

    // ── Debt ─────────────────────────────────────────────────────────────────────────
    if (_has(n, ['cong no', 'xem no', 'quan ly no'])) {
      return AiCommandResult(intent: AiCommandIntent.viewDebt, rawText: rawText);
    }

    // ── Pending repairs ──────────────────────────────────────────────────────────────
    if (_has(n, ['don dang sua', 'chua xong', 'cho sua', 'lich su sua', 'danh sach sua'])) {
      return AiCommandResult(intent: AiCommandIntent.viewPendingRepairs, rawText: rawText);
    }

    // ── Attendance ───────────────────────────────────────────────────────────────────
    if (_has(n, ['cham cong ra', 'check out', 'tan ca', 'ket thuc ca'])) {
      return AiCommandResult(intent: AiCommandIntent.attendanceOut, rawText: rawText);
    }
    if (_has(n, ['cham cong vao', 'cham cong', 'check in', 'bat dau ca', 'di lam'])) {
      return AiCommandResult(intent: AiCommandIntent.attendanceIn, rawText: rawText);
    }

    // ── Sale ─────────────────────────────────────────────────────────────────────────
    if (_has(n, ['tao don ban', 'ban hang', 'xuat hang', 'don ban', 'ban may', 'ban dien thoai'])) {
      final payload = _strip(rawText, [
        'tạo đơn bán', 'bán hàng', 'xuất hàng', 'đơn bán', 'bán máy', 'bán',
      ]);
      return AiCommandResult(
          intent: AiCommandIntent.createSale, rawText: rawText, payload: payload);
    }

    // ── Repair (broad — checked last) ────────────────────────────────────────────────
    if (_has(n, ['tao don sua', 'nhan may', 'sua may', 'don sua', 'khach sua', 'sua chua', 'sua iphone', 'sua samsung'])) {
      final payload = _strip(rawText, [
        'tạo đơn sửa', 'nhận máy', 'sửa máy', 'đơn sửa', 'sửa chữa', 'sửa',
      ]);
      return AiCommandResult(
          intent: AiCommandIntent.createRepair, rawText: rawText, payload: payload);
    }

    // ── Fallback: if text starts with a phone model name, treat as repair ────────────
    if (RegExp(r'^(iphone|samsung|oppo|xiaomi|vivo|realme|nokia|huawei)', caseSensitive: false)
        .hasMatch(rawText.trim())) {
      return AiCommandResult(
          intent: AiCommandIntent.createRepair, rawText: rawText, payload: rawText);
    }

    return AiCommandResult(intent: AiCommandIntent.unknown, rawText: rawText);
  }
}
