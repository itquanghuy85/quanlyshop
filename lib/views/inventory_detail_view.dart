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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết sản phẩm'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: double.infinity,
                height: 180,
                child: _buildImage(imagePath),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              product.name,
              style: AppTextStyles.headline3.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _row('IMEI/Serial', (product.imei ?? '').trim().isEmpty ? '--' : product.imei!),
            _row('SKU', (product.sku ?? '').trim().isEmpty ? '--' : product.sku!),
            _row('Thương hiệu', product.brand.trim().isEmpty ? '--' : product.brand),
            _row('Model', (product.model ?? '').trim().isEmpty ? '--' : product.model!),
            _row('Số lượng', product.quantity.toString()),
            _row('Giá bán', MoneyUtils.formatCurrency(product.price)),
            _row('Giá vốn', MoneyUtils.formatCurrency(product.cost)),
            _row('Nhà cung cấp', (product.supplier ?? '').trim().isEmpty ? '--' : product.supplier!),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSold ? AppColors.warning : AppColors.success,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSold ? AppColors.warning : AppColors.success,
                ),
              ),
              child: Text(
                isSold ? 'Trạng thái: Đã bán' : 'Trạng thái: Còn hàng',
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSold ? AppColors.warning : AppColors.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String imagePath) {
    if (imagePath.isEmpty) {
      return Container(
        color: AppColors.outline,
        child: const Icon(Icons.image_not_supported, size: 44),
      );
    }

    if (imagePath.startsWith('http://') ||
        imagePath.startsWith('https://') ||
        imagePath.startsWith('gs://')) {
      return AppCachedImage(
        imageUrl: imagePath,
        fit: BoxFit.cover,
      );
    }

    if (!kIsWeb) {
      final localFile = File(imagePath);
      if (localFile.existsSync()) {
        return Image.file(localFile, fit: BoxFit.cover);
      }
    }

    return Container(
      color: AppColors.outline,
      child: const Icon(Icons.image_not_supported, size: 44),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
              style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
