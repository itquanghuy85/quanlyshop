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
import 'printer_setting_view.dart';
import 'chat_view.dart';
import 'thermal_printer_design_view.dart';
import 'inventory_check_view.dart';
import 'repair_receipt_view.dart';
import 'super_admin_view.dart' as admin_view;
import 'staff_list_view.dart';
import 'qr_scan_view.dart';
import '../data/db_helper.dart';
import '../widgets/perpetual_calendar.dart';
import '../services/sync_service.dart';
import '../services/user_service.dart';

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
  bool _isSyncing = false;
  Timer? _autoSyncTimer;
  Timer? _debounceTimer;
  bool _shopLocked = false;
  final TextEditingController _phoneSearchCtrl = TextEditingController();
  Map<String, bool> _permissions = {};

  final bool _isSuperAdmin = UserService.isCurrentUserSuperAdmin();

  bool get hasFullAccess => widget.role == 'admin' || widget.role == 'owner' || _isSuperAdmin;

  @override
  void initState() {
    super.initState();
    _initialSetup();
    SyncService.initRealTimeSync(_debouncedLoadStats);
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) => _syncNow(silent: true));
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _debounceTimer?.cancel();
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
    setState(() => _isSyncing = true);
    try {
      await Future.wait([SyncService.syncAllToCloud(), SyncService.downloadAllFromCloud()]).timeout(const Duration(seconds: 120));
      await _loadStats();
      if (mounted && !silent) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ĐÃ ĐỒNG BỘ DỮ LIỆU")));
    } catch (e) {
      if (mounted && !silent) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("LỖI ĐỒNG BỘ: $e")));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _debouncedLoadStats() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) _loadStats();
    });
  }

  Future<void> _loadStats() async {
    final repairs = await db.getAllRepairs();
    final sales = await db.getAllSales();
    final debts = await db.getAllDebts();
    final expenses = await db.getAllExpenses();

    int pendingR = repairs.where((r) => r.status == 1 || r.status == 2).length;
    int doneToday = 0; int soldToday = 0; int revToday = 0; int newRToday = 0; int expToday = 0; int debtRem = 0;
    final now = DateFormat('yyyy-MM-dd').format(DateTime.now());

    for (var r in repairs) {
      final cDate = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(r.createdAt));
      if (cDate == now) newRToday++;
      if (r.status >= 3 && (r.deliveredAt != null && DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(r.deliveredAt!)) == now)) {
        doneToday++; revToday += (r.price - r.cost);
      }
    }
    for (var s in sales) {
      if (DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(s.soldAt)) == now) {
        soldToday++; revToday += (s.totalPrice - s.totalCost);
      }
    }
    for (var e in expenses) {
      if (DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(e['date'] as int)) == now) expToday += (e['amount'] as int);
    }
    for (var d in debts) {
      if (d['status'] != 'ĐÃ TRẢ') debtRem += (d['totalAmount'] as int) - (d['paidAmount'] as int? ?? 0);
    }

    if (mounted) setState(() { totalPendingRepair = pendingR; todayRepairDone = doneToday; todaySaleCount = soldToday; revenueToday = revToday; todayNewRepairs = newRToday; todayExpense = expToday; totalDebtRemain = debtRem; });
  }

  Future<void> _openCustomerHistoryQuick() async {
    final phone = _phoneSearchCtrl.text.trim();
    if (phone.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerHistoryView(phone: phone, name: phone)));
  }

  Future<bool> _onWillPop() async {
    return await showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 120, width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF2962FF), Color(0xFF00B0FF)]),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                ),
                child: const Icon(Icons.logout_rounded, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text("Nghỉ tay một chút nhé?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text("Bạn có chắc muốn đóng ứng dụng không?", textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text("HỦY"))),
                  const SizedBox(width: 16),
                  Expanded(child: ElevatedButton(onPressed: () => SystemNavigator.pop(), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text("THOÁT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                ]),
              ),
            ],
          ),
        ),
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        appBar: AppBar(
          backgroundColor: Colors.white, elevation: 0,
          title: Row(children: [
            const Icon(Icons.store_rounded, color: Color(0xFF2962FF), size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(hasFullAccess ? "QUẢN TRỊ CỬA HÀNG" : "NHÂN VIÊN", style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
          ]),
          actions: [
            IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QrScanView(role: widget.role))), icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2962FF))),
            IconButton(onPressed: _loadStats, icon: const Icon(Icons.refresh_rounded, color: Colors.blue)),
            IconButton(onPressed: () => _syncNow(), icon: _isSyncing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync, color: Colors.green)),
            IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout_rounded, color: Colors.redAccent)),
          ],
        ),
        body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_shopLocked) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.red.shade50, border: Border.all(color: Colors.redAccent), borderRadius: BorderRadius.circular(10)), child: const Text("CỬA HÀNG BỊ KHÓA", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
          TextField(controller: _phoneSearchCtrl, decoration: InputDecoration(hintText: "Tìm khách theo SĐT", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white), onSubmitted: (_) => _openCustomerHistoryQuick()),
          const SizedBox(height: 20),
          const PerpetualCalendar(),
          const SizedBox(height: 25),
          _buildTodaySummary(),
          const SizedBox(height: 25),
          _buildGridMenu(),
          const SizedBox(height: 50),
        ])),
      ),
    );
  }

  Widget _buildTodaySummary() {
    String _fmt(int v) => NumberFormat('#,###').format(v);
    return Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("VIỆC HÔM NAY", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
      const SizedBox(height: 10),
      _summaryRow(Icons.build_circle_outlined, Colors.orange, "Máy nhận mới", "$todayNewRepairs", () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListView(role: widget.role, todayOnly: true)))),
      _summaryRow(Icons.shopping_bag_outlined, Colors.pink, "Đơn bán mới", "$todaySaleCount", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleListView(todayOnly: true)))),
      _summaryRow(Icons.check_circle_outlined, Colors.green, "Đã xong/giao", "$todayRepairDone", () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListView(role: widget.role, statusFilter: const [3, 4], todayOnly: true)))),
      _summaryRow(Icons.money_off_rounded, Colors.redAccent, "Chi phí", "${_fmt(todayExpense)} đ", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseView()))),
      _summaryRow(Icons.receipt_long_rounded, Colors.deepPurple, "Công nợ", "${_fmt(totalDebtRemain)} đ", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtView()))),
    ]));
  }

  Widget _summaryRow(IconData icon, Color color, String label, String value, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 10), Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const Icon(Icons.chevron_right, size: 14, color: Colors.grey)])));
  }

  Widget _buildGridMenu() {
    final l10n = AppLocalizations.of(context)!;
    final perms = _permissions;
    final tiles = <Widget>[];
    void addTile(String permKey, String title, IconData icon, List<Color> colors, VoidCallback onTap) {
      if (hasFullAccess || (perms[permKey] ?? true)) { tiles.add(_menuTile(title, icon, colors, onTap)); }
    }
    addTile('allowViewSales', l10n.sales, Icons.shopping_cart_checkout_rounded, [const Color(0xFFFF4081), const Color(0xFFFF80AB)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleListView())));
    addTile('allowViewRepairs', l10n.repair, Icons.build_circle_rounded, [const Color(0xFF2979FF), const Color(0xFF448AFF)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListView(role: widget.role))));
    addTile('allowViewChat', l10n.chat, Icons.chat_bubble_rounded, [const Color(0xFF7C4DFF), const Color(0xFFB388FF)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatView())));
    addTile('allowViewInventory', "KIỂM KHO QR", Icons.qr_code_scanner_rounded, [const Color(0xFFFFAB00), const Color(0xFFFFD740)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryCheckView())));
    addTile('allowViewInventory', l10n.inventory, Icons.inventory_2_rounded, [const Color(0xFFFF6D00), const Color(0xFFFFAB40)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryView())));
    addTile('allowViewCustomers', l10n.customers, Icons.people_alt_rounded, [const Color(0xFF00BFA5), const Color(0xFF64FFDA)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerListView(role: widget.role))));
    addTile('allowViewRevenue', l10n.revenue, Icons.leaderboard_rounded, [const Color(0xFF304FFE), const Color(0xFF536DFE)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RevenueView())));
    addTile('allowViewRevenue', l10n.revenueReport, Icons.analytics_rounded, [const Color(0xFF3D5AFE), const Color(0xFF8C9EFF)], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RevenueReportView())));
    addTile('allowViewPrinter', l10n.printer, Icons.print_rounded, [const Color(0xFF607D8B), const Color(0xFF90A4AE)], _showPrinterMenu);
    addTile('allowViewSettings', l10n.settings, Icons.settings_rounded, [const Color(0xFF263238), const Color(0xFF455A64)], _openSettingsCenter);
    return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 15, crossAxisSpacing: 15, childAspectRatio: 1.3, children: tiles);
  }

  void _showPrinterMenu() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.receipt_long_rounded, color: Colors.blueAccent), title: Text(l10n.receiptPrinter), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingView())); }),
      ListTile(leading: const Icon(Icons.assignment_rounded, color: Colors.green), title: Text(l10n.repairReceipt), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const RepairReceiptView())); }),
      ListTile(leading: const Icon(Icons.thermostat_rounded, color: Colors.redAccent), title: Text(l10n.thermalPrinter), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const ThermalPrinterDesignView())); }),
    ]))));
  }

  void _openSettingsCenter() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.settings_rounded, color: Colors.blueGrey), title: const Text("CÀI ĐẶT HỆ THỐNG"), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsView(setLocale: widget.setLocale))); }),
      ListTile(leading: const Icon(Icons.print_rounded, color: Colors.teal), title: const Text("CẤU HÌNH MÁY IN"), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingView())); }),
      if (hasFullAccess) ListTile(leading: const Icon(Icons.group_rounded, color: Colors.indigo), title: const Text("QUẢN LÝ NHÂN VIÊN"), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffListView())); }),
      if (_isSuperAdmin) ListTile(leading: const Icon(Icons.admin_panel_settings_rounded, color: Colors.deepPurple), title: const Text("TRUNG TÂM SUPER ADMIN"), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const admin_view.SuperAdminView())); }),
    ]))));
  }

  Widget _menuTile(String title, IconData icon, List<Color> colors, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: colors[0].withOpacity(0.3), blurRadius: 8)]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 35), const SizedBox(height: 8), Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))])));
  }
}
