import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

import '../models/product_model.dart';
import '../theme/app_text_styles.dart';
import '../utils/money_utils.dart';
import '../widgets/app_cached_image.dart';

class InventoryDetailView extends StatelessWidget {
  final Product product;

  const InventoryDetailView({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final imagePath = (product.images ?? '')
        .split(',')
        .map((e) => e.trim())
        .firstWhere((e) => e.isNotEmpty, orElse: () => '');
    final isSold = product.status == 0;
    final hasImage = imagePath.isNotEmpty;
    final hasLocation = (product.locationCode ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Chi tiết sản phẩm'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area — compact with phone placeholder when empty
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: double.infinity,
                height: hasImage ? 200 : 110,
                child: _buildImage(imagePath, hasImage),
              ),
            ),
            const SizedBox(height: 14),

            // Product name
            Text(
              product.name,
              style: AppTextStyles.headline3.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSold
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSold ? Colors.red.shade300 : Colors.green.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSold ? Icons.sell_outlined : Icons.check_circle_outline,
                    size: 14,
                    color: isSold ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isSold ? 'Đã bán' : 'Còn hàng',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isSold ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Storage location badge
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

            // Info card
            Container(
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
              child: Column(
                children: [
                  _row('IMEI/Serial', (product.imei ?? '').trim().isEmpty ? '--' : product.imei!),
                  _divider(),
                  _row('SKU', (product.sku ?? '').trim().isEmpty ? '--' : product.sku!),
                  _divider(),
                  _row('Thương hiệu', product.brand.trim().isEmpty ? '--' : product.brand),
                  _divider(),
                  _row('Model', (product.model ?? '').trim().isEmpty ? '--' : product.model!),
                  _divider(),
                  _row('Số lượng', product.quantity.toString()),
                  _divider(),
                  _row('Giá bán', MoneyUtils.formatCurrency(product.price),
                      valueColor: Colors.green.shade700),
                  _divider(),
                  _row('Giá vốn', MoneyUtils.formatCurrency(product.cost),
                      valueColor: Colors.orange.shade700),
                  _divider(),
                  _row('Nhà cung cấp',
                      (product.supplier ?? '').trim().isEmpty ? '--' : product.supplier!),
                ],
              ),
            ),
          ],
        ),
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
      if (localFile.existsSync()) {
        return Image.file(localFile, fit: BoxFit.cover);
      }
    }

    return Container(
      color: const Color(0xFFF0F4FF),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 36, color: Colors.blueGrey.shade300),
          const SizedBox(height: 6),
          Text('Không tải được ảnh', style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400)),
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

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);
}
