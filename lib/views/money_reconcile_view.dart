import 'package:flutter/material.dart';

import '../services/money_reconcile_service.dart';
import '../utils/money_utils.dart';
import '../widgets/currency_text_field.dart';
import '../widgets/custom_app_bar.dart';

/// "Đối soát tiền về" — nhập số tiền nhận / chuyển đi → app tìm đơn trả góp NH
/// hoặc khoản công nợ khớp → xác nhận → ghi nhận + cập nhật trạng thái.
class MoneyReconcileView extends StatefulWidget {
  const MoneyReconcileView({super.key});

  @override
  State<MoneyReconcileView> createState() => _MoneyReconcileViewState();
}

class _MoneyReconcileViewState extends State<MoneyReconcileView> {
  final _amountCtrl = TextEditingController();
  bool _moneyIn = true; // true: tiền vào (nhận) | false: tiền ra (chuyển đi)
  bool _searching = false;
  bool _searched = false;
  List<ReconcileMatch> _matches = const [];

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  int get _amount => CurrencyTextField.getValue(_amountCtrl);

  Future<void> _search() async {
    CurrencyTextField.finalizeAll();
    final amount = _amount;
    if (amount <= 0) {
      _snack('Nhập số tiền cần đối soát.', Colors.orange);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    final res = await MoneyReconcileService.findMatches(
      amount: amount,
      moneyIn: _moneyIn,
    );
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searched = true;
      _matches = res;
    });
  }

  Future<void> _confirmApply(ReconcileMatch m) async {
    final amount = _amount;
    final kindLabel = switch (m.kind) {
      ReconcileKind.installment => 'Tất toán trả góp NH',
      ReconcileKind.customerDebt => 'Thu nợ khách',
      ReconcileKind.supplierDebt => 'Trả nợ NCC / đối tác',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(kindLabel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv('Đối tượng', m.title),
            _kv('Nội dung', m.subtitle),
            _kv('Số kỳ vọng', '${MoneyUtils.formatCurrency(m.expected)} đ'),
            _kv(
              _moneyIn ? 'Ghi nhận NHẬN' : 'Ghi nhận CHI',
              '${MoneyUtils.formatCurrency(amount)} đ',
            ),
            if (!m.exact)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  m.kind == ReconcileKind.installment
                      ? 'Số nhập nhỏ hơn tổng vay — vẫn đánh dấu ĐÃ TẤT TOÁN với số này.'
                      : 'Khớp một phần — còn nợ ${MoneyUtils.formatCurrency(m.expected - amount)} đ sau khi ghi.',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận ghi'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _searching = true);
    final r = await MoneyReconcileService.apply(
      match: m,
      amount: amount,
      viaBank: true,
    );
    if (!mounted) return;
    _snack(r.message, r.ok ? Colors.green : Colors.red);
    if (r.ok) {
      await _search(); // làm mới danh sách (khoản đã xử lý sẽ biến mất / đổi)
    } else {
      setState(() => _searching = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar.build(title: 'Đối soát tiền về'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Tiền vào (nhận)'),
                      icon: Icon(Icons.south_west_rounded),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Tiền ra (chuyển)'),
                      icon: Icon(Icons.north_east_rounded),
                    ),
                  ],
                  selected: {_moneyIn},
                  onSelectionChanged: (s) => setState(() {
                    _moneyIn = s.first;
                    _searched = false;
                    _matches = const [];
                  }),
                ),
                const SizedBox(height: 12),
                CurrencyTextField(
                  controller: _amountCtrl,
                  label: 'Số tiền nhận được từ NH / trên sao kê',
                  icon: Icons.payments_rounded,
                  onSubmitted: _search,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _searching ? null : _search,
                    icon: const Icon(Icons.search_rounded),
                    label: Text(
                      _moneyIn
                          ? 'Tìm đơn trả góp / công nợ khách khớp'
                          : 'Tìm công nợ phải trả khớp',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_searched) {
      return _hint(
        'Nhập số tiền rồi bấm Tìm.\nApp sẽ liệt kê các đơn / khoản nợ khớp để bạn '
        'chọn và xác nhận ghi nhận.',
      );
    }
    if (_matches.isEmpty) {
      return _hint(
        'Không có đơn trả góp hay khoản công nợ nào khớp số này.\n'
        'Kiểm tra lại số tiền, hoặc chiều tiền (vào / ra).',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      itemCount: _matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _matchCard(_matches[i]),
    );
  }

  Widget _matchCard(ReconcileMatch m) {
    final (icon, color) = switch (m.kind) {
      ReconcileKind.installment => (Icons.account_balance_rounded, Colors.indigo),
      ReconcileKind.customerDebt => (Icons.south_west_rounded, Colors.teal),
      ReconcileKind.supplierDebt => (Icons.north_east_rounded, Colors.deepOrange),
    };
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => _confirmApply(m),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      m.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: m.exact
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            m.exact
                                ? 'Khớp đúng'
                                : 'Khớp một phần (kỳ vọng ${MoneyUtils.formatCurrency(m.expected)})',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: m.exact
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            k,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _hint(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade600, height: 1.5),
      ),
    ),
  );
}

/// Lối tắt mở màn "Đối soát tiền về" từ bất kỳ đâu.
void openMoneyReconcile(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(builder: (_) => const MoneyReconcileView()),
  );
}
