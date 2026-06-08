import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../services/social_auth_service.dart';
import '../services/super_admin_security_service.dart';
import '../services/user_service.dart';
import '../services/event_bus.dart';
import '../services/current_shop_service.dart';
import '../services/storage_service.dart';
import '../theme/app_text_styles.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/encryption_service.dart';
import '../data/db_helper.dart';
import '../services/sync_service.dart';
import '../services/sync_orchestrator.dart';
import '../utils/app_info.dart';
import '../services/first_time_guide_service.dart';
import '../widgets/unified_sync_button.dart';
import '../widgets/shop_switcher_widget.dart';
import '../widgets/custom_app_bar.dart';
import 'help_center_view.dart';
import 'user_guide_view.dart';
import 'backup_restore_view.dart';
import 'shop_selector_view.dart';
import 'staff_permissions_view.dart';
import 'category_management_view.dart';
import 'shop_settings_view.dart';
import 'printer_settings_view.dart';
import 'notification_settings_view.dart';
import 'kiotviet_settings_view.dart';
import 'hr_salary_settings_view.dart';
import 'label_settings_view.dart';
import 'work_schedule_settings_view.dart';
import '../widgets/responsive_wrapper.dart';
import '../services/category_service.dart';
import '../models/shop_settings_model.dart';

class SettingsView extends StatefulWidget {
  final void Function(Locale)? setLocale;
  const SettingsView({super.key, this.setLocale});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Localization getter
  AppLocalizations get loc => AppLocalizations.of(context)!;
  
  String _role = 'user';
  bool _loading = true;
  late final Future<String> _versionFuture;
  bool _updatingAvatar = false;
  String? _profilePhotoUrl;
  String? _profileDisplayName;

  // Super admin shop selection
  List<Map<String, dynamic>> _allShops = [];
  String? _selectedShopId;
  bool _loadingShops = false;

  ShopSettings? _shopSettings;
  bool _isSavingPendingCost = false;
  bool _isSavingSupplier = false;
  bool _isResyncingKiotViet = false;
  bool _isPullingFromCloud = false;
  bool? _pendingCostOverride;
  int _settingsVersion = 0;
  bool get _allowPendingCost =>
      _pendingCostOverride ?? _shopSettings?.allowPendingCost ?? false;
  bool get _enableSupplier => _shopSettings?.enableSupplier ?? true;
  bool get _requireSupplier => _shopSettings?.requireSupplier ?? true;
  bool _isSavingRequireSupplier = false;
  
  // Current selected locale
  // Language selection hidden — Vietnamese only

  @override
  void initState() {
    super.initState();
    _versionFuture = AppInfo.getVersion();
    _loadRole();
    _loadCurrentUserProfile();
    _loadShopsForAdmin();
    _loadShopSettings();
    // Language selection hidden
  }

  Future<void> _loadCurrentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (!mounted || data == null) return;
      setState(() {
        _profilePhotoUrl = (data['photoUrl'] as String?)?.trim();
        final displayName = (data['displayName'] as String?)?.trim();
        _profileDisplayName =
            (displayName != null && displayName.isNotEmpty) ? displayName : null;
      });
    } catch (e) {
      debugPrint('Load current user profile failed: $e');
    }
  }

  Future<void> _loadShopSettings() async {
    // Ghi nhớ version tại thời điểm bắt đầu load
    final loadedVersion = _settingsVersion;
    try {
      final shopId = await UserService.getCurrentShopId();
      final s = await CategoryService().getShopSettings();
      final effective = s ?? (shopId != null ? ShopSettings.electronics(shopId) : null);
      if (!mounted || effective == null) return;
      // Nếu có save xảy ra trong khi đang load → bỏ qua kết quả cũ
      if (_settingsVersion != loadedVersion) return;
      setState(() => _shopSettings = effective);
    } catch (e) {
      debugPrint('SettingsView._loadShopSettings: $e');
    }
  }

  Future<void> _forceResyncKiotViet() async {
    if (_isResyncingKiotViet) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đẩy dữ liệu KiotViet lên Cloud'),
        content: const Text(
          'Thao tác này sẽ:\n'
          '• Gán shopId cho các bản ghi thiếu (import cũ)\n'
          '• Đặt lại cờ isSynced=0 cho toàn bộ đơn bán và sản phẩm\n'
          '• Đẩy tất cả lên Firestore (có thể mất vài phút)\n\n'
          'Tiếp tục?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đồng bộ ngay')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isResyncingKiotViet = true);
    try {
      final result = await SyncService.forceResyncKiotVietData();
      if (!mounted) return;
      final backfilled = (result['salesBackfilled'] ?? 0) + (result['productsBackfilled'] ?? 0);
      final reset = (result['salesReset'] ?? 0) + (result['productsReset'] ?? 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đang đồng bộ — $reset bản ghi đã được đánh dấu re-sync'
              '${backfilled > 0 ? " ($backfilled đã gán shopId)" : ""}'),
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isResyncingKiotViet = false);
    }
  }

  Future<void> _pullKhoFromCloud() async {
    if (_isPullingFromCloud) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhận kho từ Cloud'),
        content: const Text(
          'Thao tác này sẽ:\n'
          '• Xóa toàn bộ kho LOCAL trên máy này\n'
          '• Tải lại toàn bộ sản phẩm từ Firestore\n'
          '• Không ảnh hưởng đơn sửa / đơn bán\n\n'
          'Dùng sau khi máy chủ đã import KiotViet và đẩy lên cloud.\n'
          'Máy này sẽ đồng bộ sạch với cloud.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đồng ý')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isPullingFromCloud = true);
    try {
      // 1. Push any pending local ops first (sync_queue items)
      try { await SyncOrchestrator().syncAll(); } catch (_) {}

      // 2. Wipe local products for this shop before pulling
      // downloadAllFromCloud only upserts — it won't remove hard-deleted cloud docs.
      // Clearing first ensures Device B gets exactly what Firestore has.
      try {
        final shopId = await UserService.getCurrentShopId();
        if (shopId != null && shopId.isNotEmpty) {
          final db = DBHelper();
          await (await db.database).delete(
            'products',
            where: 'shopId = ?',
            whereArgs: [shopId],
          );
        }
      } catch (_) {}

      // 3. Pull fresh from Firestore
      await SyncService.downloadAllFromCloud(force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã nhận kho từ cloud thành công'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isPullingFromCloud = false);
    }
  }

  Future<void> _saveAllowPendingCost(bool value) async {
    debugPrint('🔄 TOGGLE: _saveAllowPendingCost called value=$value, _isSavingPendingCost=$_isSavingPendingCost');
    if (_isSavingPendingCost) return;

    setState(() {
      _isSavingPendingCost = true;
      _pendingCostOverride = value;
    });
    debugPrint('🔄 TOGGLE: after first setState: _allowPendingCost=$_allowPendingCost override=$_pendingCostOverride');

    try {
      final shopId = await UserService.getCurrentShopId();
      debugPrint('🔄 TOGGLE: shopId=$shopId');
      if (shopId == null || shopId.isEmpty) {
        throw Exception('Chưa xác định cửa hàng hiện tại. Vui lòng chọn lại shop.');
      }

      final current = _shopSettings ?? ShopSettings.electronics(shopId);
      final updated = current.copyWith(allowPendingCost: value, shopId: shopId);
      debugPrint('🔄 TOGGLE: updated.allowPendingCost=${updated.allowPendingCost}');

      final svc = CategoryService();
      svc.resetRemoteWriteCooldown();
      final saved = await svc.saveShopSettings(updated);
      debugPrint('🔄 TOGGLE: saveShopSettings returned=$saved');
      if (!saved) {
        throw Exception('Không thể lưu cài đặt (local/remote).');
      }

      if (!mounted) return;
      setState(() {
        _shopSettings = updated;
        _settingsVersion++;
        _pendingCostOverride = null;
        _isSavingPendingCost = false;
      });
      debugPrint('🔄 TOGGLE: SUCCESS → _allowPendingCost=$_allowPendingCost shopSettings.allowPendingCost=${_shopSettings?.allowPendingCost}');
      EventBus().emit('settings_changed');
      NotificationService.showSnackBar(
        value ? '✅ Đã bật: cho phép nhập giá vốn sau' : '🔒 Đã tắt: bắt buộc nhập giá vốn',
        color: value ? Colors.teal : Colors.grey.shade700,
      );
    } catch (e) {
      debugPrint('🔄 TOGGLE: CATCH ERROR=$e');
      if (mounted) {
        setState(() {
          _isSavingPendingCost = false;
          _pendingCostOverride = null;
        });
      }
      debugPrint('🔄 TOGGLE: after catch setState: _allowPendingCost=$_allowPendingCost shopSettings=${_shopSettings?.allowPendingCost}');
      NotificationService.showSnackBar('Lỗi lưu cài đặt: $e', color: Colors.red);
    }
  }

  Future<void> _saveRequireSupplier(bool value) async {
    if (_isSavingRequireSupplier) return;
    setState(() => _isSavingRequireSupplier = true);
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null || shopId.isEmpty) throw Exception('Chưa xác định cửa hàng');
      final current = _shopSettings ?? ShopSettings.electronics(shopId);
      final svc = CategoryService();
      svc.resetRemoteWriteCooldown();
      final saved = await svc.saveShopSettings(current.copyWith(requireSupplier: value));
      if (!saved) throw Exception('Không thể lưu cài đặt');
      if (mounted) {
        setState(() {
          _shopSettings = current.copyWith(requireSupplier: value);
          _settingsVersion++;
          _isSavingRequireSupplier = false;
        });
        EventBus().emit('settings_changed');
        NotificationService.showSnackBar(
          value ? '✅ Bắt buộc chọn NCC khi nhập kho' : '🔓 NCC không bắt buộc khi nhập kho',
          color: value ? Colors.deepOrange : Colors.grey.shade700,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isSavingRequireSupplier = false);
      NotificationService.showSnackBar('Lỗi: $e', color: Colors.red);
    }
  }

  Future<void> _saveEnableSupplier(bool value) async {
    if (_isSavingSupplier) return;
    setState(() => _isSavingSupplier = true);
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null || shopId.isEmpty) throw Exception('Chưa xác định cửa hàng');
      final current = _shopSettings ?? ShopSettings.electronics(shopId);
      final svc = CategoryService();
      svc.resetRemoteWriteCooldown();
      final saved = await svc.saveShopSettings(current.copyWith(enableSupplier: value));
      if (!saved) throw Exception('Không thể lưu cài đặt');
      if (mounted) {
        setState(() {
          _shopSettings = current.copyWith(enableSupplier: value);
          _settingsVersion++;
          _isSavingSupplier = false;
        });
        EventBus().emit('settings_changed');
        NotificationService.showSnackBar(
          value ? '✅ Đã bật: hiển thị nhà cung cấp' : '🔒 Đã tắt: ẩn tính năng nhà cung cấp',
          color: value ? Colors.indigo : Colors.grey.shade700,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isSavingSupplier = false);
      NotificationService.showSnackBar('Lỗi: $e', color: Colors.red);
    }
  }

  Future<void> _pickAndUploadMyAvatar() async {
    if (_updatingAvatar) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      NotificationService.showSnackBar('Vui lòng đăng nhập lại', color: Colors.red);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      setState(() => _updatingAvatar = true);
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (picked == null) return;

      final uploadedUrl = await StorageService.uploadXFileAndGetUrl(
        picked,
        'user_photos/${user.uid}',
      );
      if (uploadedUrl == null || uploadedUrl.trim().isEmpty) {
        final denied = StorageService.lastUploadPermissionDenied ||
            (StorageService.lastUploadErrorMessage ?? '').toLowerCase().contains('unauthorized') ||
            (StorageService.lastUploadErrorMessage ?? '').toLowerCase().contains('permission');
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              denied
                  ? 'Không có quyền tải ảnh lên (lỗi 403). Vui lòng liên hệ quản trị viên kiểm tra cấu hình App Check/Storage.'
                  : 'Không tải được ảnh lên. Vui lòng kiểm tra kết nối mạng và thử lại.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photoUrl': uploadedUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      try {
        await user.updatePhotoURL(uploadedUrl);
        await user.reload();
      } catch (e) {
        debugPrint('updatePhotoURL failed, fallback to Firestore photo only: $e');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_userPhotoUrl_${user.uid}', uploadedUrl);

      if (!mounted) return;
      setState(() {
        _profilePhotoUrl = uploadedUrl;
      });
      EventBus().emit('user_profile_changed');
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã cập nhật ảnh đại diện thành công')),
      );
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString().toLowerCase();
      final denied = errStr.contains('unauthorized') || errStr.contains('permission');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            denied
                ? 'Không có quyền tải ảnh lên (lỗi 403). Vui lòng liên hệ quản trị viên.'
                : 'Lỗi cập nhật ảnh đại diện: $e',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingAvatar = false);
    }
  }
  
  /// Load danh sách shops cho super admin
  Future<void> _loadShopsForAdmin() async {
    if (!UserService.isCurrentUserSuperAdmin()) return;
    setState(() => _loadingShops = true);
    try {
      final shops = await UserService.getAllShops();
      if (mounted) {
        final savedShopId = UserService.getAdminSelectedShop();
        // Validate that savedShopId exists in shops list
        final shopExists = savedShopId != null &&
            shops.any((s) => s['id'] == savedShopId);
        setState(() {
          _allShops = shops;
          _selectedShopId = shopExists ? savedShopId : null;
          _loadingShops = false;
        });
        // Clear invalid saved shop
        if (savedShopId != null && !shopExists) {
          UserService.setAdminSelectedShop(null);
        }
      }
    } catch (e) {
      debugPrint('Error loading shops: $e');
      if (mounted) setState(() => _loadingShops = false);
    }
  }

  /// Super admin chọn shop để xem
  Future<void> _onShopSelected(String? shopId) async {
    if (shopId == null) return;

    // Set shop TRƯỚC khi làm bất cứ gì khác
    UserService.setAdminSelectedShop(shopId);
    setState(() => _selectedShopId = shopId);

    // Hiển thị loading
    NotificationService.showSnackBar(
      loc.loadingShopData,
      color: Colors.blue,
    );

    try {
      // Hủy subscriptions cũ trước
      await SyncService.cancelAllSubscriptions();

      // Xóa local data cũ + reset sync timestamps
      await DBHelper().clearAllData();
      await SyncService.resetSyncTimestamps();

      // Download data của shop mới
      await SyncService.downloadAllFromCloud(force: true);

      // Khởi động lại real-time sync cho shop mới
      await SyncService.initRealTimeSync(() {
        if (mounted) setState(() {});
      });

      final shopName =
          _allShops.firstWhere(
            (s) => s['id'] == shopId,
            orElse: () => {'name': shopId},
          )['name'] ??
          shopId;

      NotificationService.showSnackBar(
        loc.switchedToShop(shopName),
        color: Colors.green,
      );
    } catch (e) {
      debugPrint('Error switching shop: $e');
      NotificationService.showSnackBar(
        loc.errorSwitchingShop(e.toString()),
        color: Colors.red,
      );
    }
  }

  String _getRoleDisplayName(String role, AppLocalizations localizations) {
    switch (role) {
      case 'owner':
        return localizations.ownerRole;
      case 'manager':
        return localizations.managerRole;
      case 'employee':
        return localizations.employeeRole;
      case 'technician':
        return localizations.technicianRole;
      case 'admin':
        return localizations.adminRole;
      case 'user':
        return localizations.userRole;
      default:
        return role.toUpperCase();
    }
  }

  Future<void> _loadRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final role = await UserService.getUserRole(user.uid);
      if (mounted) {
        setState(() {
          _role = role;
          _loading = false;
        });
      }
    } else {
      // User null - vẫn hiển thị UI
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _openUserGuide() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserGuideView(userRole: _role),
      ),
    );
  }

  // HÀM XỬ LÝ XÓA TRẮNG SHOP (BẢO MẬT TUYỆT ĐỐI)
  Future<void> _handleResetShop() async {
    // Chỉ super admin mới được xóa dữ liệu shop
    if (!UserService.isCurrentUserSuperAdmin()) {
      NotificationService.showSnackBar(
        loc.onlySuperAdminCanDelete,
        color: Colors.red,
      );
      return;
    }

    final confirmTextC = TextEditingController();
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          loc.dangerWarning,
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.deleteAllDataWarning),
            const SizedBox(height: 8),
            Text(
              loc.typeToConfirm,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            TextField(
              controller: confirmTextC,
              decoration: InputDecoration(hintText: loc.deleteAllPlaceholder),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.cancel.toUpperCase()),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, confirmTextC.text.trim() == "XOA HET"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              loc.confirmDeleteAll,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _loading = true);
      final errorMessage = await FirestoreService.resetEntireShopData();
      await DBHelper().clearAllData();

      if (errorMessage == null) {
        NotificationService.showSnackBar(
          loc.shopDataDeleted,
          color: Colors.green,
        );
      } else {
        NotificationService.showSnackBar(
          loc.errorDeletingCloudData(errorMessage),
          color: Colors.red,
        );
      }
      await SyncService.cancelAllSubscriptions();
      EncryptionService.reset(); // Reset mã hóa khi xóa dữ liệu
      UserService.clearCache(); // Xóa cache shopId
      CurrentShopService().clear(); // Clear multi-shop cache
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('Logout error: $e');
      }
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isAdminOrOwner = _role == 'owner' || _role == 'admin' || UserService.isCurrentUserSuperAdmin();
    return Scaffold(
      appBar: CustomAppBar.build(title: l.systemSettings),
      body: ResponsiveCenter(
        maxWidth: 800,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(10),
              children: [
                // ===== TÀI KHOẢN =====
                _buildSection(l.accountAndSecurity),
                _buildAccountCard(l),
                if (UserService.isCurrentUserSuperAdmin()) ...[
                  const SizedBox(height: 8),
                  _buildNavTile(
                    icon: Icons.swap_horiz,
                    color: Colors.deepPurple,
                    title: l.selectOtherShop,
                    subtitle: '${l.currentShop}: ${UserService.getAdminSelectedShop()?.substring(0, 8) ?? 'N/A'}...',
                    onTap: () async {
                      await SyncService.cancelAllSubscriptions();
                      await DBHelper().clearAllData();
                      UserService.setAdminSelectedShop(null);
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => ShopSelectorView(setLocale: widget.setLocale)),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
                ShopSwitcherWidget(onShopChanged: () { _loadRole(); _loadShopsForAdmin(); }),

                // ===== CỬA HÀNG =====
                if (isAdminOrOwner) ...[
                  const SizedBox(height: 10),
                  _buildSection('Cửa hàng'),
                  _buildNavTile(icon: Icons.store_outlined, color: Colors.blue, title: 'Thông tin cửa hàng', subtitle: 'Tên, logo, địa chỉ, ảnh bìa', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopSettingsView()))),
                  const SizedBox(height: 6),
                  _buildNavTile(icon: Icons.category_outlined, color: Colors.indigo, title: 'Danh mục sản phẩm', subtitle: 'Thêm, sửa, xóa danh mục', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryManagementView()))),
                  const SizedBox(height: 6),
                  _buildNavTile(icon: Icons.print_outlined, color: Colors.teal, title: 'Máy in nhiệt', subtitle: 'Kết nối máy in Bluetooth', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingsView()))),
                  const SizedBox(height: 6),
                  _buildNavTile(icon: Icons.label_outline, color: Colors.deepOrange, title: 'Tem sản phẩm', subtitle: 'Mẫu tem, kích thước, nội dung', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LabelSettingsView()))),
                  const SizedBox(height: 6),
                  _buildNavTile(icon: Icons.storefront_outlined, color: Colors.orange, title: 'Kết nối KiotViet', subtitle: 'Đồng bộ dữ liệu từ KiotViet', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KiotVietSettingsView()))),
                  const SizedBox(height: 8),
                  _buildToggleCard(
                    icon: Icons.inventory_2_outlined, iconColor: Colors.teal,
                    title: 'Cho phép nhập giá vốn sau',
                    descOff: 'Bắt buộc nhập giá vốn > 0 khi xác nhận nhập kho.',
                    descOn: 'Có thể bỏ qua giá vốn, nhập sau. Sản phẩm chưa có vốn hiện badge cảnh báo.',
                    value: _allowPendingCost, isSaving: _isSavingPendingCost || _shopSettings == null,
                    onTap: () => _saveAllowPendingCost(!_allowPendingCost),
                  ),
                  const SizedBox(height: 4),
                  _buildToggleCard(
                    icon: Icons.local_shipping_outlined, iconColor: Colors.indigo,
                    title: 'Hiển thị nhà cung cấp (NCC)',
                    descOff: 'Ẩn tính năng chọn nhà cung cấp khi nhập kho.',
                    descOn: 'Có thể chọn và theo dõi nhà cung cấp trên từng đơn nhập.',
                    value: _enableSupplier, isSaving: _isSavingSupplier || _shopSettings == null,
                    onTap: () => _saveEnableSupplier(!_enableSupplier),
                  ),
                  if (_enableSupplier) ...[
                    const SizedBox(height: 4),
                    _buildToggleCard(
                      icon: Icons.rule_rounded, iconColor: Colors.deepOrange,
                      title: 'Bắt buộc chọn NCC khi nhập kho',
                      descOff: 'NCC không bắt buộc — có thể bỏ qua khi nhập.',
                      descOn: 'Bắt buộc phải chọn NCC mới được xác nhận nhập kho.',
                      value: _requireSupplier, isSaving: _isSavingRequireSupplier || _shopSettings == null,
                      onTap: () => _saveRequireSupplier(!_requireSupplier),
                    ),
                  ],
                ],

                // ===== NHÂN SỰ =====
                if (isAdminOrOwner) ...[
                  const SizedBox(height: 10),
                  _buildSection('Nhân sự'),
                  _buildNavTile(icon: Icons.schedule_outlined, color: Colors.purple, title: 'Lịch làm việc', subtitle: 'Ca làm, giờ check-in, check-out', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkScheduleSettingsView()))),
                  const SizedBox(height: 6),
                  _buildNavTile(icon: Icons.attach_money, color: Colors.green, title: 'Cài đặt lương', subtitle: 'Mức lương, KPI, hoa hồng', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HRSalarySettingsView()))),
                ],

                // ===== THÔNG BÁO =====
                const SizedBox(height: 10),
                _buildSection('Thông báo'),
                _buildNavTile(icon: Icons.notifications_outlined, color: Colors.amber.shade700, title: 'Cài đặt thông báo', subtitle: 'Âm thanh, kiểu thông báo, push notification', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsView()))),

                // ===== ĐỒNG BỘ & SAO LƯU =====
                const SizedBox(height: 10),
                _buildSection(l.syncManagement),
                _buildNavTile(
                  icon: Icons.cloud_sync_outlined, color: Colors.teal,
                  title: l.syncCenter, subtitle: l.syncCenterDesc,
                  onTap: () => showAppBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => const SyncCenterSheet()),
                ),
                const SizedBox(height: 6),
                _buildNavTile(
                  icon: Icons.upload_rounded, color: Colors.orange.shade700,
                  title: 'Đẩy dữ liệu KiotViet lên Cloud',
                  subtitle: 'Đồng bộ đơn bán và sản phẩm đã import từ KiotViet lên Firestore',
                  isLoading: _isResyncingKiotViet,
                  onTap: _isResyncingKiotViet ? null : _forceResyncKiotViet,
                ),
                const SizedBox(height: 6),
                _buildNavTile(
                  icon: Icons.download_rounded, color: Colors.teal.shade700,
                  title: 'Nhận kho từ Cloud',
                  subtitle: 'Tải toàn bộ sản phẩm từ Firestore về máy này',
                  isLoading: _isPullingFromCloud,
                  onTap: _isPullingFromCloud ? null : _pullKhoFromCloud,
                ),
                const SizedBox(height: 6),
                _buildNavTile(icon: Icons.backup_outlined, color: Colors.blueGrey, title: 'Sao lưu & Khôi phục', subtitle: 'Export/import dữ liệu local', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupRestoreView()))),

                // ===== HỖ TRỢ =====
                const SizedBox(height: 10),
                _buildSection('Hỗ trợ'),
                _buildNavTile(icon: Icons.menu_book_outlined, color: Colors.blue, title: l.userGuideTitle, subtitle: l.userGuideDesc, onTap: _openUserGuide),
                const SizedBox(height: 6),
                _buildNavTile(icon: Icons.support_agent_outlined, color: Colors.indigo, title: 'Trung tâm trợ giúp', subtitle: 'Câu hỏi thường gặp, liên hệ hỗ trợ', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HelpCenterView(userRole: _role)))),

                // ===== QUẢN TRỊ NÂNG CAO (Super Admin) =====
                if (UserService.isCurrentUserSuperAdmin()) ...[
                  const SizedBox(height: 10),
                  _buildSection(l.advancedAdmin),
                  Card(
                    color: Colors.blue.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.blue.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.store, color: Colors.blue.shade700),
                            const SizedBox(width: 10),
                            Text(l.selectShopToViewData, style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: AppTextStyles.headline3.fontSize)),
                          ]),
                          const SizedBox(height: 8),
                          Text(l.viewShopAsAdmin, style: TextStyle(fontSize: AppTextStyles.subtitle1.fontSize, color: Colors.grey)),
                          const SizedBox(height: 8),
                          if (_loadingShops)
                            const Center(child: CircularProgressIndicator())
                          else if (_allShops.isEmpty)
                            Text(l.noShops, style: const TextStyle(color: Colors.grey))
                          else
                            DropdownButtonFormField<String>(
                              value: _selectedShopId != null && _allShops.any((s) => s['id'] == _selectedShopId) ? _selectedShopId : null,
                              decoration: InputDecoration(labelText: l.selectShopLabel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white),
                              hint: Text(l.selectShopPlaceholder),
                              items: _allShops.map((shop) {
                                final shopName = shop['name'] ?? 'Shop ${shop['id']}';
                                final ownerEmail = shop['ownerEmail'] ?? '';
                                return DropdownMenuItem<String>(
                                  value: shop['id'],
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                    Text(shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(ownerEmail, style: TextStyle(fontSize: AppTextStyles.body1.fontSize, color: Colors.grey)),
                                  ]),
                                );
                              }).toList(),
                              onChanged: _onShopSelected,
                              isExpanded: true,
                              selectedItemBuilder: (context) => _allShops.map((shop) => Text(shop['name'] ?? 'Shop ${shop['id']}')).toList(),
                            ),
                          if (_selectedShopId != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                              child: Row(children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(
                                  l.currentlyViewing(_allShops.firstWhere((s) => s['id'] == _selectedShopId, orElse: () => {'name': _selectedShopId})['name'] ?? _selectedShopId),
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                                )),
                              ]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSuperAdminSecurityCard(),
                  const SizedBox(height: 8),
                  _buildNavTile(icon: Icons.admin_panel_settings_outlined, color: Colors.orange, title: l.staffPermissions, subtitle: l.viewAndEditStaffPermissions, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffPermissionsView()))),
                  const SizedBox(height: 8),
                  _buildNavTile(
                    icon: Icons.replay, color: Colors.blue,
                    title: l.reviewUserGuide, subtitle: l.resetGuidesDesc,
                    onTap: () async {
                      await FirstTimeGuideService.resetAllGuides();
                      if (mounted) NotificationService.showSnackBar(l.guidesReset, color: Colors.green);
                    },
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: Colors.red.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.red.shade200)),
                    child: ListTile(
                      leading: const Icon(Icons.delete_forever, color: Colors.red),
                      title: Text(l.resetShopData, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      subtitle: Text(l.resetShopAdminOnly, style: TextStyle(fontSize: AppTextStyles.body1.fontSize)),
                      onTap: _handleResetShop,
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Center(
                  child: FutureBuilder<String>(
                    future: _versionFuture,
                    builder: (context, snapshot) => Text(
                      snapshot.data != null ? l.versionFormat(snapshot.data!) : l.versionFormat('...'),
                      style: TextStyle(color: Colors.grey.shade400, fontSize: AppTextStyles.caption.fontSize),
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildSuperAdminSecurityCard() {
    return Card(
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield, color: Colors.red.shade700, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Bảo mật Super Admin',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Mã PIN bảo vệ khi đăng nhập & nhật ký truy cập',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const Divider(height: 16),
            // PIN Setup/Change
            FutureBuilder<bool>(
              future: SuperAdminSecurityService.isPinSetup(),
              builder: (context, snap) {
                final hasPin = snap.data ?? false;
                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        hasPin ? Icons.lock : Icons.lock_open,
                        color: hasPin ? Colors.green : Colors.orange,
                      ),
                      title: Text(
                        hasPin ? 'Mã PIN đã bật' : 'Mã PIN chưa thiết lập',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        hasPin
                            ? 'Mỗi lần đăng nhập sẽ yêu cầu nhập PIN'
                            : 'Bật PIN để bảo vệ tài khoản super admin',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: hasPin
                          ? PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'change') _showSetupPinDialog(isChange: true);
                                if (val == 'remove') _showRemovePinDialog();
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'change', child: Text('Đổi PIN')),
                                const PopupMenuItem(value: 'remove', child: Text('Tắt PIN')),
                              ],
                            )
                          : TextButton(
                              onPressed: () => _showSetupPinDialog(),
                              child: const Text('Thiết lập'),
                            ),
                    ),
                    const Divider(height: 8),
                    // Audit Log
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history, color: Colors.deepPurple),
                      title: const Text(
                        'Nhật ký truy cập',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Xem lịch sử đăng nhập & thao tác',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: _showAuditLogDialog,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSetupPinDialog({bool isChange = false}) {
    final pinC = TextEditingController();
    final confirmC = TextEditingController();
    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.pin, color: Colors.deepPurple),
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
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmC,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Nhập lại mã PIN',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('HỦY'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (pinC.text != confirmC.text) {
                  setDialogState(() => error = 'Mã PIN không khớp');
                  return;
                }
                if (pinC.text.length < 4) {
                  setDialogState(() => error = 'PIN phải từ 4-6 số');
                  return;
                }
                final ok = await SuperAdminSecurityService.setupPin(pinC.text);
                if (ok && mounted) {
                  Navigator.pop(ctx);
                  setState(() {}); // Refresh card
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Đã thiết lập mã PIN thành công!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  setDialogState(() => error = 'Lỗi thiết lập PIN');
                }
              },
              child: const Text('XÁC NHẬN'),
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
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_open, color: Colors.red),
              SizedBox(width: 8),
              Text('Tắt mã PIN'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nhập mã PIN hiện tại để xác nhận tắt:'),
              const SizedBox(height: 12),
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
              child: const Text('HỦY'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final verified = await SuperAdminSecurityService.verifyPin(pinC.text);
                if (!verified) {
                  setDialogState(() => error = 'Mã PIN không đúng');
                  return;
                }
                await SuperAdminSecurityService.removePin();
                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã tắt mã PIN'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: const Text('TẮT PIN', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAuditLogDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Nhật ký truy cập'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: SuperAdminSecurityService.getRecentAuditLogs(limit: 30),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final logs = snap.data ?? [];
              if (logs.isEmpty) {
                return const Center(
                  child: Text('Chưa có nhật ký', style: TextStyle(color: Colors.grey)),
                );
              }
              return ListView.separated(
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final log = logs[i];
                  final action = log['action'] as String? ?? '';
                  final success = log['success'] as bool? ?? true;
                  final ts = log['timestamp'];
                  final platform = log['platform'] as String? ?? '';
                  String timeStr = '—';
                  if (ts is Timestamp) {
                    timeStr = _formatAuditTime(ts.toDate());
                  }
                  IconData icon;
                  Color color;
                  if (action.contains('login')) {
                    icon = Icons.login;
                    color = Colors.blue;
                  } else if (action.contains('shop_access')) {
                    icon = Icons.store;
                    color = Colors.green;
                  } else if (action.contains('pin_verified')) {
                    icon = Icons.check_circle;
                    color = Colors.green;
                  } else if (action.contains('failed')) {
                    icon = Icons.warning;
                    color = Colors.red;
                  } else {
                    icon = Icons.info;
                    color = Colors.grey;
                  }
                  return ListTile(
                    dense: true,
                    leading: Icon(icon, color: success ? color : Colors.red, size: 20),
                    title: Text(
                      _formatAuditAction(action),
                      style: TextStyle(fontSize: 13, color: success ? Colors.black87 : Colors.red),
                    ),
                    subtitle: Text(
                      '$timeStr · $platform',
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ĐÓNG'),
          ),
        ],
      ),
    );
  }

  String _formatAuditTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatAuditAction(String action) {
    if (action == 'super_admin_login') return 'Đăng nhập Super Admin';
    if (action == 'pin_verified') return 'Xác thực PIN thành công';
    if (action == 'pin_verify_failed') return '⚠ Nhập PIN sai';
    if (action.startsWith('shop_access:')) {
      return 'Truy cập shop: ${action.replaceFirst('shop_access: ', '')}';
    }
    return action;
  }

  /// Card tài khoản tổng hợp: user info + liên kết + đăng xuất
  Widget _buildAccountCard(AppLocalizations localizations) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'N/A';
    final displayName =
      _profileDisplayName ?? user?.displayName ?? email.split('@').first;
    final photoUrl =
      (_profilePhotoUrl != null && _profilePhotoUrl!.trim().isNotEmpty)
      ? _profilePhotoUrl
      : user?.photoURL;
    final googleLinked = SocialAuthService.isGoogleLinked();
    final appleLinked = SocialAuthService.isAppleLinked();
    final passwordLinked = SocialAuthService.isPasswordLinked();
    final showApple = kIsWeb || (!kIsWeb && Platform.isIOS) || (!kIsWeb && Platform.isMacOS);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info row
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage:
                          photoUrl != null ? NetworkImage(photoUrl) : null,
                      backgroundColor: Colors.blue.shade100,
                      child: photoUrl == null
                          ? Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _updatingAvatar ? null : _pickAndUploadMyAvatar,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: _updatingAvatar
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                    color: Colors.blue,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _getRoleDisplayName(_role, localizations),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Linked accounts section
            Row(
              children: [
                const Icon(Icons.link, color: Colors.indigo, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Liên kết tài khoản',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildProviderRow(
              icon: Icons.email,
              color: Colors.blue,
              label: 'Email/Mật khẩu',
              linked: passwordLinked,
              onLink: null,
              onUnlink: null,
              providerEmail: SocialAuthService.passwordEmail,
            ),
            const SizedBox(height: 6),
            _buildProviderRow(
              icon: Icons.g_mobiledata,
              color: Colors.red,
              label: 'Google',
              linked: googleLinked,
              onLink: () => _linkProvider('google'),
              onUnlink: googleLinked && SocialAuthService.getLinkedProviders().length > 1
                  ? () => _unlinkProvider('google')
                  : null,
              providerEmail: SocialAuthService.googleEmail,
            ),
            if (showApple) ...[
              const SizedBox(height: 6),
              _buildProviderRow(
                icon: Icons.apple,
                color: Colors.black,
                label: 'Apple',
                linked: appleLinked,
                onLink: () => _linkProvider('apple'),
                onUnlink: appleLinked && SocialAuthService.getLinkedProviders().length > 1
                    ? () => _unlinkProvider('apple')
                    : null,
                providerEmail: SocialAuthService.appleEmail,
              ),
            ],
            const Divider(height: 20),

            // Logout button
            InkWell(
              onTap: () => _confirmLogout(localizations),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: Colors.red, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      localizations.logoutAccount,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(AppLocalizations localizations) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.logoutQuestion),
        content: Text(localizations.confirmLogout),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(localizations.cancel.toUpperCase()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              localizations.logout.toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try { await SyncService.cancelAllSubscriptions(); } catch (_) {}
      try { EncryptionService.reset(); } catch (_) {}
      try { UserService.clearCache(); } catch (_) {}
      try { UserService.setAdminSelectedShop(null); } catch (_) {}
      try { SuperAdminSecurityService.clearSession(); } catch (_) {}
      try { await DBHelper().clearAllData(); } catch (_) {}
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('Logout error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.logoutError(e.toString()))),
          );
        }
      }
    }
  }

  Widget _buildProviderRow({
    required IconData icon,
    required Color color,
    required String label,
    required bool linked,
    VoidCallback? onLink,
    VoidCallback? onUnlink,
    String? providerEmail,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              if (linked && providerEmail != null && providerEmail.isNotEmpty)
                Text(providerEmail, style: TextStyle(fontSize: 11, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (linked)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
              const SizedBox(width: 4),
              Text(
                'Đã liên kết',
                style: TextStyle(fontSize: 12, color: Colors.green.shade700),
              ),
              if (onUnlink != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onUnlink,
                  child: Text(
                    'Hủy',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade400,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          )
        else if (onLink != null)
          TextButton.icon(
            onPressed: onLink,
            icon: Icon(Icons.add_link, size: 16, color: color),
            label: Text(
              'Liên kết',
              style: TextStyle(fontSize: 13, color: color),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  Future<void> _linkProvider(String provider) async {
    try {
      UserCredential? result;
      if (provider == 'google') {
        result = await SocialAuthService.linkGoogle();
      } else if (provider == 'apple') {
        result = await SocialAuthService.linkApple();
      }
      // Force refresh to get updated providerData
      await FirebaseAuth.instance.currentUser?.reload();
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (mounted) {
        setState(() {}); // Refresh UI
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Đã liên kết $provider thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // null = user cancelled, no snackbar needed
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Lỗi liên kết $provider'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, maxLines: 4),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _unlinkProvider(String provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy liên kết'),
        content: Text(
          'Bạn có chắc muốn hủy liên kết $provider? '
          'Bạn sẽ không thể đăng nhập bằng $provider nữa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('XÁC NHẬN', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      if (provider == 'google') {
        await SocialAuthService.unlinkGoogle();
      } else if (provider == 'apple') {
        await SocialAuthService.unlinkApple();
      }
      await FirebaseAuth.instance.currentUser?.reload();
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã hủy liên kết $provider'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi hủy liên kết: $e')),
        );
      }
    }
  }

  Widget _buildToggleCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String descOff,
    required String descOn,
    required bool value,
    required bool isSaving,
    required VoidCallback onTap,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: isSaving ? null : (_) => onTap(),
      activeColor: iconColor,
      checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      secondary: isSaving
          ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: iconColor))
          : Icon(icon, color: value ? iconColor : Colors.grey, size: 24),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(
        value ? descOn : descOff,
        style: TextStyle(fontSize: 12, color: value ? iconColor : Colors.grey.shade600),
      ),
      controlAffinity: ListTileControlAffinity.trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildSection(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: AppTextStyles.caption.fontSize,
        color: Colors.blueGrey,
      ),
    ),
  );

  Widget _buildNavTile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: isLoading
            ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: color))
            : Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: subtitle != null
            ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
            : null,
        trailing: onTap != null ? Icon(Icons.chevron_right, color: Colors.grey.shade400) : null,
        onTap: onTap,
      ),
    );
  }
}
