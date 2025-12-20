import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'create_repair_order_view.dart';
import 'order_list_view.dart';
import 'revenue_view.dart';
import 'customer_view.dart';
import 'repair_detail_view.dart';
import 'inventory_view.dart';
import 'create_sale_view.dart';
import 'sale_detail_view.dart';
import 'sale_list_view.dart';
import 'warranty_view.dart';
import 'staff_list_view.dart';
import 'expense_view.dart';
import 'debt_view.dart';
import 'settings_view.dart';
import 'my_profile_view.dart';
import 'printer_setting_view.dart';
import 'parts_inventory_view.dart';
import 'supplier_view.dart';
import 'chat_view.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import '../widgets/perpetual_calendar.dart';
import '../services/sync_service.dart';

class HomeView extends StatefulWidget {
  final String role;
  const HomeView({super.key, this.role = 'user'});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final db = DBHelper();
  int totalPendingRepair = 0;
  int todaySaleCount = 0;
  int todayRepairDone = 0;
  int revenueToday = 0;
  bool _isSyncing = false;

  bool get isAdmin => widget.role == 'admin';

  @override
  void initState() {
    super.initState();
    _initialSetup();
    SyncService.initRealTimeSync(() {
      if (mounted) _loadStats();
    });
  }

  Future<void> _initialSetup() async {
    await db.cleanDuplicateData();
    await _loadStats();
  }

  Future<void> _syncNow() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      await SyncService.syncAllToCloud();
      await SyncService.downloadAllFromCloud();
      await _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ĐÃ ĐỒNG BỘ DỮ LIỆU")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("LỖI ĐỒNG BỘ: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _loadStats() async {
    final repairs = await db.getAllRepairs();
    final sales = await db.getAllSales();
    int pendingR = repairs.where((r) => r.status == 1 || r.status == 2).length;
    int doneToday = 0; int soldToday = 0; int revToday = 0;
    final now = DateFormat('yyyy-MM-dd').format(DateTime.now());

    for (var r in repairs) {
      String dDate = r.deliveredAt != null ? DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(r.deliveredAt!)) : "";
      if (dDate == now || DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(r.createdAt)) == now) {
        if (r.status >= 3) { doneToday++; revToday += (r.price - r.cost); }
      }
    }
    for (var s in sales) {
      if (DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(s.soldAt)) == now) {
        soldToday++; revToday += (s.totalPrice - s.totalCost);
      }
    }
    if (mounted) setState(() { totalPendingRepair = pendingR; todayRepairDone = doneToday; todaySaleCount = soldToday; revenueToday = revToday; });
  }

  Future<bool> _onWillPop() async {
    return await showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Center(child: Text("THOÁT ỨNG DỤNG?", style: TextStyle(fontWeight: FontWeight.bold))),
          content: const Text("Bạn có chắc muốn đóng app Quản Lý Shop không?", textAlign: TextAlign.center),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("HỦY")),
            ElevatedButton(onPressed: () => SystemNavigator.pop(), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text("THOÁT")),
          ],
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
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.store_rounded, color: Colors.blueAccent),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  isAdmin ? "QUẢN LÝ SHOP" : "NHÂN VIÊN",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileView())), icon: const Icon(Icons.account_circle_rounded, color: Colors.blueAccent)),
            IconButton(onPressed: _loadStats, icon: const Icon(Icons.refresh_rounded, color: Colors.blue)),
            IconButton(onPressed: _syncNow, icon: _isSyncing ? const Icon(Icons.sync, color: Colors.grey) : const Icon(Icons.sync, color: Colors.green)),
            if (isAdmin) IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsView())), icon: const Icon(Icons.settings_rounded, color: Colors.blueGrey)),
            IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout_rounded, color: Colors.redAccent)),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PerpetualCalendar(),
              const SizedBox(height: 25),
              _buildQuickStats(),
              const SizedBox(height: 25),
              _buildGridMenu(),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(children: [
      _statCard("Đang sửa", "$totalPendingRepair", Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListView(role: widget.role, statusFilter: const [1, 2])))),
      const SizedBox(width: 10),
      _statCard("Xong/Giao hôm nay", "$todayRepairDone", Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListView(role: widget.role, statusFilter: const [3, 4], todayOnly: true)))),
      const SizedBox(width: 10),
      _statCard("Bán máy hôm nay", "$todaySaleCount", Colors.pink, () => Navigator.push(context, MaterialPageRoute(builder: (_) => SaleListView(role: widget.role, todayOnly: true)))),
    ]);
  }

  Widget _statCard(String label, String value, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.2))),
          child: Column(children: [Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10))]),
        ),
      ),
    );
  }

  Widget _buildGridMenu() {
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 15, crossAxisSpacing: 15, childAspectRatio: 1.3,
      children: [
        _menuTile("BÁN HÀNG", Icons.shopping_cart_checkout_rounded, [Colors.pink, Colors.redAccent], () => Navigator.push(context, MaterialPageRoute(builder: (_) => SaleListView(role: widget.role)))),
        _menuTile("SỬA CHỮA", Icons.build_circle_rounded, [Colors.blue, Colors.lightBlue], () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListView(role: widget.role)))),
        _menuTile("DOANH THU", Icons.leaderboard_rounded, [Colors.indigo, Colors.deepPurple], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RevenueView()))),
        _menuTile("KHO MÁY", Icons.inventory_2_rounded, [Colors.orange, Colors.amber], () => Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryView(role: widget.role)))),
        _menuTile("NHÀ PHÂN PHỐI", Icons.business_rounded, [Colors.indigo, Colors.blueAccent], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierView()))),
        _menuTile("KHÁCH HÀNG", Icons.people_alt_rounded, [Colors.cyan, Colors.teal], () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerListView(role: widget.role)))),
        _menuTile("BẢO HÀNH", Icons.verified_user_rounded, [Colors.green, Colors.teal], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarrantyView()))),
        _menuTile("CHAT", Icons.chat_bubble_rounded, [Colors.deepPurple, Colors.purpleAccent], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatView()))),
        _menuTile("MÁY IN", Icons.print_rounded, [Colors.blueGrey, Colors.grey], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingView()))),
      ],
    );
  }

  Widget _menuTile(String title, IconData icon, List<Color> colors, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: colors[0].withOpacity(0.3), blurRadius: 8)]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 35), const SizedBox(height: 8), Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))])));
  }
}
