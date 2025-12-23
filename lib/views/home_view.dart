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

  bool get isAdmin => widget.role == 'admin';
  bool get isOwner => widget.role == 'owner';

  @override
  void initState() {
    super.initState();
    debugPrint("HomeView initState called");
    debugPrint("HomeView: role = ${widget.role}");
    debugPrint("HomeView: isOwner = $isOwner");
    debugPrint("HomeView: _isSuperAdmin = $_isSuperAdmin");
    _initialSetup();
    SyncService.initRealTimeSync(_debouncedLoadStats);

    // Tự động đồng bộ định kỳ (30 giây) để hạn chế phải bấm tay
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _syncNow(silent: true);
    });
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
      // User mới, clear local DB để tránh data cũ
      await db.clearAllData();
      await prefs.setString('lastUserId', currentUser.uid);
      
      // Đảm bảo sync user info trước khi load permissions
      if (currentUser.email != null) {
        await UserService.syncUserInfo(currentUser.uid, currentUser.email!);
      }
    }
    await db.cleanDuplicateData();
    await _loadStats();
    await _updateShopLockState();
    
    // Temporary: update existing shop documents with shopId field
    await UserService.updateExistingShopsWithShopId();
  }

  Future<void> _syncNow({bool silent = false}) async {
    if (_isSyncing) {
      // Nếu đang sync và đây là manual sync (không silent), cho phép hủy
      if (!silent) {
        setState(() => _isSyncing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ĐÃ HỦY ĐỒNG BỘ")));
        }
      }
      return;
    }
    setState(() => _isSyncing = true);
    try {
      // Temporary: update existing shop documents with shopId field
      await UserService.updateExistingShopsWithShopId();
      
      // Thêm timeout để tránh sync bị treo
      await Future.wait([
        SyncService.syncAllToCloud(),
        SyncService.downloadAllFromCloud(),
      ]).timeout(const Duration(seconds: 120), onTimeout: () {
        throw TimeoutException('Đồng bộ quá thời gian cho phép (120 giây)');
      });
      
      await _loadStats();
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ĐÃ ĐỒNG BỘ DỮ LIỆU")));
      }
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("LỖI ĐỒNG BỘ: $e")));
      } else {
        // Silent khi auto-sync gặp lỗi để tránh spam người dùng
        debugPrint("Auto sync error: $e");
      }
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
    final l10n = AppLocalizations.of(context)!;
    final ok = await _ensurePermission('allowViewRevenue', l10n.noPermissionRevenue);
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RevenueView()));
  }

  Future<void> _openRevenueReportView() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _ensurePermission('allowViewRevenue', l10n.noPermissionRevenueReport);
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RevenueReportView()));
  }

  Future<void> _openSaleList() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _ensurePermission('allowViewSales', l10n.noPermissionSales);
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleListView()));
  }

  Future<void> _openOrderList() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _ensurePermission('allowViewRepairs', l10n.noPermissionRepair);
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => OrderListView(role: widget.role)));
  }

  Future<void> _openInventory() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _ensurePermission('allowViewInventory', l10n.noPermissionInventory);
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryView()));
  }

  Future<void> _openCustomers() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _ensurePermission('allowViewCustomers', l10n.noPermissionCustomers);
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerListView(role: widget.role)));
  }

  Future<void> _openWarranty() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _ensurePermission('allowViewWarranty', l10n.noPermissionWarranty);
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const WarrantyView()));
  }

  Future<void> _openChat() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _ensurePermission('allowViewChat', l10n.noPermissionChat);
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatView()));
  }

  Future<void> _openPrinterSettings() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _ensurePermission('allowViewPrinter', l10n.noPermissionPrinter);
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingView()));
  }

  Future<void> _openThermalPrinterDesign() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _ensurePermission('allowViewPrinter', l10n.noPermissionPrinter);
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ThermalPrinterDesignView()));
  }

  Future<void> _openRepairReceipt() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _ensurePermission('allowViewRepairs', l10n.noPermissionCreateRepair);
    if (!ok || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RepairReceiptView()));
  }

  void _showPrinterMenu() {
    final l10n = AppLocalizations.of(context)!;
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
                leading: const Icon(Icons.inventory_2_rounded, color: Colors.orange),
                title: Text(l10n.inventoryCheck, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(l10n.checkInventoryDesc),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryCheckView()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_rounded, color: Colors.blueAccent),
                title: Text(l10n.receiptPrinter, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(l10n.printReceiptsDesc),
                onTap: () {
                  Navigator.pop(ctx);
                  _openPrinterSettings();
                },
              ),
              ListTile(
                leading: const Icon(Icons.assignment_rounded, color: Colors.green),
                title: Text(l10n.repairReceipt, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(l10n.createRepairReceiptDesc),
                onTap: () {
                  Navigator.pop(ctx);
                  _openRepairReceipt();
                },
              ),
              ListTile(
                leading: const Icon(Icons.thermostat_rounded, color: Colors.redAccent),
                title: Text(l10n.thermalPrinter, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(l10n.printLabelsDesc),
                onTap: () {
                  Navigator.pop(ctx);
                  _openThermalPrinterDesign();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSettingsCenter() {
    print('DEBUG: _openSettingsCenter called');
    print('DEBUG: _permissions = $_permissions');
    print('DEBUG: allowManageStaff = ${_permissions['allowManageStaff']}');
    print('DEBUG: _isSuperAdmin = $_isSuperAdmin');
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
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsView(setLocale: widget.setLocale)));
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
              if (isOwner || widget.role == 'manager' || _isSuperAdmin)
                ListTile(
                  leading: const Icon(Icons.group_rounded, color: Colors.indigo),
                  title: const Text("QUẢN LÝ NHÂN VIÊN", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Thêm/sửa/xóa nhân viên, tạo mã mời"),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffListView()));
                  },
                ),
              if (_isSuperAdmin)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_rounded, color: Colors.deepPurple),
                  title: const Text("TRUNG TÂM SUPER ADMIN", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Khóa/mở shop, cấu hình đặc biệt"),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const admin_view.SuperAdminView()));
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
    final l10n = AppLocalizations.of(context)!;
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
                  isAdmin ? l10n.shopManagement : l10n.employee,
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
              tooltip: 'Quét QR đơn hàng & tem điện thoại',
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
              tooltip: 'Đồng bộ dữ liệu',
            ),
            IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout_rounded, color: Colors.redAccent)),
          ],
        ),
        body: _buildMainHome(),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
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
                      const Text('TRUY CẬP NHANH', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.inventory_2_rounded, color: Colors.orange),
                        title: const Text("KIỂM KHO", style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text("Kiểm tra tồn kho điện thoại & phụ kiện"),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryCheckView()));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.inventory_2_rounded, color: Colors.amber),
                        title: const Text("QUẢN LÝ KHO", style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text("Xem & in tem điện thoại"),
                        onTap: () {
                          Navigator.pop(ctx);
                          _openInventory();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.account_circle, color: Colors.blue),
                        title: const Text("THÔNG TIN TÀI KHOAN", style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text("Xem quyền và thông tin tài khoản"),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final user = FirebaseAuth.instance.currentUser;
                          final perms = await UserService.getCurrentUserPermissions();
                          if (!mounted) return;
                          showDialog(
                            context: context,
                            builder: (ctx) {
                              final l10n = AppLocalizations.of(ctx)!;
                              return AlertDialog(
                                title: Text(l10n.accountInfo),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${l10n.email}: ${user?.email ?? 'N/A'}'),
                                    Text('${l10n.superAdmin}: ${_isSuperAdmin ? l10n.allowed : l10n.notAllowed}'),
                                    Text('${l10n.admin}: ${perms['allowViewInventory'] == true ? l10n.allowed : l10n.notAllowed}'),
                                    Text('${l10n.viewInventoryPermission}: ${perms['allowViewInventory'] == true ? l10n.allowed : l10n.notAllowed}'),
                                    const SizedBox(height: 10),
                                    Text(l10n.otherPermissions, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('• ${l10n.salesPermission}: ${perms['allowViewSales'] == true ? l10n.allowed : l10n.notAllowed}'),
                                    Text('• ${l10n.repairPermission}: ${perms['allowViewRepairs'] == true ? l10n.allowed : l10n.notAllowed}'),
                                    Text('• ${l10n.printerPermission}: ${perms['allowViewPrinter'] == true ? l10n.allowed : l10n.notAllowed}'),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(l10n.close),
                                ),
                              ],
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          child: const Icon(Icons.menu),
          tooltip: l10n.quickMenu,
        ),
      ),
    );
  }

  Widget _buildMainHome() {
    return SingleChildScrollView(
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
          _buildWelcomeMessage(),
          const SizedBox(height: 25),
          _buildTodaySummary(),
          const SizedBox(height: 25),
          _buildGridMenu(),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserInfo(),
      builder: (context, snapshot) {
        final userInfo = snapshot.data ?? {};
        final displayName = userInfo['displayName'] ?? 'Người dùng';
        final shopName = userInfo['shopName'] ?? 'Đang tải...';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(Icons.person, color: Colors.blueAccent, size: 30),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xin chào: $displayName  $shopName',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    final userInfo = await UserService.getUserInfo(user.uid);
    final shopId = await UserService.getCurrentShopId();

    String shopName = 'Chưa xác định';
    if (shopId != null) {
      try {
        final shopDoc = await FirebaseFirestore.instance.collection('shops').doc(shopId).get();
        if (shopDoc.exists) {
          shopName = shopDoc.data()?['name'] ?? 'Shop không tên';
        }
      } catch (e) {
        // Ignore error
      }
    }

    return {
      ...userInfo,
      'shopName': shopName,
    };
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'owner':
        return 'Chủ shop';
      case 'manager':
        return 'Quản lý';
      case 'employee':
        return 'Nhân viên';
      default:
        return 'Người dùng';
    }
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
    final l10n = AppLocalizations.of(context)!;
    final tiles = <Widget>[];

    void addTile(bool canView, String title, IconData icon, List<Color> colors, VoidCallback onTap) {
      if (!canView) return;
      tiles.add(_menuTile(title, icon, colors, onTap));
    }

    final perms = _permissions;

    // Thứ tự mong muốn: Bán hàng -> Sửa chữa -> Chat -> Khách hàng -> Bảo hành -> Kho -> Nhà phân phối -> Doanh thu -> (công cụ phụ) -> Cài đặt
    addTile(perms['allowViewSales'] ?? true, l10n.sales, Icons.shopping_cart_checkout_rounded, [Colors.pink, Colors.redAccent], _openSaleList);
    addTile(perms['allowViewRepairs'] ?? true, l10n.repair, Icons.build_circle_rounded, [Colors.blue, Colors.lightBlue], _openOrderList);
    addTile(perms['allowViewChat'] ?? true, l10n.chat, Icons.chat_bubble_rounded, [Colors.deepPurple, Colors.purpleAccent], _openChat);
    addTile(perms['allowViewCustomers'] ?? true, l10n.customers, Icons.people_alt_rounded, [Colors.cyan, Colors.teal], _openCustomers);
    addTile(perms['allowViewWarranty'] ?? true, l10n.warranty, Icons.verified_user_rounded, [Colors.green, Colors.teal], _openWarranty);
    addTile(perms['allowViewInventory'] ?? true, l10n.inventory, Icons.inventory_2_rounded, [Colors.orange, Colors.amber], _openInventory);
    addTile(perms['allowViewRevenue'] ?? true, l10n.revenue, Icons.leaderboard_rounded, [Colors.indigo, Colors.deepPurple], _openRevenueView);
    addTile(perms['allowViewRevenue'] ?? true, l10n.revenueReport, Icons.analytics_rounded, [Colors.indigoAccent, Colors.blueAccent], _openRevenueReportView);
    addTile(perms['allowViewPrinter'] ?? true, l10n.printer, Icons.print_rounded, [Colors.blueGrey, Colors.grey], _showPrinterMenu);
    addTile(perms['allowViewSettings'] ?? (isAdmin || _isSuperAdmin), l10n.settings, Icons.settings_rounded, [Colors.blueGrey, Colors.black87], _openSettingsCenter);

    print('DEBUG: Total tiles created: ${tiles.length}');
    // for (var i = 0; i < tiles.length; i++) {
    //   print('DEBUG: Tile $i: ${tiles[i].title}');
    // }

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
              Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
              const SizedBox(width: 8),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
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
                builder: (_) => const SaleListView(todayOnly: true),
              ),
            );
          }),
          row(Icons.check_circle_outlined, Colors.green, "Xong/Giao hôm nay", "$todayRepairDone", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderListView(role: widget.role, statusFilter: const [3, 4], todayOnly: true),
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
