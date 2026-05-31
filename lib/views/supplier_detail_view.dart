import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/responsive_wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/supplier_model.dart';
import '../models/payment_intent_model.dart';
import '../constants/financial_constants.dart';
import '../services/supplier_service.dart';
import '../services/payment_intent_service.dart';
import '../services/user_service.dart';
import '../data/db_helper.dart';
import '../utils/money_utils.dart';
import '../widgets/currency_text_field.dart';
import '../services/notification_service.dart';
import '../services/event_bus.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/gradient_fab.dart';
import '../utils/excel_export_helper.dart';
import '../models/product_model.dart';
import '../widgets/custom_app_bar.dart';
import 'inventory_detail_view.dart';
import 'supplier_form_view.dart';

class SupplierDetailView extends StatefulWidget {
  final Supplier supplier;
  const SupplierDetailView({super.key, required this.supplier});

  @override
  State<SupplierDetailView> createState() => _SupplierDetailViewState();
}

class _SupplierDetailViewState extends State<SupplierDetailView> with TickerProviderStateMixin {
  final _service = SupplierService();
  final _db = DBHelper();
  late TabController _tab;

  List<Map<String, dynamic>> _imports = [];
  List<Map<String, dynamic>> _importOrders = [];
  Map<String, List<Map<String, dynamic>>> _importOrderItems = {};
  List<Map<String, dynamic>> _debts = [];
  List<Map<String, dynamic>> _payments = [];
  List<Product> _products = [];
  bool _loading = true;
  String? _shopId;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _load();
    EventBus().stream.where((e) => e == 'debts_changed' || e == 'suppliers_changed').listen((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _shopId ??= await UserService.getCurrentShopId();
      final isWarehouse = widget.supplier.type == 'warehouse';
      final db = await _db.database;

      final results = await Future.wait([
        _db.getSupplierImportHistory(
          widget.supplier.id!,
          supplierName: widget.supplier.name,
        ),
        _db.getAllDebts(),
        if (_shopId != null)
          _db.getProductsBySupplier(
            _shopId!,
            supplierName: widget.supplier.name,
            isWarehouse: isWarehouse,
          )
        else
          Future.value(<Product>[]),
      ]);

      final imports = results[0] as List<Map<String, dynamic>>;
      final allDebts = results[1] as List<Map<String, dynamic>>;
      final products = results[2] as List<Product>;

      // Load import_orders from KiotViet import
      List<Map<String, dynamic>> importOrders = [];
      Map<String, List<Map<String, dynamic>>> importOrderItems = {};
      try {
        importOrders = await db.query(
          'import_orders',
          where: '(UPPER(supplierName) = UPPER(?) OR supplierId = ?) AND (deleted IS NULL OR deleted != 1)',
          whereArgs: [widget.supplier.name, widget.supplier.id?.toString() ?? '-1'],
          orderBy: 'importDate DESC',
        );
        for (final order in importOrders) {
          final fid = order['firestoreId'] as String? ?? '';
          if (fid.isEmpty) continue;
          final items = await db.query(
            'import_order_items',
            where: 'importOrderFirestoreId = ? AND (deleted IS NULL OR deleted != 1)',
            whereArgs: [fid],
          );
          importOrderItems[fid] = items;
        }
      } catch (_) {}

      final debts = allDebts
          .where((d) =>
              d['type'] == 'SHOP_OWES' &&
              (d['personName'] ?? '').toString().toUpperCase() ==
                  widget.supplier.name.toUpperCase() &&
              (d['deleted'] ?? 0) != 1)
          .toList();

      final List<Map<String, dynamic>> payments = [];
      for (final d in debts) {
        final p = await _db.getDebtPayments(d['id'] as int);
        payments.addAll(p);
      }

      // Also load supplier_payments (paid to this supplier via payment dialog)
      List<Map<String, dynamic>> supplierPayments = [];
      if (widget.supplier.id != null) {
        try {
          supplierPayments = await db.query(
            'supplier_payments',
            where: 'supplierId = ? AND (deleted IS NULL OR deleted != 1)',
            whereArgs: [widget.supplier.id],
            orderBy: 'paidAt DESC',
          );
        } catch (_) {}
      }

      // Find products by IMEI from import_order_items (when supplier field not set)
      final foundIds = products.map((p) => p.id ?? 0).toSet();
      final imeiProducts = <Product>[];
      if (_shopId != null) {
        for (final items in importOrderItems.values) {
          for (final item in items) {
            final imei = item['imei'] as String?;
            if (imei == null || imei.isEmpty) continue;
            try {
              final rows = await db.query('products',
                  where: 'imei = ? AND shopId = ? AND (deleted IS NULL OR deleted != 1)',
                  whereArgs: [imei, _shopId!], limit: 1);
              for (final row in rows) {
                final pid = row['id'] as int? ?? 0;
                if (!foundIds.contains(pid)) {
                  imeiProducts.add(Product.fromMap(row));
                  foundIds.add(pid);
                }
              }
            } catch (_) {}
          }
        }
      }

      setState(() {
        _imports = imports;
        _importOrders = importOrders;
        _importOrderItems = importOrderItems;
        _debts = debts;
        _payments = [...payments, ...supplierPayments];
        _products = [...products, ...imeiProducts];
        _loading = false;
      });
    } catch (e) {
      NotificationService.showSnackBar('Lỗi tải chi tiết: $e', color: Colors.red);
      setState(() => _loading = false);
    }
  }

  // Fallback to import_orders when no manual debts recorded
  bool get _useImportOrdersForDebt => _debts.isEmpty && _importOrders.isNotEmpty;
  int get _totalDebt => _useImportOrdersForDebt
      ? _importOrders.fold(0, (s, o) => s + (o['totalAmount'] as int? ?? 0))
      : _debts.fold(0, (s, d) => s + (d['totalAmount'] as int? ?? 0));
  int get _paidDebt => _useImportOrdersForDebt
      ? _importOrders.fold(0, (s, o) => s + (o['paidAmount'] as int? ?? 0))
      : _debts.fold(0, (s, d) => s + (d['paidAmount'] as int? ?? 0));
  int get _remainDebt => _totalDebt - _paidDebt;

  Future<void> _editSupplier() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierFormView(editing: widget.supplier),
      ),
    );
    _load();
  }

  Future<void> _deleteSupplier() async {
    final messenger = ScaffoldMessenger.of(context);
    final password = await _showPasswordDialog();
    if (password == null || password.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập lại'), backgroundColor: Colors.red),
      );
      return;
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: password,
      );
      await currentUser.reauthenticateWithCredential(credential);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Mật khẩu không đúng!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa nhà cung cấp'),
        content: Text('Xóa "${widget.supplier.name}" khỏi danh sách?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('HỦY')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('XÓA', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final success = await _service.deleteSupplier(
      widget.supplier.id,
      firestoreId: widget.supplier.firestoreId,
      supplierName: widget.supplier.name,
    );
    if (success) {
      EventBus().emit('suppliers_changed');
      if (mounted) Navigator.pop(context);
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Lỗi: Không thể xóa nhà cung cấp'), backgroundColor: Colors.red),
      );
    }
  }

  Future<String?> _showPasswordDialog() async {
    String password = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nhập mật khẩu tài khoản để xác nhận:'),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              autofocus: true,
              onChanged: (v) => password = v,
              decoration: const InputDecoration(hintText: 'Mật khẩu'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('HỦY')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, password),
            child: const Text('XÁC NHẬN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar.build(
        title: widget.supplier.name,
        actions: [
          if (_tab.index == 0 && _imports.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.file_download),
              tooltip: 'Xuất Excel',
              onPressed: () => ExcelExportHelper.exportSupplierImportHistory(
                context,
                supplierName: widget.supplier.name,
                imports: _imports,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Sửa thông tin',
            onPressed: _editSupplier,
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded),
            tooltip: 'Xóa NCC',
            onPressed: _deleteSupplier,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Lịch sử nhập'),
            Tab(text: 'Công nợ'),
            Tab(text: 'Thống kê'),
            Tab(text: 'Sản phẩm'),
          ],
        ),
      ),
      body: ResponsiveCenter(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildContactCard(),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _buildImportTab(),
                      _buildDebtTab(),
                      _buildStatsTab(),
                      _buildProductsTab(),
                    ],
                  ),
                ),
              ],
            )),
      floatingActionButton: _tab.index == 1
          ? GradientFab.success(
              onPressed: _remainDebt <= 0 ? null : _payDialog,
              icon: Icons.payments,
              label: 'Thanh toán',
            )
          : null,
    );
  }

  Widget _buildContactCard() {
    final s = widget.supplier;
    final hasPhone = (s.phone ?? '').isNotEmpty;
    final hasEmail = (s.email ?? '').isNotEmpty;
    final hasAddress = (s.address ?? '').isNotEmpty;
    final hasNote = (s.note ?? '').isNotEmpty;
    if (!hasPhone && !hasEmail && !hasAddress && !hasNote) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          if (hasPhone)   _contactChip(Icons.phone_outlined, s.phone!, Colors.green),
          if (hasEmail)   _contactChip(Icons.email_outlined, s.email!, Colors.blue),
          if (hasAddress) _contactChip(Icons.location_on_outlined, s.address!, Colors.orange),
          if (hasNote)    _contactChip(Icons.notes_outlined, s.note!, Colors.purple),
        ],
      ),
    );
  }

  Widget _contactChip(IconData icon, String text, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Text(text, style: AppTextStyles.caption.copyWith(color: Colors.grey.shade700),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }

  Widget _buildImportTab() {
    final hasKv = _importOrders.isNotEmpty;
    final hasOld = _imports.isNotEmpty;
    final hasDebt = _debts.isNotEmpty;

    if (!hasKv && !hasOld && !hasDebt) {
      return Center(child: Text('Chưa có lịch sử nhập', style: AppTextStyles.body1));
    }

    final items = <Widget>[];

    // Priority 1: import_orders from KiotViet
    if (hasKv) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('Phiếu nhập hàng (${_importOrders.length})',
            style: AppTextStyles.headline6.copyWith(color: Colors.indigo.shade700)),
      ));
      for (final o in _importOrders) {
        final fid = o['firestoreId'] as String? ?? '';
        final code = o['orderCode'] as String? ?? fid.replaceFirst('KV:', '');
        final date = DateFormat('dd/MM/yyyy').format(
            DateTime.fromMillisecondsSinceEpoch(o['importDate'] as int? ?? 0));
        final total = o['totalAmount'] as int? ?? 0;
        final paid = o['paidAmount'] as int? ?? 0;
        final status = o['paymentStatus'] as String? ?? '';
        final items2 = _importOrderItems[fid] ?? [];
        final statusColor = status == 'PAID' ? Colors.green : (status == 'PARTIAL' ? Colors.orange : Colors.red);
        final statusLabel = status == 'PAID' ? 'Đã trả' : (status == 'PARTIAL' ? 'Trả một phần' : 'Chưa trả');
        items.add(Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ExpansionTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.indigo.shade50,
              child: Icon(Icons.local_shipping_outlined, size: 18, color: Colors.indigo.shade600),
            ),
            title: Text(code, style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text('$date · ${MoneyUtils.formatCurrency(total)}đ',
                style: AppTextStyles.caption),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4))),
              child: Text(statusLabel,
                  style: AppTextStyles.caption.copyWith(color: statusColor, fontWeight: FontWeight.w600)),
            ),
            children: [
              if (paid > 0 && paid < total)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Row(children: [
                    Text('Đã trả: ', style: AppTextStyles.caption),
                    Text(MoneyUtils.formatCurrency(paid) + 'đ',
                        style: AppTextStyles.caption.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                    Text(' / Còn: ', style: AppTextStyles.caption),
                    Text(MoneyUtils.formatCurrency(total - paid) + 'đ',
                        style: AppTextStyles.caption.copyWith(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ...items2.map((item) {
                final name = item['productName'] as String? ?? '';
                final imei = item['imei'] as String? ?? '';
                final qty = item['quantity'] as int? ?? 1;
                final cost = item['costPrice'] as int? ?? 0;
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.phone_android_rounded, size: 18, color: Colors.blueGrey),
                  title: Text(name, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: imei.isNotEmpty ? Text('IMEI: $imei', style: AppTextStyles.caption) : null,
                  trailing: Text(
                    'x$qty · ${MoneyUtils.formatCompactCurrency(cost)}đ',
                    style: AppTextStyles.caption.copyWith(color: Colors.indigo.shade700),
                  ),
                );
              }),
            ],
          ),
        ));
      }
    }

    // Priority 2: old supplier_import_history
    if (hasOld) {
      if (hasKv) items.add(const SizedBox(height: 8));
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('Lịch sử nhập cũ (${_imports.length})',
            style: AppTextStyles.headline6.copyWith(color: Colors.blueGrey.shade700)),
      ));
      for (final h in _imports) {
        final date = DateFormat('dd/MM/yyyy').format(
            DateTime.fromMillisecondsSinceEpoch(h['importDate'] as int? ?? 0));
        items.add(Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: const Icon(Icons.inventory_2_outlined, color: Colors.blue),
            title: Text(h['productName'] ?? 'Sản phẩm',
                style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('$date · ${MoneyUtils.formatCurrency(h['totalAmount'] as int? ?? 0)}đ',
                style: AppTextStyles.caption),
          ),
        ));
      }
    }

    // Priority 3: debts only (no purchase records)
    if (!hasKv && !hasOld && hasDebt) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('Ghi nợ (${_debts.length})',
            style: AppTextStyles.headline6.copyWith(color: Colors.orange.shade700)),
      ));
      for (final d in _debts) {
        final date = DateFormat('dd/MM/yyyy').format(
            DateTime.fromMillisecondsSinceEpoch(d['createdAt'] as int? ?? 0));
        final note = (d['note'] as String? ?? '').trim();
        final amount = d['totalAmount'] as int? ?? 0;
        items.add(Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: const Icon(Icons.receipt_long, color: Colors.orange),
            title: Text(note.isNotEmpty ? note : 'Nhập hàng',
                style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text('$date · ${MoneyUtils.formatCurrency(amount)}đ',
                style: AppTextStyles.caption),
          ),
        ));
      }
    }

    return ListView(padding: const EdgeInsets.all(14), children: items);
  }

  Widget _buildDebtTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _statChip('Tổng nợ', _totalDebt, AppColors.warning),
              const SizedBox(width: 8),
              _statChip('Đã trả', _paidDebt, AppColors.success),
              const SizedBox(width: 8),
              _statChip('Còn lại', _remainDebt, AppColors.error),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Text('Các khoản nợ', style: AppTextStyles.headline6),
              const SizedBox(height: 8),
              if (_useImportOrdersForDebt) ...[
                // Show unpaid import_orders as debt items
                ..._importOrders.where((o) => (o['paymentStatus'] as String? ?? '') != 'PAID').map((o) {
                  final code = o['orderCode'] as String? ?? '';
                  final total = o['totalAmount'] as int? ?? 0;
                  final paid = o['paidAmount'] as int? ?? 0;
                  final remain = total - paid;
                  final date = DateFormat('dd/MM/yyyy').format(
                      DateTime.fromMillisecondsSinceEpoch(o['importDate'] as int? ?? 0));
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      leading: const Icon(Icons.local_shipping_outlined, color: Colors.orange),
                      title: Text(code, style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Ngày nhập: $date', style: AppTextStyles.caption),
                        Text('Tổng: ${MoneyUtils.formatCurrency(total)}đ · Đã trả: ${MoneyUtils.formatCurrency(paid)}đ',
                            style: AppTextStyles.caption),
                      ]),
                      trailing: Text('Còn: ${MoneyUtils.formatCompactCurrency(remain)}đ',
                          style: AppTextStyles.caption.copyWith(
                              color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                    ),
                  );
                }),
                if (_importOrders.where((o) => (o['paymentStatus'] as String? ?? '') != 'PAID').isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Không có khoản nợ', style: AppTextStyles.caption),
                  ),
              ] else ...[
                ..._debts.map((d) => _debtTile(d)),
                if (_debts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Không có khoản nợ', style: AppTextStyles.caption),
                  ),
              ],
              const SizedBox(height: 12),
              Text('Thanh toán đã ghi nhận', style: AppTextStyles.headline6),
              const SizedBox(height: 8),
              ..._payments.map((p) => _paymentTile(p)),
              if (_payments.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Chưa có thanh toán', style: AppTextStyles.caption),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsTab() {
    final hasKv = _importOrders.isNotEmpty;
    // KiotViet import_orders data (preferred)
    final kvTotal = _importOrders.fold<int>(0, (s, o) => s + (o['totalAmount'] as int? ?? 0));
    final kvPaid = _importOrders.fold<int>(0, (s, o) => s + (o['paidAmount'] as int? ?? 0));
    final kvCount = _importOrders.length;
    final kvAvg = kvCount == 0 ? 0 : (kvTotal / kvCount).round();
    final kvItemCount = _importOrderItems.values.fold<int>(0, (s, list) => s + list.length);
    final kvUnpaid = kvTotal - kvPaid;
    // Debt-based data (fallback)
    final debtTotal = _totalDebt;
    final debtPaid = _paidDebt;
    final debtCount = _debts.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasKv) ...[
            // Summary chips
            Row(children: [
              _statChip('Tổng nhập', kvTotal, Colors.indigo),
              const SizedBox(width: 8),
              _statChip('Đã trả', kvPaid, AppColors.success),
              const SizedBox(width: 8),
              _statChip('Còn nợ', kvUnpaid, kvUnpaid > 0 ? AppColors.error : AppColors.success),
            ]),
            const SizedBox(height: 16),
            Text('Chi tiết phiếu nhập (KiotViet)', style: AppTextStyles.headline6),
            const Divider(),
            _statRow('Số phiếu nhập', '$kvCount phiếu'),
            _statRow('Tổng mặt hàng', '$kvItemCount sản phẩm'),
            _statRow('Tổng giá trị', '${MoneyUtils.formatCurrency(kvTotal)}đ'),
            _statRow('Đã thanh toán', '${MoneyUtils.formatCurrency(kvPaid)}đ'),
            if (kvUnpaid > 0)
              _statRow('Còn cần trả', '${MoneyUtils.formatCurrency(kvUnpaid)}đ',
                  valueColor: AppColors.error),
            _statRow('Trung bình/phiếu', '${MoneyUtils.formatCurrency(kvAvg)}đ'),
            // Paid status breakdown
            const SizedBox(height: 8),
            _statRow('Đã thanh toán đủ',
                '${_importOrders.where((o) => (o['paymentStatus'] ?? '') == 'PAID').length} phiếu',
                valueColor: AppColors.success),
            _statRow('Chưa thanh toán',
                '${_importOrders.where((o) => (o['paymentStatus'] ?? '') == 'UNPAID').length} phiếu',
                valueColor: kvUnpaid > 0 ? AppColors.error : Colors.grey),
          ] else if (debtCount > 0) ...[
            Row(children: [
              _statChip('Tổng nợ', debtTotal, AppColors.warning),
              const SizedBox(width: 8),
              _statChip('Đã trả', debtPaid, AppColors.success),
              const SizedBox(width: 8),
              _statChip('Còn lại', _remainDebt, AppColors.error),
            ]),
            const SizedBox(height: 16),
            _statRow('Số giao dịch', '$debtCount lần'),
            _statRow('Tổng giá trị', '${MoneyUtils.formatCurrency(debtTotal)}đ'),
            _statRow('Đã thanh toán', '${MoneyUtils.formatCurrency(debtPaid)}đ'),
            _statRow('Còn lại', '${MoneyUtils.formatCurrency(_remainDebt)}đ',
                valueColor: _remainDebt > 0 ? AppColors.error : AppColors.success),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Chưa có dữ liệu thống kê', style: AppTextStyles.body1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body1),
          Text(value, style: AppTextStyles.body1.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          )),
        ],
      ),
    );
  }

  Widget _statChip(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption.copyWith(color: color)),
            const SizedBox(height: 4),
            Text(MoneyUtils.formatCurrency(value), style: AppTextStyles.headline6.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _debtTile(Map<String, dynamic> d) {
    final remain = (d['totalAmount'] as int? ?? 0) - (d['paidAmount'] as int? ?? 0);
    final date = DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(d['createdAt'] as int? ?? 0));
    return Card(
      child: ListTile(
        title: Text('Nợ ${MoneyUtils.formatCurrency(d['totalAmount'] as int? ?? 0)}', style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ngày tạo: $date', style: AppTextStyles.caption),
            Text('Đã trả: ${MoneyUtils.formatCurrency(d['paidAmount'] as int? ?? 0)} | Còn: ${MoneyUtils.formatCurrency(remain)}', style: AppTextStyles.caption),
            if (d['note'] != null) Text('Ghi chú: ${d['note']}', style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  Widget _paymentTile(Map<String, dynamic> p) {
    final date = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(p['paidAt'] as int? ?? 0));
    return Card(
      child: ListTile(
        leading: const Icon(Icons.check_circle, color: Colors.green),
        title: Text('+ ${MoneyUtils.formatCurrency(p['amount'] as int? ?? 0)}'),
        subtitle: Text('$date | ${p['paymentMethod'] ?? ''}'),
        trailing: Text(p['note'] ?? '', style: AppTextStyles.caption),
      ),
    );
  }

  Widget _buildProductsTab() {
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Chưa có sản phẩm trong kho\ntừ nhà cung cấp này',
              textAlign: TextAlign.center,
              style: AppTextStyles.body1.copyWith(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final inStock = _products.where((p) => p.quantity > 0 && p.status != 0).toList();
    final sold = _products.where((p) => p.quantity <= 0 || p.status == 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary bar
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              _miniStat('Tổng', '${_products.length}', Colors.indigo),
              const SizedBox(width: 16),
              _miniStat('Còn hàng', '${inStock.length}', Colors.green),
              const SizedBox(width: 16),
              _miniStat('Đã bán', '${sold.length}', Colors.red),
              const Spacer(),
              if (_products.any((p) => p.cost > 0))
                _miniStat('Vốn TB',
                  MoneyUtils.formatCompactCurrency(
                    (_products.fold<int>(0, (s, p) => s + p.cost) / _products.length).round(),
                  ) + 'đ',
                  Colors.orange),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            itemCount: _products.length,
            itemBuilder: (_, i) {
              final p = _products[i];
              final isSold = p.quantity <= 0 || p.status == 0;
              final hasImei = (p.imei ?? '').isNotEmpty;
              final hasPrice = p.price > 0;
              final hasCost = p.cost > 0;
              final profit = hasPrice && hasCost ? p.price - p.cost : 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => InventoryDetailView(product: p)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isSold ? Colors.red.shade50 : Colors.green.shade50,
                          child: Icon(
                            isSold ? Icons.sell_outlined : Icons.phone_android_rounded,
                            size: 18,
                            color: isSold ? Colors.red.shade400 : Colors.green.shade600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name,
                                  style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Wrap(spacing: 8, runSpacing: 4, children: [
                                // Status
                                _tag(
                                  isSold ? 'Đã bán' : 'Còn x${p.quantity}',
                                  isSold ? Colors.red : Colors.green,
                                ),
                                // IMEI
                                if (hasImei)
                                  _tag('# ${p.imei}', Colors.blueGrey),
                                // Location
                                if ((p.locationCode ?? '').isNotEmpty)
                                  _tag(p.locationCode!, Colors.indigo),
                              ]),
                              if (hasPrice || hasCost) ...[
                                const SizedBox(height: 6),
                                Row(children: [
                                  if (hasCost) ...[
                                    Icon(Icons.shopping_cart_outlined, size: 13, color: Colors.orange.shade700),
                                    const SizedBox(width: 3),
                                    Text('Vốn: ${MoneyUtils.formatCompactCurrency(p.cost)}đ',
                                        style: AppTextStyles.caption.copyWith(color: Colors.orange.shade700)),
                                    const SizedBox(width: 10),
                                  ],
                                  if (hasPrice) ...[
                                    Icon(Icons.sell_outlined, size: 13, color: Colors.green.shade700),
                                    const SizedBox(width: 3),
                                    Text('Bán: ${MoneyUtils.formatCompactCurrency(p.price)}đ',
                                        style: AppTextStyles.caption.copyWith(color: Colors.green.shade700)),
                                  ],
                                  if (hasCost && hasPrice && profit > 0) ...[
                                    const SizedBox(width: 10),
                                    Text('Lãi: ${MoneyUtils.formatCompactCurrency(profit)}đ',
                                        style: AppTextStyles.caption.copyWith(
                                            color: Colors.teal.shade700, fontWeight: FontWeight.bold)),
                                  ],
                                ]),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: Colors.grey.shade500)),
        Text(value, style: AppTextStyles.body1.copyWith(
            color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: AppTextStyles.caption.copyWith(
              color: color, fontWeight: FontWeight.w500, fontSize: 10.5)),
    );
  }

  Future<void> _payDialog() async {
    final formKey = GlobalKey<FormState>();
    final payCtrl = TextEditingController();
    String method = 'TIỀN MẶT';
    String note = '';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thanh toán NCC'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CurrencyTextField(
                controller: payCtrl,
                label: 'Số tiền',
                validator: (v) => MoneyUtils.validateAmount(
                  v ?? '',
                  min: 1,
                  max: _remainDebt,
                  fieldName: 'Số tiền',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['TIỀN MẶT', 'CHUYỂN KHOẢN']
                    .map((m) => ChoiceChip(
                          label: Text(m),
                          selected: method == m,
                          onSelected: (v) => setState(() => method = m),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => note = v,
                decoration: const InputDecoration(labelText: 'Ghi chú'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('HỦY')),
          ElevatedButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final raw = MoneyUtils.parseCurrency(payCtrl.text);
              final amount = raw > 0 && raw < 100000 ? raw * 1000 : raw;
              Navigator.pop(ctx);
              await _confirmPay(amount, method, note);
            },
            child: const Text('XÁC NHẬN'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPay(int amount, String methodStr, String note) async {
    // Tìm debt có thể trả
    final activeDebts = _debts.where((d) => 
      (d['status'] ?? 'ACTIVE') == 'ACTIVE' && 
      ((d['totalAmount'] as int? ?? 0) - (d['paidAmount'] as int? ?? 0)) > 0
    ).toList();
    
    if (activeDebts.isEmpty) {
      NotificationService.showSnackBar('Không có công nợ cần thanh toán', color: Colors.orange);
      return;
    }
    
    // Lấy debt đầu tiên có thể trả
    final debt = activeDebts.first;
    final debtFId = debt['firestoreId'] as String? ?? 'debt_supplier_${widget.supplier.id}';
    
    // Convert payment method string to enum
    final method = methodStr == 'CHUYỂN KHOẢN' 
        ? PaymentMethod.transfer 
        : PaymentMethod.cash;
    
    // Execute payment directly without navigation
    final user = FirebaseAuth.instance.currentUser;
    final result = await PaymentIntentService.executePaymentDirect(
      type: PaymentIntentType.supplierDebt,
      amount: amount,
      paymentMethod: method,
      description: 'Trả nợ NCC: ${widget.supplier.name}',
      executedBy: user?.displayName ?? user?.email ?? 'unknown',
      referenceId: debtFId,
      referenceType: 'supplier_debt',
      personName: widget.supplier.name,
      personPhone: widget.supplier.phone,
      notes: note.isNotEmpty ? note : null,
      idempotencyKey: '${debtFId}_${DateTime.now().millisecondsSinceEpoch}',
      metadata: {
        'supplierId': widget.supplier.id,
        'supplierName': widget.supplier.name,
        'debtId': debt['id'],
        'debtFirestoreId': debtFId,
        'debtType': (debt['type'] ?? debt['debtType'] ?? 'SHOP_OWES').toString(),
        'suggestedMethod': methodStr,
      },
    );
    
    if (result.success) {
      if (mounted) {
        NotificationService.showSnackBar(
          'Đã thanh toán ${MoneyUtils.formatCurrency(amount)}đ!',
          color: Colors.green,
        );
        _load();
      }
    } else {
      if (mounted) {
        NotificationService.showSnackBar(
          result.errorMessage ?? 'Có lỗi xảy ra',
          color: Colors.red,
        );
      }
    }
  }
}
