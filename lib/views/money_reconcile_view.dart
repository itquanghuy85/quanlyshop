import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/db_helper.dart';
import '../services/money_reconcile_service.dart';
import '../services/bank_notification_parser.dart';
import '../services/bank_notification_service.dart';
import '../services/event_bus.dart';
import '../utils/money_utils.dart';
import '../widgets/currency_text_field.dart';
import '../widgets/custom_app_bar.dart';
import 'debt_view.dart';
import 'repair_detail_view.dart';
import 'sale_detail_view.dart';

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
  bool _searched = false;
  List<ReconcileMatch> _matches = const [];
  Timer? _debounce;

  // Nạp MỘT LẦN, lọc trong bộ nhớ → gõ số tiền không đụng DB, không lag dù shop
  // có hàng nghìn công nợ.
  ReconcileCandidates? _candidates;
  bool _loading = true;

  // Giao dịch ngân hàng đọc được từ thông báo (Android). Bấm 1 dòng → tự điền
  // số tiền + chiều tiền để đối soát.
  final _db = DBHelper();
  List<Map<String, dynamic>> _bankNotifs = const [];
  int? _activeNotifId; // thông báo đang dùng để đối soát
  StreamSubscription<String>? _busSub;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
    _loadBankNotifs();
    _busSub = EventBus().on('bank_notifications_changed', (_) {
      if (mounted) _loadBankNotifs();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busSub?.cancel();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBankNotifs() async {
    if (!BankNotificationService.instance.isSupported) return;
    try {
      final rows = await _db.getNewBankNotifications(limit: 30);
      if (!mounted) return;
      setState(() => _bankNotifs = rows);
    } catch (_) {}
  }

  void _pickBankNotif(Map<String, dynamic> n) {
    final amount = (n['amount'] as num?)?.toInt() ?? 0;
    final dir = (n['direction'] ?? 'unknown').toString();
    setState(() {
      _activeNotifId = n['id'] as int?;
      if (dir == 'credit') _moneyIn = true;
      if (dir == 'debit') _moneyIn = false;
      if (amount > 0) {
        _amountCtrl.text = CurrencyTextField.formatDisplay(amount);
      }
    });
    _applyFilter();
  }

  Future<void> _dismissNotif(int id) async {
    await _db.markBankNotificationDismissed(id);
    if (_activeNotifId == id) _activeNotifId = null;
    await BankNotificationService.instance.refreshCount();
    await _loadBankNotifs();
  }

  /// Dán nội dung tin nhắn / thông báo ngân hàng từ clipboard rồi để app tự
  /// đọc số tiền + chiều tiền. Dùng được trên MỌI nền tảng — đặc biệt cho iOS
  /// (không có API đọc thông báo) và cho ngân hàng ngoài danh sách hỗ trợ.
  Future<void> _pasteBankText() async {
    String text = '';
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      text = (data?.text ?? '').trim();
    } catch (e) {
      debugPrint('_pasteBankText: $e');
    }
    if (text.isEmpty) {
      _snack('Bộ nhớ tạm đang trống — hãy sao chép nội dung tin nhắn / thông '
          'báo ngân hàng trước.', Colors.orange);
      return;
    }

    final parsed = BankNotificationParser.parse(content: text);
    if (parsed == null || parsed.amount <= 0) {
      _snack('Không đọc được số tiền trong nội dung vừa dán — hãy gõ tay số '
          'tiền bên trên.', Colors.orange);
      return;
    }

    setState(() {
      _activeNotifId = null; // nguồn là dán tay, không gắn với thông báo nào
      if (parsed.direction == 'credit') _moneyIn = true;
      if (parsed.direction == 'debit') _moneyIn = false;
      _amountCtrl.text = CurrencyTextField.formatDisplay(parsed.amount);
    });
    _applyFilter();

    final dirLabel = switch (parsed.direction) {
      'credit' => 'tiền vào',
      'debit' => 'tiền ra',
      _ => 'chưa rõ chiều — hãy tự chọn Tiền vào / Tiền ra',
    };
    _snack(
      'Đã đọc: ${MoneyUtils.formatCurrency(parsed.amount)} đ ($dirLabel)',
      parsed.direction == 'unknown' ? Colors.orange : Colors.green,
    );
  }

  int get _amount => CurrencyTextField.getValue(_amountCtrl);

  Future<void> _loadCandidates() async {
    setState(() => _loading = true);
    final c = await MoneyReconcileService.loadCandidates();
    if (!mounted) return;
    setState(() {
      _candidates = c;
      _loading = false;
    });
    _applyFilter(); // giữ kết quả khớp với số đang nhập
  }

  /// Gõ tới đâu lọc tới đó — thuần bộ nhớ, tức thì.
  void _onAmountChanged(int value) {
    _debounce?.cancel();
    if (value <= 0) {
      if (_searched || _matches.isNotEmpty) {
        setState(() {
          _searched = false;
          _matches = const [];
        });
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), _applyFilter);
  }

  void _applyFilter() {
    final c = _candidates;
    final amount = _amount;
    if (c == null || amount <= 0) return;
    final res = MoneyReconcileService.match(c, amount, moneyIn: _moneyIn);
    if (!mounted) return;
    setState(() {
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

    setState(() => _loading = true);
    final r = await MoneyReconcileService.apply(
      match: m,
      amount: amount,
      viaBank: true,
    );
    if (!mounted) return;
    _snack(r.message, r.ok ? Colors.green : Colors.red);

    // Nếu đang đối soát theo 1 thông báo ngân hàng → đánh dấu đã xử lý.
    if (r.ok && _activeNotifId != null) {
      final refId = m.sale?.firestoreId ??
          (m.debtRow?['firestoreId']?.toString());
      await _db.markBankNotificationApplied(
        _activeNotifId!,
        matchedType: m.kind.name,
        matchedRefId: refId,
      );
      _activeNotifId = null;
      await BankNotificationService.instance.refreshCount();
      await _loadBankNotifs();
    }

    // Dữ liệu đã đổi → nạp lại danh sách nguồn rồi lọc lại.
    await _loadCandidates();
  }

  Widget _bankNotifSection() {
    if (_bankNotifs.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    size: 15, color: Color(0xFFEA580C)),
                const SizedBox(width: 6),
                Text(
                  'Giao dịch ngân hàng gần đây (${_bankNotifs.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: Color(0xFFEA580C),
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 176),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 6),
              itemCount: _bankNotifs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _bankNotifRow(_bankNotifs[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bankNotifRow(Map<String, dynamic> n) {
    final amount = (n['amount'] as num?)?.toInt() ?? 0;
    final dir = (n['direction'] ?? 'unknown').toString();
    final active = _activeNotifId == n['id'];
    final dirLabel = dir == 'credit'
        ? 'Tiền vào'
        : dir == 'debit'
            ? 'Tiền ra'
            : '?';
    final dirColor = dir == 'credit'
        ? Colors.green
        : dir == 'debit'
            ? Colors.red
            : Colors.grey;
    return InkWell(
      onTap: () => _pickBankNotif(n),
      child: Container(
        color: active ? const Color(0xFFFFE8D1) : null,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${n['bankName'] ?? 'NH'} · ',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: dirColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(dirLabel,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: dirColor)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        amount > 0
                            ? '${MoneyUtils.formatCurrency(amount)} đ'
                            : '—',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(
                    (n['memo']?.toString().trim().isNotEmpty == true
                        ? n['memo'].toString()
                        : (n['rawText']?.toString() ?? '')),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Bỏ qua',
              icon: const Icon(Icons.close_rounded, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: () => _dismissNotif(n['id'] as int),
            ),
          ],
        ),
      ),
    );
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
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
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
                  onSelectionChanged: (s) {
                    setState(() {
                      _moneyIn = s.first;
                      _searched = false;
                      _matches = const [];
                    });
                    _applyFilter(); // lọc lại theo chiều mới (dữ liệu đã có sẵn)
                  },
                ),
                const SizedBox(height: 12),
                CurrencyTextField(
                  controller: _amountCtrl,
                  label: 'Số tiền nhận được từ NH / trên sao kê',
                  icon: Icons.payments_rounded,
                  onValueChanged: _onAmountChanged,
                  onSubmitted: _applyFilter,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      _loading ? Icons.sync_rounded : Icons.bolt_rounded,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _loading
                            ? 'Đang tải danh sách…'
                            : 'Gõ số tiền — tự lọc, không cần bấm tìm',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    // Dán tin nhắn / thông báo NH → app tự đọc số tiền.
                    // Có ở MỌI nền tảng (iOS không đọc được thông báo tự động).
                    TextButton.icon(
                      onPressed: _pasteBankText,
                      icon: const Icon(Icons.content_paste_rounded, size: 15),
                      label: const Text('Dán tin nhắn NH',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                _bankNotifSection(),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildResults()),
        ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading && _candidates == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_searched && _matches.isEmpty) {
      return _hint(
        'Gõ số tiền nhận được (hoặc chuyển đi) — app tự lọc các đơn / khoản '
        'nợ khớp để bạn chọn và xác nhận ghi nhận.',
      );
    }
    if (_searched && _matches.isEmpty) {
      return _hint(
        'Không có đơn trả góp hay khoản công nợ nào khớp số này.\n'
        'Kiểm tra lại số tiền, hoặc chiều tiền (vào / ra).',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadCandidates,
      child: ListView.separated(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        itemCount: _matches.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _matchCard(_matches[i]),
      ),
    );
  }

  /// Mở đơn / khoản công nợ tương ứng với 1 kết quả đối soát.
  Future<void> _openSource(ReconcileMatch m) async {
    if (m.kind == ReconcileKind.installment && m.sale != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SaleDetailView(sale: m.sale!)),
      );
      return;
    }
    final d = m.debtRow;
    if (d == null) return;
    final lt = (d['linkedType'] ?? '').toString().toLowerCase();
    final lid = (d['linkedId'] ?? '').toString().trim();
    final fid = (d['firestoreId'] ?? '').toString();
    final db = DBHelper();

    if (lid.isNotEmpty &&
        (lt == 'sale' || fid.startsWith('debt_customer_'))) {
      final s = await db.getSaleByFirestoreId(lid);
      if (!mounted) return;
      if (s != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SaleDetailView(sale: s)),
        );
        return;
      }
    }
    if (lid.isNotEmpty &&
        (lt == 'repair' ||
            fid.startsWith('debt_repair_') ||
            fid.startsWith('debt_partner_debt_'))) {
      final r = await db.getRepairByFirestoreId(lid);
      if (!mounted) return;
      if (r != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RepairDetailView(repair: r)),
        );
        return;
      }
    }
    // Không lần được đơn gốc → mở màn Công nợ.
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DebtView()),
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
              IconButton(
                tooltip: 'Xem đơn / khoản tương ứng',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.open_in_new_rounded,
                    size: 18, color: Colors.grey),
                onPressed: () => _openSource(m),
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
