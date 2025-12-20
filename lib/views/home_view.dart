import 'dart:async';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'customer_history_view.dart';
import 'order_list_view.dart';
import 'revenue_view.dart';
import 'customer_view.dart';
import 'inventory_view.dart';
import 'sale_list_view.dart';
import 'expense_view.dart';
import 'debt_view.dart';
import 'warranty_view.dart';
import 'settings_view.dart';
import 'printer_setting_view.dart';
import 'supplier_view.dart';
import 'chat_view.dart';
import 'super_admin_view.dart';
import 'qr_scan_view.dart';
import '../data/db_helper.dart';
import '../widgets/perpetual_calendar.dart';
import '../services/sync_service.dart';
import '../services/user_service.dart';

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
  int todayNewRepairs = 0;
  int todayExpense = 0;
  int totalDebtRemain = 0;
  bool _isSyncing = false;
  Timer? _autoSyncTimer;
  bool _shopLocked = false;
  final TextEditingController _phoneSearchCtrl = TextEditingController();
  Map<String, bool> _permissions = {};

  final bool _isSuperAdmin = UserService.isCurrentUserSuperAdmin();

  bool get isAdmin => widget.role == 'admin';

  @override
  void initState() {
    super.initState();
    _initialSetup();
    SyncService.initRealTimeSync(() {
      if (mounted) _loadStats();
    });

    // Tự động đồng bộ định kỳ (30 giây) để hạn chế phải bấm tay
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _syncNow(silent: true);
    });
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _phoneSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initialSetup() async {
    await db.cleanDuplicateData();
    await _loadStats();
    await _updateShopLockState();
  }

  Future<void> _syncNow({bool silent = false}) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      await SyncService.syncAllToCloud();
      await SyncService.downloadAllFromCloud();
      await _loadStats();
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ĐÃ ĐỒNG BỘ DỮ LIỆU")));
      }
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("LỖI ĐỒNG BỘ: $e")));
      } else {
        // Silent khi auto-sync gặp lỗi để tránh spam người dùng
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _loadStats() async {
    final repairs = await db.getAllRepairs();
    final sales = await db.getAllSales();
    final debts = await db.getAllDebts();
    final expenses = await db.getAllExpenses();

    int pendingR = repairs.where((r) => r.status == 1 || r.status == 2).length;
    int doneToday = 0;
    int soldToday = 0;
    int revToday = 0;
    int newRepairsToday = 0;
    int expenseToday = 0;
    int debtRemain = 0;

    final now = DateFormat('yyyy-MM-dd').format(DateTime.now());

    for (var r in repairs) {
      final createdDate = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(r.createdAt));
      if (createdDate == now) {
        newRepairsToday++;
      }
      String dDate = r.deliveredAt != null
          ? DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(r.deliveredAt!))
          : "";
      if (dDate == now || createdDate == now) {
        if (r.status >= 3) {
          doneToday++;
          revToday += (r.price - r.cost);
        }
      }
    }
    for (var s in sales) {
      final soldDate = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(s.soldAt));
      if (soldDate == now) {
        soldToday++;
        revToday += (s.totalPrice - s.totalCost);
      }
    }

    for (var e in expenses) {
      final d = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(e['date'] as int));
      if (d == now) {
        expenseToday += (e['amount'] as int);
      }
    }

    for (var d in debts) {
      if (d['status'] == 'ĐÃ TRẢ') continue;
      final total = d['totalAmount'] as int;
      final paid = d['paidAmount'] as int? ?? 0;
      final remain = total - paid;
      if (remain > 0) debtRemain += remain;
    }

    if (mounted) {
      setState(() {
        totalPendingRepair = pendingR;
        todayRepairDone = doneToday;
        todaySaleCount = soldToday;
        revenueToday = revToday;
        todayNewRepairs = newRepairsToday;
        todayExpense = expenseToday;
        totalDebtRemain = debtRemain;
      });
    }
  }

  Future<void> _updateShopLockState() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() {
      _shopLocked = perms['shopAppLocked'] == true;
      _permissions = perms.map((key, value) => MapEntry(key, value == true));
    });
  }

  Future<void> _openCustomerHistoryQuick() async {
    final phone = _phoneSearchCtrl.text.trim();
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("VUI LÒNG NHẬP SỐ ĐIỆN THOẠI")),
      );
      return;
    }

    final error = UserService.validatePhone(phone);
    if (error != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    if (!mounted) return;
    final displayName = phone;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerHistoryView(phone: phone, name: displayName),
      ),
    );
  }
  Future<bool> _ensurePermission(String key, String messageIfDenied) async {
    final perms = await UserService.getCurrentUserPermissions();
    if (perms['shopAppLocked'] == true) {
      if (mounted) {
        setState(() => _shopLocked = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cửa hàng này đã bị SUPER ADMIN khóa tạm thời. Vui lòng liên hệ nhà phát triển để mở khóa.")),
        );
      }
      return false;
    }
    final canView = perms[key] ?? false;
    if (!canView) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageIfDenied)));
      return false;
    }
    return true;
  }

  Future<void> _openRevenueView() async {
    final ok = await _ensurePermission('allowViewRevenue', "Tài khoản này không được phép xem màn DOANH THU. Liên hệ chủ shop để phân quyền.");
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RevenueView()));
  }

  Future<void> _openSaleList() async {
    final ok = await _ensurePermission('allowViewSales', "Tài khoản này không được phép vào mục BÁN HÀNG. Liên hệ chủ shop để phân quyền.");
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => SaleListView(role: widget.role)));
  }

  Future<void> _openOrderList() async {
    final ok = await _ensurePermission('allowViewRepairs', "Tài khoản này không được phép vào mục SỬA CHỮA. Liên hệ chủ shop để phân quyền.");
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListView(role: widget.role)));
  }

  Future<void> _openInventory() async {
    final ok = await _ensurePermission('allowViewInventory', "Tài khoản này không được phép vào mục KHO MÁY. Liên hệ chủ shop để phân quyền.");
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryView(role: widget.role)));
  }

  Future<void> _openSuppliers() async {
    final ok = await _ensurePermission('allowViewSuppliers', "Tài khoản này không được phép xem danh sách NHÀ PHÂN PHỐI. Liên hệ chủ shop để phân quyền.");
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierView()));
  }

  Future<void> _openCustomers() async {
    final ok = await _ensurePermission('allowViewCustomers', "Tài khoản này không được phép xem HỆ THỐNG KHÁCH HÀNG. Liên hệ chủ shop để phân quyền.");
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerListView(role: widget.role)));
  }

  Future<void> _openWarranty() async {
    final ok = await _ensurePermission('allowViewWarranty', "Tài khoản này không được phép vào mục BẢO HÀNH. Liên hệ chủ shop để phân quyền.");
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const WarrantyView()));
  }

  Future<void> _openChat() async {
    final ok = await _ensurePermission('allowViewChat', "Tài khoản này không được phép sử dụng CHAT nội bộ. Liên hệ chủ shop để phân quyền.");
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatView()));
  }

  Future<void> _openPrinterSettings() async {
    final ok = await _ensurePermission('allowViewPrinter', "Tài khoản này không được phép cấu hình MÁY IN. Liên hệ chủ shop để phân quyền.");
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingView()));
  }

  void _openSettingsCenter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.settings_rounded, color: Colors.blueGrey),
                title: const Text("CÀI ĐẶT HỆ THỐNG", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Logo, thông tin cửa hàng, hóa đơn"),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsView()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.print_rounded, color: Colors.teal),
                title: const Text("CẤU HÌNH MÁY IN", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Bluetooth / WiFi"),
                onTap: () {
                  Navigator.pop(ctx);
                  _openPrinterSettings();
                },
              ),
              if (_isSuperAdmin)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_rounded, color: Colors.deepPurple),
                  title: const Text("TRUNG TÂM SUPER ADMIN", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Khóa/mở shop, cấu hình đặc biệt"),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SuperAdminView()));
                  },
                ),
            ],
          ),
        ),
      ),
    );
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
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => QrScanView(role: widget.role)),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.blueAccent),
            ),
            IconButton(onPressed: _loadStats, icon: const Icon(Icons.refresh_rounded, color: Colors.blue)),
            IconButton(
              onPressed: _isSyncing ? null : () => _syncNow(),
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync, color: Colors.green),
            ),
            IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout_rounded, color: Colors.redAccent)),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_shopLocked)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_clock_rounded, color: Colors.redAccent, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "CỬA HÀNG ĐANG BỊ SUPER ADMIN KHÓA TẠM THỜI. Mọi chức năng đều bị giới hạn cho đến khi được mở lại.",
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: _phoneSearchCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: "Tìm nhanh khách theo SĐT",
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded),
                    onPressed: _openCustomerHistoryQuick,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onSubmitted: (_) => _openCustomerHistoryQuick(),
              ),
              const SizedBox(height: 20),
              const PerpetualCalendar(),
              const SizedBox(height: 25),
              _buildQuickStats(),
              const SizedBox(height: 25),
              _buildTodaySummary(),
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
    final tiles = <Widget>[];

    void addTile(bool canView, String title, IconData icon, List<Color> colors, VoidCallback onTap) {
      if (!canView) return;
      tiles.add(_menuTile(title, icon, colors, onTap));
    }

    final perms = _permissions;

    // Thứ tự mong muốn: Bán hàng -> Sửa chữa -> Chat -> Khách hàng -> Bảo hành -> Kho -> Nhà phân phối -> Doanh thu -> (công cụ phụ) -> Cài đặt
    addTile(perms['allowViewSales'] ?? true, "BÁN HÀNG", Icons.shopping_cart_checkout_rounded, [Colors.pink, Colors.redAccent], _openSaleList);
    addTile(perms['allowViewRepairs'] ?? true, "SỬA CHỮA", Icons.build_circle_rounded, [Colors.blue, Colors.lightBlue], _openOrderList);
    addTile(perms['allowViewChat'] ?? true, "CHAT", Icons.chat_bubble_rounded, [Colors.deepPurple, Colors.purpleAccent], _openChat);
    addTile(perms['allowViewCustomers'] ?? true, "KHÁCH HÀNG", Icons.people_alt_rounded, [Colors.cyan, Colors.teal], _openCustomers);
    addTile(perms['allowViewWarranty'] ?? true, "BẢO HÀNH", Icons.verified_user_rounded, [Colors.green, Colors.teal], _openWarranty);
    addTile(perms['allowViewInventory'] ?? true, "KHO", Icons.inventory_2_rounded, [Colors.orange, Colors.amber], _openInventory);
    addTile(perms['allowViewSuppliers'] ?? true, "NHÀ PHÂN PHỐI", Icons.business_rounded, [Colors.indigo, Colors.blueAccent], _openSuppliers);
    addTile(perms['allowViewRevenue'] ?? true, "DOANH THU", Icons.leaderboard_rounded, [Colors.indigo, Colors.deepPurple], _openRevenueView);
    addTile(perms['allowViewPrinter'] ?? true, "MÁY IN", Icons.print_rounded, [Colors.blueGrey, Colors.grey], _openPrinterSettings);
    addTile(isAdmin || _isSuperAdmin, "CÀI ĐẶT", Icons.settings_rounded, [Colors.blueGrey, Colors.black87], _openSettingsCenter);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      childAspectRatio: 1.3,
      children: tiles,
    );
  }

  Widget _buildTodaySummary() {
    String _fmtCurrency(int v) => NumberFormat('#,###').format(v);

    Widget row(IconData icon, Color color, String label, String value, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
              const SizedBox(width: 8),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "VIỆC HÔM NAY",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 6),
          row(Icons.build_circle_outlined, Colors.orange, "Máy nhận hôm nay", "$todayNewRepairs", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderListView(role: widget.role, todayOnly: true),
              ),
            );
          }),
          row(Icons.shopping_bag_outlined, Colors.pink, "Đơn bán hôm nay", "$todaySaleCount", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SaleListView(role: widget.role, todayOnly: true),
              ),
            );
          }),
          row(Icons.money_off_csred_rounded, Colors.redAccent, "Chi phí hôm nay", "${_fmtCurrency(todayExpense)} đ", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ExpenseView(),
              ),
            );
          }),
          row(Icons.receipt_long_rounded, Colors.deepPurple, "Công nợ còn lại", "${_fmtCurrency(totalDebtRemain)} đ", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DebtView(),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _menuTile(String title, IconData icon, List<Color> colors, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: colors[0].withOpacity(0.3), blurRadius: 8)]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 35), const SizedBox(height: 8), Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))])));
  }
}
