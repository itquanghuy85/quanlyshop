import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'customer_history_view.dart';
import 'order_list_view.dart';
import 'revenue_view.dart';
import 'inventory_view.dart';
import 'fast_inventory_input_view.dart';
import 'fast_inventory_check_view.dart';
import 'sale_list_view.dart';
import 'expense_view.dart';
import 'debt_view.dart';
import 'warranty_view.dart';
import 'settings_view.dart';
import 'chat_view.dart';
import 'thermal_printer_design_view.dart';
import 'super_admin_view.dart' as admin_view;
import 'staff_list_view.dart';
import 'qr_scan_view.dart';
import 'attendance_view.dart';
import 'staff_performance_view.dart';
import 'audit_log_view.dart';
import 'notification_settings_view.dart';
import 'global_search_view.dart';
import 'work_schedule_settings_view.dart';
import 'debt_analysis_view.dart';
import 'create_sale_view.dart';
import 'customer_view.dart';
import 'stock_in_view.dart';
import 'parts_inventory_view.dart';
import 'create_repair_order_view.dart';
import '../data/db_helper.dart';
import '../widgets/perpetual_calendar.dart';
import '../services/sync_service.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';

class HomeView extends StatefulWidget {
  final String role;
  final void Function(Locale)? setLocale;

  const HomeView({super.key, required this.role, this.setLocale});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with TickerProviderStateMixin {
  final db = DBHelper();
  int totalPendingRepair = 0;
  int todaySaleCount = 0;
  int _currentIndex = 0; // Bottom navigation index
  
  // Controllers for each tab
  late List<BottomNavigationBarItem> _navItems;
  
  int todayRepairDone = 0;
  int revenueToday = 0;
  int todayNewRepairs = 0;
  int todayExpense = 0;
  int totalDebtRemain = 0;
  int expiringWarranties = 0;

  bool _isSyncing = false;
  Timer? _autoSyncTimer;
  bool _shopLocked = false;
  final TextEditingController _phoneSearchCtrl = TextEditingController();
  Map<String, bool> _permissions = {};

  final bool _isSuperAdmin = UserService.isCurrentUserSuperAdmin();
  bool get hasFullAccess => widget.role == 'admin' || widget.role == 'owner' || _isSuperAdmin;

  @override
  void initState() {
    super.initState();
    _initializeTabs();
    _initialSetup();
    SyncService.initRealTimeSync(() { if (mounted) _loadStats(); });
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 60), (_) => _syncNow(silent: true));
  }

  void _initializeTabs() {
    _navItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      const BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Bán hàng'),
      const BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Sửa chữa'),
      const BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Kho'),
      const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Nhân sự'),
      const BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Tài chính'),
      const BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Cài đặt'),
    ];
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
    });
    debugPrint('HomeView permissions updated: $_permissions');
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
      if (r.status >= 3 && r.deliveredAt != null && _isSameDay(r.deliveredAt!)) { doneT++; revT += ((r.price as int) - (r.cost as int)); }
      if (r.deliveredAt != null && r.warranty.isNotEmpty && r.warranty != "KO BH") {
        int m = int.tryParse(r.warranty.split(' ').first) ?? 0;
        if (m > 0) { DateTime d = DateTime.fromMillisecondsSinceEpoch(r.deliveredAt!); DateTime e = DateTime(d.year, d.month + m, d.day); if (e.isAfter(now) && e.difference(now).inDays <= 7) expW++; }
      }
    }
    for (var s in sales) {
      if (_isSameDay(s.soldAt)) { soldT++; revT += ((s.totalPrice as int) - (s.totalCost as int)); }
      if (s.warranty.isNotEmpty && s.warranty != "KO BH") {
        int m = int.tryParse(s.warranty.split(' ').first) ?? 12;
        DateTime d = DateTime.fromMillisecondsSinceEpoch(s.soldAt); DateTime e = DateTime(d.year, d.month + m, d.day); if (e.isAfter(now) && e.difference(now).inDays <= 7) expW++;
      }
    }
    for (var e in expenses) { if (_isSameDay(e['date'] as int)) expT += (e['amount'] as int); }
    for (var d in debts) { 
      final int total = d['totalAmount'] ?? 0; 
      final int paid = d['paidAmount'] ?? 0; 
      final int remain = total - paid;
      if (remain > 0) debtR += remain;
      else if (remain < 0) debugPrint('Debt with negative remain: id=${d['id']}, total=$total, paid=$paid');
    }
    if (mounted) setState(() { totalPendingRepair = pendingR; todayRepairDone = doneT; todaySaleCount = soldT; revenueToday = revT; todayNewRepairs = newRT; todayExpense = expT; totalDebtRemain = debtR; expiringWarranties = expW; });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text("Thoát ứng dụng?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")), TextButton(onPressed: () => SystemNavigator.pop(), child: const Text("THOÁT"))]));
        return ok ?? false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        appBar: AppBar(
          backgroundColor: Colors.white, elevation: 0,
          title: Row(children: [
            const Icon(Icons.store_rounded, color: Color(0xFF2962FF), size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(_getTabTitle(_currentIndex), style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold))),
          ]),
          actions: [
            IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QrScanView(role: widget.role))), icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2962FF))),
            IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GlobalSearchView(role: widget.role))), icon: const Icon(Icons.search, color: Color(0xFF9C27B0), size: 28), tooltip: 'Tìm kiếm toàn app'),
            IconButton(onPressed: () => _syncNow(), icon: _isSyncing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync, color: Colors.green, size: 28)),
            IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsView(setLocale: widget.setLocale))), icon: const Icon(Icons.settings_rounded, color: Colors.black54), tooltip: 'Cài đặt'),
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
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeTab(),
            _buildSalesTab(),
            _buildRepairsTab(),
            _buildInventoryTab(),
            _buildStaffTab(),
            _buildFinanceTab(),
            _buildSettingsTab(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: _navItems,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF2962FF),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
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
            _buildQuickActions(),
            const SizedBox(height: 20),
            const PerpetualCalendar(),
            const SizedBox(height: 25),
            _buildAlerts(),
            const SizedBox(height: 50),
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
        const Text("THAO TÁC NHANH", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
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
      ],
    );
  }

  Widget _quickActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
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
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

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

  Widget _buildSalesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("BÁN HÀNG", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 20),
        _tabMenuItem("Danh sách đơn bán", Icons.list_alt, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleListView()))),
        _tabMenuItem("Tạo đơn bán mới", Icons.add_circle, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateSaleView()))),
        _tabMenuItem("Quản lý khách hàng", Icons.people, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerListView(role: widget.role)))),
        _tabMenuItem("Bảo hành", Icons.verified_user, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarrantyView()))),
      ],
    );
  }

  Widget _buildRepairsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("SỬA CHỮA", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 20),
        _tabMenuItem("Danh sách đơn sửa", Icons.list_alt, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListView(role: widget.role)))),
        _tabMenuItem("Tạo đơn sửa mới", Icons.add_circle, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateRepairOrderView(role: widget.role)))),
        _tabMenuItem("Kho phụ tùng", Icons.build, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PartsInventoryView()))),
      ],
    );
  }

  Widget _buildInventoryTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("QUẢN LÝ KHO", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 20),
        _tabMenuItem("Danh sách sản phẩm", Icons.inventory, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryView(role: widget.role)))),
        _tabMenuItem("Nhập kho thủ công", Icons.add_shopping_cart, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => StockInView()))),
        _tabMenuItem("Nhập kho siêu tốc", Icons.flash_on, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => FastInventoryInputView()))),
        _tabMenuItem("Kiểm kho QR", Icons.qr_code_scanner, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => FastInventoryCheckView()))),
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
        _tabMenuItem("Danh sách nhân viên", Icons.people, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffListView()))),
        _tabMenuItem("Chấm công", Icons.fingerprint, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceView()))),
        _tabMenuItem("Hiệu suất", Icons.bar_chart, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffPerformanceView()))),
        _tabMenuItem("Lịch làm việc", Icons.schedule, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkScheduleSettingsView()))),
      ],
    );
  }

  Widget _buildFinanceTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("QUẢN LÝ TÀI CHÍNH", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 20),
        _tabMenuItem("Báo cáo doanh thu", Icons.trending_up, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RevenueView()))),
        _tabMenuItem("Quản lý chi phí", Icons.money_off, Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseView()))),
        _tabMenuItem("Công nợ", Icons.receipt_long, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtView()))),
        if (_isSuperAdmin) _tabMenuItem("Phân tích nợ", Icons.analytics, Colors.deepOrange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtAnalysisView()))),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("CÀI ĐẶT HỆ THỐNG", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 20),
        _tabMenuItem("Thông báo", Icons.notifications, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsView()))),
        _tabMenuItem("Máy in", Icons.print, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThermalPrinterDesignView()))),
        _tabMenuItem("Tìm kiếm toàn cục", Icons.search, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => GlobalSearchView(role: widget.role)))),
        _tabMenuItem("Chat nội bộ", Icons.chat, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatView()))),
        if (hasFullAccess) _tabMenuItem("Cài đặt hệ thống", Icons.settings, Colors.grey, () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsView(setLocale: widget.setLocale)))),
        if (_isSuperAdmin) _tabMenuItem("Trung tâm Admin", Icons.admin_panel_settings, Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const admin_view.SuperAdminView()))),
        if (hasFullAccess) _tabMenuItem("Nhật ký hệ thống", Icons.history, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditLogView()))),
      ],
    );
  }

  Widget _tabMenuItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 0: return hasFullAccess ? "QUẢN TRỊ SHOP" : "NHÂN VIÊN";
      case 1: return "BÁN HÀNG";
      case 2: return "SỬA CHỮA";
      case 3: return "QUẢN LÝ KHO";
      case 4: return "NHÂN SỰ";
      case 5: return "TÀI CHÍNH";
      case 6: return "CÀI ĐẶT";
      default: return "SHOP MANAGER";
    }
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
