import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/claims_service.dart';
import '../services/firestore_service.dart';
import '../services/super_admin_security_service.dart';
import '../services/user_service.dart';
import '../widgets/responsive_wrapper.dart';
import '../widgets/custom_app_bar.dart';
import '../l10n/app_localizations.dart';
import 'shop_selector_view.dart';

enum _AdminSection {
  dashboard,
  shops,
  users,
  permissions,
  audit,
  broadcast,
  settings,
  danger,
}

class SuperAdminConsoleView extends StatefulWidget {
  const SuperAdminConsoleView({super.key});

  @override
  State<SuperAdminConsoleView> createState() => _SuperAdminConsoleViewState();
}

class _SuperAdminConsoleViewState extends State<SuperAdminConsoleView> {
  final _db = FirebaseFirestore.instance;
  _AdminSection _section = _AdminSection.dashboard;

  Timer? _idleTimer;
  bool _checkingAccess = true;
  bool _hasAccess = false;

  int _shopsRefreshKey = 0;
  int _usersRefreshKey = 0;

  String? _auditShopFilter;
  String _auditActionFilter = 'all';
  String _auditTextFilter = '';

  @override
  void initState() {
    super.initState();
    _bootstrapAccess();
    _startIdleGuard();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrapAccess() async {
    try {
      final claims = await ClaimsService().getClaimsFromToken(forceRefresh: true);
      final ok = claims?['isSuperAdmin'] == true || claims?['role'] == 'super_admin';
      UserService.setCurrentUserSuperAdmin(ok);
      if (!mounted) return;
      if (ok) {
        SuperAdminSecurityService.touchActivity();
        setState(() { _hasAccess = true; _checkingAccess = false; });
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final hasPinSetup = await SuperAdminSecurityService.isPinSetup();
          if (!mounted) return;
          if (hasPinSetup && !SuperAdminSecurityService.isSessionValid()) {
            final pinOk = await _requirePinReauth(title: 'Xác thực Super Admin');
            if (!pinOk) {
              SuperAdminSecurityService.clearSession();
              UserService.clearCache();
              await FirebaseAuth.instance.signOut();
            }
          }
        });
      } else {
        setState(() { _hasAccess = false; _checkingAccess = false; });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _hasAccess = false; _checkingAccess = false; });
    }
  }

  void _startIdleGuard() {
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (!SuperAdminSecurityService.isSessionValid()) {
        SuperAdminSecurityService.lockSession();
      }
    });
  }

  Future<bool> _requirePinReauth({String title = 'Xác thực PIN'}) async {
    if (!mounted) return false;
    final pinC = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.lock, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text(title),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nhập PIN Super Admin để tiếp tục thao tác nguy hiểm.'),
              const SizedBox(height: 12),
              TextField(
                controller: pinC,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'PIN (4-6 số)',
                  border: const OutlineInputBorder(),
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(
              onPressed: () async {
                final verified = await SuperAdminSecurityService.verifyPin(pinC.text.trim());
                if (!verified) { setD(() => error = 'PIN không đúng'); return; }
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _enterShop(Map<String, dynamic> shop) async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShopSelectorView(setLocale: null)),
    );
  }

  Future<void> _toggleShopLock({
    required String shopId,
    required String flagName,
    required bool newValue,
    required String label,
  }) async {
    final requiresPin = flagName == 'appLocked' || flagName == 'adminFinanceLocked';
    if (requiresPin) {
      final ok = await _requirePinReauth(title: 'Xác thực để thay đổi $label');
      if (!ok) return;
    }
    await UserService.updateShopControlFlags(shopId: shopId, flagName: flagName, flagValue: newValue);
    await SuperAdminSecurityService.logAction(
      action: 'toggle_$flagName',
      shopId: shopId,
      metadata: {'value': newValue, 'label': label},
      success: true,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(newValue ? 'Đã khóa $label' : 'Đã mở khóa $label'),
      backgroundColor: newValue ? Colors.orange : Colors.green,
    ));
  }

  Future<void> _resetShopData(Map<String, dynamic> shop) async {
    final shopId = (shop['id'] ?? '').toString();
    final shopName = (shop['name'] ?? '').toString();
    if (shopId.isEmpty) return;

    final result = await showDialog<_ResetSelection>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SelectiveResetDialog(shopName: shopName),
    );
    if (result == null) return;

    final pinOk = await _requirePinReauth(title: 'Xác thực reset shop');
    if (!pinOk) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang xóa dữ liệu...'), duration: Duration(minutes: 2)),
      );
    }

    final error = await FirestoreService.resetEntireShopData(
      shopIdOverride: shopId,
      selectedCollections: result.collections,
      selectedStorageRoots: result.storageRoots,
    );

    await SuperAdminSecurityService.logAction(
      action: 'reset_shop_data_selective',
      shopId: shopId,
      metadata: {'shopName': shopName, 'collections': result.collections, 'storageRoots': result.storageRoots, 'error': error},
      success: error == null,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error == null ? 'Đã xóa dữ liệu đã chọn của shop $shopName' : 'Reset thất bại: $error'),
      backgroundColor: error == null ? Colors.green : Colors.red,
    ));
    if (error == null) setState(() => _shopsRefreshKey++);
  }

  Future<void> _softDeleteShop(Map<String, dynamic> shop) async {
    final shopId = (shop['id'] ?? '').toString();
    final shopName = (shop['name'] ?? '').toString();
    if (shopId.isEmpty) return;

    final pinOk = await _requirePinReauth(title: 'Xác thực xóa shop');
    if (!pinOk) return;

    await _db.collection('shops').doc(shopId).set({
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await SuperAdminSecurityService.logAction(
      action: 'soft_delete_shop',
      shopId: shopId,
      metadata: {'shopName': shopName},
      success: true,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Đã soft-delete shop $shopName'),
      backgroundColor: Colors.orange,
    ));
    setState(() => _shopsRefreshKey++);
  }

  Future<void> _editUser(BuildContext context, String uid, Map<String, dynamic> data) async {
    final loc = AppLocalizations.of(context)!;
    final nameC = TextEditingController(text: (data['displayName'] ?? '').toString());
    final phoneC = TextEditingController(text: (data['phone'] ?? '').toString());
    final addressC = TextEditingController(text: (data['address'] ?? '').toString());
    final roleC = TextEditingController(text: (data['role'] ?? 'user').toString());
    final shopC = TextEditingController(text: (data['shopId'] ?? '').toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa user'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Tên')),
              TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'SĐT')),
              TextField(controller: addressC, decoration: const InputDecoration(labelText: 'Địa chỉ')),
              TextField(controller: roleC, decoration: const InputDecoration(labelText: 'Role')),
              TextField(controller: shopC, decoration: const InputDecoration(labelText: 'Shop ID')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (saved != true) return;

    await UserService.updateUserInfo(
      uid: uid,
      name: nameC.text,
      phone: phoneC.text,
      address: addressC.text,
      role: roleC.text,
      shopId: shopC.text.trim().isEmpty ? null : shopC.text.trim(),
      loc: loc,
    );

    await SuperAdminSecurityService.logAction(
      action: 'edit_user_profile',
      targetUserId: uid,
      shopId: shopC.text.trim().isEmpty ? null : shopC.text.trim(),
      metadata: {'role': roleC.text.trim()},
      success: true,
    );
  }

  Future<void> _deleteUser(String uid, String email, {required bool withData}) async {
    final pinOk = await _requirePinReauth(title: 'Xác thực xóa user');
    if (!pinOk) return;

    if (withData) {
      await UserService.deleteUserWithData(uid);
    } else {
      await UserService.deleteUser(uid);
    }

    await SuperAdminSecurityService.logAction(
      action: withData ? 'delete_user_with_data_ui' : 'delete_user_doc_ui',
      targetUserId: uid,
      metadata: {'email': email},
      success: true,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(withData ? 'Đã xóa user + dữ liệu: $email' : 'Đã xóa user doc: $email'),
    ));
    setState(() => _usersRefreshKey++);
  }

  Future<bool> _confirmExit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thoát Console?'),
        content: const Text('Bạn có chắc muốn thoát khỏi Super Admin Console?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ở lại')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.logout, color: Colors.red),
          SizedBox(width: 8),
          Text('Đăng xuất'),
        ]),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi Super Admin Console?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    SuperAdminSecurityService.clearSession();
    UserService.clearCache();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_hasAccess) {
      return const Scaffold(
        body: Center(child: Text('Bạn không có quyền truy cập Super Admin Console.')),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 980;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final exit = await _confirmExit();
        if (!exit) return;
        navigator.pop();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: SuperAdminSecurityService.touchActivity,
        onPanDown: (_) => SuperAdminSecurityService.touchActivity(),
        child: Scaffold(
          backgroundColor: const Color(0xFFF7FAFF),
          appBar: CustomAppBar.build(
            title: 'SUPER ADMIN CONSOLE',
            actions: [
              IconButton(
                onPressed: () => setState(() {
                  _shopsRefreshKey++;
                  _usersRefreshKey++;
                }),
                icon: const Icon(Icons.refresh),
                tooltip: 'Tải lại',
              ),
              IconButton(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout),
                tooltip: 'Đăng xuất',
              ),
            ],
          ),
          body: ResponsiveCenter(
            child: isDesktop
                ? Row(children: [
                    _buildSidebar(),
                    const VerticalDivider(width: 1),
                    Expanded(child: _buildContent()),
                  ])
                : _buildContent(),
          ),
          bottomNavigationBar: isDesktop
              ? null
              : BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _mobileIndexFor(_section),
                  onTap: (i) => setState(() { _section = _sectionFromMobileIndex(i); }),
                  items: const [
                    BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
                    BottomNavigationBarItem(icon: Icon(Icons.store_outlined), activeIcon: Icon(Icons.store), label: 'Shops'),
                    BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Users'),
                    BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Logs'),
                    BottomNavigationBarItem(icon: Icon(Icons.more_horiz), activeIcon: Icon(Icons.more_horiz), label: 'More'),
                  ],
                ),
        ),
      ),
    );
  }

  int _mobileIndexFor(_AdminSection section) {
    switch (section) {
      case _AdminSection.dashboard: return 0;
      case _AdminSection.shops: return 1;
      case _AdminSection.users: return 2;
      case _AdminSection.audit: return 3;
      case _AdminSection.broadcast:
      case _AdminSection.permissions:
      case _AdminSection.settings:
      case _AdminSection.danger: return 4;
    }
  }

  _AdminSection _sectionFromMobileIndex(int i) {
    if (i == 4) { _showMoreSheet(); return _section; }
    switch (i) {
      case 0: return _AdminSection.dashboard;
      case 1: return _AdminSection.shops;
      case 2: return _AdminSection.users;
      case 3: return _AdminSection.audit;
      default: return _AdminSection.dashboard;
    }
  }

  void _showMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Permissions'),
              onTap: () { Navigator.pop(ctx); setState(() => _section = _AdminSection.permissions); },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () { Navigator.pop(ctx); setState(() => _section = _AdminSection.settings); },
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
              title: const Text('Danger Zone'),
              onTap: () { Navigator.pop(ctx); setState(() => _section = _AdminSection.danger); },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(ctx); _handleLogout(); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return SizedBox(
      width: 230,
      child: ListView(
        children: [
          const SizedBox(height: 8),
          _navItem(Icons.dashboard, 'Dashboard', _AdminSection.dashboard),
          _navItem(Icons.store, 'Shops', _AdminSection.shops),
          _navItem(Icons.people, 'Users', _AdminSection.users),
          _navItem(Icons.shield, 'Permissions', _AdminSection.permissions),
          _navItem(Icons.receipt_long, 'Audit Logs', _AdminSection.audit),
          _navItem(Icons.campaign_rounded, 'Broadcast', _AdminSection.broadcast),
          _navItem(Icons.settings, 'Settings', _AdminSection.settings),
          _navItem(Icons.warning_amber_rounded, 'Danger Zone', _AdminSection.danger, danger: true),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Đăng xuất', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, _AdminSection value, {bool danger = false}) {
    final selected = _section == value;
    return ListTile(
      leading: Icon(icon, color: danger ? Colors.red : null),
      title: Text(label, style: TextStyle(
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        color: danger ? Colors.red : null,
      )),
      selected: selected,
      onTap: () => setState(() => _section = value),
    );
  }

  Widget _buildContent() {
    switch (_section) {
      case _AdminSection.dashboard:
        return _DashboardSection(db: _db);
      case _AdminSection.shops:
        return _ShopsSection(
          key: ValueKey(_shopsRefreshKey),
          db: _db,
          onEnterShop: _enterShop,
          onToggleLock: _toggleShopLock,
          onResetShop: _resetShopData,
        );
      case _AdminSection.users:
        return _UsersSection(
          key: ValueKey(_usersRefreshKey),
          onEdit: _editUser,
          onDelete: _deleteUser,
        );
      case _AdminSection.permissions:
        return const _PermissionsSection();
      case _AdminSection.audit:
        return _AuditSection(
          db: _db,
          shopFilter: _auditShopFilter,
          actionFilter: _auditActionFilter,
          textFilter: _auditTextFilter,
          onFilterChanged: (shop, action, text) {
            setState(() {
              _auditShopFilter = shop;
              _auditActionFilter = action;
              _auditTextFilter = text;
            });
          },
        );
      case _AdminSection.broadcast:
        return const _BroadcastSection();
      case _AdminSection.settings:
        return const _SettingsSection();
      case _AdminSection.danger:
        return _DangerSection(db: _db, onResetShop: _resetShopData, onDeleteShop: _softDeleteShop);
    }
  }
}

// ─── Dashboard ───────────────────────────────────────────────────────────────

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({required this.db});
  final FirebaseFirestore db;

  Future<Map<String, int>> _loadStats() async {
    final allShopsSnap = await db.collection('shops').get();
    final allShops = allShopsSnap.docs.where((d) => d.data()['deleted'] != true).toList();
    final locked = allShops.where((d) => d.data()['appLocked'] == true).length;
    final users = await db.collection('users').get();
    return {
      'shops': allShops.length,
      'users': users.size,
      'locked': locked,
      'active': allShops.length - locked,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _loadStats(),
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final stats = snap.data ?? {'shops': 0, 'users': 0, 'locked': 0, 'active': 0};
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 2×2 grid using Rows to avoid overflow
            Row(children: [
              Expanded(child: _statCard('Tổng shop', loading ? '—' : '${stats['shops']}', Icons.store_outlined, Colors.blue)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('Hoạt động', loading ? '—' : '${stats['active']}', Icons.check_circle_outline, Colors.green)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _statCard('Tổng user', loading ? '—' : '${stats['users']}', Icons.people_outline, Colors.indigo)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('Shop bị khóa', loading ? '—' : '${stats['locked']}', Icons.lock_outline, Colors.orange)),
            ]),
            const SizedBox(height: 12),
            if (!loading && (stats['locked'] ?? 0) > 0)
              Card(
                color: Colors.orange.shade50,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  title: Text('${stats['locked']} shop đang bị khóa app'),
                  subtitle: const Text('Vào tab Shops để mở khóa.'),
                ),
              ),
            if (!loading && (stats['locked'] ?? 0) == 0)
              Card(
                color: Colors.green.shade50,
                child: const ListTile(
                  dense: true,
                  leading: Icon(Icons.check_circle_outline, color: Colors.green),
                  title: Text('Hệ thống hoạt động bình thường'),
                  subtitle: Text('Không có shop nào đang bị khóa.'),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ─── Shops ───────────────────────────────────────────────────────────────────

class _ShopsSection extends StatefulWidget {
  const _ShopsSection({
    super.key,
    required this.db,
    required this.onEnterShop,
    required this.onToggleLock,
    required this.onResetShop,
  });

  final FirebaseFirestore db;
  final Future<void> Function(Map<String, dynamic>) onEnterShop;
  final Future<void> Function({
    required String shopId,
    required String flagName,
    required bool newValue,
    required String label,
  }) onToggleLock;
  final Future<void> Function(Map<String, dynamic>) onResetShop;

  @override
  State<_ShopsSection> createState() => _ShopsSectionState();
}

class _ShopsSectionState extends State<_ShopsSection> {
  static const int _pageSize = 20;

  final _searchC = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _shops = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      Query<Map<String, dynamic>> q = widget.db
          .collection('shops')
          .orderBy('name')
          .limit(_pageSize);
      if (!reset && _lastDoc != null) q = q.startAfterDocument(_lastDoc!);

      final snap = await q.get();
      final newDocs = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return data;
      }).toList();

      setState(() {
        if (reset) _shops.clear();
        _shops.addAll(newDocs);
        if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;
        _hasMore = snap.docs.length >= _pageSize;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _shops;
    final q = _searchQuery.toLowerCase();
    return _shops.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final email = (s['ownerEmail'] ?? '').toString().toLowerCase();
      final id = (s['id'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || id.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final shops = _filtered;
    final showLoadMore = _hasMore && _searchQuery.isEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _searchC,
            decoration: InputDecoration(
              hintText: 'Tìm shop theo tên, email, ID...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () { _searchC.clear(); setState(() => _searchQuery = ''); },
                      icon: const Icon(Icons.clear, size: 18),
                    )
                  : null,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              Text(
                '${shops.length}${showLoadMore ? '+' : ''} shop',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Spacer(),
              if (_loading)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
        Expanded(
          child: shops.isEmpty && !_loading
              ? const Center(child: Text('Không có shop phù hợp'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: shops.length + (showLoadMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    if (i == shops.length) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: _loading
                              ? const CircularProgressIndicator()
                              : OutlinedButton.icon(
                                  onPressed: _loadPage,
                                  icon: const Icon(Icons.expand_more, size: 18),
                                  label: const Text('Tải thêm'),
                                ),
                        ),
                      );
                    }
                    return _buildShopTile(context, shops[i]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildShopTile(BuildContext context, Map<String, dynamic> s) {
    final appLocked = s['appLocked'] == true;
    final deleted = s['deleted'] == true;
    final shopId = (s['id'] ?? '').toString();
    final name = (s['name'] ?? 'Shop').toString();
    final owner = (s['ownerEmail'] ?? 'N/A').toString();

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: deleted ? Colors.grey.shade200 : appLocked ? Colors.red.shade50 : Colors.green.shade50,
          child: Icon(
            deleted ? Icons.delete_outline : appLocked ? Icons.lock_outline : Icons.store_outlined,
            size: 18,
            color: deleted ? Colors.grey : appLocked ? Colors.red : Colors.green,
          ),
        ),
        title: Row(children: [
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: deleted ? Colors.grey.shade100 : appLocked ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: deleted ? Colors.grey.shade300 : appLocked ? Colors.red.shade200 : Colors.green.shade200),
            ),
            child: Text(
              deleted ? 'DELETED' : appLocked ? 'LOCKED' : 'ACTIVE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: deleted ? Colors.grey : appLocked ? Colors.red : Colors.green.shade700,
              ),
            ),
          ),
        ]),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(owner, style: const TextStyle(fontSize: 12)),
            Text(shopId, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (v) {
            switch (v) {
              case 'view': _showShopDetail(context, s);
              case 'enter': widget.onEnterShop(s);
              case 'lock':
                widget.onToggleLock(shopId: shopId, flagName: 'appLocked', newValue: !appLocked, label: 'Toàn bộ app');
              case 'reset': widget.onResetShop(s);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'view', child: ListTile(dense: true, leading: Icon(Icons.visibility_outlined), title: Text('Xem chi tiết'))),
            const PopupMenuItem(value: 'enter', child: ListTile(dense: true, leading: Icon(Icons.login, color: Colors.blue), title: Text('Vào shop'))),
            PopupMenuItem(
              value: 'lock',
              child: ListTile(
                dense: true,
                leading: Icon(appLocked ? Icons.lock_open_outlined : Icons.lock_outline, color: Colors.orange),
                title: Text(appLocked ? 'Mở khóa app' : 'Khóa app'),
              ),
            ),
            const PopupMenuItem(value: 'reset', child: ListTile(
              dense: true,
              leading: Icon(Icons.restart_alt, color: Colors.red),
              title: Text('Reset dữ liệu', style: TextStyle(color: Colors.red)),
            )),
          ],
        ),
      ),
    );
  }

  void _showShopDetail(BuildContext context, Map<String, dynamic> shop) {
    showDialog<void>(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 4,
        child: AlertDialog(
          title: Text('Shop: ${shop['name'] ?? ''}'),
          content: SizedBox(
            width: 760,
            height: 520,
            child: Column(
              children: [
                const TabBar(tabs: [
                  Tab(text: 'Overview'), Tab(text: 'Users'), Tab(text: 'Locks'), Tab(text: 'Activity'),
                ]),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(children: [
                    ListView(children: [
                      ListTile(title: const Text('Shop ID'), subtitle: Text((shop['id'] ?? '').toString())),
                      ListTile(title: const Text('Owner'), subtitle: Text((shop['ownerEmail'] ?? 'N/A').toString())),
                      ListTile(title: const Text('Business Type'), subtitle: Text((shop['businessType'] ?? 'N/A').toString())),
                    ]),
                    _ShopUsersTab(shopId: (shop['id'] ?? '').toString()),
                    ListView(children: [
                      SwitchListTile(value: shop['adminFinanceLocked'] == true, onChanged: null, title: const Text('Khóa tài chính quản lý')),
                      SwitchListTile(value: shop['staffInventoryLocked'] == true, onChanged: null, title: const Text('Khóa kho cho nhân viên')),
                      SwitchListTile(value: shop['staffSalesLocked'] == true, onChanged: null, title: const Text('Khóa bán hàng cho nhân viên')),
                      SwitchListTile(value: shop['staffDebtLocked'] == true, onChanged: null, title: const Text('Khóa công nợ cho nhân viên')),
                    ]),
                    _ShopActivityTab(shopId: (shop['id'] ?? '').toString()),
                  ]),
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
        ),
      ),
    );
  }
}

class _ShopUsersTab extends StatelessWidget {
  const _ShopUsersTab({required this.shopId});
  final String shopId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').where('shopId', isEqualTo: shopId).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        if (snap.data!.docs.isEmpty) return const Center(child: Text('Không có user trong shop'));
        return ListView(
          children: snap.data!.docs.map((d) {
            final u = d.data();
            return ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text((u['displayName'] ?? u['email'] ?? '').toString()),
              subtitle: Text('Role: ${(u['role'] ?? 'user')}'),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ShopActivityTab extends StatelessWidget {
  const _ShopActivityTab({required this.shopId});
  final String shopId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('admin_audit_log')
          .where('shopId', isEqualTo: shopId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        if (snap.data!.docs.isEmpty) return const Center(child: Text('Chưa có activity'));
        return ListView(
          children: snap.data!.docs.map((d) {
            final a = d.data();
            return ListTile(
              title: Text((a['action'] ?? '').toString()),
              subtitle: Text((a['email'] ?? '').toString()),
              trailing: Text(_fmtTs(a['timestamp'])),
            );
          }).toList(),
        );
      },
    );
  }

  String _fmtTs(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final dt = ts.toDate();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Users ───────────────────────────────────────────────────────────────────

class _UsersSection extends StatefulWidget {
  const _UsersSection({super.key, required this.onEdit, required this.onDelete});

  final Future<void> Function(BuildContext, String, Map<String, dynamic>) onEdit;
  final Future<void> Function(String uid, String email, {required bool withData}) onDelete;

  @override
  State<_UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<_UsersSection> {
  static const int _pageSize = 20;

  final _searchC = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _users = [];
  final List<String> _uids = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance
          .collection('users')
          .orderBy('email')
          .limit(_pageSize);
      if (!reset && _lastDoc != null) q = q.startAfterDocument(_lastDoc!);

      final snap = await q.get();
      setState(() {
        if (reset) { _users.clear(); _uids.clear(); }
        for (final d in snap.docs) {
          _users.add(Map<String, dynamic>.from(d.data()));
          _uids.add(d.id);
        }
        if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;
        _hasMore = snap.docs.length >= _pageSize;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<(String, Map<String, dynamic>)> get _filtered {
    final pairs = List.generate(_users.length, (i) => (_uids[i], _users[i]));
    if (_searchQuery.isEmpty) return pairs;
    final q = _searchQuery.toLowerCase();
    return pairs.where((p) {
      final u = p.$2;
      final name = (u['displayName'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final role = (u['role'] ?? '').toString().toLowerCase();
      final shopId = (u['shopId'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || role.contains(q) || shopId.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final users = _filtered;
    final showLoadMore = _hasMore && _searchQuery.isEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _searchC,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, email, role, shop ID...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () { _searchC.clear(); setState(() => _searchQuery = ''); },
                      icon: const Icon(Icons.clear, size: 18),
                    )
                  : null,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              Text(
                '${users.length}${showLoadMore ? '+' : ''} user',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Spacer(),
              if (_loading)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
        Expanded(
          child: users.isEmpty && !_loading
              ? const Center(child: Text('Không có user phù hợp'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: users.length + (showLoadMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    if (i == users.length) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: _loading
                              ? const CircularProgressIndicator()
                              : OutlinedButton.icon(
                                  onPressed: _loadPage,
                                  icon: const Icon(Icons.expand_more, size: 18),
                                  label: const Text('Tải thêm'),
                                ),
                        ),
                      );
                    }
                    final (uid, u) = users[i];
                    final email = (u['email'] ?? '').toString();
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.indigo.shade50,
                          child: const Icon(Icons.person_outline, size: 18, color: Colors.indigo),
                        ),
                        title: Text((u['displayName'] ?? email).toString(), style: const TextStyle(fontSize: 14)),
                        subtitle: Text(
                          'Role: ${u['role'] ?? 'user'} · Shop: ${u['shopId'] ?? 'N/A'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => widget.onEdit(context, uid, u),
                              icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 20),
                              onSelected: (v) {
                                if (v == 'del') widget.onDelete(uid, email, withData: false);
                                if (v == 'del_all') widget.onDelete(uid, email, withData: true);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'del', child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.delete_outline, color: Colors.red),
                                  title: Text('Xóa user doc'),
                                )),
                                const PopupMenuItem(value: 'del_all', child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.delete_forever, color: Colors.red),
                                  title: Text('Xóa user + dữ liệu', style: TextStyle(color: Colors.red)),
                                )),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Permissions ─────────────────────────────────────────────────────────────

class _PermissionsSection extends StatelessWidget {
  const _PermissionsSection();

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['owner', '✓', '✓', '✓', '✓'],
      ['manager', '✓', '✓', '✗', '✗'],
      ['staff', '✓', '✗', '✗', '✗'],
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Permission Panel'),
            subtitle: Text('Chuẩn role-based baseline cho owner/manager/staff. Các khóa cấp shop sẽ override tại runtime.'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Sửa đơn')),
                DataColumn(label: Text('Xem tài chính')),
                DataColumn(label: Text('Đổi lock flags')),
                DataColumn(label: Text('Danger actions')),
              ],
              rows: rows.map((r) => DataRow(cells: [
                DataCell(Text(r[0])), DataCell(Text(r[1])), DataCell(Text(r[2])),
                DataCell(Text(r[3])), DataCell(Text(r[4])),
              ])).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Audit ───────────────────────────────────────────────────────────────────

class _AuditSection extends StatelessWidget {
  const _AuditSection({
    required this.db,
    required this.shopFilter,
    required this.actionFilter,
    required this.textFilter,
    required this.onFilterChanged,
  });

  final FirebaseFirestore db;
  final String? shopFilter;
  final String actionFilter;
  final String textFilter;
  final void Function(String? shop, String action, String text) onFilterChanged;

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query =
        db.collection('admin_audit_log').orderBy('timestamp', descending: true).limit(200);
    if (shopFilter != null && shopFilter!.isNotEmpty) query = query.where('shopId', isEqualTo: shopFilter);
    if (actionFilter != 'all') query = query.where('action', isEqualTo: actionFilter);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Filter shopId', isDense: true),
                  onChanged: (v) => onFilterChanged(v.trim().isEmpty ? null : v.trim(), actionFilter, textFilter),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Filter action', isDense: true),
                  onChanged: (v) => onFilterChanged(shopFilter, v.trim().isEmpty ? 'all' : v.trim(), textFilter),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Search email/user', isDense: true),
                  onChanged: (v) => onFilterChanged(shopFilter, actionFilter, v.trim()),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs.where((d) {
                if (textFilter.isEmpty) return true;
                final data = d.data();
                final email = (data['email'] ?? '').toString().toLowerCase();
                final target = (data['targetUserId'] ?? '').toString().toLowerCase();
                final q = textFilter.toLowerCase();
                return email.contains(q) || target.contains(q);
              }).toList();
              if (docs.isEmpty) return const Center(child: Text('Không có audit logs phù hợp.'));
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final a = docs[i].data();
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.receipt_long, size: 18),
                    title: Text((a['action'] ?? '').toString()),
                    subtitle: Text('User: ${(a['email'] ?? '')} · Shop: ${(a['shopId'] ?? '-')}'),
                    trailing: Text(_fmtTs(a['timestamp'])),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _fmtTs(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final dt = ts.toDate();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Settings ────────────────────────────────────────────────────────────────

class _SettingsSection extends StatefulWidget {
  const _SettingsSection();

  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection> {
  bool? _hasPinSetup;

  @override
  void initState() {
    super.initState();
    _reloadPinStatus();
  }

  Future<void> _reloadPinStatus() async {
    final has = await SuperAdminSecurityService.isPinSetup();
    if (mounted) setState(() => _hasPinSetup = has);
  }

  void _showSetupPinDialog({bool isChange = false}) {
    final pinC = TextEditingController();
    final confirmC = TextEditingController();
    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.lock, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text(isChange ? 'Đổi mã PIN' : 'Thiết lập mã PIN'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: pinC, keyboardType: TextInputType.number, obscureText: true, maxLength: 6, autofocus: true,
                  decoration: const InputDecoration(labelText: 'Mã PIN mới (4-6 số)', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: confirmC, keyboardType: TextInputType.number, obscureText: true, maxLength: 6,
                  decoration: const InputDecoration(labelText: 'Nhập lại PIN', border: OutlineInputBorder())),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              onPressed: () async {
                if (pinC.text.length < 4) { setD(() => error = 'PIN phải từ 4-6 số'); return; }
                if (pinC.text != confirmC.text) { setD(() => error = 'Hai mã PIN không khớp'); return; }
                final ok = await SuperAdminSecurityService.setupPin(pinC.text);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (ok) _reloadPinStatus();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok ? 'Đã thiết lập mã PIN thành công.' : 'Lỗi thiết lập PIN.'),
                    backgroundColor: ok ? Colors.green : Colors.red,
                  ));
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemovePinDialog() {
    final pinC = TextEditingController();
    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.lock_open, color: Colors.orange), SizedBox(width: 8), Text('Tắt mã PIN'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nhập PIN hiện tại để xác nhận tắt:'),
              const SizedBox(height: 10),
              TextField(controller: pinC, keyboardType: TextInputType.number, obscureText: true, maxLength: 6, autofocus: true,
                  decoration: InputDecoration(labelText: 'Mã PIN hiện tại', border: const OutlineInputBorder(), errorText: error)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                final verified = await SuperAdminSecurityService.verifyPin(pinC.text);
                if (!verified) { setD(() => error = 'Mã PIN không đúng'); return; }
                await SuperAdminSecurityService.removePin();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _reloadPinStatus();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã tắt mã PIN.'), backgroundColor: Colors.orange),
                  );
                }
              },
              child: const Text('Tắt PIN'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPin = _hasPinSetup;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.deepPurple.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.shield_outlined, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text('Bảo mật PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ]),
                const SizedBox(height: 4),
                Text('Bảo vệ Console bằng mã PIN khi session hết hạn', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const Divider(height: 16),
                if (hasPin == null)
                  const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
                else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(hasPin ? Icons.lock_outline : Icons.lock_open_outlined, color: hasPin ? Colors.green : Colors.orange),
                    title: Text(hasPin ? 'Mã PIN đã bật' : 'Chưa thiết lập PIN',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      hasPin ? 'Yêu cầu PIN khi session hết hạn (30 phút idle)' : 'Bật PIN để bảo vệ console',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: hasPin
                        ? PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'change') _showSetupPinDialog(isChange: true);
                              if (v == 'remove') _showRemovePinDialog();
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'change', child: Text('Đổi PIN')),
                              PopupMenuItem(value: 'remove', child: Text('Tắt PIN')),
                            ],
                          )
                        : FilledButton.icon(
                            onPressed: () => _showSetupPinDialog(),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Thiết lập'),
                          ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_sync),
            title: const Text('Sync custom claims'),
            subtitle: const Text('Đồng bộ claims cho toàn bộ user khi thay đổi rules/roles.'),
            onTap: () async {
              final result = await ClaimsService().batchSyncAllClaims();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result['success'] == true
                    ? 'Sync claims thành công.'
                    : 'Sync claims lỗi: ${result['error'] ?? 'unknown'}')),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Broadcast ───────────────────────────────────────────────────────────────

class _BroadcastSection extends StatefulWidget {
  const _BroadcastSection();
  @override
  State<_BroadcastSection> createState() => _BroadcastSectionState();
}

class _BroadcastSectionState extends State<_BroadcastSection> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _type = 'info';
  bool _sending = false;
  String? _lastResult;
  bool _lastSuccess = false;

  static const _types = [
    ('info', '📢 Thông tin', Colors.indigo),
    ('warning', '⚠️ Cảnh báo', Colors.orange),
    ('update_required', '🔴 Yêu cầu cập nhật', Colors.red),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() { _lastResult = 'Vui lòng nhập tiêu đề và nội dung.'; _lastSuccess = false; });
      return;
    }
    setState(() { _sending = true; _lastResult = null; });
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('sendBroadcastNotification');
      await callable.call({'title': title, 'body': body, 'type': _type});
      setState(() {
        _lastResult = '✅ Đã gửi thành công tới toàn bộ người dùng!';
        _lastSuccess = true;
        _titleCtrl.clear();
        _bodyCtrl.clear();
      });
    } catch (e) {
      setState(() { _lastResult = '❌ Lỗi: ${e.toString()}'; _lastSuccess = false; });
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _deleteBroadcast(String docId) async {
    await FirebaseFirestore.instance.collection('broadcasts').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Form panel
          Expanded(
            flex: 2,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.campaign_rounded, color: Colors.indigo, size: 28),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Gửi Thông Báo Hệ Thống', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Thông báo sẽ được gửi tới TẤT CẢ người dùng qua dialog + push notification.',
                              style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    // Type selector
                    const Text('Loại thông báo', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _types.map((t) {
                        final selected = _type == t.$1;
                        return ChoiceChip(
                          label: Text(t.$2),
                          selected: selected,
                          selectedColor: t.$3.withValues(alpha: 0.2),
                          onSelected: (_) => setState(() => _type = t.$1),
                          labelStyle: TextStyle(
                            color: selected ? t.$3 : null,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Tiêu đề',
                        hintText: 'VD: Yêu cầu cập nhật phiên bản mới',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.title_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _bodyCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Nội dung',
                        hintText: 'Nhập nội dung thông báo chi tiết...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.message_rounded),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_lastResult != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: _lastSuccess ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _lastSuccess ? Colors.green.shade200 : Colors.red.shade200),
                        ),
                        child: Text(_lastResult!, style: TextStyle(color: _lastSuccess ? Colors.green.shade800 : Colors.red.shade800)),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded),
                        label: Text(_sending ? 'Đang gửi...' : 'Gửi tới toàn bộ người dùng'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // History panel
          Expanded(
            flex: 1,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lịch sử thông báo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('broadcasts')
                          .orderBy('createdAt', descending: true)
                          .limit(20)
                          .snapshots(),
                      builder: (ctx, snap) {
                        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                        final docs = snap.data!.docs;
                        if (docs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Chưa có thông báo nào.', style: TextStyle(color: Colors.grey)),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final d = docs[i].data() as Map<String, dynamic>;
                            final type = d['type'] ?? 'info';
                            final color = type == 'update_required' ? Colors.red
                                : type == 'warning' ? Colors.orange : Colors.indigo;
                            final ts = (d['createdAt'] as Timestamp?)?.toDate();
                            final expiresAt = (d['expiresAt'] as Timestamp?)?.toDate();
                            final expired = expiresAt != null && expiresAt.isBefore(DateTime.now());
                            return ListTile(
                              dense: true,
                              leading: Icon(Icons.campaign_rounded, color: color, size: 20),
                              title: Text(d['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w600, color: expired ? Colors.grey : null)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d['body'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12)),
                                  if (ts != null) Text(
                                    '${ts.day}/${ts.month}/${ts.year} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}${expired ? ' · Hết hạn' : ''}',
                                    style: TextStyle(fontSize: 11, color: expired ? Colors.red.shade300 : Colors.grey),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                tooltip: 'Xóa',
                                onPressed: () => _deleteBroadcast(docs[i].id),
                              ),
                            );
                          },
                        );
                      },
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
}

// ─── Danger Zone ─────────────────────────────────────────────────────────────

class _DangerSection extends StatelessWidget {
  const _DangerSection({required this.db, required this.onResetShop, required this.onDeleteShop});

  final FirebaseFirestore db;
  final Future<void> Function(Map<String, dynamic>) onResetShop;
  final Future<void> Function(Map<String, dynamic>) onDeleteShop;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('shops').orderBy('name').snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final shops = snap.data!.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] = d.id;
          return data;
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              color: Color(0xFFFFF3F3),
              child: ListTile(
                leading: Icon(Icons.warning_amber_rounded, color: Colors.red),
                title: Text('Danger Zone'),
                subtitle: Text('Mọi thao tác tại đây đều yêu cầu xác thực PIN và được ghi audit log.'),
              ),
            ),
            const SizedBox(height: 12),
            ...shops.map((s) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text((s['name'] ?? 'Shop').toString()),
                subtitle: Text('ID: ${(s['id'] ?? '').toString()}'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => onResetShop(s),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => onDeleteShop(s),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            )),
          ],
        );
      },
    );
  }
}

// ─── Selective Reset ─────────────────────────────────────────────────────────

class _ResetSelection {
  final List<String> collections;
  final List<String> storageRoots;
  const _ResetSelection({required this.collections, required this.storageRoots});
}

class _CollectionGroup {
  final String label;
  final IconData icon;
  final Color color;
  final List<_CollectionItem> items;
  const _CollectionGroup({required this.label, required this.icon, required this.color, required this.items});
}

class _CollectionItem {
  final String key;
  final String label;
  final bool isStorage;
  const _CollectionItem(this.key, this.label, {this.isStorage = false});
}

const _kGroups = [
  _CollectionGroup(
    label: 'Vận hành',
    icon: Icons.build_outlined,
    color: Colors.blue,
    items: [
      _CollectionItem('repairs', 'Đơn sửa chữa'),
      _CollectionItem('sales', 'Đơn bán hàng'),
      _CollectionItem('inventory_checks', 'Kiểm kê kho'),
      _CollectionItem('cash_closings', 'Chốt ca'),
    ],
  ),
  _CollectionGroup(
    label: 'Kho & Sản phẩm',
    icon: Icons.inventory_2_outlined,
    color: Colors.teal,
    items: [
      _CollectionItem('products', 'Sản phẩm / Kho'),
      _CollectionItem('suppliers', 'Nhà cung cấp'),
      _CollectionItem('purchase_orders', 'Đơn nhập hàng'),
      _CollectionItem('quick_input_codes', 'Mã nhập nhanh'),
    ],
  ),
  _CollectionGroup(
    label: 'Tài chính',
    icon: Icons.account_balance_wallet_outlined,
    color: Colors.green,
    items: [
      _CollectionItem('debts', 'Công nợ'),
      _CollectionItem('debt_payments', 'Thanh toán nợ'),
      _CollectionItem('expenses', 'Chi phí'),
    ],
  ),
  _CollectionGroup(
    label: 'Nhân sự',
    icon: Icons.people_outline,
    color: Colors.purple,
    items: [
      _CollectionItem('attendance', 'Chấm công'),
      _CollectionItem('payroll_settings', 'Cài đặt lương'),
      _CollectionItem('work_schedules', 'Lịch làm việc'),
    ],
  ),
  _CollectionGroup(
    label: 'Quan hệ khách hàng',
    icon: Icons.person_outline,
    color: Colors.orange,
    items: [
      _CollectionItem('customers', 'Khách hàng'),
      _CollectionItem('chats', 'Tin nhắn chat'),
    ],
  ),
  _CollectionGroup(
    label: 'Hệ thống',
    icon: Icons.settings_outlined,
    color: Colors.grey,
    items: [
      _CollectionItem('audit_logs', 'Nhật ký thao tác'),
    ],
  ),
  _CollectionGroup(
    label: 'File & Ảnh (Storage)',
    icon: Icons.cloud_outlined,
    color: Colors.indigo,
    items: [
      _CollectionItem('repairs', 'Ảnh đơn sửa chữa', isStorage: true),
      _CollectionItem('products', 'Ảnh sản phẩm', isStorage: true),
      _CollectionItem('attendance', 'Ảnh chấm công', isStorage: true),
      _CollectionItem('chat_images', 'Ảnh tin nhắn', isStorage: true),
      _CollectionItem('payment_requests', 'Ảnh thanh toán', isStorage: true),
      _CollectionItem('db_backups', 'File backup DB', isStorage: true),
      _CollectionItem('shop_logos', 'Logo shop', isStorage: true),
    ],
  ),
];

class _SelectiveResetDialog extends StatefulWidget {
  const _SelectiveResetDialog({required this.shopName});
  final String shopName;

  @override
  State<_SelectiveResetDialog> createState() => _SelectiveResetDialogState();
}

class _SelectiveResetDialogState extends State<_SelectiveResetDialog> {
  final Map<String, bool> _checked = {};

  @override
  void initState() {
    super.initState();
    for (final g in _kGroups) {
      for (final item in g.items) {
        _checked[_itemKey(item)] = false;
      }
    }
  }

  String _itemKey(_CollectionItem item) => item.isStorage ? 'storage:${item.key}' : 'col:${item.key}';
  bool get _anyChecked => _checked.values.any((v) => v);
  bool get _allChecked => _checked.values.every((v) => v);
  bool _groupAllChecked(_CollectionGroup g) => g.items.every((item) => _checked[_itemKey(item)] == true);
  bool _groupAnyChecked(_CollectionGroup g) => g.items.any((item) => _checked[_itemKey(item)] == true);

  void _toggleGroup(_CollectionGroup g, bool value) {
    setState(() { for (final item in g.items) { _checked[_itemKey(item)] = value; } });
  }

  void _toggleAll(bool value) {
    setState(() { for (final key in _checked.keys) { _checked[key] = value; } });
  }

  _ResetSelection _buildResult() {
    final cols = <String>[];
    final roots = <String>[];
    _checked.forEach((key, checked) {
      if (!checked) return;
      if (key.startsWith('col:')) {
        cols.add(key.substring(4));
      } else if (key.startsWith('storage:')) {
        roots.add(key.substring(8));
      }
    });
    return _ResetSelection(collections: cols, storageRoots: roots);
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _checked.values.where((v) => v).length;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.delete_sweep_outlined, color: Colors.red),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chọn dữ liệu cần xóa', style: TextStyle(fontSize: 16)),
              Text(widget.shopName, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.normal)),
            ],
          ),
        ),
      ]),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 480,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: CheckboxListTile(
                dense: true,
                value: _allChecked ? true : (_anyChecked ? null : false),
                tristate: true,
                activeColor: Colors.red,
                title: const Text('Chọn tất cả', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('$selectedCount mục đã chọn'),
                onChanged: (v) => _toggleAll(v == true),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: _kGroups.map(_buildGroup).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton.icon(
          onPressed: _anyChecked ? () => Navigator.pop(context, _buildResult()) : null,
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          icon: const Icon(Icons.delete_outline, size: 16),
          label: Text('Xóa ($selectedCount mục)'),
        ),
      ],
    );
  }

  Widget _buildGroup(_CollectionGroup g) {
    final allChecked = _groupAllChecked(g);
    final anyChecked = _groupAnyChecked(g);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: g.color.withValues(alpha: 0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(g.icon, color: g.color, size: 20),
          title: Text(g.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (anyChecked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '${g.items.where((i) => _checked[_itemKey(i)] == true).length}/${g.items.length}',
                    style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(width: 4),
              Checkbox(
                value: allChecked ? true : (anyChecked ? null : false),
                tristate: true,
                activeColor: g.color,
                onChanged: (v) => _toggleGroup(g, v == true),
              ),
            ],
          ),
          children: g.items.map((item) => CheckboxListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            value: _checked[_itemKey(item)] ?? false,
            activeColor: g.color,
            title: Text(item.label, style: const TextStyle(fontSize: 13)),
            secondary: item.isStorage
                ? const Icon(Icons.cloud_outlined, size: 16, color: Colors.indigo)
                : const Icon(Icons.storage_outlined, size: 16, color: Colors.grey),
            onChanged: (v) => setState(() => _checked[_itemKey(item)] = v ?? false),
          )).toList(),
        ),
      ),
    );
  }
}
