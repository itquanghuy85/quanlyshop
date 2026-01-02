import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
<<<<<<< HEAD
import 'package:fl_chart/fl_chart.dart';
import '../services/event_bus.dart';
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
import 'customer_history_view.dart';
import 'order_list_view.dart';
import 'revenue_view.dart';
import 'inventory_view.dart';
<<<<<<< HEAD
import 'fast_inventory_input_view.dart';
import 'fast_inventory_check_view.dart';
import 'quick_input_codes_view.dart';
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
import 'sale_list_view.dart';
import 'expense_view.dart';
import 'debt_view.dart';
import 'warranty_view.dart';
import 'settings_view.dart';
import 'chat_view.dart';
import 'thermal_printer_design_view.dart';
<<<<<<< HEAD
=======
import 'purchase_order_list_view.dart';
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
import 'super_admin_view.dart' as admin_view;
import 'staff_list_view.dart';
import 'qr_scan_view.dart';
import 'attendance_view.dart';
import 'staff_performance_view.dart';
import 'audit_log_view.dart';
<<<<<<< HEAD
import 'notifications_view.dart';
import 'notification_settings_view.dart';
import 'supplier_view.dart';
import 'global_search_view.dart';
import 'work_schedule_settings_view.dart';
import 'debt_analysis_view.dart';
import 'create_sale_view.dart';
import 'customer_view.dart';
import 'stock_in_view.dart';
import 'parts_inventory_view.dart';
import 'create_repair_order_view.dart';
import 'repair_partner_list_view.dart';
import 'about_developer_view.dart';
import 'advanced_analytics_view.dart';
import '../data/db_helper.dart';
import '../widgets/notification_badge.dart';
import '../widgets/perpetual_calendar.dart';
import '../widgets/offline_indicator.dart';
import '../utils/responsive_layout.dart';
import '../services/sync_service.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/subscription_service.dart';
=======
import 'work_schedule_settings_view.dart';
import '../data/db_helper.dart';
import '../widgets/perpetual_calendar.dart';
import '../services/sync_service.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6

class HomeView extends StatefulWidget {
  final String role;
  final void Function(Locale)? setLocale;

  const HomeView({super.key, required this.role, this.setLocale});

  @override
  State<HomeView> createState() => _HomeViewState();
}

<<<<<<< HEAD
class _HomeViewState extends State<HomeView> with TickerProviderStateMixin {
  final db = DBHelper(); // Temporarily use regular DBHelper
  int totalPendingRepair = 0;
  int todaySaleCount = 0;
  int _currentIndex = 0; // Bottom navigation index
  
  // Tab configurations with permissions
  late List<Map<String, dynamic>> _tabConfigs;
  late List<BottomNavigationBarItem> _navItems;
  late List<Widget> _tabWidgets;

  // Missing variable declarations
  Timer? _autoSyncTimer;
  Map<String, bool> _permissions = {};
  bool _shopLocked = false;
  final TextEditingController _phoneSearchCtrl = TextEditingController();
  bool _isSyncing = false;
=======
class _HomeViewState extends State<HomeView> {
  final db = DBHelper();
  int totalPendingRepair = 0;
  int todaySaleCount = 0;
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  int todayRepairDone = 0;
  int revenueToday = 0;
  int todayNewRepairs = 0;
  int todayExpense = 0;
  int totalDebtRemain = 0;
  int expiringWarranties = 0;
<<<<<<< HEAD
  int unreadChatCount = 0;
=======

  bool _isSyncing = false;
  Timer? _autoSyncTimer;
  bool _shopLocked = false;
  final TextEditingController _phoneSearchCtrl = TextEditingController();
  Map<String, bool> _permissions = {};
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6

  final bool _isSuperAdmin = UserService.isCurrentUserSuperAdmin();
  bool get hasFullAccess => widget.role == 'admin' || widget.role == 'owner' || _isSuperAdmin;

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    _initializeTabConfigs();
    _initialSetup();
    SyncService.initRealTimeSync(() { if (mounted) _loadStats(); });
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 60), (_) => _syncNow(silent: true));
    
    // Listen to debt changes to update stats
    EventBus().stream.listen((event) {
      if (event == 'debts_changed' && mounted) _loadStats();
    });
    
    // Listen to notifications for snackbars
    NotificationService.listenToNotifications((title, body) {
      if (mounted) {
        NotificationService.showSnackBar('$title: $body');
      }
    });
  }

  void _initializeTabConfigs() {
    _tabConfigs = [
      {
        'permission': null, // Home always accessible
        'feature': null,
        'item': const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        'widget': _buildHomeTab(),
      },
      {
        'permission': 'allowViewSales',
        'feature': 'sales_tracking',
        'item': const BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Bán hàng'),
        'widget': _buildSalesTab(),
      },
      {
        'permission': 'allowViewRepairs',
        'feature': 'unlimited_repairs',
        'item': const BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Sửa chữa'),
        'widget': _buildRepairsTab(),
      },
      {
        'permission': 'allowViewInventory',
        'feature': 'advanced_inventory',
        'item': const BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Kho'),
        'widget': _buildInventoryTab(),
      },
      {
        'permission': 'allowManageStaff', // Staff tab requires manage staff permission
        'feature': 'unlimited_users',
        'item': const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Nhân sự'),
        'widget': _buildStaffTab(),
      },
      {
        'permission': 'allowViewRevenue', // Finance tab requires revenue permission
        'feature': 'financial_reports',
        'item': const BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Tài chính'),
        'widget': _buildFinanceTab(),
      },
      {
        'permission': 'allowViewRevenue', // Advanced analytics requires revenue permission
        'feature': 'advanced_analytics',
        'item': const BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Phân tích'),
        'widget': _buildAnalyticsTab(),
      },
      {
        'permission': 'allowViewSettings',
        'feature': null,
        'item': const BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Cài đặt'),
        'widget': _buildSettingsTab(),
      },
    ];
    // Initialize with default values to prevent LateInitializationError
    _navItems = [];
    _tabWidgets = [const Center(child: CircularProgressIndicator())];
    _updateAvailableTabs();
  }

  void _updateAvailableTabs() {
    final availableConfigs = _tabConfigs; // Display all features in bottom bar

    _navItems = availableConfigs.map((config) => config['item'] as BottomNavigationBarItem).toList();
    _tabWidgets = availableConfigs.map((config) => config['widget'] as Widget).toList();

    // Adjust current index if it's out of bounds
    if (_currentIndex >= _navItems.length) {
      _currentIndex = 0;
    }
=======
    _initialSetup();
    SyncService.initRealTimeSync(() { if (mounted) _loadStats(); });
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 60), (_) => _syncNow(silent: true));
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  }

  @override
  void dispose() { _autoSyncTimer?.cancel(); _phoneSearchCtrl.dispose(); super.dispose(); }

  Future<void> _initialSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = FirebaseAuth.instance.currentUser;
    final lastUserId = prefs.getString('lastUserId');
    if (currentUser != null && currentUser.uid != lastUserId) {
      await db.clearAllData();
      await prefs.setString('lastUserId', currentUser.uid);
      if (currentUser.email != null) await UserService.syncUserInfo(currentUser.uid, currentUser.email!);
    }
    await db.cleanDuplicateData();
    await _loadStats();
    await _updatePermissions();
  }

  Future<void> _updatePermissions() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() {
      _shopLocked = perms['shopAppLocked'] == true;
      _permissions = perms.map((key, value) => MapEntry(key, value == true));
<<<<<<< HEAD
      _updateAvailableTabs();
    });
    debugPrint('HomeView permissions updated: $_permissions');
=======
    });
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  }

  Future<void> _syncNow({bool silent = false}) async {
    if (_isSyncing) return;
    if (mounted) setState(() => _isSyncing = true);
    try {
      await SyncService.syncAllToCloud();
      await SyncService.downloadAllFromCloud();
      await _loadStats();
    } catch (e) { debugPrint("SYNC ERROR: $e"); }
    finally { if (mounted) setState(() => _isSyncing = false); }
  }

  bool _isSameDay(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Future<void> _loadStats() async {
    final repairs = await db.getAllRepairs();
    final sales = await db.getAllSales();
    final debts = await db.getAllDebts();
    final expenses = await db.getAllExpenses();
    int pendingR = repairs.where((r) => r.status == 1 || r.status == 2).length;
    int doneT = 0; int soldT = 0; int revT = 0; int newRT = 0; int expT = 0; int debtR = 0; int expW = 0;
    final now = DateTime.now();
    for (var r in repairs) {
      if (_isSameDay(r.createdAt)) newRT++;
<<<<<<< HEAD
      if (r.status >= 3 && r.deliveredAt != null && _isSameDay(r.deliveredAt!)) { doneT++; revT += ((r.price as int) - (r.cost as int)); }
=======
      if (r.status >= 3 && r.deliveredAt != null && _isSameDay(r.deliveredAt!)) { doneT++; revT += (r.price - r.cost); }
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
      if (r.deliveredAt != null && r.warranty.isNotEmpty && r.warranty != "KO BH") {
        int m = int.tryParse(r.warranty.split(' ').first) ?? 0;
        if (m > 0) { DateTime d = DateTime.fromMillisecondsSinceEpoch(r.deliveredAt!); DateTime e = DateTime(d.year, d.month + m, d.day); if (e.isAfter(now) && e.difference(now).inDays <= 7) expW++; }
      }
    }
    for (var s in sales) {
<<<<<<< HEAD
      if (_isSameDay(s.soldAt)) { soldT++; revT += ((s.totalPrice as int) - (s.totalCost as int)); }
=======
      if (_isSameDay(s.soldAt)) { soldT++; revT += (s.totalPrice - s.totalCost); }
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
      if (s.warranty.isNotEmpty && s.warranty != "KO BH") {
        int m = int.tryParse(s.warranty.split(' ').first) ?? 12;
        DateTime d = DateTime.fromMillisecondsSinceEpoch(s.soldAt); DateTime e = DateTime(d.year, d.month + m, d.day); if (e.isAfter(now) && e.difference(now).inDays <= 7) expW++;
      }
    }
    for (var e in expenses) { if (_isSameDay(e['date'] as int)) expT += (e['amount'] as int); }
<<<<<<< HEAD
    for (var d in debts) { 
      final int total = d['totalAmount'] ?? 0; 
      final int paid = d['paidAmount'] ?? 0; 
      final int remain = total - paid;
      if (remain > 0) debtR += remain;
      else if (remain < 0) debugPrint('Debt with negative remain: id=${d['id']}, total=$total, paid=$paid');
    }
    if (mounted) setState(() { totalPendingRepair = pendingR; todayRepairDone = doneT; todaySaleCount = soldT; revenueToday = revT; todayNewRepairs = newRT; todayExpense = expT; totalDebtRemain = debtR; expiringWarranties = expW; });
    
    // Load unread chat count
    final unread = await UserService.getUnreadChatCount(FirebaseAuth.instance.currentUser!.uid);
    if (mounted) setState(() => unreadChatCount = unread);
=======
    for (var d in debts) { final int total = d['totalAmount'] ?? 0; final int paid = d['paidAmount'] ?? 0; if (total > paid) debtR += (total - paid); }
    if (mounted) setState(() { totalPendingRepair = pendingR; todayRepairDone = doneT; todaySaleCount = soldT; revenueToday = revT; todayNewRepairs = newRT; todayExpense = expT; totalDebtRemain = debtR; expiringWarranties = expW; });
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text("Thoát ứng dụng?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")), TextButton(onPressed: () => SystemNavigator.pop(), child: const Text("THOÁT"))]));
        return ok ?? false;
      },
      child: Scaffold(
<<<<<<< HEAD
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: ResponsiveAppBar(
          title: _getTabTitle(_currentIndex),
          actions: [
            ConnectivityBadge(),
            const SizedBox(width: 8),
            NotificationBadge(
              unreadCount: FirestoreService.getUnreadCount(),
              child: IconButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsView())),
                icon: const Icon(Icons.notifications, color: Color(0xFFFF9800)),
                tooltip: 'Thông báo',
              ),
            ),
            IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QrScanView(role: widget.role))), icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2962FF))),
            IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GlobalSearchView(role: widget.role))), icon: const Icon(Icons.search, color: Color(0xFF9C27B0), size: 28), tooltip: 'Tìm kiếm toàn app'),
            IconButton(onPressed: () => _syncNow(), icon: _isSyncing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync, color: Colors.green, size: 28)),
=======
        backgroundColor: const Color(0xFFF8FAFF),
        appBar: AppBar(
          backgroundColor: Colors.white, elevation: 0,
          title: Row(children: [
            const Icon(Icons.store_rounded, color: Color(0xFF2962FF), size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(hasFullAccess ? "QUẢN TRỊ SHOP" : "NHÂN VIÊN", style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold))),
          ]),
          actions: [
            IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QrScanView(role: widget.role))), icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2962FF))),
            IconButton(onPressed: () => _syncNow(), icon: _isSyncing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync, color: Colors.green, size: 28)),
            IconButton(onPressed: _openSettingsCenter, icon: const Icon(Icons.settings_rounded, color: Colors.black54), tooltip: 'Cài đặt'),
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
            IconButton(onPressed: () async {
              await SyncService.cancelAllSubscriptions();
              try {
                await FirebaseAuth.instance.signOut();
              } catch (e) {
                debugPrint('Logout error: $e');
              }
            }, icon: const Icon(Icons.logout_rounded, color: Colors.redAccent)),
          ],
        ),
<<<<<<< HEAD
        body: IndexedStack(
          index: _currentIndex,
          children: _tabWidgets,
        ),
        bottomNavigationBar: ResponsiveBottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: _navItems,
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: () => _syncNow(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            if (_shopLocked) Container(
              padding: const EdgeInsets.all(12), 
              margin: const EdgeInsets.only(bottom: 12), 
              decoration: BoxDecoration(
                color: Colors.red.shade50, 
                border: Border.all(color: Colors.redAccent), 
                borderRadius: BorderRadius.circular(10)
              ), 
              child: const Text("CỬA HÀNG BỊ KHÓA", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
            ),
            _buildTodaySummary(),
            const SizedBox(height: 20),
            _buildFinancialChart(),
            const SizedBox(height: 20),
            _buildQuickActions(),
=======
        body: RefreshIndicator(
          onRefresh: () => _syncNow(),
          child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_shopLocked) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.red.shade50, border: Border.all(color: Colors.redAccent), borderRadius: BorderRadius.circular(10)), child: const Text("CỬA HÀNG BỊ KHÓA", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
            _buildTodaySummary(),
            const SizedBox(height: 20),
            _buildModuleGrid(),
            const SizedBox(height: 20),
            TextField(controller: _phoneSearchCtrl, decoration: InputDecoration(hintText: "Tìm nhanh khách theo SĐT", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), filled: true, fillColor: Colors.white), onSubmitted: (v) { if(v.isNotEmpty) { HapticFeedback.lightImpact(); Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerHistoryView(phone: v, name: v))); } }),
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
            const SizedBox(height: 20),
            const PerpetualCalendar(),
            const SizedBox(height: 25),
            _buildAlerts(),
            const SizedBox(height: 50),
<<<<<<< HEAD
          ]
        )
      ),
    );
  }

  Widget _buildQuickActions() {
    final perms = _permissions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //const Text("THAO TÁC NHANH", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _quickActionButton("Tạo đơn bán", Icons.add_shopping_cart, Colors.pink, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateSaleView())))),
            const SizedBox(width: 8),
            Expanded(child: _quickActionButton("Tạo đơn sửa", Icons.build_circle, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateRepairOrderView(role: widget.role))))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _quickActionButton("Nhập kho", Icons.inventory, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => FastInventoryInputView())))),
            const SizedBox(width: 8),
            Expanded(child: _quickActionButton("Kiểm kho", Icons.qr_code_scanner, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => FastInventoryCheckView())))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _quickActionButton("Báo cáo DT", Icons.bar_chart, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RevenueView())))),
            const SizedBox(width: 8),
            Expanded(child: _quickActionButton("Chấm công", Icons.access_time, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceView())))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _quickActionButton("Chat", Icons.chat, Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatView())), badgeCount: unreadChatCount)),
            const SizedBox(width: 8),
            Expanded(child: _quickActionButton("Bảo hành", Icons.shield, Colors.amber, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarrantyView())))),
          ],
        ),
      ],
    );
  }

  Widget _quickActionButton(String title, IconData icon, Color color, VoidCallback onTap, {int? badgeCount}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          border: Border.all(color: color.withAlpha(100)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Icon(icon, color: color, size: 24),
                if (badgeCount != null && badgeCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ],
=======
          ])),
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
        ),
      ),
    );
  }

<<<<<<< HEAD
  Widget _summaryRow(IconData icon, Color color, String title, String value, VoidCallback onTap, {bool isBold = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 13))),
            Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }
  
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  Widget _buildTodaySummary() {
    String fmt(int v) => NumberFormat('#,###').format(v);
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(18), 
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10)]), 
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("TRẠNG THÁI CỬA HÀNG", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 15),
        _summaryRow(Icons.build_circle, Colors.blue, "MÁY ĐANG CHỜ SỬA", "$totalPendingRepair", () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListView(role: widget.role, statusFilter: const [1, 2]))), isBold: true),
        _summaryRow(Icons.receipt_long_rounded, Colors.red, "TỔNG CÔNG NỢ TỒN ĐỌNG", "${fmt(totalDebtRemain)} đ", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtView())), isBold: true),
        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
        _summaryRow(Icons.add_task, Colors.orange, "Máy nhận mới hôm nay", "$todayNewRepairs", () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListView(role: widget.role, todayOnly: true)))),
        _summaryRow(Icons.shopping_bag_outlined, Colors.pink, "Đơn bán mới hôm nay", "$todaySaleCount", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleListView(todayOnly: true)))),
        _summaryRow(Icons.check_circle_outlined, Colors.green, "Đã giao khách hôm nay", "$todayRepairDone", () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListView(role: widget.role, statusFilter: const [4], todayOnly: true)))),
        _summaryRow(Icons.money_off_rounded, Colors.blueGrey, "Chi phí phát sinh", "${fmt(todayExpense)} đ", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseView()))),
      ])
    );
  }

<<<<<<< HEAD
  Widget _buildFinancialChart() {
    String fmt(int v) => NumberFormat('#,###').format(v);
    int revenue = revenueToday;
    int expense = todayExpense;
    int debt = totalDebtRemain;
    int total = revenue + expense + debt;
    if (total == 0) total = 1; // avoid division by zero

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("BIỂU ĐỒ TÀI CHÍNH", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: revenue.toDouble(),
                    color: Colors.green,
                    title: '${(revenue / total * 100).toStringAsFixed(1)}%',
                    radius: 40,
                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: expense.toDouble(),
                    color: Colors.red,
                    title: '${(expense / total * 100).toStringAsFixed(1)}%',
                    radius: 40,
                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: debt.toDouble(),
                    color: Colors.orange,
                    title: '${(debt / total * 100).toStringAsFixed(1)}%',
                    radius: 40,
                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
                sectionsSpace: 2,
                centerSpaceRadius: 20,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _chartLegend(Colors.green, "Doanh thu", "${fmt(revenue)} đ"),
              _chartLegend(Colors.red, "Chi phí", "${fmt(expense)} đ"),
              _chartLegend(Colors.orange, "Công nợ", "${fmt(debt)} đ"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartLegend(Color color, String label, String value) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
      ],
    );
  }

  Widget _buildSalesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("BÁN HÀNG", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 20),
        _tabMenuItem("Danh sách đơn bán", Icons.list_alt, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleListView())), subtitle: "Xem, tìm kiếm và theo dõi tất cả đơn bán hàng."),
        _tabMenuItem("Tạo đơn bán mới", Icons.add_circle, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateSaleView())), subtitle: "Tạo đơn bán hàng mới với sản phẩm và thông tin khách."),
        _tabMenuItem("Quản lý khách hàng", Icons.people, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerListView(role: widget.role))), subtitle: "Thêm, sửa và xem thông tin khách hàng."),
        _tabMenuItem("Bảo hành", Icons.verified_user, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarrantyView())), subtitle: "Xem và xử lý các yêu cầu bảo hành sản phẩm."),
      ],
    );
  }

  Widget _buildRepairsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("SỬA CHỮA", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 20),
        _tabMenuItem("Danh sách đơn sửa", Icons.list_alt, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListView(role: widget.role))), subtitle: "Xem, tìm kiếm và theo dõi tất cả đơn sửa chữa."),
        _tabMenuItem("Tạo đơn sửa mới", Icons.add_circle, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateRepairOrderView(role: widget.role))), subtitle: "Tạo đơn sửa chữa mới với thông tin máy và khách."),
        _tabMenuItem("Đối tác sửa chữa", Icons.business, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RepairPartnerListView())), subtitle: "Quản lý danh sách đối tác sửa chữa bên ngoài."),
        _tabMenuItem("Kho phụ tùng", Icons.build, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PartsInventoryView())), subtitle: "Quản lý tồn kho phụ tùng cho sửa chữa."),
      ],
    );
  }

  Widget _buildInventoryTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("QUẢN LÝ KHO", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 20),
        _tabMenuItem("Danh sách sản phẩm", Icons.inventory, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryView(role: widget.role))), subtitle: "Xem và quản lý danh sách sản phẩm trong kho."),
        _tabMenuItem("Nhà cung cấp", Icons.business, Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierView())), subtitle: "Quản lý danh sách nhà cung cấp."),
        _tabMenuItem("Nhập kho siêu tốc", Icons.flash_on, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => FastInventoryInputView())), subtitle: "Nhập nhiều sản phẩm vào kho nhanh bằng mã QR."),
        _tabMenuItem("Danh sách mã nhập nhanh", Icons.qr_code, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickInputCodesView())), subtitle: "Xem và quản lý danh sách mã nhập nhanh đã tạo."),
        _tabMenuItem("Kiểm kho QR", Icons.qr_code_scanner, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => FastInventoryCheckView())), subtitle: "Kiểm tra tồn kho bằng cách quét mã QR."),
      ],
    );
  }

  Widget _buildStaffTab() {
    if (!hasFullAccess) {
      return const Center(child: Text("Không có quyền truy cập"));
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("QUẢN LÝ NHÂN SỰ", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 20),
        _tabMenuItem("Danh sách nhân viên", Icons.people, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffListView())), subtitle: "Xem và quản lý thông tin nhân viên."),
        _tabMenuItem("Chấm công", Icons.fingerprint, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceView())), subtitle: "Ghi nhận giờ làm việc của nhân viên."),
        _tabMenuItem("Hiệu suất", Icons.bar_chart, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffPerformanceView())), subtitle: "Xem báo cáo hiệu suất làm việc của nhân viên."),
        _tabMenuItem("Lịch làm việc", Icons.schedule, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkScheduleSettingsView())), subtitle: "Thiết lập và xem lịch làm việc của nhân viên."),
      ],
    );
  }

  Widget _buildFinanceTab() {
    String fmt(int v) => NumberFormat('#,###').format(v);
    int revenue = revenueToday;
    int expense = todayExpense;
    int debt = totalDebtRemain;
    int total = revenue + expense + debt;
    if (total == 0) total = 1;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("QUẢN LÝ TÀI CHÍNH", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 20),
        // TỔNG QUAN TÀI CHÍNH
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("TỔNG QUAN TÀI CHÍNH HÔM NAY", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 15),
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(
                        value: revenue.toDouble(),
                        color: Colors.green,
                        title: 'Doanh thu\n${fmt(revenue)} đ',
                        radius: 60,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      PieChartSectionData(
                        value: expense.toDouble(),
                        color: Colors.red,
                        title: 'Chi phí\n${fmt(expense)} đ',
                        radius: 60,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      PieChartSectionData(
                        value: debt.toDouble(),
                        color: Colors.orange,
                        title: 'Công nợ\n${fmt(debt)} đ',
                        radius: 60,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _chartLegend(Colors.green, "Doanh thu", "${fmt(revenue)} đ"),
                  _chartLegend(Colors.red, "Chi phí", "${fmt(expense)} đ"),
                  _chartLegend(Colors.orange, "Công nợ", "${fmt(debt)} đ"),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        _tabMenuItem("Báo cáo doanh thu", Icons.trending_up, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RevenueView())), subtitle: "Xem báo cáo doanh thu và lợi nhuận theo thời gian."),
        _tabMenuItem("Quản lý chi phí", Icons.money_off, Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseView())), subtitle: "Thêm và theo dõi các khoản chi phí của cửa hàng."),
        _tabMenuItem("Công nợ", Icons.receipt_long, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtView())), subtitle: "Quản lý các khoản nợ và thu nợ từ khách hàng."),
        if (_isSuperAdmin) _tabMenuItem("Phân tích nợ", Icons.analytics, Colors.deepOrange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtAnalysisView())), subtitle: "Phân tích chi tiết các khoản nợ (chỉ dành cho admin)."),
      ],
    );
  }

  Widget _buildAnalyticsTab() {
    return const AdvancedAnalyticsView();
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("CÀI ĐẶT HỆ THỐNG", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 20),
        _tabMenuItem("Thông báo", Icons.notifications, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsView())), subtitle: "Cấu hình cài đặt thông báo và cảnh báo."),
        _tabMenuItem("Máy in", Icons.print, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThermalPrinterDesignView())), subtitle: "Thiết kế mẫu in cho máy in nhiệt."),
        _tabMenuItem("Tìm kiếm toàn cục", Icons.search, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => GlobalSearchView(role: widget.role))), subtitle: "Tìm kiếm thông tin trên toàn bộ ứng dụng."),
        if (hasFullAccess) _tabMenuItem("Cài đặt hệ thống", Icons.settings, Colors.grey, () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsView(setLocale: widget.setLocale))), subtitle: "Thay đổi cài đặt chung của ứng dụng."),
        if (_isSuperAdmin) _tabMenuItem("Trung tâm Admin", Icons.admin_panel_settings, Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const admin_view.SuperAdminView())), subtitle: "Quản lý toàn bộ hệ thống cho admin cấp cao."),
        if (hasFullAccess) _tabMenuItem("Nhật ký hệ thống", Icons.history, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditLogView())), subtitle: "Xem lịch sử hoạt động và thay đổi trong hệ thống."),
        _tabMenuItem("Về nhà phát triển", Icons.info, Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutDeveloperView())), subtitle: "Thông tin về nhà phát triển và ứng dụng."),
      ],
    );
  }

  Widget _tabMenuItem(String title, IconData icon, Color color, VoidCallback onTap, {String? subtitle}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _getTabTitle(int index) {
    if (index < _tabWidgets.length) {
      // Get the corresponding config from the original configs
      final availableConfigs = _tabConfigs.where((config) {
        final permission = config['permission'] as String?;
        return permission == null || (_permissions[permission] == true);
      }).toList();
      
      if (index < availableConfigs.length) {
        final item = availableConfigs[index]['item'] as BottomNavigationBarItem;
        return item.label?.toUpperCase() ?? 'TAB';
      }
    }
    return "SHOP MANAGER";
=======
  Widget _summaryRow(IconData i, Color c, String l, String v, VoidCallback t, {bool isBold = false}) => InkWell(onTap: t, child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Icon(i, size: 18, color: c), const SizedBox(width: 12), Expanded(child: Text(l, style: TextStyle(fontSize: 13, color: isBold ? Colors.black : Colors.grey, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))), Text(v, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isBold ? c : Colors.black)), const Icon(Icons.chevron_right, size: 14, color: Colors.grey)])));

  Widget _buildModuleGrid() {
    final perms = _permissions;
    final modules = <Widget>[];
    void addModule(String permKey, String title, IconData icon, List<Color> colors, VoidCallback onTap, {Widget? badge}) {
      if (hasFullAccess || (perms[permKey] ?? true)) { modules.add(_menuTile(title, icon, colors, onTap, badge: badge)); }
    }
    
    // NHÓM 1: KINH DOANH CỐT LÕI
    addModule('allowViewSales', "Bán hàng", Icons.shopping_cart_checkout_rounded, [const Color(0xFFFF4081), const Color(0xFFFF80AB)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleListView())));
    addModule('allowViewRepairs', "Sửa chữa", Icons.build_circle_rounded, [const Color(0xFF2979FF), const Color(0xFF448AFF)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListView(role: widget.role))));
    addModule('allowViewPurchaseOrders', "Đơn nhập", Icons.receipt_long_rounded, [const Color(0xFF4CAF50), const Color(0xFF81C784)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseOrderListView())));

    // NHÓM 2: QUẢN LÝ KHO & BẢO HÀNH
    addModule('allowViewInventory', "Kho hàng", Icons.inventory_rounded, [const Color(0xFFFF6F00), const Color(0xFFFFA726)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryView(role: widget.role))));
    // 'Kiểm kho QR' removed from Home screen as requested
    addModule('allowViewWarranty', "Bảo hành", Icons.verified_user_rounded, [const Color(0xFF00C853), const Color(0xFFB2FF59)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarrantyView())));

    // NHÓM 3: NHÂN SỰ & CHAT
    addModule('allowViewChat', "Chat", Icons.chat_bubble_rounded, [const Color(0xFF7C4DFF), const Color(0xFFB388FF)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatView())), badge: _buildChatBadge());
    addModule('allowViewAttendance', "Chấm công", Icons.fingerprint_rounded, [const Color(0xFF009688), const Color(0xFF4DB6AC)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceView())));
    if (hasFullAccess) addModule('allowManageStaff', "Lịch làm", Icons.schedule_rounded, [const Color(0xFF0097A7), const Color(0xFF26C6DA)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkScheduleSettingsView())));

    // NHÓM 4: QUẢN TRỊ & TÀI CHÍNH
    if (hasFullAccess) addModule('allowManageStaff', "Nhật ký", Icons.history_edu_rounded, [const Color(0xFF455A64), const Color(0xFF78909C)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditLogView())));
    if (hasFullAccess) addModule('allowViewRevenue', "DS & Lương", Icons.assessment_rounded, [const Color(0xFF6200EA), const Color(0xFF7C4DFF)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffPerformanceView())));
    addModule('allowViewRevenue', "Báo cáo DT", Icons.leaderboard_rounded, [const Color(0xFF304FFE), const Color(0xFF536DFE)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RevenueView())));

    // NHÓM 5: CÔNG CỤ & HỆ THỐNG
    addModule('allowViewDebts', "Công nợ", Icons.receipt_long_rounded, [const Color(0xFF9C27B0), const Color(0xFFE1BEE7)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtView())));
    addModule('allowViewExpenses', "Chi phí", Icons.money_off_rounded, [const Color(0xFFFF5722), const Color(0xFFFFAB91)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseView())));
    addModule('allowViewPrinter', "Máy in", Icons.print_rounded, [const Color(0xFF607D8B), const Color(0xFF90A4AE)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThermalPrinterDesignView())));

    return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.9, children: modules);
  }

  Widget _buildChatBadge() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.chatStream(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        final userId = FirebaseAuth.instance.currentUser?.uid;
        final count = snap.data!.docs.where((doc) { final data = doc.data() as Map<String, dynamic>; final List readBy = data['readBy'] ?? []; return !readBy.contains(userId); }).length;
        if (count == 0) return const SizedBox();
        return Positioned(right: 5, top: 5, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), constraints: const BoxConstraints(minWidth: 16, minHeight: 16), child: Text("$count", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center)));
      }
    );
  }

  Widget _menuTile(String title, IconData icon, List<Color> colors, VoidCallback onTap, {Widget? badge}) {
    return InkWell(onTap: () { HapticFeedback.mediumImpact(); onTap(); }, child: Stack(children: [Container(width: double.infinity, height: double.infinity, decoration: BoxDecoration(gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: colors[0].withAlpha(77), blurRadius: 6, offset: const Offset(0, 3))]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 28), const SizedBox(height: 6), Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))])), if (badge != null) badge]));
  }

  void _openSettingsCenter() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.settings_rounded, color: Colors.blueGrey), title: const Text("CÀI ĐẶT HỆ THỐNG"), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsView(setLocale: widget.setLocale))); }),
      if (hasFullAccess) ListTile(leading: const Icon(Icons.group_rounded, color: Colors.indigo), title: const Text("QUẢN LÝ NHÂN VIÊN"), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffListView())); }),
      if (_isSuperAdmin) ListTile(leading: const Icon(Icons.admin_panel_settings_rounded, color: Colors.deepPurple), title: const Text("TRUNG TÂM SUPER ADMIN"), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const admin_view.SuperAdminView())); }),
    ]))));
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  }

  Widget _buildAlerts() {
    if (expiringWarranties == 0) return const SizedBox();
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarrantyView())),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.red.withAlpha(51), blurRadius: 10)]),
        child: Row(children: [
          const Icon(Icons.notification_important, color: Colors.white, size: 28),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("NHẮC LỊCH BẢO HÀNH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            Text("Có $expiringWarranties máy sắp hết hạn bảo hành. Xem ngay!", style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ])),
          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
        ]),
      ),
    );
  }
}
