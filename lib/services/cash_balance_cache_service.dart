import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';

/// Cache "Còn lại" (tiền mặt + ngân hàng CỘNG GỘP) dùng RIÊNG để chèn vào
/// nội dung thông báo tài chính — KHÔNG phải nguồn số liệu kế toán chính
/// thức (số chính thức vẫn do `DailyFinancialAnalysisService` tính ở tab
/// Chốt quỹ, không đổi gì ở đó).
///
/// Cộng/trừ dần theo từng giao dịch (1 write + 1 read, rẻ) thay vì chạy lại
/// phân tích nhiều bảng mỗi lần gửi thông báo. Tự sửa lệch tích luỹ mỗi khi
/// có người CHỐT QUỸ thật — xem `resetBaseline()`.
class CashBalanceCacheService {
  static DocumentReference<Map<String, dynamic>> _doc(String shopId) =>
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('meta')
          .doc('cashBalanceCache');

  /// Cộng/trừ theo giao dịch, trả về tổng MỚI để chèn vào thông báo.
  /// Trả `null` nếu lỗi, số tiền = 0, hoặc phương thức là CÔNG NỢ (chưa có
  /// tiền di chuyển thật nên không tính vào quỹ) — người gọi bỏ qua phần
  /// "Còn lại" trong thông báo khi nhận `null`, KHÔNG chặn việc gửi thông
  /// báo chính.
  static Future<int?> applyDelta({
    required String shopId,
    required int amount,
    required bool isIncome,
    String? paymentMethod,
  }) async {
    if (amount == 0) return null;
    final method = (paymentMethod ?? '').trim().toUpperCase();
    if (method == 'CÔNG NỢ') return null;

    final delta = isIncome ? amount : -amount;
    final ref = _doc(shopId);
    try {
      // `update()` (không phải `set(merge:true)`) CỐ Ý lỗi not-found nếu
      // doc chưa tồn tại — bắt lỗi đó để chuyển sang seed 1 lần (bên dưới)
      // thay vì tự khởi tạo mốc từ 0 (sẽ hiện "Còn lại" sai — thiếu hẳn
      // phần quỹ tích luỹ trước đó).
      await ref.update({
        'total': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final snap = await ref.get();
      return (snap.data()?['total'] as num?)?.toInt();
    } catch (e) {
      // Chưa có mốc (lần đầu dùng tính năng này, hoặc doc bị lỗi) — seed 1
      // lần từ lần CHỐT QUỸ gần nhất ĐÃ CÓ SẴN trong máy (chỉ đọc local
      // SQLite — rẻ, KHÔNG chạy lại phân tích nhiều bảng), cộng luôn giao
      // dịch hiện tại vào mốc mới seed để không mất delta này. Nếu shop
      // chưa từng chốt quỹ lần nào thì vẫn không có gì để seed — bỏ qua,
      // không hiện số sai.
      final seeded = await _trySeedFromLastClosing(shopId, delta);
      if (seeded != null) return seeded;
      debugPrint(
        'CashBalanceCacheService.applyDelta: chưa có mốc (shop chưa từng chốt quỹ lần nào) hoặc lỗi khác: $e',
      );
      return null;
    }
  }

  static Future<int?> _trySeedFromLastClosing(
    String shopId,
    int firstDelta,
  ) async {
    try {
      final tomorrow = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now().add(const Duration(days: 1)));
      final closing = await DBHelper().getLatestClosingBefore(tomorrow);
      if (closing == null) return null;
      final cash = (closing['cashEnd'] as num?)?.toInt() ?? 0;
      final bank = (closing['bankEnd'] as num?)?.toInt() ?? 0;
      final total = cash + bank + firstDelta;
      await _doc(shopId).set({
        'total': total,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return total;
    } catch (e) {
      debugPrint('CashBalanceCacheService._trySeedFromLastClosing error: $e');
      return null;
    }
  }

  /// Đặt lại mốc = tổng đếm thực tế lúc CHỐT QUỸ (tiền mặt + ngân hàng) —
  /// sửa lệch tích luỹ định kỳ (thiếu giao dịch, sửa/xoá thủ công...).
  static Future<void> resetBaseline({
    required String shopId,
    required int cash,
    required int bank,
  }) async {
    try {
      await _doc(shopId).set({
        'total': cash + bank,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('CashBalanceCacheService.resetBaseline error: $e');
    }
  }
}
