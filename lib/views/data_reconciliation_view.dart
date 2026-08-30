import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/db_helper.dart';
import '../models/debt_model.dart';
import '../models/product_model.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import '../services/data_reconciliation_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../utils/money_utils.dart';
import '../widgets/custom_app_bar.dart';

/// Công cụ điều chỉnh dữ liệu — dùng để dọn đơn sửa/đơn bán dư thừa
/// (dữ liệu test/nhập nhầm), miễn nợ, và chỉnh số lượng kho/linh kiện.
///
/// CHỈ chủ shop/quản lý (hasFullAccess) mới thấy mục này trong Cài đặt.
/// Đây là công cụ XÓA THẬT — mọi thao tác đều yêu cầu xác nhận mật khẩu.
class DataReconciliationView extends StatefulWidget {
  const DataReconciliationView({super.key});

  @override
  State<DataReconciliationView> createState() => _DataReconciliationViewState();
}

class _DataReconciliationViewState extends State<DataReconciliationView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final DBHelper _db = DBHelper();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: CustomAppBar.build(
        title: 'CÔNG CỤ ĐIỀU CHỈNH DỮ LIỆU',
        subtitle: 'Dọn đơn dư thừa • miễn nợ • sửa kho',
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'ĐƠN SỬA'),
            Tab(text: 'ĐƠN BÁN'),
            Tab(text: 'CÔNG NỢ'),
            Tab(text: 'KHO & SP'),
            Tab(text: 'TÀI CHÍNH'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.orange.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade800,
                  size: 18,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Xóa thật — dùng để dọn dữ liệu test/nhập nhầm. Mọi thao tác đều cần mật khẩu xác nhận.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _RepairTab(db: _db),
                _SaleTab(db: _db),
                _DebtTab(db: _db),
                _InventoryTab(db: _db),
                const _FinanceCleanupTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════ Shared helpers ═══════════════════════════

/// Yêu cầu nhập lại mật khẩu đăng nhập trước khi thực thi hành động nguy
/// hiểm. Trả về true nếu xác thực đúng.
Future<bool> _confirmPassword(BuildContext context) async {
  final passCtrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Xác nhận mật khẩu'),
      content: TextField(
        controller: passCtrl,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Nhập mật khẩu đăng nhập để xác nhận',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('HỦY'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('XÁC NHẬN', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  if (ok != true) return false;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.email == null) return false;
  try {
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: passCtrl.text,
    );
    await user.reauthenticateWithCredential(cred);
    return true;
  } catch (_) {
    if (context.mounted) {
      NotificationService.showSnackBar('❌ Mật khẩu sai', color: Colors.red);
    }
    return false;
  }
}

/// Hiện tóm tắt trước khi thực thi, trả về true nếu user bấm tiếp tục.
Future<bool> _confirmSummary(
  BuildContext context, {
  required String title,
  required List<String> lines,
  required bool withReversal,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...lines.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $l'),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: withReversal ? Colors.blue.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              withReversal
                  ? 'Sẽ tự động hoàn kho/xóa công nợ/bù trừ tài chính liên quan.'
                  : 'CHỈ xóa dữ liệu — công nợ/tài chính liên quan giữ nguyên như cũ.',
              style: const TextStyle(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thao tác này không thể hoàn tác.',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('HỦY'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('TIẾP TỤC', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  return ok == true;
}

Widget _emptyState(String text) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Text(text, style: TextStyle(color: Colors.grey.shade600)),
  ),
);

Widget _searchField(
  TextEditingController ctrl,
  String hint,
  VoidCallback onChanged,
) {
  return Padding(
    padding: const EdgeInsets.all(10),
    child: TextField(
      controller: ctrl,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
    ),
  );
}

// ═══════════════════════════════ TAB: ĐƠN SỬA ═══════════════════════════════

class _RepairTab extends StatefulWidget {
  const _RepairTab({required this.db});
  final DBHelper db;

  @override
  State<_RepairTab> createState() => _RepairTabState();
}

class _RepairTabState extends State<_RepairTab> {
  List<Repair> _all = [];
  List<Repair> _filtered = [];
  final Set<int> _selected = {};
  final _searchCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await widget.db.getAllRepairs();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() {
      _all = list;
      _filtered = list;
      _selected.clear();
      _loading = false;
    });
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all
                .where(
                  (r) =>
                      r.model.toLowerCase().contains(q) ||
                      r.customerName.toLowerCase().contains(q) ||
                      r.phone.contains(q),
                )
                .toList();
    });
  }

  List<Repair> get _selectedRepairs =>
      _all.where((r) => _selected.contains(r.id)).toList();

  Future<void> _execute(bool withReversal) async {
    if (_selected.isEmpty) return;
    final selected = _selectedRepairs;
    final proceed = await _confirmSummary(
      context,
      title: 'Xóa ${selected.length} đơn sửa',
      lines: [
        '${selected.length} đơn: ${selected.take(3).map((r) => r.model).join(", ")}${selected.length > 3 ? "..." : ""}',
      ],
      withReversal: withReversal,
    );
    if (!proceed) return;
    if (!await _confirmPassword(context)) return;

    int restored = 0, debts = 0;
    for (final r in selected) {
      final result = withReversal
          ? await DataReconciliationService.deleteRepairWithReversal(r)
          : await DataReconciliationService.deleteRepairKeepBooks(r);
      restored += result.inventoryRestored;
      debts += result.debtsRemoved;
    }
    if (!mounted) return;
    NotificationService.showSnackBar(
      '✅ Đã xóa ${selected.length} đơn'
      '${withReversal && restored > 0 ? " • Kho +$restored" : ""}'
      '${withReversal && debts > 0 ? " • Xóa $debts nợ" : ""}',
      color: Colors.green,
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        _searchField(_searchCtrl, 'Tìm theo model/khách/SĐT...', _filter),
        Expanded(
          child: _filtered.isEmpty
              ? _emptyState('Không có đơn sửa nào')
              : ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final r = _filtered[i];
                    return CheckboxListTile(
                      value: _selected.contains(r.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(r.id!);
                        } else {
                          _selected.remove(r.id);
                        }
                      }),
                      dense: true,
                      title: Text(
                        r.model,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '${r.customerName} • ${r.phone} • ${MoneyUtils.formatCurrency(r.price)}đ • '
                        '${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(r.createdAt))}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
        ),
        if (_selected.isNotEmpty)
          _ActionBar(
            count: _selected.length,
            onWithReversal: () => _execute(true),
            onKeepBooks: () => _execute(false),
          ),
      ],
    );
  }
}

// ═══════════════════════════════ TAB: ĐƠN BÁN ═══════════════════════════════

class _SaleTab extends StatefulWidget {
  const _SaleTab({required this.db});
  final DBHelper db;

  @override
  State<_SaleTab> createState() => _SaleTabState();
}

class _SaleTabState extends State<_SaleTab> {
  List<SaleOrder> _all = [];
  List<SaleOrder> _filtered = [];
  final Set<int> _selected = {};
  final _searchCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await widget.db.getAllSales();
    list.sort((a, b) => b.soldAt.compareTo(a.soldAt));
    setState(() {
      _all = list;
      _filtered = list;
      _selected.clear();
      _loading = false;
    });
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all
                .where(
                  (s) =>
                      s.productNamesDisplay.toLowerCase().contains(q) ||
                      s.customerName.toLowerCase().contains(q) ||
                      s.phone.contains(q),
                )
                .toList();
    });
  }

  List<SaleOrder> get _selectedSales =>
      _all.where((s) => _selected.contains(s.id)).toList();

  Future<void> _execute(bool withReversal) async {
    if (_selected.isEmpty) return;
    final selected = _selectedSales;
    final proceed = await _confirmSummary(
      context,
      title: 'Xóa ${selected.length} đơn bán',
      lines: [
        '${selected.length} đơn: ${selected.take(3).map((s) => s.productNamesDisplay).join(", ")}${selected.length > 3 ? "..." : ""}',
      ],
      withReversal: withReversal,
    );
    if (!proceed) return;
    if (!await _confirmPassword(context)) return;

    int restored = 0, debts = 0;
    for (final s in selected) {
      final result = withReversal
          ? await DataReconciliationService.deleteSaleWithReversal(s)
          : await DataReconciliationService.deleteSaleKeepBooks(s);
      restored += result.inventoryRestored;
      debts += result.debtsRemoved;
    }
    if (!mounted) return;
    NotificationService.showSnackBar(
      '✅ Đã xóa ${selected.length} đơn'
      '${withReversal && restored > 0 ? " • Kho +$restored" : ""}'
      '${withReversal && debts > 0 ? " • Xóa $debts nợ" : ""}',
      color: Colors.green,
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        _searchField(_searchCtrl, 'Tìm theo sản phẩm/khách/SĐT...', _filter),
        Expanded(
          child: _filtered.isEmpty
              ? _emptyState('Không có đơn bán nào')
              : ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final s = _filtered[i];
                    return CheckboxListTile(
                      value: _selected.contains(s.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(s.id!);
                        } else {
                          _selected.remove(s.id);
                        }
                      }),
                      dense: true,
                      title: Text(
                        s.productNamesDisplay,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${s.customerName} • ${s.phone} • ${MoneyUtils.formatCurrency(s.finalPrice)}đ • '
                        '${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(s.soldAt))}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
        ),
        if (_selected.isNotEmpty)
          _ActionBar(
            count: _selected.length,
            onWithReversal: () => _execute(true),
            onKeepBooks: () => _execute(false),
          ),
      ],
    );
  }
}

// ═══════════════════════════════ TAB: CÔNG NỢ ═══════════════════════════════

class _DebtTab extends StatefulWidget {
  const _DebtTab({required this.db});
  final DBHelper db;

  @override
  State<_DebtTab> createState() => _DebtTabState();
}

class _DebtTabState extends State<_DebtTab> {
  List<Debt> _all = [];
  List<Debt> _filtered = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await widget.db.getAllDebts();
    final list = raw.map((m) => Debt.fromMap(m)).toList();
    setState(() {
      _all = list;
      _filtered = list;
      _loading = false;
    });
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all
                .where(
                  (d) =>
                      d.personName.toLowerCase().contains(q) ||
                      d.phone.contains(q),
                )
                .toList();
    });
  }

  Future<void> _writeOff(Debt d) async {
    final reasonCtrl = TextEditingController();
    final remaining = d.totalAmount - d.paidAmount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Miễn nợ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${d.personName} — còn ${MoneyUtils.formatCurrency(remaining)}đ',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                autofocus: true,
                onChanged: (_) => setLocal(() {}),
                decoration: const InputDecoration(
                  hintText: 'Lý do miễn nợ (bắt buộc)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Không ghi nhận là đã thu tiền — chỉ đánh dấu xóa khoản nợ này.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('HỦY'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: reasonCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('MIỄN NỢ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || reasonCtrl.text.trim().isEmpty) return;
    if (!await _confirmPassword(context)) return;

    await DataReconciliationService.writeOffDebt(
      d.id!,
      reason: reasonCtrl.text.trim(),
      personName: d.personName,
    );
    if (!mounted) return;
    NotificationService.showSnackBar(
      '✅ Đã miễn nợ cho ${d.personName}',
      color: Colors.green,
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        _searchField(_searchCtrl, 'Tìm theo tên/SĐT...', _filter),
        Expanded(
          child: _filtered.isEmpty
              ? _emptyState('Không có công nợ nào')
              : ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final d = _filtered[i];
                    final remaining = d.totalAmount - d.paidAmount;
                    return ListTile(
                      dense: true,
                      title: Text(
                        d.personName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '${d.phone} • Còn ${MoneyUtils.formatCurrency(remaining)}đ • ${d.type}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: TextButton(
                        onPressed: () => _writeOff(d),
                        child: const Text('Miễn nợ'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════ TAB: KHO & SẢN PHẨM ═══════════════════════════════

class _InventoryTab extends StatefulWidget {
  const _InventoryTab({required this.db});
  final DBHelper db;

  @override
  State<_InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<_InventoryTab> {
  List<Map<String, dynamic>> _parts = [];
  List<Product> _products = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final parts = await widget.db.getAllParts();
    final products = await widget.db.getAllProducts();
    setState(() {
      _parts = parts;
      _products = products;
      _loading = false;
    });
  }

  Future<void> _adjustPart(Map<String, dynamic> part) async {
    final qtyCtrl = TextEditingController(text: '${part['quantity'] ?? 0}');
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sửa số lượng: ${part['partName']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số lượng mới',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Lý do điều chỉnh (bắt buộc)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('LƯU'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final newQty = int.tryParse(qtyCtrl.text.trim());
    if (newQty == null) {
      NotificationService.showSnackBar('Số lượng không hợp lệ', color: Colors.red);
      return;
    }
    if (reasonCtrl.text.trim().isEmpty) {
      NotificationService.showSnackBar(
        'Nhập lý do điều chỉnh (bắt buộc)',
        color: Colors.orange,
      );
      return;
    }
    if (!await _confirmPassword(context)) return;

    await DataReconciliationService.adjustPartQuantity(
      part['id'] as int,
      newQuantity: newQty,
      reason: reasonCtrl.text.trim(),
      partName: part['partName']?.toString() ?? '',
    );
    if (!mounted) return;
    NotificationService.showSnackBar(
      '✅ Đã cập nhật số lượng',
      color: Colors.green,
    );
    _load();
  }

  Future<void> _deletePart(Map<String, dynamic> part) async {
    final linkedDebts =
        await DataReconciliationService.countLinkedSupplierDebtsForPart(
          part['firestoreId']?.toString() ?? '',
        );
    if (!mounted) return;
    final proceed = await _confirmSummary(
      context,
      title: 'Xóa linh kiện: ${part['partName']}',
      lines: [
        if (linkedDebts > 0)
          '⚠️ Còn $linkedDebts công nợ NCC liên quan (KHÔNG bị xóa theo)',
        'Linh kiện sẽ ẩn khỏi kho, không xóa lịch sử đã dùng.',
      ],
      withReversal: false,
    );
    if (!proceed) return;
    if (!await _confirmPassword(context)) return;

    await DataReconciliationService.deletePart(
      part['id'] as int,
      partName: part['partName']?.toString() ?? '',
    );
    if (!mounted) return;
    NotificationService.showSnackBar('✅ Đã xóa linh kiện', color: Colors.green);
    _load();
  }

  Future<void> _adjustProduct(Product p) async {
    final qtyCtrl = TextEditingController(text: '${p.quantity}');
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sửa số lượng: ${p.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số lượng mới',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Lý do điều chỉnh (bắt buộc)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('LƯU'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final newQty = int.tryParse(qtyCtrl.text.trim());
    if (newQty == null) {
      NotificationService.showSnackBar('Số lượng không hợp lệ', color: Colors.red);
      return;
    }
    if (reasonCtrl.text.trim().isEmpty) {
      NotificationService.showSnackBar(
        'Nhập lý do điều chỉnh (bắt buộc)',
        color: Colors.orange,
      );
      return;
    }
    if (!await _confirmPassword(context)) return;

    await DataReconciliationService.adjustProductQuantity(
      p,
      newQuantity: newQty,
      reason: reasonCtrl.text.trim(),
    );
    if (!mounted) return;
    NotificationService.showSnackBar(
      '✅ Đã cập nhật số lượng',
      color: Colors.green,
    );
    _load();
  }

  Future<void> _deleteProduct(Product p) async {
    final proceed = await _confirmSummary(
      context,
      title: 'Xóa sản phẩm: ${p.name}',
      lines: const ['Sản phẩm sẽ ẩn khỏi kho, không xóa lịch sử đã bán.'],
      withReversal: false,
    );
    if (!proceed) return;
    if (!await _confirmPassword(context)) return;

    await DataReconciliationService.deleteProduct(p);
    if (!mounted) return;
    NotificationService.showSnackBar('✅ Đã xóa sản phẩm', color: Colors.green);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final q = _searchCtrl.text.trim().toLowerCase();
    final parts = q.isEmpty
        ? _parts
        : _parts
              .where(
                (p) =>
                    (p['partName']?.toString() ?? '').toLowerCase().contains(q),
              )
              .toList();
    final products = q.isEmpty
        ? _products
        : _products.where((p) => p.name.toLowerCase().contains(q)).toList();

    if (parts.isEmpty && products.isEmpty && q.isEmpty) {
      return Column(
        children: [
          _searchField(_searchCtrl, 'Tìm theo tên...', () => setState(() {})),
          Expanded(child: _emptyState('Không có linh kiện/sản phẩm nào')),
        ],
      );
    }

    return Column(
      children: [
        _searchField(_searchCtrl, 'Tìm theo tên...', () => setState(() {})),
        Expanded(
          child: ListView(
            children: [
              if (parts.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Text(
                    'LINH KIỆN',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
                ...parts.map(
                  (p) => ListTile(
                    dense: true,
                    title: Text(
                      p['partName']?.toString() ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      'SL: ${p['quantity'] ?? 0}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _adjustPart(p),
                          tooltip: 'Sửa số lượng',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: AppColors.error,
                          ),
                          onPressed: () => _deletePart(p),
                          tooltip: 'Xóa',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (products.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Text(
                    'SẢN PHẨM',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
                ...products.map(
                  (p) => ListTile(
                    dense: true,
                    title: Text(p.name, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      'SL: ${p.quantity}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _adjustProduct(p),
                          tooltip: 'Sửa số lượng',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: AppColors.error,
                          ),
                          onPressed: () => _deleteProduct(p),
                          tooltip: 'Xóa',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════ Shared action bar ═══════════════════════════════

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.count,
    required this.onWithReversal,
    required this.onKeepBooks,
  });

  final int count;
  final VoidCallback onWithReversal;
  final VoidCallback onKeepBooks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Đã chọn $count đơn',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onKeepBooks,
                    child: const Text(
                      'Xóa, giữ sổ sách',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                    ),
                    onPressed: onWithReversal,
                    child: const Text(
                      'Xóa, hoàn tài chính',
                      style: TextStyle(fontSize: 12.5, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════ TAB: DỌN DỮ LIỆU TÀI CHÍNH ═══════════════════════════

/// Phát hiện + sửa (có xác nhận) 2 loại dữ liệu hỏng đã xác định trong đợt
/// AUDIT: (1) phiếu `debt_payments` mồ côi (công nợ đã xóa, phiếu ở lại → vẫn
/// tính "tiền vào"); (2) công nợ KHÁCH `totalAmount = 0` trong khi đơn bán có
/// giá > 0 (khoản khách nợ "tàng hình"). KHÔNG tự chạy — từng dòng phải bấm.
class _FinanceCleanupTab extends StatefulWidget {
  const _FinanceCleanupTab();

  @override
  State<_FinanceCleanupTab> createState() => _FinanceCleanupTabState();
}

class _FinanceCleanupTabState extends State<_FinanceCleanupTab> {
  List<Map<String, dynamic>> _orphans = [];
  List<Map<String, dynamic>> _zeroDebts = [];
  List<Map<String, dynamic>> _orphanRetItems = [];
  List<Map<String, dynamic>> _foreignRetItems = [];
  List<Map<String, dynamic>> _orphanExpFal = [];
  List<Map<String, dynamic>> _stockMismatch = [];
  List<Map<String, dynamic>> _voidedIntents = [];
  List<Map<String, dynamic>> _misbookedVoids = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orphans = await DataReconciliationService.findOrphanDebtPayments();
    final zeros = await DataReconciliationService.findZeroAmountCustomerDebts();
    final orphanRet = await DataReconciliationService.findOrphanSalesReturnItems();
    final foreignRet =
        await DataReconciliationService.findForeignShopSalesReturnItems();
    final orphanExp = await DataReconciliationService.findOrphanExpenseActivity();
    final stockMis = await DataReconciliationService.findStockStatusMismatch();
    final voided =
        await DataReconciliationService.findVoidedTxnPaymentIntents();
    final misVoids = await DataReconciliationService.findMisbookedVoids();
    if (!mounted) return;
    setState(() {
      _orphans = orphans;
      _zeroDebts = zeros;
      _orphanRetItems = orphanRet;
      _foreignRetItems = foreignRet;
      _orphanExpFal = orphanExp;
      _stockMismatch = stockMis;
      _voidedIntents = voided;
      _misbookedVoids = misVoids;
      _loading = false;
    });
  }

  Future<void> _fixMisVoid(Map<String, dynamic> v) async {
    final diff = (v['diff'] as num?)?.toInt() ?? 0;
    final proceed = await _confirmSummary(
      context,
      title: 'Điều chỉnh biên độ VOID',
      lines: [
        '${v['title'] ?? ''} • ${v['referenceId'] ?? ''}',
        'VOID ghi ${MoneyUtils.formatCurrency(_mi(v, 'amount'))}đ nhưng thực thu '
            '${MoneyUtils.formatCurrency(_mi(v, 'receivedIn'))}đ → lệch '
            '${MoneyUtils.formatCurrency(diff)}đ.',
        'Ghi 1 dòng bù (${diff > 0 ? 'THU' : 'CHI'} ${MoneyUtils.formatCurrency(diff.abs())}đ) '
            'để net = 0. KHÔNG xóa dòng gốc.',
      ],
      withReversal: false,
    );
    if (proceed != true || !mounted || !await _confirmPassword(context)) return;
    await DataReconciliationService.fixMisbookedVoid(
      v,
      reason: 'Công cụ dọn dữ liệu tài chính (AUDIT D-3b)',
    );
    if (!mounted) return;
    NotificationService.showSnackBar('✅ Đã điều chỉnh biên độ VOID',
        color: Colors.green);
    _load();
  }

  int _mi(Map m, String k) => (m[k] as num?)?.toInt() ?? 0;

  Future<void> _cleanRetItem(Map<String, dynamic> it) async {
    final proceed = await _confirmSummary(
      context,
      title: 'Xóa item trả hàng mồ côi',
      lines: [
        '${it['productName'] ?? ''} • ${MoneyUtils.formatCurrency(_mi(it, 'amount'))}đ',
        'Phiếu trả hàng cha: ${it['salesReturnFirestoreId'] ?? '(trống)'} — KHÔNG còn tồn tại',
        'Soft-delete + đồng bộ. KHÔNG đụng tồn kho / tài chính (item mồ côi vốn '
            'đã không được tính vào báo cáo).',
      ],
      withReversal: false,
    );
    if (proceed != true || !mounted || !await _confirmPassword(context)) return;
    await DataReconciliationService.cleanOrphanSalesReturnItem(
      it,
      reason: 'Công cụ dọn dữ liệu tài chính (AUDIT D-2)',
    );
    if (!mounted) return;
    NotificationService.showSnackBar('✅ Đã xóa item mồ côi', color: Colors.green);
    _load();
  }

  Future<void> _removeForeign() async {
    final proceed = await _confirmSummary(
      context,
      title: 'Xóa item trả hàng của shop khác',
      lines: [
        'Có ${_foreignRetItems.length} item mang shopId của cửa hàng KHÁC lọt vào '
            'DB máy này (rác lúc đổi tài khoản).',
        'Xóa cứng khỏi máy này. KHÔNG ảnh hưởng cửa hàng kia (dữ liệu của họ vẫn '
            'trên cloud).',
      ],
      withReversal: false,
    );
    if (proceed != true || !mounted || !await _confirmPassword(context)) return;
    final n = await DataReconciliationService.removeForeignShopSalesReturnItems();
    if (!mounted) return;
    NotificationService.showSnackBar('✅ Đã xóa $n item của shop khác',
        color: Colors.green);
    _load();
  }

  Future<void> _reverseExpFal(Map<String, dynamic> f) async {
    final proceed = await _confirmSummary(
      context,
      title: 'Đảo khoản chi ma',
      lines: [
        '${f['title'] ?? ''} • ${MoneyUtils.formatCurrency(_mi(f, 'amount'))}đ',
        'Nhật ký tài chính có ghi CHI nhưng KHÔNG có phiếu chi tương ứng.',
        'Ghi 1 dòng bù (THU cùng số tiền) để net = 0 + hủy payment_intent liên '
            'quan. KHÔNG xóa dòng nhật ký gốc (append-only).',
      ],
      withReversal: false,
    );
    if (proceed != true || !mounted || !await _confirmPassword(context)) return;
    await DataReconciliationService.reverseOrphanExpenseActivity(
      f,
      reason: 'Công cụ dọn dữ liệu tài chính (AUDIT D-3)',
    );
    if (!mounted) return;
    NotificationService.showSnackBar('✅ Đã đảo khoản chi ma', color: Colors.green);
    _load();
  }

  Future<void> _cancelVoidedIntent(Map<String, dynamic> pi) async {
    final proceed = await _confirmSummary(
      context,
      title: 'Hủy payment_intent của giao dịch đã VOID',
      lines: [
        '${MoneyUtils.formatCurrency(_mi(pi, 'amount'))}đ • ${pi['type'] ?? ''}',
        'Giao dịch gốc (${pi['referenceId'] ?? ''}) đã bị VOID.',
        'Đổi status → CANCELLED. KHÔNG đụng tiền (engine không cộng '
            'payment_intents).',
      ],
      withReversal: false,
    );
    if (proceed != true || !mounted || !await _confirmPassword(context)) return;
    await DataReconciliationService.cancelVoidedTxnPaymentIntent(
      pi,
      reason: 'Công cụ dọn dữ liệu tài chính (AUDIT L-4)',
    );
    if (!mounted) return;
    NotificationService.showSnackBar('✅ Đã hủy intent', color: Colors.green);
    _load();
  }

  Future<void> _cleanOrphan(Map<String, dynamic> p) async {
    final amount = (p['amount'] as int?) ?? 0;
    final proceed = await _confirmSummary(
      context,
      title: 'Xóa phiếu thu/trả nợ mồ côi',
      lines: [
        'Số tiền: ${MoneyUtils.formatCurrency(amount)}đ',
        'Công nợ liên kết: ${p['debtFirestoreId'] ?? '(trống)'} — KHÔNG còn tồn tại',
        'Sẽ đánh dấu xóa phiếu này (soft-delete) + đồng bộ. Sổ quỹ / Tài chính '
            'sẽ hết cộng khoản này vào "tiền vào".',
      ],
      withReversal: false,
    );
    if (proceed != true) return;
    if (!mounted || !await _confirmPassword(context)) return;
    await DataReconciliationService.cleanOrphanDebtPayment(
      p,
      reason: 'Công cụ dọn dữ liệu tài chính (AUDIT)',
    );
    if (!mounted) return;
    NotificationService.showSnackBar('✅ Đã xóa phiếu mồ côi', color: Colors.green);
    _load();
  }

  Future<void> _fixZeroDebt(Map<String, dynamic> d) async {
    final suggested = (d['saleFinalPrice'] as int?) ?? 0;
    if (suggested <= 0) return;
    final proceed = await _confirmSummary(
      context,
      title: 'Đặt lại số tiền công nợ',
      lines: [
        'Khách: ${d['personName'] ?? ''}',
        'Hiện tại: totalAmount = 0 (khoản nợ tàng hình ở Nợ phải thu)',
        'Đặt về: ${MoneyUtils.formatCurrency(suggested)}đ (theo giá đơn bán liên kết)',
        'paidAmount giữ nguyên (${MoneyUtils.formatCurrency((d['paidAmount'] as int?) ?? 0)}đ).',
      ],
      withReversal: false,
    );
    if (proceed != true) return;
    if (!mounted || !await _confirmPassword(context)) return;
    await DataReconciliationService.fixZeroAmountDebt(
      d,
      suggested,
      reason: 'Công cụ dọn dữ liệu tài chính (AUDIT)',
    );
    if (!mounted) return;
    NotificationService.showSnackBar(
      '✅ Đã đặt lại công nợ ${d['personName']}',
      color: Colors.green,
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final nothing = _orphans.isEmpty &&
        _zeroDebts.isEmpty &&
        _orphanRetItems.isEmpty &&
        _foreignRetItems.isEmpty &&
        _orphanExpFal.isEmpty &&
        _stockMismatch.isEmpty &&
        _voidedIntents.isEmpty &&
        _misbookedVoids.isEmpty;
    if (nothing) {
      return _emptyState('Không phát hiện dữ liệu tài chính cần dọn 👍');
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_orphanRetItems.isNotEmpty) ...[
          _sectionHeader(
            'Item trả hàng mồ côi (${_orphanRetItems.length})',
            'Item không có phiếu trả hàng cha — rác dữ liệu (không tính vào báo cáo).',
          ),
          ..._orphanRetItems.map(
            (it) => ListTile(
              dense: true,
              leading: const Icon(Icons.link_off, color: Colors.red, size: 20),
              title: Text(
                '${it['productName'] ?? ''} • ${MoneyUtils.formatCurrency(_mi(it, 'amount'))}đ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                'Phiếu cha: ${it['salesReturnFirestoreId'] ?? '(trống)'}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: TextButton(
                onPressed: () => _cleanRetItem(it),
                child: const Text('Xóa'),
              ),
            ),
          ),
        ],
        if (_foreignRetItems.isNotEmpty) ...[
          _sectionHeader(
            'Item trả hàng của SHOP KHÁC (${_foreignRetItems.length})',
            'Bản ghi mang shopId cửa hàng khác lọt vào máy này (rác đổi tài khoản).',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_sweep, size: 18),
              label: Text('Xóa tất cả ${_foreignRetItems.length} item của shop khác'),
              onPressed: _removeForeign,
            ),
          ),
        ],
        if (_orphanExpFal.isNotEmpty) ...[
          _sectionHeader(
            'Khoản chi ma trong Nhật ký (${_orphanExpFal.length})',
            'Nhật ký tài chính ghi CHI nhưng không có phiếu chi tương ứng.',
          ),
          ..._orphanExpFal.map(
            (f) => ListTile(
              dense: true,
              leading: const Icon(Icons.report_gmailerrorred,
                  color: Colors.red, size: 20),
              title: Text(
                '${f['title'] ?? ''} • ${MoneyUtils.formatCurrency(_mi(f, 'amount'))}đ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                '${f['referenceId'] ?? ''}\n${_fmtTs(f['createdAt'])}',
                style: const TextStyle(fontSize: 11),
              ),
              isThreeLine: true,
              trailing: TextButton(
                onPressed: () => _reverseExpFal(f),
                child: const Text('Đảo'),
              ),
            ),
          ),
        ],
        if (_misbookedVoids.isNotEmpty) ...[
          _sectionHeader(
            'Bút toán VOID sai biên độ (${_misbookedVoids.length})',
            'SALE_VOID/REPAIR_VOID ghi số tiền khác phần thực thu → sổ đối soát lệch.',
          ),
          ..._misbookedVoids.map(
            (v) => ListTile(
              dense: true,
              leading: const Icon(Icons.rule, color: Colors.red, size: 20),
              title: Text(
                '${v['title'] ?? ''} • lệch ${MoneyUtils.formatCurrency(_mi(v, 'diff'))}đ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                'VOID ${MoneyUtils.formatCurrency(_mi(v, 'amount'))}đ • thực thu '
                '${MoneyUtils.formatCurrency(_mi(v, 'receivedIn'))}đ\n${v['referenceId'] ?? ''}',
                style: const TextStyle(fontSize: 11),
              ),
              isThreeLine: true,
              trailing: TextButton(
                onPressed: () => _fixMisVoid(v),
                child: const Text('Bù'),
              ),
            ),
          ),
        ],
        if (_voidedIntents.isNotEmpty) ...[
          _sectionHeader(
            'payment_intent của giao dịch đã VOID (${_voidedIntents.length})',
            'Intent còn COMPLETED/PENDING cho đơn/phiếu đã bị VOID.',
          ),
          ..._voidedIntents.map(
            (pi) => ListTile(
              dense: true,
              leading: const Icon(Icons.cancel_schedule_send,
                  color: Colors.orange, size: 20),
              title: Text(
                '${MoneyUtils.formatCurrency(_mi(pi, 'amount'))}đ • ${pi['type'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                '${pi['referenceId'] ?? ''} • ${pi['status'] ?? ''}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: TextButton(
                onPressed: () => _cancelVoidedIntent(pi),
                child: const Text('Hủy'),
              ),
            ),
          ),
        ],
        if (_stockMismatch.isNotEmpty) ...[
          _sectionHeader(
            'SKU cần kiểm kho thực tế (${_stockMismatch.length})',
            'status=0 (đã bán/ẩn) nhưng số lượng > 0. KHÔNG tự đổi số lượng — '
                'báo cáo VỐN TỒN KHO đã bỏ qua các SKU này.',
          ),
          ..._stockMismatch.map(
            (p) => ListTile(
              dense: true,
              leading: const Icon(Icons.inventory_2_outlined,
                  color: Colors.blueGrey, size: 20),
              title: Text(
                '${p['name'] ?? ''} • SL ${_mi(p, 'quantity')} • '
                '${MoneyUtils.formatCurrency(_mi(p, 'quantity') * _mi(p, 'cost'))}đ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                'IMEI ${p['imei'] ?? '(không)'} • status=${p['status']} — cần kiểm kho',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
        if (_orphans.isNotEmpty) ...[
          _sectionHeader(
            'Phiếu thu/trả nợ mồ côi (${_orphans.length})',
            'Công nợ đã xóa nhưng phiếu còn — vẫn bị tính là tiền vào.',
          ),
          ..._orphans.map(
            (p) => ListTile(
              dense: true,
              leading: const Icon(Icons.link_off, color: Colors.red, size: 20),
              title: Text(
                '${MoneyUtils.formatCurrency((p['amount'] as int?) ?? 0)}đ • ${p['paymentMethod'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                '${p['debtFirestoreId'] ?? '(trống)'}\n${_fmtTs(p['paidAt'])}',
                style: const TextStyle(fontSize: 11),
              ),
              isThreeLine: true,
              trailing: TextButton(
                onPressed: () => _cleanOrphan(p),
                child: const Text('Xóa'),
              ),
            ),
          ),
        ],
        if (_zeroDebts.isNotEmpty) ...[
          _sectionHeader(
            'Công nợ khách totalAmount = 0 (${_zeroDebts.length})',
            'Đơn bán có giá > 0 nhưng công nợ = 0 → tàng hình ở Nợ phải thu.',
          ),
          ..._zeroDebts.map(
            (d) => ListTile(
              dense: true,
              leading: const Icon(
                Icons.visibility_off,
                color: Colors.orange,
                size: 20,
              ),
              title: Text(
                '${d['personName'] ?? ''} — đặt về ${MoneyUtils.formatCurrency((d['saleFinalPrice'] as int?) ?? 0)}đ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                '${d['linkedId'] ?? ''}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: TextButton(
                onPressed: () => _fixZeroDebt(d),
                child: const Text('Sửa'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, String subtitle) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    ),
  );

  String _fmtTs(dynamic ts) {
    final ms = ts is int ? ts : int.tryParse('$ts') ?? 0;
    if (ms == 0) return '';
    return DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(DateTime.fromMillisecondsSinceEpoch(ms));
  }
}
