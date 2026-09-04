import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../services/excel_import_service.dart';
import '../utils/file_picker_types.dart';
import '../utils/excel_export_helper.dart';

/// Consolidated import/export Excel page (Settings → Nhập/Xuất dữ liệu).
///
/// Provides date-range filtering for exports and row-by-row progress
/// feedback for imports. Covers 5 data types: Sửa chữa, Mua bán,
/// Kho hàng, Khách hàng, Nhà cung cấp.
class ImportExportView extends StatefulWidget {
  const ImportExportView({super.key});

  @override
  State<ImportExportView> createState() => _ImportExportViewState();
}

// ─────────────────────────────────────────────────────────────────────────────
//  STATE
// ─────────────────────────────────────────────────────────────────────────────

class _ImportExportViewState extends State<ImportExportView> {
  // Date range
  _DatePreset _preset = _DatePreset.thisMonth;
  DateTimeRange? _customRange;

  DateTimeRange get _activeRange {
    if (_preset == _DatePreset.custom && _customRange != null) {
      return _customRange!;
    }
    return _preset.range;
  }

  int? get _startMs => _preset == _DatePreset.all
      ? null
      : _activeRange.start.millisecondsSinceEpoch;

  int? get _endMs => _preset == _DatePreset.all
      ? null
      : _activeRange.end
          .copyWith(hour: 23, minute: 59, second: 59)
          .millisecondsSinceEpoch;

  // ── date preset picker ──────────────────────────────────────────────────

  void _selectPreset(_DatePreset p) async {
    if (p == _DatePreset.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)),
        initialDateRange: _customRange ?? _activeRange,
        locale: const Locale('vi', 'VN'),
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() {
        _customRange = picked;
        _preset = _DatePreset.custom;
      });
    } else {
      setState(() => _preset = p);
    }
  }

  // ── EXPORT ─────────────────────────────────────────────────────────────

  Future<void> _export(_DataType dt) async {
    switch (dt) {
      case _DataType.repairs:
        await ExcelExportHelper.exportRepairs(
          context,
          startMs: _startMs,
          endMs: _endMs,
        );
      case _DataType.sales:
        await ExcelExportHelper.exportSales(
          context,
          startMs: _startMs,
          endMs: _endMs,
        );
      case _DataType.products:
        await ExcelExportHelper.exportProducts(
          context,
          startMs: _startMs,
          endMs: _endMs,
        );
      case _DataType.customers:
        await ExcelExportHelper.exportCustomers(
          context,
          startMs: _startMs,
          endMs: _endMs,
        );
      case _DataType.suppliers:
        await ExcelExportHelper.exportSuppliers(
          context,
          startMs: _startMs,
          endMs: _endMs,
        );
    }
  }

  // ── IMPORT ─────────────────────────────────────────────────────────────

  Future<void> _import(_DataType dt) async {
    // Dung FilePickerTypes — thieu `uniformTypeIdentifiers` la iOS nem
    // ArgumentError, bam nut khong len gi.
    XFile? picked;
    try {
      picked = await openFile(acceptedTypeGroups: [FilePickerTypes.excel]);
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
    if (picked == null || !mounted) return;
    final file = picked;

    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Không đọc được file: $e', error: true);
      return;
    }

    if (!mounted) return;
    await _showImportDialog(dt, bytes);
  }

  Future<void> _showImportDialog(_DataType dt, Uint8List bytes) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ImportProgressDialog(
        dataType: dt,
        bytes: bytes,
      ),
    );
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhập / Xuất dữ liệu'),
        backgroundColor: const Color(0xFF3730A3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DateFilterBar(
            selected: _preset,
            customRange: _customRange,
            onSelect: _selectPreset,
          ),
          const SizedBox(height: 12),
          const _SectionHeader(
            icon: Icons.info_outline,
            text:
                'Bộ lọc thời gian chỉ áp dụng khi Xuất. Khi Nhập, dữ liệu được đọc từ file.',
          ),
          const SizedBox(height: 16),
          ..._DataType.values.map(
            (dt) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DataTypeCard(
                dataType: dt,
                onExport: () => _export(dt),
                onImport: () => _import(dt),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DATE FILTER BAR
// ─────────────────────────────────────────────────────────────────────────────

enum _DatePreset {
  all,
  today,
  thisWeek,
  thisMonth,
  thisYear,
  custom;

  String get label {
    switch (this) {
      case _DatePreset.all:
        return 'Tất cả';
      case _DatePreset.today:
        return 'Hôm nay';
      case _DatePreset.thisWeek:
        return 'Tuần này';
      case _DatePreset.thisMonth:
        return 'Tháng này';
      case _DatePreset.thisYear:
        return 'Năm này';
      case _DatePreset.custom:
        return 'Tuỳ chọn';
    }
  }

  DateTimeRange get range {
    final now = DateTime.now();
    switch (this) {
      case _DatePreset.today:
        final start = DateTime(now.year, now.month, now.day);
        return DateTimeRange(start: start, end: now);
      case _DatePreset.thisWeek:
        final start =
            DateTime(now.year, now.month, now.day - (now.weekday - 1));
        return DateTimeRange(start: start, end: now);
      case _DatePreset.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
      case _DatePreset.thisYear:
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
      default:
        return DateTimeRange(start: DateTime(2020), end: now);
    }
  }
}

class _DateFilterBar extends StatelessWidget {
  final _DatePreset selected;
  final DateTimeRange? customRange;
  final void Function(_DatePreset) onSelect;

  const _DateFilterBar({
    required this.selected,
    this.customRange,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.date_range,
                    color: Color(0xFF3730A3), size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Lọc thời gian xuất',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (selected == _DatePreset.custom && customRange != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${_fmt(customRange!.start)} – ${_fmt(customRange!.end)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF3730A3),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 6,
                children: _DatePreset.values.map((p) {
                  final isSelected = p == selected;
                  return FilterChip(
                    label: Text(p.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF475569),
                        )),
                    selected: isSelected,
                    onSelected: (_) => onSelect(p),
                    selectedColor: const Color(0xFF3730A3),
                    backgroundColor: const Color(0xFFF8FAFC),
                    checkmarkColor: Colors.white,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF3730A3)
                          : const Color(0xFFCBD5E1),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
//  DATA TYPE CARD
// ─────────────────────────────────────────────────────────────────────────────

enum _DataType {
  repairs,
  sales,
  products,
  customers,
  suppliers;

  String get title {
    switch (this) {
      case _DataType.repairs:
        return 'Đơn sửa chữa';
      case _DataType.sales:
        return 'Đơn mua bán';
      case _DataType.products:
        return 'Kho hàng';
      case _DataType.customers:
        return 'Khách hàng';
      case _DataType.suppliers:
        return 'Nhà cung cấp';
    }
  }

  String get subtitle {
    switch (this) {
      case _DataType.repairs:
        return 'Lịch sử nhận & sửa máy, trạng thái, giá dịch vụ';
      case _DataType.sales:
        return 'Đơn bán hàng, thông tin thanh toán';
      case _DataType.products:
        return 'Tồn kho, giá vốn, giá bán, IMEI';
      case _DataType.customers:
        return 'Danh sách khách hàng, lịch sử mua';
      case _DataType.suppliers:
        return 'Danh sách nhà cung cấp';
    }
  }

  IconData get icon {
    switch (this) {
      case _DataType.repairs:
        return Icons.build_rounded;
      case _DataType.sales:
        return Icons.shopping_cart_rounded;
      case _DataType.products:
        return Icons.inventory_2_rounded;
      case _DataType.customers:
        return Icons.people_rounded;
      case _DataType.suppliers:
        return Icons.business_rounded;
    }
  }

  Color get color {
    switch (this) {
      case _DataType.repairs:
        return const Color(0xFF0EA5E9);
      case _DataType.sales:
        return const Color(0xFF10B981);
      case _DataType.products:
        return const Color(0xFFF59E0B);
      case _DataType.customers:
        return const Color(0xFF8B5CF6);
      case _DataType.suppliers:
        return const Color(0xFFEC4899);
    }
  }

  Color get bgColor {
    switch (this) {
      case _DataType.repairs:
        return const Color(0xFFE0F2FE);
      case _DataType.sales:
        return const Color(0xFFD1FAE5);
      case _DataType.products:
        return const Color(0xFFFEF3C7);
      case _DataType.customers:
        return const Color(0xFFEDE9FE);
      case _DataType.suppliers:
        return const Color(0xFFFCE7F3);
    }
  }
}

class _DataTypeCard extends StatelessWidget {
  final _DataType dataType;
  final VoidCallback onExport;
  final VoidCallback onImport;

  const _DataTypeCard({
    required this.dataType,
    required this.onExport,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: dataType.bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(dataType.icon, color: dataType.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dataType.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dataType.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _ActionBtn(
                  label: 'Xuất',
                  icon: Icons.file_download_rounded,
                  color: dataType.color,
                  onTap: onExport,
                ),
                const SizedBox(height: 6),
                _ActionBtn(
                  label: 'Nhập',
                  icon: Icons.file_upload_rounded,
                  color: const Color(0xFF64748B),
                  onTap: onImport,
                  outlined: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: const Size(70, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(70, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  IMPORT PROGRESS DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _ImportProgressDialog extends StatefulWidget {
  final _DataType dataType;
  final Uint8List bytes;

  const _ImportProgressDialog({
    required this.dataType,
    required this.bytes,
  });

  @override
  State<_ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<_ImportProgressDialog> {
  int _current = 0;
  int _total = 0;
  String _msg = 'Đang khởi động…';
  ImportResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    void onProgress(int current, int total, String msg) {
      if (!mounted) return;
      setState(() {
        _current = current;
        _total = total;
        _msg = msg;
      });
    }

    ImportResult result;
    try {
      switch (widget.dataType) {
        case _DataType.repairs:
          result = await ExcelImportService.importRepairs(
            widget.bytes,
            onProgress: onProgress,
          );
        case _DataType.sales:
          result = await ExcelImportService.importSales(
            widget.bytes,
            onProgress: onProgress,
          );
        case _DataType.products:
          result = await ExcelImportService.importProducts(
            widget.bytes,
            onProgress: onProgress,
          );
        case _DataType.customers:
          result = await ExcelImportService.importCustomers(
            widget.bytes,
            onProgress: onProgress,
          );
        case _DataType.suppliers:
          result = await ExcelImportService.importSuppliers(
            widget.bytes,
            onProgress: onProgress,
          );
      }
    } catch (e) {
      result = ImportResult(
        dataType: widget.dataType.title,
        total: _total,
        success: _current,
        errors: ['Lỗi không xác định: $e'],
      );
    }

    if (!mounted) return;
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final done = _result != null;

    return PopScope(
      canPop: done,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: done ? _buildResult() : _buildProgress(),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final pct = _total > 0 ? (_current / _total).clamp(0.0, 1.0) : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.dataType.icon,
            color: widget.dataType.color, size: 40),
        const SizedBox(height: 12),
        Text(
          'Đang nhập ${widget.dataType.title}…',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: pct,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
          color: widget.dataType.color,
        ),
        const SizedBox(height: 12),
        Text(
          _total > 0 ? '$_current / $_total hàng' : 'Đang đọc file…',
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 4),
        Text(
          _msg,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildResult() {
    final r = _result!;
    final success = r.success;
    final failed = r.failed;
    final hasErrors = r.hasErrors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              hasErrors ? Icons.warning_rounded : Icons.check_circle_rounded,
              color: hasErrors ? Colors.orange : Colors.green,
              size: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasErrors ? 'Hoàn thành (có lỗi)' : 'Nhập thành công!',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StatRow(
          label: 'Tổng hàng:',
          value: '${r.total}',
          color: const Color(0xFF475569),
        ),
        _StatRow(
          label: 'Thành công:',
          value: '$success',
          color: Colors.green.shade700,
        ),
        if (failed > 0)
          _StatRow(
            label: 'Lỗi:',
            value: '$failed',
            color: Colors.red.shade700,
          ),
        if (hasErrors) ...[
          const SizedBox(height: 8),
          const Text(
            'Chi tiết lỗi:',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF374151)),
          ),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Text(
                r.errors.take(20).join('\n'),
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF991B1B),
                    fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3730A3),
            ),
            child: const Text('Đóng'),
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(width: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionHeader({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1D4ED8)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF1D4ED8)),
            ),
          ),
        ],
      ),
    );
  }
}
