import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/price_catalog_models.dart';
import '../services/price_catalog_service.dart';
import '../services/supplier_invoice_price_book_service.dart';
import '../utils/money_utils.dart';
import '../widgets/custom_app_bar.dart';

/// "Nhập bảng giá từ hoá đơn NCC" — luồng riêng, KHÔNG dùng chung với
/// "Nhập từ Excel" của Bảng giá (luồng đó sửa giá GHIM theo cột `_khoá`).
///
/// 3 bước: hướng dẫn/lấy prompt GPT → chọn file & xem trước → ghi + báo cáo.
class SupplierInvoicePriceImportView extends StatefulWidget {
  const SupplierInvoicePriceImportView({super.key});

  @override
  State<SupplierInvoicePriceImportView> createState() =>
      _SupplierInvoicePriceImportViewState();
}

class _SupplierInvoicePriceImportViewState
    extends State<SupplierInvoicePriceImportView> {
  bool _busy = false;
  String _fileName = '';
  CatalogImportPreview? _preview;
  CatalogImportResult? _result;
  CatalogExistingPolicy _policy = CatalogExistingPolicy.update;

  Future<void> _copyPrompt() async {
    await Clipboard.setData(
      const ClipboardData(text: SupplierInvoicePriceBookService.gptPrompt),
    );
    if (!mounted) return;
    _snack('Đã copy câu lệnh. Mở ChatGPT/Gemini, dán vào rồi đính kèm ảnh '
        'hoá đơn.');
  }

  Future<void> _downloadTemplate() async {
    setState(() => _busy = true);
    try {
      await SupplierInvoicePriceBookService.exportTemplate(context);
    } catch (e) {
      if (mounted) _snack('Không tạo được file mẫu: $e', err: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndPreview() async {
    const xlsx = XTypeGroup(label: 'Excel', extensions: ['xlsx']);
    final file = await openFile(acceptedTypeGroups: [xlsx]);
    if (file == null || !mounted) return;

    setState(() {
      _busy = true;
      _result = null;
      _preview = null;
      _fileName = file.name;
    });

    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Không đọc được file: $e', err: true);
      return;
    }

    try {
      final p = await SupplierInvoicePriceBookService.preview(bytes);
      if (!mounted) return;
      setState(() {
        _preview = p;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Lỗi đọc file: $e', err: true);
    }
  }

  Future<void> _commit() async {
    final p = _preview;
    if (p == null || p.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận nhập'),
        content: Text(
          'Sẽ tạo mới ${p.newItems.length} mặt hàng và '
          '${_policy == CatalogExistingPolicy.update ? 'cập nhật' : 'BỎ QUA'} '
          '${p.updatedItems.length} mặt hàng đã có.\n\n'
          'Thao tác này không đụng tồn kho và không đổi giá vốn của các đơn '
          'hàng đã tạo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Nhập'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final r = await SupplierInvoicePriceBookService.commit(
      p,
      policy: _policy,
      fileName: _fileName,
    );
    if (!mounted) return;
    setState(() {
      _result = r;
      _preview = null;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar.build(title: 'Nhập bảng giá từ hoá đơn NCC'),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
            children: [
              if (_result != null)
                _resultCard(_result!)
              else if (_preview != null)
                _previewCard(_preview!)
              else
                ..._introCards(),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x44000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: _bottomButton(),
        ),
      ),
    );
  }

  Widget _bottomButton() {
    if (_result != null) {
      return FilledButton.icon(
        onPressed: _busy ? null : () => Navigator.of(context).pop(true),
        icon: const Icon(Icons.check),
        label: const Text('Xong'),
      );
    }
    final p = _preview;
    if (p != null) {
      final canCommit = !p.isEmpty &&
          !(p.newItems.isEmpty &&
              _policy == CatalogExistingPolicy.skip);
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : _pickAndPreview,
              child: const Text('Chọn file khác'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: (_busy || !canCommit) ? null : _commit,
              icon: const Icon(Icons.save_alt),
              label: Text('Nhập ${p.totalItems} mặt hàng'),
            ),
          ),
        ],
      );
    }
    return FilledButton.icon(
      onPressed: _busy ? null : _pickAndPreview,
      icon: const Icon(Icons.upload_file),
      label: const Text('Chọn file Excel để nhập'),
    );
  }

  // ── Bước 1: hướng dẫn ────────────────────────────────────────────────────
  List<Widget> _introCards() => [
        _card(
          icon: Icons.auto_awesome,
          color: Colors.indigo,
          title: 'Bước 1 — Nhờ AI đọc ảnh hoá đơn',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mở ChatGPT (hoặc Gemini/Claude), dán câu lệnh dưới đây rồi '
                'đính kèm TẤT CẢ ảnh hoá đơn nhà cung cấp. AI sẽ trả về 1 file '
                'Excel duy nhất.',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Text(
                  SupplierInvoicePriceBookService.gptPrompt,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, height: 1.35),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _copyPrompt,
                      icon: const Icon(Icons.copy_all, size: 18),
                      label: const Text('Copy câu lệnh'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showFullPrompt,
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Xem đầy đủ'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _card(
          icon: Icons.fact_check_outlined,
          color: Colors.teal,
          title: 'Bước 2 — Kiểm tra file trước khi nhập',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mở file AI trả về và soát 3 việc:',
                style: TextStyle(fontSize: 12.5),
              ),
              SizedBox(height: 6),
              _Bullet('Sheet "Lỗi cần kiểm tra" — sửa lại các dòng AI đọc '
                  'không chắc (nhất là dòng nhiều model tương thích).'),
              _Bullet('Cột "Giá vốn" — đúng giá nhập 1 đơn vị, không có "đ".'),
              _Bullet('Cột "Giá thu khách" ở sheet "Tổng hợp giá vốn" — '
                  'tự điền giá báo khách. Để trống cũng được, app sẽ hiện '
                  '"Chưa thiết lập giá thu khách".'),
            ],
          ),
        ),
        _card(
          icon: Icons.download_outlined,
          color: Colors.orange,
          title: 'Chưa có file? Tải file mẫu',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'File mẫu có đủ 4 sheet đúng chuẩn + dữ liệu ví dụ để bạn '
                'đối chiếu hoặc tự gõ tay.',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _downloadTemplate,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('Tải file Excel mẫu'),
              ),
            ],
          ),
        ),
      ];

  Future<void> _showFullPrompt() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Câu lệnh cho AI', style: TextStyle(fontSize: 16)),
        content: const SingleChildScrollView(
          child: SelectableText(
            SupplierInvoicePriceBookService.gptPrompt,
            style: TextStyle(fontSize: 11.5, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _copyPrompt();
            },
            icon: const Icon(Icons.copy_all, size: 18),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  // ── Bước 2: xem trước ────────────────────────────────────────────────────
  Widget _previewCard(CatalogImportPreview p) {
    if (p.isFatal) {
      return _card(
        icon: Icons.error_outline,
        color: Colors.red,
        title: 'Không đọc được file',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in p.errors.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $e', style: const TextStyle(fontSize: 12)),
              ),
            const SizedBox(height: 6),
            const Text(
              'Hãy tải file mẫu và dùng đúng tên sheet/tên cột.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          icon: Icons.summarize_outlined,
          color: Colors.indigo,
          title: 'Xem trước — $_fileName',
          child: Column(
            children: [
              _stat('Dòng hợp lệ', p.validRows, Colors.green.shade700),
              _stat('Mặt hàng MỚI', p.newItems.length, Colors.blue.shade700),
              _stat('Mặt hàng sẽ CẬP NHẬT', p.updatedItems.length,
                  Colors.orange.shade800),
              _stat('Dòng trùng (đã nhập lần trước)', p.duplicateRows,
                  Colors.grey.shade600),
              _stat('Dòng thiếu tên', p.missingNameRows, Colors.red.shade700),
              _stat('Dòng thiếu giá vốn', p.missingCostRows,
                  Colors.red.shade700),
              _stat('Dòng số lượng không hợp lệ', p.invalidQtyRows,
                  Colors.orange.shade800),
              _stat('Mặt hàng CHƯA có giá thu khách',
                  p.emptyCustomerPriceItems, Colors.grey.shade700),
              _stat('Mặt hàng CẦN KIỂM TRA', p.needsReviewItems,
                  Colors.deepOrange.shade700),
            ],
          ),
        ),
        if (p.updatedItems.isNotEmpty)
          _card(
            icon: Icons.rule,
            color: Colors.orange,
            title: 'Mặt hàng đã có trong bảng giá',
            child: Column(
              children: [
                _policyTile(
                  CatalogExistingPolicy.update,
                  'Cập nhật',
                  'Gộp thêm lịch sử giá từ hoá đơn mới, tính lại giá vốn '
                      'gần nhất / bình quân.',
                ),
                _policyTile(
                  CatalogExistingPolicy.skip,
                  'Bỏ qua',
                  'Giữ nguyên bản ghi cũ, chỉ tạo mặt hàng mới.',
                ),
              ],
            ),
          ),
        if (p.newItems.isNotEmpty)
          _itemsCard('Sẽ tạo mới (${p.newItems.length})', p.newItems, null),
        if (p.updatedItems.isNotEmpty)
          _itemsCard(
            'Sẽ cập nhật (${p.updatedItems.length})',
            p.updatedItems,
            p.existing,
          ),
        if (p.warnings.isNotEmpty)
          _card(
            icon: Icons.info_outline,
            color: Colors.blue,
            title: 'Lưu ý',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final w in p.warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $w', style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
        if (p.errors.isNotEmpty)
          _card(
            icon: Icons.warning_amber_rounded,
            color: Colors.red,
            title: 'Dòng có vấn đề (${p.errors.length})',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in p.errors.take(20))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $e', style: const TextStyle(fontSize: 11.5)),
                  ),
                if (p.errors.length > 20)
                  Text('… và ${p.errors.length - 20} dòng khác',
                      style: TextStyle(
                          fontSize: 11.5, color: Colors.grey.shade600)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _policyTile(
    CatalogExistingPolicy value,
    String title,
    String subtitle,
  ) {
    final selected = _policy == value;
    return InkWell(
      onTap: () => setState(() => _policy = value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 19,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade500,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 11.5, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemsCard(
    String title,
    List<PriceCatalogItem> items,
    Map<String, PriceCatalogItem>? existing,
  ) {
    return _card(
      icon: Icons.list_alt_rounded,
      color: Colors.blueGrey,
      title: title,
      child: Column(
        children: [
          for (final it in items.take(25)) _itemRow(it, existing?[it.importKey]),
          if (items.length > 25)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('… và ${items.length - 25} mặt hàng khác',
                  style:
                      TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            ),
        ],
      ),
    );
  }

  Widget _itemRow(PriceCatalogItem it, PriceCatalogItem? old) {
    final costChanged = old != null && old.lastCost != it.lastCost;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  it.itemName,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (it.needsReview)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('KIỂM TRA',
                      style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.deepOrange.shade800)),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              'Vốn ${MoneyUtils.formatCurrency(it.lastCost)}đ'
                  '${costChanged ? ' (cũ ${MoneyUtils.formatCurrency(old.lastCost)}đ)' : ''}',
              if (it.avgCost > 0 && it.avgCost != it.lastCost)
                'BQ ${MoneyUtils.formatCurrency(it.avgCost)}đ',
              it.hasCustomerPrice
                  ? 'Thu ${MoneyUtils.formatCurrency(it.customerPrice)}đ'
                  : 'Chưa có giá thu khách',
            ].join('  ·  '),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          if (it.needsReview && it.reviewNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                it.reviewNote,
                style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.deepOrange.shade700,
                    fontStyle: FontStyle.italic),
              ),
            ),
          const Divider(height: 10),
        ],
      ),
    );
  }

  // ── Bước 3: báo cáo ──────────────────────────────────────────────────────
  Widget _resultCard(CatalogImportResult r) {
    final ok = r.failed == 0;
    return Column(
      children: [
        _card(
          icon: ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
          color: ok ? Colors.green : Colors.orange,
          title: ok ? 'Nhập xong' : 'Nhập xong (có lỗi)',
          child: Column(
            children: [
              _stat('Tạo mới', r.created, Colors.blue.shade700),
              _stat('Cập nhật', r.updated, Colors.orange.shade800),
              _stat('Bỏ qua', r.skipped, Colors.grey.shade600),
              _stat('Lỗi', r.failed,
                  r.failed > 0 ? Colors.red.shade700 : Colors.grey.shade600),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Dữ liệu đã lưu vào Bảng giá (tab Sửa chữa) và sẽ tự đồng '
                  'bộ sang các máy khác trong shop.',
                  style:
                      TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
        if (r.errors.isNotEmpty)
          _card(
            icon: Icons.error_outline,
            color: Colors.red,
            title: 'Lỗi',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in r.errors.take(20))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $e', style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Vụn UI ───────────────────────────────────────────────────────────────
  Widget _card({
    required IconData icon,
    required MaterialColor color,
    required String title,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: color.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12.5)),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: value > 0 ? color : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String m, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: err ? Colors.red : Colors.green,
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(fontSize: 12.5)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }
}

/// Mở màn "Nhập bảng giá từ hoá đơn NCC". Trả về true nếu đã nhập xong (để
/// màn gọi tự tải lại dữ liệu).
Future<bool> openSupplierInvoicePriceImport(BuildContext context) async {
  if (!await PriceCatalogService.canImport()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bạn không có quyền nhập bảng giá từ hoá đơn (cần quyền xem giá vốn).',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
    return false;
  }
  if (!context.mounted) return false;
  final r = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => const SupplierInvoicePriceImportView(),
    ),
  );
  return r == true;
}
