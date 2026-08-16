import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/claims_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/super_admin_security_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
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
  otherApps,
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
      final claims = await ClaimsService().getClaimsFromToken(
        forceRefresh: true,
      );
      final ok =
          claims?['isSuperAdmin'] == true || claims?['role'] == 'super_admin';
      UserService.setCurrentUserSuperAdmin(ok);
      if (!mounted) return;
      if (ok) {
        SuperAdminSecurityService.touchActivity();
        setState(() {
          _hasAccess = true;
          _checkingAccess = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final hasPinSetup = await SuperAdminSecurityService.isPinSetup();
          if (!mounted) return;
          if (hasPinSetup && !SuperAdminSecurityService.isSessionValid()) {
            final loc = AppLocalizations.of(context)!;
            final pinOk = await _requirePinReauth(
              title: loc.adminAuthSuperAdmin,
            );
            if (!pinOk) {
              SuperAdminSecurityService.clearSession();
              UserService.clearCache();
              await FirebaseAuth.instance.signOut();
            }
          }
        });
      } else {
        setState(() {
          _hasAccess = false;
          _checkingAccess = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasAccess = false;
        _checkingAccess = false;
      });
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

  Future<bool> _requirePinReauth({String? title}) async {
    if (!mounted) return false;
    final loc = AppLocalizations.of(context)!;
    final pinC = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.lock, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Text(title ?? loc.adminAuthPin),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.adminEnterPinForDangerous),
              const SizedBox(height: 12),
              TextField(
                controller: pinC,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: loc.adminPinHint,
                  border: const OutlineInputBorder(),
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final verified = await SuperAdminSecurityService.verifyPin(
                  pinC.text.trim(),
                );
                if (!verified) {
                  setD(() => error = loc.adminPinWrong);
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: Text(loc.confirm),
            ),
          ],
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _enterShop(Map<String, dynamic> shop) async {
    if (!mounted) return;
    final shopId = (shop['id'] ?? '').toString();
    if (shopId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopSelectorView(
          setLocale: null,
          autoSelectShopId: shopId,
          autoSelectShopName: (shop['name'] ?? '').toString(),
        ),
      ),
    );
  }

  Future<void> _toggleShopLock({
    required String shopId,
    required String flagName,
    required bool newValue,
    required String label,
  }) async {
    final requiresPin =
        flagName == 'appLocked' || flagName == 'adminFinanceLocked';
    if (requiresPin) {
      final ok = await _requirePinReauth(
        title: 'Xác thực để thay đổi $label',
      ); // label is dynamic
      if (!ok) return;
    }
    await UserService.updateShopControlFlags(
      shopId: shopId,
      flagName: flagName,
      flagValue: newValue,
    );
    await SuperAdminSecurityService.logAction(
      action: 'toggle_$flagName',
      shopId: shopId,
      metadata: {'value': newValue, 'label': label},
      success: true,
    );
    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newValue
              ? loc.adminLockedLabel(label)
              : loc.adminUnlockedLabel(label),
        ),
        backgroundColor: newValue ? Colors.orange : Colors.green,
      ),
    );
  }

  Future<void> _resetShopData(Map<String, dynamic> shop) async {
    final shopId = (shop['id'] ?? '').toString();
    final shopName = (shop['name'] ?? '').toString();
    if (shopId.isEmpty) return;

    final loc = AppLocalizations.of(context)!;

    final result = await showDialog<_ResetSelection>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SelectiveResetDialog(shopName: shopName),
    );
    if (result == null) return;

    final pinOk = await _requirePinReauth(title: loc.adminAuthPin);
    if (!pinOk) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.adminDeletingData),
          duration: const Duration(minutes: 2),
        ),
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
      metadata: {
        'shopName': shopName,
        'collections': result.collections,
        'storageRoots': result.storageRoots,
        'error': error,
      },
      success: error == null,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    final resetMsg = error == null
        ? loc.adminResetSuccess(shopName)
        : loc.adminResetFailed(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(resetMsg),
        backgroundColor: error == null ? Colors.green : Colors.red,
      ),
    );
    if (error == null) setState(() => _shopsRefreshKey++);
  }

  Future<void> _softDeleteShop(Map<String, dynamic> shop) async {
    final shopId = (shop['id'] ?? '').toString();
    final shopName = (shop['name'] ?? '').toString();
    if (shopId.isEmpty) return;

    final loc = AppLocalizations.of(context)!;
    final pinOk = await _requirePinReauth(title: loc.adminAuthPin);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã soft-delete shop $shopName'),
        backgroundColor: Colors.orange,
      ),
    );
    setState(() => _shopsRefreshKey++);
  }

  Future<void> _editUser(
    BuildContext context,
    String uid,
    Map<String, dynamic> data,
  ) async {
    final loc = AppLocalizations.of(context)!;
    final nameC = TextEditingController(
      text: (data['displayName'] ?? '').toString(),
    );
    final phoneC = TextEditingController(
      text: (data['phone'] ?? '').toString(),
    );
    final addressC = TextEditingController(
      text: (data['address'] ?? '').toString(),
    );
    final roleC = TextEditingController(
      text: (data['role'] ?? 'user').toString(),
    );
    final shopC = TextEditingController(
      text: (data['shopId'] ?? '').toString(),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa user'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                decoration: const InputDecoration(labelText: 'Tên'),
              ),
              TextField(
                controller: phoneC,
                decoration: const InputDecoration(labelText: 'SĐT'),
              ),
              TextField(
                controller: addressC,
                decoration: const InputDecoration(labelText: 'Địa chỉ'),
              ),
              TextField(
                controller: roleC,
                decoration: const InputDecoration(labelText: 'Vai trò'),
              ),
              TextField(
                controller: shopC,
                decoration: const InputDecoration(labelText: 'Mã cửa hàng'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lưu'),
          ),
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

  Future<void> _deleteUser(
    String uid,
    String email, {
    required bool withData,
    String? role,
    String? shopName,
  }) async {
    final isOwner = role == 'owner';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                withData ? 'Xóa user + dữ liệu' : 'Xóa user doc',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isOwner)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Đây là CHỦ SHOP. Cẩn thận khi xóa!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Tài khoản: '),
                  TextSpan(
                    text: email,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (role != null)
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Vai trò: '),
                    TextSpan(
                      text: role,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            if (shopName != null)
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Cửa hàng: '),
                    TextSpan(
                      text: shopName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (withData) ...[
              const Text(
                'Sẽ XÓA VĨNH VIỄN:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                '• Tài khoản Firebase Auth (mất đăng nhập)',
                style: TextStyle(fontSize: 13),
              ),
              const Text(
                '• Hồ sơ user trong Firestore',
                style: TextStyle(fontSize: 13),
              ),
              const Text(
                '• Đơn sửa, bán hàng, chi phí do user tạo',
                style: TextStyle(fontSize: 13),
              ),
              const Text(
                '• Dữ liệu chấm công, thông báo của user',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                '⚠️ Dữ liệu shop (kho, khách hàng...) KHÔNG bị xóa.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ] else ...[
              const Text(
                'Chỉ xóa hồ sơ user trong Firestore.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Tài khoản Firebase Auth vẫn còn — user vẫn có thể đăng nhập nhưng mất liên kết shop.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(withData ? 'Xóa hoàn toàn' : 'Xóa user doc'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

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
      metadata: {'email': email, 'role': role, 'shopName': shopName},
      success: true,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          withData
              ? 'Đã xóa user + dữ liệu: $email'
              : 'Đã xóa user doc: $email',
        ),
      ),
    );
    setState(() => _usersRefreshKey++);
  }

  Future<bool> _confirmExit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thoát Console?'),
        content: const Text('Bạn có chắc muốn thoát khỏi Super Admin Console?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ở lại'),
          ),
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
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Đăng xuất'),
          ],
        ),
        content: const Text(
          'Bạn có chắc muốn đăng xuất khỏi Super Admin Console?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
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
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_hasAccess) {
      return const Scaffold(
        body: Center(
          child: Text('Bạn không có quyền truy cập Super Admin Console.'),
        ),
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
                ? Row(
                    children: [
                      _buildSidebar(),
                      const VerticalDivider(width: 1),
                      Expanded(child: _buildContent()),
                    ],
                  )
                : _buildContent(),
          ),
          bottomNavigationBar: isDesktop
              ? null
              : BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _mobileIndexFor(_section),
                  onTap: (i) => setState(() {
                    _section = _sectionFromMobileIndex(i);
                  }),
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard_outlined),
                      activeIcon: Icon(Icons.dashboard),
                      label: 'Dashboard',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.store_outlined),
                      activeIcon: Icon(Icons.store),
                      label: 'Shops',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.people_outline),
                      activeIcon: Icon(Icons.people),
                      label: 'Users',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.receipt_long_outlined),
                      activeIcon: Icon(Icons.receipt_long),
                      label: 'Logs',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.more_horiz),
                      activeIcon: Icon(Icons.more_horiz),
                      label: 'More',
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  int _mobileIndexFor(_AdminSection section) {
    switch (section) {
      case _AdminSection.dashboard:
        return 0;
      case _AdminSection.shops:
        return 1;
      case _AdminSection.users:
        return 2;
      case _AdminSection.audit:
        return 3;
      case _AdminSection.broadcast:
      case _AdminSection.otherApps:
      case _AdminSection.permissions:
      case _AdminSection.settings:
      case _AdminSection.danger:
        return 4;
    }
  }

  _AdminSection _sectionFromMobileIndex(int i) {
    if (i == 4) {
      _showMoreSheet();
      return _section;
    }
    switch (i) {
      case 0:
        return _AdminSection.dashboard;
      case 1:
        return _AdminSection.shops;
      case 2:
        return _AdminSection.users;
      case 3:
        return _AdminSection.audit;
      default:
        return _AdminSection.dashboard;
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
              leading: const Icon(Icons.campaign_rounded, color: Colors.indigo),
              title: const Text('Thông báo'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _section = _AdminSection.broadcast);
              },
            ),
            ListTile(
              leading: const Icon(Icons.apps_rounded, color: Colors.deepPurple),
              title: const Text('Ứng dụng khác'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _section = _AdminSection.otherApps);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Quyền hạn'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _section = _AdminSection.permissions);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Cài đặt'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _section = _AdminSection.settings);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
              ),
              title: const Text('Vùng nguy hiểm'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _section = _AdminSection.danger);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Đăng xuất',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _handleLogout();
              },
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
          _navItem(Icons.dashboard, 'Tổng quan', _AdminSection.dashboard),
          _navItem(Icons.store, 'Cửa hàng', _AdminSection.shops),
          _navItem(Icons.people, 'Người dùng', _AdminSection.users),
          _navItem(Icons.shield, 'Quyền hạn', _AdminSection.permissions),
          _navItem(Icons.receipt_long, 'Nhật ký', _AdminSection.audit),
          _navItem(
            Icons.campaign_rounded,
            'Thông báo',
            _AdminSection.broadcast,
          ),
          _navItem(
            Icons.apps_rounded,
            'Ứng dụng khác',
            _AdminSection.otherApps,
          ),
          _navItem(Icons.settings, 'Cài đặt', _AdminSection.settings),
          _navItem(
            Icons.warning_amber_rounded,
            'Vùng nguy hiểm',
            _AdminSection.danger,
            danger: true,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Đăng xuất',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    _AdminSection value, {
    bool danger = false,
  }) {
    final selected = _section == value;
    final dangerColor = danger ? AppColors.error : null;
    return ListTile(
      leading: Icon(icon, color: dangerColor),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          color: dangerColor,
        ),
      ),
      selected: selected,
      selectedColor: AppColors.primary,
      selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
      onTap: () => setState(() => _section = value),
    );
  }

  Widget _buildContent() {
    switch (_section) {
      case _AdminSection.dashboard:
        return _DashboardSection(
          db: _db,
          onNavigate: (s) => setState(() => _section = s),
        );
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
      case _AdminSection.otherApps:
        return const _OtherAppsSection();
      case _AdminSection.settings:
        return const _SettingsSection();
      case _AdminSection.danger:
        return _DangerSection(
          db: _db,
          onResetShop: _resetShopData,
          onDeleteShop: _softDeleteShop,
        );
    }
  }
}

// ─── Shared widgets (section header + status pill) ────────────────────────────
//
// Dùng chung cho mọi section để nhất quán style + giúp luôn biết đang ở mục
// nào ("dễ theo dõi"). Chỉ ảnh hưởng giao diện, không đụng logic nghiệp vụ.

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.headline3),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

enum _PillStatus { active, locked, deleted, owner, neutral }

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.status});

  final String label;
  final _PillStatus status;

  Color get _color {
    switch (status) {
      case _PillStatus.active:
        return AppColors.success;
      case _PillStatus.locked:
        return AppColors.error;
      case _PillStatus.deleted:
        return AppColors.textDisabled;
      case _PillStatus.owner:
        return AppColors.info;
      case _PillStatus.neutral:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c),
      ),
    );
  }
}

// ─── Dashboard ───────────────────────────────────────────────────────────────

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({required this.db, required this.onNavigate});
  final FirebaseFirestore db;
  final ValueChanged<_AdminSection> onNavigate;

  Future<Map<String, int>> _loadStats() async {
    final allShopsSnap = await db.collection('shops').get();
    final allShops = allShopsSnap.docs
        .where((d) => d.data()['deleted'] != true)
        .toList();
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
        final stats =
            snap.data ?? {'shops': 0, 'users': 0, 'locked': 0, 'active': 0};
        final lockedCount = stats['locked'] ?? 0;
        return ListView(
          children: [
            const _SectionHeader(
              icon: Icons.dashboard_rounded,
              title: 'Tổng quan hệ thống',
              subtitle: 'Số liệu realtime từ Firestore',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  // 2×2 grid using Rows to avoid overflow
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          context,
                          title: 'Tổng shop',
                          value: loading ? '—' : '${stats['shops']}',
                          icon: Icons.store_outlined,
                          color: AppColors.info,
                          onTap: () => onNavigate(_AdminSection.shops),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statCard(
                          context,
                          title: 'Hoạt động',
                          value: loading ? '—' : '${stats['active']}',
                          icon: Icons.check_circle_outline,
                          color: AppColors.success,
                          onTap: () => onNavigate(_AdminSection.shops),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          context,
                          title: 'Tổng user',
                          value: loading ? '—' : '${stats['users']}',
                          icon: Icons.people_outline,
                          color: AppColors.primary,
                          onTap: () => onNavigate(_AdminSection.users),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statCard(
                          context,
                          title: 'Shop bị khóa',
                          value: loading ? '—' : '$lockedCount',
                          icon: Icons.lock_outline,
                          color: AppColors.warning,
                          onTap: () => onNavigate(_AdminSection.shops),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!loading) _attentionCard(context, lockedCount),
                  const SizedBox(height: 20),
                  _quickAccessRow(context),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _attentionCard(BuildContext context, int lockedCount) {
    final ok = lockedCount == 0;
    final color = ok ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok
                      ? 'Hệ thống hoạt động bình thường'
                      : '$lockedCount shop đang bị khóa app',
                  style: AppTextStyles.headline6,
                ),
                Text(
                  ok
                      ? 'Không có shop nào đang bị khóa.'
                      : 'Vào mục Cửa hàng để xem và mở khóa.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          if (!ok)
            TextButton(
              onPressed: () => onNavigate(_AdminSection.shops),
              child: const Text('Xem'),
            ),
        ],
      ),
    );
  }

  Widget _quickAccessRow(BuildContext context) {
    final items = <(IconData, String, _AdminSection)>[
      (Icons.people_outline, 'Người dùng', _AdminSection.users),
      (Icons.receipt_long_outlined, 'Nhật ký', _AdminSection.audit),
      (Icons.campaign_rounded, 'Thông báo', _AdminSection.broadcast),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Truy cập nhanh', style: AppTextStyles.headline6),
        const SizedBox(height: 8),
        Row(
          children: items
              .map(
                (it) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => onNavigate(it.$3),
                      icon: Icon(it.$1, size: 16),
                      label: Text(it.$2, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: AppTextStyles.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shops ───────────────────────────────────────────────────────────────────

enum _ShopFilter { all, active, locked, deleted }

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
  })
  onToggleLock;
  final Future<void> Function(Map<String, dynamic>) onResetShop;

  @override
  State<_ShopsSection> createState() => _ShopsSectionState();
}

class _ShopsSectionState extends State<_ShopsSection> {
  static const int _pageSize = 20;

  final _searchC = TextEditingController();
  String _searchQuery = '';
  _ShopFilter _filter = _ShopFilter.all;

  final List<Map<String, dynamic>> _shops = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _loading = false;
  bool _hasMore = true;

  // Tìm kiếm chỉ lọc trên _shops (dữ liệu đã phân trang) sẽ bỏ sót shop
  // chưa được tải — nên khi có từ khóa, tải TOÀN BỘ shop 1 lần (cache lại)
  // để tìm đúng, thay vì chỉ tìm trong trang hiện tại.
  List<Map<String, dynamic>>? _allShopsCache;
  bool _searchLoading = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _searchC.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadAllShopsForSearch() async {
    if (_allShopsCache != null || _searchLoading) return;
    setState(() => _searchLoading = true);
    try {
      final snap = await widget.db
          .collection('shops')
          .orderBy('name')
          .limit(2000)
          .get();
      final all = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return data;
      }).toList();
      if (!mounted) return;
      setState(() {
        _allShopsCache = all;
        _searchLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  void _onSearchChanged(String v) {
    final q = v.trim();
    setState(() => _searchQuery = q);
    _searchDebounce?.cancel();
    if (q.isEmpty) return;
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      _loadAllShopsForSearch,
    );
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
    final searching = _searchQuery.isNotEmpty;
    final source = (searching && _allShopsCache != null)
        ? _allShopsCache!
        : _shops;
    var list = source.where((s) {
      final deleted = s['deleted'] == true;
      final locked = s['appLocked'] == true;
      switch (_filter) {
        case _ShopFilter.all:
          return !deleted;
        case _ShopFilter.active:
          return !deleted && !locked;
        case _ShopFilter.locked:
          return !deleted && locked;
        case _ShopFilter.deleted:
          return deleted;
      }
    }).toList();
    if (!searching) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((s) {
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
    final searchingUnindexed =
        _searchQuery.isNotEmpty && _allShopsCache == null;

    return Column(
      children: [
        _SectionHeader(
          icon: Icons.store_rounded,
          title: 'Cửa hàng',
          subtitle:
              '${shops.length}${showLoadMore ? '+' : ''} shop'
              '${_loading ? ' · đang tải...' : ''}'
              '${searchingUnindexed ? ' · đang tìm toàn bộ...' : ''}',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: TextField(
            controller: _searchC,
            decoration: InputDecoration(
              hintText: 'Tìm shop theo tên, email, ID...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchC.clear();
                        _searchDebounce?.cancel();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.clear, size: 18),
                    )
                  : null,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Wrap(
            spacing: 6,
            children: [
              _filterChip('Tất cả', _ShopFilter.all),
              _filterChip('Hoạt động', _ShopFilter.active),
              _filterChip('Đã khóa', _ShopFilter.locked),
              _filterChip('Đã xóa', _ShopFilter.deleted),
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

  Widget _filterChip(String label, _ShopFilter value) {
    final selected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      visualDensity: VisualDensity.compact,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? AppColors.primary : null,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
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
        onTap: deleted ? null : () => widget.onEnterShop(s),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: deleted
              ? Colors.grey.shade200
              : appLocked
              ? Colors.red.shade50
              : Colors.green.shade50,
          child: Icon(
            deleted
                ? Icons.delete_outline
                : appLocked
                ? Icons.lock_outline
                : Icons.store_outlined,
            size: 18,
            color: deleted
                ? Colors.grey
                : appLocked
                ? Colors.red
                : Colors.green,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            _StatusPill(
              label: deleted
                  ? 'DELETED'
                  : appLocked
                  ? 'LOCKED'
                  : 'ACTIVE',
              status: deleted
                  ? _PillStatus.deleted
                  : appLocked
                  ? _PillStatus.locked
                  : _PillStatus.active,
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(owner, style: const TextStyle(fontSize: 12)),
            Text(
              shopId,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (v) {
            switch (v) {
              case 'view':
                _showShopDetail(context, s);
              case 'enter':
                widget.onEnterShop(s);
              case 'lock':
                widget.onToggleLock(
                  shopId: shopId,
                  flagName: 'appLocked',
                  newValue: !appLocked,
                  label: 'Toàn bộ app',
                );
              case 'reset':
                widget.onResetShop(s);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'view',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.visibility_outlined),
                title: Text('Xem chi tiết'),
              ),
            ),
            const PopupMenuItem(
              value: 'enter',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.login, color: Colors.blue),
                title: Text('Vào shop'),
              ),
            ),
            PopupMenuItem(
              value: 'lock',
              child: ListTile(
                dense: true,
                leading: Icon(
                  appLocked ? Icons.lock_open_outlined : Icons.lock_outline,
                  color: Colors.orange,
                ),
                title: Text(appLocked ? 'Mở khóa app' : 'Khóa app'),
              ),
            ),
            const PopupMenuItem(
              value: 'reset',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.restart_alt, color: Colors.red),
                title: Text(
                  'Reset dữ liệu',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
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
          title: Text('Cửa hàng: ${shop['name'] ?? ''}'),
          content: SizedBox(
            width: 760,
            height: 520,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Tổng quan'),
                    Tab(text: 'Người dùng'),
                    Tab(text: 'Khóa'),
                    Tab(text: 'Hoạt động'),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        children: [
                          ListTile(
                            title: const Text('Mã cửa hàng'),
                            subtitle: Text((shop['id'] ?? '').toString()),
                          ),
                          ListTile(
                            title: const Text('Chủ cửa hàng'),
                            subtitle: Text(
                              (shop['ownerEmail'] ?? 'N/A').toString(),
                            ),
                          ),
                          ListTile(
                            title: const Text('Loại hình'),
                            subtitle: Text(
                              (shop['businessType'] ?? 'N/A').toString(),
                            ),
                          ),
                        ],
                      ),
                      _ShopUsersTab(shopId: (shop['id'] ?? '').toString()),
                      ListView(
                        children: [
                          SwitchListTile(
                            value: shop['adminFinanceLocked'] == true,
                            onChanged: null,
                            title: const Text('Khóa tài chính quản lý'),
                          ),
                          SwitchListTile(
                            value: shop['staffInventoryLocked'] == true,
                            onChanged: null,
                            title: const Text('Khóa kho cho nhân viên'),
                          ),
                          SwitchListTile(
                            value: shop['staffSalesLocked'] == true,
                            onChanged: null,
                            title: const Text('Khóa bán hàng cho nhân viên'),
                          ),
                          SwitchListTile(
                            value: shop['staffDebtLocked'] == true,
                            onChanged: null,
                            title: const Text('Khóa công nợ cho nhân viên'),
                          ),
                        ],
                      ),
                      _ShopActivityTab(shopId: (shop['id'] ?? '').toString()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
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
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('shopId', isEqualTo: shopId)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snap.data!.docs.isEmpty)
          return const Center(child: Text('Không có user trong shop'));
        return ListView(
          children: snap.data!.docs.map((d) {
            final u = d.data();
            return ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text((u['displayName'] ?? u['email'] ?? '').toString()),
              subtitle: Text('Vai trò: ${(u['role'] ?? 'user')}'),
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
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snap.data!.docs.isEmpty)
          return const Center(child: Text('Chưa có activity'));
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
  const _UsersSection({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });

  final Future<void> Function(BuildContext, String, Map<String, dynamic>)
  onEdit;
  final Future<void> Function(
    String uid,
    String email, {
    required bool withData,
    String? role,
    String? shopName,
  })
  onDelete;

  @override
  State<_UsersSection> createState() => _UsersSectionState();
}

enum _UserRoleFilter { all, owner, staff }

class _UsersSectionState extends State<_UsersSection> {
  static const int _pageSize = 20;

  final _searchC = TextEditingController();
  String _searchQuery = '';
  _UserRoleFilter _roleFilter = _UserRoleFilter.all;

  final List<Map<String, dynamic>> _users = [];
  final List<String> _uids = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _loading = false;
  bool _hasMore = true;
  final Map<String, String> _shopNames = {};
  bool _findingDuplicates = false;

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

  /// Quét toàn bộ /users, gom theo email (chuẩn hoá lowercase) để tìm tài
  /// khoản trùng — CHỈ đọc dữ liệu, không tự xoá gì. Admin xem chi tiết rồi
  /// tự quyết định xoá cái nào qua đúng nút "Xóa" đã có sẵn (yêu cầu PIN).
  Future<void> _showDuplicateFinder(BuildContext context) async {
    setState(() => _findingDuplicates = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .limit(5000)
          .get();
      final byEmail = <String, List<(String, Map<String, dynamic>)>>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final email = (data['email'] ?? '').toString().trim().toLowerCase();
        if (email.isEmpty) continue;
        byEmail.putIfAbsent(email, () => []).add((doc.id, data));
      }
      final duplicates =
          byEmail.entries.where((e) => e.value.length > 1).toList()
            ..sort((a, b) => b.value.length.compareTo(a.value.length));

      final shopIds = duplicates
          .expand((e) => e.value)
          .map((p) => (p.$2['shopId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();
      await _loadShopNames(shopIds);

      if (!mounted) return;
      setState(() => _findingDuplicates = false);

      if (duplicates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy tài khoản trùng email.'),
          ),
        );
        return;
      }

      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _DuplicateUsersDialog(
          groups: duplicates,
          shopNames: _shopNames,
          onDelete: widget.onDelete,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _findingDuplicates = false);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tìm trùng: $e')));
      }
    }
  }

  Future<void> _loadShopNames(List<String> shopIds) async {
    final toFetch = shopIds
        .where((id) => id.isNotEmpty && !_shopNames.containsKey(id))
        .toSet()
        .toList();
    if (toFetch.isEmpty) return;
    try {
      for (final id in toFetch) {
        final snap = await FirebaseFirestore.instance
            .collection('shops')
            .doc(id)
            .get();
        final name = (snap.data()?['shopName'] ?? snap.data()?['name'] ?? '')
            .toString();
        _shopNames[id] = name.isNotEmpty ? name : id;
      }
      if (mounted) setState(() {});
    } catch (_) {}
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
      final newUsers = snap.docs
          .map((d) => Map<String, dynamic>.from(d.data()))
          .toList();
      setState(() {
        if (reset) {
          _users.clear();
          _uids.clear();
        }
        for (int i = 0; i < snap.docs.length; i++) {
          _users.add(newUsers[i]);
          _uids.add(snap.docs[i].id);
        }
        if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;
        _hasMore = snap.docs.length >= _pageSize;
        _loading = false;
      });
      final shopIds = newUsers
          .map((u) => (u['shopId'] ?? '').toString())
          .toList();
      _loadShopNames(shopIds);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<(String, Map<String, dynamic>)> get _filtered {
    var pairs = List.generate(_users.length, (i) => (_uids[i], _users[i]));
    if (_roleFilter != _UserRoleFilter.all) {
      pairs = pairs.where((p) {
        final isOwner = (p.$2['role'] ?? '').toString() == 'owner';
        return _roleFilter == _UserRoleFilter.owner ? isOwner : !isOwner;
      }).toList();
    }
    if (_searchQuery.isEmpty) return pairs;
    final q = _searchQuery.toLowerCase();
    return pairs.where((p) {
      final u = p.$2;
      final name = (u['displayName'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final role = (u['role'] ?? '').toString().toLowerCase();
      final shopId = (u['shopId'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          email.contains(q) ||
          role.contains(q) ||
          shopId.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final users = _filtered;
    final showLoadMore = _hasMore && _searchQuery.isEmpty;

    return Column(
      children: [
        _SectionHeader(
          icon: Icons.people_rounded,
          title: 'Người dùng',
          subtitle:
              '${users.length}${showLoadMore ? '+' : ''} user'
              '${_loading ? ' · đang tải...' : ''}',
          trailing: IconButton(
            tooltip: 'Tìm tài khoản trùng email',
            onPressed: _findingDuplicates
                ? null
                : () => _showDuplicateFinder(context),
            icon: _findingDuplicates
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.content_copy_rounded),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: TextField(
            controller: _searchC,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, email, role, shop ID...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchC.clear();
                        setState(() => _searchQuery = '');
                      },
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
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Wrap(
            spacing: 6,
            children: [
              _roleChip('Tất cả', _UserRoleFilter.all),
              _roleChip('Chủ shop', _UserRoleFilter.owner),
              _roleChip('Nhân viên', _UserRoleFilter.staff),
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
                    final role = (u['role'] ?? 'user').toString();
                    final shopId = (u['shopId'] ?? '').toString();
                    final shopName = shopId.isNotEmpty
                        ? (_shopNames[shopId] ?? shopId)
                        : 'Chưa có shop';
                    final isOwner = role == 'owner';
                    final createdAt = u['createdAt'];
                    String joinDate = '';
                    if (createdAt != null) {
                      try {
                        final dt = (createdAt as dynamic).toDate() as DateTime;
                        joinDate = ' · ${dt.day}/${dt.month}/${dt.year}';
                      } catch (_) {}
                    }
                    return Card(
                      margin: EdgeInsets.zero,
                      shape: isOwner
                          ? RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.indigo.shade200),
                            )
                          : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: isOwner
                              ? Colors.indigo.shade100
                              : Colors.indigo.shade50,
                          child: Icon(
                            isOwner
                                ? Icons.store_rounded
                                : Icons.person_outline,
                            size: 18,
                            color: Colors.indigo,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                (u['displayName'] ?? email).toString(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            if (isOwner)
                              const _StatusPill(
                                label: 'OWNER',
                                status: _PillStatus.owner,
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              'Vai trò: $role · 🏪 $shopName$joinDate',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => widget.onEdit(context, uid, u),
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.orange,
                                size: 20,
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 20),
                              onSelected: (v) {
                                if (v == 'del')
                                  widget.onDelete(
                                    uid,
                                    email,
                                    withData: false,
                                    role: role,
                                    shopName: shopName,
                                  );
                                if (v == 'del_all')
                                  widget.onDelete(
                                    uid,
                                    email,
                                    withData: true,
                                    role: role,
                                    shopName: shopName,
                                  );
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'del',
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(
                                      Icons.delete_outline,
                                      color: Colors.orange,
                                    ),
                                    title: Text('Xóa user doc'),
                                    subtitle: Text(
                                      'Chỉ xóa hồ sơ, Auth còn',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'del_all',
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(
                                      Icons.delete_forever,
                                      color: Colors.red,
                                    ),
                                    title: Text(
                                      'Xóa hoàn toàn',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                    subtitle: Text(
                                      'Auth + dữ liệu do user tạo',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
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

  Widget _roleChip(String label, _UserRoleFilter value) {
    final selected = _roleFilter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _roleFilter = value),
      visualDensity: VisualDensity.compact,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? AppColors.primary : null,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

// ─── Other apps (Ứng dụng khác của chúng tôi) ─────────────────────────────────

class _OtherAppsSection extends StatefulWidget {
  const _OtherAppsSection();
  @override
  State<_OtherAppsSection> createState() => _OtherAppsSectionState();
}

class _OtherAppsSectionState extends State<_OtherAppsSection> {
  final _db = FirebaseFirestore.instance;

  Future<void> _showEditDialog({
    String? docId,
    Map<String, dynamic>? existing,
  }) async {
    final nameC = TextEditingController(
      text: (existing?['name'] ?? '').toString(),
    );
    final descC = TextEditingController(
      text: (existing?['description'] ?? '').toString(),
    );
    final iconC = TextEditingController(
      text: (existing?['iconUrl'] ?? '').toString(),
    );
    final androidC = TextEditingController(
      text: (existing?['androidUrl'] ?? '').toString(),
    );
    final iosC = TextEditingController(
      text: (existing?['iosUrl'] ?? '').toString(),
    );
    final orderC = TextEditingController(
      text: (existing?['order'] ?? 0).toString(),
    );
    bool active = existing?['active'] != false; // default true khi tạo mới
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(docId == null ? 'Thêm ứng dụng' : 'Sửa ứng dụng'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameC,
                    decoration: const InputDecoration(
                      labelText: 'Tên ứng dụng *',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: descC,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Mô tả ngắn'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: iconC,
                    decoration: const InputDecoration(
                      labelText: 'Link ảnh icon (URL)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: androidC,
                    decoration: const InputDecoration(
                      labelText: 'Link Google Play',
                      hintText: 'https://play.google.com/store/apps/...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: iosC,
                    decoration: const InputDecoration(
                      labelText: 'Link App Store',
                      hintText: 'https://apps.apple.com/...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: orderC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Thứ tự hiển thị (số nhỏ hơn hiện trước)',
                    ),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (v) => setDialogState(() => active = v),
                    title: const Text('Đang hiển thị cho người dùng'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    final androidUrl = androidC.text.trim();
    final iosUrl = iosC.text.trim();
    if (androidUrl.isNotEmpty &&
        !androidUrl.startsWith('http://') &&
        !androidUrl.startsWith('https://')) {
      _showSnack('Link Google Play phải bắt đầu bằng http:// hoặc https://');
      return;
    }
    if (iosUrl.isNotEmpty &&
        !iosUrl.startsWith('http://') &&
        !iosUrl.startsWith('https://')) {
      _showSnack('Link App Store phải bắt đầu bằng http:// hoặc https://');
      return;
    }

    final data = {
      'name': nameC.text.trim(),
      'description': descC.text.trim(),
      'iconUrl': iconC.text.trim(),
      'androidUrl': androidUrl,
      'iosUrl': iosUrl,
      'order': int.tryParse(orderC.text.trim()) ?? 0,
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (docId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await _db.collection('other_apps').add(data);
      } else {
        await _db
            .collection('other_apps')
            .doc(docId)
            .set(data, SetOptions(merge: true));
      }
      if (mounted) _showSnack('Đã lưu "${nameC.text.trim()}"', success: true);
    } catch (e) {
      if (mounted) _showSnack('Lỗi lưu: $e');
    }
  }

  Future<void> _confirmDelete(String docId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa ứng dụng'),
        content: Text('Xóa "$name" khỏi danh sách giới thiệu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _db.collection('other_apps').doc(docId).delete();
      if (mounted) _showSnack('Đã xóa "$name"', success: true);
    } catch (e) {
      if (mounted) _showSnack('Lỗi xóa: $e');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('other_apps').orderBy('order').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        return Column(
          children: [
            _SectionHeader(
              icon: Icons.apps_rounded,
              title: 'Ứng dụng khác',
              subtitle:
                  '${docs.length} ứng dụng • hiển thị cho toàn bộ người dùng',
              trailing: FilledButton.icon(
                onPressed: () => _showEditDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm'),
              ),
            ),
            Expanded(
              child: !snap.hasData
                  ? const Center(child: CircularProgressIndicator())
                  : docs.isEmpty
                  ? const Center(child: Text('Chưa có ứng dụng nào'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final doc = docs[i];
                        final data = doc.data();
                        final name = (data['name'] ?? '').toString();
                        final desc = (data['description'] ?? '').toString();
                        final active = data['active'] != false;
                        final iconUrl = (data['iconUrl'] ?? '')
                            .toString()
                            .trim();
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: iconUrl.isEmpty
                                  ? Container(
                                      width: 44,
                                      height: 44,
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      child: Icon(
                                        Icons.apps_rounded,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : Image.network(
                                      iconUrl,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 44,
                                        height: 44,
                                        color: AppColors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        child: Icon(
                                          Icons.apps_rounded,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                _StatusPill(
                                  label: active ? 'HIỆN' : 'ẨN',
                                  status: active
                                      ? _PillStatus.active
                                      : _PillStatus.neutral,
                                ),
                              ],
                            ),
                            subtitle: desc.isEmpty
                                ? null
                                : Text(
                                    desc,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () => _showEditDialog(
                                    docId: doc.id,
                                    existing: data,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: AppColors.error,
                                  ),
                                  onPressed: () => _confirmDelete(doc.id, name),
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
      },
    );
  }
}

// ─── Duplicate users (cùng email, khác uid) ───────────────────────────────────

class _DuplicateUsersDialog extends StatelessWidget {
  const _DuplicateUsersDialog({
    required this.groups,
    required this.shopNames,
    required this.onDelete,
  });

  final List<MapEntry<String, List<(String, Map<String, dynamic>)>>> groups;
  final Map<String, String> shopNames;
  final Future<void> Function(
    String uid,
    String email, {
    required bool withData,
    String? role,
    String? shopName,
  })
  onDelete;

  String _fmtDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.day}/${d.month}/${d.year}';
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final totalExtra = groups.fold<int>(0, (s, e) => s + e.value.length - 1);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.content_copy_rounded, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${groups.length} email trùng · $totalExtra dòng thừa',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        height: 480,
        child: ListView.separated(
          itemCount: groups.length,
          separatorBuilder: (_, __) => const Divider(height: 20),
          itemBuilder: (_, i) {
            final email = groups[i].key;
            final members = groups[i].value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                ...members.map((m) {
                  final uid = m.$1;
                  final data = m.$2;
                  final role = (data['role'] ?? '?').toString();
                  final shopId = (data['shopId'] ?? '').toString();
                  final shopName = shopId.isEmpty
                      ? '(không thuộc shop)'
                      : (shopNames[shopId] ?? shopId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$role · $shopName · tạo ${_fmtDate(data['createdAt'])} · $uid',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Xóa dòng này',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          onPressed: () => onDelete(
                            uid,
                            email,
                            withData: true,
                            role: role,
                            shopName: shopName,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
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
      children: [
        const _SectionHeader(
          icon: Icons.shield_rounded,
          title: 'Quyền hạn',
          subtitle: 'Bảng quyền role-based baseline',
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Bảng quyền hạn'),
              subtitle: Text(
                'Chuẩn role-based baseline cho owner/manager/staff. Các khóa cấp shop sẽ override tại runtime.',
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Vai trò')),
                  DataColumn(label: Text('Sửa đơn')),
                  DataColumn(label: Text('Xem tài chính')),
                  DataColumn(label: Text('Đổi lock flags')),
                  DataColumn(label: Text('Thao tác nguy hiểm')),
                ],
                rows: rows
                    .map(
                      (r) => DataRow(
                        cells: [
                          DataCell(Text(r[0])),
                          DataCell(Text(r[1])),
                          DataCell(Text(r[2])),
                          DataCell(Text(r[3])),
                          DataCell(Text(r[4])),
                        ],
                      ),
                    )
                    .toList(),
              ),
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
    Query<Map<String, dynamic>> query = db
        .collection('admin_audit_log')
        .orderBy('timestamp', descending: true)
        .limit(200);
    if (shopFilter != null && shopFilter!.isNotEmpty)
      query = query.where('shopId', isEqualTo: shopFilter);
    if (actionFilter != 'all')
      query = query.where('action', isEqualTo: actionFilter);

    return Column(
      children: [
        const _SectionHeader(
          icon: Icons.receipt_long_rounded,
          title: 'Nhật ký',
          subtitle: 'Lịch sử thao tác quản trị',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Filter shopId',
                    isDense: true,
                  ),
                  onChanged: (v) => onFilterChanged(
                    v.trim().isEmpty ? null : v.trim(),
                    actionFilter,
                    textFilter,
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Filter action',
                    isDense: true,
                  ),
                  onChanged: (v) => onFilterChanged(
                    shopFilter,
                    v.trim().isEmpty ? 'all' : v.trim(),
                    textFilter,
                  ),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Search email/user',
                    isDense: true,
                  ),
                  onChanged: (v) =>
                      onFilterChanged(shopFilter, actionFilter, v.trim()),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (_, snap) {
              if (!snap.hasData)
                return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs.where((d) {
                if (textFilter.isEmpty) return true;
                final data = d.data();
                final email = (data['email'] ?? '').toString().toLowerCase();
                final target = (data['targetUserId'] ?? '')
                    .toString()
                    .toLowerCase();
                final q = textFilter.toLowerCase();
                return email.contains(q) || target.contains(q);
              }).toList();
              if (docs.isEmpty)
                return const Center(
                  child: Text('Không có audit logs phù hợp.'),
                );
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final a = docs[i].data();
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.receipt_long, size: 18),
                    title: Text((a['action'] ?? '').toString()),
                    subtitle: Text(
                      'Người dùng: ${(a['email'] ?? '')} · Cửa hàng: ${(a['shopId'] ?? '-')}',
                    ),
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
          title: Row(
            children: [
              const Icon(Icons.lock, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Text(isChange ? 'Đổi mã PIN' : 'Thiết lập mã PIN'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinC,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Mã PIN mới (4-6 số)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmC,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Nhập lại PIN',
                  border: OutlineInputBorder(),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(
                  error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                if (pinC.text.length < 4) {
                  setD(() => error = 'PIN phải từ 4-6 số');
                  return;
                }
                if (pinC.text != confirmC.text) {
                  setD(() => error = 'Hai mã PIN không khớp');
                  return;
                }
                final ok = await SuperAdminSecurityService.setupPin(pinC.text);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (ok) _reloadPinStatus();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Đã thiết lập mã PIN thành công.'
                            : 'Lỗi thiết lập PIN.',
                      ),
                      backgroundColor: ok ? Colors.green : Colors.red,
                    ),
                  );
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
          title: const Row(
            children: [
              Icon(Icons.lock_open, color: Colors.orange),
              SizedBox(width: 8),
              Text('Tắt mã PIN'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nhập PIN hiện tại để xác nhận tắt:'),
              const SizedBox(height: 10),
              TextField(
                controller: pinC,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Mã PIN hiện tại',
                  border: const OutlineInputBorder(),
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                final verified = await SuperAdminSecurityService.verifyPin(
                  pinC.text,
                );
                if (!verified) {
                  setD(() => error = 'Mã PIN không đúng');
                  return;
                }
                await SuperAdminSecurityService.removePin();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _reloadPinStatus();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã tắt mã PIN.'),
                      backgroundColor: Colors.orange,
                    ),
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
      children: [
        const _SectionHeader(
          icon: Icons.settings_rounded,
          title: 'Cài đặt',
          subtitle: 'Bảo mật PIN & đồng bộ hệ thống',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.deepPurple.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Colors.deepPurple),
                          SizedBox(width: 8),
                          Text(
                            'Bảo mật PIN',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bảo vệ Console bằng mã PIN khi session hết hạn',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const Divider(height: 16),
                      if (hasPin == null)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            hasPin
                                ? Icons.lock_outline
                                : Icons.lock_open_outlined,
                            color: hasPin ? Colors.green : Colors.orange,
                          ),
                          title: Text(
                            hasPin ? 'Mã PIN đã bật' : 'Chưa thiết lập PIN',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            hasPin
                                ? 'Yêu cầu PIN khi session hết hạn (30 phút idle)'
                                : 'Bật PIN để bảo vệ console',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: hasPin
                              ? PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'change')
                                      _showSetupPinDialog(isChange: true);
                                    if (v == 'remove') _showRemovePinDialog();
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'change',
                                      child: Text('Đổi PIN'),
                                    ),
                                    PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Tắt PIN'),
                                    ),
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
                  subtitle: const Text(
                    'Đồng bộ claims cho toàn bộ user khi thay đổi rules/roles.',
                  ),
                  onTap: () async {
                    final result = await ClaimsService().batchSyncAllClaims();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result['success'] == true
                              ? 'Sync claims thành công.'
                              : 'Sync claims lỗi: ${result['error'] ?? 'unknown'}',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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
  final _urlCtrl = TextEditingController();
  String _type = 'info';
  bool _sending = false;
  String? _lastResult;
  bool _lastSuccess = false;
  bool _useStoreLink = false;

  static const _types = [
    ('info', '📢 Thông tin', Colors.indigo),
    ('warning', '⚠️ Cảnh báo', Colors.orange),
    ('update_required', '🔴 Yêu cầu cập nhật', Colors.red),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  bool get _showStoreLinkOption => _type == 'update_required';

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    final url = _showStoreLinkOption && _useStoreLink
        ? NotificationService.storeLinkSentinel
        : _urlCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() {
        _lastResult = 'Vui lòng nhập tiêu đề và nội dung.';
        _lastSuccess = false;
      });
      return;
    }
    if (url.isNotEmpty &&
        url != NotificationService.storeLinkSentinel &&
        !url.startsWith('http://') &&
        !url.startsWith('https://')) {
      setState(() {
        _lastResult = 'Link phải bắt đầu bằng http:// hoặc https://';
        _lastSuccess = false;
      });
      return;
    }
    setState(() {
      _sending = true;
      _lastResult = null;
    });
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('sendBroadcastNotification');
      await callable.call({
        'title': title,
        'body': body,
        'type': _type,
        if (url.isNotEmpty) 'url': url,
      });
      setState(() {
        _lastResult = '✅ Đã gửi thành công tới toàn bộ người dùng!';
        _lastSuccess = true;
        _titleCtrl.clear();
        _bodyCtrl.clear();
        _urlCtrl.clear();
      });
    } catch (e) {
      setState(() {
        _lastResult = '❌ Lỗi: ${e.toString()}';
        _lastSuccess = false;
      });
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _deleteBroadcast(String docId) async {
    await FirebaseFirestore.instance
        .collection('broadcasts')
        .doc(docId)
        .delete();
  }

  Widget _buildFormCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: Colors.indigo,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gửi Thông Báo Hệ Thống',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Gửi tới TẤT CẢ người dùng qua dialog + push.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Loại thông báo',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _types.map((t) {
                final selected = _type == t.$1;
                return ChoiceChip(
                  label: Text(t.$2, style: const TextStyle(fontSize: 13)),
                  selected: selected,
                  selectedColor: t.$3.withValues(alpha: 0.2),
                  onSelected: (_) => setState(() {
                    _type = t.$1;
                    if (t.$1 == 'update_required') _useStoreLink = true;
                  }),
                  labelStyle: TextStyle(
                    color: selected ? t.$3 : null,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Tiêu đề',
                hintText: 'VD: Yêu cầu cập nhật phiên bản mới',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.title_rounded),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Nội dung',
                hintText: 'Nhập nội dung thông báo chi tiết...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.message_rounded),
                alignLabelWithHint: true,
                isDense: true,
              ),
            ),
            if (_showStoreLinkOption) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _useStoreLink,
                  onChanged: (v) => setState(() => _useStoreLink = v),
                  activeThumbColor: AppColors.primary,
                  title: const Text(
                    'Bấm vào là mở kho ứng dụng',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Tự động mở App Store (iOS) hoặc Google Play (Android) đúng theo máy người dùng — không cần dán link',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              ),
            ],
            if (!_showStoreLinkOption || !_useStoreLink) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _urlCtrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Link (không bắt buộc)',
                  hintText: 'VD: link bài viết, link khuyến mãi...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.link_rounded),
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_lastResult != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _lastSuccess
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _lastSuccess
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                  ),
                ),
                child: Text(
                  _lastResult!,
                  style: TextStyle(
                    color: _lastSuccess
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                    fontSize: 13,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _sending ? 'Đang gửi...' : 'Gửi tới toàn bộ người dùng',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Lịch sử thông báo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('broadcasts')
                  .orderBy('createdAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData)
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Chưa có thông báo nào.',
                      style: TextStyle(color: Colors.grey),
                    ),
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
                    final color = type == 'update_required'
                        ? Colors.red
                        : type == 'warning'
                        ? Colors.orange
                        : Colors.indigo;
                    final ts = (d['createdAt'] as Timestamp?)?.toDate();
                    final expiresAt = (d['expiresAt'] as Timestamp?)?.toDate();
                    final expired =
                        expiresAt != null && expiresAt.isBefore(DateTime.now());
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.campaign_rounded,
                        color: color,
                        size: 20,
                      ),
                      title: Text(
                        d['title'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: expired ? Colors.grey : null,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['body'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (ts != null)
                            Text(
                              '${ts.day}/${ts.month}/${ts.year} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}${expired ? ' · Hết hạn' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: expired
                                    ? Colors.red.shade300
                                    : Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red,
                        ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        const header = _SectionHeader(
          icon: Icons.campaign_rounded,
          title: 'Thông báo hệ thống',
          subtitle: 'Gửi tới toàn bộ người dùng',
        );
        if (isWide) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildFormCard()),
                      const SizedBox(width: 20),
                      Expanded(flex: 1, child: _buildHistoryCard()),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          child: Column(
            children: [
              header,
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    _buildFormCard(),
                    const SizedBox(height: 16),
                    _buildHistoryCard(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Danger Zone ─────────────────────────────────────────────────────────────

class _DangerSection extends StatelessWidget {
  const _DangerSection({
    required this.db,
    required this.onResetShop,
    required this.onDeleteShop,
  });

  final FirebaseFirestore db;
  final Future<void> Function(Map<String, dynamic>) onResetShop;
  final Future<void> Function(Map<String, dynamic>) onDeleteShop;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('shops').orderBy('name').snapshots(),
      builder: (_, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final allDocs = snap.data!.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] = d.id;
          return data;
        }).toList();
        // Shop đã xóa (deleted: true) không còn hành động gì để làm ở đây —
        // ẩn khỏi danh sách để "Xóa" biến mất thật sự thay vì trông như vẫn
        // còn nguyên (xem tab Cửa hàng > bộ lọc "Đã xóa" để xem lại).
        final shops = allDocs.where((s) => s['deleted'] != true).toList();
        final deletedCount = allDocs.length - shops.length;

        return ListView(
          children: [
            _SectionHeader(
              icon: Icons.warning_amber_rounded,
              title: 'Vùng nguy hiểm',
              subtitle:
                  '${shops.length} shop'
                  '${deletedCount > 0 ? ' • $deletedCount đã xóa (xem ở tab Cửa hàng)' : ''}'
                  ' • thao tác yêu cầu xác thực PIN, được ghi audit log',
              color: AppColors.error,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Card(
                    color: AppColors.errorLight,
                    child: ListTile(
                      leading: Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                      ),
                      title: Text('Cẩn trọng'),
                      subtitle: Text(
                        'Mọi thao tác tại đây đều yêu cầu xác thực PIN và được ghi audit log.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...shops.map(
                    (s) => Card(
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
                              label: const Text('Đặt lại'),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.error,
                              ),
                              onPressed: () => onDeleteShop(s),
                              icon: const Icon(Icons.delete_forever),
                              label: const Text('Xóa'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
  const _ResetSelection({
    required this.collections,
    required this.storageRoots,
  });
}

class _CollectionGroup {
  final String label;
  final IconData icon;
  final Color color;
  final List<_CollectionItem> items;
  const _CollectionGroup({
    required this.label,
    required this.icon,
    required this.color,
    required this.items,
  });
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
    items: [_CollectionItem('audit_logs', 'Nhật ký thao tác')],
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

const Set<String> _kCoreDataCollectionsToKeep = {
  'repairs',
  'customers',
  'attendance',
  'payroll_settings',
  'work_schedules',
};

const Set<String> _kCoreDataStorageRootsToKeep = {
  'repairs',
  'attendance',
  'db_backups',
  'shop_logos',
};

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

  String _itemKey(_CollectionItem item) =>
      item.isStorage ? 'storage:${item.key}' : 'col:${item.key}';
  bool get _anyChecked => _checked.values.any((v) => v);
  bool get _allChecked => _checked.values.every((v) => v);
  bool _groupAllChecked(_CollectionGroup g) =>
      g.items.every((item) => _checked[_itemKey(item)] == true);
  bool _groupAnyChecked(_CollectionGroup g) =>
      g.items.any((item) => _checked[_itemKey(item)] == true);

  void _toggleGroup(_CollectionGroup g, bool value) {
    setState(() {
      for (final item in g.items) {
        _checked[_itemKey(item)] = value;
      }
    });
  }

  void _toggleAll(bool value) {
    setState(() {
      for (final key in _checked.keys) {
        _checked[key] = value;
      }
    });
  }

  void _applyCoreDataCleanupPreset() {
    setState(() {
      for (final g in _kGroups) {
        for (final item in g.items) {
          final key = _itemKey(item);
          if (item.isStorage) {
            _checked[key] = !_kCoreDataStorageRootsToKeep.contains(item.key);
          } else {
            _checked[key] = !_kCoreDataCollectionsToKeep.contains(item.key);
          }
        }
      }
    });
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
      title: Row(
        children: [
          const Icon(Icons.delete_sweep_outlined, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn dữ liệu cần xóa',
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  widget.shopName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
                title: const Text(
                  'Chọn tất cả',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('$selectedCount mục đã chọn'),
                onChanged: (v) => _toggleAll(v == true),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _applyCoreDataCleanupPreset,
                icon: const Icon(Icons.cleaning_services_outlined, size: 16),
                label: const Text('Giữ sửa chữa + khách hàng + nhân sự'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(children: _kGroups.map(_buildGroup).toList()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _anyChecked
              ? () => Navigator.pop(context, _buildResult())
              : null,
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
          title: Text(
            g.label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (anyChecked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${g.items.where((i) => _checked[_itemKey(i)] == true).length}/${g.items.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
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
          children: g.items
              .map(
                (item) => CheckboxListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: _checked[_itemKey(item)] ?? false,
                  activeColor: g.color,
                  title: Text(item.label, style: const TextStyle(fontSize: 13)),
                  secondary: item.isStorage
                      ? const Icon(
                          Icons.cloud_outlined,
                          size: 16,
                          color: Colors.indigo,
                        )
                      : const Icon(
                          Icons.storage_outlined,
                          size: 16,
                          color: Colors.grey,
                        ),
                  onChanged: (v) =>
                      setState(() => _checked[_itemKey(item)] = v ?? false),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
