import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Biểu đồ cột ngang hiển thị top-N item với CustomPainter.
class AuditBarChart extends StatelessWidget {
  final List<_BarItem> items;
  final Color barColor;
  final int maxItems;

  const AuditBarChart({
    super.key,
    required this.items,
    this.barColor = const Color(0xFF6C63FF),
    this.maxItems = 8,
  });

  factory AuditBarChart.fromMap(
    Map<String, int> data, {
    Color barColor = const Color(0xFF6C63FF),
    int maxItems = 8,
  }) {
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final items = sorted
        .take(maxItems)
        .map((e) => _BarItem(label: e.key, value: e.value))
        .toList();
    return AuditBarChart(items: items, barColor: barColor, maxItems: maxItems);
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Chưa có dữ liệu',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      );
    }
    final maxValue = items.map((e) => e.value).reduce(math.max);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final valueColor = isDark ? Colors.white : Colors.black87;

    return Column(
      children: items.asMap().entries.map((entry) {
        final item = entry.value;
        final ratio = maxValue > 0 ? item.value / maxValue : 0.0;
        final opacity = 1.0 - (entry.key * 0.08);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final maxWidth = constraints.maxWidth;
              final labelWidth = math.min(140.0, maxWidth * 0.38);

              return Row(
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 11.5,
                        overflow: TextOverflow.ellipsis,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: barColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: ratio.clamp(0.02, 1.0),
                          child: Container(
                            height: 20,
                            decoration: BoxDecoration(
                              color: barColor.withOpacity(
                                opacity.clamp(0.3, 1.0),
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 46,
                    child: Text(
                      _formatNum(item.value),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: valueColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }).toList(),
    );
  }

  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _BarItem {
  final String label;
  final int value;
  const _BarItem({required this.label, required this.value});
}

/// Sparkline mini chart dùng CustomPainter.
class AuditSparkline extends StatelessWidget {
  final List<int> values;
  final Color color;
  final double height;

  const AuditSparkline({
    super.key,
    required this.values,
    this.color = const Color(0xFF6C63FF),
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SizedBox(height: height);
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(values: values, color: color),
        size: Size.infinite,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> values;
  final Color color;

  const _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxVal = values.reduce(math.max);
    if (maxVal <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    final w = size.width;
    final h = size.height;
    final step = w / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final x = i * step;
      final y = h - (values[i] / maxVal) * h * 0.9 - h * 0.05;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, h);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(w, h);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
