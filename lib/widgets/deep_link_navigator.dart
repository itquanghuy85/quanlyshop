import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../constants/product_constants.dart';

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
  final int? soldQty;
  final int? soldPrice;
  final int? salePrice;
  final String? soldImei;

  const ProductLinkRef({
    this.productId,
    required this.displayName,
    this.imei,
    this.serial,
    this.sku,
    this.imageUrl,
    this.sourceEvent,
    this.soldQty,
    this.soldPrice,
    this.salePrice,
    this.soldImei,
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
        // Đơn "khách vãng lai" cố ý không lưu vào danh bạ (đúng thiết kế) —
        // nhưng nếu đơn vẫn có sẵn tên + SĐT thật (nhân viên lỡ tick vãng
        // lai chứ không phải khách ẩn danh), mời tạo hồ sơ ngay từ đó thay
        // vì chỉ báo lỗi rồi hết, người dùng phải tự gõ lại thủ công.
        final canCreate = rawPhone.isNotEmpty && rawName.isNotEmpty;
        if (!canCreate) {
          NotificationService.showSnackBar(
            'Không tìm thấy hồ sơ khách hàng',
            color: AppColors.warning,
          );
          return;
        }
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Không tìm thấy hồ sơ khách hàng (đơn đánh dấu khách vãng lai)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Tạo hồ sơ',
              textColor: Colors.white,
              onPressed: () => _createAndOpenCustomer(
                context,
                name: rawName,
                phone: rawPhone,
              ),
            ),
          ),
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

  /// Tạo hồ sơ khách hàng mới từ tên + SĐT đã có sẵn trên đơn (trường hợp
  /// đơn đánh dấu "khách vãng lai" nên chưa từng lưu vào danh bạ), rồi mở
  /// thẳng hồ sơ vừa tạo — gọi từ action "Tạo hồ sơ" trên SnackBar.
  static Future<void> _createAndOpenCustomer(
    BuildContext context, {
    required String name,
    required String phone,
  }) async {
    try {
      final created = await CustomerService().addCustomer(
        Customer(
          name: name,
          phone: phone,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      if (!context.mounted) return;
      if (created == null) {
        NotificationService.showSnackBar(
          'Không tạo được hồ sơ khách hàng, thử lại sau.',
          color: AppColors.error,
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerProfileView(customer: created),
        ),
      );
    } catch (e) {
      debugPrint('DeepLinkNavigator._createAndOpenCustomer error: $e');
      if (context.mounted) {
        NotificationService.showSnackBar(
          'Không tạo được hồ sơ khách hàng, thử lại sau.',
          color: AppColors.error,
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
    int? soldQty,
    int? soldPrice,
    int? salePrice,
    String? soldImei,
  }) async {
    try {
      final db = DBHelper();
      Product? found;

      final rawProductId = (productId ?? '').trim();
      final rawImei = (imei ?? '').trim();
      final rawSerial = (serial ?? '').trim();
      final rawSku = (sku ?? '').trim();
      final rawName = (fallbackName ?? '').trim();

      // Priority 1: productId (firestoreId, or a local SQLite id)
      //
      // A numeric id is the row id of whichever device wrote the record and is
      // NOT portable: on another phone the same number is a different product
      // (2026-09-12: a sale's "CÓC SẠC" opened "IPAD GEN 10" on the owner's
      // phone, and a third product on the iPhone). So a numeric hit is only
      // trusted when its name matches the name we were given; otherwise fall
      // through to IMEI / SKU / name, which are device-independent.
      if (rawProductId.isNotEmpty) {
        final localId = int.tryParse(rawProductId);
        if (localId != null) {
          final byLocalId = await db.getProductById(localId);
          if (byLocalId != null &&
              ProductConstants.isSameProductName(byLocalId.name, rawName)) {
            found = byLocalId;
          }
        }
        // Also covers an all-digit firestoreId (none seen in real data, kept
        // so behaviour is a strict superset of the old lookup).
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

      // Priority 4.5: partial IMEI suffix (for short KiotViet serial codes ≤ 8 chars)
      if (found == null && rawImei.isNotEmpty && rawImei.length <= 8) {
        found = await db.getProductByImeiSuffix(rawImei);
      }

      // Fallback by name for resilient UX
      if (found == null && rawName.isNotEmpty) {
        found = await db.getProductByNameFlexible(rawName);
      }

      // Final fallback: strip quantity suffix (e.g. "ỐP LƯNG X2" → "ỐP LƯNG")
      if (found == null && rawName.isNotEmpty) {
        final nameWithoutQty = rawName.replaceAll(RegExp(r'\s+[xX]\d+\b'), '').trim();
        if (nameWithoutQty != rawName && nameWithoutQty.isNotEmpty) {
          found = await db.getProductByNameFlexible(nameWithoutQty);
        }
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
        MaterialPageRoute(
          builder: (_) => InventoryDetailView(
            product: found!,
            soldQty: soldQty,
            soldPrice: soldPrice,
            salePrice: salePrice,
            soldImei: soldImei,
          ),
        ),
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
