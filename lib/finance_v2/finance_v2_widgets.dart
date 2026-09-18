import 'package:flutter/material.dart';
import '../utils/money_utils.dart';
import 'finance_v2_theme.dart';

/// Bộ khối giao diện dùng chung cho 4 tab Tài chính (Tiền / Lãi / Nợ /
/// Chốt quỹ) — kiểu "app tài chính": nền sáng, thẻ trắng bo 16, bóng rất
/// nhẹ, số tiền là thứ nổi bật nhất, metadata nhỏ và xám.
///
/// CHỈ vẽ, không đọc dữ liệu: mọi con số đều do màn cha đưa vào từ
/// `FinanceV2Snapshot` (SQLite) — không widget nào ở đây chạm DB/Firestore.
class FinanceV2Widgets {
  FinanceV2Widgets._();

  static const Color tintGreen = Color(0xFFE8F5EE);
  static const Color tintRed = Color(0xFFFDECEA);
  static const Color tintBlue = Color(0xFFE8F0FE);
  static const Color tintOrange = Color(0xFFFFF3E0);
  static const Color tintGrey = Color(0xFFF1F4F9);
  static const Color divider = Color(0xFFEEF1F7);

  static String compact(int v) => MoneyUtils.formatCompactCurrency(v.abs());

  static String signed(int v) =>
      '${v < 0 ? '-' : ''}${MoneyUtils.formatCompactCurrency(v.abs())}';

  /// Thẻ trắng bo góc, bóng rất nhẹ.
  static Widget card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
    EdgeInsetsGeometry? margin,
    Color? color,
  }) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? FinanceV2Theme.panelBg,
        borderRadius: BorderRadius.circular(FinanceV2Theme.radiusPanel),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F1F3D).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Nhãn mục in hoa nhỏ: "DÒNG TIỀN · 7 NGÀY".
  static Widget sectionLabel(String text, {Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: FinanceV2Theme.subInk,
              letterSpacing: 0.6,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  /// Ô số liệu nền màu nhạt: icon + số to + nhãn nhỏ.
  static Widget statTile({
    required String label,
    required String value,
    required Color color,
    required Color tint,
    IconData? icon,
    VoidCallback? onTap,
    bool selected = false,
    double valueSize = 18,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: valueSize,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(label, style: FinanceV2Theme.micro),
            ],
          ),
        ),
      ),
    );
  }

  /// Dòng "mở tiếp": ô icon vuông nền nhạt + nhãn + chevron.
  static Widget linkRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = FinanceV2Theme.accent,
    Color? tint,
    String? value,
    Color? valueColor,
    bool showDivider = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: tint ?? color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 17, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: FinanceV2Theme.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (value != null) ...[
                  Text(
                    value,
                    style: FinanceV2Theme.amountMd.copyWith(
                      color: valueColor ?? FinanceV2Theme.ink,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: FinanceV2Theme.subInk,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 58, color: divider),
      ],
    );
  }

  /// Nút hành động viền màu nền nhạt: "+ Ghi thu" / "− Ghi chi".
  static Widget outlinedAction({
    required IconData icon,
    required String label,
    required Color color,
    required Color tint,
    required VoidCallback onTap,
  }) {
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Chip lọc viên thuốc: chọn = nền xanh chữ trắng.
  static Widget filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Material(
      color: selected ? FinanceV2Theme.accent : tintGrey,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: icon != null && label.isEmpty ? 9 : 13,
            vertical: 6,
          ),
          child: icon != null && label.isEmpty
              ? Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : FinanceV2Theme.subInk,
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : FinanceV2Theme.subInk,
                  ),
                ),
        ),
      ),
    );
  }

  /// Icon tròn nền nhạt cho từng loại giao dịch.
  static ({IconData icon, Color color, Color tint}) txIcon(
    String type,
    bool isIncome,
  ) {
    switch (type) {
      case 'SALE':
        return (
          icon: Icons.shopping_cart_outlined,
          color: FinanceV2Theme.positive,
          tint: tintGreen,
        );
      case 'REPAIR':
        return (
          icon: Icons.build_outlined,
          color: FinanceV2Theme.positive,
          tint: tintGreen,
        );
      case 'INCOME':
        return (
          icon: Icons.add_card_outlined,
          color: FinanceV2Theme.positive,
          tint: tintGreen,
        );
      case 'DEBT_COLLECT':
        return (
          icon: Icons.person_outline_rounded,
          color: FinanceV2Theme.positive,
          tint: tintGreen,
        );
      case 'DEBT_PAY':
        return (
          icon: Icons.person_outline_rounded,
          color: FinanceV2Theme.negative,
          tint: tintRed,
        );
      case 'REFUND':
        return (
          icon: Icons.undo_rounded,
          color: const Color(0xFFE65100),
          tint: tintOrange,
        );
      case 'EXPENSE':
      default:
        return isIncome
            ? (
                icon: Icons.arrow_downward_rounded,
                color: FinanceV2Theme.positive,
                tint: tintGreen,
              )
            : (
                icon: Icons.inventory_2_outlined,
                color: FinanceV2Theme.negative,
                tint: tintRed,
              );
    }
  }

  /// Một dòng giao dịch: icon tròn · tiêu đề + 1-2 dòng meta · số tiền.
  /// Không viền, không card — ngăn cách bằng divider rất nhẹ ở danh sách.
  static Widget txTile({
    required String type,
    required bool isIncome,
    required String title,
    required String meta,
    String? meta2,
    required int amount,
    required VoidCallback onTap,
    IconData? iconOverride,
    Color? colorOverride,
  }) {
    final spec = txIcon(type, isIncome);
    final amountColor =
        isIncome ? FinanceV2Theme.positive : FinanceV2Theme.negative;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colorOverride?.withValues(alpha: 0.12) ?? spec.tint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconOverride ?? spec.icon,
                size: 18,
                color: colorOverride ?? spec.color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: FinanceV2Theme.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: FinanceV2Theme.micro,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meta2 != null && meta2.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      meta2,
                      style: FinanceV2Theme.micro.copyWith(
                        color: FinanceV2Theme.subInk.withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${isIncome ? '+' : '-'}${compact(amount)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dòng số liệu trong thẻ Lãi: nhãn trái, số phải. [sub] = dòng con thụt vào.
  static Widget kpiRow(
    String label,
    int amount, {
    IconData? icon,
    Color? amountColor,
    bool sub = false,
    bool bold = false,
    bool signed = false,
  }) {
    final text = signed ? FinanceV2Widgets.signed(amount) : compact(amount);
    return Padding(
      padding: EdgeInsets.only(
        top: sub ? 2 : 6,
        bottom: sub ? 2 : 6,
        left: sub ? 30 : 0,
      ),
      child: Row(
        children: [
          if (!sub && icon != null) ...[
            Icon(icon, size: 16, color: FinanceV2Theme.subInk),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              style: sub
                  ? FinanceV2Theme.micro
                  : FinanceV2Theme.bodyMd.copyWith(
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    ),
            ),
          ),
          Text(
            text,
            style: sub
                ? FinanceV2Theme.micro.copyWith(fontWeight: FontWeight.w600)
                : TextStyle(
                    fontSize: bold ? 15 : 14,
                    fontWeight: FontWeight.w800,
                    color: amountColor ?? FinanceV2Theme.ink,
                  ),
          ),
        ],
      ),
    );
  }

  /// Cột so sánh kỳ: nhãn · số kỳ này (mũi tên màu) · "trước: x" · %.
  static Widget compareColumn({
    required String label,
    required int current,
    required int previous,
    bool higherIsBetter = true,
  }) {
    final up = current >= previous;
    final good = higherIsBetter ? up : !up;
    final color = good ? FinanceV2Theme.positive : FinanceV2Theme.negative;
    // Kỳ trước quá nhỏ thì % bung thành "+8333%" — vô nghĩa, giấu đi (vẫn
    // hiện số kỳ trước để người đọc tự so).
    final rawPct = previous == 0
        ? null
        : ((current - previous) / previous.abs()) * 100.0;
    final pct = rawPct != null && rawPct.abs() < 1000 ? rawPct : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: FinanceV2Theme.micro),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Icon(
                up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 13,
                color: color,
              ),
              const SizedBox(width: 2),
              Text(
                compact(current),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text('trước: ${compact(previous)}', style: FinanceV2Theme.caption),
        if (pct != null)
          Text(
            '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}%',
            style: FinanceV2Theme.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
      ],
    );
  }

  /// Biểu đồ cột mini thu (xanh) / chi (đỏ) theo ngày. [days] đã được lấp đủ
  /// ngày (kể cả ngày trống) bởi màn cha.
  static Widget miniBars(List<({String label, int inAmt, int outAmt})> days) {
    if (days.length < 2) return const SizedBox.shrink();
    int maxV = 1;
    for (final d in days) {
      if (d.inAmt > maxV) maxV = d.inAmt;
      if (d.outAmt > maxV) maxV = d.outAmt;
    }
    final showEvery = days.length <= 8 ? 1 : (days.length / 6).ceil();
    return SizedBox(
      height: 72,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in days)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: _bar(d.inAmt / maxV, FinanceV2Theme.positive)),
                          const SizedBox(width: 1),
                          Expanded(child: _bar(d.outAmt / maxV, FinanceV2Theme.negative)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: Text(
                    (i % showEvery == 0 || i == days.length - 1)
                        ? days[i].label
                        : '',
                    style: const TextStyle(
                      fontSize: 9,
                      color: FinanceV2Theme.subInk,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _bar(double ratio, Color color) {
    final r = ratio.clamp(0.0, 1.0);
    return FractionallySizedBox(
      heightFactor: r < 0.04 && r > 0 ? 0.04 : r,
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          color: r == 0 ? Colors.transparent : color.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
      ),
    );
  }

  /// Thẻ chọn Phải thu / Phải trả (đầy màu khi chọn).
  static Widget debtToggle({
    required String label,
    required int amount,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? color : tintGrey,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          alignment: Alignment.center,
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : FinanceV2Theme.subInk,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  compact(amount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : FinanceV2Theme.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ô tuổi nợ viền màu nhạt: "0–30 ngày / 32,65 Tr".
  static Widget agingTile(String label, int amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: FinanceV2Theme.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount == 0 ? '0' : compact(amount),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ô trắng nửa trong suốt đặt trên thẻ gradient xanh (Tiền mặt / NH).
  static Widget heroSubTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
