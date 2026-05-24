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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icon box with frosted glass effect
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.phone_android_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (code.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.qr_code_rounded,
                                  size: 11,
                                  color: Colors.white.withValues(alpha: 0.65)),
                              const SizedBox(width: 4),
                              Text(
                                code,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.8), size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
