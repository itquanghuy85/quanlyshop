import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/sale_order_model.dart';
import '../services/event_bus.dart';
import '../services/user_service.dart';
import '../theme/app_text_styles.dart';
import '../utils/money_utils.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/responsive_wrapper.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/skeleton_list.dart';
import 'sale_detail_view.dart';

/// Danh sách THẲNG các đơn trả góp NH đã bán nhưng CHƯA nhận tiền giải
/// ngân — khác `BankInstallmentReportView` (màn thống kê theo ngân hàng/
/// theo kỳ, không phải danh sách đơn để xử lý từng cái).
///
/// Nguồn: `DBHelper.getPendingSettlementSales()` — cùng nguồn với
/// `ReminderService`/thẻ "TỔNG TÀI SẢN" nên số đếm/tổng tiền luôn khớp 3 nơi
/// đó. KHÔNG bound theo ngày — đơn bán từ rất lâu vẫn hiện nếu NH chưa
/// giải ngân.
class PendingBankSettlementView extends StatefulWidget {
  const PendingBankSettlementView({super.key});

  @override
  State<PendingBankSettlementView> createState() =>
      _PendingBankSettlementViewState();
}

class _PendingBankSettlementViewState
    extends State<PendingBankSettlementView> {
  final _db = DBHelper();
  List<SaleOrder> _sales = [];
  bool _loading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _load();
    EventBus().on('sales_changed', (_) {
      if (mounted) _load();
    });
  }

  Future<void> _checkPermission() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() => _hasPermission = perms['allowViewSales'] ?? false);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sales = await _db.getPendingSettlementSales();
      // Chờ lâu nhất lên đầu — đây là danh sách để XỬ LÝ, không phải sổ
      // giao dịch mới-nhất-lên-đầu.
      sales.sort((a, b) => a.soldAt.compareTo(b.soldAt));
      if (!mounted) return;
      setState(() {
        _sales = sales;
        _loading = false;
      });
    } catch (e) {
      debugPrint('PendingBankSettlementView._load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _money(int v) => MoneyUtils.formatCompactCurrency(v);

  int get _totalAmount =>
      _sales.fold(0, (s, o) => s + o.loanAmount + o.loanAmount2);

  int _daysWaiting(SaleOrder s) =>
      DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(s.soldAt)).inDays;

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Scaffold(
        appBar: CustomAppBar.build(title: 'Chờ ngân hàng tất toán'),
        body: const Center(
          child: Text(
            'Bạn không có quyền truy cập tính năng này',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: CustomAppBar.build(
        title: 'Chờ ngân hàng tất toán',
        subtitle: _loading
            ? null
            : '${_sales.length} đơn • ${_money(_totalAmount)}',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: _loading
            ? const SkeletonListView(
                variant: SkeletonVariant.repairCard,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              )
            : _sales.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Không còn đơn nào chờ NH tất toán',
                    subtitle: 'Mọi đơn trả góp đã được ngân hàng giải ngân.',
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _sales.length,
                      itemBuilder: (context, i) => _row(_sales[i]),
                    ),
                  ),
      ),
    );
  }

  Widget _row(SaleOrder s) {
    final days = _daysWaiting(s);
    final overdue = days > 7;
    final amount = s.loanAmount + s.loanAmount2;
    final banks = [
      if ((s.bankName ?? '').trim().isNotEmpty) s.bankName!.trim(),
      if ((s.bankName2 ?? '').trim().isNotEmpty) s.bankName2!.trim(),
    ].join(' + ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SaleDetailView(sale: s)),
          );
          _load();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.customerName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: AppTextStyles.headline4.fontSize,
                          ),
                        ),
                        Text(
                          s.productNames,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: AppTextStyles.subtitle1.fontSize,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: overdue
                          ? Colors.red.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Chờ $days ngày',
                      style: TextStyle(
                        color: overdue
                            ? Colors.red.shade700
                            : Colors.orange.shade700,
                        fontSize: AppTextStyles.body1.fontSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (banks.isNotEmpty)
                    _chip(Icons.account_balance, banks, Colors.indigo),
                  if (banks.isNotEmpty) const SizedBox(width: 8),
                  _chip(
                    Icons.calendar_today,
                    DateFormat('dd/MM/yy')
                        .format(DateTime.fromMillisecondsSinceEpoch(s.soldAt)),
                    Colors.grey,
                  ),
                  const Spacer(),
                  Text(
                    _money(amount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade700,
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

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: AppTextStyles.body1.fontSize, color: color),
          ),
        ],
      ),
    );
  }
}
