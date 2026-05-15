import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
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
import '../utils/app_info.dart';
import '../services/first_time_guide_service.dart';
import '../widgets/unified_sync_button.dart';
import '../widgets/shop_switcher_widget.dart';
import '../widgets/custom_app_bar.dart';
import 'help_center_view.dart';
import 'user_guide_view.dart';
import 'shop_selector_view.dart';
import 'staff_permissions_view.dart';
import 'category_management_view.dart';
import '../widgets/responsive_wrapper.dart';

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
  
  // Current selected locale
  // Language selection hidden — Vietnamese only

  @override
  void initState() {
    super.initState();
    _versionFuture = AppInfo.getVersion();
    _loadRole();
    _loadCurrentUserProfile();
    _loadShopsForAdmin();
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

  Future<void> _pickAndUploadMyAvatar() async {
    if (_updatingAvatar) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      NotificationService.showSnackBar('Vui lòng đăng nhập lại', color: AppColors.error);
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
      color: AppColors.primary,
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
        color: AppColors.success,
      );
    } catch (e) {
      debugPrint('Error switching shop: $e');
      NotificationService.showSnackBar(
        loc.errorSwitchingShop(e.toString()),
        color: AppColors.error,
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

  void _openHelpCenter() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HelpCenterView(userRole: _role),
      ),
    );
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
        color: AppColors.error,
      );
      return;
    }

    final confirmTextC = TextEditingController();
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          loc.dangerWarning,
          style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(
              loc.confirmDeleteAll,
              style: const TextStyle(color: AppColors.surface),
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
          color: AppColors.success,
        );
      } else {
        NotificationService.showSnackBar(
          loc.errorDeletingCloudData(errorMessage),
          color: AppColors.error,
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
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: CustomAppBar.build(
        title: localizations.systemSettings,
      ),
      body: ResponsiveCenter(
        maxWidth: 800,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(10),
              children: [
                // ====== TÀI KHOẢN & BẢO MẬT - ĐẶT LÊN ĐẦU ĐỂ DỄ TÌM ======
                _buildSection(localizations.accountAndSecurity),
                // Card tài khoản gọn: avatar + tên + email + role + liên kết + đăng xuất
                _buildAccountCard(localizations),
                const SizedBox(height: 8),

                // NÚT CHỌN SHOP KHÁC - Chỉ hiện cho Super Admin
                if (UserService.isCurrentUserSuperAdmin()) ...[
                  Card(
                    color: AppColors.repairDelivered,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: AppColors.repairDelivered),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.swap_horiz,
                        color: AppColors.repairDelivered,
                      ),
                      title: Text(
                        localizations.selectOtherShop,
                        style: const TextStyle(
                          color: AppColors.repairDelivered,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "${localizations.currentShop}: ${UserService.getAdminSelectedShop()?.substring(0, 8) ?? 'N/A'}...",
                        style: TextStyle(
                          fontSize: AppTextStyles.body1.fontSize,
                        ),
                      ),
                      onTap: () async {
                        await SyncService.cancelAllSubscriptions();
                        await DBHelper().clearAllData();
                        UserService.setAdminSelectedShop(null);
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) =>
                                  ShopSelectorView(setLocale: widget.setLocale),
                            ),
                            (route) => false,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // ====== SHOP SWITCHER (Owner với nhiều shop) ======
                ShopSwitcherWidget(
                  onShopChanged: () {
                    // Reload settings when shop changes
                    _loadRole();
                    _loadShopsForAdmin();
                  },
                ),
                
                // ====== HƯỚNG DẪN SỬ DỤNG - MOVE LÊN ĐẦU ĐỂ DỄ TÌM ======
                _buildSection(loc.userGuideSection),
                
                // Card chính: Hướng dẫn sử dụng đầy đủ
                Card(
                  color: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: AppColors.primary),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(10),
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(77),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.surface,
                        size: 28,
                      ),
                    ),
                    title: Text(
                      loc.userGuideTitle,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          loc.userGuideDesc,
                          style: TextStyle(
                            fontSize: AppTextStyles.body1.fontSize,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildFeatureChip(loc.inventoryFeature, AppColors.primary),
                            _buildFeatureChip(loc.salesFeature, AppColors.warning),
                            _buildFeatureChip(loc.repairFeature, AppColors.primary),
                            _buildFeatureChip(loc.reportFeature, AppColors.error),
                          ],
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    onTap: _openUserGuide,
                  ),
                ),

                // ĐỒNG BỘ DỮ LIỆU - Chỉ còn 1 entry point duy nhất
                const SizedBox(height: 10),
                _buildSection(localizations.syncManagement),
                // Card đơn giản mở Trung tâm đồng bộ
                Card(
                  color: AppColors.info,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: AppColors.info),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.info,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cloud_sync,
                        color: AppColors.info,
                        size: 28,
                      ),
                    ),
                    title: Text(
                      localizations.syncCenter,
                      style: const TextStyle(
                        color: AppColors.info,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      localizations.syncCenterDesc,
                      style: TextStyle(fontSize: AppTextStyles.body1.fontSize),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.info,
                    ),
                    onTap: () {
                      showAppBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const SyncCenterSheet(),
                      );
                    },
                  ),
                ),

                // ====== QUẢN LÝ CỬA HÀNG ======
                const SizedBox(height: 10),
                _buildSection('Quản lý cửa hàng'),
                
                // Quản lý danh mục sản phẩm
                if (_role == 'owner' || UserService.isCurrentUserSuperAdmin())
                  Card(
                    color: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: AppColors.primary),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.category,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      title: const Text(
                        'Quản lý danh mục',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Thêm, sửa, xóa danh mục sản phẩm',
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CategoryManagementView(),
                          ),
                        );
                      },
                    ),
                  ),

                // NÚT XÓA TRẮNG CHỈ HIỆN CHO SUPER ADMIN
                if (UserService.isCurrentUserSuperAdmin()) ...[
                  const SizedBox(height: 10),
                  _buildSection(localizations.advancedAdmin),

                  // DROPDOWN CHỌN SHOP
                  Card(
                    color: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: AppColors.primary),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.store, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Text(
                                localizations.selectShopToViewData,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppTextStyles.headline3.fontSize,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),


                          Text(
                            localizations.viewShopAsAdmin,
                            style: TextStyle(
                              fontSize: AppTextStyles.subtitle1.fontSize,
                              color: AppColors.textHint,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_loadingShops)
                            const Center(child: CircularProgressIndicator())
                          else if (_allShops.isEmpty)
                            Text(
                              localizations.noShops,
                              style: const TextStyle(color: AppColors.textHint),
                            )
                          else
                            DropdownButtonFormField<String>(
                              // Safety: ensure value exists in items to prevent assertion error
                              value: _selectedShopId != null &&
                                      _allShops.any((s) => s['id'] == _selectedShopId)
                                  ? _selectedShopId
                                  : null,
                              decoration: InputDecoration(
                                labelText: localizations.selectShopLabel,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: AppColors.surface,
                              ),
                              hint: Text(localizations.selectShopPlaceholder),
                              items: _allShops.map((shop) {
                                final shopName =
                                    shop['name'] ?? 'Shop ${shop['id']}';
                                final ownerEmail = shop['ownerEmail'] ?? '';
                                return DropdownMenuItem<String>(
                                  value: shop['id'],
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        shopName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        ownerEmail,
                                        style: TextStyle(
                                          fontSize:
                                              AppTextStyles.body1.fontSize,
                                          color: AppColors.textHint,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: _onShopSelected,
                              isExpanded: true,
                              selectedItemBuilder: (context) {
                                return _allShops.map((shop) {
                                  return Text(
                                    shop['name'] ?? 'Shop ${shop['id']}',
                                  );
                                }).toList();
                              },
                            ),
                          if (_selectedShopId != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.success,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppColors.success,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      localizations.currentlyViewing(
                                        _allShops.firstWhere(
                                              (s) => s['id'] == _selectedShopId,
                                              orElse: () => {
                                                'name': _selectedShopId,
                                              },
                                            )['name'] ??
                                            _selectedShopId,
                                      ),
                                      style: const TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // BẢO MẬT SUPER ADMIN - PIN & Audit
                  _buildSuperAdminSecurityCard(),
                  const SizedBox(height: 8),

                  Card(
                    color: AppColors.warning,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: AppColors.warning),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.admin_panel_settings,
                        color: AppColors.warning,
                      ),
                      title: Text(
                        localizations.staffPermissions,
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        localizations.viewAndEditStaffPermissions,
                        style: TextStyle(
                          fontSize: AppTextStyles.body1.fontSize,
                        ),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StaffPermissionsView(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Nút reset hướng dẫn sử dụng
                  Card(
                    color: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: AppColors.primary),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.replay,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        loc.reviewUserGuide,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        loc.resetGuidesDesc,
                        style: TextStyle(
                          fontSize: AppTextStyles.body1.fontSize,
                        ),
                      ),
                      onTap: () async {
                        await FirstTimeGuideService.resetAllGuides();
                        if (mounted) {
                          NotificationService.showSnackBar(
                            loc.guidesReset,
                            color: AppColors.success,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: AppColors.error),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.delete_forever,
                        color: AppColors.error,
                      ),
                      title: Text(
                        localizations.resetShopData,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        localizations.resetShopAdminOnly,
                        style: TextStyle(
                          fontSize: AppTextStyles.body1.fontSize,
                        ),
                      ),
                      onTap: _handleResetShop,
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Center(
                  child: FutureBuilder<String>(
                    future: _versionFuture,
                    builder: (context, snapshot) {
                      final versionText = snapshot.data != null
                          ? localizations.versionFormat(snapshot.data!)
                          : '${localizations.versionFormat('...')}';
                      return Text(
                        versionText,
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: AppTextStyles.caption.fontSize,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildSuperAdminSecurityCard() {
    return Card(
      color: AppColors.error,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: AppColors.error),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield, color: AppColors.error, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Bảo mật Super Admin',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Mã PIN bảo vệ khi đăng nhập & nhật ký truy cập',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                        color: hasPin ? AppColors.success : AppColors.warning,
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
                      leading: const Icon(Icons.history, color: AppColors.repairDelivered),
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
              const Icon(Icons.pin, color: AppColors.repairDelivered),
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
                      backgroundColor: AppColors.success,
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
              Icon(Icons.lock_open, color: AppColors.error),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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
                      backgroundColor: AppColors.warning,
                    ),
                  );
                }
              },
              child: const Text('TẮT PIN', style: TextStyle(color: AppColors.surface)),
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
            Icon(Icons.history, color: AppColors.repairDelivered),
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
                  child: Text('Chưa có nhật ký', style: TextStyle(color: AppColors.textHint)),
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
                    color = AppColors.primary;
                  } else if (action.contains('shop_access')) {
                    icon = Icons.store;
                    color = AppColors.success;
                  } else if (action.contains('pin_verified')) {
                    icon = Icons.check_circle;
                    color = AppColors.success;
                  } else if (action.contains('failed')) {
                    icon = Icons.warning;
                    color = AppColors.error;
                  } else {
                    icon = Icons.info;
                    color = AppColors.textHint;
                  }
                  return ListTile(
                    dense: true,
                    leading: Icon(icon, color: success ? color : AppColors.error, size: 20),
                    title: Text(
                      _formatAuditAction(action),
                      style: TextStyle(fontSize: 13, color: success ? AppColors.textPrimary : AppColors.error),
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
                      backgroundColor: AppColors.primary,
                      child: photoUrl == null
                          ? Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Material(
                        color: AppColors.surface,
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
                                    color: AppColors.primary,
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
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _getRoleDisplayName(_role, localizations),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Linked accounts section
            Row(
              children: [
                const Icon(Icons.link, color: AppColors.primary, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Liên kết tài khoản',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildProviderRow(
              icon: Icons.email,
              color: AppColors.primary,
              label: 'Email/Mật khẩu',
              linked: passwordLinked,
              onLink: null,
              onUnlink: null,
              providerEmail: SocialAuthService.passwordEmail,
            ),
            const SizedBox(height: 6),
            _buildProviderRow(
              icon: Icons.g_mobiledata,
              color: AppColors.error,
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
                color: AppColors.textPrimary,
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

            // Đổi mật khẩu (chỉ hiển thị khi dùng Email/Password)
            if (passwordLinked) ...[
              InkWell(
                onTap: _showChangePasswordDialog,
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.lock_reset, color: AppColors.warning, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Đổi mật khẩu',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],

            // Logout button
            InkWell(
              onTap: () => _confirmLogout(localizations),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      localizations.logoutAccount,
                      style: const TextStyle(
                        color: AppColors.error,
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

  Future<void> _showChangePasswordDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? errorText;
    bool loading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: AppColors.warning),
              SizedBox(width: 8),
              Text('Đổi mật khẩu'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorText != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Text(errorText!, style: TextStyle(color: AppColors.error, fontSize: 13)),
                  ),
                TextField(
                  controller: currentPassCtrl,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu hiện tại',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPassCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu mới (tối thiểu 6 ký tự)',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPassCtrl,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Xác nhận mật khẩu mới',
                    prefixIcon: const Icon(Icons.lock_clock),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
              onPressed: loading
                  ? null
                  : () async {
                      final currentPass = currentPassCtrl.text.trim();
                      final newPass = newPassCtrl.text.trim();
                      final confirmPass = confirmPassCtrl.text.trim();
                      if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                        setDialogState(() => errorText = 'Vui lòng điền đầy đủ thông tin');
                        return;
                      }
                      if (newPass.length < 6) {
                        setDialogState(() => errorText = 'Mật khẩu mới phải có ít nhất 6 ký tự');
                        return;
                      }
                      if (newPass != confirmPass) {
                        setDialogState(() => errorText = 'Mật khẩu xác nhận không khớp');
                        return;
                      }
                      setDialogState(() { loading = true; errorText = null; });
                      try {
                        final credential = EmailAuthProvider.credential(
                          email: user.email!,
                          password: currentPass,
                        );
                        await user.reauthenticateWithCredential(credential);
                        await user.updatePassword(newPass);
                        if (ctx.mounted) Navigator.pop(ctx);
                        NotificationService.showSnackBar('Đổi mật khẩu thành công', color: AppColors.success);
                      } on FirebaseAuthException catch (e) {
                        String msg;
                        switch (e.code) {
                          case 'wrong-password':
                            msg = 'Mật khẩu hiện tại không đúng';
                          case 'weak-password':
                            msg = 'Mật khẩu mới quá yếu (tối thiểu 6 ký tự)';
                          case 'too-many-requests':
                            msg = 'Quá nhiều lần thử, vui lòng thử lại sau';
                          default:
                            msg = 'Lỗi: ${e.message}';
                        }
                        setDialogState(() { loading = false; errorText = msg; });
                      } catch (e) {
                        setDialogState(() { loading = false; errorText = 'Lỗi không xác định: $e'; });
                      }
                    },
              child: loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface))
                  : const Text('Xác nhận', style: TextStyle(color: AppColors.surface)),
            ),
          ],
        ),
      ),
    );

    currentPassCtrl.dispose();
    newPassCtrl.dispose();
    confirmPassCtrl.dispose();
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(
              localizations.logout.toUpperCase(),
              style: const TextStyle(color: AppColors.surface),
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

  Widget _buildLinkedAccountsCard() {
    final googleLinked = SocialAuthService.isGoogleLinked();
    final appleLinked = SocialAuthService.isAppleLinked();
    final passwordLinked = SocialAuthService.isPasswordLinked();
    final showApple = kIsWeb || (!kIsWeb && Platform.isIOS) || (!kIsWeb && Platform.isMacOS);

    return Card(
      color: AppColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: AppColors.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Liên kết tài khoản',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Liên kết để đăng nhập nhanh hơn',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const Divider(height: 16),
            // Email/Password
            _buildProviderRow(
              icon: Icons.email,
              color: AppColors.primary,
              label: 'Email/Mật khẩu',
              linked: passwordLinked,
              onLink: null, // Always linked by default
              onUnlink: null, // Cannot unlink if it's the only method
              providerEmail: SocialAuthService.passwordEmail,
            ),
            const SizedBox(height: 8),
            // Google
            _buildProviderRow(
              icon: Icons.g_mobiledata,
              color: AppColors.error,
              label: 'Google',
              linked: googleLinked,
              onLink: () => _linkProvider('google'),
              onUnlink: googleLinked && SocialAuthService.getLinkedProviders().length > 1
                  ? () => _unlinkProvider('google')
                  : null,
              providerEmail: SocialAuthService.googleEmail,
            ),
            // Apple (only on iOS/macOS/web)
            if (showApple) ...[
              const SizedBox(height: 8),
              _buildProviderRow(
                icon: Icons.apple,
                color: AppColors.textPrimary,
                label: 'Apple',
                linked: appleLinked,
                onLink: () => _linkProvider('apple'),
                onUnlink: appleLinked && SocialAuthService.getLinkedProviders().length > 1
                    ? () => _unlinkProvider('apple')
                    : null,
                providerEmail: SocialAuthService.appleEmail,
              ),
            ],
          ],
        ),
      ),
    );
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
                Text(providerEmail, style: TextStyle(fontSize: 11, color: AppColors.textHint), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (linked)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 18),
              const SizedBox(width: 4),
              Text(
                'Đã liên kết',
                style: TextStyle(fontSize: 12, color: AppColors.success),
              ),
              if (onUnlink != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onUnlink,
                  child: Text(
                    'Hủy',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
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
              backgroundColor: AppColors.success,
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
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, maxLines: 4),
            backgroundColor: AppColors.error,
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('XÁC NHẬN', style: TextStyle(color: AppColors.surface)),
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
            backgroundColor: AppColors.warning,
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

  Widget _buildSection(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: AppTextStyles.caption.fontSize,
        color: AppColors.textSecondary,
      ),
    ),
  );

  Widget _buildFeatureChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
