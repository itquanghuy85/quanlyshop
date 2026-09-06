import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants/financial_constants.dart';
import '../models/payment_intent_model.dart';
import '../utils/money_utils.dart';
import 'audit_service.dart';
import 'event_bus.dart';
import 'notification_service.dart';
import 'payment_intent_service.dart';

/// Một khoản được phân bổ trong lần trả gộp.
class BulkDebtAllocation {
  BulkDebtAllocation({
    required this.debt,
    required this.amount,
    required this.remainingBefore,
  });

  /// Bản ghi gốc trong bảng `debts`.
  final Map<String, dynamic> debt;

  /// Số tiền dồn vào khoản này trong lần trả gộp.
  final int amount;

  /// Còn nợ của riêng khoản này TRƯỚC khi trả.
  final int remainingBefore;

  String get personName => (debt['personName'] ?? '').toString();
  String? get firestoreId => debt['firestoreId']?.toString();
}

/// Kết quả một lần trả gộp.
class BulkDebtPaymentResult {
  BulkDebtPaymentResult({
    required this.paidTotal,
    required this.paidCount,
    required this.plannedTotal,
    required this.plannedCount,
    this.errorMessage,
  });

  final int paidTotal;
  final int paidCount;
  final int plannedTotal;
  final int plannedCount;
  final String? errorMessage;

  bool get success => errorMessage == null && paidCount == plannedCount;

  /// Đã ghi được một phần rồi mới hỏng — trường hợp NGUY HIỂM NHẤT, phải nói
  /// rõ cho người dùng chứ không được báo "thất bại" chung chung: tiền của
  /// những khoản trước đó ĐÃ ghi vào sổ thật.
  bool get partiallyApplied => paidCount > 0 && paidCount < plannedCount;
}

/// Trả / thu **một cục** cho nhiều khoản nợ của cùng một người.
///
/// Vì sao cần: một nhà cung cấp thường có hàng chục khoản nợ lẻ (mỗi lần nhập
/// hàng một khoản). Trả tiền thực tế thì trả một cục, không ai ngồi bấm trả
/// từng khoản. Trước đây màn Công nợ chỉ cho trả **từng khoản một**.
///
/// **KHÔNG tự viết logic ghi tiền.** Mỗi khoản vẫn đi qua đúng
/// `PaymentIntentService.executePaymentDirect` mà `DebtPaymentSheet` đang dùng
/// (kèm audit log, thông báo cho cả shop, `EventBus('debts_changed')`) — công
/// nợ đã có lịch sử lệch số vì mỗi nơi tự ghi một kiểu, xem `[2026-08-30d]`.
/// Ở đây chỉ thêm phần **chia tiền** và **báo cáo trung thực** khi hỏng giữa
/// chừng.
class BulkDebtPaymentService {
  BulkDebtPaymentService._();

  static bool isPayable(String debtType) {
    final t = debtType.trim().toUpperCase();
    return t == 'SHOP_OWES' ||
        t == 'OTHER_SHOP_OWES' ||
        t == 'OWED' ||
        t == 'REPAIR_PARTNER';
  }

  static int remainingOf(Map<String, dynamic> debt) {
    final total = (debt['totalAmount'] as num?)?.toInt() ?? 0;
    final paid = (debt['paidAmount'] as num?)?.toInt() ?? 0;
    final remain = total - paid;
    return remain > 0 ? remain : 0;
  }

  /// Chia [amount] vào [debts] theo FIFO — khoản **cũ nhất trả trước**.
  ///
  /// Hàm thuần: không đụng DB, không sửa list gốc. Trả về đúng phần chia được;
  /// nếu [amount] lớn hơn tổng nợ thì phần dư bị bỏ (nơi gọi phải chặn trước và
  /// báo cho người dùng, đừng im lặng nuốt tiền thừa).
  static List<BulkDebtAllocation> allocateFifo(
    List<Map<String, dynamic>> debts,
    int amount,
  ) {
    final sorted = [...debts]..sort((a, b) {
      final ax = (a['createdAt'] as num?)?.toInt() ?? 0;
      final bx = (b['createdAt'] as num?)?.toInt() ?? 0;
      return ax.compareTo(bx);
    });
    final out = <BulkDebtAllocation>[];
    var left = amount;
    for (final d in sorted) {
      if (left <= 0) break;
      final remain = remainingOf(d);
      if (remain <= 0) continue;
      final take = remain < left ? remain : left;
      out.add(
        BulkDebtAllocation(debt: d, amount: take, remainingBefore: remain),
      );
      left -= take;
    }
    return out;
  }

  /// Ghi lần lượt từng khoản đã phân bổ.
  ///
  /// **Dừng ngay khi một khoản hỏng.** Cố chạy tiếp sẽ rải lỗi ra nhiều bản ghi
  /// mà người dùng không lần được đã ghi tới đâu; dừng sớm thì phần đã ghi là
  /// một tiền tố liên tục, đối chiếu lại được.
  static Future<BulkDebtPaymentResult> execute({
    required List<BulkDebtAllocation> allocations,
    required PaymentMethod paymentMethod,
    String? note,
  }) async {
    final planned = allocations.where((a) => a.amount > 0).toList();
    final plannedTotal = planned.fold<int>(0, (s, a) => s + a.amount);
    if (planned.isEmpty) {
      return BulkDebtPaymentResult(
        paidTotal: 0,
        paidCount: 0,
        plannedTotal: 0,
        plannedCount: 0,
        errorMessage: 'Chưa phân bổ được khoản nào',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    final by = user?.displayName ?? user?.email ?? 'unknown';

    var paidTotal = 0;
    var paidCount = 0;
    String? error;

    for (final a in planned) {
      // Chặn lại lần cuối ngay trước khi ghi: số dư có thể đã đổi do máy khác
      // vừa trả cùng khoản này trong lúc người dùng đang gõ số tiền.
      if (a.amount > a.remainingBefore) {
        error = 'Số tiền của một khoản vượt quá số nợ còn lại của khoản đó';
        break;
      }
      final debtType = (a.debt['type'] ?? '').toString();
      if (debtType.trim().isEmpty) {
        // Giống `DebtPaymentSheet`: thiếu `type` là không biết chiều thu hay
        // trả — ghi sai chiều dòng tiền nguy hiểm hơn dừng lại.
        error = 'Một khoản không xác định được loại công nợ (thu/trả)';
        break;
      }
      final isCustomerDebt = !isPayable(debtType);

      try {
        final result = await PaymentIntentService.executePaymentDirect(
          type: isCustomerDebt
              ? PaymentIntentType.customerDebtCollection
              : PaymentIntentType.supplierDebt,
          amount: a.amount,
          paymentMethod: paymentMethod,
          description: isCustomerDebt
              ? 'Thu nợ: ${a.personName}'
              : 'Trả nợ: ${a.personName}',
          executedBy: by,
          referenceId: a.firestoreId,
          referenceType: 'debt',
          personName: a.personName,
          personPhone: a.debt['phone']?.toString(),
          notes: note,
          idempotencyKey:
              '${a.firestoreId ?? a.debt['id']}_${DateTime.now().millisecondsSinceEpoch}_$paidCount',
          metadata: {
            'debtId': a.debt['id'],
            'debtFirestoreId': a.debt['firestoreId'],
            'debtType': debtType,
            'linkedId': a.debt['linkedId'],
            'bulkPayment': true,
          },
        );

        if (!result.success) {
          error = result.errorMessage ?? 'Ghi nhận thanh toán thất bại';
          break;
        }

        paidTotal += a.amount;
        paidCount++;

        await AuditService.logAction(
          action: isCustomerDebt ? 'DEBT_COLLECTED' : 'SUPPLIER_PAID',
          entityType: 'DEBT',
          entityId: a.firestoreId ?? '',
          summary:
              '${isCustomerDebt ? "Thu nợ" : "Thanh toán nợ"} ${a.personName}: '
              '${MoneyUtils.formatCurrency(a.amount)}đ (trả gộp)',
        );
        // ignore: unawaited_futures
        NotificationService.notifyDebtActivity(
          action: isCustomerDebt ? 'collect' : 'pay',
          personName: a.personName,
          amount: a.amount,
          by: user?.displayName ?? user?.email?.split('@').first,
          debtFirestoreId: a.firestoreId,
        );
      } catch (e) {
        debugPrint('BulkDebtPaymentService.execute error: $e');
        error = e.toString();
        break;
      }
    }

    if (paidCount > 0) {
      EventBus().emit('debts_changed');
      EventBus().emit(EventBus.financialChanged);
    }

    return BulkDebtPaymentResult(
      paidTotal: paidTotal,
      paidCount: paidCount,
      plannedTotal: plannedTotal,
      plannedCount: planned.length,
      errorMessage: error,
    );
  }
}
