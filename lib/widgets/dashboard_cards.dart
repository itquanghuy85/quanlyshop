import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../core/utils/money_utils.dart';
import '../services/activity_navigator.dart';
import '../services/reminder_service.dart';

/// Thẻ "CẦN XỬ LÝ" ở Trang chủ.
///
/// ĐÂY LÀ BẢN RÚT GỌN của trang Nhắc nhở ([RemindersView]) — cùng một danh
/// sách [TaskReminder] do [ReminderService] dựng ra, không tự đếm gì thêm.
///
/// Trước 2026-09-06 thẻ này tự chạy ~9 câu SQL riêng để đếm việc, rồi còn kèm
/// thêm một dòng "N việc cần xử lý" trỏ ngược sang trang Nhắc nhở. Hệ quả:
///  - Cùng một việc hiện 2 lần với 2 con số khác nhau (đơn sửa chờ xử lý đếm
///    status 1+2 ở thẻ nhưng chỉ status 1 ở trang Nhắc nhở).
///  - "Hàng chờ xác nhận nhập kho" ở thẻ đếm `products.isPending` (kho tạm —
///    sản phẩm chưa có giá vốn) trong khi màn mở ra lại là danh sách phiếu
///    `stock_entries` status=draft ⇒ số không bao giờ khớp danh sách.
///  - Các câu SQL của thẻ không lọc `shopId`.
/// Nay mọi phép đếm nằm trong [ReminderService] (có lọc shopId), thẻ chỉ vẽ.
class ActionRequiredCard extends StatelessWidget {
  /// Danh sách đã load sẵn từ [ReminderService.loadReminders].
  final List<TaskReminder> reminders;

  /// Mở màn hình tương ứng cho 1 mục.
  final void Function(TaskReminder reminder)? onTapReminder;

  /// Mở trang Nhắc nhở đầy đủ.
  final VoidCallback? onSeeAll;

  /// Số mục tối đa hiển thị trên Trang chủ; phần còn lại gom vào dòng
  /// "Xem tất cả".
  final int maxItems;

  const ActionRequiredCard({
    super.key,
    required this.reminders,
    this.onTapReminder,
    this.onSeeAll,
    this.maxItems = 5,
  });

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) return const SizedBox.shrink();

    final shown = reminders.take(maxItems).toList();
    final hiddenCount = reminders.length - shown.length;
    final totalTasks = ReminderService.totalCount(reminders);

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
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Icon(
                  Icons.notification_important,
                  color: Colors.orange.shade700,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'CẦN XỬ LÝ ($totalTasks)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (onSeeAll != null)
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 14,
                    color: Colors.orange.shade700,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...shown.map((r) => _reminderRow(r)),
          if (hiddenCount > 0)
            InkWell(
              onTap: onSeeAll,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.orange.shade800,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Xem tất cả — còn $hiddenCount việc khác',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.orange.shade400,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _reminderRow(TaskReminder r) {
    // Ưu tiên `subtitle` vì nó đã kèm sẵn con số (vd "3 đơn sửa xong chờ duyệt
    // giao") — giữ đúng cách diễn đạt của thẻ cũ, không lặp lại tiêu đề.
    final label = r.subtitle.isNotEmpty ? r.subtitle : r.title;
    return InkWell(
      onTap: onTapReminder == null ? null : () => onTapReminder!(r),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: r.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(r.icon, color: r.color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  if (r.totalAmount != null && r.totalAmount! > 0)
                    Text(
                      '${MoneyUtils.formatVND(r.totalAmount!)} đ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: r.color,
                      ),
                    ),
                ],
              ),
            ),
            if (r.priority == ReminderPriority.urgent)
              Container(
                margin: const EdgeInsets.only(right: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFD32F2F),
                  shape: BoxShape.circle,
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
    );
  }
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
                'partnerId',
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
            expenseMode: isIncome ? 'THU' : 'CHI',
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
            referenceId: d['firestoreId'] as String?,
            payable: isShopOwes,
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
            referenceId: sp['firestoreId'] as String?,
            localId: (sp['supplierId'] as num?)?.toInt(),
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
            referenceId: rp['firestoreId'] as String?,
            localId: (rp['partnerId'] as num?)?.toInt(),
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
            payable: isShopOwes,
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

  /// Mở chi tiết của một dòng hoạt động.
  ///
  /// Trước đây hàm này chỉ biết `sale` và `repair`, và khi tra không ra bản ghi
  /// thì `return` im lặng — bấm vào như không có gì. Nay đẩy hết sang
  /// [ActivityNavigator] để tất cả danh sách hoạt động dùng chung một bảng đích
  /// và cùng báo rõ khi không mở được.
  Future<void> _navigateToDetail(_ActivityItem item) async {
    await ActivityNavigator.open(
      context,
      type: item.referenceType,
      firestoreId: item.referenceId,
      localId: item.localId,
      expenseMode: item.expenseMode,
      payable: item.payable,
    );
  }

  Widget _buildActivityRow(_ActivityItem item) {
    final time = item.timestamp > 0
        ? DateFormat(
            'HH:mm',
          ).format(DateTime.fromMillisecondsSinceEpoch(item.timestamp))
        : '';

    final canNavigate = ActivityNavigator.canOpen(
      type: item.referenceType,
      firestoreId: item.referenceId,
      localId: item.localId,
    );

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

  /// Khoá SQLite của nhà cung cấp / đối tác sửa chữa — hai màn chi tiết đó
  /// nhận vào cả object nên phải tra theo id nội bộ, không dùng firestoreId.
  final int? localId;

  /// `'THU'` / `'CHI'` để màn Thu Chi mở đúng tab.
  final String? expenseMode;

  /// Khoản này là SHOP NỢ (phải trả) — để màn Công nợ mở đúng tab.
  final bool payable;

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
    this.localId,
    this.expenseMode,
    this.payable = false,
  });
}
