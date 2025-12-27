import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import 'customer_history_view.dart';
import 'order_list_view.dart';
import 'revenue_view.dart';
import 'revenue_report_view.dart';
import 'customer_view.dart';
import 'inventory_view.dart';
import 'sale_list_view.dart';
import 'expense_view.dart';
import 'debt_view.dart';
import 'warranty_view.dart';
import 'settings_view.dart';
import 'chat_view.dart';
import 'thermal_printer_design_view.dart';
import 'inventory_check_view.dart';
import 'super_admin_view.dart' as admin_view;
import 'staff_list_view.dart';
import 'qr_scan_view.dart';
import 'attendance_view.dart';
import 'staff_performance_view.dart';
import 'audit_log_view.dart';
import 'work_schedule_settings_view.dart'; // Import màn hình cài lịch
import '../data/db_helper.dart';
import '../widgets/perpetual_calendar.dart';
import '../services/sync_service.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';

class HomeView extends StatefulWidget {
  final String role;
  final void Function(Locale)? setLocale;

  HomeView({Key? key, required this.role, this.setLocale}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final db = DBHelper();
  int totalPendingRepair = 0;
  int todaySaleCount = 0;
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
    _initialSetup();
    SyncService.initRealTimeSync(() {
      if (mounted) _loadStats();
    });
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 60), (_) => _syncNow(silent: true));
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _phoneSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initialSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = FirebaseAuth.instance.currentUser;
    final lastUserId = prefs.getString('lastUserId');
    if (currentUser != null && currentUser.uid != lastUserId) {
      await db.clearAllData();
      await prefs.setString('lastUserId', currentUser.uid);
      if (currentUser.email != null) {
        await UserService.syncUserInfo(currentUser.uid, currentUser.email!);
      }
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
  }

  Future<void> _syncNow({bool silent = false}) async {
    if (_isSyncing) return;
    if (mounted) setState(() => _isSyncing = true);
    try {
      await SyncService.syncAllToCloud();
      await SyncService.downloadAllFromCloud();
      await _loadStats();
    } catch (e) {
      debugPrint("SYNC ERROR: $e");
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
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
      if (r.status >= 3 && r.deliveredAt != null && _isSameDay(r.deliveredAt!)) {
        doneT++; 
        revT += (r.price - r.cost);
      }
      if (r.deliveredAt != null && r.warranty.isNotEmpty && r.warranty != "KO BH") {
        int m = int.tryParse(r.warranty.split(' ').first) ?? 0;
        if (m > 0) {
          DateTime d = DateTime.fromMillisecondsSinceEpoch(r.deliveredAt!);
          DateTime e = DateTime(d.year, d.month + m, d.day);
          if (e.isAfter(now) && e.difference(now).inDays <= 7) expW++;
        }
      }
    }
    for (var s in sales) {
      if (_isSameDay(s.soldAt)) {
        soldT++; 
        revT += (s.totalPrice - s.totalCost);
      }
      if (s.warranty.isNotEmpty && s.warranty != "KO BH") {
        int m = int.tryParse(s.warranty.split(' ').first) ?? 12;
        DateTime d = DateTime.fromMillisecondsSinceEpoch(s.soldAt);
        DateTime e = DateTime(d.year, d.month + m, d.day);
        if (e.isAfter(now) && e.difference(now).inDays <= 7) expW++;
      }
    }
    for (var e in expenses) {
      if (_isSameDay(e['date'] as int)) expT += (e['amount'] as int);
    }
    for (var d in debts) {
      final int total = d['totalAmount'] ?? 0;
      final int paid = d['paidAmount'] ?? 0;
      if (paid < total) debtR += (total - paid);
    }

    if (mounted) {
      setState(() { 
        totalPendingRepair = pendingR; todayRepairDone = doneT; todaySaleCount = soldT; 
        revenueToday = revT; todayNewRepairs = newRT; todayExpense = expT; 
        totalDebtRemain = debtR; expiringWarranties = expW;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            Expanded(child: Text(hasFullAccess ? "QUẢN TRỊ SHOP" : "NHÂN VIÊN", style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold))),
          ]),
          actions: [
            IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QrScanView(role: widget.role))), icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2962FF))),
            IconButton(onPressed: () => _syncNow(), icon: _isSyncing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync, color: Colors.green, size: 28)),
            IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout_rounded, color: Colors.redAccent)),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => _syncNow(),
          child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_shopLocked) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.red.shade50, border: Border.all(color: Colors.redAccent), borderRadius: BorderRadius.circular(10)), child: const Text("CỬA HÀNG BỊ KHÓA", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
            _buildTodaySummary(),
            const SizedBox(height: 25),
            _buildGridMenu(),
            const SizedBox(height: 20),
            TextField(controller: _phoneSearchCtrl, decoration: InputDecoration(hintText: "Tìm nhanh khách theo SĐT", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), filled: true, fillColor: Colors.white), onSubmitted: (v) { if(v.isNotEmpty) { HapticFeedback.lightImpact(); Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerHistoryView(phone: v, name: v))); } }),
            const SizedBox(height: 20),
            const PerpetualCalendar(),
            const SizedBox(height: 25),
            _buildAlerts(),
            const SizedBox(height: 50),
          ])),
        ),
      ),
    );
  }

  Widget _buildAlerts() {
    if (expiringWarranties == 0) return const SizedBox();
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarrantyView())),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.2), blurRadius: 10)]),
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

  Widget _buildTodaySummary() {
    String _fmt(int v) => NumberFormat('#,###').format(v);
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(18), 
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]
      ), 
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("TRẠNG THÁI CỬA HÀNG", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 15),
        _summaryRow(Icons.build_circle, Colors.blue, "MÁY ĐANG CHỜ SỬA", "$totalPendingRepair", () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListView(role: widget.role, statusFilter: const [1, 2]))), isBold: true),
        _summaryRow(Icons.receipt_long_rounded, Colors.red, "TỔNG CÔNG NỢ TỒN ĐỌNG", "${_fmt(totalDebtRemain)} đ", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtView())), isBold: true),
        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
        _summaryRow(Icons.add_task, Colors.orange, "Máy nhận mới hôm nay", "$todayNewRepairs", () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListView(role: widget.role, todayOnly: true)))),
        _summaryRow(Icons.shopping_bag_outlined, Colors.pink, "Đơn bán mới hôm nay", "$todaySaleCount", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleListView(todayOnly: true)))),
        _summaryRow(Icons.check_circle_outlined, Colors.green, "Đã giao khách hôm nay", "$todayRepairDone", () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListView(role: widget.role, statusFilter: const [4], todayOnly: true)))),
        _summaryRow(Icons.money_off_rounded, Colors.blueGrey, "Chi phí phát sinh", "${_fmt(todayExpense)} đ", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseView()))),
      ])
    );
  }

  Widget _summaryRow(IconData i, Color c, String l, String v, VoidCallback t, {bool isBold = false}) => InkWell(onTap: t, child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Icon(i, size: 18, color: c), const SizedBox(width: 12), Expanded(child: Text(l, style: TextStyle(fontSize: 13, color: isBold ? Colors.black : Colors.grey, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))), Text(v, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isBold ? c : Colors.black)), const Icon(Icons.chevron_right, size: 14, color: Colors.grey)])));

  Widget _buildGridMenu() {
    final l10n = AppLocalizations.of(context)!;
    final perms = _permissions;
    final tiles = <Widget>[];
    
    void addTile(String permKey, String title, IconData icon, List<Color> colors, VoidCallback onTap, {Widget? badge}) {
      if (hasFullAccess || (perms[permKey] ?? true)) { 
        tiles.add(
          _menuTile(title, icon, colors, onTap, badge: badge)
        ); 
      }
    }
    
    addTile('allowViewSales', l10n.sales, Icons.shopping_cart_checkout_rounded, [const Color(0xFFFF4081), const Color(0xFFFF80AB)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleListView())));
    addTile('allowViewRepairs', l10n.repair, Icons.build_circle_rounded, [const Color(0xFF2979FF), const Color(0xFF448AFF)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListView(role: widget.role))));
    addTile('allowViewInventory', l10n.inventory, Icons.inventory_2_rounded, [const Color(0xFFFF6D00), const Color(0xFFFFAB40)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryView(role: widget.role))));
    addTile('allowViewDebts', "CÔNG NỢ", Icons.receipt_long_rounded, [const Color(0xFF9C27B0), const Color(0xFFE1BEE7)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtView())));

    // --- KHÔI PHỤC NÚT CHI PHÍ ---
    addTile('allowViewExpenses', "CHI PHÍ", Icons.money_off_rounded, [const Color(0xFFFF5722), const Color(0xFFFFAB91)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseView())));

    // --- KHÔI PHỤC NÚT BẢO HÀNH ---
    addTile('allowViewWarranty', "BẢO HÀNH", Icons.verified_user_rounded, [const Color(0xFF4CAF50), const Color(0xFF81C784)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarrantyView())));

    addTile(
      'allowViewChat', "CHAT NỘI BỘ", Icons.chat_bubble_rounded, [const Color(0xFF7C4DFF), const Color(0xFFB388FF)], 
      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatView())),
      badge: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.chatStream(),
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox();
          final userId = FirebaseAuth.instance.currentUser?.uid;
          final unreadCount = snap.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final List readBy = data['readBy'] ?? [];
            return !readBy.contains(userId);
          }).length;
          
          if (unreadCount == 0) return const SizedBox();
          return Positioned(
            right: 0, top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text("$unreadCount", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
          );
        }
      )
    );

    if (hasFullAccess) {
      addTile('allowManageStaff', "NHẬT KÝ", Icons.history_edu_rounded, [const Color(0xFF455A64), const Color(0xFF78909C)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditLogView())));
    }

    addTile('allowViewChat', "CHẤM CÔNG", Icons.fingerprint_rounded, [const Color(0xFF00C853), const Color(0xFF64DD17)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceView())));
    addTile('allowViewCustomers', l10n.customers, Icons.people_alt_rounded, [const Color(0xFF00BFA5), const Color(0xFF64FFDA)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerListView(role: widget.role))));
    
    if (hasFullAccess) {
      addTile('allowViewRevenue', "DS & LƯƠNG", Icons.assessment_rounded, [const Color(0xFF6200EA), const Color(0xFF7C4DFF)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffPerformanceView())));
      // NÚT LỊCH LÀM VIỆC DÀNH RIÊNG CHO OWNER
      addTile('allowManageStaff', "LỊCH LÀM", Icons.schedule_rounded, [const Color(0xFF0097A7), const Color(0xFF26C6DA)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkScheduleSettingsView())));
    }

    addTile('allowViewRevenue', l10n.revenue, Icons.leaderboard_rounded, [const Color(0xFF304FFE), const Color(0xFF536DFE)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RevenueView())));
    addTile('allowViewPrinter', l10n.printer, Icons.print_rounded, [const Color(0xFF607D8B), const Color(0xFF90A4AE)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThermalPrinterDesignView())));
    addTile('allowViewSettings', l10n.settings, Icons.settings_rounded, [const Color(0xFF263238), const Color(0xFF455A64)], _openSettingsCenter);
    
    addTile('allowViewInventory', "KIỂM KHO QR", Icons.qr_code_scanner_rounded, [const Color(0xFFFFAB00), const Color(0xFFFFD740)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryCheckView())));

    return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 15, crossAxisSpacing: 15, childAspectRatio: 1.3, children: tiles);
  }

  void _openSettingsCenter() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.settings_rounded, color: Colors.blueGrey), title: const Text("CÀI ĐẶT HỆ THỐNG"), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsView(setLocale: widget.setLocale))); }),
      if (hasFullAccess) ListTile(leading: const Icon(Icons.group_rounded, color: Colors.indigo), title: const Text("QUẢN LÝ NHÂN VIÊN"), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffListView())); }),
      if (_isSuperAdmin) ListTile(leading: const Icon(Icons.admin_panel_settings_rounded, color: Colors.deepPurple), title: const Text("TRUNG TÂM SUPER ADMIN"), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const admin_view.SuperAdminView())); }),
    ]))));
  }

  Widget _menuTile(String title, IconData icon, List<Color> colors, VoidCallback onTap, {Widget? badge}) {
    return InkWell(
      onTap: onTap, 
      child: Stack(
        children: [
          Container(
            width: double.infinity, height: double.infinity,
            decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: colors[0].withOpacity(0.3), blurRadius: 8)]), 
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 35), const SizedBox(height: 8), Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))])
          ),
          if (badge != null) badge,
        ],
      )
    );
  }
}
