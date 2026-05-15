import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/responsive_wrapper.dart';
import '../services/user_service.dart';
import '../services/claims_service.dart';
import '../services/super_admin_security_service.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_spacing.dart';
import '../l10n/app_localizations.dart';

String getRoleDisplayName(String role) {
  switch (role) {
    case 'owner':
      return 'Chủ shop';
    case 'manager':
      return 'Quản lý';
    case 'employee':
      return 'Nhân viên';
    case 'technician':
      return 'Kỹ thuật';
    case 'admin':
      return 'Admin';
    case 'user':
      return 'Người dùng';
    default:
      return role;
  }
}

class SuperAdminView extends StatelessWidget {
  const SuperAdminView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0068FF), Color(0xFF0084FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          title: Text(
            'SUPER ADMIN CONTROL',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: AppTextStyles.headline3.fontSize,
            ),
          ),
          bottom: const TabBar(
            labelColor: AppColors.surface,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.surface,
            tabs: [
              Tab(text: 'SHOPS'),
              Tab(text: 'USERS'),
            ],
          ),
        ),
        body: ResponsiveCenter(
          child: const TabBarView(children: [ShopsTab(), UsersTab()]),
        ),
      ),
    );
  }
}

class ShopsTab extends StatefulWidget {
  const ShopsTab({super.key});

  @override
  State<ShopsTab> createState() => _ShopsTabState();
}

class _ShopsTabState extends State<ShopsTab> {
  bool _isSyncingClaims = false;
  late final Stream<QuerySnapshot> _shopsStream;
  final Map<String, List<QueryDocumentSnapshot>> _shopMembersCache = {};
  final Set<String> _loadingShopMembers = <String>{};

  @override
  void initState() {
    super.initState();
    _shopsStream = UserService.getAllShopsStreamForSuperAdmin();
  }

  Future<void> _loadShopMembers(String shopId, {bool force = false}) async {
    if (_loadingShopMembers.contains(shopId)) return;
    if (!force && _shopMembersCache.containsKey(shopId)) return;

    setState(() => _loadingShopMembers.add(shopId));
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('shopId', isEqualTo: shopId)
          .limit(20)
          .get();
      if (!mounted) return;
      setState(() {
        _shopMembersCache[shopId] = snap.docs;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _shopMembersCache[shopId] = const [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingShopMembers.remove(shopId));
      }
    }
  }

  Future<void> _syncAllClaims() async {
    setState(() => _isSyncingClaims = true);

    try {
      final result = await ClaimsService().batchSyncAllClaims();

      if (!mounted) return;

      if (result['success'] == true) {
        // Safely cast stats map
        final statsRaw = result['stats'];
        final stats = statsRaw is Map
            ? Map<String, dynamic>.from(statsRaw)
            : <String, dynamic>{};
        final total = stats['total'] ?? 0;
        final success = stats['success'] ?? 0;
        final skipped = stats['skipped'] ?? 0;
        final failed = stats['failed'] ?? 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Đồng bộ hoàn tất!\n'
              'Tổng: $total | Thành công: $success | Bỏ qua: $skipped | Lỗi: $failed',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi: ${result['error'] ?? 'Không xác định'}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lỗi: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncingClaims = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _shopsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Chưa có shop nào được tạo',
                  style: TextStyle(color: AppColors.textHint),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tải lại'),
                ),
              ],
            ),
          );
        }

        // Filter out metadata-only events with no actual docs
        final allDocs = snapshot.data!.docs;
        final shops = allDocs.toList()
          ..sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['createdAt'];
            final bTime = (b.data() as Map<String, dynamic>)['createdAt'];
            if (aTime is Timestamp && bTime is Timestamp)
              return bTime.compareTo(aTime);
            if (aTime is Timestamp) return -1;
            if (bTime is Timestamp) return 1;
            return 0;
          });
        final isFromCache = snapshot.data!.metadata.isFromCache;
        return ListView(
          padding: const EdgeInsets.all(15),
          children: [
            _buildIntroCard(context),
            const SizedBox(height: 12),
            if (isFromCache)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Dữ liệu từ cache — kéo xuống để tải lại',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            _buildClaimsSyncCard(),
            const SizedBox(height: 12),
            _buildStatsCard(shops.length),
            const SizedBox(height: 12),
            ...shops.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final shopId = doc.id;
              final shopName = data['name'] ?? 'Shop chưa đặt tên';
              final ownerEmail =
                  data['ownerEmail'] ?? 'Không rõ email chủ shop';
              final ownerUid = data['ownerUid'] ?? 'Không rõ UID chủ shop';
              final createdAt = data['createdAt'];
              final appLocked = data['appLocked'] == true;
              final adminFinanceLocked = data['adminFinanceLocked'] == true;
              final staffSalesLocked = data['staffSalesLocked'] == true;
              final staffInventoryLocked = data['staffInventoryLocked'] == true;
              final staffDebtLocked = data['staffDebtLocked'] == true;
              final staffSettingsLocked = data['staffSettingsLocked'] == true;

              String createdText = 'Chưa rõ ngày tạo';
              if (createdAt is Timestamp) {
                createdText =
                    'Tạo: ${createdAt.toDate().toString().substring(0, 16)}';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ExpansionTile(
                  onExpansionChanged: (expanded) {
                    if (expanded) {
                      _loadShopMembers(shopId);
                    }
                  },
                  leading: Icon(
                    appLocked ? Icons.lock : Icons.store_mall_directory,
                    color: appLocked ? AppColors.error : Colors.blueAccent,
                  ),
                  title: Text(
                    shopName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTextStyles.headline4.fontSize,
                      color: appLocked ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ID: $shopId',
                        style: TextStyle(
                          fontSize: AppTextStyles.body1.fontSize,
                          color: AppColors.textHint,
                        ),
                      ),
                      Text(
                        ownerEmail,
                        style: TextStyle(
                          fontSize: AppTextStyles.body1.fontSize,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Owner UID: $ownerUid',
                            style: TextStyle(
                              fontSize: AppTextStyles.body1.fontSize,
                              color: AppColors.textHint,
                            ),
                          ),
                          Text(
                            createdText,
                            style: TextStyle(
                              fontSize: AppTextStyles.body1.fontSize,
                              color: AppColors.textHint,
                            ),
                          ),
                          const Divider(height: 20),
                          Text(
                            '🔐 ĐIỀU KHIỂN SUPER ADMIN',
                            style: TextStyle(
                              fontSize: AppTextStyles.headline5.fontSize,
                              fontWeight: FontWeight.bold,
                              color: AppColors.repairDelivered,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildLockSwitch(
                            context: context,
                            title: '🚫 KHÓA TOÀN BỘ APP',
                            subtitle:
                                'Mọi tài khoản của shop không truy cập được app.',
                            value: appLocked,
                            onChanged: (v) => _updateFlag(
                              context,
                              shopId,
                              'appLocked',
                              v,
                              'toàn bộ app',
                            ),
                            isDestructive: true,
                          ),
                          _buildLockSwitch(
                            context: context,
                            title: '💰 KHÓA TÀI CHÍNH CHO QUẢN LÝ',
                            subtitle:
                                'Quản lý không xem được doanh thu, chi phí, công nợ.',
                            value: adminFinanceLocked,
                            onChanged: (v) => _updateFlag(
                              context,
                              shopId,
                              'adminFinanceLocked',
                              v,
                              'tài chính quản lý',
                            ),
                          ),
                          const Divider(height: 20),
                          Text(
                            '👷 KHÓA CHỨC NĂNG CHO NHÂN VIÊN',
                            style: TextStyle(
                              fontSize: AppTextStyles.headline5.fontSize,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildLockSwitch(
                            context: context,
                            title: '🛒 KHÓA XEM BÁN HÀNG',
                            subtitle:
                                'Nhân viên không xem được danh sách bán hàng.',
                            value: staffSalesLocked,
                            onChanged: (v) => _updateFlag(
                              context,
                              shopId,
                              'staffSalesLocked',
                              v,
                              'bán hàng nhân viên',
                            ),
                          ),
                          _buildLockSwitch(
                            context: context,
                            title: '📦 KHÓA XEM KHO',
                            subtitle: 'Nhân viên không xem được kho hàng.',
                            value: staffInventoryLocked,
                            onChanged: (v) => _updateFlag(
                              context,
                              shopId,
                              'staffInventoryLocked',
                              v,
                              'kho nhân viên',
                            ),
                          ),
                          _buildLockSwitch(
                            context: context,
                            title: '📋 KHÓA XEM CÔNG NỢ',
                            subtitle: 'Nhân viên không xem được sổ công nợ.',
                            value: staffDebtLocked,
                            onChanged: (v) => _updateFlag(
                              context,
                              shopId,
                              'staffDebtLocked',
                              v,
                              'công nợ nhân viên',
                            ),
                          ),
                          _buildLockSwitch(
                            context: context,
                            title: '⚙️ KHÓA CÀI ĐẶT',
                            subtitle:
                                'Nhân viên & Quản lý không vào được trang Cài đặt.',
                            value: staffSettingsLocked,
                            onChanged: (v) => _updateFlag(
                              context,
                              shopId,
                              'staffSettingsLocked',
                              v,
                              'cài đặt',
                            ),
                          ),
                          const Divider(height: 20),
                          Text(
                            '👥 THÀNH VIÊN TRONG SHOP',
                            style: AppTextStyles.headline5.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildShopMembersList(shopId),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildShopMembersList(String shopId) {
    final isLoading = _loadingShopMembers.contains(shopId);
    final members = _shopMembersCache[shopId];

    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (members == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: TextButton.icon(
          onPressed: () => _loadShopMembers(shopId, force: true),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Tải thành viên'),
        ),
      );
    }

    if (members.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(
          'Không có thành viên',
          style: AppTextStyles.subtitle1.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: members.map((doc) {
            final userData = doc.data() as Map<String, dynamic>;
            final email = userData['email'] ?? 'Không có email';
            final displayName = userData['displayName'] ?? '';
            final role = userData['role'] ?? 'user';
            final phone = userData['phone'] ?? '';

            // Map role to Vietnamese
            String roleText;
            Color roleColor;
            IconData roleIcon;
            switch (role) {
              case 'owner':
                roleText = 'Chủ shop';
                roleColor = AppColors.primary;
                roleIcon = Icons.star;
                break;
              case 'manager':
                roleText = 'Quản lý';
                roleColor = AppColors.primary;
                roleIcon = Icons.manage_accounts;
                break;
              case 'employee':
                roleText = 'Nhân viên';
                roleColor = AppColors.success;
                roleIcon = Icons.person;
                break;
              case 'technician':
                roleText = 'Kỹ thuật';
                roleColor = AppColors.warning;
                roleIcon = Icons.build;
                break;
              case 'admin':
                roleText = 'Admin';
                roleColor = AppColors.error;
                roleIcon = Icons.admin_panel_settings;
                break;
              default:
                roleText = 'Người dùng';
                roleColor = AppColors.textHint;
                roleIcon = Icons.person_outline;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: roleColor.withAlpha(20),
                borderRadius: BorderRadius.circular(AppSpacing.lg),
                border: Border.all(color: roleColor.withOpacity(0.18)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: roleColor.withAlpha(38),
                      borderRadius: BorderRadius.circular(AppSpacing.md),
                    ),
                    child: Icon(roleIcon, color: roleColor, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName.isNotEmpty ? displayName : email,
                          style: AppTextStyles.headline5.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (displayName.isNotEmpty)
                          Text(
                            email,
                            style: AppTextStyles.body1.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        if (phone.isNotEmpty)
                          Text(
                            '📞 $phone',
                            style: AppTextStyles.body1.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: roleColor,
                      borderRadius: BorderRadius.circular(AppSpacing.lg),
                    ),
                    child: Text(
                      roleText,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.surface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildStatsCard(int totalShops) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.lg)),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.analytics, color: Theme.of(context).colorScheme.primary, size: 32),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tổng số Shop',
                  style: TextStyle(
                    fontSize: AppTextStyles.subtitle1.fontSize,
                    color: AppColors.textHint,
                  ),
                ),
                Text(
                  '$totalShops',
                  style: TextStyle(
                    fontSize: AppTextStyles.headline1.fontSize,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockSwitch({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    bool isDestructive = false,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          fontSize: AppTextStyles.subtitle1.fontSize,
          fontWeight: FontWeight.bold,
          color: isDestructive && value ? AppColors.error : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: AppTextStyles.body1.fontSize,
          color: AppColors.textHint,
        ),
      ),
      value: value,
      activeThumbColor: isDestructive ? AppColors.error : AppColors.primary,
      onChanged: onChanged,
    );
  }

  Future<void> _updateFlag(
    BuildContext context,
    String shopId,
    String flag,
    bool value,
    String featureName,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await UserService.updateShopControlFlags(
      shopId: shopId,
      flagName: flag,
      flagValue: value,
    );
    // Audit log mọi hành động khóa/mở khóa
    await SuperAdminSecurityService.logAction(
      action: value ? 'lock_shop_flag' : 'unlock_shop_flag',
      shopId: shopId,
      metadata: {'flag': flag, 'featureName': featureName, 'value': value},
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'ĐÃ KHÓA $featureName cho shop $shopId'
              : 'ĐÃ MỞ KHÓA $featureName cho shop $shopId',
        ),
        backgroundColor: value ? AppColors.warning : AppColors.success,
      ),
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Giới thiệu ứng dụng',
                    style: TextStyle(
                      fontSize: AppTextStyles.headline4.fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ứng dụng quản lý cửa hàng đa ngành HULUCA - giải pháp toàn diện cho: Điện tử (IMEI, bảo hành), Thực phẩm (HSD), Thời trang (biến thể size/màu) và nhiều loại hình kinh doanh khác. Hỗ trợ offline và đồng bộ thời gian thực với Firebase.',
              style: TextStyle(
                fontSize: AppTextStyles.subtitle1.fontSize,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ứng dụng được xây dựng và vận hành bởi HULUCA (itquanghuy85@gmail.com) với mục tiêu hỗ trợ các cửa hàng bán lẻ vừa và nhỏ quản lý công việc hiệu quả, minh bạch và chuyên nghiệp hơn.',
              style: TextStyle(
                fontSize: AppTextStyles.subtitle1.fontSize,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimsSyncCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: AppColors.repairDelivered,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync, color: AppColors.repairDelivered),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đồng bộ Custom Claims',
                    style: TextStyle(
                      fontSize: AppTextStyles.headline4.fontSize,
                      fontWeight: FontWeight.bold,
                      color: AppColors.repairDelivered,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sau khi thay đổi Firestore Rules để sử dụng Custom Claims, bạn cần đồng bộ claims cho TẤT CẢ user để họ có thể truy cập được dữ liệu.',
              style: TextStyle(
                fontSize: AppTextStyles.subtitle1.fontSize,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSyncingClaims ? null : _syncAllClaims,
                icon: _isSyncingClaims
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.surface,
                        ),
                      )
                    : const Icon(Icons.cloud_sync),
                label: Text(
                  _isSyncingClaims
                      ? 'Đang đồng bộ...'
                      : 'ĐỒNG BỘ TẤT CẢ CLAIMS',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.repairDelivered,
                  foregroundColor: AppColors.surface,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  late final Stream<QuerySnapshot> _usersStream;

  @override
  void initState() {
    super.initState();
    _usersStream = UserService.getAllUsersStream();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _usersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'Chưa có user nào',
              style: TextStyle(color: AppColors.textHint),
            ),
          );
        }

        final users = snapshot.data!.docs;
        return ListView(
          padding: const EdgeInsets.all(15),
          children: users.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final uid = doc.id;
            final email = data['email'] ?? 'Không rõ email';
            final displayName = data['displayName'] ?? 'Không rõ tên';
            final phone = data['phone'] ?? 'Không rõ số điện thoại';
            final address = data['address'] ?? 'Không rõ địa chỉ';
            final role = data['role'] ?? 'user';
            final shopId = data['shopId'] ?? 'Không có shop';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blueAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            email,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: AppTextStyles.headline4.fontSize,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppColors.warning),
                          onPressed: () =>
                              _showEditUserDialog(context, uid, data),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: AppColors.error),
                          onPressed: () =>
                              _showDeleteUserDialog(context, uid, email),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tên: $displayName',
                      style: TextStyle(
                        fontSize: AppTextStyles.subtitle1.fontSize,
                      ),
                    ),
                    Text(
                      'SĐT: $phone',
                      style: TextStyle(
                        fontSize: AppTextStyles.subtitle1.fontSize,
                      ),
                    ),
                    Text(
                      'Địa chỉ: $address',
                      style: TextStyle(
                        fontSize: AppTextStyles.subtitle1.fontSize,
                      ),
                    ),
                    Text(
                      'Vai trò: ${getRoleDisplayName(role)}',
                      style: TextStyle(
                        fontSize: AppTextStyles.subtitle1.fontSize,
                      ),
                    ),
                    Text(
                      'Shop ID: $shopId',
                      style: TextStyle(
                        fontSize: AppTextStyles.subtitle1.fontSize,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showEditUserDialog(
    BuildContext context,
    String uid,
    Map<String, dynamic> data,
  ) {
    final nameController = TextEditingController(
      text: data['displayName'] ?? '',
    );
    final phoneController = TextEditingController(text: data['phone'] ?? '');
    final addressController = TextEditingController(
      text: data['address'] ?? '',
    );
    final roleController = TextEditingController(text: data['role'] ?? 'user');
    final shopIdController = TextEditingController(text: data['shopId'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa thông tin user'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tên'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Địa chỉ'),
              ),
              TextField(
                controller: roleController,
                decoration: const InputDecoration(labelText: 'Vai trò'),
              ),
              TextField(
                controller: shopIdController,
                decoration: const InputDecoration(labelText: 'Shop ID'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              try {
                await UserService.updateUserInfo(
                  uid: uid,
                  name: nameController.text,
                  phone: phoneController.text,
                  address: addressController.text,
                  role: roleController.text,
                  loc: AppLocalizations.of(context)!,
                  shopId: shopIdController.text.isEmpty
                      ? null
                      : shopIdController.text,
                );
                await SuperAdminSecurityService.logAction(
                  action: 'edit_user',
                  targetUserId: uid,
                  metadata: {
                    'newRole': roleController.text,
                    'newShopId': shopIdController.text.isEmpty ? null : shopIdController.text,
                  },
                );
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Đã cập nhật thông tin user')),
                );
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Lỗi: $e')));
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showDeleteUserDialog(BuildContext context, String uid, String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa user'),
        content: Text(
          'Bạn có chắc muốn xóa user $email?\n\n'
          '• Xóa dữ liệu: Xóa tài khoản Auth + Firestore doc + dữ liệu liên quan (repairs, sales, expenses...)\n'
          '• Chỉ xóa doc: Chỉ xóa Firestore user document\n\n'
          'Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              try {
                await UserService.deleteUser(uid);
                await SuperAdminSecurityService.logAction(
                  action: 'delete_user_doc',
                  targetUserId: uid,
                  metadata: {'email': email},
                );
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Đã xóa Firestore doc của $email')),
                );
              } catch (e) {
                navigator.pop();
                messenger.showSnackBar(SnackBar(content: Text('Lỗi: $e')));
              }
            },
            child: const Text('Chỉ xóa doc'),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              try {
                final result = await UserService.deleteUserWithData(uid);
                navigator.pop();
                final deleted =
                    (result['results']?['deleted'] as List?)?.join(', ') ?? '';
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Đã xóa $email và dữ liệu: $deleted'),
                    duration: const Duration(seconds: 5),
                  ),
                );
              } catch (e) {
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Lỗi xóa dữ liệu: $e')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Xóa dữ liệu'),
          ),
        ],
      ),
    );
  }
}
