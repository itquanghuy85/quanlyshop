import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../data/db_helper.dart';
import '../models/payment_request_model.dart';
import 'user_service.dart';
import 'stock_entry_service.dart';

/// Category cho mỗi loại nhắc nhở
enum ReminderCategory {
  repairApproval,    // Duyệt giao máy sửa
  repairAssignment,  // Máy cần sửa (thợ)  
  deliveryTask,      // Giao máy cho khách (nhân viên)
  activeDebt,        // Công nợ chưa thu/trả
  pendingStock,      // Hàng chờ xác nhận nhập kho
  pendingPurchase,   // Đơn nhập chờ duyệt
  salesReturn,       // Đơn trả hàng chờ duyệt
  paymentRequest,    // Yêu cầu đóng tiền chờ duyệt
  paymentIntent,     // Lệnh chi chờ thực hiện
  // ─── Gộp từ thẻ "CẦN XỬ LÝ" ở Trang chủ (dashboard_cards.dart) ───
  // Trước đây thẻ đó tự chạy SQL riêng, đếm lệch với trang Nhắc nhở và có
  // mục "N việc cần xử lý" trỏ ngược lại chính trang Nhắc nhở => trùng lặp.
  warrantyExpiring,  // Thiết bị sắp hết bảo hành
  unclosedCash,      // Nhiều ngày chưa chốt quỹ
  missingCostRepair, // Đơn sửa đã giao nhưng chưa ghi nhận giá vốn
  pendingInstallment,// Đơn trả góp chờ ngân hàng tất toán
}

/// Độ ưu tiên
enum ReminderPriority { urgent, high, normal }

/// Model cho 1 nhóm task nhắc nhở
class TaskReminder {
  final ReminderCategory category;
  final ReminderPriority priority;
  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color color;
  /// Tổng giá trị tiền (nếu có) — dùng cho debt/payment
  final int? totalAmount;

  const TaskReminder({
    required this.category,
    required this.priority,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
    this.totalAmount,
  });
}

/// Service tổng hợp tất cả task cần nhắc nhở theo role & permission
class ReminderService {
  static final DBHelper _db = DBHelper();

  /// Ngưỡng "công nợ quá hạn" (ngày) — giữ cùng con số với `debt_view.dart`
  /// và thẻ CẦN XỬ LÝ cũ để khái niệm "quá hạn" không đá nhau giữa các màn.
  static const int overdueDebtDays = 30;

  /// Số ngày không chốt quỹ liên tiếp thì bắt đầu nhắc.
  static const int unclosedCashThresholdDays = 2;

  /// Load tất cả reminder theo role và permission hiện tại.
  /// Returns danh sách đã sort theo priority.
  ///
  /// [enableRepair] / [enableWarranty] là cờ ngành nghề của shop
  /// (`ShopSettings`) — shop không làm sửa chữa thì không nhắc việc sửa chữa
  /// / bảo hành. Mặc định `true` để giữ nguyên hành vi cho caller cũ.
  static Future<List<TaskReminder>> loadReminders({
    required String role,
    required Map<String, bool> permissions,
    bool enableRepair = true,
    bool enableWarranty = true,
  }) async {
    final reminders = <TaskReminder>[];
    final isOwnerOrManager = _isOwnerOrManager(role);
    final isTechnician = role == 'technician';
    final canViewRepairs = (isOwnerOrManager || permissions['allowViewRepairs'] == true) &&
        enableRepair;
    final canViewSales = isOwnerOrManager || permissions['allowViewSales'] == true;
    final canViewInventory = isOwnerOrManager || permissions['allowViewInventory'] == true;
    final canViewDebts = isOwnerOrManager || permissions['allowViewDebts'] == true;
    final canViewRevenue = isOwnerOrManager || permissions['allowViewRevenue'] == true;

    // Parallel load tất cả data sources
    final futures = <String, Future>{};

    if (canViewRepairs) {
      futures['repairApproval'] = _countPendingApproval();
      // Thợ đã có mục riêng "Máy cần sửa" bên dưới → loại đơn của chính họ ra
      // khỏi con số toàn shop, nếu không badge tổng đếm 1 đơn thành 2 việc.
      futures['repairNeedWork'] = _countRepairsNeedWork(
        excludeUid: isTechnician ? FirebaseAuth.instance.currentUser?.uid : null,
      );
      futures['repairDone'] = _countRepairsDoneForDelivery();
      futures['missingCostRepair'] = _countMissingCostRepairs();
    }
    if (canViewRepairs && enableWarranty) {
      futures['warrantyExpiring'] = _countExpiringWarranty();
    }
    if (isTechnician && enableRepair) {
      futures['technicianRepairs'] = _countTechnicianRepairs();
    }
    if (canViewDebts) {
      futures['debts'] = _loadActiveDebts();
    }
    if (canViewInventory) {
      futures['pendingStock'] = _countPendingStock();
      futures['pendingPurchase'] = _countPendingPurchaseOrders();
    }
    if (canViewSales) {
      futures['salesReturn'] = _countPendingSalesReturns();
      futures['pendingInstallment'] = _loadPendingInstallments();
    }
    if (canViewRevenue) {
      futures['unclosedCash'] = _daysSinceLastClosing();
    }
    if (isOwnerOrManager) {
      futures['paymentRequest'] = _countPendingPaymentRequests();
      futures['paymentIntent'] = _countPendingPaymentIntents();
    }

    // Await all
    final results = <String, dynamic>{};
    final keys = futures.keys.toList();
    final values = await Future.wait(futures.values);
    for (var i = 0; i < keys.length; i++) {
      results[keys[i]] = values[i];
    }

    // Build reminders from results
    // 1. Repair Approval (owner/manager)
    if (results.containsKey('repairApproval')) {
      final count = results['repairApproval'] as int;
      if (count > 0) {
        reminders.add(TaskReminder(
          category: ReminderCategory.repairApproval,
          priority: ReminderPriority.urgent,
          title: 'Chờ duyệt giao máy',
          subtitle: '$count đơn sửa xong chờ duyệt giao',
          count: count,
          icon: Icons.approval_rounded,
          color: const Color(0xFFE65100),
        ));
      }
    }

    // 2. Payment Requests (owner/manager)
    if (results.containsKey('paymentRequest')) {
      final count = results['paymentRequest'] as int;
      if (count > 0) {
        reminders.add(TaskReminder(
          category: ReminderCategory.paymentRequest,
          priority: ReminderPriority.urgent,
          title: 'Yêu cầu đóng tiền',
          subtitle: '$count yêu cầu chờ xử lý',
          count: count,
          icon: Icons.payment_rounded,
          color: const Color(0xFFC62828),
        ));
      }
    }

    // 3. Technician repairs
    if (results.containsKey('technicianRepairs')) {
      final count = results['technicianRepairs'] as int;
      if (count > 0) {
        reminders.add(TaskReminder(
          category: ReminderCategory.repairAssignment,
          priority: ReminderPriority.urgent,
          title: 'Máy cần sửa',
          subtitle: '$count máy đang chờ bạn sửa',
          count: count,
          icon: Icons.build_circle_rounded,
          color: const Color(0xFF1565C0),
        ));
      }
    }

    // 4. Repairs need work (received, not started)
    if (results.containsKey('repairNeedWork')) {
      final count = results['repairNeedWork'] as int;
      if (count > 0) {
        reminders.add(TaskReminder(
          category: ReminderCategory.repairAssignment,
          priority: ReminderPriority.high,
          title: 'Đơn sửa chờ xử lý',
          subtitle: '$count máy tiếp nhận / đang sửa',
          count: count,
          icon: Icons.phone_android_rounded,
          color: const Color(0xFF1976D2),
        ));
      }
    }

    // 5. Repairs done - ready for delivery (employee)
    if (results.containsKey('repairDone')) {
      final count = results['repairDone'] as int;
      if (count > 0) {
        reminders.add(TaskReminder(
          category: ReminderCategory.deliveryTask,
          priority: ReminderPriority.high,
          title: 'Giao máy cho khách',
          subtitle: '$count máy sửa xong chờ giao',
          count: count,
          icon: Icons.local_shipping_rounded,
          color: const Color(0xFF2E7D32),
        ));
      }
    }

    // 6. Active debts.
    // Khoản "quá hạn" (> [overdueDebtDays] ngày) là TẬP CON của khoản đang nợ
    // nên chỉ nâng độ ưu tiên + ghi chú thêm vào chính mục này, KHÔNG tách
    // thành mục riêng — tách ra là đếm 1 khoản nợ thành 2 việc trên badge.
    if (results.containsKey('debts')) {
      final debtInfo = results['debts'] as _DebtSummary;
      if (debtInfo.customerOwes > 0) {
        reminders.add(TaskReminder(
          category: ReminderCategory.activeDebt,
          priority: debtInfo.customerOverdueCount > 0
              ? ReminderPriority.urgent
              : ReminderPriority.high,
          title: 'Công nợ khách hàng',
          subtitle: debtInfo.customerOverdueCount > 0
              ? '${debtInfo.customerOwesCount} khách còn nợ • ${debtInfo.customerOverdueCount} quá hạn'
              : '${debtInfo.customerOwesCount} khách còn nợ',
          count: debtInfo.customerOwesCount,
          icon: Icons.person_pin_rounded,
          color: const Color(0xFFE65100),
          totalAmount: debtInfo.customerOwes,
        ));
      }
      if (debtInfo.shopOwes > 0) {
        reminders.add(TaskReminder(
          category: ReminderCategory.activeDebt,
          priority: debtInfo.shopOverdueCount > 0
              ? ReminderPriority.urgent
              : ReminderPriority.high,
          title: 'Shop nợ NCC',
          subtitle: debtInfo.shopOverdueCount > 0
              ? '${debtInfo.shopOwesCount} khoản chưa trả • ${debtInfo.shopOverdueCount} quá hạn'
              : '${debtInfo.shopOwesCount} khoản chưa trả',
          count: debtInfo.shopOwesCount,
          icon: Icons.store_rounded,
          color: const Color(0xFFF57C00),
          totalAmount: debtInfo.shopOwes,
        ));
      }
    }

    // 7. Sales Returns pending
    if (results.containsKey('salesReturn')) {
      final count = results['salesReturn'] as int;
      if (count > 0) {
        reminders.add(TaskReminder(
          category: ReminderCategory.salesReturn,
          priority: ReminderPriority.normal,
          title: 'Trả hàng chờ duyệt',
          subtitle: '$count đơn trả hàng chờ xác nhận',
          count: count,
          icon: Icons.assignment_return_rounded,
          color: const Color(0xFF7B1FA2),
        ));
      }
    }

    // 8. Pending stock (nhập kho chờ xác nhận)
    if (results.containsKey('pendingStock')) {
      final count = results['pendingStock'] as int;
      if (count > 0) {
        reminders.add(TaskReminder(
          category: ReminderCategory.pendingStock,
          priority: ReminderPriority.normal,
          title: 'Nhập kho chờ xác nhận',
          subtitle: '$count phiếu nhập hàng chờ duyệt',
          count: count,
          icon: Icons.inventory_2_rounded,
          color: const Color(0xFF00838F),
        ));
      }
    }

    // 9. Pending purchase orders
    if (results.containsKey('pendingPurchase')) {
      final count = results['pendingPurchase'] as int;
      if (count > 0) {
        reminders.add(TaskReminder(
          category: ReminderCategory.pendingPurchase,
          priority: ReminderPriority.normal,
          title: 'Đơn nhập chờ duyệt',
          subtitle: '$count đơn hàng nhập chờ xác nhận',
          count: count,
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF4527A0),
        ));
      }
    }

    // 10. Payment intents
    if (results.containsKey('paymentIntent')) {
      final count = results['paymentIntent'] as int;
      if (count > 0) {
        reminders.add(TaskReminder(
          category: ReminderCategory.paymentIntent,
          priority: ReminderPriority.normal,
          title: 'Lệnh chi chờ thực hiện',
          subtitle: '$count lệnh chi/thu chưa hoàn thành',
          count: count,
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFF558B2F),
        ));
      }
    }

    // ─── 11-14. Các mục gộp từ thẻ "CẦN XỬ LÝ" ở Trang chủ ───────────────

    // 11. Chưa chốt quỹ nhiều ngày
    if (results.containsKey('unclosedCash')) {
      final days = results['unclosedCash'] as int;
      if (days >= unclosedCashThresholdDays) {
        reminders.add(TaskReminder(
          category: ReminderCategory.unclosedCash,
          priority: ReminderPriority.high,
          title: 'Chưa chốt quỹ',
          subtitle: 'Đã $days ngày chưa chốt quỹ',
          // count = 1 việc (không phải 1 việc / mỗi ngày) để badge tổng không
          // bị thổi phồng khi bỏ chốt quỹ lâu ngày.
          count: 1,
          icon: Icons.point_of_sale_rounded,
          color: const Color(0xFFE64A19),
        ));
      }
    }

    // 12. Đơn sửa đã giao tuần này nhưng chưa ghi nhận giá vốn
    if (results.containsKey('missingCostRepair')) {
      final count = results['missingCostRepair'] as int;
      if (count > 0) {
        reminders.add(TaskReminder(
          category: ReminderCategory.missingCostRepair,
          priority: ReminderPriority.normal,
          title: 'Đơn sửa thiếu giá vốn',
          subtitle: '$count đơn tuần này chưa nhập giá vốn',
          count: count,
          icon: Icons.money_off_rounded,
          color: const Color(0xFF6A1B9A),
        ));
      }
    }

    // 13. Trả góp ngân hàng tuần này chưa tất toán
    if (results.containsKey('pendingInstallment')) {
      final info = results['pendingInstallment'] as _InstallmentSummary;
      if (info.count > 0) {
        reminders.add(TaskReminder(
          category: ReminderCategory.pendingInstallment,
          priority: ReminderPriority.normal,
          title: 'Chờ NH tất toán',
          subtitle: '${info.count} đơn trả góp tuần này chưa về tiền',
          count: info.count,
          icon: Icons.account_balance_rounded,
          color: const Color(0xFF303F9F),
          totalAmount: info.amount > 0 ? info.amount : null,
        ));
      }
    }

    // 14. Thiết bị sắp hết bảo hành
    if (results.containsKey('warrantyExpiring')) {
      final count = results['warrantyExpiring'] as int;
      if (count > 0) {
        reminders.add(TaskReminder(
          category: ReminderCategory.warrantyExpiring,
          priority: ReminderPriority.normal,
          title: 'Sắp hết bảo hành',
          subtitle: '$count thiết bị hết BH trong 7 ngày',
          count: count,
          icon: Icons.shield_rounded,
          color: const Color(0xFFEF6C00),
        ));
      }
    }

    // Sort: urgent → high → normal, then by count desc
    reminders.sort((a, b) {
      final priComp = a.priority.index.compareTo(b.priority.index);
      if (priComp != 0) return priComp;
      return b.count.compareTo(a.count);
    });

    return reminders;
  }

  /// Total badge count cho icon nhắc nhở trên Home.
  ///
  /// Chỉ dùng khi caller KHÔNG cần danh sách. Trang chủ nên gọi thẳng
  /// [loadReminders] rồi tự cộng — gọi cả hai là chạy trùng nguyên bộ query.
  static Future<int> getTotalReminderCount({
    required String role,
    required Map<String, bool> permissions,
    bool enableRepair = true,
    bool enableWarranty = true,
  }) async {
    final reminders = await loadReminders(
      role: role,
      permissions: permissions,
      enableRepair: enableRepair,
      enableWarranty: enableWarranty,
    );
    return totalCount(reminders);
  }

  /// Tổng số việc của một danh sách reminder đã load sẵn.
  static int totalCount(List<TaskReminder> reminders) =>
      reminders.fold<int>(0, (total, r) => total + r.count);

  // ============ PRIVATE QUERY HELPERS ============

  static bool _isOwnerOrManager(String role) =>
      role == 'owner' || role == 'manager' || role == 'admin' ||
      UserService.isCurrentUserSuperAdmin();

  /// Đếm đơn sửa chờ duyệt giao (status=3, pendingDeliveryApproval=1)
  static Future<int> _countPendingApproval() async {
    try {
      final db = await _db.database;
      final shopId = UserService.getShopIdSync();
      String where = 'status = 3 AND pendingDeliveryApproval = 1 AND (deleted = 0 OR deleted IS NULL)';
      List<dynamic> args = [];
      if (shopId != null && shopId.isNotEmpty) {
        where += ' AND (shopId = ? OR shopId IS NULL)';
        args.add(shopId);
      }
      final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM repairs WHERE $where', args);
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('ReminderService._countPendingApproval error: $e');
      return 0;
    }
  }

  /// Đếm đơn sửa đang xử lý — status 1 (Tiếp nhận) + 2 (Đang sửa).
  ///
  /// Cùng phạm vi với `OrderListView(statusFilter: [1, 2])` mà mục này mở ra,
  /// và với con số mà thẻ "CẦN XỬ LÝ" cũ đếm. Trước khi gộp, service này chỉ
  /// đếm status=1 còn thẻ đếm cả 1 và 2 → hai chỗ ra hai số khác nhau cho
  /// cùng một việc.
  ///
  /// [excludeUid] loại các đơn đã được giao cho chính người đang xem (thợ) vì
  /// họ đã có mục riêng "Máy cần sửa".
  static Future<int> _countRepairsNeedWork({String? excludeUid}) async {
    try {
      final db = await _db.database;
      final shopId = UserService.getShopIdSync();
      String where = 'status IN (1, 2) AND (deleted = 0 OR deleted IS NULL)';
      List<dynamic> args = [];
      if (shopId != null && shopId.isNotEmpty) {
        where += ' AND (shopId = ? OR shopId IS NULL)';
        args.add(shopId);
      }
      if (excludeUid != null && excludeUid.isNotEmpty) {
        where += ' AND (repairedBy IS NULL OR repairedBy != ?)';
        args.add(excludeUid);
      }
      final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM repairs WHERE $where', args);
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('ReminderService._countRepairsNeedWork error: $e');
      return 0;
    }
  }

  /// Đếm máy sửa xong chờ giao (status=3, pendingDeliveryApproval != 1 hoặc null)
  static Future<int> _countRepairsDoneForDelivery() async {
    try {
      final db = await _db.database;
      final shopId = UserService.getShopIdSync();
      String where = 'status = 3 AND (pendingDeliveryApproval = 0 OR pendingDeliveryApproval IS NULL) AND (deleted = 0 OR deleted IS NULL)';
      List<dynamic> args = [];
      if (shopId != null && shopId.isNotEmpty) {
        where += ' AND (shopId = ? OR shopId IS NULL)';
        args.add(shopId);
      }
      final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM repairs WHERE $where', args);
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('ReminderService._countRepairsDoneForDelivery error: $e');
      return 0;
    }
  }

  /// Đếm máy được assign cho thợ hiện tại (status 1 or 2, repairedBy = current uid)
  static Future<int> _countTechnicianRepairs() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return 0;
      final db = await _db.database;
      final shopId = UserService.getShopIdSync();
      String where = 'status IN (1, 2) AND repairedBy = ? AND (deleted = 0 OR deleted IS NULL)';
      List<dynamic> args = [uid];
      if (shopId != null && shopId.isNotEmpty) {
        where += ' AND (shopId = ? OR shopId IS NULL)';
        args.add(shopId);
      }
      final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM repairs WHERE $where', args);
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('ReminderService._countTechnicianRepairs error: $e');
      return 0;
    }
  }

  /// Load tổng hợp công nợ active (kèm số khoản đã quá hạn)
  static Future<_DebtSummary> _loadActiveDebts() async {
    try {
      final allDebts = await _db.getAllDebts();
      final overdueBefore = DateTime.now()
          .subtract(const Duration(days: overdueDebtDays))
          .millisecondsSinceEpoch;
      int customerOwes = 0, customerOwesCount = 0, customerOverdueCount = 0;
      int shopOwes = 0, shopOwesCount = 0, shopOverdueCount = 0;

      for (final d in allDebts) {
        final status = (d['status'] ?? '').toString().toUpperCase();
        if (status == 'PAID' || status == 'CANCELLED') continue;

        final total = (d['totalAmount'] as num?)?.toInt() ?? 0;
        final paid = (d['paidAmount'] as num?)?.toInt() ?? 0;
        final remain = total - paid;
        if (remain <= 0) continue;

        final createdAt = (d['createdAt'] as num?)?.toInt();
        final isOverdue = createdAt != null && createdAt < overdueBefore;

        final type = (d['type'] ?? '').toString().toUpperCase();
        if (type == 'CUSTOMER_OWES' || type == 'OTHER_CUSTOMER_OWES' || type == 'OWE') {
          customerOwes += remain;
          customerOwesCount++;
          if (isOverdue) customerOverdueCount++;
        } else if (type == 'SHOP_OWES' || type == 'OTHER_SHOP_OWES' || type == 'OWED') {
          shopOwes += remain;
          shopOwesCount++;
          if (isOverdue) shopOverdueCount++;
        }
      }
      return _DebtSummary(
        customerOwes: customerOwes,
        customerOwesCount: customerOwesCount,
        customerOverdueCount: customerOverdueCount,
        shopOwes: shopOwes,
        shopOwesCount: shopOwesCount,
        shopOverdueCount: shopOverdueCount,
      );
    } catch (e) {
      debugPrint('ReminderService._loadActiveDebts error: $e');
      return const _DebtSummary();
    }
  }

  /// Số ngày kể từ lần chốt quỹ gần nhất. Nếu chưa từng chốt quỹ thì tính từ
  /// ngày bán hàng đầu tiên; chưa bán gì thì trả 0 (không nhắc shop mới mở).
  static Future<int> _daysSinceLastClosing() async {
    try {
      final db = await _db.database;
      final lastRows = await db.rawQuery(
        'SELECT MAX(dateKey) as lastKey FROM cash_closings',
      );
      final lastKey =
          lastRows.isNotEmpty ? lastRows.first['lastKey'] as String? : null;
      if (lastKey != null && lastKey.isNotEmpty) {
        final lastDate = DateFormat('yyyy-MM-dd').parse(lastKey);
        return DateTime.now().difference(lastDate).inDays;
      }
      final firstRows = await db.rawQuery(
        'SELECT MIN(soldAt) as firstSale FROM sales '
        'WHERE (deleted IS NULL OR deleted != 1)',
      );
      final firstSaleMs = firstRows.isNotEmpty
          ? (firstRows.first['firstSale'] as num?)?.toInt()
          : null;
      if (firstSaleMs == null) return 0;
      return DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(firstSaleMs))
          .inDays;
    } catch (e) {
      debugPrint('ReminderService._daysSinceLastClosing error: $e');
      return 0;
    }
  }

  /// Đếm đơn sửa đã giao TUẦN NÀY nhưng chưa ghi nhận giá vốn.
  /// Chỉ tính khi cost = 0 VÀ chưa từng ghi nhận (costRecordedAt rỗng) — đơn
  /// đã đánh dấu "không tốn giá vốn" (costRecordedAt có giá trị) không bị nhắc.
  static Future<int> _countMissingCostRepairs() async {
    try {
      final db = await _db.database;
      final shopId = UserService.getShopIdSync();
      String where =
          'status = 4 AND (cost IS NULL OR cost = 0) '
          'AND (costRecordedAt IS NULL OR costRecordedAt = 0) '
          'AND deliveredAt >= ? AND (deleted IS NULL OR deleted != 1)';
      final args = <dynamic>[_startOfWeekMs()];
      if (shopId != null && shopId.isNotEmpty) {
        where += ' AND (shopId = ? OR shopId IS NULL)';
        args.add(shopId);
      }
      final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM repairs WHERE $where',
        args,
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('ReminderService._countMissingCostRepairs error: $e');
      return 0;
    }
  }

  /// Đơn trả góp ngân hàng bán TUẦN NÀY mà ngân hàng chưa tất toán.
  static Future<_InstallmentSummary> _loadPendingInstallments() async {
    try {
      final db = await _db.database;
      final shopId = UserService.getShopIdSync();
      String where =
          'isInstallment = 1 AND settlementReceivedAt IS NULL '
          'AND soldAt >= ? AND (deleted IS NULL OR deleted != 1)';
      final args = <dynamic>[_startOfWeekMs()];
      if (shopId != null && shopId.isNotEmpty) {
        where += ' AND (shopId = ? OR shopId IS NULL)';
        args.add(shopId);
      }
      final rows = await db.rawQuery(
        'SELECT COUNT(*) as cnt, '
        'COALESCE(SUM(COALESCE(loanAmount, 0) + COALESCE(loanAmount2, 0)), 0) as total '
        'FROM sales WHERE $where',
        args,
      );
      if (rows.isEmpty) return const _InstallmentSummary();
      return _InstallmentSummary(
        count: (rows.first['cnt'] as num?)?.toInt() ?? 0,
        amount: (rows.first['total'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('ReminderService._loadPendingInstallments error: $e');
      return const _InstallmentSummary();
    }
  }

  /// Đếm thiết bị đã giao còn bảo hành nhưng hết hạn trong 7 ngày tới.
  static Future<int> _countExpiringWarranty() async {
    try {
      final db = await _db.database;
      final shopId = UserService.getShopIdSync();
      String where =
          "deliveredAt IS NOT NULL AND warranty IS NOT NULL "
          "AND warranty != '' AND UPPER(warranty) != 'KO BH' AND status = 4 "
          "AND (deleted IS NULL OR deleted != 1)";
      final args = <dynamic>[];
      if (shopId != null && shopId.isNotEmpty) {
        where += ' AND (shopId = ? OR shopId IS NULL)';
        args.add(shopId);
      }
      final rows = await db.query(
        'repairs',
        columns: ['deliveredAt', 'warranty'],
        where: where,
        whereArgs: args,
      );
      final now = DateTime.now();
      int count = 0;
      for (final r in rows) {
        final deliveredAt = (r['deliveredAt'] as num?)?.toInt();
        if (deliveredAt == null) continue;
        final months =
            int.tryParse((r['warranty'] ?? '').toString().split(' ').first) ?? 0;
        if (months <= 0) continue;
        final d = DateTime.fromMillisecondsSinceEpoch(deliveredAt);
        final expiry = DateTime(d.year, d.month + months, d.day);
        if (expiry.isAfter(now) && expiry.difference(now).inDays <= 7) count++;
      }
      return count;
    } catch (e) {
      debugPrint('ReminderService._countExpiringWarranty error: $e');
      return 0;
    }
  }

  /// Mốc 00:00 Thứ 2 của tuần hiện tại (ms).
  static int _startOfWeekMs() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1))
        .millisecondsSinceEpoch;
  }

  /// Đếm phiếu nhập kho draft (chờ xác nhận) — Firestore
  static Future<int> _countPendingStock() async {
    try {
      return await StockEntryService().getPendingCount();
    } catch (e) {
      debugPrint('ReminderService._countPendingStock error: $e');
      return 0;
    }
  }

  /// Đếm đơn nhập hàng PENDING trong SQLite
  static Future<int> _countPendingPurchaseOrders() async {
    try {
      final db = await _db.database;
      final shopId = UserService.getShopIdSync();
      String where = "status = 'PENDING' AND (deleted = 0 OR deleted IS NULL)";
      List<dynamic> args = [];
      if (shopId != null && shopId.isNotEmpty) {
        where += ' AND (shopId = ? OR shopId IS NULL)';
        args.add(shopId);
      }
      final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM purchase_orders WHERE $where', args);
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('ReminderService._countPendingPurchaseOrders error: $e');
      return 0;
    }
  }

  /// Đếm đơn trả hàng PENDING trong SQLite
  static Future<int> _countPendingSalesReturns() async {
    try {
      final db = await _db.database;
      final shopId = UserService.getShopIdSync();
      String where = "status = 'PENDING' AND (deleted = 0 OR deleted IS NULL)";
      List<dynamic> args = [];
      if (shopId != null && shopId.isNotEmpty) {
        where += ' AND (shopId = ? OR shopId IS NULL)';
        args.add(shopId);
      }
      final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM sales_returns WHERE $where', args);
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('ReminderService._countPendingSalesReturns error: $e');
      return 0;
    }
  }

  /// Đếm yêu cầu đóng tiền pending — Firestore real-time
  static Future<int> _countPendingPaymentRequests() async {
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null) return 0;
      final snap = await FirebaseFirestore.instance
          .collection('payment_requests')
          .where('shopId', isEqualTo: shopId)
          .where('deleted', isEqualTo: false)
          .where('status', isEqualTo: PaymentRequestStatus.pending.name)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('ReminderService._countPendingPaymentRequests error: $e');
      return 0;
    }
  }

  /// Đếm Payment Intent PENDING trong SQLite
  static Future<int> _countPendingPaymentIntents() async {
    try {
      final list = await _db.getPendingPaymentIntents();
      return list.length;
    } catch (e) {
      debugPrint('ReminderService._countPendingPaymentIntents error: $e');
      return 0;
    }
  }
}

/// Internal DTO cho debt summary
class _DebtSummary {
  final int customerOwes;
  final int customerOwesCount;
  final int customerOverdueCount;
  final int shopOwes;
  final int shopOwesCount;
  final int shopOverdueCount;

  const _DebtSummary({
    this.customerOwes = 0,
    this.customerOwesCount = 0,
    this.customerOverdueCount = 0,
    this.shopOwes = 0,
    this.shopOwesCount = 0,
    this.shopOverdueCount = 0,
  });
}

/// Internal DTO cho đơn trả góp chờ ngân hàng tất toán
class _InstallmentSummary {
  final int count;
  final int amount;
  const _InstallmentSummary({this.count = 0, this.amount = 0});
}
