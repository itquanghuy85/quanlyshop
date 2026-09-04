import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../utils/file_picker_types.dart';
import '../theme/app_colors.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_spacing.dart';
import '../widgets/custom_app_bar.dart';
import 'kiotviet_import_view.dart';
import 'shop_migration_view.dart';
import '../services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// All collection keys in order — used by initState() without needing l10n.
const _kAllCollectionKeys = [
  'repairs', 'repair_parts', 'repair_partners', 'partner_repair_history',
  'sales', 'inventory_checks', 'cash_closings',
  'products', 'salvage_phones', 'storage_locations',
  'suppliers', 'purchase_orders', 'import_orders', 'supplier_import_history',
  'quick_input_codes', 'debts', 'debt_payments', 'expenses',
  'payment_intents', 'payment_requests', 'supplier_payments', 'repair_partner_payments',
  'attendance', 'payroll_settings', 'work_schedules',
  'customers', 'chats', 'audit_logs',
];

// Build localized collection groups for the picker UI.
List<_ColGroup> _buildGroups(AppLocalizations l10n) => [
  _ColGroup(l10n.backupGroupOperations, Icons.build_outlined, const Color(0xFF1565C0), [
    _ColItem('repairs', l10n.backupColRepairs),
    _ColItem('repair_parts', l10n.backupColRepairParts),
    _ColItem('repair_partners', l10n.backupColRepairPartners),
    _ColItem('partner_repair_history', l10n.backupColPartnerHistory),
    _ColItem('sales', l10n.backupColSales),
    _ColItem('inventory_checks', l10n.backupColInventoryChecks),
    _ColItem('cash_closings', l10n.backupColCashClosings),
  ]),
  _ColGroup(l10n.backupGroupWarehouse, Icons.inventory_2_outlined, const Color(0xFF00695C), [
    _ColItem('products', l10n.backupColProducts),
    _ColItem('salvage_phones', l10n.backupColSalvagePhones),
    _ColItem('storage_locations', l10n.backupColStorageLocations),
    _ColItem('suppliers', l10n.backupColSuppliers),
    _ColItem('purchase_orders', l10n.backupColPurchaseOrders),
    _ColItem('import_orders', l10n.backupColImportOrders),
    _ColItem('supplier_import_history', l10n.backupColSupplierImportHistory),
    _ColItem('quick_input_codes', l10n.backupColQuickInputCodes),
  ]),
  _ColGroup(l10n.backupGroupFinance, Icons.account_balance_wallet_outlined, const Color(0xFF2E7D32), [
    _ColItem('debts', l10n.backupColDebts),
    _ColItem('debt_payments', l10n.backupColDebtPayments),
    _ColItem('expenses', l10n.backupColExpenses),
    _ColItem('payment_intents', l10n.backupColPaymentIntents),
    _ColItem('payment_requests', l10n.backupColPaymentRequests),
    _ColItem('supplier_payments', l10n.backupColSupplierPayments),
    _ColItem('repair_partner_payments', l10n.backupColRepairPartnerPayments),
  ]),
  _ColGroup(l10n.backupGroupHr, Icons.people_outline, const Color(0xFF6A1B9A), [
    _ColItem('attendance', l10n.backupColAttendance),
    _ColItem('payroll_settings', l10n.backupColPayrollSettings),
    _ColItem('work_schedules', l10n.backupColWorkSchedules),
  ]),
  _ColGroup(l10n.backupGroupCrm, Icons.person_outline, const Color(0xFFE65100), [
    _ColItem('customers', l10n.backupColCustomers),
    _ColItem('chats', l10n.backupColChats),
  ]),
  _ColGroup(l10n.backupGroupSystem, Icons.settings_outlined, const Color(0xFF546E7A), [
    _ColItem('audit_logs', l10n.backupColAuditLogs),
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
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupGuideTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.backupGuideStep1),
              const SizedBox(height: 8),
              Text(l10n.backupGuideStep2),
              const SizedBox(height: 8),
              Text(l10n.backupGuideStep3),
              const SizedBox(height: 8),
              Text(l10n.backupGuideStep4),
              const SizedBox(height: 8),
              Text(l10n.backupGuideStep5),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.understood),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: CustomAppBar.build(
        title: l10n.backupRestoreTitle,
        actions: [
          PopupMenuButton<String>(
            tooltip: l10n.backupOptionsTooltip,
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
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'sqlite',
                child: Row(
                  children: [
                    const Icon(Icons.storage_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(l10n.backupOpenSqliteTab),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'firestore',
                child: Row(
                  children: [
                    const Icon(Icons.cloud_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(l10n.backupOpenFirestoreTab),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'guide',
                child: Row(
                  children: [
                    const Icon(Icons.help_outline, size: 18),
                    const SizedBox(width: 8),
                    Text(l10n.usageGuide),
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
          tabs: [
            Tab(icon: const Icon(Icons.storage_outlined, size: 18), text: l10n.backupSqliteTabLabel),
            Tab(icon: const Icon(Icons.cloud_outlined, size: 18), text: l10n.backupFirestoreTabLabel),
            const Tab(icon: Icon(Icons.photo_library_outlined, size: 18), text: 'Đơn sửa + Ảnh'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _SqliteTab(),
          _FirestoreTab(),
          _RepairImagesTab(),
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
        final l10n = AppLocalizations.of(context)!;
        final isUnauth = e.toString().contains('unauthorized') ||
            e.toString().contains('permission-denied');
        setState(() {
          _backupsLoaded = true;
          _storageUnauthorized = isUnauth;
        });
        if (!isUnauth) {
          NotificationService.showSnackBar(l10n.backupCannotLoad(e.toString()), color: AppColors.error);
        }
      }
    }
  }

  Future<void> _exportToLocal() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _loading = true);
    try {
      final path = await BackupService.saveSqliteToLocal();
      _lastSavedPath = path;
      await _loadLocalBackups();
      NotificationService.showSnackBar(l10n.backupSavedLocally, color: AppColors.success);
    } catch (e) {
      NotificationService.showSnackBar(l10n.backupExportError(e.toString()), color: AppColors.error);
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
    final l10n = AppLocalizations.of(context)!;
    try {
      await BackupService.shareSqliteFile(backup.path);
    } catch (e) {
      NotificationService.showSnackBar(l10n.backupShareFileError(e.toString()), color: AppColors.error);
    }
  }

  Future<void> _deleteLocalBackup(LocalSqliteBackup backup) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupDeleteLocalTitle),
        content: Text(l10n.backupDeleteLocalContent(backup.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await BackupService.deleteLocalSqliteBackup(backup.path);
      await _loadLocalBackups();
      if (mounted) {
        NotificationService.showSnackBar(
          l10n.backupDeletedLocalName(backup.name),
          color: AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showSnackBar(l10n.backupDeleteLocalError(e.toString()), color: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _backupToCloud() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _loading = true);
    try {
      await BackupService.backupToFirebase();
      NotificationService.showSnackBar(l10n.backupCloudSuccess, color: AppColors.success);
      await _loadCloudBackups();
    } catch (e) {
      NotificationService.showSnackBar(
        _friendlyCloudError(l10n, l10n.backupBackupLabel, e),
        color: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteCloudBackup(String fileName) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupDeleteCloudTitle),
        content: Text(l10n.backupDeleteLocalContent(fileName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await BackupService.deleteSqliteBackupFromFirebase(fileName: fileName);
      await _loadCloudBackups();
      NotificationService.showSnackBar(l10n.backupDeletedCloud, color: AppColors.success);
    } catch (e) {
      NotificationService.showSnackBar(
        _friendlyCloudError(l10n, l10n.delete, e),
        color: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restoreFromFile() async {
    // Dung FilePickerTypes — thieu `uniformTypeIdentifiers` la iOS nem
    // ArgumentError, bam nut khong len gi.
    XFile? picked;
    try {
      picked = await openFile(acceptedTypeGroups: [FilePickerTypes.database]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Khong mo duoc trinh chon file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (picked == null) return;
    final file = picked;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _loading = true);
    try {
      final remap = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.backupChooseRestoreType),
          content: Text(l10n.backupRestoreOriginalDesc),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.backupRestoreOriginalBtn),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.backupTransferToCurrentShop),
            ),
          ],
        ),
      );
      if (remap == null) return;

      final selected = await showDialog<List<String>>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _CollectionPickerDialog(
          title: l10n.backupSelectDataSqlite,
          confirmLabel: l10n.backupRestoreBtn,
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
          title: Text(l10n.backupRestoreSuccessTitle),
          content: Text(
            remap
                ? l10n.backupRestoredWithTransfer(selected.length)
                : l10n.backupRestoredNoTransfer(selected.length),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.close))],
        ),
      );
    } catch (e) {
      NotificationService.showSnackBar(l10n.backupRestoreErrorMsg(e.toString()), color: AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restoreFromCloudBackup(String fileName) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupRestoreCloudTitle),
        content: Text(l10n.backupRestoreCloudContent(fileName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.backupRestoreBtn),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final remap = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupChooseRestoreType),
        content: Text(l10n.backupChooseRestoreTypeTip),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.backupRestoreOriginalBtn),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.backupTransferToCurrentShop),
          ),
        ],
      ),
    );
    if (remap == null) return;

    final selected = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CollectionPickerDialog(
        title: l10n.backupSelectDataSqlite,
        confirmLabel: l10n.backupRestoreBtn,
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
          title: Text(l10n.backupRestoreSuccessTitle),
          content: Text(
            remap
                ? l10n.backupRestoredCloudWithTransfer(selected.length)
                : l10n.backupRestoredCloudNoTransfer(selected.length),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
    } catch (e) {
      NotificationService.showSnackBar(
        _friendlyCloudError(l10n, l10n.backupRestoreBtn, e),
        color: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Selective data delete ──────────────────────────────────────────────────

  Future<void> _deleteSelectedData(List<String> collections, String label) async {
    final l10n = AppLocalizations.of(context)!;
    bool deleteCloudToo = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.backupDeleteWarningTitle(label), style: const TextStyle(fontSize: 15))),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.backupDeleteWarningContent),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: deleteCloudToo,
                  onChanged: (v) => setDialogState(() => deleteCloudToo = v ?? false),
                  title: Text(l10n.backupDeleteCloudTooLabel),
                  subtitle: Text(l10n.backupDeleteCloudTooSubtitle),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.backupDeleteForever),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    try {
      final localRows = await BackupService.deleteSelectedData(collections);
      int cloudRows = 0;
      if (deleteCloudToo) {
        cloudRows = await BackupService.deleteSelectedDataFromCloud(
          collections: collections,
        );
      }
      if (mounted) {
        NotificationService.showSnackBar(
          deleteCloudToo
              ? l10n.backupDeleteSuccessWithCloud(localRows, cloudRows, label)
              : l10n.backupDeleteSuccessLocalOnly(localRows, label),
          color: AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) NotificationService.showSnackBar(l10n.backupDeleteErrorMsg(e.toString()), color: AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteCustomData() async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CollectionPickerDialog(
        title: l10n.backupSelectDataToDelete,
        confirmLabel: l10n.delete,
        confirmIcon: Icons.delete_outline,
        confirmColor: Colors.red,
        availableCollections: null,
      ),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    await _deleteSelectedData(selected, l10n.backupSelectedCountLabel(selected.length));
  }

  // ── Clean old backups ──────────────────────────────────────────────────────

  Future<void> _cleanOldBackups() async {
    final l10n = AppLocalizations.of(context)!;
    final days = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.backupKeepDaysTitle),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 30),
            child: Text(l10n.backupKeep30Days),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 60),
            child: Text(l10n.backupKeep60Days),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 90),
            child: Text(l10n.backupKeep90Days),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 180),
            child: Text(l10n.backupKeep180Days),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey)),
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
              ? l10n.backupNoOldFiles(days)
              : l10n.backupDeletedOldFiles(count, days),
          color: AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) NotificationService.showSnackBar(l10n.backupCleanError(e.toString()), color: AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Widget> _deletePresetGroup(
    String label,
    Color color,
    List<(String, IconData, List<String>)> items,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: items.map((item) {
          final (lbl, icon, cols) = item;
          return OutlinedButton.icon(
            onPressed: _loading ? null : () => _deleteSelectedData(cols, lbl),
            icon: Icon(icon, size: 14),
            label: Text(lbl, style: const TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 10),
    ];
  }

  String _friendlyCloudError(AppLocalizations l10n, String action, Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('permission-denied') || raw.contains('unauthorized')) {
      return l10n.backupCloudPermissionError(action);
    }
    if (raw.contains('object-not-found')) {
      return l10n.backupCloudNotFoundError(action);
    }
    if (raw.contains('unauthenticated')) {
      return l10n.backupCloudAuthError(action);
    }
    return l10n.backupCloudGenericError(action, error.toString());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _SectionCard(
              title: l10n.backupSqliteSectionTitle,
              icon: Icons.backup,
              children: [
                _ActionButton(label: l10n.backupSaveToDevice, icon: Icons.save_alt, onTap: _loading ? null : _exportToLocal),
                AppSpacing.gapSm,
                if (_localBackups.isNotEmpty)
                  _ActionButton(
                    label: l10n.backupShareLatest,
                    icon: Icons.share,
                    onTap: _loading ? null : () => _shareLocalBackup(_localBackups.first),
                  ),
                if (_lastSavedPath != null) ...[
                  AppSpacing.gapSm,
                  Text(
                    l10n.backupSavedPathLabel(_lastSavedPath!.split('\\').last),
                    style: TextStyle(
                      fontSize: AppTextStyles.subtitle1Size,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                AppSpacing.gapSm,
                _ActionButton(label: l10n.backupUploadToCloud, icon: Icons.cloud_upload, onTap: _loading ? null : _backupToCloud, color: const Color(0xFF0A56C2)),
              ],
            ),
            AppSpacing.gapMd,
            _SectionCard(
              title: l10n.backupLocalListTitle,
              icon: Icons.folder_outlined,
              trailing: IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _loading ? null : _loadLocalBackups,
                tooltip: l10n.refresh,
              ),
              children: [
                if (_localBackups.isEmpty)
                  Text(
                    l10n.backupNoLocalBackupsHint,
                    style: TextStyle(fontSize: AppTextStyles.subtitle1Size, color: AppColors.textSecondary),
                  )
                else
                  ..._localBackups.map(
                    (b) => _LocalSqliteBackupItem(
                      backup: b,
                      onRestoreFromPath: () => _restoreFromLocalPath(b.path),
                      onShare: () => _shareLocalBackup(b),
                      onDelete: () => _deleteLocalBackup(b),
                    ),
                  ),
              ],
            ),
            AppSpacing.gapMd,
            _SectionCard(
              title: l10n.backupQuickGuideTitle,
              icon: Icons.help_outline,
              children: [
                Text(l10n.backupQuickGuideOffline),
                const SizedBox(height: 4),
                Text(l10n.backupQuickGuideShare),
                const SizedBox(height: 4),
                Text(l10n.backupQuickGuideRestoreOffline),
                const SizedBox(height: 4),
                Text(l10n.backupQuickGuideRestoreOnline),
              ],
            ),
            AppSpacing.gapMd,
            _SectionCard(
              title: l10n.backupCloudListTitle,
              icon: Icons.cloud,
              children: [
                if (!_backupsLoaded)
                  const Center(child: CircularProgressIndicator())
                else if (_storageUnauthorized)
                  _StorageAuthWarning()
                else if (_cloudBackups.isEmpty)
                  Text(l10n.backupNoCloudBackups, style: TextStyle(fontSize: AppTextStyles.subtitle1Size, color: AppColors.textSecondary))
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
              title: l10n.backupRestoreFromFileTitle,
              icon: Icons.restore,
              children: [
                Text(l10n.backupRestoreFileHint, style: TextStyle(fontSize: AppTextStyles.subtitle1Size, color: AppColors.textSecondary)),
                AppSpacing.gapSm,
                _ActionButton(label: l10n.backupSelectFile, icon: Icons.folder_open, onTap: _loading ? null : _restoreFromFile, color: AppColors.warning),
              ],
            ),
            AppSpacing.gapMd,
            _SectionCard(
              title: 'Nhập từ KiotViet',
              icon: Icons.upload_file_outlined,
              children: [
                const Text(
                  'Nhập danh sách sản phẩm, khách hàng, nhà cung cấp từ file Excel xuất bởi KiotViet.',
                  style: TextStyle(fontSize: AppTextStyles.subtitle1Size, color: AppColors.textSecondary),
                ),
                AppSpacing.gapSm,
                _ActionButton(
                  label: 'Mở màn hình nhập KiotViet',
                  icon: Icons.arrow_forward_rounded,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const KiotVietImportView()),
                  ),
                  color: const Color(0xFF0068D6),
                ),
              ],
            ),
            AppSpacing.gapMd,
            _SectionCard(
              title: l10n.backupDeleteSelectiveTitle,
              icon: Icons.delete_sweep_outlined,
              children: [
                Text(
                  l10n.backupDeleteSelectiveHint,
                  style: const TextStyle(fontSize: AppTextStyles.subtitle1Size, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                ..._deletePresetGroup(l10n.backupGroupOperations, const Color(0xFF1565C0), [
                  (l10n.backupColRepairs, Icons.build_outlined, ['repairs']),
                  (l10n.backupColSales, Icons.point_of_sale_outlined, ['sales']),
                  (l10n.backupPresetInventoryCash, Icons.assignment_outlined, ['inventory_checks', 'cash_closings']),
                ]),
                ..._deletePresetGroup(l10n.backupGroupWarehouse, const Color(0xFF00695C), [
                  (l10n.backupPresetAccessoriesProducts, Icons.inventory_2_outlined, ['products']),
                  (l10n.backupPresetRepairParts, Icons.build_circle_outlined, ['repair_parts']),
                  (l10n.backupColSalvagePhones, Icons.phone_android_outlined, ['salvage_phones']),
                  (l10n.backupPresetSupplierImport, Icons.local_shipping_outlined, ['suppliers', 'purchase_orders', 'import_orders', 'supplier_import_history']),
                ]),
                ..._deletePresetGroup(l10n.backupGroupFinance, const Color(0xFF2E7D32), [
                  (l10n.backupColDebts, Icons.account_balance_outlined, ['debts', 'debt_payments']),
                  (l10n.backupColExpenses, Icons.receipt_long_outlined, ['expenses']),
                  (l10n.backupPresetPayments, Icons.payment_outlined, ['payment_intents', 'payment_requests', 'supplier_payments', 'repair_partner_payments']),
                ]),
                ..._deletePresetGroup(l10n.backupPresetOther, const Color(0xFF546E7A), [
                  (l10n.backupColCustomers, Icons.person_outline, ['customers']),
                  (l10n.backupPresetHr, Icons.people_outline, ['attendance', 'payroll_settings', 'work_schedules']),
                  (l10n.backupPresetSystemLog, Icons.history_outlined, ['audit_logs']),
                ]),
                _ActionButton(
                  label: l10n.backupSelectCustomItems,
                  icon: Icons.checklist_outlined,
                  onTap: _loading ? null : _deleteCustomData,
                  color: Colors.red,
                ),
              ],
            ),
            AppSpacing.gapMd,
            _SectionCard(
              title: l10n.backupCleanOldTitle,
              icon: Icons.cleaning_services_outlined,
              children: [
                Text(
                  l10n.backupCleanOldHint,
                  style: const TextStyle(fontSize: AppTextStyles.subtitle1Size, color: AppColors.textSecondary),
                ),
                AppSpacing.gapSm,
                _ActionButton(
                  label: l10n.backupCleanOldBtn,
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
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupLocalRestoreTitle),
        content: Text(l10n.backupLocalRestoreContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.backupRestoreBtn),
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
          title: Text(l10n.backupChooseRestoreType),
          content: Text(l10n.backupChooseRestoreTypeTip),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.backupRestoreOriginalBtn),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.backupTransferToCurrentShop),
            ),
          ],
        ),
      );
      if (remap == null) return;

      final selected = await showDialog<List<String>>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _CollectionPickerDialog(
          title: l10n.backupSelectDataSqlite,
          confirmLabel: l10n.backupRestoreBtn,
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
          title: Text(l10n.backupRestoreSuccessTitle),
          content: Text(
            remap
                ? l10n.backupRestoredLocalWithTransfer(selected.length)
                : l10n.backupRestoredLocalNoTransfer(selected.length),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.close)),
          ],
        ),
      );
    } catch (e) {
      NotificationService.showSnackBar(l10n.backupRestoreLocalErrorMsg(e.toString()), color: AppColors.error);
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
    final l10n = AppLocalizations.of(context)!;
    final groups = _buildGroups(l10n);
    final colLabels = <String, String>{
      for (final g in groups)
        for (final item in g.items)
          item.key: item.label,
    };
    final selected = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CollectionPickerDialog(
        title: l10n.backupSelectDataBackup,
        confirmLabel: l10n.backupBackupLabel,
        confirmIcon: Icons.cloud_upload_outlined,
        confirmColor: const Color(0xFF0A56C2),
        availableCollections: null,
      ),
    );
    if (selected == null || selected.isEmpty) return;

    setState(() { _loading = true; _progressMsg = l10n.backupPreparingMsg; });
    try {
      await BackupService.backupFirestoreToCloud(
        collections: selected,
        onProgress: (col, done, total) {
          if (mounted) {
            setState(() => _progressMsg = l10n.backupBackingUpItem(colLabels[col] ?? col, done, total));
          }
        },
      );
      NotificationService.showSnackBar(l10n.backupFirestoreSuccess(selected.length), color: AppColors.success);
      await _loadBackupSets();
    } catch (e) {
      NotificationService.showSnackBar(l10n.backupFirestoreError(e.toString()), color: AppColors.error);
    } finally {
      if (mounted) setState(() { _loading = false; _progressMsg = null; });
    }
  }

  Future<void> _restoreBackupSet(FirestoreBackupSet set) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CollectionPickerDialog(
        title: l10n.backupSelectDataSqlite,
        confirmLabel: l10n.backupRestoreBtn,
        confirmIcon: Icons.restore_outlined,
        confirmColor: Colors.orange,
        availableCollections: set.collections,
      ),
    );
    if (selected == null || selected.isEmpty) return;
    if (!mounted) return;

    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(set.createdAt);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 8),
          Text(l10n.backupConfirmRestoreTitle),
        ]),
        content: Text(l10n.backupConfirmRestoreContent(selected.length, formattedDate)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.backupRestoreBtn),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() { _loading = true; _progressMsg = l10n.backupRestoringMsg; });
    try {
      await BackupService.restoreFirestoreFromCloud(
        backupSet: set,
        collections: selected,
      );
      NotificationService.showSnackBar(l10n.backupRestoreSuccessMsg(selected.length), color: AppColors.success);
    } catch (e) {
      NotificationService.showSnackBar(l10n.backupRestoreFirestoreError(e.toString()), color: AppColors.error);
    } finally {
      if (mounted) setState(() { _loading = false; _progressMsg = null; });
    }
  }

  Future<void> _deleteBackupSet(FirestoreBackupSet set) async {
    final l10n = AppLocalizations.of(context)!;
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(set.createdAt);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupDeleteSetTitle),
        content: Text(l10n.backupDeleteSetContent(formattedDate)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await BackupService.deleteFirestoreBackupSet(set);
      await _loadBackupSets();
      NotificationService.showSnackBar(l10n.backupDeletedSet, color: AppColors.success);
    } catch (e) {
      NotificationService.showSnackBar(l10n.backupDeleteSetErrorMsg(e.toString()), color: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    l10n.backupFirestoreInfoText,
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  )),
                ]),
              ),
            ),
            AppSpacing.gapMd,
            _SectionCard(
              title: l10n.backupRestoreByItemTitle,
              icon: Icons.tune,
              children: [
                Text(l10n.backupRestoreByItemDesc1),
                const SizedBox(height: 4),
                Text(l10n.backupRestoreByItemDesc2),
              ],
            ),
            AppSpacing.gapMd,

            // Backup now
            _SectionCard(
              title: l10n.backupFirestoreSectionTitle,
              icon: Icons.cloud_upload_outlined,
              children: [
                _ActionButton(
                  label: l10n.backupSelectAndBackup,
                  icon: Icons.cloud_upload,
                  onTap: _loading ? null : _startBackup,
                  color: const Color(0xFF0A56C2),
                ),
              ],
            ),
            AppSpacing.gapMd,

            // Backup sets list
            _SectionCard(
              title: l10n.backupFirestoreListTitle,
              icon: Icons.history,
              trailing: IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _loading ? null : _loadBackupSets,
                tooltip: l10n.refresh,
              ),
              children: [
                if (!_setsLoaded)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                else if (_backupSets.isEmpty)
                  Text(l10n.backupNoFirestoreBackups, style: TextStyle(fontSize: AppTextStyles.subtitle1Size, color: AppColors.textSecondary))
                else
                  ..._backupSets.map((set) => _FirestoreBackupItem(
                        set: set,
                        onRestore: () => _restoreBackupSet(set),
                        onDelete: () => _deleteBackupSet(set),
                      )),
              ],
            ),
            AppSpacing.gapMd,
            _MigrationEntryCard(),
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
                    Text(_progressMsg ?? l10n.backupProcessing, style: const TextStyle(fontSize: 14)),
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Tab 3: Đơn sửa kèm ảnh ────────────────────────────────────────────────────

class _RepairImagesTab extends StatefulWidget {
  const _RepairImagesTab();

  @override
  State<_RepairImagesTab> createState() => _RepairImagesTabState();
}

class _RepairImagesTabState extends State<_RepairImagesTab> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  bool _running = false;
  int _done = 0;
  int _total = 0;
  List<LocalSqliteBackup> _pastBackups = [];

  @override
  void initState() {
    super.initState();
    _loadPastBackups();
  }

  Future<void> _loadPastBackups() async {
    try {
      final list = await BackupService.listRepairImageBackups();
      if (mounted) setState(() => _pastBackups = list);
    } catch (_) {
      // Ignore local listing errors.
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  Future<void> _runBackup() async {
    setState(() {
      _running = true;
      _done = 0;
      _total = 0;
    });
    try {
      final result = await BackupService.backupRepairsWithImages(
        from: _from,
        to: _to,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _done = done;
            _total = total;
          });
        },
      );
      if (!mounted) return;
      await _loadPastBackups();
      final failedNote = result.failedImageCount > 0
          ? ', ${result.failedImageCount} ảnh lỗi khi tải'
          : '';
      NotificationService.showSnackBar(
        'Đã sao lưu ${result.repairCount} đơn, ${result.imageCount} ảnh$failedNote',
        color: AppColors.success,
      );
      await BackupService.shareRepairImageBackup(result.filePath);
    } catch (e) {
      if (!mounted) return;
      NotificationService.showSnackBar(
        'Sao lưu thất bại: $e',
        color: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _deleteBackup(LocalSqliteBackup backup) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa file sao lưu?'),
        content: Text(backup.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await BackupService.deleteRepairImageBackup(backup.path);
      await _loadPastBackups();
    } catch (e) {
      if (!mounted) return;
      NotificationService.showSnackBar('Lỗi khi xóa: $e', color: AppColors.error);
    }
  }

  String _formatSize(int size) {
    if (size < 1024) return '${size}B';
    final kb = size / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)}KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _SectionCard(
          title: 'Sao lưu đơn sửa kèm ảnh',
          icon: Icons.photo_library_outlined,
          children: [
            const Text(
              'Đóng gói thông tin đơn sửa + toàn bộ ảnh nhận/giao máy đã '
              'tải lên trong khoảng ngày chọn thành 1 file .zip để chia sẻ '
              'lưu trữ ngoài (Drive, Zalo, email...). Ảnh chưa upload xong '
              '(còn ở máy cũ, chưa đồng bộ) sẽ không có trong bản sao lưu.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _running ? null : _pickRange,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, size: 18, color: Color(0xFF0A56C2)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${df.format(_from)} → ${df.format(_to)}'),
                    ),
                    const Icon(Icons.edit, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_running) ...[
              LinearProgressIndicator(
                value: _total > 0 ? _done / _total : null,
              ),
              const SizedBox(height: 6),
              Text(
                _total > 0
                    ? 'Đang xử lý $_done/$_total đơn sửa...'
                    : 'Đang tải danh sách đơn sửa...',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
            ],
            _ActionButton(
              label: _running ? 'Đang sao lưu...' : 'Bắt đầu sao lưu',
              icon: Icons.archive_outlined,
              onTap: _running ? null : _runBackup,
              color: const Color(0xFF0A56C2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_pastBackups.isNotEmpty)
          _SectionCard(
            title: 'Đã sao lưu trên máy này',
            icon: Icons.folder_zip_outlined,
            children: [
              for (final backup in _pastBackups)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.textHint,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.folder_zip, color: Colors.deepOrange),
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
                          onPressed: () =>
                              BackupService.shareRepairImageBackup(backup.path),
                          tooltip: 'Chia sẻ',
                          icon: const Icon(Icons.share_outlined, size: 20),
                        ),
                        IconButton(
                          onPressed: () => _deleteBackup(backup),
                          tooltip: 'Xóa',
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
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
    for (final key in _kAllCollectionKeys) {
      _checked[key] = false;
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
    final l10n = AppLocalizations.of(context)!;
    final groups = _buildGroups(l10n);
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
                title: Text(l10n.selectAll, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(l10n.backupSelectedCountLabel(_selectedCount)),
                onChanged: (v) => _toggleAll(v == true),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: groups.map((g) {
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
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
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
    final l10n = AppLocalizations.of(context)!;
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
              subtitle: available ? null : Text(l10n.backupNotAvailable, style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
    final l10n = AppLocalizations.of(context)!;
    final groups = _buildGroups(l10n);
    final colLabels = <String, String>{
      for (final g in groups)
        for (final item in g.items)
          item.key: item.label,
    };
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
                  tooltip: l10n.backupRestoreBtn,
                  onPressed: onRestore,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: l10n.delete,
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: set.collections.map((col) {
                final lbl = colLabels[col] ?? col;
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.warning_amber, color: AppColors.warning, size: 16),
          const SizedBox(width: 6),
          Text(l10n.backupStorageRulesTitle, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.warning, fontSize: 13)),
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

// ─── Migration entry card (owner / super_admin only) ─────────────────────────

class _MigrationEntryCard extends StatefulWidget {
  const _MigrationEntryCard();

  @override
  State<_MigrationEntryCard> createState() => _MigrationEntryCardState();
}

class _MigrationEntryCardState extends State<_MigrationEntryCard> {
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final role = await UserService.getUserRole(uid);
    if (mounted) setState(() => _role = role);
  }

  @override
  Widget build(BuildContext context) {
    if (_role == null) return const SizedBox.shrink();
    if (_role != 'owner' && _role != 'super_admin') return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.deepOrange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.swap_horiz_rounded, color: Colors.deepOrange, size: 18),
              const SizedBox(width: 8),
              const Text('Chuyển đơn sửa chữa sang shop khác',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
            const Divider(height: 16),
            const Text(
              'Copy toàn bộ lịch sử đơn sửa chữa sang một shop mới.\n'
              'Dữ liệu shop cũ giữ nguyên, không bị xóa.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Bắt đầu chuyển dữ liệu'),
                onPressed: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => const ShopMigrationView()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SQLite backup item ───────────────────────────────────────────────────────

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
    final l10n = AppLocalizations.of(context)!;
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
            TextButton(onPressed: onRestore, child: Text(l10n.backupRestoreBtn)),
            IconButton(
              onPressed: onDelete,
              tooltip: l10n.delete,
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
  final VoidCallback onDelete;

  const _LocalSqliteBackupItem({
    required this.backup,
    required this.onRestoreFromPath,
    required this.onShare,
    required this.onDelete,
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
    final l10n = AppLocalizations.of(context)!;
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
              tooltip: l10n.share,
              icon: const Icon(Icons.share_outlined, size: 20),
            ),
            IconButton(
              onPressed: onRestoreFromPath,
              tooltip: l10n.backupRestoreBtn,
              icon: const Icon(Icons.restore_outlined, size: 20),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
