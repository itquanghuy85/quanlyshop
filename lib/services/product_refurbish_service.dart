// Sửa/tân trang sản phẩm trong kho trước khi bán (2026-09-22).
//
// Tình huống: mua máy lẻ về (vd iPhone bể kính/hư pin/hư sạc), cần gửi đối
// tác ép kính + sửa mainboard, lấy pin từ kho phụ tùng để thay — mỗi khoản
// chi phí phải: (1) cộng vào giá vốn hiển thị của sản phẩm (tách riêng
// "chi phí sửa" khỏi giá vốn gốc lúc nhập — quyết định 2026-09-22), (2) trừ
// đúng kho phụ tùng nếu dùng linh kiện, (3) ghi đúng công nợ đối tác hoặc
// phiếu chi tài chính.
//
// KHÔNG theo dõi trạng thái "đã gửi/đang sửa/đã nhận về" (quyết định
// 2026-09-22) — chỉ ghi nhận 1 lần chi phí ngay khi nhập, giống cách ghi
// dịch vụ đối tác trong đơn sửa hiện có.
import 'package:flutter/foundation.dart';

import '../data/db_helper.dart';
import 'app_session.dart';
import 'event_bus.dart';
import 'payment_intent_service.dart';
import 'sync_orchestrator.dart';
import 'user_service.dart';

class ProductRefurbishResult {
  final bool success;
  final String? error;
  final int? newRefurbishCost;
  const ProductRefurbishResult({
    required this.success,
    this.error,
    this.newRefurbishCost,
  });
}

class ProductRefurbishService {
  ProductRefurbishService._();

  static String _generateFirestoreId() =>
      'refurb_${DateTime.now().microsecondsSinceEpoch}';

  static Future<String> _actorName() async =>
      AppSession.isOffline ? AppSession.actorName : await UserService.getCurrentUserName();

  /// Ghi 1 khoản chi phí gửi đối tác (ép kính, sửa mainboard...) hoặc chi phí
  /// khác không gắn NCC (công thợ tự làm) cho 1 sản phẩm trong kho.
  static Future<ProductRefurbishResult> addServiceOrOtherCost({
    required int productId,
    required String? productFirestoreId,
    required String description,
    int? partnerId,
    String? partnerName,
    required int amount,
    required String paymentMethod, // TIỀN MẶT | CHUYỂN KHOẢN | CÔNG NỢ
  }) async {
    if (amount <= 0) {
      return const ProductRefurbishResult(
        success: false,
        error: 'Số tiền phải lớn hơn 0',
      );
    }
    final db = DBHelper();
    final now = DateTime.now().millisecondsSinceEpoch;
    final shopId = await UserService.getCurrentShopId() ?? '';
    final userName = await _actorName();
    final itemFid = _generateFirestoreId();
    final isPartner = partnerId != null || (partnerName?.trim().isNotEmpty ?? false);
    final type = isPartner
        ? 'PARTNER_SERVICE'
        : 'OTHER';

    String? debtFirestoreId;
    String? expenseFirestoreId;

    try {
      if (paymentMethod == 'CÔNG NỢ') {
        debtFirestoreId = 'debt_refurb_$itemFid';
        await PaymentIntentService.createDebtRecord(
          debtType: 'SHOP_OWES',
          amount: amount,
          personName: (partnerName?.trim().isNotEmpty ?? false)
              ? partnerName!.trim()
              : 'Chi phí sửa/tân trang',
          note: 'Sửa/tân trang sản phẩm: $description',
          linkedId: productFirestoreId,
          linkedType: 'PRODUCT_REFURBISH',
          debtFirestoreId: debtFirestoreId,
        );
      } else {
        expenseFirestoreId = 'exp_refurb_$itemFid';
        await db.insertExpense({
          'firestoreId': expenseFirestoreId,
          'category': 'SỬA CHỮA/TÂN TRANG SP',
          'title': description,
          'amount': amount,
          'paymentMethod': paymentMethod,
          'note': isPartner ? 'Đối tác: ${partnerName ?? ''}' : null,
          'date': now,
          'createdBy': userName,
          'shopId': shopId,
          'isSynced': 0,
        });
      }
    } catch (e) {
      debugPrint('❌ ProductRefurbishService: lỗi ghi tiền: $e');
      return ProductRefurbishResult(success: false, error: e.toString());
    }

    final itemId = await db.insertProductRefurbishItem({
      'firestoreId': itemFid,
      'productId': productId,
      'productFirestoreId': productFirestoreId,
      'type': type,
      'description': description,
      'partnerId': partnerId,
      'partnerName': partnerName,
      'quantity': 1,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'debtFirestoreId': debtFirestoreId,
      'expenseFirestoreId': expenseFirestoreId,
      'createdAt': now,
      'createdBy': userName,
      'shopId': shopId,
      'isSynced': 0,
      'deleted': 0,
    });
    if (itemId <= 0) {
      return const ProductRefurbishResult(
        success: false,
        error: 'Không lưu được khoản chi phí',
      );
    }

    final updated = await db.addToProductRefurbishCost(productId, amount);
    _pushCloud(productId, productFirestoreId);

    EventBus().emit('inventory_changed');
    EventBus().emit('financial_activity_changed');
    return ProductRefurbishResult(
      success: true,
      newRefurbishCost: updated['refurbishCost'] as int?,
    );
  }

  /// Lấy 1 linh kiện từ Kho phụ tùng (nguồn `repair_parts` hoặc `products`
  /// type LINH_KIEN — [source] khớp key `getAllPartsUnified()` trả về) để
  /// thay cho sản phẩm — trừ tồn kho phụ tùng + cộng chi phí (mặc định = giá
  /// vốn linh kiện × số lượng, cho phép ghi đè nếu cần) vào chi phí sửa.
  static Future<ProductRefurbishResult> addPartCost({
    required int productId,
    required String? productFirestoreId,
    required int partId,
    required String source, // 'repair_parts' | 'products'
    required String partName,
    required int quantity,
    int? unitCostOverride,
  }) async {
    if (quantity <= 0) {
      return const ProductRefurbishResult(
        success: false,
        error: 'Số lượng phải lớn hơn 0',
      );
    }
    final db = DBHelper();
    int currentQty;
    int partCost;
    if (source == 'products') {
      final part = await db.getProductById(partId);
      if (part == null) {
        return const ProductRefurbishResult(
          success: false,
          error: 'Không tìm thấy linh kiện',
        );
      }
      currentQty = part.quantity;
      partCost = part.cost;
    } else {
      final part = await db.getPartById(partId);
      if (part == null) {
        return const ProductRefurbishResult(
          success: false,
          error: 'Không tìm thấy linh kiện',
        );
      }
      currentQty = (part['quantity'] as num?)?.toInt() ?? 0;
      partCost = (part['cost'] as num?)?.toInt() ?? 0;
    }
    if (currentQty < quantity) {
      return ProductRefurbishResult(
        success: false,
        error: 'Không đủ tồn kho phụ tùng: $partName (còn $currentQty, cần $quantity)',
      );
    }

    final unitCost = unitCostOverride ?? partCost;
    final amount = unitCost * quantity;

    final deducted = await db.deductPartQuantityUnified(
      partId,
      source,
      quantity,
    );
    if (!deducted) {
      return ProductRefurbishResult(
        success: false,
        error: 'Không đủ tồn kho phụ tùng: $partName',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final shopId = await UserService.getCurrentShopId() ?? '';
    final userName = await _actorName();
    final itemFid = _generateFirestoreId();

    final itemId = await db.insertProductRefurbishItem({
      'firestoreId': itemFid,
      'productId': productId,
      'productFirestoreId': productFirestoreId,
      'type': 'PART',
      'description': 'Thay $partName',
      'partId': partId,
      'partName': partName,
      'quantity': quantity,
      'amount': amount,
      'paymentMethod': null,
      'createdAt': now,
      'createdBy': userName,
      'shopId': shopId,
      'isSynced': 0,
      'deleted': 0,
    });
    if (itemId <= 0) {
      return const ProductRefurbishResult(
        success: false,
        error: 'Không lưu được khoản linh kiện',
      );
    }

    final updated = await db.addToProductRefurbishCost(productId, amount);
    _pushCloud(productId, productFirestoreId);

    EventBus().emit('inventory_changed');
    return ProductRefurbishResult(
      success: true,
      newRefurbishCost: updated['refurbishCost'] as int?,
    );
  }

  static void _pushCloud(int productId, String? productFirestoreId) {
    // Đẩy cloud ngay nếu có mạng (SyncOrchestrator tự gate/timeout/bump qua
    // CloudWritePolicy + SyncSignal); không có mạng thì isSynced=0 vẫn còn,
    // sweep chung của products + product_refurbish_items trong syncAllToCloud
    // sẽ đẩy lại sau — không tự tạo cơ chế riêng.
    // ignore: unawaited_futures
    SyncOrchestrator().syncAll();
  }

  static Future<List<Map<String, dynamic>>> getHistory(int productId) async {
    return DBHelper().getProductRefurbishItems(productId);
  }
}
