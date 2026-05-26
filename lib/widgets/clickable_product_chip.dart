import 'package:flutter/material.dart';
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
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5EAF2)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B1A2A).withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6FB),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.phone_android_rounded,
                      color: Color(0xFF3F4F63),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF162230),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.2,
                          ),
                        ),
                        if (code.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.qr_code_rounded,
                                size: 12,
                                color: theme.colorScheme.primary.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                code,
                                style: TextStyle(
                                  color: const Color(0xFF5B697A),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FC),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF6D7D91),
                      size: 18,
                    ),
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
