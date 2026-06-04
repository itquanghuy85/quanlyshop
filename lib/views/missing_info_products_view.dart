import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart' show DBHelper;
import '../models/product_model.dart';
import '../models/shop_settings_model.dart';
import '../services/notification_service.dart';
import '../services/sync_orchestrator.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/money_utils.dart';
import '../widgets/currency_text_field.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/supplier_picker_sheet.dart';

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
  final _scrollCtrs = [ScrollController(), ScrollController()];

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
  }

  @override
  void dispose() {
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
      missingInfoOnly: true,
    );
    // Tab 1 (đã bán): chỉ lấy quantity <= 0
    final filtered = inStock ? page : page.where((p) => p.quantity <= 0).toList();
    final count = await _db.getProductsCount(
      inStockOnly: inStock,
      missingInfoOnly: true,
    );
    if (!mounted) return;
    setState(() {
      _products[tab] = filtered;
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
      missingInfoOnly: true,
    );
    final filtered = inStock ? page : page.where((p) => p.quantity <= 0).toList();
    if (!mounted) return;
    setState(() {
      _products[tab].addAll(filtered);
      _offsets[tab] += _pageSize;
      _hasMore[tab] = page.length >= _pageSize;
      _loading[tab] = false;
    });
  }

  Future<void> _refresh(int tab) => _load(tab);

  // Nhập giá vốn inline
  Future<void> _editCost(Product p) async {
    final costCtrl = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C2331),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.attach_money_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nhập giá vốn: ${p.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CurrencyTextField(
                controller: costCtrl,
                label: 'Giá vốn (đ)',
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Bỏ qua'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, color: Colors.white, size: 16),
                      label: const Text('Lưu giá vốn', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final newCost = CurrencyTextField.parseValue(costCtrl.text);
    if (newCost <= 0) {
      NotificationService.showSnackBar('Giá vốn phải lớn hơn 0', color: Colors.red);
      return;
    }
    try {
      final updated = p.copyWith(cost: newCost, updatedAt: DateTime.now().millisecondsSinceEpoch);
      await _db.upsertProduct(updated);
      await SyncOrchestrator().enqueue(
        entityType: SyncEntityType.product,
        entityId: updated.id!,
        firestoreId: updated.firestoreId,
        operation: SyncOperation.update,
      );
      NotificationService.showSnackBar('Đã lưu giá vốn ${MoneyUtils.formatCurrency(newCost)} đ', color: Colors.green);
      _load(_tabController.index);
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
      _load(_tabController.index);
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
        bottom: TabBar(
          controller: _tabController,
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
    final isSold = tab == 1;

    return Card(
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
    );
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
