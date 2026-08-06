import 'package:flutter/material.dart';

/// Section hiển thị danh sách top-N với sort/expand.
class TopListSection extends StatelessWidget {
  final String title;
  final List<_TopItem> items;
  final Color accentColor;
  final int maxVisible;
  final ValueChanged<String>? onItemTap;

  const TopListSection({
    super.key,
    required this.title,
    required this.items,
    this.accentColor = const Color(0xFF6C63FF),
    this.maxVisible = 5,
    this.onItemTap,
  });

  factory TopListSection.fromMap(
    String title,
    Map<String, int> data, {
    Color accentColor = const Color(0xFF6C63FF),
    int maxVisible = 5,
    ValueChanged<String>? onItemTap,
  }) {
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return TopListSection(
      title: title,
      items: sorted
          .take(maxVisible)
          .map((e) => _TopItem(label: e.key, value: e.value))
          .toList(),
      accentColor: accentColor,
      maxVisible: maxVisible,
      onItemTap: onItemTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final subText = isDark ? Colors.white60 : Colors.black54;
    final maxValue = items.isEmpty
        ? 1
        : items.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                'Chưa có dữ liệu',
                style: TextStyle(color: subText, fontSize: 12),
              ),
            )
          else
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final ratio = maxValue > 0 ? item.value / maxValue : 0.0;

              return InkWell(
                onTap: onItemTap != null ? () => onItemTap!(item.label) : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: Text(
                          '${i + 1}.',
                          style: TextStyle(
                            color: subText,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        flex: 4,
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: ratio.clamp(0.02, 1.0),
                            backgroundColor: accentColor.withOpacity(0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              accentColor.withOpacity(0.7 - i * 0.05),
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 48,
                        child: Text(
                          _fmt(item.value),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _TopItem {
  final String label;
  final int value;
  const _TopItem({required this.label, required this.value});
}
