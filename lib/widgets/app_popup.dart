import 'package:flutter/material.dart';
import '../theme/popup_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// DRAG HANDLE
// ═══════════════════════════════════════════════════════════════════════════

class PopupDragHandle extends StatelessWidget {
  const PopupDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        decoration: BoxDecoration(
          color: PopupTheme.borderDark,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET WRAPPER
// ═══════════════════════════════════════════════════════════════════════════

class AppBottomSheetContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool showHandle;

  const AppBottomSheetContainer({
    super.key,
    required this.child,
    this.padding,
    this.showHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PopupTheme.bgDark,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PopupTheme.radiusSheet),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle) const PopupDragHandle(),
          Flexible(
            child: SingleChildScrollView(
              padding: padding ?? const EdgeInsets.fromLTRB(
                PopupTheme.pagePadding,
                8,
                PopupTheme.pagePadding,
                PopupTheme.pagePadding,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIALOG WRAPPER
// ═══════════════════════════════════════════════════════════════════════════

class AppDarkDialog extends StatelessWidget {
  final Widget? header;
  final Widget content;
  final List<Widget>? actions;
  final double? width;

  const AppDarkDialog({
    super.key,
    this.header,
    required this.content,
    this.actions,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final w = width ?? MediaQuery.of(context).size.width * 0.92;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: w.clamp(0, 480),
        decoration: BoxDecoration(
          color: PopupTheme.bgDark,
          borderRadius: BorderRadius.circular(PopupTheme.radiusDialog),
          boxShadow: PopupTheme.shadowMedium,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) header!,
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  PopupTheme.pagePadding,
                  PopupTheme.pagePadding,
                  PopupTheme.pagePadding,
                  8,
                ),
                child: content,
              ),
            ),
            if (actions != null && actions!.isNotEmpty)
              _ActionsRow(children: actions!),
          ],
        ),
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  final List<Widget> children;
  const _ActionsRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        PopupTheme.pagePadding,
        8,
        PopupTheme.pagePadding,
        PopupTheme.pagePadding,
      ),
      child: children.length == 1
          ? children.first
          : Row(
              children: children
                  .expand((w) => [w, const SizedBox(width: 8)])
                  .take(children.length * 2 - 1)
                  .map((w) => w is SizedBox ? w : Expanded(child: w))
                  .toList(),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GRADIENT DIALOG HEADER
// ═══════════════════════════════════════════════════════════════════════════

class PopupGradientHeader extends StatelessWidget {
  final LinearGradient gradient;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  const PopupGradientHeader({
    super.key,
    this.gradient = PopupTheme.headerEdit,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(PopupTheme.radiusDialog),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onClose != null)
            GestureDetector(
              onTap: onClose,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// INFO ROW — label:value display
// ═══════════════════════════════════════════════════════════════════════════

class PopupInfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  final VoidCallback? onTap;
  final IconData? trailingIcon; // overrides default copy icon when onTap != null

  const PopupInfoRow({
    super.key,
    required this.icon,
    this.iconColor = PopupTheme.textSecondary,
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
    this.onTap,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 86,
              child: Text(
                label,
                style: const TextStyle(
                  color: PopupTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor ?? PopupTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                ),
                textAlign: TextAlign.end,
              ),
            ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  trailingIcon ?? Icons.copy_outlined,
                  size: 13,
                  color: PopupTheme.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STAT CARD — counts display
// ═══════════════════════════════════════════════════════════════════════════

class PopupStatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const PopupStatCard({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(PopupTheme.radiusCard),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: PopupTheme.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION DIVIDER
// ═══════════════════════════════════════════════════════════════════════════

class PopupSectionDivider extends StatelessWidget {
  final String? title;
  const PopupSectionDivider({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    if (title == null) {
      return const Divider(
        height: 20,
        color: PopupTheme.borderDark,
        thickness: 1,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(child: Divider(color: PopupTheme.borderDark, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              title!,
              style: const TextStyle(
                color: PopupTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const Expanded(child: Divider(color: PopupTheme.borderDark, thickness: 1)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BADGE CHIP
// ═══════════════════════════════════════════════════════════════════════════

class PopupBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const PopupBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(PopupTheme.radiusBadge),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PRODUCT IMAGE TILE
// ═══════════════════════════════════════════════════════════════════════════

class PopupProductImage extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const PopupProductImage({super.key, this.imageUrl, this.size = 68});

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();
    final hasImage = url.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: PopupTheme.surfaceDark,
        borderRadius: BorderRadius.circular(PopupTheme.radiusCard),
        border: Border.all(color: PopupTheme.borderDark),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.phone_android_rounded,
        size: size * 0.36,
        color: PopupTheme.textMuted,
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// CONFIRM DIALOG
// ═══════════════════════════════════════════════════════════════════════════

class PopupConfirmDialog extends StatelessWidget {
  final LinearGradient headerGradient;
  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const PopupConfirmDialog({
    super.key,
    this.headerGradient = PopupTheme.headerRed,
    required this.icon,
    required this.title,
    required this.message,
    this.confirmLabel = 'Xác nhận',
    this.cancelLabel = 'Hủy',
    this.confirmColor = PopupTheme.red,
    required this.onConfirm,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AppDarkDialog(
      header: PopupGradientHeader(
        gradient: headerGradient,
        icon: icon,
        title: title,
        onClose: onCancel ?? () => Navigator.pop(context),
      ),
      content: Text(
        message,
        style: const TextStyle(
          color: PopupTheme.textPrimary,
          fontSize: 13,
          height: 1.5,
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: onCancel ?? () => Navigator.pop(context, false),
          style: PopupTheme.secondaryButton(),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: PopupTheme.primaryButton(color: confirmColor),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LIGHT DROPDOWN FIELD
// ═══════════════════════════════════════════════════════════════════════════

class DarkDropdownField<T> extends StatelessWidget {
  final T? value;
  final String label;
  final IconData? prefixIcon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool isExpanded;

  const DarkDropdownField({
    super.key,
    this.value,
    required this.label,
    this.prefixIcon,
    required this.items,
    required this.onChanged,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      // ignore: deprecated_member_use
      value: value,
      isExpanded: isExpanded,
      dropdownColor: PopupTheme.bgDark,
      style: const TextStyle(
        color: PopupTheme.textPrimary,
        fontSize: 13,
      ),
      decoration: PopupTheme.darkField(label: label, prefixIcon: prefixIcon),
      items: items,
      onChanged: onChanged,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS — show functions
// ═══════════════════════════════════════════════════════════════════════════

/// Show a premium confirm dialog. Returns true if confirmed.
Future<bool?> showPremiumConfirm({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Xác nhận',
  String cancelLabel = 'Hủy',
  Color confirmColor = PopupTheme.blue,
  LinearGradient headerGradient = PopupTheme.headerEdit,
  IconData icon = Icons.help_outline_rounded,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => PopupConfirmDialog(
      headerGradient: headerGradient,
      icon: icon,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      confirmColor: confirmColor,
      onConfirm: () => Navigator.pop(context, true),
      onCancel: () => Navigator.pop(context, false),
    ),
  );
}
