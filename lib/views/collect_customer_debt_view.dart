import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/financial_constants.dart';
import '../services/customer_debt_payment_service.dart';
import '../services/debt_summary_service.dart';
import '../utils/money_input_formatter.dart';
import '../utils/money_utils.dart';
import '../widgets/currency_text_field.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/responsive_wrapper.dart';

/// 1 dòng phân bổ chỉnh sửa được trong bước 2 của luồng thu tiền gộp.
class _AllocRow {
  final Map<String, dynamic> debt;
  final TextEditingController amountCtrl;
  bool selected;

  _AllocRow({
    required this.debt,
    required this.amountCtrl,
    required this.selected,
  });

  int get remaining {
    final total = (debt['totalAmount'] as num?)?.toInt() ?? 0;
    final paid = (debt['paidAmount'] as num?)?.toInt() ?? 0;
    return total - paid;
  }

  int get amount => selected ? CurrencyTextField.getValue(amountCtrl) : 0;
}

/// Thu tiền gộp nhiều đơn của cùng 1 khách — luồng 3 bước:
/// 1) nhập số tiền + phương thức, 2) phân bổ (FIFO đề xuất, sửa tay được),
/// 3) kết quả. Trả về true qua Navigator.pop khi đã thu thành công (để màn
/// gọi tự refresh).
class CollectCustomerDebtView extends StatefulWidget {
  final String phone;
  final String personName;

  const CollectCustomerDebtView({
    super.key,
    required this.phone,
    required this.personName,
  });

  @override
  State<CollectCustomerDebtView> createState() =>
      _CollectCustomerDebtViewState();
}

class _CollectCustomerDebtViewState extends State<CollectCustomerDebtView> {
  final _debtSummary = DebtSummaryService();
  final _paymentService = CustomerDebtPaymentService();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _submitting = false;
  int _step = 0; // 0: nhập tiền, 1: phân bổ, 2: kết quả
  List<Map<String, dynamic>> _debts = [];
  List<_AllocRow> _rows = [];
  String _paymentMethodCode = 'TIỀN MẶT';
  CollectDebtResult? _result;
  bool _resultChanged = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    for (final r in _rows) {
      r.amountCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final debts = await _debtSummary.getCustomerActiveDebts(widget.phone);
    if (!mounted) return;
    setState(() {
      _debts = debts;
      _loading = false;
    });
  }

  int get _totalOutstanding => _debts.fold<int>(
    0,
    (sum, d) =>
        sum +
        (((d['totalAmount'] as num?)?.toInt() ?? 0) -
            ((d['paidAmount'] as num?)?.toInt() ?? 0)),
  );

  int get _allocatedTotal => _rows.fold<int>(0, (sum, r) => sum + r.amount);

  bool get _allocationValid {
    final entered = CurrencyTextField.getValue(_amountCtrl);
    if (_allocatedTotal != entered) return false;
    for (final r in _rows) {
      if (r.amount > r.remaining) return false;
    }
    return true;
  }

  void _goToAllocation() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = CurrencyTextField.getValue(_amountCtrl);
    if (amount <= 0) return;

    final suggested = CustomerDebtPaymentService.suggestFifoAllocation(
      _debts,
      amount,
    );
    final suggestedByDebtId = {for (final a in suggested) a.debtId: a.amount};

    for (final r in _rows) {
      r.amountCtrl.dispose();
    }
    _rows = _debts.map((d) {
      final debtId = d['id'] as int;
      final suggestedAmount = suggestedByDebtId[debtId] ?? 0;
      return _AllocRow(
        debt: d,
        amountCtrl: TextEditingController(
          text: suggestedAmount > 0
              ? CurrencyTextField.formatDisplay(suggestedAmount)
              : '',
        ),
        selected: suggestedAmount > 0,
      );
    }).toList();

    setState(() => _step = 1);
  }

  void _toggleRow(_AllocRow row, bool selected) {
    setState(() {
      row.selected = selected;
      if (selected && CurrencyTextField.getValue(row.amountCtrl) == 0) {
        final entered = CurrencyTextField.getValue(_amountCtrl);
        final remainingToAllocate = (entered - _allocatedTotal).clamp(
          0,
          row.remaining,
        );
        if (remainingToAllocate > 0) {
          row.amountCtrl.text = CurrencyTextField.formatDisplay(
            remainingToAllocate,
          );
        }
      }
    });
  }

  Future<void> _confirm() async {
    if (!_allocationValid || _submitting) return;
    setState(() => _submitting = true);

    final user = FirebaseAuth.instance.currentUser;
    final allocations = _rows
        .where((r) => r.amount > 0)
        .map(
          (r) => DebtAllocation(
            debtId: r.debt['id'] as int,
            debtFirestoreId: r.debt['firestoreId'] as String?,
            linkedId: r.debt['linkedId'] as String?,
            remainingBefore: r.remaining,
            amount: r.amount,
          ),
        )
        .toList();

    final result = await _paymentService.collectPayment(
      phone: widget.phone,
      personName: widget.personName,
      allocations: allocations,
      paymentMethod: _paymentMethodCode == 'CHUYỂN KHOẢN'
          ? PaymentMethod.transfer
          : PaymentMethod.cash,
      executedBy: user?.displayName ?? user?.email ?? 'unknown',
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _result = result;
      _submitting = false;
      _resultChanged = result.totalCollected > 0;
      _step = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _resultChanged);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: CustomAppBar.build(
          title: 'Thu tiền công nợ',
          subtitle: widget.personName,
          onBackPressed: () => Navigator.pop(context, _resultChanged),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ResponsiveCenter(
                maxWidth: 800,
                child: switch (_step) {
                  1 => _buildAllocationStep(),
                  2 => _buildResultStep(),
                  _ => _buildAmountStep(),
                },
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Bước 1: nhập số tiền + phương thức
  // ---------------------------------------------------------------------
  Widget _buildAmountStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoCard(
              title: 'Công nợ hiện tại',
              value: '${MoneyUtils.formatCurrency(_totalOutstanding)}đ',
              color: const Color(0xFFB91C1C),
            ),
            const SizedBox(height: 16),
            CurrencyTextField(
              controller: _amountCtrl,
              label: 'Số tiền thu',
              required: true,
              validator: (v) => MoneyUtils.validateAmount(
                v ?? '',
                min: 1,
                max: _totalOutstanding,
                fieldName: 'Số tiền thu',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Phương thức',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: ['TIỀN MẶT', 'CHUYỂN KHOẢN']
                  .map(
                    (m) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(m == 'TIỀN MẶT' ? 'Tiền mặt' : 'Chuyển khoản'),
                          selected: _paymentMethodCode == m,
                          onSelected: (_) =>
                              setState(() => _paymentMethodCode = m),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'Ghi chú',
                hintText: 'VD: Khách thanh toán công nợ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _debts.isEmpty ? null : _goToAllocation,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('TIẾP TỤC'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Bước 2: phân bổ (FIFO đề xuất, sửa tay được)
  // ---------------------------------------------------------------------
  Widget _buildAllocationStep() {
    final entered = CurrencyTextField.getValue(_amountCtrl);
    final valid = _allocationValid;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _infoCard(
                title: 'Số tiền thu',
                value: '${MoneyUtils.formatCurrency(entered)}đ',
                color: const Color(0xFF166534),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: valid ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: valid
                        ? Colors.green.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Đã phân bổ: ${MoneyUtils.formatCurrency(_allocatedTotal)}đ',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: valid
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                      ),
                    ),
                    Text(
                      'Cần: ${MoneyUtils.formatCurrency(entered)}đ',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Phân bổ vào đơn (mặc định FIFO — đơn cũ trả trước, có thể sửa tay)',
                style: TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ..._rows.map(_buildAllocRow),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (!_submitting && valid) ? _confirm : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('XÁC NHẬN THU TIỀN'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllocRow(_AllocRow row) {
    final createdAt = (row.debt['createdAt'] as num?)?.toInt() ?? 0;
    final dateStr = createdAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(
            createdAt,
          ).toString().substring(0, 10)
        : '';
    final overAllocated = row.amount > row.remaining;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: overAllocated ? Colors.red.shade300 : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: row.selected,
              onChanged: (v) => _toggleRow(row, v ?? false),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đơn $dateStr',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Còn nợ: ${MoneyUtils.formatCurrency(row.remaining)}đ',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: TextField(
                controller: row.amountCtrl,
                enabled: row.selected,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                inputFormatters: [MoneyInputFormatter()],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: 'đ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorText: overAllocated ? 'Vượt số dư' : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Bước 3: kết quả
  // ---------------------------------------------------------------------
  Widget _buildResultStep() {
    final result = _result;
    if (result == null) return const SizedBox.shrink();
    final success = result.success;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: success ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: success ? Colors.green.shade200 : Colors.red.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error_outline,
                  color: success ? Colors.green.shade700 : Colors.red.shade700,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    success
                        ? 'Thu tiền thành công!'
                        : (result.errorMessage ?? 'Có lỗi xảy ra'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: success
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (result.totalCollected > 0) ...[
            _resultRow(
              'Số tiền thu',
              '${MoneyUtils.formatCurrency(result.totalCollected)}đ',
            ),
            _resultRow(
              'Phương thức',
              _paymentMethodCode == 'CHUYỂN KHOẢN' ? 'Chuyển khoản' : 'Tiền mặt',
            ),
            const SizedBox(height: 12),
            const Text(
              'Phân bổ công nợ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...result.results.map((r) {
              final debt = r.allocation;
              final after = debt.remainingBefore - debt.amount;
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    r.success ? Icons.check_circle : Icons.cancel,
                    color: r.success ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  title: Text('-${MoneyUtils.formatCurrency(debt.amount)}đ'),
                  trailing: after <= 0
                      ? Chip(
                          label: const Text(
                            'Hết nợ',
                            style: TextStyle(fontSize: 11, color: Colors.white),
                          ),
                          backgroundColor: Colors.green.shade600,
                          visualDensity: VisualDensity.compact,
                        )
                      : Text(
                          'Còn ${MoneyUtils.formatCurrency(after)}đ',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _resultChanged),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('QUAY LẠI'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Widget _infoCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
