import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

import '../theme/app_text_styles.dart';
import '../theme/app_spacing.dart';
import '../theme/design_tokens.dart';
import 'deep_link_navigator.dart';
import 'entity_avatar.dart';

class ClickableCustomerHeader extends StatelessWidget {
  final String customerName;
  final String phoneNumber;
  final String? customerId;
  final String? avatarUrl;
  final String? sourceEvent;
  final String tooltip;

  const ClickableCustomerHeader({
    super.key,
    required this.customerName,
    required this.phoneNumber,
    this.customerId,
    this.avatarUrl,
    this.sourceEvent,
    this.tooltip = 'Xem hồ sơ khách hàng',
  });

  @override
  Widget build(BuildContext context) {
    final cleanName = customerName.trim();
    final cleanPhone = phoneNumber.trim();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              DeepLinkNavigator.openCustomerProfile(
                context,
                customerId: customerId,
                phoneNumber: cleanPhone,
                normalizedName: cleanName,
                sourceEvent: sourceEvent,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  EntityAvatar(
                    imageUrl: avatarUrl,
                    name: cleanName.isEmpty ? 'Khách hàng' : cleanName,
                    radius: DesignTokens.iconMd,
                  ),
                  AppSpacing.hSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cleanName.isEmpty ? 'Khách hàng' : cleanName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.subtitle1.copyWith(
                            color: const Color(0xFF2962FF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (cleanPhone.isNotEmpty)
                          Text(
                            cleanPhone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  AppSpacing.hXs,
                  Icon(
                    Icons.open_in_new,
                    size: DesignTokens.iconSm,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
