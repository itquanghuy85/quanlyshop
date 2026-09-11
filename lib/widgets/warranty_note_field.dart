import 'package:flutter/material.dart';

import '../utils/warranty_note.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

export '../utils/warranty_note.dart';

/// Chip chọn nhanh + ô ghi chú tự do cho bảo hành.
///
/// Giá trị luôn là MỘT chuỗi ([value]); bấm chip thì ghi đúng chữ của chip
/// vào ô, gõ tay thì chip bỏ chọn. Vì thế mọi nơi đọc `warranty` không cần
/// biết người dùng chọn hay gõ.
class WarrantyNoteField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String? label;
  final bool dense;

  const WarrantyNoteField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.dense = false,
  });

  @override
  State<WarrantyNoteField> createState() => _WarrantyNoteFieldState();
}

class _WarrantyNoteFieldState extends State<WarrantyNoteField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: WarrantyNote.normalize(widget.value));
  }

  @override
  void didUpdateWidget(covariant WarrantyNoteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // So theo giá trị CHUẨN HOÁ: ô trống và "KO BH" là một — nếu không, sau
    // khi bấm ✕ (ô trống, parent nhận "KO BH") chính chỗ này điền lại chữ
    // "KO BH" vào ô và người dùng gõ tiếp bị nối đuôi.
    final normalized = WarrantyNote.normalize(widget.value);
    if (widget.value != oldWidget.value &&
        WarrantyNote.normalize(_ctrl.text) != normalized) {
      _ctrl.text = normalized == WarrantyNote.none ? '' : normalized;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _set(String v) {
    _ctrl.text = v;
    _ctrl.selection = TextSelection.collapsed(offset: v.length);
    widget.onChanged(v);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Ô trống ≡ "KO BH" (chip KO BH sáng) để nút ✕ có thể xoá trống cho
    // người dùng gõ mới, thay vì đặt lại chữ "KO BH" rồi gõ bị nối vào sau.
    final current = WarrantyNote.normalize(_ctrl.text).toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Wrap(
          spacing: 6,
          runSpacing: -6,
          children: WarrantyNote.presets
              .map(
                (opt) => ChoiceChip(
                  label: Text(opt, style: AppTextStyles.caption),
                  selected: current == opt,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => _set(opt),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                ),
              )
              .toList(),
        ),
        SizedBox(height: widget.dense ? 4 : 8),
        TextField(
          controller: _ctrl,
          textCapitalization: TextCapitalization.characters,
          style: AppTextStyles.caption,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.verified_user_outlined, size: 18),
            hintText: 'Hoặc gõ ghi chú: BH MÀN 3 THÁNG, PIN 6 THÁNG…',
            hintStyle: AppTextStyles.caption.copyWith(color: Colors.grey),
            helperText: widget.dense
                ? null
                : 'Ghi số tháng để app tự tính ngày hết hạn ở mục Bảo hành',
            helperStyle: AppTextStyles.caption.copyWith(
              color: Colors.grey,
              fontSize: 10,
            ),
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _ctrl.clear();
                      widget.onChanged(WarrantyNote.none);
                      setState(() {});
                    },
                  ),
          ),
          onChanged: (v) {
            widget.onChanged(v.trim().isEmpty ? WarrantyNote.none : v.trim());
            setState(() {});
          },
        ),
      ],
    );
  }
}
