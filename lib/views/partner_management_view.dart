import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../models/supplier_model.dart';
import '../models/repair_partner_model.dart';
import '../models/supplier_import_history_model.dart';
import '../models/supplier_product_prices_model.dart';
import '../models/supplier_payment_model.dart';
import '../models/repair_partner_payment_model.dart';
import '../services/supplier_service.dart';
import '../services/repair_partner_service.dart';
import '../services/supplier_payment_service.dart';
import '../services/repair_partner_payment_service.dart';
import '../services/user_service.dart';
import '../widgets/validated_text_field.dart';

class PartnerManagementView extends StatefulWidget {
  const PartnerManagementView({super.key});

  @override
  State<PartnerManagementView> createState() => _PartnerManagementViewState();
}

class _PartnerManagementViewState extends State<PartnerManagementView> with SingleTickerProviderStateMixin {
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

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Load repair partners
      final partnerService = RepairPartnerService();
      _repairPartners = await partnerService.getRepairPartners();

      // Load suppliers
      final supplierService = SupplierService();
      _suppliers = await supplierService.getSuppliers();

      // Load import history for partners (assuming partners can have import history)
      for (var partner in _repairPartners) {
        final history = await supplierService.getSupplierImportHistory(partner.id.toString());
        _partnerImportHistory.addAll(history);
      }

      // Load import history for suppliers
      for (var supplier in _suppliers) {
        final history = await supplierService.getSupplierImportHistory(supplier.id.toString());
        _supplierImportHistory.addAll(history);
        final prices = await supplierService.getSupplierProductPrices(supplier.id.toString());
        _supplierProductPrices.addAll(prices);
      }

      // Load payments
      final partnerPaymentService = RepairPartnerPaymentService();
      final supplierPaymentService = SupplierPaymentService();
      for (var partner in _repairPartners) {
        final payments = await partnerPaymentService.getPartnerPayments(partner.id!);
        _partnerPayments.addAll(payments);
      }
      for (var supplier in _suppliers) {
        final payments = await supplierPaymentService.getSupplierPayments(supplier.id!);
        _supplierPayments.addAll(payments);
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
      appBar: AppBar(
        title: const Text('QUẢN LÝ ĐỐI TÁC & NHÀ CUNG CẤP'),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: TextStyle(fontSize: 12),
          tabs: const [
            Tab(text: 'ĐỐI TÁC SỬA CHỮA'),
            Tab(text: 'NHÀ CUNG CẤP'),
          ],
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildRepairPartnersTab(),
              _buildSuppliersTab(),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        onPressed: _showAddDialog,
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
            labelStyle: TextStyle(fontSize: 12),
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
            labelStyle: TextStyle(fontSize: 12),
            tabs: [
              Tab(text: 'DANH SÁCH'),
              Tab(text: 'LỊCH SỬ NHẬP'),
              Tab(text: 'GIÁ SẢN PHẨM'),
              Tab(text: 'THANH TOÁN'),
              Tab(text: 'THỐNG KÊ'),
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
    return ListView.builder(
      itemCount: _repairPartners.length,
      itemBuilder: (ctx, i) {
        final partner = _repairPartners[i];
        return Card(
          child: ListTile(
            title: Text(partner.name, style: TextStyle(fontSize: 14)),
            subtitle: Text(partner.phone ?? 'Không có SĐT', style: TextStyle(fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditPartnerDialog(partner),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuppliersList() {
    return ListView.builder(
      itemCount: _suppliers.length,
      itemBuilder: (ctx, i) {
        final supplier = _suppliers[i];
        return Card(
          child: ListTile(
            title: Text(supplier.name, style: TextStyle(fontSize: 14)),
            subtitle: Text('${supplier.phone ?? ''} - ${supplier.email ?? ''}', style: TextStyle(fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditSupplierDialog(supplier),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPartnerImportHistory() {
    return ListView.builder(
      itemCount: _partnerImportHistory.length,
      itemBuilder: (ctx, i) {
        final history = _partnerImportHistory[i];
        return Card(
          child: ListTile(
            title: Text('Lô ${history.batchId}', style: TextStyle(fontSize: 14)),
            subtitle: Text('Tổng: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(history.totalCost)} - ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(history.createdAt))}', style: TextStyle(fontSize: 12)),
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
            title: Text('Lô ${history.batchId}', style: TextStyle(fontSize: 14)),
            subtitle: Text('Tổng: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(history.totalCost)} - ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(history.createdAt))}', style: TextStyle(fontSize: 12)),
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
            title: Text(price.productId, style: TextStyle(fontSize: 14)),
            subtitle: Text('Giá nhập: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(price.costPrice)} - Giá bán: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(price.sellingPrice)}', style: TextStyle(fontSize: 12)),
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
            title: Text('${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(payment.amount)} - ${payment.paymentMethod}', style: TextStyle(fontSize: 14)),
            subtitle: Text('${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(payment.paidAt))} - ${payment.note ?? ''}', style: TextStyle(fontSize: 12)),
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
            title: Text('${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(payment.amount)} - ${payment.paymentMethod}', style: TextStyle(fontSize: 14)),
            subtitle: Text('${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(payment.paidAt))} - ${payment.note ?? ''}', style: TextStyle(fontSize: 12)),
          ),
        );
      },
    );
  }

  Widget _buildPartnerStats() {
    final totalPaid = _partnerPayments.fold<int>(0, (sum, p) => sum + p.amount);
    final paymentStats = <String, int>{};
    for (var p in _partnerPayments) {
      paymentStats[p.paymentMethod] = (paymentStats[p.paymentMethod] ?? 0) + p.amount;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Tổng thanh toán: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalPaid)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: paymentStats.entries.map((e) => PieChartSectionData(
                  value: e.value.toDouble(),
                  title: '${e.key}\n${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(e.value)}',
                  color: Colors.primaries[paymentStats.keys.toList().indexOf(e.key) % Colors.primaries.length],
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierStats() {
    final totalPaid = _supplierPayments.fold<int>(0, (sum, p) => sum + p.amount);
    final paymentStats = <String, int>{};
    for (var p in _supplierPayments) {
      paymentStats[p.paymentMethod] = (paymentStats[p.paymentMethod] ?? 0) + p.amount;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Tổng thanh toán: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalPaid)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: paymentStats.entries.map((e) => PieChartSectionData(
                  value: e.value.toDouble(),
                  title: '${e.key}\n${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(e.value)}',
                  color: Colors.primaries[paymentStats.keys.toList().indexOf(e.key) % Colors.primaries.length],
                )).toList(),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValidatedTextField(controller: nameCtrl, label: 'Tên đối tác *'),
            ValidatedTextField(controller: phoneCtrl, label: 'Số điện thoại'),
            ValidatedTextField(controller: noteCtrl, label: 'Ghi chú'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValidatedTextField(controller: nameCtrl, label: 'Tên nhà cung cấp *'),
            ValidatedTextField(controller: phoneCtrl, label: 'Số điện thoại'),
            ValidatedTextField(controller: emailCtrl, label: 'Email'),
            ValidatedTextField(controller: addressCtrl, label: 'Địa chỉ'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final service = SupplierService();
              final supplier = Supplier(
                name: nameCtrl.text.trim().toUpperCase(),
                phone: phoneCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                address: addressCtrl.text.trim(),
                shopId: (await UserService.getCurrentShopId())!,
              );
              await service.addSupplier(supplier);
              _loadData();
              Navigator.pop(ctx);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  void _showEditPartnerDialog(RepairPartner partner) {
    // Similar to add, but pre-fill
  }

  void _showEditSupplierDialog(Supplier supplier) {
    // Similar to add, but pre-fill
  }
}