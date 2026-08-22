import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/db_helper.dart';
import '../services/debt_summary_service.dart';
import '../theme/app_colors.dart';
import '../utils/money_utils.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/responsive_wrapper.dart';
import 'collect_customer_debt_view.dart';
import 'repair_detail_view.dart';
import 'sale_detail_view.dart';

/// Công nợ khách hàng gộp nhiều đơn: tổng nợ hiện tại của 1 khách (theo
/// phone, cả đơn bán lẫn đơn sửa dùng chung bảng debts) + danh sách từng đơn
/// còn nợ + lối vào luồng thu tiền gộp nhiều đơn.
class CustomerDebtView extends StatefulWidget {
  final String phone;
  final String customerName;

  const CustomerDebtView({
    super.key,
    required this.phone,
    required this.customerName,
  });

  @override
  State<CustomerDebtView> createState() => _CustomerDebtViewState();
}

class _CustomerDebtViewState extends State<CustomerDebtView> {
  final _db = DBHelper();
  final _debtSummary = DebtSummaryService();

  bool _loading = true;
  List<Map<String, dynamic>> _debts = [];
  List<Map<String, dynamic>> _timeline = [];
  bool _loadingTimeline = true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadTimeline();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final debts = await _debtSummary.getCustomerActiveDebts(widget.phone);
    if (!mounted) return;
    setState(() {
      _debts = debts;
      _loading = false;
    });
  }

  // Lịch sử công nợ: gộp sự kiện "tạo đơn phát sinh nợ" + "thu tiền" của tất
  // cả đơn (kể cả đã trả hết), sort mới nhất trước.
  Future<void> _loadTimeline() async {
    setState(() => _loadingTimeline = true);
    final debts = await _debtSummary.getAllCustomerDebtsForHistory(
      widget.phone,
    );
    final events = <Map<String, dynamic>>[];
    for (final d in debts) {
      events.add({
        'kind': 'create',
        'ts': (d['createdAt'] as num?)?.toInt() ?? 0,
        'debt': d,
      });
      final debtId = d['id'] as int?;
      if (debtId == null) continue;
      final payments = await _db.getDebtPayments(debtId);
      for (final p in payments) {
        events.add({
          'kind': 'payment',
          'ts': (p['paidAt'] as num?)?.toInt() ?? (p['createdAt'] as num?)?.toInt() ?? 0,
          'payment': p,
          'debt': d,
        });
      }
    }
    events.sort((a, b) => (b['ts'] as int).compareTo(a['ts'] as int));
    if (!mounted) return;
    setState(() {
      _timeline = events;
      _loadingTimeline = false;
    });
  }

  Future<void> _refreshAll() async {
    await Future.wait([_load(), _loadTimeline()]);
  }

  int get _totalDebt => _debts.fold<int>(
    0,
    (sum, d) =>
        sum +
        (((d['totalAmount'] as num?)?.toInt() ?? 0) -
            ((d['paidAmount'] as num?)?.toInt() ?? 0)),
  );

  String _guessLinkedType(Map<String, dynamic> d) {
    final explicit = (d['linkedType'] as String?)?.trim().toLowerCase();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final linkedId = (d['linkedId'] as String?) ?? '';
    return linkedId.startsWith('sale_') ? 'sale' : 'repair';
  }

  Future<void> _openOrder(Map<String, dynamic> debt) async {
    final linkedId = debt['linkedId'] as String?;
    if (linkedId == null || linkedId.isEmpty) return;
    final type = _guessLinkedType(debt);
    if (type == 'sale') {
      final sale = await _db.getSaleByFirestoreId(linkedId);
      if (sale != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SaleDetailView(sale: sale)),
        );
        _refreshAll();
      }
    } else {
      final repair = await _db.getRepairByFirestoreId(linkedId);
      if (repair != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RepairDetailView(repair: repair)),
        );
        _refreshAll();
      }
    }
  }

  Future<void> _openCollect() async {
    if (_debts.isEmpty) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CollectCustomerDebtView(
          phone: widget.phone,
          personName: widget.customerName,
        ),
      ),
    );
    if (changed == true) _refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: CustomAppBar.build(
        title: 'Công nợ khách hàng',
        subtitle: widget.customerName,
        gradient: const LinearGradient(
          colors: [Color(0xFFB91C1C), Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveCenter(
              maxWidth: 800,
              child: RefreshIndicator(
                onRefresh: _refreshAll,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 18),
                    if (_debts.isEmpty)
                      _buildEmptyState()
                    else ...[
                      Text(
                        'Đơn còn nợ (${_debts.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._debts.map(_buildDebtRow),
                    ],
                    if (!_loadingTimeline && _timeline.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Lịch sử công nợ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._timeline.map(_buildTimelineRow),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTimelineRow(Map<String, dynamic> event) {
    final ts = event['ts'] as int;
    final dateStr = ts > 0
        ? DateFormat('HH:mm dd/MM/yyyy').format(
            DateTime.fromMillisecondsSinceEpoch(ts),
          )
        : '';
    final isPayment = event['kind'] == 'payment';

    if (isPayment) {
      final p = event['payment'] as Map<String, dynamic>;
      final amount = (p['amount'] as num?)?.toInt() ?? 0;
      final method = p['paymentMethod'] == 'CHUYỂN KHOẢN'
          ? 'Chuyển khoản'
          : 'Tiền mặt';
      return _timelineTile(
        icon: Icons.arrow_downward,
        iconColor: Colors.green.shade700,
        iconBg: Colors.green.shade50,
        title: 'THU TIỀN',
        subtitle: '$method • $dateStr',
        trailing: '-${MoneyUtils.formatCurrency(amount)}đ',
        trailingColor: Colors.green.shade700,
      );
    }

    final d = event['debt'] as Map<String, dynamic>;
    final total = (d['totalAmount'] as num?)?.toInt() ?? 0;
    final paid = (d['paidAmount'] as num?)?.toInt() ?? 0;
    final type = _guessLinkedType(d);
    return _timelineTile(
      icon: Icons.receipt_long,
      iconColor: AppColors.primary,
      iconBg: AppColors.primarySurface,
      title: type == 'sale' ? 'TẠO ĐƠN BÁN' : 'TẠO ĐƠN SỬA',
      subtitle: 'Đã thu lúc tạo: ${MoneyUtils.formatCurrency(paid)}đ • $dateStr',
      trailing: '+${MoneyUtils.formatCurrency(total)}đ',
      trailingColor: const Color(0xFF1F2937),
    );
  }

  Widget _timelineTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String trailing,
    required Color trailingColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            trailing,
            style: TextStyle(fontWeight: FontWeight.bold, color: trailingColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB91C1C), Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CÔNG NỢ HIỆN TẠI',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${MoneyUtils.formatCurrency(_totalDebt)}đ',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _debts.isEmpty ? null : _openCollect,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFB91C1C),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.payments_outlined),
              label: const Text(
                'THU TIỀN',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'Khách không còn nợ đơn nào',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtRow(Map<String, dynamic> d) {
    final total = (d['totalAmount'] as num?)?.toInt() ?? 0;
    final paid = (d['paidAmount'] as num?)?.toInt() ?? 0;
    final remain = total - paid;
    final createdAt = (d['createdAt'] as num?)?.toInt() ?? 0;
    final type = _guessLinkedType(d);
    final dateStr = createdAt > 0
        ? DateFormat('dd/MM/yyyy').format(
            DateTime.fromMillisecondsSinceEpoch(createdAt),
          )
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openOrder(d),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: type == 'sale'
                      ? AppColors.primarySurface
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  type == 'sale'
                      ? Icons.shopping_bag_outlined
                      : Icons.build_outlined,
                  color: type == 'sale'
                      ? AppColors.primary
                      : Colors.orange.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type == 'sale' ? 'Đơn bán' : 'Đơn sửa',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${MoneyUtils.formatCurrency(remain)}đ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFFB45309),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
