import 'package:flutter/material.dart';

import 'clickable_product_chip.dart';
import 'deep_link_navigator.dart';

class ClickableProductList extends StatelessWidget {
  final List<ProductLinkRef> items;
  final String tooltip;

  const ClickableProductList({
    super.key,
    required this.items,
    this.tooltip = 'Bấm để xem chi tiết sản phẩm',
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ClickableProductChip(
                displayName: item.displayName,
                productId: item.productId,
                imeiOrSerial: item.imei ?? item.serial,
                sku: item.sku,
                imageUrl: item.imageUrl,
                sourceEvent: item.sourceEvent,
                tooltip: tooltip,
                soldQty: item.soldQty,
                soldPrice: item.soldPrice,
              ),
            ),
          )
          .toList(),
    );
  }
}
