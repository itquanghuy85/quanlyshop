import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../core/utils/money_utils.dart';
import '../views/repair_detail_view.dart';
import '../views/sale_detail_view.dart';

/// "Cần xử lý" card - shows actionable items with counts
class ActionRequiredCard extends StatefulWidget {
  final bool enableRepair;
  final bool enableWarranty;
  final bool enableExpiry;
  final VoidCallback? onPendingRepairsTap;
  final VoidCallback? onPendingStockTap;
  final VoidCallback? onWarrantyTap;
  final VoidCallback? onExpiryTap;
  final int reminderCount;
  final VoidCallback? onReminderTap;
  final VoidCallback? onOverdueDebtsTap;
  final VoidCallback? onPendingInstallmentTap;
  final VoidCallback? onUnclosedCashTap;
  final VoidCallback? onMissingCostRepairsTap;

  const ActionRequiredCard({
    super.key,
    this.enableRepair = true,
    this.enableWarranty = true,
    this.enableExpiry = false,
    this.onPendingRepairsTap,
    this.onPendingStockTap,
    this.onWarrantyTap,
    this.onExpiryTap,
    this.reminderCount = 0,
    this.onReminderTap,
    this.onOverdueDebtsTap,
    this.onPendingInstallmentTap,
    this.onUnclosedCashTap,
    this.onMissingCostRepairsTap,
  });

  @override
  State<ActionRequiredCard> createState() => _ActionRequiredCardState();
}

class _ActionRequiredCardState extends State<ActionRequiredCard> {
  int _pendingRepairs = 0;
  int _pendingStock = 0;
  int _expiringWarranty = 0;
  int _expiringProducts = 0;
  int _overdueDebts = 0;
  int _pendingInstallments = 0;
  int _pendingInstallmentAmount = 0; // Σ loanAmount+loanAmount2 đơn chưa tất toán
  int _daysSinceClosing = 0;
  int _missingCostRepairs = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final db = await DBHelper().database;
      final nowDt = DateTime.now();
      final overdueDebtCutoffMs = nowDt
          .subtract(const Duration(days: 30))
          .millisecondsSinceEpoch;
      // Đầu tuần này (Thứ 2, 00:00) — dùng cho các cảnh báo "trong tuần".
      final startOfWeekMs = DateTime(nowDt.year, nowDt.month, nowDt.day)
          .subtract(Duration(days: nowDt.weekday - 1))
          .millisecondsSinceEpoch;
      final results = await Future.wait([
        db.rawQuery('SELECT COUNT(*) FROM repairs WHERE status IN (1, 2)'),
        db.rawQuery('SELECT COUNT(*) FROM products WHERE isPending = 1'),
        // Warranty expiring within 7 days
        db.query(
          'repairs',
          columns: ['deliveredAt', 'warranty'],
          where:
              "deliveredAt IS NOT NULL AND warranty IS NOT NULL AND warranty != '' AND UPPER(warranty) != 'KO BH' AND status = 4",
        ),
        // Công nợ quá hạn (>30 ngày chưa trả hết) — cùng ngưỡng "quá hạn"
        // đang dùng ở debt_view.dart để nhất quán khái niệm "khẩn cấp".
        db.rawQuery(
          'SELECT COUNT(*) FROM debts WHERE (deleted = 0 OR deleted IS NULL) '
          'AND (totalAmount - paidAmount) > 0 AND createdAt < ?',
          [overdueDebtCutoffMs],
        ),
        // Đơn bán trả góp NH TUẦN NÀY chưa được ngân hàng tất toán
        db.rawQuery(
          'SELECT COUNT(*) FROM sales WHERE isInstallment = 1 '
          'AND settlementReceivedAt IS NULL '
          'AND soldAt >= ? '
          'AND (deleted IS NULL OR deleted != 1)',
          [startOfWeekMs],
        ),
        // Lần chốt quỹ gần nhất (để tính số ngày chưa chốt)
        db.rawQuery('SELECT MAX(dateKey) as lastKey FROM cash_closings'),
        // Nếu chưa từng chốt quỹ lần nào, lấy ngày bán hàng sớm nhất làm mốc
        db.rawQuery(
          'SELECT MIN(soldAt) as firstSale FROM sales '
          'WHERE (deleted IS NULL OR deleted != 1)',
        ),
        // Đơn sửa đã giao TUẦN NÀY nhưng CHƯA GHI NHẬN giá vốn.
        // Chỉ tính khi cost = 0 VÀ chưa từng ghi nhận (costRecordedAt rỗng) —
        // đơn đã đánh dấu "không tốn giá vốn" (costRecordedAt có giá trị,
        // cost = 0) KHÔNG bị nhắc; đơn cost > 0 cũng không (đã có giá vốn).
        db.rawQuery(
          "SELECT COUNT(*) FROM repairs WHERE status = 4 "
          "AND (cost IS NULL OR cost = 0) "
          "AND (costRecordedAt IS NULL OR costRecordedAt = 0) "
          "AND deliveredAt >= ? "
          "AND (deleted IS NULL OR deleted != 1)",
          [startOfWeekMs],
        ),
        // Tổng tiền NH chưa tất toán TUẦN NÀY (cùng điều kiện với đếm đơn ở trên)
        db.rawQuery(
          'SELECT COALESCE(SUM(loanAmount + loanAmount2), 0) AS total FROM sales '
          'WHERE isInstallment = 1 AND settlementReceivedAt IS NULL '
          'AND soldAt >= ? '
          'AND (deleted IS NULL OR deleted != 1)',
          [startOfWeekMs],
        ),
      ]);

      final pendingR = (results[0].first.values.first as num?)?.toInt() ?? 0;
      final pendingS = (results[1].first.values.first as num?)?.toInt() ?? 0;
      final overdueDebts =
          (results[3].first.values.first as num?)?.toInt() ?? 0;
      final pendingInstallments =
          (results[4].first.values.first as num?)?.toInt() ?? 0;
      final missingCostRepairs =
          (results[7].first.values.first as num?)?.toInt() ?? 0;
      final pendingInstallmentAmount =
          (results[8].first['total'] as num?)?.toInt() ?? 0;

      // Số ngày chưa chốt quỹ: tính từ lần chốt gần nhất, hoặc từ ngày bán
      // hàng đầu tiên nếu chưa từng chốt quỹ lần nào.
      int daysSinceClosing = 0;
      final lastClosingKey = results[5].first['lastKey'] as String?;
      if (lastClosingKey != null && lastClosingKey.isNotEmpty) {
        try {
          final lastDate = DateFormat('yyyy-MM-dd').parse(lastClosingKey);
          daysSinceClosing = DateTime.now().difference(lastDate).inDays;
        } catch (_) {}
      } else {
        final firstSaleMs = (results[6].first['firstSale'] as num?)?.toInt();
        if (firstSaleMs != null) {
          final firstDate = DateTime.fromMillisecondsSinceEpoch(firstSaleMs);
          daysSinceClosing = DateTime.now().difference(firstDate).inDays;
        }
      }

      // Calculate expiring warranties
      int expW = 0;
      final now = DateTime.now();
      for (final r in results[2]) {
        final deliveredAt = (r['deliveredAt'] as num?)?.toInt();
        final warranty = (r['warranty'] ?? '').toString();
        if (deliveredAt == null) continue;
        int m = int.tryParse(warranty.split(' ').first) ?? 0;
        if (m > 0) {
          DateTime d = DateTime.fromMillisecondsSinceEpoch(deliveredAt);
          DateTime e = DateTime(d.year, d.month + m, d.day);
          if (e.isAfter(now) && e.difference(now).inDays <= 7) expW++;
        }
      }

      if (mounted) {
        setState(() {
          _pendingRepairs = pendingR;
          _pendingStock = pendingS;
          _expiringWarranty = expW;
          _overdueDebts = overdueDebts;
          _pendingInstallments = pendingInstallments;
          _pendingInstallmentAmount = pendingInstallmentAmount;
          _daysSinceClosing = daysSinceClosing;
          _missingCostRepairs = missingCostRepairs;
          _loaded = true;
        });
      }
    } catch (e) {
      debugPrint('ActionRequiredCard: Error loading counts: $e');
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return _buildShimmer();
    }

    final items = <_ActionItem>[];
    if (widget.enableRepair && _pendingRepairs > 0) {
      items.add(
        _ActionItem(
          icon: Icons.build_circle,
          label: '$_pendingRepairs đơn sửa chờ xử lý',
          color: Colors.blue,
          onTap: widget.onPendingRepairsTap,
        ),
      );
    }
    if (_pendingStock > 0) {
      items.add(
        _ActionItem(
          icon: Icons.pending_actions,
          label: '$_pendingStock hàng chờ xác nhận nhập kho',
          color: Colors.orange,
          onTap: widget.onPendingStockTap,
        ),
      );
    }
    if (widget.enableWarranty && _expiringWarranty > 0) {
      items.add(
        _ActionItem(
          icon: Icons.shield,
          label: '$_expiringWarranty thiết bị sắp hết bảo hành',
          color: Colors.amber.shade800,
          onTap: widget.onWarrantyTap,
        ),
      );
    }
    if (widget.enableExpiry && _expiringProducts > 0) {
      items.add(
        _ActionItem(
          icon: Icons.timer,
          label: '$_expiringProducts sản phẩm sắp hết HSD',
          color: Colors.red,
          onTap: widget.onExpiryTap,
        ),
      );
    }
    if (_daysSinceClosing >= 2) {
      items.add(
        _ActionItem(
          icon: Icons.point_of_sale,
          label: 'Đã $_daysSinceClosing ngày chưa chốt quỹ',
          color: Colors.deepOrange,
          onTap: widget.onUnclosedCashTap,
        ),
      );
    }
    if (widget.enableRepair && _missingCostRepairs > 0) {
      items.add(
        _ActionItem(
          icon: Icons.money_off,
          label: '$_missingCostRepairs đơn sửa tuần này chưa có giá vốn',
          color: Colors.purple.shade700,
          onTap: widget.onMissingCostRepairsTap,
        ),
      );
    }
    if (_overdueDebts > 0) {
      items.add(
        _ActionItem(
          icon: Icons.account_balance_wallet,
          label: '$_overdueDebts công nợ quá hạn cần thu/trả',
          color: Colors.red.shade700,
          onTap: widget.onOverdueDebtsTap,
        ),
      );
    }
    if (_pendingInstallments > 0) {
      items.add(
        _ActionItem(
          icon: Icons.account_balance,
          label: _pendingInstallmentAmount > 0
              ? 'Tiền NH tuần này chưa tất toán: ${MoneyUtils.formatVND(_pendingInstallmentAmount)} đ · $_pendingInstallments đơn'
              : '$_pendingInstallments đơn trả góp tuần này chờ NH tất toán',
          color: Colors.indigo,
          onTap: widget.onPendingInstallmentTap,
        ),
      );
    }
    if (widget.reminderCount > 0) {
      items.add(
        _ActionItem(
          icon: Icons.notifications_active_rounded,
          label: '${widget.reminderCount} việc cần xử lý',
          color: const Color(0xFFE65100),
          onTap: widget.onReminderTap,
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notification_important,
                color: Colors.orange.shade700,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'CẦN XỬ LÝ (${items.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.icon, color: item.color, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    // Invisible placeholder while loading - no spinner to avoid visual noise
    return const SizedBox.shrink();
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });
}

/// Compact finance summary - shows Doanh thu / Lợi nhuận / Quỹ
class FinanceSummaryCard extends StatelessWidget {
  final int revenue;
  final int netProfit;
  final int currentFund;
  final VoidCallback? onTap;

  const FinanceSummaryCard({
    super.key,
    required this.revenue,
    required this.netProfit,
    required this.currentFund,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Colors.blue.shade600,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'TÓM TẮT HÔM NAY',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd/MM').format(DateTime.now()),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 10,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Thu - Chi - Profit row
            Row(
              children: [
                Expanded(
                  child: _metricTile(
                    'Doanh thu',
                    MoneyUtils.formatCompact(revenue),
                    Colors.blue.shade700,
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.grey.shade200),
                Expanded(
                  child: _metricTile(
                    '📈 Lợi nhuận',
                    '${netProfit >= 0 ? '+' : ''}${MoneyUtils.formatCompact(netProfit)}',
                    netProfit >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.grey.shade200),
                Expanded(
                  child: _metricTile(
                    '🏦 Quỹ',
                    '${currentFund >= 0 ? '+' : ''}${MoneyUtils.formatCompact(currentFund)}',
                    currentFund >= 0 ? Colors.indigo : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Activity Feed card showing recent transactions
class ActivityFeedCard extends StatefulWidget {
  final bool enableRepair;
  final VoidCallback? onViewAll;

  const ActivityFeedCard({super.key, this.enableRepair = true, this.onViewAll});

  @override
  State<ActivityFeedCard> createState() => _ActivityFeedCardState();
}

class _ActivityFeedCardState extends State<ActivityFeedCard> {
  List<_ActivityItem> _activities = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    try {
      final db = await DBHelper().database;
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final startMs = todayStart.millisecondsSinceEpoch;

      // Load recent sales, repairs, expenses, debt_payments, supplier_payments from today
      final results = await Future.wait([
        // Recent sales (last 5)
        db.query(
          'sales',
          columns: [
            'firestoreId',
            'customerName',
            'totalPrice',
            'soldAt',
            'paymentMethod',
            'productNames',
            'sellerName',
          ],
          where: 'soldAt >= ? AND (deleted IS NULL OR deleted != 1)',
          whereArgs: [startMs],
          orderBy: 'soldAt DESC',
          limit: 5,
        ),
        // Recent repairs (last 5)
        if (widget.enableRepair)
          db.query(
            'repairs',
            columns: [
              'firestoreId',
              'customerName',
              'model',
              'price',
              'issue',
              'createdAt',
              'status',
              'finishedAt',
              'deliveredAt',
              'repairedBy',
              'deliveredBy',
            ],
            where:
                'createdAt >= ? OR (finishedAt IS NOT NULL AND finishedAt >= ?) '
                'OR (deliveredAt IS NOT NULL AND deliveredAt >= ?)',
            whereArgs: [startMs, startMs, startMs],
            orderBy: 'createdAt DESC',
            limit: 6,
          )
        else
          Future.value(<Map<String, dynamic>>[]),
        // Recent expenses (last 5)
        db.query(
          'expenses',
          columns: [
            'firestoreId',
            'title',
            'amount',
            'date',
            'type',
            'category',
          ],
          where: 'date >= ?',
          whereArgs: [startMs],
          orderBy: 'date DESC',
          limit: 5,
        ),
        // Recent debt payments (last 5)
        db.query(
          'debt_payments',
          columns: [
            'firestoreId',
            'amount',
            'paidAt',
            'paymentMethod',
            'debtType',
            'note',
            'personName',
            'customerName',
          ],
          where: 'paidAt >= ? AND (deleted IS NULL OR deleted != 1)',
          whereArgs: [startMs],
          orderBy: 'paidAt DESC',
          limit: 5,
        ),
        // Recent supplier payments (last 5) — JOIN suppliers to get name
        db.rawQuery(
          '''SELECT sp.firestoreId, sp.amount, sp.paidAt, sp.paymentMethod,
                    sp.supplierId, sp.note, s.name AS supplierName
             FROM supplier_payments sp
             LEFT JOIN suppliers s ON s.id = sp.supplierId
             WHERE sp.paidAt >= ? AND (sp.deleted IS NULL OR sp.deleted != 1)
             ORDER BY sp.paidAt DESC LIMIT 5''',
          [startMs],
        ),
        // Recent repair partner payments (last 5)
        db
            .query(
              'repair_partner_payments',
              columns: [
                'firestoreId',
                'amount',
                'paidAt',
                'paymentMethod',
                'partnerName',
                'note',
              ],
              where: 'paidAt >= ? AND (deleted IS NULL OR deleted != 1)',
              whereArgs: [startMs],
              orderBy: 'paidAt DESC',
              limit: 5,
            )
            .catchError((_) => <Map<String, dynamic>>[]),
        // Công nợ mới phát sinh hôm nay (last 5)
        db
            .query(
              'debts',
              columns: [
                'firestoreId',
                'personName',
                'totalAmount',
                'createdAt',
                'type',
                'note',
              ],
              where: 'createdAt >= ? AND (deleted IS NULL OR deleted != 1)',
              whereArgs: [startMs],
              orderBy: 'createdAt DESC',
              limit: 5,
            )
            .catchError((_) => <Map<String, dynamic>>[]),
      ]);

      final activities = <_ActivityItem>[];

      // Sales
      for (final s in results[0]) {
        final name = (s['customerName'] as String? ?? '').trim();
        final products = (s['productNames'] as String? ?? '').trim();
        final seller = (s['sellerName'] as String? ?? '').trim();
        final price = (s['totalPrice'] as num?)?.toInt() ?? 0;
        final at = (s['soldAt'] as num?)?.toInt() ?? 0;
        final fid = s['firestoreId'] as String?;

        // Title: "Bán hàng - <seller>" or "Bán hàng" if no seller
        final saleTitle = seller.isNotEmpty ? 'Bán hàng - $seller' : 'Bán hàng';
        // Subtitle: product name (truncated) + customer if present
        String saleSubtitle = '';
        if (products.isNotEmpty) {
          final firstProduct = products.split(',').first.trim();
          saleSubtitle = firstProduct.length > 30
              ? '${firstProduct.substring(0, 30)}…'
              : firstProduct;
        }
        if (name.isNotEmpty && name != 'Khách lẻ') {
          saleSubtitle = saleSubtitle.isNotEmpty
              ? '$saleSubtitle · $name'
              : name;
        }

        activities.add(
          _ActivityItem(
            icon: Icons.shopping_cart,
            color: Colors.green,
            title: saleTitle,
            subtitle: saleSubtitle,
            amount: '+${MoneyUtils.formatCompact(price)}',
            amountColor: Colors.green,
            timestamp: at,
            referenceType: 'sale',
            referenceId: fid,
          ),
        );
      }

      // Repairs — phân biệt Nhận sửa / Sửa xong / Giao máy + thông tin chi tiết
      for (final r in results[1]) {
        final name = (r['customerName'] ?? '').toString().trim();
        final device = (r['model'] ?? '').toString().trim();
        final issue = (r['issue'] ?? '').toString().trim();
        final status = (r['status'] as num?)?.toInt() ?? 1;
        final price = (r['price'] as num?)?.toInt() ?? 0;
        final createdAt = (r['createdAt'] as num?)?.toInt() ?? 0;
        final finishedAt = (r['finishedAt'] as num?)?.toInt() ?? 0;
        final deliveredAt = (r['deliveredAt'] as num?)?.toInt() ?? 0;
        final repairedBy = (r['repairedBy'] ?? '').toString().trim();
        final deliveredBy = (r['deliveredBy'] ?? '').toString().trim();
        final fid = r['firestoreId'] as String?;

        String rTitle;
        int rAt;
        IconData rIcon;
        Color rColor;
        String rAmount = '';
        final sub = <String>[];
        final shortIssue = issue.length > 26
            ? '${issue.substring(0, 26)}…'
            : issue;

        if (status == 4) {
          rTitle = 'Giao máy${name.isNotEmpty ? ' - $name' : ''}';
          rAt = deliveredAt > 0
              ? deliveredAt
              : (finishedAt > 0 ? finishedAt : createdAt);
          rIcon = Icons.check_circle;
          rColor = Colors.blue;
          rAmount = '+${MoneyUtils.formatCompact(price)}';
          if (device.isNotEmpty) sub.add(device);
          if (shortIssue.isNotEmpty) sub.add(shortIssue);
          if (deliveredBy.isNotEmpty) sub.add('Giao: $deliveredBy');
        } else if (status == 3) {
          rTitle =
              'Sửa xong - ${device.isNotEmpty ? device : (name.isNotEmpty ? name : 'đơn sửa')}';
          rAt = finishedAt > 0 ? finishedAt : createdAt;
          rIcon = Icons.task_alt;
          rColor = Colors.teal;
          if (name.isNotEmpty) sub.add(name);
          if (shortIssue.isNotEmpty) sub.add(shortIssue);
          if (repairedBy.isNotEmpty) sub.add('KTV: $repairedBy');
        } else {
          rTitle = 'Nhận sửa - ${device.isNotEmpty ? device : name}';
          rAt = createdAt;
          rIcon = Icons.build_circle;
          rColor = Colors.orange;
          if (device.isNotEmpty && name.isNotEmpty) sub.add(name);
          if (shortIssue.isNotEmpty) sub.add(shortIssue);
        }

        activities.add(
          _ActivityItem(
            icon: rIcon,
            color: rColor,
            title: rTitle,
            subtitle: sub.join(' · '),
            amount: rAmount,
            amountColor: Colors.blue,
            timestamp: rAt,
            referenceType: 'repair',
            referenceId: fid,
          ),
        );
      }

      // Expenses
      for (final e in results[2]) {
        final title = e['title'] ?? e['category'] ?? 'Chi phí';
        final amount = (e['amount'] as num?)?.toInt() ?? 0;
        final at = (e['date'] as num?)?.toInt() ?? 0;
        final eType = (e['type'] as String? ?? '').toUpperCase();
        final isIncome = eType == 'THU';
        final fid = e['firestoreId'] as String?;
        activities.add(
          _ActivityItem(
            icon: isIncome ? Icons.add_circle : Icons.remove_circle,
            color: isIncome ? Colors.teal : Colors.red,
            title: isIncome ? 'Thu: $title' : 'Chi: $title',
            amount: isIncome
                ? '+${MoneyUtils.formatCompact(amount)}'
                : '-${MoneyUtils.formatCompact(amount)}',
            amountColor: isIncome ? Colors.teal : Colors.red,
            timestamp: at,
            referenceType: 'expense',
            referenceId: fid,
          ),
        );
      }

      // Debt payments
      for (final d in results[3]) {
        final amount = (d['amount'] as num?)?.toInt() ?? 0;
        final at = (d['paidAt'] as num?)?.toInt() ?? 0;
        final debtType = (d['debtType'] as String? ?? '').toUpperCase();
        final note = (d['note'] ?? '').toString();
        final personName =
            ((d['personName'] as String?) ??
                    (d['customerName'] as String?) ??
                    '')
                .trim();
        final isShopOwes =
            debtType == 'SHOP_OWES' ||
            debtType == 'OTHER_SHOP_OWES' ||
            debtType == 'OWED' ||
            debtType == 'REPAIR_PARTNER';
        final debtLabel = personName.isNotEmpty
            ? personName
            : (note.isNotEmpty ? note : '');
        activities.add(
          _ActivityItem(
            icon: isShopOwes ? Icons.payment : Icons.account_balance_wallet,
            color: isShopOwes ? Colors.deepOrange : Colors.cyan,
            title: isShopOwes
                ? 'Trả nợ NCC${debtLabel.isNotEmpty ? ' - $debtLabel' : ''}'
                : 'Thu nợ KH${debtLabel.isNotEmpty ? ' - $debtLabel' : ''}',
            amount: isShopOwes
                ? '-${MoneyUtils.formatCompact(amount)}'
                : '+${MoneyUtils.formatCompact(amount)}',
            amountColor: isShopOwes ? Colors.deepOrange : Colors.cyan,
            timestamp: at,
            referenceType: 'debt_payment',
          ),
        );
      }

      // Supplier payments
      for (final sp in results[4]) {
        final amount = (sp['amount'] as num?)?.toInt() ?? 0;
        final at = (sp['paidAt'] as num?)?.toInt() ?? 0;
        final supplierName = ((sp['supplierName'] as String?) ?? '').trim();
        final supplierLabel = supplierName.isNotEmpty ? supplierName : 'NCC';
        activities.add(
          _ActivityItem(
            icon: Icons.local_shipping,
            color: Colors.brown,
            title: 'Trả NCC - $supplierLabel',
            amount: '-${MoneyUtils.formatCompact(amount)}',
            amountColor: Colors.brown,
            timestamp: at,
            referenceType: 'supplier_payment',
          ),
        );
      }

      // Repair partner payments
      for (final rp in results[5]) {
        final amount = (rp['amount'] as num?)?.toInt() ?? 0;
        final at = (rp['paidAt'] as num?)?.toInt() ?? 0;
        final partner = (rp['partnerName'] ?? 'Đối tác').toString();
        activities.add(
          _ActivityItem(
            icon: Icons.handshake,
            color: Colors.indigo,
            title: 'TT đối tác - $partner',
            amount: '-${MoneyUtils.formatCompact(amount)}',
            amountColor: Colors.indigo,
            timestamp: at,
            referenceType: 'partner_payment',
          ),
        );
      }

      // Công nợ mới tạo hôm nay
      for (final dbt in results[6]) {
        final amount = (dbt['totalAmount'] as num?)?.toInt() ?? 0;
        final at = (dbt['createdAt'] as num?)?.toInt() ?? 0;
        final name = ((dbt['personName'] as String?) ?? '').trim();
        final t = ((dbt['type'] as String?) ?? '').toUpperCase();
        final isShopOwes = t.contains('SHOP_OWES') ||
            t == 'OWED' ||
            t == 'REPAIR_PARTNER';
        activities.add(
          _ActivityItem(
            icon: Icons.note_add_outlined,
            color: Colors.blueGrey,
            title: isShopOwes
                ? 'Công nợ phải trả mới${name.isNotEmpty ? ' - $name' : ''}'
                : 'Công nợ khách mới${name.isNotEmpty ? ' - $name' : ''}',
            amount: MoneyUtils.formatCompact(amount),
            amountColor: Colors.blueGrey,
            timestamp: at,
            referenceType: 'debt',
            referenceId: dbt['firestoreId'] as String?,
          ),
        );
      }

      // Sort by timestamp desc, take top 10
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final top = activities.take(10).toList();

      if (mounted) {
        setState(() {
          _activities = top;
          _loaded = true;
        });
      }
    } catch (e) {
      debugPrint('ActivityFeedCard: Error: $e');
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      // Invisible placeholder while loading - no spinner to avoid visual noise
      return const SizedBox.shrink();
    }

    if (_activities.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.history, color: Colors.grey.shade400, size: 20),
            const SizedBox(width: 10),
            Text(
              'Chưa có hoạt động hôm nay',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.purple.shade400, size: 16),
                const SizedBox(width: 6),
                Text(
                  'HOẠT ĐỘNG HÔM NAY',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade600,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_activities.length} mục',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ..._activities.map((a) => _buildActivityRow(a)),
          if (widget.onViewAll != null)
            InkWell(
              onTap: widget.onViewAll,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Center(
                  child: Text(
                    'Xem tất cả ›',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.purple.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _navigateToDetail(_ActivityItem item) async {
    if (item.referenceId == null || item.referenceId!.isEmpty) return;
    final db = DBHelper();
    try {
      switch (item.referenceType) {
        case 'sale':
          final sale = await db.getSaleByFirestoreId(item.referenceId!);
          if (sale != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SaleDetailView(sale: sale)),
            );
          }
          break;
        case 'repair':
          final repair = await db.getRepairByFirestoreId(item.referenceId!);
          if (repair != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RepairDetailView(repair: repair),
              ),
            );
          }
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('ActivityFeedCard: Navigation error: $e');
    }
  }

  Widget _buildActivityRow(_ActivityItem item) {
    final time = item.timestamp > 0
        ? DateFormat(
            'HH:mm',
          ).format(DateTime.fromMillisecondsSinceEpoch(item.timestamp))
        : '';

    final canNavigate =
        item.referenceId != null &&
        item.referenceId!.isNotEmpty &&
        (item.referenceType == 'sale' || item.referenceType == 'repair');

    return InkWell(
      onTap: canNavigate ? () => _navigateToDetail(item) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            // Time column
            SizedBox(
              width: 40,
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Icon
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(item.icon, color: item.color, size: 14),
            ),
            const SizedBox(width: 8),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.subtitle.isNotEmpty)
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Amount
            if (item.amount.isNotEmpty)
              Text(
                item.amount,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: item.amountColor,
                ),
              ),
            if (canNavigate)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String amount;
  final Color amountColor;
  final int timestamp;
  final String? referenceType;
  final String? referenceId;

  const _ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle = '',
    required this.amount,
    required this.amountColor,
    required this.timestamp,
    this.referenceType,
    this.referenceId,
  });
}
