import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models/price_book_models.dart';
import '../models/product_model.dart';
import '../services/price_book_service.dart';
import '../utils/money_utils.dart';
import '../utils/vietnamese_utils.dart';
import '../widgets/currency_text_field.dart';
import '../widgets/custom_app_bar.dart';
import 'similar_repair_history_view.dart';

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
  List<PriceBookRow> _sale = const [];
  int _seasonPct = 0;

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
    const xlsx = XTypeGroup(label: 'Excel', extensions: ['xlsx']);
    final file = await openFile(acceptedTypeGroups: [xlsx]);
    if (file == null || !mounted) return;
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
    final r = await PriceBookService.buildRepairRows();
    final s = await PriceBookService.buildSaleRows();
    final pct = await PriceBookService.seasonPct();
    if (!mounted) return;
    setState(() {
      _repair = r;
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
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'season', child: Text('Hệ số giá mùa vụ')),
              PopupMenuItem(value: 'export', child: Text('Xuất Excel')),
              PopupMenuItem(value: 'import', child: Text('Nhập từ Excel')),
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
      body: Column(
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
                      _list(_filtered(_repair), 'Chưa có đơn sửa nào đã hoàn '
                          'thành để tính giá.'),
                      _list(_filtered(_sale), 'Chưa có sản phẩm nào để tính giá.'),
                    ],
                  ),
          ),
        ],
      ),
    );
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
            for (final r in groups[b]!) _rowCard(r),
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

  Widget _rowCard(PriceBookRow r) {
    final priceLabel = r.scope == 'repair' ? 'Thu' : 'Bán';
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
                        'NIÊM YẾT',
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
                          'Chưa có giá ${priceLabel.toLowerCase()} — chạm để đặt giá',
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.grey.shade700),
                        ),
                      ),
                      if (r.effectiveCost > 0)
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
                ),
                const SizedBox(height: 4),
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPinSheet(PriceBookRow r) async {
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đề xuất: ${MoneyUtils.formatCurrency(r.autoPrice)}đ '
                '(${r.sampleCount} mẫu · ${r.confidenceLabel})',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              CurrencyTextField(
                controller: priceCtrl,
                label: r.scope == 'repair'
                    ? 'Giá thu khách (niêm yết)'
                    : 'Giá bán (niêm yết)',
              ),
              const SizedBox(height: 10),
              CurrencyTextField(
                controller: costCtrl,
                label: 'Giá vốn dự kiến (tuỳ chọn)',
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
                'Ghim = đặt giá chính thức, form tạo đơn sẽ tự điền giá này.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
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
      if (p <= 0) {
        _snack('Nhập giá niêm yết hợp lệ.', err: true);
        return;
      }
      final c = MoneyUtils.parseCurrency(costCtrl.text);
      await PriceBookService.pin(
        r.key,
        price: p,
        cost: c > 0 ? c : null,
        note: noteCtrl.text.trim(),
      );
      _snack('Đã ghim: ${MoneyUtils.formatCurrency(p)}đ');
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
