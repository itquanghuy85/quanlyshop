import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Helper class chứa các widgets UI dùng chung cho toàn app
/// Áp dụng style thống nhất như Settings View
class AppUIHelpers {
  /// Gradient colors chủ đạo cho AppBar (2 màu đẹp)
  static const Color gradientStart = Color(0xFF0068FF); // Zalo Blue
  static const Color gradientEnd = Color(0xFF0084FF); // Zalo Blue Light

  /// Alternative gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0068FF), Color(0xFF0084FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tealGradient = LinearGradient(
    colors: [Color(0xFF00695C), Color(0xFF26A69A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient orangeGradient = LinearGradient(
    colors: [Color(0xFFE65100), Color(0xFFFF9800)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// AppBar gradient đẹp với 2 màu - STYLE CHÍNH của app
  static PreferredSizeWidget buildGradientAppBar({
    required String title,
    String? subtitle,
    List<Widget>? actions,
    bool showBackButton = true,
    PreferredSizeWidget? bottom,
    LinearGradient? gradient,
  }) {
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(gradient: gradient ?? primaryGradient),
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.surface,
      elevation: 0,
      automaticallyImplyLeading: showBackButton,
      iconTheme: const IconThemeData(color: AppColors.surface),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTextStyles.headline3.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.surface,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.surface.withOpacity(0.8),
              ),
            ),
        ],
      ),
      actions: actions,
      bottom: bottom,
    );
  }

  /// AppBar gradient đẹp với title và subtitle (legacy - backward compatible)
  static PreferredSizeWidget gradientAppBar({
    required String title,
    String? subtitle,
    required Color color,
    List<Widget>? actions,
    bool showBackButton = true,
    PreferredSizeWidget? bottom,
  }) {
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withAlpha(179)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.surface,
      elevation: 0,
      automaticallyImplyLeading: showBackButton,
      iconTheme: const IconThemeData(color: AppColors.surface),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.headline2.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.surface,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.surface.withOpacity(0.8),
              ),
            ),
        ],
      ),
      actions: actions,
      bottom: bottom,
    );
  }

  /// Header card với gradient cho các trang chi tiết
  static Widget headerCard({
    required String title,
    required IconData icon,
    required Color color,
    String? subtitle,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withAlpha(179)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.xxl),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(77),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface.withAlpha(51),
              borderRadius: BorderRadius.circular(AppSpacing.lg),
            ),
            child: Icon(icon, color: AppColors.surface, size: 32),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.headline1.copyWith(
                    color: AppColors.surface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.surface.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  /// Section header giống Settings View
  static Widget sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
      child: Text(
        title,
        style: AppTextStyles.headline4.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Menu item card với màu sắc
  static Widget menuItemCard({
    required String title,
    required IconData icon,
    required Color color,
    String? subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: color.withAlpha(13),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        side: BorderSide(color: color.withAlpha(51)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(AppSpacing.md),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: AppTextStyles.headline4.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: AppTextStyles.body2.copyWith(color: AppColors.textHint),
              )
            : null,
        trailing:
            trailing ??
            Icon(
              Icons.arrow_forward_ios,
              color: color.withAlpha(128),
              size: 16,
            ),
        onTap: onTap,
      ),
    );
  }

  /// Quick action card 2 cột
  static Widget quickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return Card(
      color: color.withAlpha(13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        side: BorderSide(color: color.withAlpha(51)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: color.withAlpha(26),
                      borderRadius: BorderRadius.circular(AppSpacing.md),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  if (badgeCount != null && badgeCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badgeCount > 9 ? '9+' : badgeCount.toString(),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.surface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                style: AppTextStyles.headline4.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Stat card cho dashboard
  static Widget statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          border: Border.all(color: color.withAlpha(51)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      color: color.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios,
                    color: color.withOpacity(0.4),
                    size: 10,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: AppTextStyles.headline2.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Empty state widget
  static Widget emptyState({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.outline),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTextStyles.headline3.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                style: AppTextStyles.body2.copyWith(color: AppColors.textHint),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: AppSpacing.xl), action],
          ],
        ),
      ),
    );
  }

  /// Loading overlay
  static Widget loadingOverlay({String? message}) {
    return Container(
      color: AppColors.textPrimary.withAlpha(77),
      child: Center(
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                if (message != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    message,
                    style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Confirmation dialog với style mới
  static Future<bool?> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'XÁC NHẬN',
    String cancelText = 'HỦY',
    Color confirmColor = AppColors.error,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.xxl)),
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: confirmColor),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.headline3.copyWith(
                  fontWeight: FontWeight.bold,
                  color: confirmColor,
                ),
              ),
            ),
          ],
        ),
        content: Text(message, style: AppTextStyles.body1),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.md),
              ),
            ),
            child: Text(
              confirmText,
              style: AppTextStyles.button.copyWith(color: AppColors.surface),
            ),
          ),
        ],
      ),
    );
  }

  /// Date display helper
  static String formatDate(
    int timestamp, {
    String format = 'dd/MM/yyyy HH:mm',
  }) {
    return DateFormat(
      format,
      'vi',
    ).format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  /// Today date string
  static String get todayString =>
      DateFormat('EEEE, dd/MM/yyyy', 'vi').format(DateTime.now());
}

/// Extension để dễ dàng format số tiền
extension MoneyFormat on int {
  String get vnd => NumberFormat('#,###', 'vi').format(this);
  String get vndFull => '${NumberFormat('#,###', 'vi').format(this)} đ';
}
