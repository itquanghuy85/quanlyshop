import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ReceiptShareTarget { customer, internal }

/// Bottom sheet cho nhân viên chọn đích chia sẻ ảnh biên nhận/phiếu sửa:
/// gửi cho khách (share sheet hệ thống — Zalo, Messenger, lưu ảnh...) hay
/// đăng thẳng vào chat nội bộ shop. Trả về null nếu người dùng huỷ (bấm ra
/// ngoài/kéo xuống) — caller phải dừng lại, không tự ý chọn đích mặc định.
Future<ReceiptShareTarget?> showShareReceiptTargetSheet(BuildContext context) {
  return showModalBottomSheet<ReceiptShareTarget>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _ShareReceiptTargetSheet(),
  );
}

class _ShareReceiptTargetSheet extends StatelessWidget {
  const _ShareReceiptTargetSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Chia sẻ ảnh',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _ShareOption(
              icon: Icons.ios_share_rounded,
              iconColor: AppColors.primary,
              iconBg: AppColors.primarySurface,
              title: 'Gửi cho khách',
              subtitle: 'Qua Zalo, Messenger, lưu ảnh...',
              onTap: () => Navigator.pop(context, ReceiptShareTarget.customer),
            ),
            _ShareOption(
              icon: Icons.forum_rounded,
              iconColor: AppColors.success,
              iconBg: AppColors.successLight,
              title: 'Gửi nội bộ',
              subtitle: 'Đăng thẳng vào chat nội bộ shop',
              onTap: () => Navigator.pop(context, ReceiptShareTarget.internal),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
