import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

import '../data/db_helper.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../services/customer_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../utils/vietnamese_utils.dart';
import '../views/customer_profile_view.dart';
import '../views/inventory_detail_view.dart';

class ProductLinkRef {
  final String? productId;
  final String displayName;
  final String? imei;
  final String? serial;
  final String? sku;
  final String? imageUrl;
  final String? sourceEvent;

  const ProductLinkRef({
    this.productId,
    required this.displayName,
    this.imei,
    this.serial,
    this.sku,
    this.imageUrl,
    this.sourceEvent,
  });
}

class DeepLinkNavigator {
  DeepLinkNavigator._();

  static String _normalizePhone(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static String _normalizeName(String input) {
    return VietnameseUtils.normalize(input).trim();
  }

  static Future<void> openCustomerProfile(
    BuildContext context, {
    String? customerId,
    String? phoneNumber,
    String? normalizedName,
    String? sourceEvent,
  }) async {
    try {
      final service = CustomerService();
      final customers = await service.getCustomers();
      Customer? found;

      final rawCustomerId = (customerId ?? '').trim();
      final rawPhone = (phoneNumber ?? '').trim();
      final rawName = (normalizedName ?? '').trim();

      // Priority 1: customerId (local id or firestoreId)
      if (rawCustomerId.isNotEmpty) {
        final localId = int.tryParse(rawCustomerId);
        if (localId != null) {
          for (final c in customers) {
            if (c.id == localId) {
              found = c;
              break;
            }
          }
        }
        if (found == null) {
          for (final c in customers) {
            if ((c.firestoreId ?? '') == rawCustomerId) {
              found = c;
              break;
            }
          }
        }
      }

      // Priority 2: phoneNumber
      if (found == null && rawPhone.isNotEmpty) {
        final target = _normalizePhone(rawPhone);
        if (target.isNotEmpty) {
          for (final c in customers) {
            if (_normalizePhone(c.phone) == target) {
              found = c;
              break;
            }
          }
        }
      }

      // Priority 3: normalizedName
      if (found == null && rawName.isNotEmpty) {
        final target = _normalizeName(rawName);
        if (target.isNotEmpty) {
          for (final c in customers) {
            if (_normalizeName(c.name) == target) {
              found = c;
              break;
            }
          }
        }
      }

      if (!context.mounted) return;
      if (found == null) {
        NotificationService.showSnackBar(
          'Không tìm thấy hồ sơ khách hàng',
          color: AppColors.warning,
        );
        return;
      }

      if ((sourceEvent ?? '').trim().isNotEmpty) {
        debugPrint('📊 deeplink_event=$sourceEvent');
      }

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CustomerProfileView(customer: found!)),
      );
    } catch (e) {
      debugPrint('DeepLinkNavigator.openCustomerProfile error: $e');
      if (context.mounted) {
        NotificationService.showSnackBar(
          'Không tìm thấy hồ sơ khách hàng',
          color: AppColors.warning,
        );
      }
    }
  }

  static Future<Product?> _findProductBySku(String sku) async {
    final shopId = await UserService.getCurrentShopId();
    final db = await DBHelper().database;
    final cleanSku = sku.trim();
    if (cleanSku.isEmpty) return null;

    final List<Map<String, Object?>> rows;
    if (shopId == null || shopId.trim().isEmpty) {
      rows = await db.rawQuery(
        'SELECT * FROM products WHERE UPPER(sku) = UPPER(?) AND (deleted = 0 OR deleted IS NULL) LIMIT 1',
        [cleanSku],
      );
    } else {
      rows = await db.rawQuery(
        'SELECT * FROM products WHERE UPPER(sku) = UPPER(?) AND shopId = ? AND (deleted = 0 OR deleted IS NULL) LIMIT 1',
        [cleanSku, shopId],
      );
    }

    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  static Future<void> openProductDetail(
    BuildContext context, {
    String? productId,
    String? imei,
    String? serial,
    String? sku,
    String? fallbackName,
    String? sourceEvent,
  }) async {
    try {
      final db = DBHelper();
      Product? found;

      final rawProductId = (productId ?? '').trim();
      final rawImei = (imei ?? '').trim();
      final rawSerial = (serial ?? '').trim();
      final rawSku = (sku ?? '').trim();
      final rawName = (fallbackName ?? '').trim();

      // Priority 1: productId (local id or firestoreId)
      if (rawProductId.isNotEmpty) {
        final localId = int.tryParse(rawProductId);
        if (localId != null) {
          found = await db.getProductById(localId);
        }
        found ??= await db.getProductByFirestoreId(rawProductId);
      }

      // Priority 2: imei
      if (found == null && rawImei.isNotEmpty) {
        found = await db.getProductByImei(rawImei);
      }

      // Priority 3: serial
      if (found == null && rawSerial.isNotEmpty) {
        found = await db.getProductByImei(rawSerial);
      }

      // Priority 4: sku
      if (found == null && rawSku.isNotEmpty) {
        found = await _findProductBySku(rawSku);
      }

      // Fallback by name for resilient UX
      if (found == null && rawName.isNotEmpty) {
        found = await db.getProductByNameFlexible(rawName);
      }

      if (!context.mounted) return;
      if (found == null) {
        NotificationService.showSnackBar(
          'Không tìm thấy sản phẩm',
          color: AppColors.warning,
        );
        return;
      }

      if ((sourceEvent ?? '').trim().isNotEmpty) {
        debugPrint('📊 deeplink_event=$sourceEvent');
      }

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => InventoryDetailView(product: found!)),
      );
    } catch (e) {
      debugPrint('DeepLinkNavigator.openProductDetail error: $e');
      if (context.mounted) {
        NotificationService.showSnackBar(
          'Không tìm thấy sản phẩm',
          color: AppColors.warning,
        );
      }
    }
  }
}
