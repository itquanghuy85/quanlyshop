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
    _ColItem('sales', 'Đơn bán hàng'),
    _ColItem('inventory_checks', 'Kiểm kê kho'),
    _ColItem('cash_closings', 'Chốt ca'),
  ]),
  _ColGroup('Kho & Sản phẩm', Icons.inventory_2_outlined, Color(0xFF00695C), [
    _ColItem('products', 'Sản phẩm / Kho'),
    _ColItem('suppliers', 'Nhà cung cấp'),
    _ColItem('purchase_orders', 'Đơn nhập hàng'),
    _ColItem('quick_input_codes', 'Mã nhập nhanh'),
  ]),
  _ColGroup('Tài chính', Icons.account_balance_wallet_outlined, Color(0xFF2E7D32), [
    _ColItem('debts', 'Công nợ'),
    _ColItem('debt_payments', 'Thanh toán nợ'),
    _ColItem('expenses', 'Chi phí'),
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
        bottom: TabBar(
          controller: _tab,
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
  bool _backupsLoaded = false;
  bool _storageUnauthorized = false;

  @override
  void initState() {
    super.initState();
    _loadCloudBackups();
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
      await BackupService.exportToLocal(context);
    } catch (e) {
      NotificationService.showSnackBar('Lỗi xuất file: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _backupToCloud() async {
    setState(() => _loading = true);
    try {
      await BackupService.backupToFirebase();
      NotificationService.showSnackBar('Sao lưu SQLite lên Cloud thành công!', color: AppColors.success);
      await _loadCloudBackups();
    } catch (e) {
      NotificationService.showSnackBar('Lỗi sao lưu: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restoreFromFile() async {
    const typeGroup = XTypeGroup(label: 'Database', extensions: ['db']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    setState(() => _loading = true);
    try {
      await BackupService.restoreFromLocalFile(file.path);
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Khôi phục thành công'),
            content: const Text('Đã khôi phục dữ liệu. Vui lòng khởi động lại ứng dụng để áp dụng thay đổi.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
          ),
        );
      }
    } catch (e) {
      NotificationService.showSnackBar('Lỗi khôi phục: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                _ActionButton(label: 'Chia sẻ / Lưu máy', icon: Icons.share, onTap: _loading ? null : _exportToLocal),
                AppSpacing.gapSm,
                _ActionButton(label: 'Sao lưu lên Cloud', icon: Icons.cloud_upload, onTap: _loading ? null : _backupToCloud, color: const Color(0xFF0A56C2)),
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
                        onRestore: () => NotificationService.showSnackBar('Khôi phục SQLite từ cloud đang phát triển.'),
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
            AppSpacing.gapLg,
          ],
        ),
        if (_loading)
          const ColoredBox(color: Colors.black26, child: Center(child: CircularProgressIndicator())),
      ],
    );
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
          '  allow read, write: if request.auth != null;\n'
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

  const _SqliteBackupItem({required this.name, required this.timestamp, required this.onRestore});

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
        trailing: TextButton(onPressed: onRestore, child: const Text('Khôi phục')),
      ),
    );
  }
}
