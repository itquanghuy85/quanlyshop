/// Sắp xếp dòng giao dịch của Sổ quỹ theo thời gian THẬT.
///
/// Mỗi dòng giao dịch Sổ quỹ là một `Map` mang 2 trường thời gian:
///   • `time`      — chuỗi hiển thị `"HH:mm"`;
///   • `timestamp` — mốc tuyệt đối (millisecondsSinceEpoch).
///
/// Trước 2026-09-06 mọi chỗ sắp xếp đều so **chuỗi `time`**. Trong 1 ngày thì
/// vô hại, nhưng màn hình Sổ quỹ thường xuyên gộp NHIỀU ngày:
///   • tự gộp (các) ngày trước đó chưa chốt quỹ vào ngày đang xem;
///   • người dùng tự chọn một khoảng ngày ở màn "Lịch sử tài chính".
/// Khi đó `"09:00"` của hôm kia lớn hơn `"08:00"` của hôm nay ⇒ danh sách xen
/// kẽ lộn xộn, mà thẻ giao dịch lại chỉ in giờ nên không cách nào biết dòng
/// nào thuộc ngày nào.
library;

/// Mốc thời gian tuyệt đối (ms) của 1 dòng giao dịch; 0 nếu thiếu.
int txTimestamp(Map<String, dynamic> t) => (t['timestamp'] as int?) ?? 0;

/// So sánh giảm dần theo thời gian thật (mới nhất lên đầu).
///
/// Chỉ lùi về so chuỗi `"HH:mm"` khi CẢ HAI dòng đều thiếu `timestamp` — dữ
/// liệu cũ hoặc nguồn nào đó chưa gắn mốc.
int byTimeDesc(Map<String, dynamic> a, Map<String, dynamic> b) {
  final ta = txTimestamp(a);
  final tb = txTimestamp(b);
  if (ta != 0 || tb != 0) return tb.compareTo(ta);
  final sa = a['time'] as String? ?? '';
  final sb = b['time'] as String? ?? '';
  return sb.compareTo(sa);
}
