// Logic thuần (không Flutter) — model, DB, export đều dùng được.

/// Bảo hành trong app là MỘT DÒNG GHI CHÚ (`repairs.warranty`,
/// `sales.warranty` — String), không phải model riêng. File này gom mọi thứ
/// liên quan tới dòng chữ đó về một chỗ:
///
/// - [WarrantyNote.none] / [WarrantyNote.presets]: giá trị chuẩn để mọi màn
///   ghi giống nhau (trước đây đơn sửa mặc định "Không bảo hành", đơn bán
///   "KO BH", dialog giao máy thì "1 tháng" chữ thường — cùng một nghĩa mà 3
///   cách viết, truy vấn lọc `!= 'KO BH'` bị lọt).
/// - [WarrantyNote.parseDuration]: rút số tháng/ngày ra khỏi ghi chú tự do
///   ("BH màn 3 tháng, pin 6 tháng" → 3 tháng — lấy mốc ĐẦU TIÊN) để màn Tra
///   cứu bảo hành tự tính hạn. Không có số ⇒ null ⇒ chỉ là ghi chú, không
///   tính hạn.
/// - [WarrantyNoteField]: chip chọn nhanh + ô gõ tự do, dùng chung cho đơn
///   sửa (giao máy / duyệt giao / sửa đơn) và đơn bán.
class WarrantyNote {
  WarrantyNote._();

  static const String none = 'KO BH';
  static const List<String> presets = [
    none,
    '1 THÁNG',
    '3 THÁNG',
    '6 THÁNG',
    '12 THÁNG',
  ];

  /// Chuẩn hoá giá trị đọc từ dữ liệu cũ về dạng hiển thị thống nhất.
  static String normalize(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return none;
    final upper = v.toUpperCase();
    if (upper == 'KO BH' ||
        upper == 'KHÔNG BẢO HÀNH' ||
        upper == 'KHONG BAO HANH' ||
        upper == 'KHÔNG BH' ||
        upper == 'NO WARRANTY') {
      return none;
    }
    return v;
  }

  /// Có phải "không bảo hành" (hoặc rỗng) không.
  static bool isNone(String? raw) => normalize(raw) == none;

  /// Thời hạn rút ra từ ghi chú, hoặc null nếu ghi chú không nêu con số.
  /// Hỗ trợ: `3 tháng` / `3th` / `3t`, `1 năm` / `1n`, `15 ngày` / `15ng`,
  /// `2 tuần`. Lấy mốc ĐẦU TIÊN xuất hiện trong chuỗi.
  static Duration? parseDuration(String? raw) {
    if (raw == null || isNone(raw)) return null;
    final lower = raw.toLowerCase();
    final m = RegExp(
      r'(\d+)\s*(tháng|thang|th|t|năm|nam|n|ngày|ngay|ng|tuần|tuan)\b',
    ).firstMatch(lower);
    if (m == null) return null;
    final n = int.tryParse(m.group(1)!) ?? 0;
    if (n <= 0) return null;
    switch (m.group(2)) {
      case 'tháng':
      case 'thang':
      case 'th':
      case 't':
        return Duration(days: n * 30);
      case 'năm':
      case 'nam':
      case 'n':
        return Duration(days: n * 365);
      case 'tuần':
      case 'tuan':
        return Duration(days: n * 7);
      default:
        return Duration(days: n);
    }
  }

  /// Số tháng rút ra từ ghi chú (0 nếu không nêu). Dùng cho phép cộng theo
  /// lịch `DateTime(y, m + months, d)` ở màn Tra cứu.
  static int parseMonths(String? raw) {
    if (raw == null || isNone(raw)) return 0;
    final m = RegExp(
      r'(\d+)\s*(tháng|thang|th|t)\b',
    ).firstMatch(raw.toLowerCase());
    if (m != null) return int.tryParse(m.group(1)!) ?? 0;
    final y = RegExp(r'(\d+)\s*(năm|nam|n)\b').firstMatch(raw.toLowerCase());
    if (y != null) return (int.tryParse(y.group(1)!) ?? 0) * 12;
    return 0;
  }

  /// Ngày hết hạn tính từ [startMs], hoặc null nếu ghi chú không có thời hạn.
  static DateTime? expiryFrom(int startMs, String? raw) {
    if (isNone(raw)) return null;
    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    final months = parseMonths(raw);
    if (months > 0) return DateTime(start.year, start.month + months, start.day);
    final d = parseDuration(raw);
    if (d == null) return null;
    return start.add(d);
  }
}
