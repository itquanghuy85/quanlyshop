import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../models/supplier_model.dart';
import '../services/event_bus.dart';
import '../services/sync_orchestrator.dart';
import '../theme/app_colors.dart';
import '../models/product_model.dart';
import '../theme/app_text_styles.dart';
import '../utils/money_utils.dart';
import '../widgets/app_cached_image.dart';
import '../widgets/currency_text_field.dart';
import '../widgets/custom_app_bar.dart';
import 'supplier_detail_view.dart';

class InventoryDetailView extends StatefulWidget {
  final Product product;
  final int? soldQty;
  final int? soldPrice;
  final int? salePrice;
  final String? soldImei;

  const InventoryDetailView({
    super.key,
    required this.product,
    this.soldQty,
    this.soldPrice,
    this.salePrice,
    this.soldImei,
  });

  @override
  State<InventoryDetailView> createState() => _InventoryDetailViewState();
}

class _InventoryDetailViewState extends State<InventoryDetailView> {
  late Product _product;
  final _db = DBHelper();

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  Future<void> _openSupplier(String name) async {
    if (name.trim().isEmpty || name == '--') return;
    final row = await _db.getSupplierByName(name);
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

  Future<void> _editCostDialog() async {
    final ctrl = TextEditingController(
      text: CurrencyTextField.formatDisplay(_product.cost),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa giá vốn'),
        content: CurrencyTextField(
          controller: ctrl,
          label: 'Giá vốn',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    CurrencyTextField.finalizeAll();
    final newCost = CurrencyTextField.parseValue(ctrl.text);
    if (newCost == _product.cost) return;

    _product.cost = newCost;
    _product.isSynced = false;
    await _db.updateProduct(_product);

    if (_product.id != null) {
      await SyncOrchestrator().enqueue(
        entityType: SyncEntityType.product,
        entityId: _product.id!,
        firestoreId: _product.firestoreId,
        operation: SyncOperation.update,
        data: _product.toMap(),
      );
    }
    EventBus().emit('products_changed');

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật giá vốn: ${MoneyUtils.formatCurrency(newCost)} đ'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    // Ưu tiên ảnh local (vừa chọn, chưa/lỗi upload lên cloud) giống hệt cách
    // list sản phẩm hiển thị — trước đây màn này chỉ đọc `images` (URL cloud)
    // nên ảnh mới chọn không hiện cho tới khi upload nền xong.
    final localImagePath = (product.localImagePath ?? '').trim();
    final imagePath = localImagePath.isNotEmpty
        ? localImagePath
        : (product.images ?? '')
            .split(',')
            .map((e) => e.trim())
            .firstWhere((e) => e.isNotEmpty, orElse: () => '');
    final isSold = product.status == 0 || product.quantity <= 0;
    final isOutOfStock = product.status != 0 && product.quantity <= 0;
    final hasImage = imagePath.isNotEmpty;
    final hasLocation = (product.locationCode ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: CustomAppBar.build(
        title: 'Chi tiết sản phẩm',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: double.infinity,
                height: hasImage ? 200 : 110,
                child: _buildImage(imagePath, hasImage),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              product.name,
              style: AppTextStyles.headline3.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSold
                    ? (isOutOfStock ? Colors.orange.shade50 : Colors.red.shade50)
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSold
                      ? (isOutOfStock ? Colors.orange.shade300 : Colors.red.shade300)
                      : Colors.green.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSold
                        ? (isOutOfStock ? Icons.inventory_2_outlined : Icons.sell_outlined)
                        : Icons.check_circle_outline,
                    size: 14,
                    color: isSold
                        ? (isOutOfStock ? Colors.orange.shade700 : Colors.red.shade700)
                        : Colors.green.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isSold ? (isOutOfStock ? 'Hết hàng' : 'Đã bán') : 'Còn hàng',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isSold
                          ? (isOutOfStock ? Colors.orange.shade700 : Colors.red.shade700)
                          : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (hasLocation) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF1D4ED8)),
                    const SizedBox(width: 6),
                    Text(
                      [product.locationCode, product.locationName]
                          .where((v) => v != null && v.isNotEmpty)
                          .join(' · '),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.location_off_outlined, size: 15, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Chưa cập nhật vị trí',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            _sectionTitle('THÔNG TIN SẢN PHẨM', Icons.info_outline_rounded),
            _sectionCard([
              _row('IMEI/Serial', (product.imei ?? '').trim().isEmpty ? '--' : product.imei!),
              _divider(),
              _row('SKU', (product.sku ?? '').trim().isEmpty ? '--' : product.sku!),
              _divider(),
              _row('Thương hiệu', product.brand.trim().isEmpty ? '--' : product.brand),
              _divider(),
              _row('Model', (product.model ?? '').trim().isEmpty ? '--' : product.model!),
              _divider(),
              _row('Tồn kho', product.quantity.toString()),
            ]),
            const SizedBox(height: 16),
            _sectionTitle('GIÁ & LỢI NHUẬN', Icons.payments_outlined),
            _sectionCard([
              if (widget.soldQty != null) ...[
                _row(
                  'Bán trong đơn này',
                  '${widget.soldQty} cái',
                  valueColor: Colors.blue.shade700,
                ),
                _divider(),
              ],
              if (widget.soldImei != null && widget.soldImei!.isNotEmpty) ...[
                _row(
                  'IMEI đã bán',
                  widget.soldImei!,
                  valueColor: Colors.deepPurple.shade600,
                ),
                _divider(),
              ],
              Builder(builder: (ctx) {
                final basePrice = widget.salePrice ?? product.price;
                final sp = widget.soldPrice;
                final hasDiscount = sp != null && sp > 0 && basePrice > sp;
                final discount = hasDiscount ? basePrice - sp : 0;
                // Giá thực nhận về khi tính lợi nhuận: giá đã bán trong đơn
                // (nếu có) — không thì lấy giá bán niêm yết hiện tại (lợi
                // nhuận dự kiến, chưa chắc chắn cho tới khi bán thật).
                final realizedPrice = (sp != null && sp > 0) ? sp : basePrice;
                final profit = realizedPrice - product.cost;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row(
                      hasDiscount ? 'Giá bán gốc' : 'Giá bán',
                      MoneyUtils.formatCompactCurrency(basePrice),
                      valueColor: Colors.green.shade700,
                    ),
                    if (hasDiscount) ...[
                      _divider(),
                      _row(
                        'Đã giảm',
                        '-${MoneyUtils.formatCompactCurrency(discount)}',
                        valueColor: Colors.orange.shade700,
                      ),
                      _divider(),
                      _row(
                        'Giá bán trong đơn',
                        MoneyUtils.formatCompactCurrency(sp),
                        valueColor: Colors.indigo.shade600,
                      ),
                    ] else if (sp != null && sp > 0 && sp != product.price) ...[
                      _divider(),
                      _row(
                        'Giá bán trong đơn',
                        MoneyUtils.formatCompactCurrency(sp),
                        valueColor: Colors.indigo.shade600,
                      ),
                    ],
                    _divider(),
                    _costRow(product.cost),
                    _divider(),
                    _row(
                      widget.soldPrice != null ? 'Lợi nhuận' : 'Lợi nhuận dự kiến',
                      '${profit >= 0 ? '+' : ''}${MoneyUtils.formatCompactCurrency(profit)}',
                      valueColor: profit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ],
                );
              }),
            ]),
            const SizedBox(height: 16),
            _sectionTitle('NHẬP HÀNG', Icons.local_shipping_outlined),
            _sectionCard([
              _supplierRow(product.supplier ?? ''),
              _divider(),
              _row('Thanh toán', _paymentMethodLabel(product.paymentMethod)),
              _divider(),
              _importDateRow(product),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  // Row giá vốn có nút sửa nhanh
  Widget _costRow(int cost) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              'Giá vốn',
              style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              MoneyUtils.formatCompactCurrency(cost),
              style: AppTextStyles.body1.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade700,
              ),
              textAlign: TextAlign.end,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _editCostDialog,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Icon(Icons.edit_outlined, size: 14, color: Colors.orange.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String imagePath, bool hasImage) {
    if (!hasImage) {
      return Container(
        color: const Color(0xFFF0F4FF),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_android_rounded, size: 40, color: Colors.blueGrey.shade300),
            const SizedBox(height: 6),
            Text(
              'Chưa có ảnh sản phẩm',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400),
            ),
          ],
        ),
      );
    }
    if (imagePath.startsWith('http://') ||
        imagePath.startsWith('https://') ||
        imagePath.startsWith('gs://')) {
      return AppCachedImage(imageUrl: imagePath, fit: BoxFit.cover);
    }
    if (!kIsWeb) {
      final localFile = File(imagePath);
      if (localFile.existsSync()) return Image.file(localFile, fit: BoxFit.cover);
    }
    return Container(
      color: const Color(0xFFF0F4FF),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 36, color: Colors.blueGrey.shade300),
          const SizedBox(height: 6),
          Text('Không tải được ảnh',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400)),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body1.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _supplierRow(String supplierName) {
    final display = supplierName.trim().isEmpty ? '--' : supplierName.trim();
    final tappable = display != '--';
    return InkWell(
      onTap: tappable ? () => _openSupplier(display) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                'Nhà cung cấp',
                style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    display,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tappable ? const Color(0xFF4F46E5) : null,
                      decoration: tappable ? TextDecoration.underline : null,
                      decorationColor: const Color(0xFF4F46E5),
                    ),
                    textAlign: TextAlign.end,
                  ),
                  if (tappable) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF4F46E5)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);

  String _paymentMethodLabel(String? method) {
    switch (method) {
      case 'CÔNG NỢ':
        return 'Công nợ';
      case 'CHUYỂN KHOẢN':
        return 'Chuyển khoản';
      case 'TIỀN MẶT':
        return 'Tiền mặt';
      default:
        return '--';
    }
  }

  // Ngày giờ sản phẩm được nhập vào kho (product.createdAt).
  // Với hàng gộp số lượng qua nhiều lần nhập (phụ kiện/linh kiện không IMEI),
  // đây chỉ là mốc lần nhập đầu tiên — các lần nhập bổ sung sau không có
  // dấu vết riêng trong dữ liệu hiện tại.
  Widget _importDateRow(Product product) {
    final formatted = DateFormat(
      'HH:mm dd/MM/yyyy',
    ).format(DateTime.fromMillisecondsSinceEpoch(product.createdAt));
    final isAccumulated = (product.imei ?? '').trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              'Ngày nhập kho',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatted,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isAccumulated)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '(lần nhập đầu tiên, có thể đã nhập bổ sung sau đó)',
                      textAlign: TextAlign.end,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
