import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/price_catalog_models.dart';
import '../services/price_catalog_service.dart';
import '../services/supplier_invoice_price_book_service.dart';
import '../utils/file_picker_types.dart';
import '../utils/money_utils.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/responsive_wrapper.dart';

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
    // Dùng FilePickerTypes.excel — KHÔNG tự khai XTypeGroup tại chỗ: thiếu
    // `uniformTypeIdentifiers` là iOS ném ArgumentError, bấm nút không lên gì.
    XFile? picked;
    try {
      picked = await openFile(acceptedTypeGroups: [FilePickerTypes.excel]);
    } catch (e) {
      if (mounted) _snack('Không mở được trình chọn file: $e', err: true);
      return;
    }
    if (picked == null || !mounted) return;
    final file = picked;

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

  /// Bề ngang tối đa của nội dung. Đây là màn hướng dẫn đọc-theo-thứ-tự nên
  /// giữ MỘT cột hẹp dễ đọc; trên web/máy tính nếu để giãn hết màn thì mỗi
  /// dòng dài cả gang tay, đọc rất mỏi và các bước mất cảm giác nối tiếp nhau.
  static const double _maxContentWidth = 760;

  @override
  Widget build(BuildContext context) {
    // Xoay ngang trên điện thoại: chiều cao còn rất ít, nên bớt khoảng đệm
    // dọc để phần đọc được không bị bóp lại quá nhỏ.
    final isShort = MediaQuery.sizeOf(context).height < 480;
    return Scaffold(
      appBar: CustomAppBar.build(title: 'Nhập bảng giá từ hoá đơn NCC'),
      body: Stack(
        children: [
          ResponsiveBody(
            maxWidth: _maxContentWidth,
            child: ListView(
              padding: EdgeInsets.fromLTRB(14, isShort ? 6 : 12, 14, 90),
              children: [
                if (_result != null)
                  _resultCard(_result!)
                else if (_preview != null)
                  _previewCard(_preview!)
                else
                  ..._introCards(),
              ],
            ),
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
      // KHÔNG dùng ResponsiveBody ở đây: nó bọc `Center`, mà `Center` giãn hết
      // chiều cao khả dụng — đặt trong `bottomNavigationBar` (chỗ đáng lẽ chỉ
      // cao bằng nội dung) làm thanh dưới chiếm trọn màn hình, ép thân màn còn
      // 0 chiều cao ⇒ toàn bộ phần hướng dẫn biến mất, chỉ còn cái nút nằm
      // giữa màn trắng. `heightFactor: 1` bắt nó ôm sát chiều cao của nút.
      bottomNavigationBar: SafeArea(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                isShort ? 4 : 6,
                14,
                isShort ? 6 : 10,
              ),
              child: _bottomButton(),
            ),
          ),
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
        _flowCard(),
        _card(
          icon: Icons.looks_one_outlined,
          color: Colors.indigo,
          title: 'Chụp ảnh hoá đơn',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chụp rõ từng tờ hoá đơn nhà cung cấp — nhìn thấy được tên '
                'hàng, số lượng và đơn giá. Bao nhiêu tờ cũng được, gửi chung '
                'một lần.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
              SizedBox(height: 8),
              _Tip('Chỗ nào ảnh mờ, AI sẽ đánh dấu để bạn kiểm tra lại chứ '
                  'không tự đoán bừa.'),
            ],
          ),
        ),
        _card(
          icon: Icons.looks_two_outlined,
          color: Colors.deepPurple,
          title: 'Đưa cho ChatGPT kèm câu lệnh',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mở ChatGPT (hoặc Gemini, Claude) → bấm nút bên dưới để chép '
                'câu lệnh → dán vào ô chat → đính kèm tất cả ảnh hoá đơn → gửi.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
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
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, height: 1.35),
                ),
              ),
              const SizedBox(height: 10),
              _actionRow([
                FilledButton.icon(
                  onPressed: _copyPrompt,
                  icon: const Icon(Icons.copy_all, size: 18),
                  label: const Text('Chép câu lệnh'),
                ),
                OutlinedButton.icon(
                  onPressed: _showFullPrompt,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Xem đầy đủ'),
                ),
              ]),
              const SizedBox(height: 8),
              const _Tip('AI sẽ trả về MỘT file Excel (.xlsx) để tải về. Nếu '
                  'nó chỉ trả bảng chữ, bảo nó "xuất thành file .xlsx cho tôi '
                  'tải về".'),
            ],
          ),
        ),
        _card(
          icon: Icons.looks_3_outlined,
          color: Colors.teal,
          title: 'Mở file ra kiểm tra',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'File có 4 trang (sheet). Bạn chỉ cần quan tâm 2 trang:',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 8),
              _sheetRow(
                'Lỗi cần kiểm tra',
                'Những dòng AI đọc không chắc. Soát lại và sửa cho đúng.',
                Colors.orange,
                Icons.warning_amber_rounded,
              ),
              _sheetRow(
                'Tổng hợp giá vốn',
                'Điền cột "Giá thu khách" — giá bạn báo cho khách.',
                Colors.green,
                Icons.edit_outlined,
              ),
              const SizedBox(height: 4),
              const _Tip('Để trống "Giá thu khách" vẫn nhập được. App sẽ hiện '
                  '"Chưa thiết lập giá thu khách", KHÔNG bao giờ lấy giá vốn '
                  'báo cho khách.'),
              const SizedBox(height: 12),
              _fileShapeTable(),
            ],
          ),
        ),
        _card(
          icon: Icons.looks_4_outlined,
          color: Colors.blue,
          title: 'Nhập vào app',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bấm "Chọn file Excel để nhập" ở dưới cùng. App cho bạn xem '
                'trước có bao nhiêu mặt hàng mới, bao nhiêu mặt hàng được cập '
                'nhật — xem xong rồi mới ghi.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
              SizedBox(height: 8),
              _Tip('Lỡ nhập lại đúng file cũ cũng không sao — app tự nhận ra '
                  'và không ghi trùng.'),
            ],
          ),
        ),
        _card(
          icon: Icons.download_outlined,
          color: Colors.blueGrey,
          title: 'Chưa có file? Tải mẫu về xem trước',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'File mẫu có đủ 4 trang đúng chuẩn kèm dữ liệu ví dụ của một '
                'hoá đơn thật — mở ra là hình dung được ngay. Bạn cũng có thể '
                'tự gõ tay theo mẫu này mà không cần AI.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _downloadTemplate,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('Tải file Excel mẫu'),
              ),
            ],
          ),
        ),
      ];

  /// Sơ đồ 4 bước — để người dùng mới thấy toàn cảnh trước khi đọc chi tiết.
  /// Dùng [Wrap] nên tự xuống dòng ở màn hẹp thay vì tràn ngang.
  Widget _flowCard() {
    const steps = <(IconData, String)>[
      (Icons.photo_camera_outlined, 'Chụp ảnh\nhoá đơn'),
      (Icons.smart_toy_outlined, 'ChatGPT\nđọc ảnh'),
      (Icons.table_chart_outlined, 'Một file\nExcel'),
      (Icons.price_check, 'Bảng giá\ntrong app'),
    ];
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.indigo.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.indigo.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Biến ảnh hoá đơn thành bảng giá tra cứu được',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.indigo.shade900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Không phải gõ tay từng dòng. Làm một lần, cả cửa hàng tra chung.',
              style: TextStyle(fontSize: 11.5, color: Colors.indigo.shade700),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 10,
              children: [
                // Mũi tên đi KÈM mục phía sau nó trong cùng một phần tử Wrap.
                // Nếu để mũi tên là phần tử riêng, khi xuống dòng nó bị bỏ lại
                // cuối dòng trên và trỏ vào khoảng trống.
                for (var i = 0; i < steps.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: Colors.indigo.shade300,
                          ),
                        ),
                      SizedBox(
                        width: 72,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white,
                              child: Icon(
                                steps[i].$1,
                                size: 18,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              steps[i].$2,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.25,
                                color: Colors.indigo.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Một dòng mô tả trang (sheet) cần để ý trong file Excel.
  Widget _sheetRow(
    String name,
    String desc,
    MaterialColor color,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trang "$name"',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color.shade800,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bảng minh hoạ file trông ra sao — nhìn là biết phải điền vào đâu, đỡ
  /// phải tưởng tượng từ chữ. Cuộn ngang trong khung riêng để không đẩy tràn
  /// cả trang trên màn hẹp.
  Widget _fileShapeTable() {
    Widget cell(String t, {bool head = false, bool highlight = false}) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          color: head
              ? Colors.grey.shade200
              : (highlight ? Colors.green.shade50 : Colors.transparent),
          child: Text(
            t,
            style: TextStyle(
              fontSize: 9.5,
              height: 1.2,
              fontWeight: head ? FontWeight.w700 : FontWeight.w400,
              color: highlight ? Colors.green.shade900 : Colors.grey.shade800,
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'File trông như thế này (rút gọn):',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  children: [
                    cell('Tên mặt hàng', head: true),
                    cell('Số lượng', head: true),
                    cell('Giá vốn', head: true),
                    cell('Giá thu khách', head: true),
                  ],
                ),
                TableRow(
                  children: [
                    cell('Pin iPhone 11 Pro Max'),
                    cell('3'),
                    cell('310000'),
                    cell('← bạn điền', highlight: true),
                  ],
                ),
                TableRow(
                  children: [
                    cell('Màn hình iPhone 13 OLED'),
                    cell('1'),
                    cell('900000'),
                    cell('← bạn điền', highlight: true),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'AI điền sẵn phần giá vốn. Bạn chỉ điền cột cuối (để trống cũng được).',
          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  /// Hàng nút tự xuống dòng khi quá hẹp — tránh tràn ở màn nhỏ / cửa sổ chia đôi.
  Widget _actionRow(List<Widget> buttons) {
    return LayoutBuilder(
      builder: (_, c) {
        if (c.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                buttons[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: buttons[i]),
            ],
          ],
        );
      },
    );
  }

  Future<void> _showFullPrompt() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Câu lệnh cho AI', style: TextStyle(fontSize: 16)),
        // Câu lệnh rất dài: khi xoay ngang chiều cao còn rất ít nên phải chốt
        // trần chiều cao, nếu không AlertDialog tự giãn quá màn và tràn.
        content: SizedBox(
          width: responsiveDialogWidth(ctx, maxWidth: 640),
          height: MediaQuery.sizeOf(ctx).height * 0.6,
          child: const SingleChildScrollView(
            child: SelectableText(
              SupplierInvoicePriceBookService.gptPrompt,
              style: TextStyle(fontSize: 11.5, height: 1.4),
            ),
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
          // Màn rộng (web/máy tính bảng/xoay ngang) xếp 2 cột cho đỡ phải cuộn;
          // màn hẹp giữ 1 cột để nhãn dài không bị cắt.
          child: ResponsiveGrid(
            minChildWidth: 260,
            maxColumns: 2,
            spacing: 14,
            runSpacing: 0,
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

/// Dòng mẹo/trấn an dưới mỗi bước hướng dẫn — nền nhạt + icon bóng đèn để mắt
/// phân biệt ngay với phần việc phải làm ở trên.
class _Tip extends StatelessWidget {
  final String text;
  const _Tip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 14,
            color: Colors.amber.shade900,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: Colors.brown.shade800,
              ),
            ),
          ),
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
