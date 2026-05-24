import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;
  final Color? iconColor;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onAction,
    this.actionLabel,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Colors.grey.shade300;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.body1.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: AppTextStyles.body2.copyWith(color: Colors.grey.shade400),
                textAlign: TextAlign.center,
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(actionLabel!),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueGrey,
                  side: BorderSide(color: Colors.blueGrey.shade200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
