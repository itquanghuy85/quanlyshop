import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants/financial_constants.dart';
import '../data/db_helper.dart';
import '../models/payment_intent_model.dart';
import '../models/sale_order_model.dart';
import 'audit_service.dart';
import 'event_bus.dart';
import 'payment_intent_service.dart';
import 'sync_orchestrator.dart';

/// Loại khoản tiền có thể đối soát.
enum ReconcileKind {
  /// Ngân hàng tất toán đơn trả góp (tiền vào).
  installment,

  /// Khách trả nợ (công nợ phải thu — tiền vào).
  customerDebt,

  /// Shop trả nợ NCC / đối tác (công nợ phải trả — tiền ra).
  supplierDebt,
}

/// Một kết quả khớp với số tiền người dùng nhập.
class ReconcileMatch {
  final ReconcileKind kind;

  /// Tên đối tượng: khách / ngân hàng / NCC.
  final String title;

  /// Nội dung phụ: đơn / ghi chú.
  final String subtitle;

  /// Số tiền KỲ VỌNG của khoản này (tổng vay còn lại / số còn nợ).
  final int expected;

  /// true = số nhập đúng bằng [expected]; false = khớp một phần (nhập < expected).
  final bool exact;

  /// Tiền vào (true) hay tiền ra (false).
  final bool moneyIn;

  // Nguồn dữ liệu để [MoneyReconcileService.apply] xử lý.
  final SaleOrder? sale; // kind == installment
  final Map<String, dynamic>? debtRow; // kind == customerDebt / supplierDebt

  const ReconcileMatch({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.expected,
    required this.exact,
    required this.moneyIn,
    this.sale,
    this.debtRow,
  });
}

class ReconcileApplyResult {
  final bool ok;
  final String message;
  const ReconcileApplyResult(this.ok, this.message);
}

/// "Đối soát tiền về": nhập số tiền nhận/chuyển → tìm đơn trả góp hoặc khoản
/// công nợ tương ứng → ghi nhận + cập nhật trạng thái.
///
/// KHÔNG viết lại logic tiền: tái dùng đúng các luồng đã kiểm chứng
/// (`PaymentIntentService.executePaymentDirect` cho công nợ; luồng tất toán
/// trả góp giống hệt `sale_detail_view._openSettlementDialog`).
class MoneyReconcileService {
  MoneyReconcileService._();

  static const Set<String> _payableTypes = {
    'SHOP_OWES',
    'OTHER_SHOP_OWES',
    'OWED',
    'REPAIR_PARTNER',
  };

  /// Tìm các khoản khớp [amount]. [moneyIn] = true tìm khoản nhận tiền
  /// (trả góp NH + công nợ khách), false tìm khoản chi (công nợ NCC/đối tác).
  static Future<List<ReconcileMatch>> findMatches({
    required int amount,
    required bool moneyIn,
  }) async {
    if (amount <= 0) return const [];
    final db = DBHelper();
    final out = <ReconcileMatch>[];

    if (moneyIn) {
      // 1) Trả góp NH chưa tất toán — khớp tổng tiền vay.
      try {
        final sales = await db.getPendingSettlementSales();
        for (final s in sales) {
          final totalLoan = s.loanAmount + s.loanAmount2;
          if (totalLoan <= 0) continue;
          final exact = totalLoan == amount;
          final partial = amount < totalLoan;
          if (!exact && !partial) continue;
          final banks = [
            s.bankName,
            if ((s.bankName2 ?? '').isNotEmpty) s.bankName2,
          ].whereType<String>().where((b) => b.isNotEmpty).join(' + ');
          out.add(ReconcileMatch(
            kind: ReconcileKind.installment,
            title: banks.isEmpty ? 'Ngân hàng' : banks,
            subtitle: 'Tất toán trả góp — KH: ${s.customerName}',
            expected: totalLoan,
            exact: exact,
            moneyIn: true,
            sale: s,
          ));
        }
      } catch (e) {
        debugPrint('MoneyReconcile installment: $e');
      }
    }

    // 2/3) Công nợ — phải thu (moneyIn) hoặc phải trả (moneyOut).
    try {
      final debts = await db.getDebtsForFinanceSnapshot();
      for (final d in debts) {
        final total = (d['totalAmount'] as int?) ?? 0;
        final paid = (d['paidAmount'] as int?) ?? 0;
        final remaining = total - paid;
        if (remaining <= 0) continue;
        final status = (d['status'] as String? ?? '').toUpperCase();
        if (status == 'PAID' || status == 'CANCELLED') continue;
        final type = (d['type'] as String? ?? 'CUSTOMER_OWES');
        final isPayable = _payableTypes.contains(type);
        if (moneyIn && isPayable) continue;
        if (!moneyIn && !isPayable) continue;

        final exact = remaining == amount;
        final partial = amount < remaining;
        if (!exact && !partial) continue;

        final note = (d['note'] as String? ?? '').trim();
        out.add(ReconcileMatch(
          kind: isPayable
              ? ReconcileKind.supplierDebt
              : ReconcileKind.customerDebt,
          title: (d['personName'] as String? ?? 'Không rõ').trim(),
          subtitle: note.isEmpty
              ? (isPayable ? 'Công nợ phải trả' : 'Công nợ phải thu')
              : note,
          expected: remaining,
          exact: exact,
          moneyIn: moneyIn,
          debtRow: d,
        ));
      }
    } catch (e) {
      debugPrint('MoneyReconcile debts: $e');
    }

    // Khớp đúng lên trước, rồi tới khớp một phần; trong mỗi nhóm số lớn trước.
    out.sort((a, b) {
      if (a.exact != b.exact) return a.exact ? -1 : 1;
      return b.expected.compareTo(a.expected);
    });
    return out;
  }

  /// Ghi nhận khoản tiền cho [match]. [amount] = số tiền thực nhận/chi.
  /// [viaBank] true = chuyển khoản (mặc định), false = tiền mặt.
  static Future<ReconcileApplyResult> apply({
    required ReconcileMatch match,
    required int amount,
    bool viaBank = true,
    int fee = 0,
  }) async {
    if (amount <= 0) {
      return const ReconcileApplyResult(false, 'Số tiền phải lớn hơn 0.');
    }
    switch (match.kind) {
      case ReconcileKind.installment:
        return _applyInstallment(match.sale!, amount, fee);
      case ReconcileKind.customerDebt:
      case ReconcileKind.supplierDebt:
        return _applyDebt(match, amount, viaBank);
    }
  }

  // ── Tất toán trả góp — giữ đúng logic sale_detail_view._openSettlementDialog ──
  static Future<ReconcileApplyResult> _applyInstallment(
    SaleOrder s,
    int received,
    int fee,
  ) async {
    try {
      final db = DBHelper();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final user = FirebaseAuth.instance.currentUser;

      s.settlementAmount = received;
      s.settlementFee = fee;
      s.settlementNote = 'Đối soát tiền về';
      s.settlementReceivedAt = nowMs;
      s.isSynced = false;
      await db.updateSale(s);

      if (s.firestoreId != null) {
        await SyncOrchestrator().enqueue(
          entityType: SyncEntityType.sale,
          entityId: s.id!,
          firestoreId: s.firestoreId,
          operation: SyncOperation.update,
          data: s.toMap(),
        );
      }
      EventBus().emit('sales_changed');
      EventBus().emit('products_changed');

      final banks = [
        s.bankName,
        if ((s.bankName2 ?? '').isNotEmpty) s.bankName2,
      ].whereType<String>().join(' + ');

      await PaymentIntentService.createIntent(PaymentIntent(
        id: 'pi_settlement_${s.firestoreId ?? s.id}_$nowMs',
        type: PaymentIntentType.saleInstallment,
        status: PaymentIntentStatus.completed,
        amount: received,
        personName: banks,
        personPhone: '',
        description: 'Ngân hàng $banks tất toán - KH: ${s.customerName}',
        referenceType: 'sale',
        referenceId: s.firestoreId ?? 'sale_${s.soldAt}',
        createdBy: user?.uid ?? 'unknown',
        createdAt: nowMs,
        paymentMethod: PaymentMethod.bank,
        paidAt: nowMs,
      ));

      if (fee > 0) {
        await PaymentIntentService.createIntent(PaymentIntent(
          id: 'pi_bank_fee_${s.firestoreId ?? s.id}_$nowMs',
          type: PaymentIntentType.operatingExpense,
          status: PaymentIntentStatus.completed,
          amount: fee,
          personName: s.bankName ?? 'NGÂN HÀNG',
          personPhone: '',
          description: 'Phí NH ${s.bankName ?? ""} - KH: ${s.customerName}',
          referenceType: 'sale',
          referenceId: s.firestoreId ?? 'sale_${s.soldAt}',
          createdBy: user?.uid ?? 'unknown',
          createdAt: nowMs,
          paymentMethod: PaymentMethod.bank,
          paidAt: nowMs,
        ));
      }

      await AuditService.logAction(
        action: 'SETTLEMENT_RECEIVED',
        entityType: 'sale',
        entityId: s.firestoreId ?? 'sale_${s.soldAt}',
        summary: 'Đối soát: nhận ${_fmt(received)} từ NH',
        payload: {'fee': fee, 'bank': s.bankName, 'via': 'money_reconcile'},
      );

      return ReconcileApplyResult(
        true,
        'Đã tất toán trả góp cho ${s.customerName}: ${_fmt(received)}.',
      );
    } catch (e) {
      return ReconcileApplyResult(false, 'Lỗi tất toán: $e');
    }
  }

  // ── Công nợ khách / NCC — dùng executePaymentDirect như debt_payment_sheet ──
  static Future<ReconcileApplyResult> _applyDebt(
    ReconcileMatch match,
    int amount,
    bool viaBank,
  ) async {
    final d = match.debtRow!;
    final isCustomer = match.kind == ReconcileKind.customerDebt;
    final user = FirebaseAuth.instance.currentUser;
    try {
      final result = await PaymentIntentService.executePaymentDirect(
        type: isCustomer
            ? PaymentIntentType.customerDebtCollection
            : PaymentIntentType.supplierDebt,
        amount: amount,
        paymentMethod: viaBank ? PaymentMethod.transfer : PaymentMethod.cash,
        description: isCustomer
            ? 'Thu nợ (đối soát): ${d['personName'] ?? ''}'
            : 'Trả nợ (đối soát): ${d['personName'] ?? ''}',
        executedBy: user?.displayName ?? user?.email ?? 'unknown',
        referenceId: d['firestoreId']?.toString(),
        referenceType: 'debt',
        personName: d['personName']?.toString(),
        personPhone: d['phone']?.toString(),
        idempotencyKey:
            '${d['firestoreId']}_${DateTime.now().millisecondsSinceEpoch}',
        metadata: {
          'debtId': d['id'],
          'debtFirestoreId': d['firestoreId'],
          'debtType': d['type'],
          'linkedId': d['linkedId'],
          'via': 'money_reconcile',
        },
      );
      if (!result.success) {
        return ReconcileApplyResult(
          false,
          result.errorMessage ?? 'Ghi nhận thất bại.',
        );
      }
      await AuditService.logAction(
        action: isCustomer ? 'DEBT_COLLECTED' : 'SUPPLIER_PAID',
        entityType: 'debt',
        entityId: d['firestoreId']?.toString() ?? '${d['id']}',
        summary:
            '${isCustomer ? "Thu" : "Trả"} ${_fmt(amount)} — ${d['personName'] ?? ''} (đối soát)',
      );
      EventBus().emit('debts_changed');
      return ReconcileApplyResult(
        true,
        '${isCustomer ? "Đã thu nợ" : "Đã trả nợ"} ${d['personName'] ?? ''}: ${_fmt(amount)}.',
      );
    } catch (e) {
      return ReconcileApplyResult(false, 'Lỗi ghi nhận: $e');
    }
  }

  static String _fmt(int v) {
    final raw = v.toString();
    final b = StringBuffer();
    var c = 0;
    for (var i = raw.length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) b.write('.');
      b.write(raw[i]);
      c++;
    }
    return '${b.toString().split('').reversed.join()}đ';
  }
}
