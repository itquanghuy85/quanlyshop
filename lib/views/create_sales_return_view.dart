import 'dart:convert';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../models/sale_order_model.dart';
import '../models/sales_return_model.dart';
import '../models/product_model.dart';
import '../data/db_helper.dart';
import '../services/sales_return_service.dart';
import '../services/notification_service.dart';
import '../utils/money_utils.dart';
import '../widgets/responsive_wrapper.dart';
import '../constants/product_constants.dart';

/// View to create a sales return from a specific sale order
class CreateSalesReturnView extends StatefulWidget {
  final SaleOrder sale;
  const CreateSalesReturnView({super.key, required this.sale});

  @override
  State<CreateSalesReturnView> createState() => _CreateSalesReturnViewState();
}

class _CreateSalesReturnViewState extends State<CreateSalesReturnView> {
  final _db = DBHelper();
  final _noteController = TextEditingController();
  late String _refundMethod;
  bool _isLoading = false;

  // Parsed items from sale
  List<_ReturnableItem> _items = [];
  String? _loadError;

  bool _loadingItems = true;

  @override
  void initState() {
    super.initState();
    // Nếu đơn gốc là công nợ (chưa thanh toán), mặc định giảm nợ (không chi tiền mặt)
    _refundMethod = widget.sale.paymentMethod == 'CÔNG NỢ' ? 'CÔNG NỢ' : 'TIỀN MẶT';
    _parseItems();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _parseItems() async {
    final snapshotItems = _decodeSnapshotItems(widget.sale.itemSnapshotsJson);
    if (snapshotItems.isEmpty) {
      if (mounted) {
        setState(() {
          _items = <_ReturnableItem>[];
          _loadError = 'Đơn bán này không có snapshot giá gốc từng sản phẩm. Không thể trả hàng an toàn.';
          _loadingItems = false;
        });
      }
      return;
    }

    if (snapshotItems.any((item) => !item.hasExactPricing)) {
      if (mounted) {
        setState(() {
          _items = <_ReturnableItem>[];
          _loadError = 'Đơn bán này không có giá item-level chính xác sau giảm giá. Không thể trả hàng an toàn.';
          _loadingItems = false;
        });
      }
      return;
    }

    final allItems = snapshotItems
        .map((item) => item.toReturnable())
        .toList(growable: true);

    for (final item in allItems) {
      Product? product;
      if (item.imei.isNotEmpty &&
          !item.imei.toUpperCase().startsWith('PKX') &&
          item.imei != 'NO_IMEI') {
        product = await _db.getProductByImei(item.imei);
      }
      product ??= await _db.getProductByName(item.name);
      product ??= await _db.getProductByNameFlexible(item.name);
      if (product != null) {
        item.productId = product.id;
        item.productFirestoreId = product.firestoreId;
      }
    }

    if (widget.sale.id != null && widget.sale.id! > 0) {
      final returnedMap = await _db.getReturnedQuantitiesForSale(widget.sale.id!);
      for (final item in allItems) {
        final isPhone = item.imei.isNotEmpty &&
            !item.imei.toUpperCase().startsWith('PKX') &&
            item.imei != 'NO_IMEI';
        final key = isPhone ? item.imei.toUpperCase() : item.name.toUpperCase();
        final alreadyReturned = returnedMap[key] ?? 0;
        item.maxQuantity = (item.maxQuantity - alreadyReturned).clamp(0, item.maxQuantity);
      }
      allItems.removeWhere((item) => item.maxQuantity <= 0);
    }

    if (mounted) {
      setState(() {
        _items = allItems;
        _loadError = null;
        _loadingItems = false;
      });
    }
  }

  List<_SaleItemSnapshot> _decodeSnapshotItems(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) {
      return const <_SaleItemSnapshot>[];
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return const <_SaleItemSnapshot>[];
      return decoded
          .whereType<Map>()
          .map((item) => _SaleItemSnapshot.fromMap(Map<String, dynamic>.from(item)))
          .where((item) => item.quantity > 0)
          .toList(growable: false);
    } catch (_) {
      return const <_SaleItemSnapshot>[];
    }
  }

  int get _totalRefund {
    int total = 0;
    for (final item in _items) {
      if (item.isSelected) {
        total += item.pricePerUnit * item.returnQuantity;
      }
    }
    return total;
  }

  bool get _hasSelection => _items.any((i) => i.isSelected && i.returnQuantity > 0);

  Future<void> _processReturn() async {
    if (_isLoading) {
      return;
    }
    if (!_hasSelection) {
      NotificationService.showSnackBar('Vui lòng chọn sản phẩm cần trả', color: AppColors.error);
      return;
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận trả hàng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Khách: ${widget.sale.customerName}'),
            const SizedBox(height: 8),
            ..._items.where((i) => i.isSelected && i.returnQuantity > 0).map((i) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${ProductConstants.cleanProductName(i.name)} x${i.returnQuantity} — ${MoneyUtils.formatCurrency(i.pricePerUnit * i.returnQuantity)}đ'),
              ),
            ),
            const Divider(),
            Text(
              'Hoàn lại: ${MoneyUtils.formatCurrency(_totalRefund)}đ',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
            ),
            Text('Phương thức: $_refundMethod'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xác nhận trả hàng'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    // Build return items
    final returnItems = <SalesReturnItem>[];
    for (final item in _items) {
      if (!item.isSelected || item.returnQuantity <= 0) continue;
      returnItems.add(SalesReturnItem(
        productId: item.productId,
        productFirestoreId: item.productFirestoreId,
        productName: item.name,
        productImei: item.imei.isNotEmpty ? item.imei : null,
        quantity: item.returnQuantity,
        price: item.pricePerUnit,
        cost: item.costPerUnit,
        amount: item.pricePerUnit * item.returnQuantity,
      ));
    }

    final result = await SalesReturnService.processReturn(
      salesOrderId: widget.sale.id ?? 0,
      salesOrderFirestoreId: widget.sale.firestoreId,
      customerName: widget.sale.customerName,
      customerPhone: widget.sale.phone,
      refundMethod: _refundMethod,
      items: returnItems,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success'] == true) {
      NotificationService.showSnackBar(
        'Trả hàng thành công! Hoàn ${MoneyUtils.formatCurrency(_totalRefund)}đ',
        color: AppColors.success,
      );
      Navigator.pop(context, true);
    } else {
      NotificationService.showSnackBar(
        'Lỗi: ${result['error']}',
        color: AppColors.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trả hàng'),
        backgroundColor: AppColors.error,
        foregroundColor: AppColors.surface,
      ),
      body: ResponsiveCenter(
        child: _isLoading || _loadingItems
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _loadError == null ? Icons.check_circle : Icons.error_outline,
                            size: 64,
                            color: _loadError == null ? AppColors.success : AppColors.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _loadError ?? 'Tất cả sản phẩm đã được trả hàng',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _loadError ?? 'Đơn hàng này không còn mặt hàng nào để trả.',
                            style: TextStyle(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Quay lại'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSaleInfo(),
                  const SizedBox(height: 16),
                  _buildItemSelection(),
                  const SizedBox(height: 16),
                  _buildRefundMethod(),
                  const SizedBox(height: 12),
                  _buildNoteField(),
                  const SizedBox(height: 16),
                  _buildSummary(),
                  const SizedBox(height: 20),
                  _buildSubmitButton(),
                  const SizedBox(height: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildSaleInfo() {
    final s = widget.sale;
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(s.soldAt),
    );
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text('Thông tin đơn gốc', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            const Divider(height: 16),
            _infoRow('Khách hàng', s.customerName),
            _infoRow('SĐT', s.phone),
            _infoRow('Ngày bán', dateStr),
            _infoRow('Tổng đơn', '${MoneyUtils.formatCurrency(s.finalPrice)}đ'),
            _infoRow('Thanh toán', s.paymentMethod),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 14))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildItemSelection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.warning),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_return, size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                const Text('Chọn sản phẩm trả', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            const Divider(height: 16),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('Không có sản phẩm nào')),
              )
            else
              ..._items.map((item) => _buildItemTile(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(_ReturnableItem item) {
    final isPhone = item.imei.isNotEmpty &&
        !item.imei.toUpperCase().startsWith('PKX') &&
        item.imei != 'NO_IMEI';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: item.isSelected ? AppColors.error : AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.isSelected ? AppColors.error : AppColors.outline,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: item.isSelected,
                activeColor: AppColors.error,
                onChanged: (val) {
                  setState(() {
                    item.isSelected = val ?? false;
                    if (item.isSelected && item.returnQuantity == 0) {
                      item.returnQuantity = isPhone ? 1 : 1;
                    }
                    if (!item.isSelected) item.returnQuantity = 0;
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ProductConstants.cleanProductName(item.name),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (isPhone)
                      Text('IMEI: ${item.imei}', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    Text(
                      '${MoneyUtils.formatCurrency(item.pricePerUnit)}đ/cái • Tối đa: ${item.maxQuantity}',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.isSelected && item.maxQuantity > 1)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 4),
              child: Row(
                children: [
                  const Text('Số lượng trả: ', style: TextStyle(fontSize: 14)),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 22),
                    onPressed: item.returnQuantity > 1
                        ? () => setState(() => item.returnQuantity--)
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      '${item.returnQuantity}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                    onPressed: item.returnQuantity < item.maxQuantity
                        ? () => setState(() => item.returnQuantity++)
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  Text('/ ${item.maxQuantity}', style: TextStyle(fontSize: 14, color: AppColors.textHint)),
                ],
              ),
            ),
          if (item.isSelected && item.returnQuantity > 0)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Hoàn: ${MoneyUtils.formatCurrency(item.pricePerUnit * item.returnQuantity)}đ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRefundMethod() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Phương thức hoàn tiền', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: ['TIỀN MẶT', 'CHUYỂN KHOẢN', 'CÔNG NỢ'].map((method) {
                final isActive = _refundMethod == method;
                return ChoiceChip(
                  label: Text(method, style: TextStyle(fontSize: 14, color: isActive ? AppColors.surface : null)),
                  selected: isActive,
                  selectedColor: AppColors.primary,
                  onSelected: (val) => setState(() => _refundMethod = method),
                );
              }).toList(),
            ),
            if (_refundMethod == 'CÔNG NỢ')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '⚠️ Giảm trực tiếp số nợ khách hàng, không chi tiền mặt',
                  style: TextStyle(fontSize: 14, color: AppColors.warning),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return TextField(
      controller: _noteController,
      decoration: InputDecoration(
        labelText: 'Ghi chú / Lý do trả hàng',
        hintText: 'Lỗi kỹ thuật, không ưng ý, sai sản phẩm...',
        prefixIcon: const Icon(Icons.note_alt_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      maxLines: 2,
    );
  }

  Widget _buildSummary() {
    return Card(
      elevation: 0,
      color: _hasSelection ? AppColors.error : AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _hasSelection ? AppColors.error : AppColors.outline,
          width: _hasSelection ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sản phẩm trả:', style: TextStyle(fontSize: 16)),
                Text(
                  '${_items.where((i) => i.isSelected && i.returnQuantity > 0).length} mục',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng hoàn lại:', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text(
                  '${MoneyUtils.formatCurrency(_totalRefund)}đ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _hasSelection ? AppColors.error : AppColors.textHint,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: (_hasSelection && !_isLoading) ? _processReturn : null,
        icon: const Icon(Icons.assignment_return),
        label: Text(_isLoading
            ? 'Đang xử lý...'
            : _hasSelection
            ? 'Xác nhận trả hàng — ${MoneyUtils.formatCurrency(_totalRefund)}đ'
            : 'Chọn sản phẩm để trả'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// Internal model for UI state
class _ReturnableItem {
  String name;
  String imei;
  int maxQuantity;
  int returnQuantity;
  bool isSelected;
  int pricePerUnit;
  int costPerUnit;
  int? productId;
  String? productFirestoreId;

  _ReturnableItem({
    required this.name,
    required this.imei,
    required this.maxQuantity,
    required this.returnQuantity,
    required this.isSelected,
    this.pricePerUnit = 0,
    this.costPerUnit = 0,
    this.productId,
    this.productFirestoreId,
  });
}

class _SaleItemSnapshot {
  final int? productId;
  final String? productFirestoreId;
  final String productName;
  final String productImei;
  final int quantity;
  final int unitPrice;
  final int unitCost;
  final bool hasExactPricing;

  const _SaleItemSnapshot({
    this.productId,
    this.productFirestoreId,
    required this.productName,
    required this.productImei,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    required this.hasExactPricing,
  });

  factory _SaleItemSnapshot.fromMap(Map<String, dynamic> map) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? 0;
    }

    return _SaleItemSnapshot(
      productId: map['productId'] is int ? map['productId'] as int : int.tryParse('${map['productId'] ?? ''}'),
      productFirestoreId: map['productFirestoreId']?.toString(),
      productName: (map['productName'] ?? '').toString().trim(),
      productImei: (map['productImei'] ?? '').toString().trim(),
      quantity: asInt(map['quantity']),
      unitPrice: asInt(map['unitPrice']),
      unitCost: asInt(map['unitCost']),
      hasExactPricing: map['exactPricing'] == true || map['exactPricing'] == 1,
    );
  }

  _ReturnableItem toReturnable() {
    return _ReturnableItem(
      name: productName,
      imei: productImei,
      maxQuantity: quantity,
      returnQuantity: 0,
      isSelected: false,
      pricePerUnit: unitPrice,
      costPerUnit: unitCost,
      productId: productId,
      productFirestoreId: productFirestoreId,
    );
  }
}
