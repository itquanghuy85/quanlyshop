import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import 'deep_link_navigator.dart';

class ClickableCustomerChip extends StatelessWidget {
  final String customerName;
  final String phoneNumber;
  final String? customerId;
  final String? sourceEvent;
  final String tooltip;

  const ClickableCustomerChip({
    super.key,
    required this.customerName,
    required this.phoneNumber,
    this.customerId,
    this.sourceEvent,
    this.tooltip = 'Mở hồ sơ khách hàng',
  });

  @override
  Widget build(BuildContext context) {
    final cleanName = customerName.trim();
    final cleanPhone = phoneNumber.trim();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: tooltip,
        child: ActionChip(
          avatar: const Icon(Icons.person, size: 16),
          label: Text(
            cleanPhone.isEmpty ? cleanName : '$cleanName • $cleanPhone',
            style: AppTextStyles.body2,
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: () {
            DeepLinkNavigator.openCustomerProfile(
              context,
              customerId: customerId,
              phoneNumber: cleanPhone,
              normalizedName: cleanName,
              sourceEvent: sourceEvent,
            );
          },
        ),
      ),
    );
  }
}
