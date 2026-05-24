import 'package:flutter/material.dart';
import '../widgets/responsive_wrapper.dart';
import '../widgets/custom_app_bar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/utils/money_utils.dart';
import '../data/db_helper.dart';
import '../models/supplier_model.dart';
import '../models/repair_partner_model.dart';
import '../models/supplier_import_history_model.dart';
import '../models/supplier_product_prices_model.dart';
import '../models/supplier_payment_model.dart';
import '../models/repair_partner_payment_model.dart';
import '../controllers/fast_inventory_input_controller.dart';
import '../services/event_bus.dart';
import '../services/supplier_service.dart';
import '../services/repair_partner_service.dart';
import '../services/repair_partner_payment_service.dart';
import '../services/user_service.dart';
import '../widgets/validated_text_field.dart';
import '../constants/partner_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../l10n/app_localizations.dart';
import 'repair_partner_detail_view.dart';
import 'supplier_detail_view.dart';

class PartnerManagementView extends StatefulWidget {
  const PartnerManagementView({super.key});

  @override
  State<PartnerManagementView> createState() => _PartnerManagementViewState();
}

class _PartnerManagementViewState extends State<PartnerManagementView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DBHelper _db = DBHelper();

  // Repair Partners
  List<RepairPartner> _repairPartners = [];
  List<SupplierImportHistory> _partnerImportHistory = [];
  List<RepairPartnerPayment> _partnerPayments = [];

  // Suppliers
  List<Supplier> _suppliers = [];
  List<SupplierImportHistory> _supplierImportHistory = [];
  List<SupplierProductPrices> _supplierProductPrices = [];
  List<SupplierPayment> _supplierPayments = [];
  List<Map<String, dynamic>> _supplierDebts = []; // Thêm debts cho suppliers

  bool _loading = true;
  bool _canViewCostPrice = false;
  String _partnerSearchQuery = '';
  String _supplierSearchQuery = '';
  String _partnerFilter = 'all';
  String _supplierFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _normalizePaymentMethod(String? raw) {
    final value = (raw ?? '').trim().toUpperCase();
    if (PartnerConstants.paymentMethods.contains(value)) return value;
    return value.isEmpty ? 'KHÁC' : value;
  }

  bool get _isSupplierTopTab => _tabController.index == 1;

  String _normalizeKey(String input) => input.trim().toUpperCase();

  bool _containsText(String source, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;
    return source.toLowerCase().contains(normalizedQuery);
  }

  int _remainingDebtByName(String personName) {
    final key = _normalizeKey(personName);
    int totalRemaining = 0;
    for (final debt in _supplierDebts) {
      final debtName = _normalizeKey((debt['personName'] ?? '').toString());
      if (debtName != key) continue;
      final total = (debt['totalAmount'] as num?)?.toInt() ?? 0;
      final paid = (debt['paidAmount'] as num?)?.toInt() ?? 0;
      totalRemaining += (total - paid);
    }
    return totalRemaining;
  }

  bool _hasDebtHistory(String personName) {
    final key = _normalizeKey(personName);
    return _supplierDebts.any(
      (debt) => _normalizeKey((debt['personName'] ?? '').toString()) == key,
    );
  }

  int _extractDueDateMs(Map<String, dynamic> debt) {
    const candidates = [
      'dueDate',
      'dueAt',
      'deadlineAt',
      'deadline',
      'paymentDueAt',
    ];
    for (final key in candidates) {
      final raw = debt[key];
      if (raw is num) return raw.toInt();
      if (raw is String) {
        final parsed = int.tryParse(raw.trim());
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  bool _isSupplierOverdue(String supplierName) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final key = _normalizeKey(supplierName);
    for (final debt in _supplierDebts) {
      final debtName = _normalizeKey((debt['personName'] ?? '').toString());
      if (debtName != key) continue;
      final total = (debt['totalAmount'] as num?)?.toInt() ?? 0;
      final paid = (debt['paidAmount'] as num?)?.toInt() ?? 0;
      final dueAt = _extractDueDateMs(debt);
      if ((total - paid) > 0 && dueAt > 0 && dueAt < now) {
        return true;
      }
    }
    return false;
  }

  int _latestSupplierTransactionMs(Supplier supplier) {
    final supplierId = supplier.id;
    int latestPaidAt = 0;
    int latestImportAt = 0;

    if (supplierId != null) {
      for (final payment in _supplierPayments) {
        if (payment.supplierId == supplierId && payment.paidAt > latestPaidAt) {
          latestPaidAt = payment.paidAt;
        }
      }
      for (final history in _supplierImportHistory) {
        if (history.supplierId == supplierId.toString() &&
            history.importDate > latestImportAt) {
          latestImportAt = history.importDate;
        }
      }
    }

    return latestPaidAt > latestImportAt ? latestPaidAt : latestImportAt;
  }

  List<RepairPartner> get _filteredRepairPartners {
    var data = _repairPartners.where((partner) {
      final q = _partnerSearchQuery;
      if (q.isEmpty) return true;
      return _containsText(partner.name, q) ||
          _containsText(partner.phone ?? '', q) ||
          _containsText(partner.note ?? '', q);
    }).toList();

    switch (_partnerFilter) {
      case 'active':
        data = data.where((p) => p.active).toList();
        break;
      case 'inactive':
        data = data.where((p) => !p.active).toList();
        break;
      case 'hasDebt':
        data = data.where((p) => _remainingDebtByName(p.name) > 0).toList();
        break;
      case 'byName':
        data.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      default:
        break;
    }

    return data;
  }

  List<Supplier> get _filteredSuppliers {
    var data = _suppliers.where((supplier) {
      final q = _supplierSearchQuery;
      if (q.isEmpty) return true;
      return _containsText(supplier.name, q) ||
          _containsText(supplier.phone ?? '', q) ||
          _containsText(supplier.email ?? '', q);
    }).toList();

    switch (_supplierFilter) {
      case 'hasDebt':
        data = data.where((s) => _remainingDebtByName(s.name) > 0).toList();
        break;
      case 'settled':
        data = data
            .where(
              (s) =>
                  _hasDebtHistory(s.name) && _remainingDebtByName(s.name) <= 0,
            )
            .toList();
        break;
      case 'overdue':
        data = data.where((s) => _isSupplierOverdue(s.name)).toList();
        break;
      case 'recent':
        data.sort(
          (a, b) => _latestSupplierTransactionMs(
            b,
          ).compareTo(_latestSupplierTransactionMs(a)),
        );
        break;
      default:
        break;
    }

    return data;
  }

  String get _activeFilterLabel {
    if (_isSupplierTopTab) {
      switch (_supplierFilter) {
        case 'hasDebt':
          return 'Còn nợ';
        case 'settled':
          return 'Đã tất toán';
        case 'overdue':
          return 'Quá hạn';
        case 'recent':
          return 'Giao dịch gần đây';
        default:
          return 'Tất cả';
      }
    }

    switch (_partnerFilter) {
      case 'active':
        return 'Hoạt động';
      case 'inactive':
        return 'Ngừng HĐ';
      case 'hasDebt':
        return 'Còn nợ';
      case 'byName':
        return 'Theo tên';
      default:
        return 'Tất cả';
    }
  }

  Future<void> _openTopBarSearchDialog() async {
    final isSupplier = _isSupplierTopTab;
    final controller = TextEditingController(
      text: isSupplier ? _supplierSearchQuery : _partnerSearchQuery,
    );

    final keyword = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isSupplier ? 'Tìm kiếm nhà cung cấp' : 'Tìm kiếm đối tác sửa chữa',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nhập tên, SĐT hoặc từ khóa...',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Xóa'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Áp dụng'),
          ),
        ],
      ),
    );

    if (keyword == null || !mounted) return;
    setState(() {
      if (isSupplier) {
        _supplierSearchQuery = keyword.trim();
      } else {
        _partnerSearchQuery = keyword.trim();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final perms = await UserService.getCurrentUserPermissions();
      _canViewCostPrice = perms['allowViewCostPrice'] ?? false;

      // Clear old data to avoid duplicate accumulation on refresh
      _repairPartners = [];
      _partnerImportHistory = [];
      _partnerPayments = [];
      _suppliers = [];
      _supplierImportHistory = [];
      _supplierProductPrices = [];
      _supplierPayments = [];
      _supplierDebts = [];

      // Load repair partners
      final partnerService = RepairPartnerService();
      _repairPartners = await partnerService.getRepairPartners();

      // Load suppliers
      final supplierService = SupplierService();
      _suppliers = await supplierService.getSuppliers();

      // Đối tác sửa chữa không có supplier_import_history riêng
      // Lịch sử công việc của đối tác được lưu trong repairs.services (JSON với partnerId)
      // Hiện tại để trống, cần implement riêng nếu muốn thống kê từ repairs
      _partnerImportHistory = [];

      // Load import history for suppliers - dùng Set để tránh duplicate
      final importIdSet = <int>{}; // Track IDs đã load
      for (var supplier in _suppliers) {
        // Truyền cả supplierName để tìm được cả các record lưu với supplierId = 0
        final history = await supplierService.getSupplierImportHistory(
          supplier.id.toString(),
          supplierName: supplier.name,
        );
        // Chỉ add nếu chưa có trong list (tránh duplicate khi 1 import khớp nhiều supplier)
        for (var h in history) {
          final historyId = h.id;
          if (historyId != null && !importIdSet.contains(historyId)) {
            importIdSet.add(historyId);
            _supplierImportHistory.add(h);
          } else if (historyId == null) {
            _supplierImportHistory.add(h); // Nếu không có ID, add anyway
          }
        }
        final prices = await supplierService.getSupplierProductPrices(
          supplier.id.toString(),
        );
        _supplierProductPrices.addAll(prices);
      }

      // Load debts for suppliers (SHOP_OWES type), filter deleted
      // PHẢI load trước khi load payments vì cần map từ debt -> payment
      final allDebts = await _db.getAllDebts();
      _supplierDebts = allDebts.where((debt) {
        final isDeleted = (debt['deleted'] ?? 0) == 1;
        return debt['type'] == 'SHOP_OWES' && !isDeleted;
      }).toList();

      // Load payments
      final partnerPaymentService = RepairPartnerPaymentService();
      for (var partner in _repairPartners) {
        final payments = await partnerPaymentService.getPartnerPayments(
          partner.id!,
        );
        _partnerPayments.addAll(payments);
      }

      // Load supplier payments từ debt_payments (thay vì supplier_payments)
      // Vì thanh toán NCC đều đi qua PaymentIntent -> debt_payments
      final allDebtPayments = await _db.getAllDebtPaymentsForSync();
      for (var supplier in _suppliers) {
        // Tìm các khoản thanh toán cho supplier này
        // debt_payments chứa debtFirestoreId liên kết với debt, mà debt có personName = supplier.name
        final supplierDebtIds = _supplierDebts
            .where(
              (d) =>
                  (d['personName'] ?? '').toString().toUpperCase() ==
                  supplier.name.toUpperCase(),
            )
            .map((d) => d['firestoreId'] as String?)
            .where((id) => id != null)
            .toSet();

        // Cũng tìm các debtId local
        final supplierDebtLocalIds = _supplierDebts
            .where(
              (d) =>
                  (d['personName'] ?? '').toString().toUpperCase() ==
                  supplier.name.toUpperCase(),
            )
            .map((d) => d['id'] as int?)
            .where((id) => id != null)
            .toSet();

        for (var dp in allDebtPayments) {
          final dpDebtFirestoreId = dp['debtFirestoreId'] as String?;
          final dpDebtId = dp['debtId'] as int?;

          if ((dpDebtFirestoreId != null &&
                  supplierDebtIds.contains(dpDebtFirestoreId)) ||
              (dpDebtId != null && supplierDebtLocalIds.contains(dpDebtId))) {
            final shopId = await UserService.getCurrentShopId() ?? '';
            _supplierPayments.add(
              SupplierPayment(
                id: dp['id'] as int?,
                firestoreId: dp['firestoreId'] as String?,
                supplierId: supplier.id!,
                shopId: shopId,
                amount: dp['amount'] as int? ?? 0,
                paymentMethod: dp['paymentMethod'] as String? ?? 'CASH',
                paidAt:
                    dp['paidAt'] as int? ??
                    DateTime.now().millisecondsSinceEpoch,
                note: dp['note'] as String?,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar.build(
        title: 'Quản lý đối tác & NCC',
        bottom: CustomTabBar.buildGradient(
          controller: _tabController,
          tabs: const [
            Tab(text: 'ĐỐI TÁC SỬA CHỮA'),
            Tab(text: 'NHÀ CUNG CẤP'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _isSupplierTopTab
                ? 'Tìm kiếm nhà cung cấp'
                : 'Tìm kiếm đối tác sửa chữa',
            onPressed: _openTopBarSearchDialog,
            icon: const Icon(Icons.search),
          ),
          PopupMenuButton<String>(
            tooltip: 'Lọc: $_activeFilterLabel',
            onSelected: (value) {
              setState(() {
                if (_isSupplierTopTab) {
                  _supplierFilter = value;
                } else {
                  _partnerFilter = value;
                }
              });
            },
            itemBuilder: (_) {
              if (_isSupplierTopTab) {
                return const [
                  PopupMenuItem(value: 'all', child: Text('Tất cả')),
                  PopupMenuItem(value: 'hasDebt', child: Text('Còn nợ')),
                  PopupMenuItem(value: 'settled', child: Text('Đã tất toán')),
                  PopupMenuItem(value: 'overdue', child: Text('Quá hạn')),
                  PopupMenuItem(
                    value: 'recent',
                    child: Text('Giao dịch gần đây'),
                  ),
                ];
              }

              return const [
                PopupMenuItem(value: 'all', child: Text('Tất cả')),
                PopupMenuItem(value: 'active', child: Text('Hoạt động')),
                PopupMenuItem(value: 'inactive', child: Text('Ngừng HĐ')),
                PopupMenuItem(value: 'hasDebt', child: Text('Còn nợ')),
                PopupMenuItem(value: 'byName', child: Text('Theo tên')),
              ];
            },
            icon: const Icon(Icons.filter_alt_outlined),
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [_buildRepairPartnersTab(), _buildSuppliersTab()],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRepairPartnersTab() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            labelStyle: TextStyle(fontSize: AppTextStyles.h4),
            tabs: [
              Tab(text: 'DANH SÁCH'),
              Tab(text: 'LỊCH SỬ NHẬP'),
              Tab(text: 'THANH TOÁN'),
              Tab(text: 'THỐNG KÊ'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPartnersList(),
                _buildPartnerImportHistory(),
                _buildPartnerPayments(),
                _buildPartnerStats(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuppliersTab() {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const TabBar(
            labelStyle: TextStyle(fontSize: AppTextStyles.h4),
            tabs: [
              Tab(text: 'D/SÁCH'),
              Tab(text: 'L/ SỬ NHẬP'),
              Tab(text: 'GIÁ S/PHẨM'),
              Tab(text: 'T/TOÁN'),
              Tab(text: 'T KÊ'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSuppliersList(),
                _buildSupplierImportHistory(),
                _buildSupplierProductPrices(),
                _buildSupplierPayments(),
                _buildSupplierStats(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnersList() {
    final filteredPartners = _filteredRepairPartners;
    if (filteredPartners.isEmpty) {
      return Center(
        child: Text(
          'Không có đối tác phù hợp bộ lọc',
          style: AppTextStyles.body1.copyWith(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredPartners.length,
      itemBuilder: (ctx, i) {
        final partner = filteredPartners[i];
        return Card(
          child: ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RepairPartnerDetailView(partner: partner),
              ),
            ).then((_) => _loadData()),
            title: Text(partner.name, style: AppTextStyles.headline2),
            subtitle: Text(
              partner.phone ?? 'Không có SĐT',
              style: AppTextStyles.body1,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _verifyAndEditPartner(partner),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _verifyAndDeletePartner(partner),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuppliersList() {
    final filteredSuppliers = _filteredSuppliers;
    if (filteredSuppliers.isEmpty) {
      return Center(
        child: Text(
          'Không có nhà cung cấp phù hợp bộ lọc',
          style: AppTextStyles.body1.copyWith(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredSuppliers.length,
      itemBuilder: (ctx, i) {
        final supplier = filteredSuppliers[i];
        return Card(
          child: ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SupplierDetailView(supplier: supplier),
              ),
            ).then((_) => _loadData()),
            title: Text(supplier.name, style: AppTextStyles.headline2),
            subtitle: Text(
              '${supplier.phone ?? ''} - ${supplier.email ?? ''}',
              style: AppTextStyles.body1,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _verifyAndEditSupplier(supplier),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _verifyAndDeleteSupplier(supplier),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPartnerImportHistory() {
    if (_partnerImportHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Chưa có lịch sử công việc',
                style: AppTextStyles.headline1.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                'Lịch sử công việc gửi đối tác sẽ hiển thị từ các đơn sửa chữa',
                style: AppTextStyles.body1.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: _partnerImportHistory.length,
      itemBuilder: (ctx, i) {
        final history = _partnerImportHistory[i];
        return Card(
          child: ListTile(
            title: Text(
              'Lô ${history.batchId}',
              style: AppTextStyles.headline2,
            ),
            subtitle: _canViewCostPrice
                ? Text(
                    'Tổng: ${MoneyUtils.formatVND(history.totalCost.toInt())}₫ - ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(history.createdAt))}',
                    style: AppTextStyles.body1,
                  )
                : Text(
                    DateFormat('dd/MM/yyyy').format(
                      DateTime.fromMillisecondsSinceEpoch(history.createdAt),
                    ),
                    style: AppTextStyles.body1,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildSupplierImportHistory() {
    return ListView.builder(
      itemCount: _supplierImportHistory.length,
      itemBuilder: (ctx, i) {
        final history = _supplierImportHistory[i];
        return Card(
          child: ListTile(
            title: Text(
              'Lô ${history.batchId}',
              style: AppTextStyles.headline2,
            ),
            subtitle: _canViewCostPrice
                ? Text(
                    'Tổng: ${MoneyUtils.formatVND(history.totalCost.toInt())}₫ - ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(history.createdAt))}',
                    style: AppTextStyles.body1,
                  )
                : Text(
                    DateFormat('dd/MM/yyyy').format(
                      DateTime.fromMillisecondsSinceEpoch(history.createdAt),
                    ),
                    style: AppTextStyles.body1,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildSupplierProductPrices() {
    return ListView.builder(
      itemCount: _supplierProductPrices.length,
      itemBuilder: (ctx, i) {
        final price = _supplierProductPrices[i];
        return Card(
          child: ListTile(
            title: Text(price.productId, style: AppTextStyles.headline2),
            subtitle: _canViewCostPrice
                ? Text(
                    'Giá nhập: ${MoneyUtils.formatVND(price.costPrice.toInt())}₫ - Giá bán: ${MoneyUtils.formatVND(price.sellingPrice.toInt())}₫',
                    style: AppTextStyles.body1,
                  )
                : Text(
                    'Giá bán: ${MoneyUtils.formatVND(price.sellingPrice.toInt())}₫',
                    style: AppTextStyles.body1,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildPartnerPayments() {
    return ListView.builder(
      itemCount: _partnerPayments.length,
      itemBuilder: (ctx, i) {
        final payment = _partnerPayments[i];
        return Card(
          child: ListTile(
            title: Text(
              '${MoneyUtils.formatVND(payment.amount)}₫ - ${payment.paymentMethod}',
              style: AppTextStyles.headline2,
            ),
            subtitle: Text(
              '${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(payment.paidAt))} - ${payment.note ?? ''}',
              style: AppTextStyles.body1,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSupplierPayments() {
    return ListView.builder(
      itemCount: _supplierPayments.length,
      itemBuilder: (ctx, i) {
        final payment = _supplierPayments[i];
        return Card(
          child: ListTile(
            title: Text(
              '${MoneyUtils.formatVND(payment.amount)}₫ - ${payment.paymentMethod}',
              style: AppTextStyles.headline2,
            ),
            subtitle: Text(
              '${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(payment.paidAt))} - ${payment.note ?? ''}',
              style: AppTextStyles.body1,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPartnerStats() {
    final totalPaid = _partnerPayments.fold<int>(0, (sum, p) => sum + p.amount);
    final paymentStats = <String, int>{};
    for (var p in _partnerPayments) {
      final method = _normalizePaymentMethod(p.paymentMethod);
      paymentStats[method] = (paymentStats[method] ?? 0) + p.amount;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Tổng thanh toán: ${MoneyUtils.formatVND(totalPaid)}₫',
            style: AppTextStyles.headline1.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: paymentStats.entries
                    .map(
                      (e) => PieChartSectionData(
                        value: e.value.toDouble(),
                        title: '${e.key}\n${MoneyUtils.formatVND(e.value)}₫',
                        color:
                            Colors.primaries[paymentStats.keys.toList().indexOf(
                                  e.key,
                                ) %
                                Colors.primaries.length],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierStats() {
    final totalPaid = _supplierPayments.fold<int>(
      0,
      (sum, p) => sum + p.amount,
    );

    // Tính tổng công nợ cho suppliers
    final supplierDebtStats = <String, Map<String, dynamic>>{};
    for (var supplier in _suppliers) {
      final supplierDebts = _supplierDebts
          .where((debt) => debt['personName'] == supplier.name)
          .toList();

      int totalOwed = 0;
      for (var debt in supplierDebts) {
        final int total = debt['totalAmount'] ?? 0;
        final int paid = debt['paidAmount'] ?? 0;
        totalOwed += (total - paid);
      }

      if (totalOwed > 0 || supplierDebts.isNotEmpty) {
        supplierDebtStats[supplier.name] = {
          'totalOwed': totalOwed,
          'debtCount': supplierDebts.length,
        };
      }
    }

    final totalOwedAll = supplierDebtStats.values.fold<int>(
      0,
      (sum, stat) => sum + (stat['totalOwed'] as int),
    );

    final paymentStats = <String, int>{};
    for (var p in _supplierPayments) {
      final method = _normalizePaymentMethod(p.paymentMethod);
      paymentStats[method] = (paymentStats[method] ?? 0) + p.amount;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tổng quan thanh toán
          Text(
            '💰 TỔNG THANH TOÁN: ${MoneyUtils.formatVND(totalPaid)}₫',
            style: AppTextStyles.headline1.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),

          const SizedBox(height: 16),

          // Tổng quan công nợ
          Text(
            '💸 TỔNG CÔNG NỢ: ${MoneyUtils.formatVND(totalOwedAll)}₫',
            style: AppTextStyles.headline1.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),

          const SizedBox(height: 20),

          // Chi tiết công nợ theo supplier
          if (supplierDebtStats.isNotEmpty) ...[
            Text(
              '📋 CHI TIẾT CÔNG NỢ THEO NCC:',
              style: AppTextStyles.headline1.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...supplierDebtStats.entries.map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${MoneyUtils.formatVND(entry.value['totalOwed'])}₫ (${entry.value['debtCount']} khoản)',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Biểu đồ thanh toán
          Text(
            '📊 THỐNG KÊ THANH TOÁN:',
            style: AppTextStyles.headline1.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: paymentStats.isEmpty
                ? const Center(child: Text('Chưa có dữ liệu thanh toán'))
                : PieChart(
                    PieChartData(
                      sections: paymentStats.entries
                          .map(
                            (e) => PieChartSectionData(
                              value: e.value.toDouble(),
                              title:
                                  '${e.key}\n${MoneyUtils.formatVND(e.value)}₫',
                              color:
                                  Colors.primaries[paymentStats.keys
                                          .toList()
                                          .indexOf(e.key) %
                                      Colors.primaries.length],
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    if (_tabController.index == 0) {
      _showAddPartnerDialog();
    } else {
      _showAddSupplierDialog();
    }
  }

  void _showAddPartnerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm đối tác sửa chữa'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValidatedTextField(
                controller: nameCtrl,
                label: 'Tên đối tác *',
                required: true,
              ),
              ValidatedTextField(controller: phoneCtrl, label: 'Số điện thoại'),
              ValidatedTextField(controller: noteCtrl, label: 'Ghi chú'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập tên đối tác')),
                );
                return;
              }
              if (phoneCtrl.text.trim().isNotEmpty) {
                final phoneError = UserService.validatePhone(
                  phoneCtrl.text.trim(),
                  AppLocalizations.of(ctx)!,
                );
                if (phoneError != null) {
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(SnackBar(content: Text(phoneError)));
                  return;
                }
              }
              final service = RepairPartnerService();
              final partner = RepairPartner(
                name: nameCtrl.text.trim().toUpperCase(),
                phone: phoneCtrl.text.trim(),
                note: noteCtrl.text.trim(),
                shopId: (await UserService.getCurrentShopId())!,
              );
              await service.addRepairPartner(partner);
              _loadData();
              Navigator.pop(ctx);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  void _showAddSupplierDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm nhà cung cấp'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValidatedTextField(
                controller: nameCtrl,
                label: 'Tên nhà cung cấp *',
                required: true,
              ),
              ValidatedTextField(controller: phoneCtrl, label: 'Số điện thoại'),
              ValidatedTextField(controller: emailCtrl, label: 'Email'),
              ValidatedTextField(controller: addressCtrl, label: 'Địa chỉ'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập tên nhà cung cấp'),
                  ),
                );
                return;
              }

              try {
                if (phoneCtrl.text.trim().isNotEmpty) {
                  final phoneError = UserService.validatePhone(
                    phoneCtrl.text.trim(),
                    AppLocalizations.of(ctx)!,
                  );
                  if (phoneError != null) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(phoneError)));
                    return;
                  }
                }

                final service = SupplierService();
                final supplier = Supplier(
                  name: nameCtrl.text.trim().toUpperCase(),
                  phone: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  shopId: (await UserService.getCurrentShopId())!,
                );

                final result = await service.addSupplier(supplier);
                if (result != null) {
                  // Clear supplier cache in other controllers
                  FastInventoryInputController().clearSupplierCache();
                  // Send event to refresh other views
                  EventBus().emit('suppliers_changed');
                  await _loadData();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Đã thêm nhà cung cấp thành công'),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Lỗi: Không thể thêm nhà cung cấp'),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error adding supplier: $e');
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  // ============ PASSWORD VERIFICATION ============
  Future<String?> _showPasswordDialog(String action) async {
    String password = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xác nhận $action'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Chỉ chủ shop được phép thực hiện.\nNhập mật khẩu tài khoản để xác nhận:',
            ),
            const SizedBox(height: 10),
            TextField(
              obscureText: true,
              onChanged: (value) => password = value,
              decoration: const InputDecoration(
                hintText: 'Mật khẩu',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, password),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Future<bool> _verifyOwnerPassword(String action) async {
    final password = await _showPasswordDialog(action);
    if (password == null || password.isEmpty) return false;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập lại')));
      return false;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: password,
      );
      await currentUser.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Mật khẩu không đúng!')));
      }
      return false;
    }
  }

  // ============ VERIFY AND EDIT/DELETE PARTNER ============
  Future<void> _verifyAndEditPartner(RepairPartner partner) async {
    if (await _verifyOwnerPassword('chỉnh sửa đối tác')) {
      _showEditPartnerDialog(partner);
    }
  }

  Future<void> _verifyAndDeletePartner(RepairPartner partner) async {
    if (await _verifyOwnerPassword('xóa đối tác')) {
      _confirmDeletePartner(partner);
    }
  }

  // ============ VERIFY AND EDIT/DELETE SUPPLIER ============
  Future<void> _verifyAndEditSupplier(Supplier supplier) async {
    if (await _verifyOwnerPassword('chỉnh sửa nhà cung cấp')) {
      _showEditSupplierDialog(supplier);
    }
  }

  Future<void> _verifyAndDeleteSupplier(Supplier supplier) async {
    if (await _verifyOwnerPassword('xóa nhà cung cấp')) {
      _confirmDeleteSupplier(supplier);
    }
  }

  void _showEditPartnerDialog(RepairPartner partner) {
    final nameCtrl = TextEditingController(text: partner.name);
    final phoneCtrl = TextEditingController(text: partner.phone ?? '');
    final noteCtrl = TextEditingController(text: partner.note ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Chỉnh sửa đối tác sửa chữa')),
            // Nút xóa đối tác
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              tooltip: 'Xóa đối tác',
              onPressed: () {
                Navigator.pop(ctx);
                _confirmDeletePartner(partner);
              },
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValidatedTextField(
                controller: nameCtrl,
                label: 'Tên đối tác *',
                required: true,
              ),
              ValidatedTextField(controller: phoneCtrl, label: 'Số điện thoại'),
              ValidatedTextField(controller: noteCtrl, label: 'Ghi chú'),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _confirmDeletePartner(partner);
                },
                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                label: const Text('Xóa', style: TextStyle(color: Colors.red)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Vui lòng nhập tên đối tác')),
                    );
                    return;
                  }
                  if (phoneCtrl.text.trim().isNotEmpty) {
                    final phoneError = UserService.validatePhone(
                      phoneCtrl.text.trim(),
                      AppLocalizations.of(ctx)!,
                    );
                    if (phoneError != null) {
                      ScaffoldMessenger.of(
                        ctx,
                      ).showSnackBar(SnackBar(content: Text(phoneError)));
                      return;
                    }
                  }

                  final service = RepairPartnerService();
                  final updated = partner.copyWith(
                    name: nameCtrl.text.trim().toUpperCase(),
                    phone: phoneCtrl.text.trim(),
                    note: noteCtrl.text.trim(),
                  );
                  await service.updateRepairPartner(updated);
                  await _loadData();
                  if (mounted) Navigator.pop(ctx);
                },
                child: const Text('Lưu'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditSupplierDialog(Supplier supplier) {
    final nameCtrl = TextEditingController(text: supplier.name);
    final phoneCtrl = TextEditingController(text: supplier.phone ?? '');
    final emailCtrl = TextEditingController(text: supplier.email ?? '');
    final addressCtrl = TextEditingController(text: supplier.address ?? '');
    final noteCtrl = TextEditingController(text: supplier.note ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Chỉnh sửa nhà cung cấp')),
            // Nút xóa nhà cung cấp
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              tooltip: 'Xóa nhà cung cấp',
              onPressed: () {
                Navigator.pop(ctx);
                _confirmDeleteSupplier(supplier);
              },
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValidatedTextField(
                controller: nameCtrl,
                label: 'Tên nhà cung cấp *',
                required: true,
              ),
              ValidatedTextField(controller: phoneCtrl, label: 'Số điện thoại'),
              ValidatedTextField(controller: emailCtrl, label: 'Email'),
              ValidatedTextField(controller: addressCtrl, label: 'Địa chỉ'),
              ValidatedTextField(controller: noteCtrl, label: 'Ghi chú'),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _confirmDeleteSupplier(supplier);
                },
                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                label: const Text('Xóa', style: TextStyle(color: Colors.red)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng nhập tên nhà cung cấp'),
                      ),
                    );
                    return;
                  }
                  if (phoneCtrl.text.trim().isNotEmpty) {
                    final phoneError = UserService.validatePhone(
                      phoneCtrl.text.trim(),
                      AppLocalizations.of(ctx)!,
                    );
                    if (phoneError != null) {
                      ScaffoldMessenger.of(
                        ctx,
                      ).showSnackBar(SnackBar(content: Text(phoneError)));
                      return;
                    }
                  }

                  final service = SupplierService();
                  final updated = supplier.copyWith(
                    name: nameCtrl.text.trim().toUpperCase(),
                    phone: phoneCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    note: noteCtrl.text.trim(),
                  );
                  await service.updateSupplier(updated);
                  await _loadData();
                  if (mounted) Navigator.pop(ctx);
                },
                child: const Text('Lưu'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeletePartner(RepairPartner partner) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa đối tác "${partner.name}"?\n\nLưu ý: Dữ liệu liên quan có thể bị ảnh hưởng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final service = RepairPartnerService();
                // Truyền firestoreId để xóa cả local và cloud
                final success = await service.deleteRepairPartner(
                  partner.id!,
                  firestoreId: partner.firestoreId,
                );
                if (success) {
                  EventBus().emit('repair_partners_changed');
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã xóa đối tác thành công'),
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lỗi: Không thể xóa đối tác'),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                }
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSupplier(Supplier supplier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa nhà cung cấp "${supplier.name}"?\n\nLưu ý: Dữ liệu liên quan có thể bị ảnh hưởng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final service = SupplierService();
                // Truyền firestoreId để xóa cả local và cloud
                final success = await service.deleteSupplier(
                  supplier.id,
                  firestoreId: supplier.firestoreId,
                  supplierName: supplier.name,
                );
                if (success) {
                  FastInventoryInputController().clearSupplierCache();
                  EventBus().emit('suppliers_changed');
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã xóa nhà cung cấp thành công'),
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lỗi: Không thể xóa nhà cung cấp'),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                }
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
