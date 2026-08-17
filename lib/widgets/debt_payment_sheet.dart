import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/app_localizations.dart';
import '../utils/money_utils.dart';
import '../widgets/currency_text_field.dart';
import '../services/payment_intent_service.dart';
import '../models/payment_intent_model.dart';
import '../services/audit_service.dart';
import '../services/adjustment_service.dart';
import '../services/event_bus.dart';
import '../services/notification_service.dart';
import '../constants/financial_constants.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_colors.dart';
import '../theme/popup_theme.dart';
import '../widgets/app_popup.dart';
import '../widgets/payment_result_sheet.dart';

/// Sheet thanh toán/thu nợ thống nhất — dùng chung toàn bộ ứng dụng.
/// Nhận debt map từ bảng debts (hoặc virtual map có cùng cấu trúc).
/// Trả về true nếu thanh toán thành công.
class DebtPaymentSheet {
  // Các type mà shop phải trả (payable).
  static bool _isPayable(String debtType) =>
      debtType == 'SHOP_OWES' ||
      debtType == 'OTHER_SHOP_OWES' ||
      debtType == 'OWED' ||
      debtType == 'REPAIR_PARTNER';

  static Future<bool> show(
    BuildContext context,
    Map<String, dynamic> debt, {
    VoidCallback? onSuccess,
  }) async {
    final l10n = AppLocalizations.of(context)!;

    final today = DateTime.now();
    final canEdit = await AdjustmentService.canEditDirectly(today.millisecondsSinceEpoch);
    if (!canEdit) {
      if (context.mounted) {
        NotificationService.showSnackBar(l10n.closedTodayDebt, color: Colors.red);
      }
      return false;
    }

    final int totalAmount = (debt['totalAmount'] as num?)?.toInt() ?? 0;
    final int paidAmount = (debt['paidAmount'] as num?)?.toInt() ?? 0;
    final int remaining = totalAmount - paidAmount;
    final String debtType = (debt['type'] as String?)?.trim() ?? '';
    // Trước đây thiếu 'type' âm thầm mặc định về CUSTOMER_OWES (thu nợ) —
    // hướng đi ngược hoàn toàn nếu bản ghi thật ra là nợ NCC (SHOP_OWES,
    // phải trả). Ghi sai chiều dòng tiền còn nguy hiểm hơn crash vì không
    // ai để ý ngay. Nên chặn hẳn thay vì đoán khi không rõ loại nợ.
    if (debtType.isEmpty) {
      if (context.mounted) {
        NotificationService.showSnackBar(
          'Không xác định được loại công nợ (thu/trả) — vui lòng mở lại từ danh sách công nợ',
          color: Colors.red,
        );
      }
      return false;
    }
    final bool isCustomerDebt = !_isPayable(debtType);

    if (remaining <= 0) {
      if (context.mounted) {
        NotificationService.showSnackBar('Khoản nợ đã thanh toán đủ', color: Colors.orange);
      }
      return false;
    }

    final formKey = GlobalKey<FormState>();
    final payC = TextEditingController();
    String payMethod = 'TIỀN MẶT';
    bool success = false;

    if (!context.mounted) return false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // Đã tự vẽ PopupDragHandle() riêng — tắt drag handle mặc định của theme
      // (bottomSheetTheme.showDragHandle=true) để tránh 2 lớp handle chồng
      // nhau ăn mất không gian, đẩy nút Hủy/Xác nhận ra ngoài vùng hiển thị
      // trên máy có màn hình thấp (đã xác nhận qua test thực tế).
      showDragHandle: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          // Cộng thêm viewPadding.bottom (vùng an toàn hệ thống/nav bar) —
          // chỉ cộng viewInsets (bàn phím) là chưa đủ trên máy có vùng điều
          // hướng lớn ở đáy, khiến nút Hủy/Xác nhận bị đẩy ra ngoài vùng
          // chạm được.
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom +
                MediaQuery.paddingOf(context).bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: PopupTheme.bgDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(PopupTheme.radiusSheet)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            // Cuộn toàn bộ nội dung (kể cả hàng nút) thay vì chỉ phần giữa: một
            // SingleChildScrollView lồng trong Flexible luôn giãn hết chiều cao
            // được cấp bất kể nội dung ngắn hay dài, đẩy nút Hủy/Xác nhận ra khỏi
            // màn hình trên các máy có vùng hệ thống lớn ở đáy. Cuộn cả khối đảm
            // bảo nút luôn chạm tới được bằng cách kéo xuống.
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PopupDragHandle(),
                    Text(
                      isCustomerDebt ? l10n.collectDebtTitle : l10n.payDebtTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: PopupTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: PopupTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(PopupTheme.radiusCard),
                        border: Border.all(color: PopupTheme.borderDark),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statCol(l10n.totalDebtLabel, totalAmount, Colors.grey.shade700),
                          _statCol(l10n.paidAmountLabel, paidAmount, Colors.green),
                          _statCol(l10n.remainingLabel, remaining, Colors.red),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    CurrencyTextField(
                      controller: payC,
                      label: isCustomerDebt ? l10n.collectAmountVnd : l10n.payAmountVnd,
                      validator: (v) => MoneyUtils.validateAmount(
                        v ?? '',
                        min: 1,
                        max: remaining,
                        fieldName: isCustomerDebt ? l10n.debtCollectFieldName : l10n.debtPayFieldName,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.payWithLabel,
                      style: AppTextStyles.overline.copyWith(color: AppColors.onSurface.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: ['TIỀN MẶT', 'CHUYỂN KHOẢN']
                          .map(
                            (m) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: ChoiceChip(
                                  label: Text(
                                    m == 'TIỀN MẶT' ? l10n.cash : l10n.bankTransfer,
                                    style: AppTextStyles.caption,
                                  ),
                                  selected: payMethod == m,
                                  onSelected: (_) => setS(() => payMethod = m),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              FocusManager.instance.primaryFocus?.unfocus();
                              await Future.delayed(Duration.zero);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: Text(l10n.cancelButton),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCustomerDebt ? PopupTheme.green : PopupTheme.blue,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              if (!(formKey.currentState?.validate() ?? false)) return;
                              final amount = MoneyUtils.parseCurrency(payC.text);
                              if (amount <= 0) return;
                              FocusManager.instance.primaryFocus?.unfocus();
                              await Future.delayed(Duration.zero);
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);

                              final user = FirebaseAuth.instance.currentUser;
                              final method = payMethod == 'CHUYỂN KHOẢN'
                                  ? PaymentMethod.transfer
                                  : PaymentMethod.cash;

                              final result = await PaymentIntentService.executePaymentDirect(
                                type: isCustomerDebt
                                    ? PaymentIntentType.customerDebtCollection
                                    : PaymentIntentType.supplierDebt,
                                amount: amount,
                                paymentMethod: method,
                                description: isCustomerDebt
                                    ? 'Thu nợ: ${debt['personName'] ?? ''}'
                                    : 'Trả nợ: ${debt['personName'] ?? ''}',
                                executedBy: user?.displayName ?? user?.email ?? 'unknown',
                                referenceId: debt['firestoreId']?.toString(),
                                referenceType: 'debt',
                                personName: debt['personName']?.toString(),
                                personPhone: debt['phone']?.toString(),
                                idempotencyKey:
                                    '${debt['firestoreId']}_${DateTime.now().millisecondsSinceEpoch}',
                                metadata: {
                                  'debtId': debt['id'],
                                  'debtFirestoreId': debt['firestoreId'],
                                  'debtType': debtType,
                                  'linkedId': debt['linkedId'],
                                },
                              );

                              success = result.success;

                              if (result.success) {
                                await AuditService.logAction(
                                  action: isCustomerDebt ? 'DEBT_COLLECTED' : 'SUPPLIER_PAID',
                                  entityType: 'DEBT',
                                  entityId: debt['firestoreId']?.toString() ?? '',
                                  summary:
                                      '${isCustomerDebt ? "Thu nợ" : "Thanh toán nợ"} ${debt['personName']}: ${MoneyUtils.formatCurrency(amount)}đ',
                                );
                                EventBus().emit('debts_changed');
                                onSuccess?.call();
                              }

                              if (context.mounted) {
                                await PaymentResultSheet.show(
                                  context: context,
                                  state: result.success
                                      ? PaymentResultState.success
                                      : PaymentResultState.failure,
                                  amount: result.success ? amount : null,
                                  paymentMethod: result.success ? payMethod : null,
                                  personName: debt['personName']?.toString(),
                                  isCollecting: isCustomerDebt,
                                  errorMessage: result.success
                                      ? null
                                      : (result.errorMessage ?? l10n.debtPaymentGenericError),
                                );
                              }
                            },
                            child: Text(l10n.confirmPayButton),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    payC.dispose();
    return success;
  }

  static Widget _statCol(String label, int amount, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: AppTextStyles.overlineSize, color: Colors.grey.shade600),
          ),
          Text(
            '${MoneyUtils.formatCurrency(amount)}đ',
            style: TextStyle(
              fontSize: AppTextStyles.caption.fontSize,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      );
}
