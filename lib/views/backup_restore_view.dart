import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_spacing.dart';
import '../widgets/custom_app_bar.dart';

class BackupRestoreView extends StatefulWidget {
  const BackupRestoreView({super.key});

  @override
  State<BackupRestoreView> createState() => _BackupRestoreViewState();
}

class _BackupRestoreViewState extends State<BackupRestoreView> {
  bool _loading = false;
  List<Map<String, String>> _cloudBackups = [];
  bool _backupsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCloudBackups();
  }

  bool _storageUnauthorized = false;

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
        final isUnauthorized = e.toString().contains('unauthorized') ||
            e.toString().contains('permission-denied');
        setState(() {
          _backupsLoaded = true;
          _storageUnauthorized = isUnauthorized;
        });
        if (!isUnauthorized) {
          NotificationService.showSnackBar(
            'Không thể tải danh sách backup: $e',
            color: AppColors.error,
          );
        }
      }
    }
  }

  Future<void> _exportToLocal() async {
    setState(() => _loading = true);
    try {
      await BackupService.exportToLocal(context);
    } catch (e) {
      NotificationService.showSnackBar(
        'Lỗi xuất file: $e',
        color: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _backupToCloud() async {
    setState(() => _loading = true);
    try {
      final url = await BackupService.backupToFirebase();
      NotificationService.showSnackBar(
        'Sao lưu thành công lên Cloud!',
        color: AppColors.success,
      );
      debugPrint('Backup URL: $url');
      await _loadCloudBackups();
    } catch (e) {
      NotificationService.showSnackBar(
        'Lỗi sao lưu Cloud: $e',
        color: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCloudRestoreNotice() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thông báo'),
        content: const Text(
          'Tính năng khôi phục từ cloud sẽ sớm ra mắt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreFromFile() async {
    const typeGroup = XTypeGroup(
      label: 'Database',
      extensions: ['db'],
    );
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
            content: const Text(
              'Đã khôi phục dữ liệu. Vui lòng khởi động lại ứng dụng để áp dụng thay đổi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      NotificationService.showSnackBar(
        'Lỗi khôi phục: $e',
        color: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar.build(
        title: 'Sao lưu & Khôi phục',
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Card: Sao lưu ngay
              _SectionCard(
                title: 'Sao lưu ngay',
                icon: Icons.backup,
                children: [
                  _ActionButton(
                    label: 'Chia sẻ / Lưu máy',
                    icon: Icons.share,
                    onTap: _loading ? null : _exportToLocal,
                  ),
                  AppSpacing.gapSm,
                  _ActionButton(
                    label: 'Sao lưu lên Cloud',
                    icon: Icons.cloud_upload,
                    onTap: _loading ? null : _backupToCloud,
                    color: const Color(0xFF0A56C2),
                  ),
                ],
              ),
              AppSpacing.gapMd,

              // Card: Bản sao lưu trên Cloud
              _SectionCard(
                title: 'Bản sao lưu trên Cloud',
                icon: Icons.cloud,
                children: [
                  if (!_backupsLoaded)
                    const Center(child: CircularProgressIndicator())
                  else if (_storageUnauthorized)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber, color: AppColors.warning, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Cần cấu hình Firebase Storage Rules',
                              style: TextStyle(
                                fontSize: AppTextStyles.h4,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Vào Firebase Console → Storage → Rules và thêm:\n'
                          'match /db_backups/{shopId}/{allPaths=**} {\n'
                          '  allow read, write: if request.auth != null;\n'
                          '}',
                          style: TextStyle(
                            fontSize: AppTextStyles.subtitle1Size,
                            color: AppColors.textSecondary,
                            fontFamily: 'monospace',
                            height: 1.5,
                          ),
                        ),
                      ],
                    )
                  else if (_cloudBackups.isEmpty)
                    Text(
                      'Chưa có bản sao lưu nào trên Cloud.',
                      style: TextStyle(
                        fontSize: AppTextStyles.subtitle1Size,
                        color: AppColors.textSecondary,
                      ),
                    )
                  else
                    ...(_cloudBackups.map((backup) => _BackupItem(
                          name: backup['name'] ?? '',
                          timestamp: backup['timestamp'] ?? '',
                          onRestore: _showCloudRestoreNotice,
                        ))),
                ],
              ),
              AppSpacing.gapMd,

              // Card: Khôi phục từ file
              _SectionCard(
                title: 'Khôi phục từ file',
                icon: Icons.restore,
                children: [
                  Text(
                    'Chọn file .db đã sao lưu trước đó để khôi phục dữ liệu.',
                    style: TextStyle(
                      fontSize: AppTextStyles.subtitle1Size,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  AppSpacing.gapSm,
                  _ActionButton(
                    label: 'Chọn file .db',
                    icon: Icons.folder_open,
                    onTap: _loading ? null : _restoreFromFile,
                    color: AppColors.warning,
                  ),
                ],
              ),
              AppSpacing.gapLg,
            ],
          ),
          if (_loading)
            const ColoredBox(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _BackupItem extends StatelessWidget {
  final String name;
  final String timestamp;
  final VoidCallback onRestore;

  const _BackupItem({
    required this.name,
    required this.timestamp,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.textHint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider!),
      ),
      child: ListTile(
        leading: const Icon(Icons.storage, color: Color(0xFF0A56C2)),
        title: Text(
          name,
          style: const TextStyle(
            fontSize: AppTextStyles.h4,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          timestamp,
          style: TextStyle(
            fontSize: AppTextStyles.subtitle1Size,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: TextButton(
          onPressed: onRestore,
          child: const Text('Khôi phục'),
        ),
      ),
    );
  }
}
