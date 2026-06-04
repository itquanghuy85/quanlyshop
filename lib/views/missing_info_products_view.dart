import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart' show DBHelper;
import '../models/product_model.dart';
import '../models/shop_settings_model.dart';
import '../services/event_bus.dart';
import '../services/financial_activity_service.dart';
import '../services/notification_service.dart';
import '../services/sync_orchestrator.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/money_utils.dart';
import '../models/sale_order_model.dart';
import '../widgets/currency_text_field.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/supplier_picker_sheet.dart';
import 'inventory_detail_view.dart';
import 'sale_detail_view.dart';

class MissingInfoProductsView extends StatefulWidget {
  final ShopSettings? shopSettings;
  final bool canViewCostPrice;
  final String role;

  const MissingInfoProductsView({
    super.key,
    required this.shopSettings,
    required this.canViewCostPrice,
    required this.role,
  });

  @override
  State<MissingInfoProductsView> createState() => _MissingInfoProductsViewState();
}

class _MissingInfoProductsViewState extends State<MissingInfoProductsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _db = DBHelper();

  static const _pageSize = 20;

  // Tab 0: Còn hàng, Tab 1: Đã bán
  final _products = [<Product>[], <Product>[]];
  final _offsets = [0, 0];
  final _hasMore = [true, true];
  final _loading = [true, true];
  final _counts = [0, 0];

  // ── Dedup helpers ────────────────────────────────────────────────────────────

  /// Key duy nhất cho mỗi sản phẩm: ưu tiên firestoreId → imei → name+ngày
  static String _productKey(Product p) {
    if (p.firestoreId != null && p.firestoreId!.isNotEmpty) return p.firestoreId!;
    if (p.imei != null && p.imei!.isNotEmpty) return 'imei:${p.imei}';
    return 'name:${p.name}:${p.createdAt}';
  }

  /// Điểm đầy đủ thông tin — record có nhiều info hơn được giữ lại
  static int _infoScore(Product p) =>
      (p.firestoreId != null && p.firestoreId!.isNotEmpty ? 4 : 0) +
      (p.cost > 0 ? 2 : 0) +
      (p.supplier != null && p.supplier!.isNotEmpty ? 2 : 0) +
      (p.imei != null && p.imei!.isNotEmpty ? 1 : 0);

  /// Loại bỏ record trùng — khi 2 record cùng key, giữ cái có nhiều thông tin hơn
  static List<Product> _dedup(List<Product> list, [Map<String, Product>? seen]) {
    final map = seen ?? <String, Product>{};
    for (final p in list) {
      final key = _productKey(p);
      if (!map.containsKey(key) || _infoScore(p) > _infoScore(map[key]!)) {
        map[key] = p;
      }
    }
    return map.values.toList();
  }
  final _scrollCtrs = [ScrollController(), ScrollController()];
  StreamSubscription<String>? _productEventSub;

  bool get _allowPendingCost => widget.shopSettings?.allowPendingCost ?? false;
  bool get _enableSupplier => widget.shopSettings?.enableSupplier ?? true;
  bool get _canManage =>
      widget.role == 'owner' ||
      widget.role == 'admin' ||
      UserService.isCurrentUserSuperAdmin();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollCtrs[0].addListener(() => _onScroll(0));
    _scrollCtrs[1].addListener(() => _onScroll(1));
    _load(0);
    _load(1);
    _productEventSub = EventBus().stream
        .where((e) => e == 'financial_changed' || e == 'products_changed')
        .listen((_) { if (mounted) { _load(0); _load(1); } });
  }

  @override
  void dispose() {
    _productEventSub?.cancel();
    _tabController.dispose();
    _scrollCtrs[0].dispose();
    _scrollCtrs[1].dispose();
    super.dispose();
  }

  void _onScroll(int tab) {
    final c = _scrollCtrs[tab];
    if (c.position.pixels >= c.position.maxScrollExtent - 200 &&
        _hasMore[tab] &&
        !_loading[tab]) {
      _loadMore(tab);
    }
  }

  Future<void> _load(int tab) async {
    if (!mounted) return;
    setState(() {
      _loading[tab] = true;
      _products[tab] = [];
      _offsets[tab] = 0;
      _hasMore[tab] = true;
    });
    final inStock = tab == 0;
    final page = await _db.getProductsPaged(
      _pageSize, 0,
      inStockOnly: inStock,
      soldOnly: !inStock,
      missingInfoOnly: true,
    );
    final count = await _db.getProductsCount(
      inStockOnly: inStock,
      soldOnly: !inStock,
      missingInfoOnly: true,
    );
    if (!mounted) return;
    final deduped = _dedup(page);
    setState(() {
      _products[tab] = deduped;
      _offsets[tab] = _pageSize;
      _hasMore[tab] = page.length >= _pageSize;
      _counts[tab] = count;
      _loading[tab] = false;
    });
  }

  Future<void> _loadMore(int tab) async {
    if (!mounted || _loading[tab]) return;
    setState(() => _loading[tab] = true);
    final inStock = tab == 0;
    final page = await _db.getProductsPaged(
      _pageSize, _offsets[tab],
      inStockOnly: inStock,
      soldOnly: !inStock,
      missingInfoOnly: true,
    );
    if (!mounted) return;
    // Dedup mới kết hợp với items hiện có để loại bỏ trùng cross-page
    final seen = <String, Product>{
      for (final p in _products[tab]) _productKey(p): p,
    };
    final merged = _dedup(page, seen);
    setState(() {
      _products[tab] = merged;
      _offsets[tab] += _pageSize;
      _hasMore[tab] = page.length >= _pageSize;
      _loading[tab] = false;
    });
  }

  Future<void> _refresh(int tab) => _load(tab);

  // ── Navigation ──────────────────────────────────────────────────────────────

  Future<void> _openDetail(Product p, {required bool isSold}) async {
    if (!mounted) return;
    if (isSold && p.imei != null && p.imei!.isNotEmpty) {
      final saleMaps = await _db.getSalesByProductImei(p.imei!);
      if (!mounted) return;
      if (saleMaps.isNotEmpty) {
        final sale = SaleOrder.fromMap(saleMaps.last); // lấy hóa đơn gần nhất
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => SaleDetailView(sale: sale),
        ));
        return;
      }
    }
    // Fallback hoặc còn hàng → xem chi tiết kho
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => InventoryDetailView(product: p),
      ));
    }
  }

  Future<void> _editCost(Product p) async {
    final costCtrl = TextEditingController();
    String selectedPayment = 'TIỀN MẶT';
    String supplierName = p.supplier?.trim() ?? '';
    const fieldTextColor = Color(0xFF1F2937);
    const fieldLabelColor = Color(0xFF6B7280);

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.attach_money_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Nhập giá vốn: ${p.name}',
                    style: const TextStyle(color: Color(0xFF1C2331), fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  )),
                ]),
                const SizedBox(height: 16),
                CurrencyTextField(controller: costCtrl, label: 'Giá vốn (đ)', icon: Icons.account_balance_wallet_outlined),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedPayment,
                  decoration: const InputDecoration(
                    labelText: 'Phương thức thanh toán',
                    labelStyle: TextStyle(color: fieldLabelColor),
                    prefixIcon: Icon(Icons.payment, color: fieldLabelColor),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFD1D5DB))),
                  ),
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: fieldTextColor, fontWeight: FontWeight.w600),
                  items: ['TIỀN MẶT', 'CHUYỂN KHOẢN', 'CÔNG NỢ']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setS(() => selectedPayment = v ?? 'TIỀN MẶT'),
                ),
                if (_enableSupplier) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showSupplierPickerSheet(ctx);
                      final name = (picked?['name'] as String?)?.trim() ?? '';
                      if (name.isNotEmpty) setS(() => supplierName = name);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: selectedPayment == 'CÔNG NỢ' ? 'Nhà cung cấp (bắt buộc)' : 'Nhà cung cấp',
                        labelStyle: const TextStyle(color: fieldLabelColor),
                        prefixIcon: const Icon(Icons.storefront_outlined, color: fieldLabelColor),
                        suffixIcon: const Icon(Icons.search, color: fieldLabelColor),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(
                          color: selectedPayment == 'CÔNG NỢ' && supplierName.isEmpty
                              ? Colors.red.shade400 : const Color(0xFFD1D5DB),
                        )),
                      ),
                      child: Text(
                        supplierName.isEmpty ? '-- Chạm để chọn --' : supplierName,
                        style: TextStyle(
                          color: supplierName.isEmpty ? fieldLabelColor : fieldTextColor,
                          fontWeight: supplierName.isEmpty ? FontWeight.w500 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text('Hủy'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    icon: const Icon(Icons.check, color: Colors.white, size: 16),
                    label: const Text('Lưu giá vốn', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    onPressed: () {
                      final cost = CurrencyTextField.parseValue(costCtrl.text);
                      if (cost <= 0) {
                        NotificationService.showSnackBar('Giá vốn phải lớn hơn 0', color: Colors.red);
                        return;
                      }
                      if (selectedPayment == 'CÔNG NỢ' && supplierName.isEmpty) {
                        NotificationService.showSnackBar('Thanh toán CÔNG NỢ phải chọn nhà cung cấp', color: Colors.red);
                        return;
                      }
                      Navigator.pop(ctx, {'payment': selectedPayment, 'supplier': supplierName});
                    },
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );

    // dispose controller sau khi sheet đóng
    final costText = costCtrl.text;
    costCtrl.dispose();
    if (result == null || !mounted) return;
    // newCost đã validate trong modal, nhưng double-check để an toàn
    final newCost = CurrencyTextField.parseValue(costText);
    if (newCost <= 0) return;
    final payment = result['payment'] as String;
    final supplier = result['supplier'] as String;

    try {
      final updated = p.copyWith(
        cost: newCost,
        supplier: supplier.isNotEmpty ? supplier : p.supplier,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _db.upsertProduct(updated);
      await SyncOrchestrator().enqueue(
        entityType: SyncEntityType.product,
        entityId: updated.id!,
        firestoreId: updated.firestoreId,
        operation: SyncOperation.update,
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      final shopId = await UserService.getCurrentShopId() ?? '';
      if (!mounted) return;
      final supplierLabel = supplier.isNotEmpty ? supplier : 'NCC';

      if (payment == 'CÔNG NỢ') {
        final debtFid = 'debt_cost_${p.firestoreId ?? p.id}_$now';
        final debtId = await _db.insertDebt({
          'firestoreId': debtFid,
          'type': 'SHOP_OWES',
          'debtType': 'SHOP_OWES',
          'personName': supplierLabel.toUpperCase().trim(),
          'phone': '',
          'totalAmount': newCost,
          'paidAmount': 0,
          'status': 'ACTIVE',
          'note': 'Nhập giá vốn: ${p.name} - ${MoneyUtils.formatCurrency(newCost)}đ',
          'linkedId': p.firestoreId ?? '',
          'linkedType': 'product_cost',
          'createdAt': now,
          'updatedAt': now,
          'shopId': shopId,
          'deleted': 0,
          'isSynced': 0,
        });
        if (debtId > 0) {
          await SyncOrchestrator().enqueueDebt(
            debtId,
            firestoreId: debtFid,
            operation: SyncOperation.create,
          );
        }
        EventBus().emit('debts_changed');
      } else {
        final expFid = 'exp_cost_${p.firestoreId ?? p.id}_$now';
        final expId = await _db.insertExpense({
          'firestoreId': expFid,
          'category': 'NHẬP HÀNG',
          'title': 'Giá vốn: ${p.name}',
          'amount': newCost,
          'paymentMethod': payment,
          'note': 'Nhập giá vốn: ${p.name}',
          'date': now,
          'createdAt': now,
          'shopId': shopId,
          'isSynced': 0,
        });
        if (expId > 0) {
          await SyncOrchestrator().enqueueExpense(
            expId,
            firestoreId: expFid,
            operation: SyncOperation.create,
          );
        }
      }

      await FinancialActivityService.logPurchase(
        firestoreId: 'cost_${p.firestoreId ?? p.id}_$now',
        amount: newCost,
        paymentMethod: payment,
        productName: p.name,
        supplierName: supplierLabel,
        quantity: p.quantity,
        createdAt: now,
      );

      EventBus().emit('financial_changed');
      NotificationService.showSnackBar(
        'Đã lưu giá vốn ${MoneyUtils.formatCurrency(newCost)}đ • $payment',
        color: Colors.green,
      );
      // Reload cả 2 tabs để count badges cập nhật đúng
      _load(0);
      _load(1);
    } catch (e) {
      NotificationService.showSnackBar('Lỗi: $e', color: Colors.red);
    }
  }

  // Chọn NCC
  Future<void> _pickSupplier(Product p) async {
    final picked = await showSupplierPickerSheet(context);
    if (!mounted) return;
    final name = (picked?['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return;
    try {
      final updated = p.copyWith(supplier: name, updatedAt: DateTime.now().millisecondsSinceEpoch);
      await _db.upsertProduct(updated);
      await SyncOrchestrator().enqueue(
        entityType: SyncEntityType.product,
        entityId: updated.id!,
        firestoreId: updated.firestoreId,
        operation: SyncOperation.update,
      );
      NotificationService.showSnackBar('Đã gán NCC: $name', color: Colors.teal);
      // Reload cả 2 tabs để count badges cập nhật đúng
      _load(0);
      _load(1);
    } catch (e) {
      NotificationService.showSnackBar('Lỗi: $e', color: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canView = _canManage && widget.canViewCostPrice;
    if (!canView) {
      return Scaffold(
        appBar: CustomAppBar.build(title: 'Theo dõi thiếu thông tin'),
        body: const Center(child: Text('Không có quyền xem')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar.build(
        title: 'Thiếu vốn / NCC',
        subtitle: 'Hàng chưa đủ thông tin kế toán',
        titleWidget: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Thiếu vốn / NCC',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Hàng chưa đủ thông tin kế toán',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'Còn hàng (${_counts[0]})'),
            Tab(text: 'Đã bán (${_counts[1]})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTab(0), _buildTab(1)],
      ),
    );
  }

  Widget _buildTab(int tab) {
    if (_loading[tab] && _products[tab].isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final list = _products[tab];
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 12),
            Text(
              tab == 0 ? 'Tất cả hàng còn đều đủ thông tin!' : 'Không có hàng đã bán thiếu thông tin.',
              style: AppTextStyles.body1.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _refresh(tab),
      child: ListView.builder(
        controller: _scrollCtrs[tab],
        padding: const EdgeInsets.all(12),
        itemCount: list.length + (_hasMore[tab] ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == list.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildCard(list[i], tab);
        },
      ),
    );
  }

  Widget _buildCard(Product p, int tab) {
    final missingCost = _allowPendingCost && widget.canViewCostPrice && p.cost == 0;
    final missingSupplier = _enableSupplier && (p.supplier == null || p.supplier!.trim().isEmpty);
    // Edge case: cả 2 chức năng tắt → không có badge/action nào → ẩn card
    if (!missingCost && !missingSupplier) return const SizedBox.shrink();
    final isSold = tab == 1;

    return GestureDetector(
      onTap: () => _openDetail(p, isSold: isSold),
      child: Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: missingCost && missingSupplier
              ? Colors.red.shade200
              : missingCost
                  ? Colors.orange.shade200
                  : Colors.indigo.shade100,
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: tên + ngày
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.name,
                    style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yy').format(
                    DateTime.fromMillisecondsSinceEpoch(p.createdAt),
                  ),
                  style: AppTextStyles.caption.copyWith(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Meta info
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (p.imei != null && p.imei!.isNotEmpty)
                  _chip(p.imei!, Colors.blueGrey, Icons.tag_rounded),
                if (p.supplier != null && p.supplier!.isNotEmpty)
                  _chip(p.supplier!, Colors.teal.shade700, Icons.storefront_outlined),
                if (p.cost > 0 && widget.canViewCostPrice)
                  _chip(MoneyUtils.formatCompactCurrency(p.cost), Colors.deepPurple, Icons.account_balance_wallet_outlined),
                if (isSold)
                  _chip('Đã bán', Colors.grey.shade600, Icons.sell_outlined),
                if (!isSold)
                  _chip('Tồn: ${p.quantity}', Colors.blue.shade700, Icons.inventory_2_outlined),
              ],
            ),
            const SizedBox(height: 8),
            // Missing badges + actions
            Row(
              children: [
                if (missingCost)
                  _badge('⚠ Chưa vốn', Colors.orange.shade700, Colors.orange.shade50),
                if (missingCost) const SizedBox(width: 6),
                if (missingSupplier)
                  _badge('⚠ Chưa NCC', Colors.red.shade600, Colors.red.shade50),
                const Spacer(),
                if (missingCost && _canManage)
                  _actionBtn(
                    label: 'Nhập vốn',
                    icon: Icons.edit_rounded,
                    color: Colors.orange,
                    onTap: () => _editCost(p),
                  ),
                if (missingCost && missingSupplier && _canManage)
                  const SizedBox(width: 6),
                if (missingSupplier && _canManage)
                  _actionBtn(
                    label: 'Chọn NCC',
                    icon: Icons.store_mall_directory_outlined,
                    color: Colors.indigo,
                    onTap: () => _pickSupplier(p),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),   // Card
    );   // GestureDetector
  }

  Widget _chip(String label, Color color, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _badge(String label, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: AppTextStyles.caption.copyWith(color: fg, fontWeight: FontWeight.bold)),
      );

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
}
