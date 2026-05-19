import 'package:flutter/foundation.dart';

import '../data/db_helper.dart';
import '../models/product_model.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';
import '../widgets/image_picker_widget.dart';

/// Manages product image lifecycle: local storage → Firebase Storage upload.
///
/// Usage:
///   1. User picks image → save localPath to product, show pending indicator.
///   2. Call [uploadAndSaveToProduct] in background.
///   3. On success the product record in local DB is updated automatically.
class ProductImageService {
  /// Upload a locally-compressed image for a product.
  /// Returns the Firebase Storage URL on success, null on failure.
  static Future<String?> uploadProductImage({
    required String localPath,
    required String shopId,
    required String productFirestoreId,
  }) async {
    try {
      final storagePath = 'uploads/products/$shopId/$productFirestoreId/main.jpg';
      return await StorageService.uploadAndGetUrl(localPath, storagePath);
    } catch (e) {
      debugPrint('ProductImageService.uploadProductImage error: $e');
      return null;
    }
  }

  /// Upload product image and update the product record in local DB.
  /// Returns the cloud URL or null if failed.
  static Future<String?> uploadAndSaveToProduct({
    required Product product,
    required String localPath,
  }) async {
    final shopId =
        product.shopId ?? await UserService.getCurrentShopId() ?? 'unknown';
    final productId =
        product.firestoreId ?? 'prod_${product.createdAt}_${product.name}';

    // Compress before upload
    String uploadPath = localPath;
    final compressed = await ImagePickerWidget.compressImage(localPath);
    if (compressed != null) uploadPath = compressed;

    final url = await uploadProductImage(
      localPath: uploadPath,
      shopId: shopId,
      productFirestoreId: productId,
    );

    if (url != null && product.id != null) {
      final db = DBHelper();
      final now = DateTime.now().millisecondsSinceEpoch;
      final updated = product.copyWith(
        images: url,
        localImagePath: null,
        imageUpdatedAt: now,
        updatedAt: now,
        isSynced: false,
      );
      await db.upsertProduct(updated);
    }

    return url;
  }

  /// Retry all products with pending local images (localImagePath set, images empty).
  static Future<void> retryPendingProductImages(String shopId) async {
    try {
      final db = DBHelper();
      final underlying = await db.database;
      final rows = await underlying.rawQuery(
        'SELECT * FROM products WHERE shopId = ? AND localImagePath IS NOT NULL AND localImagePath != "" AND (images IS NULL OR images = "") AND (deleted = 0 OR deleted IS NULL)',
        [shopId],
      );

      for (final row in rows) {
        final product = Product.fromMap(Map<String, dynamic>.from(row));
        if (product.localImagePath == null || product.localImagePath!.isEmpty) {
          continue;
        }
        await uploadAndSaveToProduct(
          product: product,
          localPath: product.localImagePath!,
        );
      }
    } catch (e) {
      debugPrint('ProductImageService.retryPending error: $e');
    }
  }
}
