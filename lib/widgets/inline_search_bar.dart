import 'package:flutter/material.dart';

/// Thanh tìm kiếm nằm NGAY TRONG màn, gõ tới đâu lọc tới đó.
///
/// Dựng theo đúng thanh tìm ở "DANH SÁCH ĐIỆN THOẠI" (`order_list_view`) — cao
/// 42, bo góc 12, nền trắng, icon kính lúp ở đầu — để mọi màn tìm kiếm trong
/// app nhìn và dùng giống hệt nhau.
///
/// Thay cho kiểu cũ ở màn NCC / Đối tác: một nút 🔍 trên thanh tiêu đề mở ra
/// hộp thoại "Tìm kiếm…" với ba nút *Xóa / Hủy / Áp dụng*. Kiểu đó bắt người
/// dùng bấm ba lần mới lọc được một lần, gõ xong không thấy kết quả đổi cho tới
/// khi bấm "Áp dụng", và giấu luôn từ khoá đang lọc sau khi hộp thoại đóng.
///
/// Việc so khớp **không dấu / không phân biệt hoa thường** nằm ở phía màn dùng
/// nó — dùng `VietnameseUtils.containsVietnamese`.
class InlineSearchBar extends StatefulWidget {
  const InlineSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  final TextEditingController controller;
  final String hintText;

  /// Gọi mỗi lần chữ đổi (kể cả khi bấm nút xoá) — nơi dùng gọi `setState`.
  final ValueChanged<String>? onChanged;

  final EdgeInsetsGeometry padding;

  @override
  State<InlineSearchBar> createState() => _InlineSearchBarState();
}

class _InlineSearchBarState extends State<InlineSearchBar> {
  @override
  void initState() {
    super.initState();
    // Nghe controller thay vì chỉ dựa vào `onChanged` của TextField: nút xoá và
    // những chỗ đặt text bằng code (vd mở màn kèm từ khoá sẵn) cũng phải làm
    // nút xoá hiện/ẩn đúng.
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return Padding(
      padding: widget.padding,
      child: SizedBox(
        height: 42,
        child: TextField(
          controller: widget.controller,
          onChanged: widget.onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: hasText
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Xoá tìm kiếm',
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged?.call('');
                      FocusScope.of(context).unfocus();
                    },
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2962FF)),
            ),
          ),
        ),
      ),
    );
  }
}
