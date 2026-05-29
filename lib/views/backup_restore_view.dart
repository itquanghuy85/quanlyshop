import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_spacing.dart';
import '../widgets/custom_app_bar.dart';

// Collection groups for the picker UI — reuses same structure as selective reset
const _kGroups = [
  _ColGroup('Vận hành', Icons.build_outlined, Color(0xFF1565C0), [
    _ColItem('repairs', 'Đơn sửa chữa'),
    _ColItem('repair_parts', 'Kho linh kiện sửa chữa'),
    _ColItem('repair_partners', 'Đối tác sửa chữa'),
    _ColItem('partner_repair_history', 'Lịch sử gửi đối tác'),
    _ColItem('sales', 'Đơn bán hàng'),
    _ColItem('inventory_checks', 'Kiểm kê kho'),
    _ColItem('cash_closings', 'Chốt ca'),
  ]),
  _ColGroup('Kho & Sản phẩm', Icons.inventory_2_outlined, Color(0xFF00695C), [
    _ColItem('products', 'Sản phẩm / Kho'),
    _ColItem('salvage_phones', 'Kho máy xác'),
    _ColItem('storage_locations', 'Kho vị trí'),
    _ColItem('suppliers', 'Nhà cung cấp'),
    _ColItem('purchase_orders', 'Đơn nhập hàng'),
    _ColItem('import_orders', 'Phiếu nhập kho'),
    _ColItem('supplier_import_history', 'Lịch sử nhập NCC'),
    _ColItem('quick_input_codes', 'Mã nhập nhanh'),
  ]),
  _ColGroup('Tài chính', Icons.account_balance_wallet_outlined, Color(0xFF2E7D32), [
    _ColItem('debts', 'Công nợ'),
    _ColItem('debt_payments', 'Thanh toán nợ'),
    _ColItem('expenses', 'Chi phí'),
    _ColItem('payment_intents', 'Yêu cầu thanh toán'),
    _ColItem('payment_requests', 'Yêu cầu đóng tiền'),
    _ColItem('supplier_payments', 'Chi NCC'),
    _ColItem('repair_partner_payments', 'Chi đối tác sửa chữa'),
  ]),
  _ColGroup('Nhân sự', Icons.people_outline, Color(0xFF6A1B9A), [
    _ColItem('attendance', 'Chấm công'),
    _ColItem('payroll_settings', 'Cài đặt lương'),
    _ColItem('work_schedules', 'Lịch làm việc'),
  ]),
  _ColGroup('Quan hệ khách hàng', Icons.person_outline, Color(0xFFE65100), [
    _ColItem('customers', 'Khách hàng'),
    _ColItem('chats', 'Tin nhắn chat'),
  ]),
  _ColGroup('Hệ thống', Icons.settings_outlined, Color(0xFF546E7A), [
    _ColItem('audit_logs', 'Nhật ký thao tác'),
  ]),
];

class _ColGroup {
  final String label;
  final IconData icon;
  final Color color;
  final List<_ColItem> items;
  const _ColGroup(this.label, this.icon, this.color, this.items);
}

class _ColItem {
  final String key;
  final String label;
  const _ColItem(this.key, this.label);
}

// ─── Main view ───────────────────────────────────────────────────────────────

class BackupRestoreView extends StatefulWidget {
  const BackupRestoreView({super.key});

  @override
  State<BackupRestoreView> createState() => _BackupRestoreViewState();
}

class _BackupRestoreViewState extends State<BackupRestoreView>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  Future<void> _showUsageGuide() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hướng dẫn sao lưu & khôi phục'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. SQLite (offline): dùng khi cần sao lưu/khôi phục toàn bộ file dữ liệu tại máy.'),
              SizedBox(height: 8),
              Text('2. Firestore (online): cho phép sao lưu/khôi phục theo từng mục (đơn sửa, đơn bán, kho, công nợ...).'),
              SizedBox(height: 8),
              Text('3. Khuyến nghị: sao lưu lên Cloud định kỳ mỗi ngày và trước khi cập nhật ứng dụng.'),
              SizedBox(height: 8),
              Text('4. Restore SQLite có 2 kiểu: khôi phục nguyên bản cho cùng shop, hoặc chuyển dữ liệu sang shop hiện tại bằng cách đổi shopId.'),
              SizedBox(height: 8),
              Text('5. Nếu khôi phục vào shop khác mà không đổi shopId thì dữ liệu vẫn thuộc shop cũ nên app sẽ không hiển thị đúng.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar.build(
        title: 'Sao lưu & Khôi phục',
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Tùy chọn',
            onSelected: (value) {
              switch (value) {
                case 'sqlite':
                  _tab.animateTo(0);
                  break;
                case 'firestore':
                  _tab.animateTo(1);
                  break;
                case 'guide':
                  _showUsageGuide();
                  break;
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem<String>(
                value: 'sqlite',
                child: Row(
                  children: [
                    Icon(Icons.storage_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Mở tab SQLite'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'firestore',
                child: Row(
                  children: [
                    Icon(Icons.cloud_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Mở tab Firestore'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'guide',
                child: Row(
                  children: [
                    Icon(Icons.help_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Hướng dẫn sử dụng'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          dividerColor: Colors.white24,
          tabs: const [
            Tab(icon: Icon(Icons.storage_outlined, size: 18), text: 'SQLite (file .db)'),
            Tab(icon: Icon(Icons.cloud_outlined, size: 18), text: 'Firestore (cloud)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _SqliteTab(),
          _FirestoreTab(),
        ],
      ),
    );
  }
}

// ─── Tab 1: SQLite (existing) ─────────────────────────────────────────────────

class _SqliteTab extends StatefulWidget {
  const _SqliteTab();

  @override
  State<_SqliteTab> createState() => _SqliteTabState();
}

class _SqliteTabState extends State<_SqliteTab> {
  bool _loading = false;
  List<Map<String, String>> _cloudBackups = [];
  List<LocalSqliteBackup> _localBackups = [];
  bool _backupsLoaded = false;
  bool _storageUnauthorized = false;
  String? _lastSavedPath;

  @override
  void initState() {
    super.initState();
    _loadCloudBackups();
    _loadLocalBackups();
  }

  Future<void> _loadCloudBackups() async {
    try {
      final backups = await BackupService.listFirebaseBackups();
      if (mounted) {
        setState(() {
          _cloudBackups = backups;
          _backupsLoaded = true;
          _storageUnauthorized = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final isUnauth = e.toString().contains('unauthorized') ||
            e.toString().contains('permission-denied');
        setState(() {
          _backupsLoaded = true;
          _storageUnauthorized = isUnauth;
        });
        if (!isUnauth) {
          NotificationService.showSnackBar('Không thể tải backup: $e', color: AppColors.error);
        }
      }
    }
  }

  Future<void> _exportToLocal() async {
    setState(() => _loading = true);
    try {
      final path = await BackupService.saveSqliteToLocal();
      _lastSavedPath = path;
      await _loadLocalBackups();
      NotificationService.showSnackBar(
        'Đã lưu bản sao SQLite vào máy. Bạn có thể chia sẻ từ danh sách backup cục bộ.',
        color: AppColors.success,
      );
    } catch (e) {
      NotificationService.showSnackBar('Lỗi xuất file: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadLocalBackups() async {
    try {
      final local = await BackupService.listLocalSqliteBackups();
      if (mounted) {
        setState(() => _localBackups = local);
      }
    } catch (_) {
      // Ignore local listing errors.
    }
  }

  Future<void> _shareLocalBackup(LocalSqliteBackup backup) async {
    try {
      await BackupService.shareSqliteFile(backup.path);
    } catch (e) {
      NotificationService.showSnackBar('Lỗi chia sẻ file: $e', color: AppColors.error);
    }
  }

  Future<void> _backupToCloud() async {
    setState(() => _loading = true);
    try {
      await BackupService.backupToFirebase();
      NotificationService.showSnackBar('Sao lưu SQLite lên Cloud thành công!', color: AppColors.success);
      await _loadCloudBackups();
    } catch (e) {
      NotificationService.showSnackBar(
        _friendlyCloudError('Sao lưu', e),
        color: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteCloudBackup(String fileName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bản sao lưu Cloud?'),
        content: Text('Bạn có chắc muốn xóa file "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await BackupService.deleteSqliteBackupFromFirebase(fileName: fileName);
      await _loadCloudBackups();
      NotificationService.showSnackBar('Đã xóa bản sao lưu Cloud.', color: AppColors.success);
    } catch (e) {
      NotificationService.showSnackBar(
        _friendlyCloudError('Xóa', e),
        color: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restoreFromFile() async {
    const typeGroup = XTypeGroup(label: 'Database', extensions: ['db']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final remap = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Chọn kiểu khôi phục'),
          content: const Text(
            'Khôi phục nguyên bản: giữ dữ liệu thuộc shop đã backup.\n\n'
            'Chuyển vào shop hiện tại: đổi shopId để dữ liệu hiện ra trong shop đang đăng nhập.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Khôi phục nguyên bản'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Chuyển vào shop hiện tại'),
            ),
          ],
        ),
      );
      if (remap == null) return;

      final selected = await showDialog<List<String>>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const _CollectionPickerDialog(
          title: 'Chọn dữ liệu cần khôi phục (SQLite)',
          confirmLabel: 'Khôi phục',
          confirmIcon: Icons.restore_outlined,
          confirmColor: Colors.orange,
          availableCollections: null,
        ),
      );
      if (selected == null || selected.isEmpty) return;

      if (!mounted) return;
      await BackupService.restoreSelectedFromLocalFile(
        filePath: file.path,
        collections: selected,
        remapShopIdToCurrentShop: remap,
      );
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Khôi phục thành công'),
          content: Text(
            remap
                ? 'Đã khôi phục ${selected.length} mục và chuyển vào shop hiện tại. Vui lòng khởi động lại ứng dụng để áp dụng thay đổi.'
                : 'Đã khôi phục ${selected.length} mục dữ liệu. Vui lòng khởi động lại ứng dụng để áp dụng thay đổi.',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
        ),
      );
    } catch (e) {
      NotificationService.showSnackBar('Lỗi khôi phục: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restoreFromCloudBackup(String fileName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Khôi phục SQLite từ Cloud'),
        content: Text(
          'Bạn sắp khôi phục từ bản sao lưu:\n$fileName\n\nDữ liệu hiện tại trên máy sẽ bị ghi đè. Tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final remap = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Chọn kiểu khôi phục'),
        content: const Text(
          'Khôi phục nguyên bản sẽ giữ nguyên shopId cũ.\n\n'
          'Nếu muốn đưa dữ liệu vào shop hiện tại, chọn phương án chuyển shopId.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Khôi phục nguyên bản'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Chuyển vào shop hiện tại'),
          ),
        ],
      ),
    );
    if (remap == null) return;

    final selected = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _CollectionPickerDialog(
        title: 'Chọn dữ liệu cần khôi phục (SQLite)',
        confirmLabel: 'Khôi phục',
        confirmIcon: Icons.restore_outlined,
        confirmColor: Colors.orange,
        availableCollections: null,
      ),
    );
    if (selected == null || selected.isEmpty) return;

    setState(() => _loading = true);
    try {
      await BackupService.restoreSelectedSqliteFromFirebase(
        fileName: fileName,
        collections: selected,
        remapShopIdToCurrentShop: remap,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Khôi phục thành công'),
          content: Text(
            remap
                ? 'Đã khôi phục ${selected.length} mục từ Cloud và chuyển vào shop hiện tại. Vui lòng khởi động lại ứng dụng.'
                : 'Đã khôi phục ${selected.length} mục từ Cloud. Vui lòng khởi động lại ứng dụng để áp dụng dữ liệu mới.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (e) {
      NotificationService.showSnackBar(
        _friendlyCloudError('Khôi phục', e),
        color: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Selective data delete ──────────────────────────────────────────────────

  Future<void> _deleteSelectedData(List<String> collections, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text('Xóa: $label?', style: const TextStyle(fontSize: 15))),
        ]),
        content: const Text(
          'Dữ liệu sẽ bị xóa vĩnh viễn khỏi thiết bị này.\n\n'
          'Nên sao lưu trước khi xóa để tránh mất dữ liệu quan trọng.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    try {
      final rows = await BackupService.deleteSelectedData(collections);
      if (mounted) {
        NotificationService.showSnackBar(
          'Đã xóa $rows bản ghi ($label). Khởi động lại app để áp dụng.',
          color: AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) NotificationService.showSnackBar('Lỗi xóa: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteCustomData() async {
    final selected = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _CollectionPickerDialog(
        title: 'Chọn dữ liệu cần xóa',
        confirmLabel: 'Xóa',
        confirmIcon: Icons.delete_outline,
        confirmColor: Colors.red,
        availableCollections: null,
      ),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    await _deleteSelectedData(selected, '${selected.length} mục đã chọn');
  }

  // ── Clean old backups ──────────────────────────────────────────────────────

  Future<void> _cleanOldBackups() async {
    final days = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Giữ backup bao nhiêu ngày gần nhất?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 30),
            child: const Text('30 ngày — xóa backup cũ hơn 1 tháng'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 60),
            child: const Text('60 ngày — xóa backup cũ hơn 2 tháng'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 90),
            child: const Text('90 ngày — xóa backup cũ hơn 3 tháng'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 180),
            child: const Text('180 ngày — xóa backup cũ hơn 6 tháng'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
    if (days == null || !mounted) return;
    setState(() => _loading = true);
    try {
      final count = await BackupService.cleanOldLocalBackups(keepDays: days);
      await _loadLocalBackups();
      if (mounted) {
        NotificationService.showSnackBar(
          count == 0
              ? 'Không có backup nào cũ hơn $days ngày.'
              : 'Đã xóa $count file backup cũ hơn $days ngày.',
          color: AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) NotificationService.showSnackBar('Lỗi dọn backup: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyCloudError(String action, Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('permission-denied') || raw.contains('unauthorized')) {
      return '$action Cloud thất bại: tài khoản chưa có quyền Firebase Storage cho db_backups.';
    }
    if (raw.contains('object-not-found')) {
      return '$action Cloud thất bại: không tìm thấy file backup trên Cloud.';
    }
    if (raw.contains('unauthenticated')) {
      return '$action Cloud thất bại: phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.';
    }
    return '$action Cloud thất bại: $error';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _SectionCard(
              title: 'Sao lưu SQLite',
              icon: Icons.backup,
              children: [
                _ActionButton(label: 'Lưu file .db vào máy', icon: Icons.save_alt, onTap: _loading ? null : _exportToLocal),
                AppSpacing.gapSm,
                if (_localBackups.isNotEmpty)
                  _ActionButton(
                    label: 'Chia sẻ bản sao mới nhất',
                    icon: Icons.share,
                    onTap: _loading ? null : () => _shareLocalBackup(_localBackups.first),
                  ),
                if (_lastSavedPath != null) ...[
                  AppSpacing.gapSm,
                  Text(
                    'Đã lưu: ${_lastSavedPath!.split('\\').last}',
                    style: TextStyle(
                      fontSize: AppTextStyles.subtitle1Size,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                AppSpacing.gapSm,
                _ActionButton(label: 'Sao lưu lên Cloud', icon: Icons.cloud_upload, onTap: _loading ? null : _backupToCloud, color: const Color(0xFF0A56C2)),
              ],
            ),
            AppSpacing.gapMd,
            _SectionCard(
              title: 'Bản sao lưu SQLite trong máy',
              icon: Icons.folder_outlined,
              trailing: IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _loading ? null : _loadLocalBackups,
                tooltip: 'Tải lại',
              ),
              children: [
                if (_localBackups.isEmpty)
                  Text(
                    'Chưa có bản sao lưu cục bộ nào. Hãy bấm "Lưu file .db vào máy" ở trên.',
                    style: TextStyle(fontSize: AppTextStyles.subtitle1Size, color: AppColors.textSecondary),
                  )
                else
                  ..._localBackups.map(
                    (b) => _LocalSqliteBackupItem(
                      backup: b,
                      onRestoreFromPath: () => _restoreFromLocalPath(b.path),
                      onShare: () => _shareLocalBackup(b),
                    ),
                  ),
              ],
            ),
            AppSpacing.gapMd,
            _SectionCard(
              title: 'Hướng dẫn nhanh',
              icon: Icons.help_outline,
              children: const [
                Text('• Sao lưu offline: bấm "Lưu file .db vào máy" để tạo bản backup cục bộ.'),
                SizedBox(height: 4),
                Text('• Chia sẻ backup: dùng nút "Chia sẻ" trong danh sách backup cục bộ.'),
                SizedBox(height: 4),
                Text('• Khôi phục offline: chọn từ danh sách backup cục bộ hoặc file .db.'),
                SizedBox(height: 4),
                Text('• Khôi phục online: chọn một bản SQLite trên Cloud và bấm "Khôi phục".'),
              ],
            ),
            AppSpacing.gapMd,
            _SectionCard(
              title: 'Bản sao lưu SQLite trên Cloud',
              icon: Icons.cloud,
              children: [
                if (!_backupsLoaded)
                  const Center(child: CircularProgressIndicator())
                else if (_storageUnauthorized)
                  _StorageAuthWarning()
                else if (_cloudBackups.isEmpty)
                  Text('Chưa có bản sao lưu nào.', style: TextStyle(fontSize: AppTextStyles.subtitle1Size, color: AppColors.textSecondary))
                else
                  ..._cloudBackups.map((b) => _SqliteBackupItem(
                        name: b['name'] ?? '',
                        timestamp: b['timestamp'] ?? '',
                        onRestore: () => _restoreFromCloudBackup(b['name'] ?? ''),
                        onDelete: () => _deleteCloudBackup(b['name'] ?? ''),
                      )),
              ],
            ),
            AppSpacing.gapMd,
            _SectionCard(
              title: 'Khôi phục từ file',
              icon: Icons.restore,
              children: [
                Text('Chọn file .db đã sao lưu trước đó để khôi phục.', style: TextStyle(fontSize: AppTextStyles.subtitle1Size, color: AppColors.textSecondary)),
                AppSpacing.gapSm,
                _ActionButton(label: 'Chọn file .db', icon: Icons.folder_open, onTap: _loading ? null : _restoreFromFile, color: AppColors.warning),
              ],
            ),
            AppSpacing.gapMd,
            _SectionCard(
              title: 'Xóa dữ liệu chọn lọc',
              icon: Icons.delete_sweep_outlined,
              children: [
                const Text(
                  'Xóa vĩnh viễn dữ liệu cục bộ khỏi thiết bị này. Nên sao lưu trước khi xóa.',
                  style: TextStyle(fontSize: AppTextStyles.subtitle1Size, color: AppColors.textSecondary),
                ),
                AppSpacing.gapSm,
                _ActionButton(
                  label: 'Xóa Kho phụ kiện / Sản phẩm',
                  icon: Icons.inventory_2_outlined,
                  onTap: _loading ? null : () => _deleteSelectedData(['products'], 'Kho phụ kiện / Sản phẩm'),
                  color: Colors.deepOrange,
                ),
                AppSpacing.gapSm,
                _ActionButton(
                  label: 'Xóa Linh kiện sửa chữa',
                  icon: Icons.build_outlined,
                  onTap: _loading ? null : () => _deleteSelectedData(['repair_parts'], 'Linh kiện sửa chữa'),
                  color: Colors.deepOrange,
                ),
                AppSpacing.gapSm,
                _ActionButton(
                  label: 'Xóa tùy chọn (chọn nhiều mục)...',
                  icon: Icons.checklist_outlined,
                  onTap: _loading ? null : _deleteCustomData,
                  color: Colors.red,
                ),
              ],
            ),
            AppSpacing.gapMd,
            _SectionCard(
              title: 'Dọn backup cũ',
              icon: Icons.cleaning_services_outlined,
              children: [
                const Text(
                  'Xóa các file backup cục bộ cũ hơn số ngày bạn chọn.',
                  style: TextStyle(fontSize: AppTextStyles.subtitle1Size, color: AppColors.textSecondary),
                ),
                AppSpacing.gapSm,
                _ActionButton(
                  label: 'Dọn backup cũ...',
                  icon: Icons.delete_outline,
                  onTap: _loading ? null : _cleanOldBackups,
                  color: Colors.blueGrey,
                ),
              ],
            ),
            AppSpacing.gapLg,
          ],
        ),
        if (_loading)
          const ColoredBox(color: Colors.black26, child: Center(child: CircularProgressIndicator())),
      ],
    );
  }

  Future<void> _restoreFromLocalPath(String filePath) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Khôi phục SQLite cục bộ'),
        content: const Text('Dữ liệu hiện tại sẽ bị ghi đè bởi bản backup này. Tiếp tục?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      final remap = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Chọn kiểu khôi phục'),
          content: const Text(
            'Khôi phục nguyên bản sẽ giữ nguyên shopId cũ.\n\n'
            'Nếu muốn đưa dữ liệu vào shop hiện tại, chọn phương án chuyển shopId.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Khôi phục nguyên bản'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Chuyển vào shop hiện tại'),
            ),
          ],
        ),
      );
      if (remap == null) return;

      final selected = await showDialog<List<String>>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const _CollectionPickerDialog(
          title: 'Chọn dữ liệu cần khôi phục (SQLite)',
          confirmLabel: 'Khôi phục',
          confirmIcon: Icons.restore_outlined,
          confirmColor: Colors.orange,
          availableCollections: null,
        ),
      );
      if (selected == null || selected.isEmpty) return;

      if (!mounted) return;
      await BackupService.restoreSelectedFromLocalFile(
        filePath: filePath,
        collections: selected,
        remapShopIdToCurrentShop: remap,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Khôi phục thành công'),
          content: Text(
            remap
                ? 'Đã khôi phục ${selected.length} mục và chuyển vào shop hiện tại. Vui lòng khởi động lại ứng dụng.'
                : 'Đã khôi phục ${selected.length} mục từ bản backup cục bộ. Vui lòng khởi động lại ứng dụng.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          ],
        ),
      );
    } catch (e) {
      NotificationService.showSnackBar('Lỗi khôi phục cục bộ: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─── Tab 2: Firestore backup ──────────────────────────────────────────────────

class _FirestoreTab extends StatefulWidget {
  const _FirestoreTab();

  @override
  State<_FirestoreTab> createState() => _FirestoreTabState();
}

class _FirestoreTabState extends State<_FirestoreTab> {
  bool _loading = false;
  String? _progressMsg;
  List<FirestoreBackupSet> _backupSets = [];
  bool _setsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBackupSets();
  }

  Future<void> _loadBackupSets() async {
    try {
      final sets = await BackupService.listFirestoreBackupSets();
      if (mounted) setState(() { _backupSets = sets; _setsLoaded = true; });
    } catch (e) {
      if (mounted) setState(() => _setsLoaded = true);
    }
  }

  Future<void> _startBackup() async {
    // Show collection picker
    final selected = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _CollectionPickerDialog(
        title: 'Chọn dữ liệu cần sao lưu',
        confirmLabel: 'Sao lưu',
        confirmIcon: Icons.cloud_upload_outlined,
        confirmColor: Color(0xFF0A56C2),
        availableCollections: null, // all
      ),
    );
    if (selected == null || selected.isEmpty) return;

    setState(() { _loading = true; _progressMsg = 'Đang chuẩn bị...'; });
    try {
      await BackupService.backupFirestoreToCloud(
        collections: selected,
        onProgress: (col, done, total) {
          if (mounted) {
            setState(() => _progressMsg = 'Đang sao lưu ${BackupService.kCollectionLabels[col] ?? col} ($done/$total)...');
          }
        },
      );
      NotificationService.showSnackBar('Sao lưu Firestore thành công (${selected.length} mục)!', color: AppColors.success);
      await _loadBackupSets();
    } catch (e) {
      NotificationService.showSnackBar('Lỗi sao lưu Firestore: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() { _loading = false; _progressMsg = null; });
    }
  }

  Future<void> _restoreBackupSet(FirestoreBackupSet set) async {
    final selected = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CollectionPickerDialog(
        title: 'Chọn dữ liệu cần khôi phục',
        confirmLabel: 'Khôi phục',
        confirmIcon: Icons.restore_outlined,
        confirmColor: Colors.orange,
        availableCollections: set.collections,
      ),
    );
    if (selected == null || selected.isEmpty) return;
    if (!mounted) return;

    // Confirm
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('Xác nhận khôi phục'),
        ]),
        content: Text(
          'Dữ liệu hiện tại của ${selected.length} mục sẽ bị ghi đè bởi bản sao lưu ngày '
          '${DateFormat('dd/MM/yyyy HH:mm').format(set.createdAt)}.\n\nTiếp tục?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() { _loading = true; _progressMsg = 'Đang khôi phục...'; });
    try {
      await BackupService.restoreFirestoreFromCloud(
        backupSet: set,
        collections: selected,
      );
      NotificationService.showSnackBar('Khôi phục thành công (${selected.length} mục)!', color: AppColors.success);
    } catch (e) {
      NotificationService.showSnackBar('Lỗi khôi phục: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() { _loading = false; _progressMsg = null; });
    }
  }

  Future<void> _deleteBackupSet(FirestoreBackupSet set) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bản sao lưu?'),
        content: Text('Xóa bản sao lưu ngày ${DateFormat('dd/MM/yyyy HH:mm').format(set.createdAt)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await BackupService.deleteFirestoreBackupSet(set);
      await _loadBackupSets();
      NotificationService.showSnackBar('Đã xóa bản sao lưu.', color: AppColors.success);
    } catch (e) {
      NotificationService.showSnackBar('Lỗi xóa: $e', color: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Info card
            Card(
              color: Colors.blue.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.shade200)),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'Sao lưu Firestore lưu từng collection thành file JSON riêng. Bạn có thể chọn mục nào cần sao lưu hoặc khôi phục.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  )),
                ]),
              ),
            ),
            AppSpacing.gapMd,
            _SectionCard(
              title: 'Khôi phục theo từng mục',
              icon: Icons.tune,
              children: const [
                Text('Bạn có thể chọn chính xác từng nhóm dữ liệu khi khôi phục (VD: chỉ Đơn sửa, chỉ Kho, chỉ Công nợ).'),
                SizedBox(height: 4),
                Text('Hệ thống chỉ ghi đè các mục bạn chọn, không ảnh hưởng các mục còn lại.'),
              ],
            ),
            AppSpacing.gapMd,

            // Backup now
            _SectionCard(
              title: 'Sao lưu Firestore',
              icon: Icons.cloud_upload_outlined,
              children: [
                _ActionButton(
                  label: 'Chọn mục & Sao lưu lên Cloud',
                  icon: Icons.cloud_upload,
                  onTap: _loading ? null : _startBackup,
                  color: const Color(0xFF0A56C2),
                ),
              ],
            ),
            AppSpacing.gapMd,

            // Backup sets list
            _SectionCard(
              title: 'Bản sao lưu Firestore',
              icon: Icons.history,
              trailing: IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _loading ? null : _loadBackupSets,
                tooltip: 'Tải lại',
              ),
              children: [
                if (!_setsLoaded)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                else if (_backupSets.isEmpty)
                  Text('Chưa có bản sao lưu Firestore nào.', style: TextStyle(fontSize: AppTextStyles.subtitle1Size, color: AppColors.textSecondary))
                else
                  ..._backupSets.map((set) => _FirestoreBackupItem(
                        set: set,
                        onRestore: () => _restoreBackupSet(set),
                        onDelete: () => _deleteBackupSet(set),
                      )),
              ],
            ),
            AppSpacing.gapLg,
          ],
        ),
        if (_loading)
          ColoredBox(
            color: Colors.black38,
            child: Center(
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_progressMsg ?? 'Đang xử lý...', style: const TextStyle(fontSize: 14)),
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Collection picker dialog ─────────────────────────────────────────────────

class _CollectionPickerDialog extends StatefulWidget {
  const _CollectionPickerDialog({
    required this.title,
    required this.confirmLabel,
    required this.confirmIcon,
    required this.confirmColor,
    required this.availableCollections, // null = show all
  });

  final String title;
  final String confirmLabel;
  final IconData confirmIcon;
  final Color confirmColor;
  final List<String>? availableCollections;

  @override
  State<_CollectionPickerDialog> createState() => _CollectionPickerDialogState();
}

class _CollectionPickerDialogState extends State<_CollectionPickerDialog> {
  final Map<String, bool> _checked = {};

  @override
  void initState() {
    super.initState();
    for (final g in _kGroups) {
      for (final item in g.items) {
        final available = widget.availableCollections == null ||
            widget.availableCollections!.contains(item.key);
        _checked[item.key] = available ? false : false;
      }
    }
  }

  bool _isAvailable(String key) =>
      widget.availableCollections == null || widget.availableCollections!.contains(key);

  bool get _anyChecked => _checked.values.any((v) => v);
  bool get _allChecked => _checked.entries.where((e) => _isAvailable(e.key)).every((e) => e.value);
  int get _selectedCount => _checked.values.where((v) => v).length;

  bool _groupAllChecked(_ColGroup g) =>
      g.items.where((i) => _isAvailable(i.key)).every((i) => _checked[i.key] == true);
  bool _groupAnyChecked(_ColGroup g) =>
      g.items.where((i) => _isAvailable(i.key)).any((i) => _checked[i.key] == true);

  void _toggleGroup(_ColGroup g, bool value) {
    setState(() {
      for (final item in g.items) {
        if (_isAvailable(item.key)) _checked[item.key] = value;
      }
    });
  }

  void _toggleAll(bool value) {
    setState(() {
      for (final key in _checked.keys) {
        if (_isAvailable(key)) _checked[key] = value;
      }
    });
  }

  List<String> get _result =>
      _checked.entries.where((e) => e.value).map((e) => e.key).toList();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 16)),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 460,
        child: Column(
          children: [
            // Select-all header
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: CheckboxListTile(
                dense: true,
                value: _allChecked ? true : (_anyChecked ? null : false),
                tristate: true,
                title: const Text('Chọn tất cả', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('$_selectedCount mục đã chọn'),
                onChanged: (v) => _toggleAll(v == true),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: _kGroups.map((g) {
                  final hasAvailable = g.items.any((i) => _isAvailable(i.key));
                  if (!hasAvailable) return const SizedBox.shrink();
                  return _GroupTile(
                    group: g,
                    isAvailable: _isAvailable,
                    isChecked: (key) => _checked[key] ?? false,
                    onItemToggle: (key, v) => setState(() => _checked[key] = v),
                    allChecked: _groupAllChecked(g),
                    anyChecked: _groupAnyChecked(g),
                    onGroupToggle: (v) => _toggleGroup(g, v),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton.icon(
          onPressed: _anyChecked ? () => Navigator.pop(context, _result) : null,
          style: FilledButton.styleFrom(backgroundColor: widget.confirmColor),
          icon: Icon(widget.confirmIcon, size: 16),
          label: Text('${widget.confirmLabel} ($_selectedCount)'),
        ),
      ],
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.isAvailable,
    required this.isChecked,
    required this.onItemToggle,
    required this.allChecked,
    required this.anyChecked,
    required this.onGroupToggle,
  });

  final _ColGroup group;
  final bool Function(String) isAvailable;
  final bool Function(String) isChecked;
  final void Function(String, bool) onItemToggle;
  final bool allChecked;
  final bool anyChecked;
  final void Function(bool) onGroupToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: group.color.withValues(alpha: 0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(group.icon, color: group.color, size: 20),
          title: Text(group.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          initiallyExpanded: false,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (anyChecked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: group.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${group.items.where((i) => isChecked(i.key)).length}/${group.items.where((i) => isAvailable(i.key)).length}',
                    style: TextStyle(fontSize: 11, color: group.color, fontWeight: FontWeight.bold),
                  ),
                ),
              Checkbox(
                value: allChecked ? true : (anyChecked ? null : false),
                tristate: true,
                activeColor: group.color,
                onChanged: (v) => onGroupToggle(v == true),
              ),
            ],
          ),
          children: group.items.map((item) {
            final available = isAvailable(item.key);
            return CheckboxListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              value: isChecked(item.key),
              activeColor: group.color,
              enabled: available,
              title: Text(
                item.label,
                style: TextStyle(fontSize: 13, color: available ? null : Colors.grey),
              ),
              subtitle: available ? null : const Text('Không có trong bản sao lưu này', style: TextStyle(fontSize: 11, color: Colors.grey)),
              onChanged: available ? (v) => onItemToggle(item.key, v ?? false) : null,
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Firestore backup set list item ──────────────────────────────────────────

class _FirestoreBackupItem extends StatelessWidget {
  const _FirestoreBackupItem({
    required this.set,
    required this.onRestore,
    required this.onDelete,
  });

  final FirestoreBackupSet set;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final label = BackupService.kCollectionLabels;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_done_outlined, color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('dd/MM/yyyy  HH:mm').format(set.createdAt),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.restore_outlined, color: Colors.orange),
                  tooltip: 'Khôi phục',
                  onPressed: onRestore,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Xóa',
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: set.collections.map((col) {
                final lbl = label[col] ?? col;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Text(lbl, style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _StorageAuthWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.warning_amber, color: AppColors.warning, size: 16),
          SizedBox(width: 6),
          Text('Cần cấu hình Firebase Storage Rules', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.warning, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        Text(
          'match /db_backups/{shopId}/{allPaths=**} {\n'
          '  allow read: if request.auth != null;\n'
          '  allow create, update: if request.auth != null;\n'
          '  allow delete: if request.auth != null;\n'
          '}',
          style: TextStyle(fontSize: AppTextStyles.subtitle1Size, color: AppColors.textSecondary, fontFamily: 'monospace', height: 1.5),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  const _SectionCard({required this.title, required this.icon, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF0A56C2), size: 18),
                AppSpacing.hSm,
                Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                if (trailing != null) trailing!,
              ],
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const _ActionButton({required this.label, required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppColors.textSecondary,
          foregroundColor: AppColors.surface,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _SqliteBackupItem extends StatelessWidget {
  final String name;
  final String timestamp;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _SqliteBackupItem({
    required this.name,
    required this.timestamp,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.textHint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        leading: const Icon(Icons.storage, color: Color(0xFF0A56C2)),
        title: Text(name, style: const TextStyle(fontSize: AppTextStyles.h4, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(timestamp, style: TextStyle(fontSize: AppTextStyles.subtitle1Size, color: AppColors.textSecondary)),
        trailing: Wrap(
          spacing: 2,
          children: [
            TextButton(onPressed: onRestore, child: const Text('Khôi phục')),
            IconButton(
              onPressed: onDelete,
              tooltip: 'Xóa',
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalSqliteBackupItem extends StatelessWidget {
  final LocalSqliteBackup backup;
  final VoidCallback onRestoreFromPath;
  final VoidCallback onShare;

  const _LocalSqliteBackupItem({
    required this.backup,
    required this.onRestoreFromPath,
    required this.onShare,
  });

  String _formatSize(int size) {
    if (size < 1024) return '${size}B';
    final kb = size / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)}KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.textHint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        leading: const Icon(Icons.storage, color: Colors.deepOrange),
        title: Text(
          backup.name,
          style: const TextStyle(
            fontSize: AppTextStyles.h4,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy HH:mm').format(backup.modifiedAt)} • ${_formatSize(backup.sizeBytes)}',
          style: TextStyle(
            fontSize: AppTextStyles.subtitle1Size,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              onPressed: onShare,
              tooltip: 'Chia sẻ',
              icon: const Icon(Icons.share_outlined, size: 20),
            ),
            IconButton(
              onPressed: onRestoreFromPath,
              tooltip: 'Khôi phục',
              icon: const Icon(Icons.restore_outlined, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
