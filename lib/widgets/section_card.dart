import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/design_tokens.dart';

/// Widget Card với header chuyên nghiệp dùng cho các sections trong form
/// Thiết kế: Header có icon + tiêu đề + badge tùy chọn, body có padding và border radius
class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets? padding;
  final bool showDivider;
  final VoidCallback? onHeaderTap;

  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor,
    this.trailing,
    this.padding,
    this.showDivider = true,
    this.onHeaderTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: DesignTokens.brLg,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: onHeaderTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusLg)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withOpacity(0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusLg)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: AppSpacing.pSm,
                    decoration: BoxDecoration(
                      color: (iconColor ?? AppColors.primary).withOpacity(0.15),
                      borderRadius: DesignTokens.brSm,
                    ),
                    child: Icon(
                      icon,
                      color: iconColor ?? AppColors.primary,
                      size: DesignTokens.iconMd,
                    ),
                  ),
                  AppSpacing.hMd,
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.subtitle1.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ),
          // Divider
          if (showDivider)
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.outline.withAlpha(77),
            ),
          // Content
          Padding(
            padding: padding ?? AppSpacing.pLg,
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Card đơn giản không có header, chỉ có border và shadow nhẹ
class SimpleCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? backgroundColor;
  final Color? borderColor;

  const SimpleCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: AppSpacing.md),
      padding: padding ?? AppSpacing.pLg,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: DesignTokens.brMd,
        border: borderColor != null ? Border.all(color: borderColor!) : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// InfoRow widget để hiển thị label: value một cách nhất quán
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final bool bold;
  final VoidCallback? onTap;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.bold = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: DesignTokens.iconSm, color: AppColors.grey600),
            AppSpacing.hSm,
          ],
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.grey600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body2.copyWith(
                color: valueColor ?? AppColors.onSurface,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right,
              size: DesignTokens.iconSm + 2,
              color: AppColors.grey600,
            ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: DesignTokens.brSm,
        child: content,
      );
    }
    return content;
  }
}

/// StatusBadge widget cho hiển thị trạng thái với màu sắc
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// ActionButton nhỏ gọn cho các actions trong card
class CompactActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final bool outlined;

  const CompactActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? AppColors.primary;

    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: AppTextStyles.caption),
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonColor,
          side: BorderSide(color: buttonColor),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: AppTextStyles.caption),
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

