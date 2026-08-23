import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../models/import_order_model.dart';
import '../models/supplier_model.dart';
import '../services/import_order_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/correct_supplier_payment_dialog.dart';
import '../utils/money_utils.dart';
import 'supplier_detail_view.dart';

class ImportOrderDetailView extends StatefulWidget {
  final ImportOrder order;
  const ImportOrderDetailView({super.key, required this.order});

  @override
  State<ImportOrderDetailView> createState() => _ImportOrderDetailViewState();
}

class _ImportOrderDetailViewState extends State<ImportOrderDetailView> {
  late ImportOrder _order;
  List<ImportOrderItem> _items = [];
  bool _isLoading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _loadItems();
  }

  Future<void> _loadItems() async {
    if (_order.firestoreId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final items = await ImportOrderService.getImportOrderItems(
        _order.firestoreId!,
      );
      if (mounted) setState(() => _items = items);
    } catch (e) {
      debugPrint('Error loading import order items: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editSupplierAndPayment() async {
    final stockEntryId = _order.stockEntryId;
    if (stockEntryId == null || stockEntryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phiếu này thiếu liên kết phiếu nhập kho gốc, không thể sửa')),
      );
      return;
    }

    setState(() => _saving = true);
    final result = await showCorrectSupplierPaymentSheet(
      context: context,
      entryId: stockEntryId,
      currentSupplierName: _order.supplierName ?? '',
      currentPaymentMethod: _order.paymentMethod ?? '',
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result != null) {
        _order = _order.copyWith(
          supplierId: result['supplierId'] as String?,
          supplierName: result['supplierName'] as String?,
          paymentMethod: result['paymentMethod'] as String?,
          paymentStatus: result['paymentStatus'] as String?,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final date = order.importDate != null
        ? DateTime.fromMillisecondsSinceEpoch(order.importDate!)
        : null;
    final isDebt = order.paymentStatus == 'DEBT';

    return Scaffold(
      appBar: CustomAppBar.build(
        title: order.orderCode,
        actions: [
          if (order.status == 'CONFIRMED')
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.edit_outlined),
              tooltip: 'Sửa NCC / thanh toán',
              onPressed: _saving ? null : _editSupplierAndPayment,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order info card
                  _buildInfoCard(order, date, isDebt),
                  const SizedBox(height: 16),
                  // Items header
                  Row(
                    children: [
                      const Icon(
                        Icons.list_alt,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Chi tiết sản phẩm (${_items.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Items list
                  if (_items.isEmpty)
                    _buildEmptyItems()
                  else
                    ..._items.asMap().entries.map(
                      (entry) => _buildItemCard(entry.key + 1, entry.value),
                    ),
                  const SizedBox(height: 16),
                  // Total row
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TỔNG CỘNG',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          MoneyUtils.formatCurrency(order.totalAmount),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(ImportOrder order, DateTime? date, bool isDebt) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDebt
                    ? [
                        AppColors.warning.withAlpha(20),
                        AppColors.warning.withAlpha(8),
                      ]
                    : [
                        AppColors.success.withAlpha(20),
                        AppColors.success.withAlpha(8),
                      ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDebt
                        ? AppColors.warning.withAlpha(30)
                        : AppColors.success.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDebt ? Icons.warning_amber : Icons.check_circle,
                    color: isDebt ? AppColors.warning : AppColors.success,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDebt ? 'CÔNG NỢ' : 'ĐÃ THANH TOÁN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDebt
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                      if (date != null)
                        Text(
                          DateFormat('HH:mm - dd/MM/yyyy').format(date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${order.totalQuantity} SP',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          // Info rows
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _supplierInfoRow(order.supplierName ?? ''),
                const SizedBox(height: 8),
                _infoRow(
                  Icons.payments,
                  'Thanh toán',
                  _paymentMethodLabel(order.paymentMethod),
                ),
                if (order.importedBy != null && order.importedBy!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow(Icons.person, 'Người nhập', order.importedBy!),
                ],
                if (order.notes != null && order.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow(Icons.notes, 'Ghi chú', order.notes!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Future<void> _openSupplierByName(String name) async {
    if (name.trim().isEmpty) return;
    final row = await DBHelper().getSupplierByName(name);
    if (!mounted) return;
    if (row != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SupplierDetailView(supplier: Supplier.fromMap(row)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tìm thấy nhà cung cấp "$name"')),
      );
    }
  }

  Widget _supplierInfoRow(String supplierName) {
    final display = supplierName.trim().isEmpty ? 'Không rõ' : supplierName.trim();
    final tappable = supplierName.trim().isNotEmpty;
    return InkWell(
      onTap: tappable ? () => _openSupplierByName(display) : null,
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: [
          Icon(Icons.store, size: 16,
              color: tappable ? const Color(0xFF4F46E5) : Colors.grey.shade500),
          const SizedBox(width: 8),
          Text('NCC: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Flexible(
            child: Text(
              display,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: tappable ? const Color(0xFF4F46E5) : null,
                decoration: tappable ? TextDecoration.underline : null,
                decorationColor: const Color(0xFF4F46E5),
              ),
            ),
          ),
          if (tappable)
            const Icon(Icons.chevron_right_rounded, size: 15, color: Color(0xFF4F46E5)),
        ],
      ),
    );
  }

  Widget _buildEmptyItems() {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Text(
        'Không có dữ liệu chi tiết',
        style: TextStyle(color: Colors.grey.shade400),
      ),
    );
  }

  Widget _buildItemCard(int index, ImportOrderItem item) {
    final typeColor = _typeColor(item.productType);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Index
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: typeColor.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$index',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: typeColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.typeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: typeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Details row
                  Row(
                    children: [
                      if (item.productBrand != null &&
                          item.productBrand!.isNotEmpty)
                        _detailChip(item.productBrand!),
                      if (item.imei != null && item.imei!.isNotEmpty)
                        _detailChip('IMEI: ${item.imei}'),
                      if (item.color != null && item.color!.isNotEmpty)
                        _detailChip(item.color!),
                      if (item.size != null && item.size!.isNotEmpty)
                        _detailChip(item.size!),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Price row
                  Row(
                    children: [
                      Text(
                        'SL: ${item.quantity}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '×',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        MoneyUtils.formatCurrency(item.costPrice),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        MoneyUtils.formatCurrency(item.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'DIEN_THOAI':
        return Colors.blue;
      case 'PHU_KIEN':
        return Colors.teal;
      case 'LINH_KIEN':
        return Colors.orange;
      case 'QUAN_AO':
        return Colors.purple;
      case 'GIAY_DEP':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  String _paymentMethodLabel(String? method) {
    switch (method) {
      case 'CÔNG NỢ':
        return 'Công nợ';
      case 'CHUYỂN KHOẢN':
        return 'Chuyển khoản';
      case 'TIỀN MẶT':
        return 'Tiền mặt';
      default:
        return method ?? 'Không rõ';
    }
  }
}
