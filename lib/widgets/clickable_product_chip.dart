import 'package:flutter/material.dart';
import '../utils/money_utils.dart';
import 'deep_link_navigator.dart';

class ClickableProductChip extends StatelessWidget {
  final String displayName;
  final String? productId;
  final String? imeiOrSerial;
  final String? sku;
  final String? imageUrl;
  final String? sourceEvent;
  final String tooltip;
  final int? soldQty;
  final int? soldPrice;
  final int? salePrice;
  final String? soldImei;

  const ClickableProductChip({
    super.key,
    required this.displayName,
    this.productId,
    this.imeiOrSerial,
    this.sku,
    this.imageUrl,
    this.sourceEvent,
    this.tooltip = 'Xem chi tiết sản phẩm',
    this.soldQty,
    this.soldPrice,
    this.salePrice,
    this.soldImei,
  });

  @override
  Widget build(BuildContext context) {
    final code = (imeiOrSerial ?? '').trim();
    final theme = Theme.of(context);
    final hasCode = code.isNotEmpty;
    final hasQty = soldQty != null;
    final hasPrice = soldPrice != null && soldPrice! > 0;
    final itemDiscount = (salePrice != null && soldPrice != null && salePrice! > soldPrice!)
        ? (salePrice! - soldPrice!) * (soldQty ?? 1)
        : 0;
    final hasDiscount = itemDiscount > 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              DeepLinkNavigator.openProductDetail(
                context,
                productId: productId,
                imei: code,
                serial: code,
                sku: sku,
                fallbackName: displayName,
                sourceEvent: sourceEvent,
                soldQty: soldQty,
                soldPrice: soldPrice,
                salePrice: salePrice,
                soldImei: soldImei,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5EAF2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6FB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.phone_android_rounded,
                      color: Color(0xFF3F4F63),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF162230),
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            height: 1.2,
                          ),
                        ),
                        if (hasCode || hasQty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (hasCode) ...[
                                Icon(
                                  Icons.qr_code_rounded,
                                  size: 11,
                                  color: theme.colorScheme.primary.withValues(alpha: 0.75),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  code,
                                  style: const TextStyle(
                                    color: Color(0xFF5B697A),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (hasQty) const SizedBox(width: 6),
                              ],
                              if (hasQty) ...[
                                const Icon(Icons.shopping_cart_outlined, size: 11, color: Color(0xFF1565C0)),
                                const SizedBox(width: 2),
                                Text(
                                  'x$soldQty',
                                  style: const TextStyle(
                                    color: Color(0xFF1565C0),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hasPrice || hasDiscount) ...[
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasPrice)
                          Text(
                            MoneyUtils.formatCompactCurrency(soldPrice!),
                            style: const TextStyle(
                              color: Color(0xFF1565C0),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (hasDiscount)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.orange.shade300,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              '-${MoneyUtils.formatCompactCurrency(itemDiscount)}',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFB0BEC5),
                    size: 16,
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
