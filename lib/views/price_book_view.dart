import 'package:flutter/material.dart';

import '../models/price_book_models.dart';
import '../services/price_book_service.dart';
import '../utils/money_utils.dart';
import '../utils/vietnamese_utils.dart';
import '../widgets/currency_text_field.dart';
import '../widgets/custom_app_bar.dart';

/// "Bảng giá" — giá đề xuất (trung vị lịch sử) cho sửa chữa & bán hàng,
/// cho phép chủ shop GHIM giá niêm yết. Form tạo đơn đọc từ đây.
class PriceBookView extends StatefulWidget {
  const PriceBookView({super.key});

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

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)..addListener(_onTab);
    _load();
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
    if (!mounted) return;
    setState(() {
      _repair = r;
      _sale = s;
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
                b.toUpperCase(),
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

  Widget _rowCard(PriceBookRow r) {
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
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${r.sampleCount} mẫu · ${r.confidenceLabel}'
                      '${r.minPrice > 0 && r.minPrice != r.maxPrice ? ' · ${MoneyUtils.formatCurrency(r.minPrice)}–${MoneyUtils.formatCurrency(r.maxPrice)}đ' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${MoneyUtils.formatCurrency(r.effectivePrice)}đ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: r.isPinned
                          ? Colors.indigo.shade700
                          : Colors.black87,
                    ),
                  ),
                  if (r.isPinned)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
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
                    )
                  else if (r.autoCost > 0)
                    Text(
                      'lãi ${MoneyUtils.formatCurrency(r.effectiveProfit)}đ',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.green.shade700,
                      ),
                    ),
                ],
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Colors.grey),
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
    if (action == 'unpin') {
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

/// Lối tắt mở màn "Bảng giá".
void openPriceBook(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(builder: (_) => const PriceBookView()),
  );
}
