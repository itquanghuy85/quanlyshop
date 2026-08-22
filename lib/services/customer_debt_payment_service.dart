import '../constants/financial_constants.dart';
import '../models/payment_intent_model.dart';
import '../utils/money_utils.dart';
import 'adjustment_service.dart';
import 'audit_service.dart';
import 'debt_summary_service.dart';
import 'event_bus.dart';
import 'payment_intent_service.dart';

/// 1 khoản phân bổ tiền thu vào 1 đơn (1 dòng trong bảng debts) — dùng cho
/// luồng thu tiền gộp nhiều đơn của cùng 1 khách.
class DebtAllocation {
  final int debtId;
  final String? debtFirestoreId;
  final String? linkedId;
  final int remainingBefore;
  final int amount;

  DebtAllocation({
    required this.debtId,
    this.debtFirestoreId,
    this.linkedId,
    required this.remainingBefore,
    required this.amount,
  });

  DebtAllocation copyWith({int? amount}) => DebtAllocation(
    debtId: debtId,
    debtFirestoreId: debtFirestoreId,
    linkedId: linkedId,
    remainingBefore: remainingBefore,
    amount: amount ?? this.amount,
  );
}

class DebtAllocationResult {
  final DebtAllocation allocation;
  final bool success;
  final String? errorMessage;

  DebtAllocationResult({
    required this.allocation,
    required this.success,
    this.errorMessage,
  });
}

class CollectDebtResult {
  final bool success;
  final String paymentGroupId;
  final int totalCollected;
  final List<DebtAllocationResult> results;
  final String? errorMessage;

  CollectDebtResult({
    required this.success,
    required this.paymentGroupId,
    required this.totalCollected,
    required this.results,
    this.errorMessage,
  });
}

/// Thu tiền gộp nhiều đơn của cùng 1 khách (mô hình bán sỉ: nợ dồn qua nhiều
/// đơn, trả gộp sau). Tái dùng nguyên cơ chế 1-đơn đã có
/// (PaymentIntentService.executePaymentDirect, giống DebtPaymentSheet) —
/// lặp lại cho từng đơn trong danh sách phân bổ, gắn chung 1 paymentGroupId
/// để nhóm thành 1 phiếu thu khi hiển thị lịch sử/biên nhận. Không đổi
/// doanh thu — chỉ ghi vào debts/debt_payments như cơ chế hiện tại.
class CustomerDebtPaymentService {
  CustomerDebtPaymentService({DebtSummaryService? debtSummary})
    : _debtSummary = debtSummary ?? DebtSummaryService();

  final DebtSummaryService _debtSummary;

  /// Đề xuất phân bổ FIFO (đơn cũ nhất trước) cho [amount] trên danh sách nợ
  /// [debts] — thường là kết quả của DebtSummaryService.getCustomerActiveDebts
  /// (đã sort cũ nhất trước). Không sửa list gốc; không vượt số dư từng đơn,
  /// không vượt tổng [amount]. Đây chỉ là ĐỀ XUẤT — nhân viên có thể sửa tay.
  static List<DebtAllocation> suggestFifoAllocation(
    List<Map<String, dynamic>> debts,
    int amount,
  ) {
    final allocations = <DebtAllocation>[];
    var remainingToAllocate = amount;
    for (final d in debts) {
      if (remainingToAllocate <= 0) break;
      final total = (d['totalAmount'] as num?)?.toInt() ?? 0;
      final paid = (d['paidAmount'] as num?)?.toInt() ?? 0;
      final remain = total - paid;
      if (remain <= 0) continue;
      final take = remain < remainingToAllocate ? remain : remainingToAllocate;
      allocations.add(
        DebtAllocation(
          debtId: d['id'] as int,
          debtFirestoreId: d['firestoreId'] as String?,
          linkedId: d['linkedId'] as String?,
          remainingBefore: remain,
          amount: take,
        ),
      );
      remainingToAllocate -= take;
    }
    return allocations;
  }

  /// Thực hiện thu tiền, phân bổ vào nhiều đơn cùng lúc. Chặn nếu tổng phân
  /// bổ vượt tổng công nợ hiện tại của khách, hoặc 1 khoản phân bổ vượt số
  /// dư của đúng đơn đó (validate lại phía service, không chỉ tin UI).
  Future<CollectDebtResult> collectPayment({
    required String phone,
    required String personName,
    required List<DebtAllocation> allocations,
    required PaymentMethod paymentMethod,
    required String executedBy,
    String? note,
  }) async {
    final canEdit = await AdjustmentService.canEditDirectly(
      DateTime.now().millisecondsSinceEpoch,
    );
    if (!canEdit) {
      return CollectDebtResult(
        success: false,
        paymentGroupId: '',
        totalCollected: 0,
        results: const [],
        errorMessage: 'Ngày hôm nay đã bị khóa sổ, không thể ghi nhận thu tiền',
      );
    }

    final validAllocations = allocations.where((a) => a.amount > 0).toList();
    if (validAllocations.isEmpty) {
      return CollectDebtResult(
        success: false,
        paymentGroupId: '',
        totalCollected: 0,
        results: const [],
        errorMessage: 'Chưa phân bổ số tiền nào',
      );
    }
    for (final a in validAllocations) {
      if (a.amount > a.remainingBefore) {
        return CollectDebtResult(
          success: false,
          paymentGroupId: '',
          totalCollected: 0,
          results: const [],
          errorMessage: 'Số tiền phân bổ cho 1 đơn vượt quá số nợ còn lại của đơn đó',
        );
      }
    }

    final totalRequested = validAllocations.fold<int>(
      0,
      (sum, a) => sum + a.amount,
    );

    // Chặn thu vượt tổng công nợ hiện tại của khách (theo yêu cầu nghiệp vụ).
    final currentDebts = await _debtSummary.getCustomerActiveDebts(phone);
    final totalOutstanding = currentDebts.fold<int>(
      0,
      (sum, d) =>
          sum +
          (((d['totalAmount'] as num?)?.toInt() ?? 0) -
              ((d['paidAmount'] as num?)?.toInt() ?? 0)),
    );
    if (totalRequested > totalOutstanding) {
      return CollectDebtResult(
        success: false,
        paymentGroupId: '',
        totalCollected: 0,
        results: const [],
        errorMessage:
            'Số tiền thu (${MoneyUtils.formatCurrency(totalRequested)}đ) vượt quá tổng công nợ hiện tại (${MoneyUtils.formatCurrency(totalOutstanding)}đ)',
      );
    }

    final paymentGroupId = 'pg_${DateTime.now().millisecondsSinceEpoch}';
    final results = <DebtAllocationResult>[];
    int totalCollected = 0;

    for (final a in validAllocations) {
      final result = await PaymentIntentService.executePaymentDirect(
        type: PaymentIntentType.customerDebtCollection,
        amount: a.amount,
        paymentMethod: paymentMethod,
        description: 'Thu nợ gộp: $personName',
        executedBy: executedBy,
        referenceId: a.debtFirestoreId,
        referenceType: 'debt',
        personName: personName,
        personPhone: phone,
        notes: note,
        idempotencyKey: '${a.debtFirestoreId}_$paymentGroupId',
        metadata: {
          'debtId': a.debtId,
          'debtFirestoreId': a.debtFirestoreId,
          'debtType': 'CUSTOMER_OWES',
          'linkedId': a.linkedId,
          'paymentGroupId': paymentGroupId,
        },
      );
      results.add(
        DebtAllocationResult(
          allocation: a,
          success: result.success,
          errorMessage: result.errorMessage,
        ),
      );
      if (result.success) totalCollected += a.amount;
    }

    final allSucceeded = results.every((r) => r.success);

    if (totalCollected > 0) {
      await AuditService.logAction(
        action: 'DEBT_COLLECTED_MULTI',
        entityType: 'CUSTOMER',
        entityId: phone,
        summary:
            'Thu nợ gộp $personName: ${MoneyUtils.formatCurrency(totalCollected)}đ (${results.where((r) => r.success).length} đơn)',
        payload: {
          'paymentGroupId': paymentGroupId,
          'phone': phone,
          'allocations': validAllocations
              .map((a) => {'debtId': a.debtId, 'amount': a.amount})
              .toList(),
        },
      );
      EventBus().emit('debts_changed');
    }

    return CollectDebtResult(
      success: allSucceeded,
      paymentGroupId: paymentGroupId,
      totalCollected: totalCollected,
      results: results,
      errorMessage: allSucceeded
          ? null
          : 'Một số khoản phân bổ chưa ghi nhận được, vui lòng kiểm tra lại công nợ',
    );
  }
}
