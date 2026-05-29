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

    // ── Stock check ──────────────────────────────────────────────────────────────────
    if (_has(n, [
      'kiem kho', 'ton kho', 'hang ton', 'kiem tra kho', 'xem ton kho',
      'con bao nhieu', 'so luong ton', 'hang con',
      'xem kho', 'kho hien tai', 'kho con gi', 'hang hoa ton', 'hang co san',
      'inventory', 'stock check', 'so luong hang',
    ])) {
      return AiCommandResult(intent: AiCommandIntent.stockCheck, rawText: rawText);
    }

    // ── Stock entry ──────────────────────────────────────────────────────────────────
    if (_has(n, [
      'nhap kho', 'nhap hang', 'nhan hang', 'them kho',
      'hang ve', 'hang moi ve', 'nhap them', 'cap nhat kho',
      'them san pham', 'nhap san pham moi', 'nhap linh kien', 'nhap phu kien',
      'them vao kho', 'bo sung kho',
    ])) {
      final payload = _strip(rawText, [
        'nhập kho', 'nhập hàng', 'nhận hàng', 'thêm kho',
      ]);
      return AiCommandResult(
          intent: AiCommandIntent.stockEntry, rawText: rawText, payload: payload);
    }

    // ── Finance week ─────────────────────────────────────────────────────────────────
    if (_has(n, [
      'tai chinh tuan', 'thu chi tuan', 'doanh thu tuan', 'bao cao tuan',
      'tuan nay', 'tuan truoc',
    ])) {
      return AiCommandResult(intent: AiCommandIntent.viewFinanceWeek, rawText: rawText);
    }

    // ── Finance month ────────────────────────────────────────────────────────────────
    if (_has(n, [
      'tai chinh thang', 'thu chi thang', 'doanh thu thang', 'bao cao thang',
      'thang nay', 'thang truoc',
    ])) {
      return AiCommandResult(intent: AiCommandIntent.viewFinanceMonth, rawText: rawText);
    }

    // ── Finance today ────────────────────────────────────────────────────────────────
    if (_has(n, [
      'tai chinh hom nay', 'thu chi hom nay', 'doanh thu hom nay',
      'tai chinh ngay', 'tai chinh', 'bao cao tai chinh', 'thu chi',
      'hom nay thu', 'doanh so',
      'bao nhieu tien', 'ban duoc bao nhieu', 'thu duoc bao nhieu',
      'ket qua hom nay', 'tong ket hom nay', 'hom nay the nao',
    ])) {
      return AiCommandResult(intent: AiCommandIntent.viewFinanceToday, rawText: rawText);
    }

    // ── Customer ─────────────────────────────────────────────────────────────────────
    if (_has(n, [
      'tim khach', 'khach hang', 'xem khach', 'danh sach khach', 'quan ly khach',
      'tim ten', 'tim so dien thoai', 'khach cu',
      'thong tin khach', 'lich su khach', 'khach nao', 'ten khach',
      'so dien thoai khach', 'tim nguoi',
    ])) {
      return AiCommandResult(intent: AiCommandIntent.findCustomer, rawText: rawText);
    }

    // ── Debt ─────────────────────────────────────────────────────────────────────────
    if (_has(n, [
      'cong no', 'xem no', 'quan ly no',
      'no chua tra', 'khach no', 'thu no', 'no hang',
    ])) {
      return AiCommandResult(intent: AiCommandIntent.viewDebt, rawText: rawText);
    }

    // ── Pending repairs ──────────────────────────────────────────────────────────────
    if (_has(n, [
      'don dang sua', 'chua xong', 'cho sua', 'lich su sua', 'danh sach sua',
      'may chua xong', 'don cho', 'cho lay',
      'dang xu ly', 'may dang sua', 'sua chua dang cho', 'tinh trang sua',
      'don sap xong', 'xem tat ca don sua', 'danh sach may sua',
    ])) {
      return AiCommandResult(intent: AiCommandIntent.viewPendingRepairs, rawText: rawText);
    }

    // ── Attendance out (before "in" to avoid conflict) ───────────────────────────────
    if (_has(n, [
      'cham cong ra', 'check out', 'tan ca', 'ket thuc ca',
      'ra ve', 'nghi lam', 'het ca',
    ])) {
      return AiCommandResult(intent: AiCommandIntent.attendanceOut, rawText: rawText);
    }

    // ── Attendance in ────────────────────────────────────────────────────────────────
    if (_has(n, [
      'cham cong vao', 'cham cong', 'check in', 'bat dau ca', 'di lam',
      'vao lam', 'bat ca', 'den lam',
    ])) {
      return AiCommandResult(intent: AiCommandIntent.attendanceIn, rawText: rawText);
    }

    // ── Sale ─────────────────────────────────────────────────────────────────────────
    if (_has(n, [
      'tao don ban', 'ban hang', 'xuat hang', 'don ban', 'ban may', 'ban dien thoai',
      'thanh toan', 'thu tien', 'xuat may',
      'lap don ban', 'tao hoa don', 'ban san pham', 'ban linh kien',
      'khach mua', 'khach thanh toan', 'xuat hoa don',
    ])) {
      final payload = _strip(rawText, [
        'tạo đơn bán', 'bán hàng', 'xuất hàng', 'đơn bán', 'bán máy', 'bán',
      ]);
      return AiCommandResult(
          intent: AiCommandIntent.createSale, rawText: rawText, payload: payload);
    }

    // ── Repair (broad — checked last) ────────────────────────────────────────────────
    if (_has(n, [
      'tao don sua', 'nhan may', 'sua may', 'don sua', 'khach sua', 'sua chua',
      'sua iphone', 'sua samsung', 'sua oppo', 'sua xiaomi', 'sua vivo',
      'thay man hinh', 'thay pin', 'thay kinh', 'sua main',
      'bao hanh', 'may bi hong', 'may hu',
      'tiep nhan may', 'nhan bao hanh', 'thay vo may', 'thay camera',
      'may bi loi', 'may sap', 'man hinh den', 'man hinh hong',
      'sua realme', 'sua nokia', 'sua huawei', 'sua tecno', 'sua infinix',
    ])) {
      final payload = _strip(rawText, [
        'tạo đơn sửa', 'nhận máy', 'sửa máy', 'đơn sửa', 'sửa chữa', 'sửa',
      ]);
      return AiCommandResult(
          intent: AiCommandIntent.createRepair, rawText: rawText, payload: payload);
    }

    // ── Fallback: text starts with phone brand → repair ──────────────────────────────
    if (RegExp(
      r'^(iphone|samsung|oppo|xiaomi|vivo|realme|nokia|huawei|tecno|infinix|motorola)',
      caseSensitive: false,
    ).hasMatch(rawText.trim())) {
      return AiCommandResult(
          intent: AiCommandIntent.createRepair, rawText: rawText, payload: rawText);
    }

    return AiCommandResult(intent: AiCommandIntent.unknown, rawText: rawText);
  }
}
