import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../services/kiotviet_excel_import_service.dart';
import '../services/notification_service.dart';
import '../services/sync_orchestrator.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/custom_app_bar.dart';

class KiotVietImportView extends StatefulWidget {
  const KiotVietImportView({super.key});

  @override
  State<KiotVietImportView> createState() => _KiotVietImportViewState();
}

class _KiotVietImportViewState extends State<KiotVietImportView> {
  bool _loading = false;
  bool _overwrite = false;

  // Per-type state
  final Map<String, _FileState> _files = {
    'products': const _FileState(),
    'customers': const _FileState(),
    'suppliers': const _FileState(),
    'purchase_orders': const _FileState(),
    'sales': const _FileState(),
  };

  static const _typeLabel = {
    'products': 'Sản phẩm / Kho hàng',
    'customers': 'Khách hàng',
    'suppliers': 'Nhà cung cấp',
    'purchase_orders': 'Phiếu nhập hàng (NCC)',
    'sales': 'Hóa đơn bán hàng',
  };

  static const _typeHint = {
    'products': 'DanhSachSanPham_KV*.xlsx',
    'customers': 'DanhSachKhachHang_KV*.xlsx',
    'suppliers': 'DanhSachNhaCungCap_KV*.xlsx',
    'purchase_orders': 'DanhSachChiTietNhapHang_KV*.xlsx',
    'sales': 'DanhSachChiTietHoaDon_KV*.xlsx',
  };

  static const _typeIcon = {
    'products': Icons.inventory_2_outlined,
    'customers': Icons.people_outline,
    'suppliers': Icons.store_outlined,
    'purchase_orders': Icons.local_shipping_outlined,
    'sales': Icons.receipt_long_outlined,
  };

  static const _typeColor = {
    'products': Color(0xFF1565C0),
    'customers': Color(0xFF6A1B9A),
    'suppliers': Color(0xFF2E7D32),
    'purchase_orders': Color(0xFFE65100),
    'sales': Color(0xFFBF360C),
  };

  // ── File picking ──────────────────────────────────────────────────────────

  Future<void> _pickFile(String type) async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Excel KiotViet',
          extensions: ['xlsx', 'xls'],
        ),
      ],
    );
    if (file == null) return;

    // Read bytes immediately while Android content-URI access is still valid.
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      if (!mounted) return;
      NotificationService.showSnackBar('Không đọc được file: $e', color: Colors.red);
      return;
    }

    final detected = await KiotVietExcelImportService.detectFileType(bytes);
    if (detected != null && detected != type) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('File không khớp loại'),
          content: Text(
            'File này có vẻ là danh sách "${_typeLabel[detected]}", '
            'nhưng bạn đang chọn cho "${_typeLabel[type]}".\n\n'
            'Tiếp tục nhập vào "${_typeLabel[type]}" không?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tiếp tục')),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() {
      _files[type] = _FileState(
        path: file.path,
        name: file.name,
        bytes: bytes,
        detectedType: detected,
      );
    });
  }

  void _clearFile(String type) => setState(() => _files[type] = _FileState());

  // ── Import ─────────────────────────────────────────────────────────────────

  Future<void> _import() async {
    final toImport = _files.entries.where((e) => e.value.path != null).toList();
    if (toImport.isEmpty) {
      NotificationService.showSnackBar('Chưa chọn file nào', color: Colors.orange);
      return;
    }

    setState(() {
      _loading = true;
      for (final e in toImport) {
        _files[e.key] = e.value.copyWith(status: _ImportStatus.running, progress: 0);
      }
    });

    KvImportResult total = const KvImportResult();

    for (final entry in toImport) {
      final type = entry.key;
      final state = entry.value;

      try {
        KvImportResult result;
        final bytes = state.bytes!;
        switch (type) {
          case 'products':
            result = await KiotVietExcelImportService.importProducts(
              bytes,
              overwriteExisting: _overwrite,
              onProgress: (done, total) => _setProgress(type, done, total),
            );
          case 'customers':
            result = await KiotVietExcelImportService.importCustomers(
              bytes,
              overwriteExisting: _overwrite,
              onProgress: (done, t) => _setProgress(type, done, t),
            );
          case 'purchase_orders':
            result = await KiotVietExcelImportService.importPurchaseOrders(
              bytes,
              overwriteExisting: _overwrite,
              onProgress: (done, t) => _setProgress(type, done, t),
            );
          case 'sales':
            result = await KiotVietExcelImportService.importSales(
              bytes,
              overwriteExisting: _overwrite,
              onProgress: (done, t) => _setProgress(type, done, t),
            );
          case 'suppliers':
          default:
            result = await KiotVietExcelImportService.importSuppliers(
              bytes,
              overwriteExisting: _overwrite,
              onProgress: (done, t) => _setProgress(type, done, t),
            );
        }
        total = total + result;
        if (mounted) {
          setState(() => _files[type] = state.copyWith(
            status: result.hasErrors ? _ImportStatus.partial : _ImportStatus.done,
            result: result,
          ));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _files[type] = state.copyWith(
            status: _ImportStatus.error,
            result: KvImportResult(errors: ['$e']),
          ));
        }
      }
    }

    setState(() => _loading = false);

    // Trigger Firestore sync so imported data reaches cloud
    SyncOrchestrator().syncAll().ignore();

    if (!mounted) return;
    final msg = 'Nhập xong: ${total.inserted} mới, ${total.updated} cập nhật, '
        '${total.skipped} bỏ qua${total.hasErrors ? " (có lỗi)" : ""}';
    NotificationService.showSnackBar(msg,
        color: total.hasErrors ? Colors.orange : AppColors.success);
  }

  void _setProgress(String type, int done, int total) {
    if (!mounted) return;
    setState(() {
      _files[type] = _files[type]!.copyWith(progress: total > 0 ? done / total : 0);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final anySelected = _files.values.any((f) => f.path != null);

    return Scaffold(
      appBar: CustomAppBar.build(
        title: 'Nhập từ KiotViet',
        subtitle: 'Import danh sách Excel xuất từ KiotViet',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGuide(),
            const SizedBox(height: 16),
            ...['products', 'customers', 'suppliers', 'purchase_orders', 'sales'].map(_buildFileCard),
            const SizedBox(height: 12),
            _buildOptions(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: (_loading || !anySelected) ? null : _import,
                icon: _loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))

                    : const Icon(Icons.upload_rounded),
                label: Text(_loading ? 'Đang nhập dữ liệu...' : 'Nhập dữ liệu vào shop'),
                style: FilledButton.styleFrom(
                  backgroundColor: anySelected ? AppColors.primary : Colors.grey,
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Dữ liệu sẽ được lưu vào thiết bị và tự động đồng bộ Cloud',
                style: AppTextStyles.caption.copyWith(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuide() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
            const SizedBox(width: 6),
            Text('Cách xuất file từ KiotViet',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
          ]),
          const SizedBox(height: 8),
          const Text(
            '1. Sản phẩm: KiotViet → Hàng hóa → Xuất file\n'
            '2. Khách hàng: KiotViet → Khách hàng → Xuất file\n'
            '3. Nhà cung cấp: KiotViet → Nhà cung cấp → Xuất file\n'
            '4. Phiếu nhập hàng: KiotViet → Nhập hàng → Xuất file chi tiết\n'
            '5. Hóa đơn bán: KiotViet → Bán hàng → Báo cáo → Xuất chi tiết',
            style: TextStyle(fontSize: 12, height: 1.7),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(String type) {
    final state = _files[type]!;
    final color = _typeColor[type]!;
    final icon = _typeIcon[type]!;
    final label = _typeLabel[type]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: state.path != null ? color : Colors.grey.shade300,
          width: state.path != null ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
        color: state.path != null ? color.withValues(alpha: 0.04) : Colors.white,
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, size: 20, color: color),
            ),
            title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: state.path != null
                ? Text(state.name!, style: TextStyle(fontSize: 11, color: color),
                    overflow: TextOverflow.ellipsis)
                : Text(_typeHint[type] ?? 'Chưa chọn file',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    overflow: TextOverflow.ellipsis),
            trailing: state.path != null
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    if (state.status == _ImportStatus.done)
                      Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                    if (state.status == _ImportStatus.partial)
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                    if (state.status == _ImportStatus.error)
                      Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _loading ? null : () => _clearFile(type),
                      visualDensity: VisualDensity.compact,
                    ),
                  ])
                : TextButton.icon(
                    onPressed: _loading ? null : () => _pickFile(type),
                    icon: Icon(Icons.folder_open_outlined, size: 16, color: color),
                    label: Text('Chọn file', style: TextStyle(color: color, fontSize: 13)),
                  ),
          ),
          // Progress bar
          if (state.status == _ImportStatus.running)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: state.progress,
                    backgroundColor: Colors.grey.shade200,
                    color: color,
                  ),
                  const SizedBox(height: 4),
                  Text('Đang nhập...', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
          // Result summary
          if (state.result != null && state.status != _ImportStatus.running)
            _buildResult(state.result!, color),
        ],
      ),
    );
  }

  Widget _buildResult(KvImportResult result, Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(children: [
            _chip('${result.inserted} mới', Colors.green.shade600),
            const SizedBox(width: 6),
            if (result.updated > 0) _chip('${result.updated} cập nhật', Colors.blue.shade600),
            if (result.updated > 0) const SizedBox(width: 6),
            if (result.skipped > 0) _chip('${result.skipped} bỏ qua', Colors.grey.shade600),
          ]),
          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 6),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('${result.errors.length} lỗi',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
              children: result.errors.take(10).map((e) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• $e',
                      style: const TextStyle(fontSize: 11, color: Colors.red)),
                ),
              ).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );

  Widget _buildOptions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SwitchListTile(
        title: const Text('Cập nhật bản ghi trùng', style: TextStyle(fontSize: 14)),
        subtitle: const Text(
          'Bật: trùng tên/SĐT → cập nhật thông tin\nTắt: trùng → bỏ qua (mặc định)',
          style: TextStyle(fontSize: 12),
        ),
        value: _overwrite,
        onChanged: _loading ? null : (v) => setState(() => _overwrite = v),
        activeThumbColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}

// ─── State helpers ─────────────────────────────────────────────────────────────

enum _ImportStatus { idle, running, done, partial, error }

class _FileState {
  final String? path;
  final String? name;
  final Uint8List? bytes;
  final String? detectedType;
  final _ImportStatus status;
  final double progress;
  final KvImportResult? result;

  const _FileState({
    this.path,
    this.name,
    this.bytes,
    this.detectedType,
    this.status = _ImportStatus.idle,
    this.progress = 0,
    this.result,
  });

  _FileState copyWith({
    String? path,
    String? name,
    Uint8List? bytes,
    String? detectedType,
    _ImportStatus? status,
    double? progress,
    KvImportResult? result,
  }) => _FileState(
    path: path ?? this.path,
    name: name ?? this.name,
    bytes: bytes ?? this.bytes,
    detectedType: detectedType ?? this.detectedType,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    result: result ?? this.result,
  );
}
