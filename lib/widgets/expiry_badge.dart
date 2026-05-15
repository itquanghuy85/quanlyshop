import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/product_model.dart';
import '../services/expiry_alert_service.dart';

/// Widget hiển thị badge cảnh báo hạn sử dụng
/// Sử dụng cho danh sách sản phẩm, chi tiết sản phẩm
class ExpiryBadge extends StatelessWidget {
  final Product product;
  final int? warningDays;
  final bool showDays;
  final bool compact;

  const ExpiryBadge({
    super.key,
    required this.product,
    this.warningDays,
    this.showDays = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (product.expiryDate == null) return const SizedBox.shrink();

    final service = ExpiryAlertService();
    final status = service.getExpiryStatus(product, warningDays: warningDays);
    final text = service.formatExpiryText(product, warningDays: warningDays);

    final config = _getBadgeConfig(status);

    if (compact) {
      return _buildCompactBadge(config, status);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 14, color: config.iconColor),
          if (showDays) ...[
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: config.textColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactBadge(_BadgeConfig config, ExpiryStatus status) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: config.iconColor,
        shape: BoxShape.circle,
      ),
    );
  }

  _BadgeConfig _getBadgeConfig(ExpiryStatus status) {
    switch (status) {
      case ExpiryStatus.expired:
        return _BadgeConfig(
          icon: Icons.error,
          iconColor: AppColors.error,
          textColor: AppColors.error,
          backgroundColor: AppColors.error,
          borderColor: AppColors.error,
        );
      case ExpiryStatus.expiringToday:
        return _BadgeConfig(
          icon: Icons.warning,
          iconColor: AppColors.warning,
          textColor: AppColors.warning,
          backgroundColor: AppColors.warning,
          borderColor: AppColors.warning,
        );
      case ExpiryStatus.nearExpiry:
        return _BadgeConfig(
          icon: Icons.schedule,
          iconColor: AppColors.warning,
          textColor: AppColors.warning,
          backgroundColor: AppColors.warning,
          borderColor: AppColors.warning,
        );
      case ExpiryStatus.good:
        return _BadgeConfig(
          icon: Icons.check_circle,
          iconColor: AppColors.success,
          textColor: AppColors.success,
          backgroundColor: AppColors.success,
          borderColor: AppColors.success,
        );
      case ExpiryStatus.noExpiry:
        return _BadgeConfig(
          icon: Icons.remove_circle,
          iconColor: AppColors.textHint,
          textColor: AppColors.textSecondary,
          backgroundColor: AppColors.background,
          borderColor: AppColors.outline,
        );
    }
  }
}

class _BadgeConfig {
  final IconData icon;
  final Color iconColor;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;

  _BadgeConfig({
    required this.icon,
    required this.iconColor,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
  });
}

/// Widget hiển thị thông tin hạn sử dụng chi tiết
/// Dùng trong màn hình chi tiết sản phẩm
class ExpiryInfoCard extends StatelessWidget {
  final Product product;
  final int? warningDays;
  final VoidCallback? onTap;

  const ExpiryInfoCard({
    super.key,
    required this.product,
    this.warningDays,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (product.expiryDate == null) return const SizedBox.shrink();

    final service = ExpiryAlertService();
    final status = service.getExpiryStatus(product, warningDays: warningDays);
    final days = service.daysUntilExpiry(product);
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(product.expiryDate!);

    return Card(
      elevation: 0,
      color: _getCardColor(status),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _getBorderColor(status)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getIconBgColor(status),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIcon(status),
                  color: _getIconColor(status),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTitle(status),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _getTextColor(status),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'HSD: ${_formatDate(expiryDate)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (product.batchNumber != null &&
                        product.batchNumber!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Lô: ${product.batchNumber}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    status == ExpiryStatus.expired
                        ? '${-days}'
                        : '$days',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _getTextColor(status),
                    ),
                  ),
                  Text(
                    status == ExpiryStatus.expired ? 'ngày trước' : 'ngày',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _getTitle(ExpiryStatus status) {
    switch (status) {
      case ExpiryStatus.expired:
        return '⛔ ĐÃ HẾT HẠN';
      case ExpiryStatus.expiringToday:
        return '🔥 HẾT HẠN HÔM NAY';
      case ExpiryStatus.nearExpiry:
        return '⚠️ SẮP HẾT HẠN';
      case ExpiryStatus.good:
        return '✅ CÒN HẠN';
      case ExpiryStatus.noExpiry:
        return 'Không có HSD';
    }
  }

  IconData _getIcon(ExpiryStatus status) {
    switch (status) {
      case ExpiryStatus.expired:
        return Icons.error;
      case ExpiryStatus.expiringToday:
        return Icons.local_fire_department;
      case ExpiryStatus.nearExpiry:
        return Icons.schedule;
      case ExpiryStatus.good:
        return Icons.check_circle;
      case ExpiryStatus.noExpiry:
        return Icons.remove_circle;
    }
  }

  Color _getCardColor(ExpiryStatus status) {
    switch (status) {
      case ExpiryStatus.expired:
        return AppColors.error;
      case ExpiryStatus.expiringToday:
        return AppColors.warning;
      case ExpiryStatus.nearExpiry:
        return AppColors.warning;
      case ExpiryStatus.good:
        return AppColors.success;
      case ExpiryStatus.noExpiry:
        return AppColors.background;
    }
  }

  Color _getBorderColor(ExpiryStatus status) {
    switch (status) {
      case ExpiryStatus.expired:
        return AppColors.error;
      case ExpiryStatus.expiringToday:
        return AppColors.warning;
      case ExpiryStatus.nearExpiry:
        return AppColors.warning;
      case ExpiryStatus.good:
        return AppColors.success;
      case ExpiryStatus.noExpiry:
        return AppColors.outline;
    }
  }

  Color _getIconBgColor(ExpiryStatus status) {
    switch (status) {
      case ExpiryStatus.expired:
        return AppColors.error;
      case ExpiryStatus.expiringToday:
        return AppColors.warning;
      case ExpiryStatus.nearExpiry:
        return AppColors.warning;
      case ExpiryStatus.good:
        return AppColors.success;
      case ExpiryStatus.noExpiry:
        return AppColors.background;
    }
  }

  Color _getIconColor(ExpiryStatus status) {
    switch (status) {
      case ExpiryStatus.expired:
        return AppColors.error;
      case ExpiryStatus.expiringToday:
        return AppColors.warning;
      case ExpiryStatus.nearExpiry:
        return AppColors.warning;
      case ExpiryStatus.good:
        return AppColors.success;
      case ExpiryStatus.noExpiry:
        return AppColors.textHint;
    }
  }

  Color _getTextColor(ExpiryStatus status) {
    switch (status) {
      case ExpiryStatus.expired:
        return AppColors.error;
      case ExpiryStatus.expiringToday:
        return AppColors.warning;
      case ExpiryStatus.nearExpiry:
        return AppColors.warning;
      case ExpiryStatus.good:
        return AppColors.success;
      case ExpiryStatus.noExpiry:
        return AppColors.textSecondary;
    }
  }
}

/// Widget hiển thị thống kê hạn sử dụng
/// Dùng trên màn hình Home hoặc Dashboard
class ExpiryStatsWidget extends StatelessWidget {
  final ExpiryStats stats;
  final VoidCallback? onViewAll;

  const ExpiryStatsWidget({
    super.key,
    required this.stats,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onViewAll,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.timer,
                      color: AppColors.warning,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Hạn sử dụng',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (onViewAll != null)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppColors.textHint,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      '⛔ Hết hạn',
                      stats.expiredCount,
                      AppColors.error,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      '⚠️ Sắp hết',
                      stats.nearExpiryCount,
                      AppColors.warning,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      '✅ Còn hạn',
                      stats.goodCount,
                      AppColors.success,
                    ),
                  ),
                ],
              ),
              if (stats.valueAtRisk > 0) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Giá trị gặp rủi ro: ${_formatCurrency(stats.valueAtRisk)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: count > 0 ? color : AppColors.textHint,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatCurrency(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return '$amount đ';
  }
}
