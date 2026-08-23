import 'package:flutter/material.dart';
import '../utils/money_utils.dart';
import '../theme/app_text_styles.dart';

enum PaymentResultState { success, failure, queued }

class PaymentResultSheet extends StatelessWidget {
  final PaymentResultState state;
  final int? amount;
  final String? paymentMethod;
  final String? personName;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool isCollecting;
  final VoidCallback? onShareReceipt;

  const PaymentResultSheet({
    super.key,
    required this.state,
    this.amount,
    this.paymentMethod,
    this.personName,
    this.errorMessage,
    this.onRetry,
    this.isCollecting = true,
    this.onShareReceipt,
  });

  static Future<void> show({
    required BuildContext context,
    required PaymentResultState state,
    int? amount,
    String? paymentMethod,
    String? personName,
    String? errorMessage,
    VoidCallback? onRetry,
    bool isCollecting = true,
    VoidCallback? onShareReceipt,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentResultSheet(
        state: state,
        amount: amount,
        paymentMethod: paymentMethod,
        personName: personName,
        errorMessage: errorMessage,
        onRetry: onRetry,
        isCollecting: isCollecting,
        onShareReceipt: onShareReceipt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config();
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad > 0 ? bottomPad + 8 : 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // State icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cfg.iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(cfg.icon, color: cfg.iconColor, size: 32),
          ),
          const SizedBox(height: 14),

          // Title
          Text(cfg.title, style: AppTextStyles.headline3.copyWith(color: cfg.iconColor, fontSize: 16)),
          const SizedBox(height: 4),

          // Subtitle / error
          if (state == PaymentResultState.failure && errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                errorMessage!,
                style: AppTextStyles.body1.copyWith(color: Colors.red.shade700),
                textAlign: TextAlign.center,
              ),
            ),

          if (state != PaymentResultState.failure) ...[
            const SizedBox(height: 16),

            // Amount row
            if (amount != null && amount! > 0)
              _infoRow(
                Icons.payments_rounded,
                '${MoneyUtils.formatCurrency(amount!)}đ',
                bold: true,
                color: state == PaymentResultState.success
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
              ),

            // Payment method
            if (paymentMethod != null && paymentMethod!.isNotEmpty)
              _infoRow(
                paymentMethod == 'CHUYỂN KHOẢN'
                    ? Icons.account_balance_rounded
                    : Icons.money_rounded,
                paymentMethod!,
              ),

            // Person
            if (personName != null && personName!.isNotEmpty)
              _infoRow(Icons.person_outline_rounded, personName!),
          ],

          // Queued explanation
          if (state == PaymentResultState.queued)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Giao dịch sẽ được xử lý khi kết nối mạng ổn định.',
                style: AppTextStyles.caption.copyWith(color: Colors.orange.shade600),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 24),

          // Chia sẻ ảnh biên nhận (chỉ hiện khi caller truyền callback, vd.
          // ngay sau khi tạo đơn bán — không ảnh hưởng các nơi gọi khác như
          // thu công nợ vì mặc định null).
          if (onShareReceipt != null && state != PaymentResultState.failure) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onShareReceipt!();
                },
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Chia sẻ ảnh biên nhận'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cfg.iconColor,
                  side: BorderSide(color: cfg.iconColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Actions
          Row(
            children: [
              if (state == PaymentResultState.failure && onRetry != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onRetry!();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Thử lại'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cfg.iconColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(state == PaymentResultState.failure ? 'Đóng' : 'Xong'),
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

  Widget _infoRow(IconData icon, String text, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.body1.copyWith(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  _Cfg _config() {
    switch (state) {
      case PaymentResultState.success:
        return _Cfg(
          icon: Icons.check_circle_rounded,
          iconColor: Colors.green.shade700,
          iconBg: Colors.green.shade50,
          title: isCollecting ? 'Đã thu tiền thành công' : 'Đã thanh toán thành công',
        );
      case PaymentResultState.failure:
        return _Cfg(
          icon: Icons.error_rounded,
          iconColor: Colors.red.shade700,
          iconBg: Colors.red.shade50,
          title: 'Giao dịch thất bại',
        );
      case PaymentResultState.queued:
        return _Cfg(
          icon: Icons.cloud_off_rounded,
          iconColor: Colors.orange.shade700,
          iconBg: Colors.orange.shade50,
          title: 'Đã ghi nhận — chờ đồng bộ',
        );
    }
  }
}

class _Cfg {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  const _Cfg({required this.icon, required this.iconColor, required this.iconBg, required this.title});
}
