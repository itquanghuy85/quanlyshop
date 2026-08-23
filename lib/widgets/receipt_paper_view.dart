import 'package:flutter/material.dart';

/// Khung "tờ giấy in" dùng chung cho biên nhận đơn bán/phiếu sửa chữa khi
/// xem trước hoặc xuất ảnh chia sẻ — cùng 1 khối nền trắng ngà, bo góc nhẹ,
/// đổ bóng, nổi trên nền xám nhạt.
///
/// 2 chế độ nội dung, chọn đúng theo những gì THỰC SỰ được in ra máy in
/// nhiệt (`UnifiedPrinterService`), không được bịa thêm nội dung khác:
/// - `text`: dùng khi shop đã tự bật + tùy biến mẫu in riêng — máy in lúc
///   này in ra ĐÚNG NGUYÊN VĂN chuỗi template này (`_printTextReceipt`),
///   nên hiển thị lại y hệt, chỉ làm đẹp cách trình bày (đường kẻ, tiêu đề).
/// - `children`: dùng khi shop CHƯA tự tùy biến mẫu (mặc định) — máy in lúc
///   này in theo layout ESC/POS dựng sẵn có phân cấp rõ (tên shop đậm to,
///   tổng tiền đậm to, mục nhỏ hơn...), nên bản xem trước phải dựng lại
///   ĐÚNG cấu trúc/phân cấp đó bằng widget thay vì suy luận từ text thô.
class ReceiptPaperView extends StatelessWidget {
  final String? text;
  final List<Widget>? children;
  final Widget? footer;

  const ReceiptPaperView({super.key, this.text, this.children, this.footer})
      : assert(
          (text != null) != (children != null),
          'Truyền đúng 1 trong 2: text (mẫu tùy biến) hoặc children (layout mặc định)',
        );

  static final RegExp _titleLine = RegExp(r'^={2,}\s*(.+?)\s*={2,}$');
  static final RegExp _dashLine = RegExp(r'^-{3,}$');

  @override
  Widget build(BuildContext context) {
    final content = children ?? _buildLines(text!.split('\n'));
    return Container(
      width: 380,
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFA),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...content,
          if (footer != null) ...[
            receiptDivider(),
            footer!,
          ],
        ],
      ),
    );
  }

  List<Widget> _buildLines(List<String> lines) {
    final widgets = <Widget>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      final titleMatch = _titleLine.firstMatch(line.trim());
      if (titleMatch != null) {
        widgets.add(receiptTitle(titleMatch.group(1)!));
        continue;
      }
      if (_dashLine.hasMatch(line.trim())) {
        widgets.add(receiptDivider());
        continue;
      }
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 10));
        continue;
      }
      widgets.add(
        Text(
          line,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.55,
            color: Color(0xFF1A1A1A),
          ),
        ),
      );
    }
    return widgets;
  }
}

// ---------------------------------------------------------------------------
// Các dòng kiểu chữ dùng chung, tái hiện đúng phân cấp ESC/POS thật của máy
// in (bold/size2/align center/fontB) bằng TextStyle tương đương — dùng khi
// dựng layout mặc định (children) cho cả 2 loại biên nhận.
// ---------------------------------------------------------------------------

/// Tên shop / tiêu đề biên nhận — tương đương `bold: true, height: size2,
/// align: center` bên máy in.
Widget receiptTitle(String text, {double fontSize = 18}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: fontSize,
        letterSpacing: 0.2,
        color: const Color(0xFF1A1A1A),
      ),
    ),
  );
}

/// Dòng canh giữa (địa chỉ, mã đơn, ngày, hotline...) — tương đương
/// `align: center`, có thể đậm.
Widget receiptCenter(String text, {bool bold = false, double fontSize = 13}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontSize: fontSize,
        color: const Color(0xFF1A1A1A),
      ),
    ),
  );
}

/// Dòng canh trái thường (tên khách, SĐT, sản phẩm...) — có thể đậm cho
/// nhãn mục (tương đương `bold: true` bên máy in).
Widget receiptLeft(String text, {bool bold = false, double fontSize = 13.5}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontSize: fontSize,
        color: const Color(0xFF1A1A1A),
      ),
    ),
  );
}

/// Dòng chữ nhỏ, xám — tương đương `fontType: PosFontType.fontB` bên máy in
/// (chi tiết phụ: IMEI, ghi chú chính sách, dòng cuối biên nhận).
Widget receiptSmall(
  String text, {
  TextAlign align = TextAlign.left,
  double fontSize = 11.5,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Text(
      text,
      textAlign: align,
      style: TextStyle(fontSize: fontSize, color: Colors.grey.shade700),
    ),
  );
}

/// Khoảng trống giữa các khối — tương đương `generator.feed(1)`.
Widget receiptGap([double height = 10]) => SizedBox(height: height);

/// Đường kẻ ngang mảnh — tương đương `generator.hr()`.
Widget receiptDivider() {
  return const Padding(
    padding: EdgeInsets.symmetric(vertical: 10),
    child: Divider(color: Color(0xFFBBBBBB), thickness: 1, height: 1),
  );
}
