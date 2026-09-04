import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models/price_book_models.dart';
import '../models/price_catalog_models.dart';
import '../models/product_model.dart';
import '../services/price_book_service.dart';
import '../services/price_catalog_service.dart';
import '../utils/file_picker_types.dart';
import '../utils/money_utils.dart';
import '../utils/vietnamese_utils.dart';
import '../widgets/currency_text_field.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/responsive_wrapper.dart';
import 'similar_repair_history_view.dart';
import 'supplier_invoice_price_import_view.dart';

/// "Bảng giá" — giá đề xuất (trung vị lịch sử) cho sửa chữa & bán hàng,
/// cho phép chủ shop GHIM giá niêm yết. Form tạo đơn đọc từ đây.
class PriceBookView extends StatefulWidget {
  /// 0 = Sửa chữa, 1 = Bán hàng.
  final int initialTab;
  const PriceBookView({super.key, this.initialTab = 0});

  @override
  State<PriceBookView> createState() => _PriceBookViewState();
}

class _PriceBookViewState extends State<PriceBookView>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _searchCtrl = TextEditingController();
  String _q = '';

  bool _loading = true;
  List<PriceBookRow> _repair = const [];
  List<PriceBookRow> _parts = const [];
  List<PriceBookRow> _catalog = const [];
  List<PriceBookRow> _sale = const [];
  int _seasonPct = 0;

  /// Nhân viên KHÔNG có quyền xem giá vốn ⇒ ẩn toàn bộ ô Vốn/Lãi và mọi
  /// thông tin nhập hàng. Dữ liệu giá vốn cũng đã bị service loại bỏ trước
  /// khi tới đây, cờ này chỉ để giao diện không chừa ô trống vô nghĩa.
  bool _canViewCost = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    )..addListener(_onTab);
    _load();
  }

  Future<void> _editSeason() async {
    final ctrl = TextEditingController(text: _seasonPct.toString());
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hệ số giá mùa vụ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cộng/trừ % vào GIÁ ĐỀ XUẤT (không đụng giá đã ghim).\n'
              'VD: 10 = +10% dịp Tết; -5 = giảm 5%.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: '% điều chỉnh',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(ctrl.text.trim()) ?? 0),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (v == null || !mounted) return;
    await PriceBookService.setSeasonPct(v);
    _snack(v == 0 ? 'Đã tắt hệ số mùa vụ.' : 'Hệ số mùa vụ: ${v > 0 ? '+' : ''}$v%');
    await _load();
  }

  Future<void> _export() async {
    await PriceBookService.exportToExcel(context);
  }

  /// Xem các đơn sửa / SP đã tạo ra dòng bảng giá.
  Future<void> _openSources(PriceBookRow r) async {
    if (r.scope == 'repair') {
      final list =
          await PriceBookService.repairSourcesFor(r.src1, r.src2);
      if (!mounted) return;
      if (list.isEmpty) {
        _snack('Không tìm thấy đơn tương ứng.');
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              SimilarRepairHistoryView(repairs: list, showCost: true),
        ),
      );
      return;
    }
    // sale
    final products = await PriceBookService.saleSourcesFor(
      r.src1,
      r.src2,
      r.src3,
      r.src4,
    );
    if (!mounted) return;
    if (products.isEmpty) {
      _snack('Không tìm thấy sản phẩm tương ứng.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, sc) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '${r.title} — ${products.length} SP',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: sc,
                itemCount: products.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _productTile(products[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productTile(Product p) {
    return ListTile(
      dense: true,
      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        'Bán ${MoneyUtils.formatCurrency(p.price)}đ  ·  Vốn '
        '${MoneyUtils.formatCurrency(p.cost)}đ  ·  Tồn ${p.quantity}'
        '${p.imei != null && p.imei!.isNotEmpty ? '  ·  ${p.imei}' : ''}',
        style: const TextStyle(fontSize: 11.5),
      ),
    );
  }

  Future<void> _import() async {
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
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      _snack('Không đọc được file: $e', err: true);
      return;
    }
    if (!mounted) return;
    setState(() => _loading = true);
    final r = await PriceBookService.importFromExcel(bytes);
    if (!mounted) return;
    _snack(
      'Nhập xong: ghim ${r.pinned}, bỏ ghim ${r.cleared}'
      '${r.errors.isEmpty ? '' : ', ${r.errors.length} lỗi'}.',
      err: r.errors.isNotEmpty,
    );
    await _load();
  }

  /// Luồng RIÊNG cho file Excel 4 sheet do AI đọc ảnh hoá đơn NCC tạo ra —
  /// KHÔNG dùng chung với [_import] (luồng đó sửa giá GHIM theo cột _khoá của
  /// chính file Bảng giá xuất ra).
  Future<void> _importFromSupplierInvoice() async {
    final done = await openSupplierInvoicePriceImport(context);
    if (done && mounted) await _load();
  }

  /// Màu theo mức độ tin cậy — dùng thống nhất cho badge + (khi rất thấp)
  /// làm nhạt con số giá, để mắt phân biệt được dòng đáng tin và dòng chỉ
  /// dựa trên 1 lần bán ngẫu nhiên.
  Color _confColor(String label) {
    switch (label) {
      case 'Tốt':
        return Colors.green.shade700;
      case 'Khá':
        return Colors.blue.shade700;
      case 'Thấp':
        return Colors.orange.shade800;
      default: // 'Dữ liệu quá ít' / 'Không có dữ liệu'
        return Colors.grey.shade600;
    }
  }

  void _onTab() => setState(() {});

  @override
  void dispose() {
    _tab.removeListener(_onTab);
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final canCost = await PriceCatalogService.canViewCost();
    final r = await PriceBookService.buildRepairRows();
    final parts = await PriceBookService.buildPartRows();
    final catalog = await PriceCatalogService.buildRows(includeCost: canCost);
    final s = await PriceBookService.buildSaleRows();
    final pct = await PriceBookService.seasonPct();
    if (!mounted) return;
    setState(() {
      _canViewCost = canCost;
      _repair = r;
      _parts = parts;
      _catalog = catalog;
      _sale = s;
      _seasonPct = pct;
      _loading = false;
    });
  }

  List<PriceBookRow> _filtered(List<PriceBookRow> src) {
    final nq = VietnameseUtils.normalize(_q.trim());
    if (nq.isEmpty) return src;
    return src
        .where((r) => VietnameseUtils.normalize('${r.title} ${r.note}')
            .contains(nq))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isSale = _tab.index == 1;
    return Scaffold(
      appBar: CustomAppBar.build(
        title: 'Bảng giá',
        actions: [
          if (isSale)
            IconButton(
              tooltip: 'Áp giá cho SP chưa có giá',
              icon: const Icon(Icons.price_change_outlined, color: Colors.white),
              onPressed: _bulkApply,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) {
              switch (v) {
                case 'season':
                  _editSeason();
                case 'export':
                  _export();
                case 'import':
                  _import();
                case 'import_invoice':
                  _importFromSupplierInvoice();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'season', child: Text('Hệ số giá mùa vụ')),
              PopupMenuItem(value: 'export', child: Text('Xuất Excel')),
              PopupMenuItem(value: 'import', child: Text('Nhập từ Excel')),
              PopupMenuItem(
                value: 'import_invoice',
                child: Text('Nhập bảng giá từ hoá đơn NCC'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Sửa chữa'),
            Tab(text: 'Bán hàng'),
          ],
        ),
      ),
      // Web/máy tính bảng: chốt bề ngang để thẻ giá không bị kéo dài cả màn
      // (giá nằm mãi bên phải, tên mãi bên trái, mắt phải quét rất xa).
      body: ResponsiveBody(
        maxWidth: 1100,
        child: Column(
        children: [
          if (_seasonPct != 0)
            Material(
              color: Colors.amber.shade100,
              child: InkWell(
                onTap: _editSeason,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Đang áp hệ số mùa vụ: ${_seasonPct > 0 ? '+' : ''}'
                          '$_seasonPct% (chỉ vào giá đề xuất) — chạm để sửa',
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.brown.shade800),
                        ),
                      ),
                      Icon(Icons.edit_outlined,
                          size: 14, color: Colors.brown.shade800),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Tìm model, lỗi… (vd "iphone 12 ép kính")',
                filled: true,
                fillColor: Theme.of(context).cardColor,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tab,
                    children: [
                      _list(
                        _filtered([..._repair, ..._parts, ..._catalog]),
                        'Chưa có đơn sửa nào đã hoàn thành để tính giá.',
                      ),
                      _list(_filtered(_sale), 'Chưa có sản phẩm nào để tính giá.'),
                    ],
                  ),
          ),
        ],
        ),
      ),
      floatingActionButton: isSale
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddMenu,
              icon: const Icon(Icons.add),
              label: const Text('Thêm mục'),
            ),
    );
  }

  /// Cho phép chủ shop tự dựng bảng giá TRƯỚC khi có đơn/hoá đơn thật —
  /// "Sửa chữa" (model + lỗi) hoặc "Phụ tùng tham khảo" (tên + giá vốn),
  /// cùng cơ chế ghim "mồ côi" đã dùng cho luồng nhập hoá đơn NCC.
  Future<void> _showAddMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.build_outlined),
              title: const Text('Thêm mục sửa chữa mới'),
              subtitle: const Text(
                  'Model + lỗi chưa từng có đơn — đặt giá trước để báo khách.'),
              onTap: () => Navigator.pop(ctx, 'repair'),
            ),
            ListTile(
              leading: const Icon(Icons.memory_outlined),
              title: const Text('Thêm phụ tùng tham khảo mới'),
              subtitle: const Text(
                  'Tên phụ tùng + giá vốn — chưa cần có trong Kho phụ tùng.'),
              onTap: () => Navigator.pop(ctx, 'part'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'repair') {
      await _addRepairEntry();
    } else {
      await _addPartEntry();
    }
  }

  Future<void> _addRepairEntry() async {
    final modelCtrl = TextEditingController();
    final issueCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    String? err;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Thêm mục sửa chữa mới'),
          content: SizedBox(
            // Chot be ngang: tren web/may tinh bang dialog mac dinh
            // gian rat rong, o nhap gia nam lot thom giua man.
            width: responsiveDialogWidth(ctx, maxWidth: 520),
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đặt sẵn giá cho 1 model + lỗi CHƯA từng có đơn — nhân '
                  'viên/chủ shop nhìn vào là báo giá được ngay, tránh mỗi '
                  'người báo 1 giá.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Model (vd "iPhone 13", "Oppo A74")',
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: issueCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lỗi / dịch vụ (vd "Thay pin", "Ép kính")',
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 10),
                CurrencyTextField(
                  controller: priceCtrl,
                  label: 'Giá thu khách (niêm yết)',
                ),
                const SizedBox(height: 10),
                CurrencyTextField(
                  controller: costCtrl,
                  label: 'Giá vốn dự kiến (tuỳ chọn)',
                ),
                if (err != null) ...[
                  const SizedBox(height: 8),
                  Text(err!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () {
                final model = modelCtrl.text.trim();
                final issue = issueCtrl.text.trim();
                final p = MoneyUtils.parseCurrency(priceCtrl.text);
                if (model.isEmpty) {
                  setLocal(() => err = 'Nhập model.');
                  return;
                }
                if (issue.isEmpty) {
                  setLocal(() => err = 'Nhập lỗi/dịch vụ.');
                  return;
                }
                if (p <= 0) {
                  setLocal(() => err = 'Nhập giá thu khách hợp lệ.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      final model = modelCtrl.text.trim();
      final issue = issueCtrl.text.trim();
      final p = MoneyUtils.parseCurrency(priceCtrl.text);
      final c = MoneyUtils.parseCurrency(costCtrl.text);
      await PriceBookService.pin(
        PriceBookService.repairKey(model, issue),
        price: p,
        cost: c > 0 ? c : null,
        displayName: model,
        displayExtra: issue,
      );
      _snack('Đã thêm: $model · $issue');
      await _load();
    }
    modelCtrl.dispose();
    issueCtrl.dispose();
    priceCtrl.dispose();
    costCtrl.dispose();
  }

  Future<void> _addPartEntry() async {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String? err;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Thêm phụ tùng tham khảo mới'),
          content: SizedBox(
            // Chot be ngang: tren web/may tinh bang dialog mac dinh
            // gian rat rong, o nhap gia nam lot thom giua man.
            width: responsiveDialogWidth(ctx, maxWidth: 520),
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chỉ để tham khảo giá vốn/báo giá — không tạo tồn kho, '
                  'không đụng Kho phụ tùng. Đặt tên rõ kèm model để dễ tra '
                  'cứu (vd "Màn hình Oppo A74" thay vì chỉ "Màn hình").',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên phụ tùng (vd "Pin iPhone 13")',
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: brandCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Hãng máy (tuỳ chọn, vd "iPhone")',
                    helperText: 'Để trống thì app tự đoán hãng từ tên.',
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 10),
                CurrencyTextField(
                  controller: costCtrl,
                  label: 'Giá vốn tham khảo',
                ),
                const SizedBox(height: 10),
                CurrencyTextField(
                  controller: priceCtrl,
                  label: 'Giá thu khách (tuỳ chọn)',
                ),
                if (err != null) ...[
                  const SizedBox(height: 8),
                  Text(err!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final c = MoneyUtils.parseCurrency(costCtrl.text);
                final p = MoneyUtils.parseCurrency(priceCtrl.text);
                if (name.isEmpty) {
                  setLocal(() => err = 'Nhập tên phụ tùng.');
                  return;
                }
                if (c <= 0 && p <= 0) {
                  setLocal(() => err = 'Nhập giá vốn hoặc giá thu khách.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      final name = nameCtrl.text.trim();
      final brand = brandCtrl.text.trim();
      final c = MoneyUtils.parseCurrency(costCtrl.text);
      final p = MoneyUtils.parseCurrency(priceCtrl.text);
      await PriceBookService.pin(
        PriceBookService.partKey(name),
        price: p,
        cost: c > 0 ? c : null,
        displayName: name,
        brandHint: brand.isEmpty ? null : brand,
      );
      _snack('Đã thêm: $name');
      await _load();
    }
    nameCtrl.dispose();
    brandCtrl.dispose();
    costCtrl.dispose();
    priceCtrl.dispose();
  }

  Widget _list(List<PriceBookRow> rows, String emptyMsg) {
    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _q.isEmpty ? emptyMsg : 'Không có dòng nào khớp "$_q".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ),
          ],
        ),
      );
    }
    // Group by brand
    final groups = <String, List<PriceBookRow>>{};
    for (final r in rows) {
      groups.putIfAbsent(r.brand, () => []).add(r);
    }
    final brands = groups.keys.toList()..sort();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
        children: [
          for (final b in brands) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
              child: Text(
                '${b.toUpperCase()} (${groups[b]!.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            // Màn rộng xếp 2–3 thẻ mỗi hàng thay vì 1 thẻ kéo dài cả màn.
            // Điện thoại dựng đứng vẫn 1 cột như cũ (minChildWidth > bề ngang).
            ResponsiveGrid(
              minChildWidth: 330,
              maxColumns: 3,
              spacing: 6,
              runSpacing: 0,
              children: [for (final r in groups[b]!) _rowCard(r)],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9.5,
                    color: color,
                    fontWeight: FontWeight.w600)),
            Text(
              '${MoneyUtils.formatCurrency(value)}đ',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Dòng phụ dưới thẻ giá cho mặt hàng đến từ hoá đơn NCC.
  ///
  /// Model/loại linh kiện/SKU hiện cho MỌI vai trò (nhân viên cần để tra
  /// đúng mặt hàng). Giá vốn bình quân, NCC, ngày nhập chỉ hiện cho người có
  /// quyền xem giá vốn — và với người không có quyền thì các trường này đã
  /// rỗng sẵn từ tầng service, đây chỉ là lớp chặn thứ hai.
  Widget _catalogMeta(PriceCatalogItem c) {
    final idParts = [
      if (c.partType.trim().isNotEmpty) c.partType.trim(),
      if (c.model.trim().isNotEmpty) c.model.trim(),
      if (c.sku.trim().isNotEmpty) 'SKU ${c.sku.trim()}',
    ].join(' · ');

    final costParts = !_canViewCost
        ? const <String>[]
        : [
            if (c.avgCost > 0 && c.avgCost != c.lastCost)
              'BQ ${MoneyUtils.formatCurrency(c.avgCost)}đ',
            if (c.minCost > 0 && c.minCost != c.maxCost)
              '${MoneyUtils.formatCurrency(c.minCost)}–${MoneyUtils.formatCurrency(c.maxCost)}đ',
            if (c.supplier.trim().isNotEmpty) c.supplier.trim(),
            if (c.lastInvoiceDate.trim().isNotEmpty)
              'Nhập ${c.lastInvoiceDate.trim()}',
          ];

    if (idParts.isEmpty && costParts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (idParts.isNotEmpty)
            Text(
              idParts,
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (costParts.isNotEmpty)
            Text(
              costParts.join('  ·  '),
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _rowCard(PriceBookRow r) {
    final priceLabel = r.scope == 'sale' ? 'Bán' : 'Thu';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => _openPinSheet(r),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      r.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (r.catalog?.needsReview ?? false)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'KIỂM TRA',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.deepOrange.shade800,
                        ),
                      ),
                    ),
                  if (r.isPinned)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        r.scope == 'catalog' ? 'BẢNG GIÁ NCC' : 'NIÊM YẾT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                    ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 6),
              if (!r.hasPrice)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.price_change_outlined,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          // Dòng danh mục NCC: nói rõ "chưa thiết lập giá thu
                          // khách" — nhân viên tuyệt đối không được lấy giá
                          // vốn báo cho khách thay thế.
                          r.scope == 'catalog'
                              ? (_canViewCost
                                  ? '${CatalogLookup.noPriceMessage} — chạm để đặt giá'
                                  : CatalogLookup.noPriceMessage)
                              : 'Chưa có giá ${priceLabel.toLowerCase()} — chạm để đặt giá',
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.grey.shade700),
                        ),
                      ),
                      if (_canViewCost && r.effectiveCost > 0)
                        Text(
                          'Vốn ${MoneyUtils.formatCurrency(r.effectiveCost)}đ',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                    ],
                  ),
                )
              else ...[
                Row(
                  children: [
                    _metric(priceLabel, r.effectivePrice,
                        r.isPinned ? Colors.indigo.shade700 : Colors.black87),
                    // Vốn + Lãi chỉ dành cho chủ shop/quản lý.
                    if (_canViewCost) ...[
                      const SizedBox(width: 8),
                      _metric('Vốn', r.effectiveCost, Colors.orange.shade800),
                      const SizedBox(width: 8),
                      _metric(
                        'Lãi',
                        r.effectiveProfit,
                        r.effectiveProfit >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (r.scope != 'catalog')
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${r.sampleCount} mẫu'
                          '${r.minPrice > 0 && r.minPrice != r.maxPrice ? ' · ${MoneyUtils.formatCurrency(r.minPrice)}–${MoneyUtils.formatCurrency(r.maxPrice)}đ' : ''}',
                          style: TextStyle(
                              fontSize: 10.5, color: Colors.grey.shade600),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _confColor(r.confidenceLabel)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          r.confidenceLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: _confColor(r.confidenceLabel),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
              if (r.catalog != null) _catalogMeta(r.catalog!),
            ],
          ),
        ),
      ),
    );
  }

  /// Đặt/sửa GIÁ THU KHÁCH cho 1 mặt hàng của danh mục hoá đơn NCC.
  ///
  /// Ghi vào SQLite + đồng bộ Firestore ([PriceCatalogService]), KHÔNG dùng
  /// cơ chế ghim SharedPreferences (chỉ nằm trên 1 máy).
  Future<void> _openCatalogSheet(PriceBookRow r) async {
    final c = r.catalog;
    if (c == null) return;

    // Nhân viên chỉ được XEM giá thu khách, không được sửa bảng giá.
    if (!_canViewCost) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(c.itemName, style: const TextStyle(fontSize: 15)),
          content: Text(
            c.hasCustomerPrice
                ? 'Giá thu khách: '
                    '${MoneyUtils.formatCurrency(c.customerPrice)}đ'
                : '${CatalogLookup.noPriceMessage}.\n\n'
                    'Hãy hỏi chủ shop/quản lý trước khi báo giá cho khách.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
      return;
    }

    final priceCtrl = TextEditingController(
      text: c.hasCustomerPrice
          ? CurrencyTextField.formatDisplay(c.customerPrice)
          : '',
    );
    final noteCtrl = TextEditingController(text: c.note);

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          c.itemName,
          style: const TextStyle(fontSize: 15),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: SizedBox(
          // Chot be ngang: tren web/may tinh bang dialog mac dinh
          // gian rat rong, o nhap gia nam lot thom giua man.
          width: responsiveDialogWidth(ctx, maxWidth: 520),
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Giá vốn gần nhất: '
                      '${MoneyUtils.formatCurrency(c.lastCost)}đ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    if (c.avgCost > 0)
                      Text(
                        'Bình quân: ${MoneyUtils.formatCurrency(c.avgCost)}đ'
                        '${c.minCost != c.maxCost ? '  ·  Thấp nhất ${MoneyUtils.formatCurrency(c.minCost)}đ  ·  Cao nhất ${MoneyUtils.formatCurrency(c.maxCost)}đ' : ''}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.orange.shade900),
                      ),
                    if (c.supplier.trim().isNotEmpty ||
                        c.lastInvoiceDate.trim().isNotEmpty)
                      Text(
                        [
                          if (c.supplier.trim().isNotEmpty) c.supplier.trim(),
                          if (c.lastInvoiceNo.trim().isNotEmpty)
                            'HĐ ${c.lastInvoiceNo.trim()}',
                          if (c.lastInvoiceDate.trim().isNotEmpty)
                            c.lastInvoiceDate.trim(),
                        ].join('  ·  '),
                        style: TextStyle(
                            fontSize: 11, color: Colors.orange.shade900),
                      ),
                    Text(
                      '${c.costHistory.length} lần nhập đã ghi nhận',
                      style: TextStyle(
                          fontSize: 10.5, color: Colors.orange.shade800),
                    ),
                  ],
                ),
              ),
              if (c.needsReview && c.reviewNote.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '⚠ ${c.reviewNote.trim()}',
                  style: TextStyle(
                      fontSize: 11.5, color: Colors.deepOrange.shade800),
                ),
              ],
              const SizedBox(height: 12),
              CurrencyTextField(
                controller: priceCtrl,
                label: 'Giá thu khách',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (tuỳ chọn)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Để trống = chưa thiết lập giá. Nhân viên sẽ thấy "'
                '${CatalogLookup.noPriceMessage}" thay vì giá vốn.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Text('Xoá khỏi bảng giá',
                style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (mounted && action == 'save') {
      final p = MoneyUtils.parseCurrency(priceCtrl.text);
      final ok = await PriceCatalogService.setCustomerPrice(
        c.importKey,
        p,
        note: noteCtrl.text.trim(),
      );
      if (mounted) {
        _snack(
          !ok
              ? 'Không lưu được.'
              : (p > 0
                  ? 'Đã đặt giá thu khách: ${MoneyUtils.formatCurrency(p)}đ'
                  : 'Đã xoá giá thu khách.'),
          err: !ok,
        );
      }
    } else if (mounted && action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Xoá khỏi bảng giá?'),
          content: Text(
            'Xoá "${c.itemName}" khỏi bảng giá NCC. Lịch sử giá nhập cũng '
            'sẽ không còn tra được. Không ảnh hưởng Kho phụ tùng và các đơn '
            'hàng đã tạo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Xoá'),
            ),
          ],
        ),
      );
      if (ok == true) {
        final done = await PriceCatalogService.softDelete(c);
        if (mounted) {
          _snack(done ? 'Đã xoá khỏi bảng giá.' : 'Không xoá được.',
              err: !done);
        }
      }
    }

    priceCtrl.dispose();
    noteCtrl.dispose();
    if (mounted) await _load();
  }

  Future<void> _openPinSheet(PriceBookRow r) async {
    if (r.scope == 'catalog') {
      await _openCatalogSheet(r);
      return;
    }
    final priceCtrl = TextEditingController(
      text: CurrencyTextField.formatDisplay(r.effectivePrice),
    );
    final costCtrl = TextEditingController(
      text: CurrencyTextField.formatDisplay(r.effectiveCost),
    );
    final noteCtrl = TextEditingController(text: r.pinnedNote ?? '');

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          r.title,
          style: const TextStyle(fontSize: 15),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: SizedBox(
          // Chot be ngang: tren web/may tinh bang dialog mac dinh
          // gian rat rong, o nhap gia nam lot thom giua man.
          width: responsiveDialogWidth(ctx, maxWidth: 520),
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.scope == 'part')
                // Nhân viên không có quyền xem giá vốn ⇒ không hiện dòng vốn.
                _canViewCost
                    ? Text(
                        'Vốn hiện tại: ${MoneyUtils.formatCurrency(r.autoCost)}đ'
                        '${r.autoCost <= 0 ? ' (chưa có trong Kho phụ tùng — chỉ để tham khảo)' : ' (đang lưu trong Kho phụ tùng)'}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      )
                    : const SizedBox.shrink()
              else
                Text(
                  'Đề xuất: ${MoneyUtils.formatCurrency(r.autoPrice)}đ '
                  '(${r.sampleCount} mẫu · ${r.confidenceLabel})',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              const SizedBox(height: 12),
              CurrencyTextField(
                controller: priceCtrl,
                label: switch (r.scope) {
                  'repair' => 'Giá thu khách (niêm yết)',
                  'part' => 'Giá thu khách (tuỳ chọn)',
                  _ => 'Giá bán (niêm yết)',
                },
              ),
              if (_canViewCost) ...[
                const SizedBox(height: 10),
                CurrencyTextField(
                  controller: costCtrl,
                  label: r.scope == 'part'
                      ? 'Giá vốn tham khảo'
                      : 'Giá vốn dự kiến (tuỳ chọn)',
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (tuỳ chọn)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                r.scope == 'part'
                    ? 'Chỉ để tham khảo — không tự điền vào đơn sửa.'
                    : 'Ghim = đặt giá chính thức, form tạo đơn sẽ tự điền giá này.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              if (r.scope != 'part') ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(ctx, 'sources'),
                    icon: const Icon(Icons.list_alt_rounded, size: 16),
                    label: Text(
                      r.scope == 'repair'
                          ? 'Xem ${r.sampleCount} đơn tương ứng'
                          : 'Xem ${r.sampleCount} sản phẩm tương ứng',
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
        actions: [
          if (r.isPinned)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'unpin'),
              child: const Text('Bỏ ghim',
                  style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'pin'),
            child: const Text('Ghim giá'),
          ),
        ],
      ),
    );

    if (!mounted || action == null) return;
    if (action == 'sources') {
      await _openSources(r);
    } else if (action == 'unpin') {
      await PriceBookService.unpin(r.key);
      _snack('Đã bỏ ghim.');
    } else if (action == 'pin') {
      final p = MoneyUtils.parseCurrency(priceCtrl.text);
      final c = MoneyUtils.parseCurrency(costCtrl.text);
      if (r.scope == 'part') {
        // Phụ tùng: chỉ cần 1 trong 2 (vốn tham khảo hoặc giá thu) — không
        // bắt buộc có giá thu như đơn sửa/SP.
        if (p <= 0 && c <= 0) {
          _snack('Nhập giá vốn hoặc giá thu khách.', err: true);
          return;
        }
      } else if (p <= 0) {
        _snack('Nhập giá niêm yết hợp lệ.', err: true);
        return;
      }
      await PriceBookService.pin(
        r.key,
        price: p,
        cost: c > 0 ? c : null,
        note: noteCtrl.text.trim(),
        displayName: r.scope == 'part' ? r.title : null,
      );
      _snack(p > 0
          ? 'Đã ghim: ${MoneyUtils.formatCurrency(p)}đ'
          : 'Đã lưu giá vốn tham khảo: ${MoneyUtils.formatCurrency(c)}đ');
    }
    priceCtrl.dispose();
    costCtrl.dispose();
    noteCtrl.dispose();
    await _load();
  }

  Future<void> _bulkApply() async {
    setState(() => _loading = true);
    final proposals = await PriceBookService.proposeSalePrices();
    if (!mounted) return;
    setState(() => _loading = false);

    if (proposals.isEmpty) {
      _snack('Không có SP nào chưa có giá mà tính được giá đề xuất.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Áp giá cho ${proposals.length} sản phẩm'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Các SP chưa có giá bán sẽ được đặt theo giá đề xuất:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in proposals.take(30))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• ${p.label} → ${MoneyUtils.formatCurrency(p.newPrice)}đ',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    if (proposals.length > 30)
                      Text('… và ${proposals.length - 30} SP khác',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Áp ${proposals.length} SP'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _loading = true);
    final n = await PriceBookService.commitSalePrices(proposals);
    if (!mounted) return;
    _snack('Đã đặt giá cho $n sản phẩm.');
    await _load();
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

/// Lối tắt mở màn "Bảng giá". [initialTab] 0 = Sửa chữa, 1 = Bán hàng.
void openPriceBook(BuildContext context, {int initialTab = 0}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => PriceBookView(initialTab: initialTab),
    ),
  );
}
