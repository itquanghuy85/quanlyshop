import 'package:flutter/material.dart';

/// Hiển thị nội dung biên nhận/hóa đơn (chuỗi text đã build từ template có
/// thể tùy biến theo shop) dưới dạng tờ giấy in — dùng chung cho biên nhận
/// đơn bán và phiếu sửa chữa khi xem trước/xuất ảnh chia sẻ.
///
/// Không thay đổi NỘI DUNG (vẫn đúng 100% những gì máy in nhiệt in ra, tôn
/// trọng mẫu shop tự tùy biến) — chỉ trình bày lại cho rõ ràng, sạch sẽ hơn
/// khối chữ monospace thô: dòng toàn dấu "-" thành 1 đường kẻ, dòng bọc
/// trong "===...===" thành tiêu đề in đậm căn giữa, còn lại giữ nguyên
/// dạng monospace canh trái như biên nhận giấy thật.
class ReceiptPaperView extends StatelessWidget {
  final String text;
  final Widget? footer;

  const ReceiptPaperView({super.key, required this.text, this.footer});

  static final RegExp _titleLine = RegExp(r'^={2,}\s*(.+?)\s*={2,}$');
  static final RegExp _dashLine = RegExp(r'^-{3,}$');

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
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
          ..._buildLines(lines),
          if (footer != null) ...[
            const _ReceiptDivider(),
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
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              titleMatch.group(1)!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
        continue;
      }
      if (_dashLine.hasMatch(line.trim())) {
        widgets.add(const _ReceiptDivider());
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

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Divider(color: Color(0xFFBBBBBB), thickness: 1, height: 1),
    );
  }
}
