import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

import '../theme/app_text_styles.dart';
import '../theme/app_spacing.dart';
import '../theme/design_tokens.dart';
import 'deep_link_navigator.dart';

class ClickableProductChip extends StatelessWidget {
  final String displayName;
  final String? productId;
  final String? imeiOrSerial;
  final String? sku;
  final String? imageUrl;
  final String? sourceEvent;
  final String tooltip;

  const ClickableProductChip({
    super.key,
    required this.displayName,
    this.productId,
    this.imeiOrSerial,
    this.sku,
    this.imageUrl,
    this.sourceEvent,
    this.tooltip = 'Xem chi tiết sản phẩm',
  });

  @override
  Widget build(BuildContext context) {
    final code = (imeiOrSerial ?? '').trim();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              DeepLinkNavigator.openProductDetail(
                context,
                productId: productId,
                imei: code,
                serial: code,
                sku: sku,
                fallbackName: displayName,
                sourceEvent: sourceEvent,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary),
                color: AppColors.primary,
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: DesignTokens.iconSm, color: AppColors.surface),
                  AppSpacing.hSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body1.copyWith(
                            color: AppColors.surface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (code.isNotEmpty)
                          Text(
                            code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.surface.withAlpha(179),
                            ),
                          ),
                      ],
                    ),
                  ),
                  AppSpacing.hXs,
                  Icon(Icons.arrow_forward_ios, size: DesignTokens.iconSm - 4, color: AppColors.surface.withAlpha(204)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
