import 'package:flutter/material.dart';

import '../constants/financial_constants.dart';
import '../services/bulk_debt_payment_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/money_utils.dart';
import 'responsive_wrapper.dart';
import 'currency_text_field.dart';
import 'keyboard_aware_padding.dart';

/// Bảng "Thu / Trả GỘP công nợ" — dùng chung cho màn Công nợ và tab Nợ ở
/// Tài chính.
///
/// Tách khỏi `debt_view` vì tab Nợ trong Tài chính trước đây chỉ có nút
/// *"Đi thu nợ / Đi trả nợ"* đẩy sang màn Công nợ, rồi người dùng phải **tự tìm
/// lại đúng nhà cung cấp đó** và bấm trả thêm một lần nữa — ba nhịp cho một
/// việc. Nay cả hai nơi mở chung đúng bảng này, trả ngay tại chỗ.
class BulkDebtPaymentSheet {
  BulkDebtPaymentSheet._();

  static Future<bool> show(
    BuildContext context, {
    required String personName,
    required List<Map<String, dynamic>> debts,
    required bool isReceivable,
  }) async {
    final activeDebts = debts
        .where((d) => BulkDebtPaymentService.remainingOf(d) > 0)
        .toList();
    if (activeDebts.isEmpty) return false;
    final remainingTotal = activeDebts.fold<int>(
      0,
      (s, d) => s + BulkDebtPaymentService.remainingOf(d),
    );

    final amountCtrl = TextEditingController(
      text: MoneyUtils.formatCurrency(remainingTotal),
    );
    var method = 'TIỀN MẶT';
    final color = isReceivable ? Colors.red.shade700 : Colors.blue.shade700;

    final confirmed = await showAppBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final typed = MoneyUtils.parseCurrency(amountCtrl.text);
          final over = typed > remainingTotal;
          final allocations = BulkDebtPaymentService.allocateFifo(
            activeDebts,
            typed > remainingTotal ? remainingTotal : typed,
          );
          return KeyboardAwarePadding(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isReceivable ? 'THU GỘP CÔNG NỢ' : 'TRẢ GỘP CÔNG NỢ',
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    '${personName} · ${activeDebts.length} khoản · còn nợ '
                    '${MoneyUtils.formatCurrency(remainingTotal)}đ',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 14),
                  CurrencyTextField(
                    controller: amountCtrl,
                    label: 'Số tiền',
                    onChanged: (_) => setSheet(() {}),
                  ),
                  if (over)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Số tiền vượt tổng nợ — sẽ chỉ ghi tối đa '
                        '${MoneyUtils.formatCurrency(remainingTotal)}đ.',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final m in const ['TIỀN MẶT', 'CHUYỂN KHOẢN'])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(m),
                            selected: method == m,
                            onSelected: (_) => setSheet(() => method = m),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tiền vào các khoản (cũ nhất trước):',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.28,
                    ),
                    child: allocations.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Nhập số tiền để xem cách chia.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.onSurface.withOpacity(0.5),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: allocations.length,
                            itemBuilder: (_, i) {
                              final a = allocations[i];
                              final note =
                                  (a.debt['note'] ?? '').toString().trim();
                              final done = a.amount >= a.remainingBefore;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        note.isEmpty
                                            ? 'Khoản ${i + 1}'
                                            : note,
                                        style: AppTextStyles.caption,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      MoneyUtils.formatCompactCurrency(
                                        a.amount,
                                      ),
                                      style: AppTextStyles.caption.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      done ? 'hết nợ' : 'còn lại',
                                      style: AppTextStyles.caption.copyWith(
                                        color: done
                                            ? Colors.green.shade700
                                            : AppColors.onSurface.withOpacity(
                                                0.5,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Hủy'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: allocations.isEmpty
                              ? null
                              : () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(46),
                          ),
                          child: Text(
                            '${isReceivable ? "Thu" : "Trả"} '
                            '${MoneyUtils.formatCompactCurrency(allocations.fold<int>(0, (s, a) => s + a.amount))}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (confirmed != true || !context.mounted) return false;

    final typed = MoneyUtils.parseCurrency(amountCtrl.text);
    final allocations = BulkDebtPaymentService.allocateFifo(
      activeDebts,
      typed > remainingTotal ? remainingTotal : typed,
    );
    final result = await BulkDebtPaymentService.execute(
      allocations: allocations,
      paymentMethod: method == 'CHUYỂN KHOẢN'
          ? PaymentMethod.transfer
          : PaymentMethod.cash,
      note: isReceivable ? 'Thu gộp công nợ' : 'Trả gộp công nợ',
    );
    if (!context.mounted) return result.paidCount > 0;

    if (result.success) {
      NotificationService.showSnackBar(
        '${isReceivable ? "Đã thu" : "Đã trả"} '
        '${MoneyUtils.formatCurrency(result.paidTotal)}đ cho ${result.paidCount} khoản',
        color: Colors.green,
      );
    } else if (result.partiallyApplied) {
      // Trường hợp nguy hiểm nhất: tiền của mấy khoản đầu ĐÃ vào sổ thật.
      // Phải nói rõ đã ghi tới đâu, không báo "thất bại" chung chung.
      NotificationService.showSnackBar(
        'Đã ghi ${result.paidCount}/${result.plannedCount} khoản '
        '(${MoneyUtils.formatCurrency(result.paidTotal)}đ) rồi dừng: '
        '${result.errorMessage}',
        color: Colors.orange,
      );
    } else {
      NotificationService.showSnackBar(
        'Không ghi được: ${result.errorMessage}',
        color: Colors.red,
      );
    }
    return result.paidCount > 0;
  }
}
