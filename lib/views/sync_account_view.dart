import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/db_helper.dart';
import '../services/app_session.dart';
import '../services/connectivity_service.dart';
import '../services/owner_reauth_service.dart';
import '../services/session_logout_service.dart';
import '../services/sync_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import 'claim_account_view.dart';

/// Cài đặt → Đồng bộ & Tài khoản (PLAN_OFFLINE_FIRST step 3).
///
/// Three states, so a user never mistakes "no network" for "not connected":
///   ● Chế độ Offline        — dữ liệu chỉ trên máy      [Kết nối tài khoản]
///   ● Online · Chờ mạng     — đã có tài khoản, mất mạng
///   ● Online · Đã đồng bộ   — tài khoản xxx, lần cuối hh:mm [Đồng bộ ngay] [Đăng xuất]
class SyncAccountView extends StatefulWidget {
  const SyncAccountView({super.key});

  @override
  State<SyncAccountView> createState() => _SyncAccountViewState();
}

class _SyncAccountViewState extends State<SyncAccountView> {
  Map<String, int> _unsynced = const {};
  bool _syncing = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadUnsynced();
    // Cheap periodic refresh of counters while the screen is open.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadUnsynced(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUnsynced() async {
    try {
      final m = await DBHelper().countAllUnsyncedData();
      if (mounted) setState(() => _unsynced = m);
    } catch (_) {}
  }

  int get _unsyncedTotal => _unsynced.values.fold(0, (a, b) => a + b);

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await SyncService.syncAllToCloud(force: true);
      await SyncService.refreshCloudCollections(
        reason: 'sync_account_view',
        force: true,
      );
      await _loadUnsynced();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã đồng bộ xong')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi đồng bộ: $e')));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _logout() async {
    final shopId = UserService.getShopIdSync();
    final keepsLocal =
        AppSession.offlineModeAvailable && AppSession.ownsShop(shopId);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: Text(
          keepsLocal
              ? 'Dữ liệu vẫn được giữ trên máy này và bạn tiếp tục dùng ở chế '
                    'độ Offline. Đăng nhập lại để đồng bộ tiếp.'
              : (_unsyncedTotal > 0
                    ? 'Còn $_unsyncedTotal bản ghi chưa đồng bộ lên máy chủ. '
                          'Đăng xuất bây giờ sẽ MẤT các bản ghi này.\n\n'
                          'Dữ liệu trên máy sẽ bị xoá khi đăng xuất.'
                    : 'Dữ liệu trên máy sẽ bị xoá khi đăng xuất '
                          '(đã có bản trên máy chủ).'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await SessionLogoutService.signOut();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Name + address + phone: the receipt header. Offline there is no
  /// "Thông tin cửa hàng" screen (cloud-only), so this is the only place
  /// to set what gets printed.
  Future<void> _renameOfflineShop() async {
    final ctrl = TextEditingController(
      text: AppSession.offlineShopName ?? AppSession.defaultOfflineShopName,
    );
    final addrCtrl = TextEditingController(
      text: AppSession.offlineShopAddress ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: AppSession.offlineShopPhone ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thông tin cửa hàng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Tên cửa hàng',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addrCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ (in trên biên nhận)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại / Hotline',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    final name = ctrl.text;
    final address = addrCtrl.text;
    final phone = phoneCtrl.text;
    // Dispose after the route transition — see feedback_modal_sheet_dependents_crash.
    Future.delayed(const Duration(milliseconds: 400), () {
      ctrl.dispose();
      addrCtrl.dispose();
      phoneCtrl.dispose();
    });
    if (saved != true) return;
    if (name.trim().isNotEmpty) {
      await AppSession.setOfflineShopName(name);
    }
    await AppSession.setOfflineShopContact(address: address, phone: phone);
    if (mounted) setState(() {});
  }

  Future<void> _editOfflinePin() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mật khẩu bảo vệ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Dùng để xác nhận các thao tác nhạy cảm khi chưa có tài khoản '
              '(xoá sản phẩm, xoá đơn, sửa đơn đã bán). Để trống để bỏ mật khẩu.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(milliseconds: 400), ctrl.dispose);
    if (result == null) return;
    await OwnerReauthService.setOfflinePin(result);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.trim().isEmpty ? 'Đã bỏ mật khẩu bảo vệ' : 'Đã lưu mật khẩu',
          ),
        ),
      );
    }
  }

  void _openClaim() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ClaimAccountView()))
        .then((_) {
          if (mounted) setState(() {});
        });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppSession.revision,
      builder: (context, _, __) {
        return Scaffold(
          appBar: AppBar(title: const Text('Đồng bộ & Tài khoản')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppSession.isOffline ? _offlineCard() : _onlineCard(),
              const SizedBox(height: 16),
              _unsyncedCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _statusHeader({
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: Colors.grey[700])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _offlineCard() {
    final shopName =
        AppSession.offlineShopName ?? AppSession.defaultOfflineShopName;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusHeader(
              color: Colors.grey,
              title: 'Chế độ Offline',
              subtitle: 'Dữ liệu đang lưu trên thiết bị này',
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storefront_outlined),
              title: Text(shopName),
              subtitle: Text(
                [
                  AppSession.offlineShopAddress ?? '',
                  AppSession.offlineShopPhone ?? '',
                ].where((s) => s.isNotEmpty).join(' · ').isEmpty
                    ? 'Tên, địa chỉ, SĐT in trên biên nhận'
                    : [
                        AppSession.offlineShopAddress ?? '',
                        AppSession.offlineShopPhone ?? '',
                      ].where((s) => s.isNotEmpty).join(' · '),
              ),
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: _renameOfflineShop,
            ),
            FutureBuilder<bool>(
              future: OwnerReauthService.hasOfflinePin(),
              builder: (context, snap) {
                final has = snap.data == true;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    has ? Icons.lock_outline : Icons.lock_open_outlined,
                  ),
                  title: Text(
                    has ? 'Đã đặt mật khẩu bảo vệ' : 'Mật khẩu bảo vệ',
                  ),
                  subtitle: Text(
                    has
                        ? 'Hỏi khi xoá sản phẩm / đơn, sửa đơn đã bán'
                        : 'Chưa đặt — các thao tác xoá không hỏi mật khẩu',
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 20),
                  onTap: _editOfflinePin,
                );
              },
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _openClaim,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Kết nối tài khoản'),
            ),
            const SizedBox(height: 8),
            Text(
              'Kết nối để sao lưu lên đám mây, dùng trên nhiều máy và thêm '
              'nhân viên. Dữ liệu hiện có sẽ được giữ nguyên và đưa lên tài khoản.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _onlineCard() {
    final user = FirebaseAuth.instance.currentUser;
    final hasNet = ConnectivityService.instance.isOnline;
    return ValueListenableBuilder<DateTime?>(
      valueListenable: SyncService.lastCloudSyncAt,
      builder: (context, lastAt, _) {
        final last = lastAt == null
            ? 'chưa có trong phiên này'
            : DateFormat('HH:mm dd/MM').format(lastAt);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statusHeader(
                  color: hasNet ? AppColors.success : Colors.orange,
                  title: hasNet ? 'Online · Đã kết nối' : 'Online · Chờ mạng',
                  subtitle: hasNet
                      ? 'Tự động đồng bộ 2 chiều với đám mây'
                      : 'Đã có tài khoản, sẽ đồng bộ khi có mạng trở lại',
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(user?.email ?? '—'),
                  subtitle: const Text('Tài khoản'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(last),
                  subtitle: const Text('Đồng bộ lần cuối'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _syncing || !hasNet ? null : _syncNow,
                        icon: _syncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync),
                        label: const Text('Đồng bộ ngay'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        icon: const Icon(Icons.logout),
                        label: const Text('Đăng xuất'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _unsyncedCard() {
    if (AppSession.isOffline) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.phone_android, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Toàn bộ dữ liệu chỉ nằm trên máy này. Mất máy hoặc xoá '
                  'ứng dụng là mất dữ liệu — hãy sao lưu định kỳ.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final total = _unsyncedTotal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  total == 0 ? Icons.check_circle : Icons.cloud_upload,
                  color: total == 0 ? AppColors.success : Colors.orange,
                ),
                const SizedBox(width: 10),
                Text(
                  total == 0
                      ? 'Không có bản ghi chờ đồng bộ'
                      : '$total bản ghi chờ đẩy lên',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (total > 0) ...[
              const SizedBox(height: 8),
              for (final e in _unsynced.entries)
                if (e.value > 0)
                  Text(
                    '• ${e.key}: ${e.value}',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}
