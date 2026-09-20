// RepairPriceAdjustmentService — sửa giá thu ĐƠN SỬA ĐÃ GIAO (NEW-02, 2026-09-20).
//
// Vấn đề: giao máy xong đã thu tiền / ghi nợ theo giá cũ; đổi giá sau đó chỉ
// đổi `repairs.price` ⇒ phần chênh lệch không nằm ở đâu (không nợ, không
// phiếu, tài chính cash-basis vẫn số cũ).
//
// Chính sách:
//   * Đơn CHƯA giao (status 1–3): chỉ đổi giá, tiền tính lúc giao — không làm gì.
//   * Đơn ĐÃ giao (status 4): TÍNH LẠI phần còn phải thu/phải trả từ trạng thái
//     hiện có, không cộng dồn theo từng lần sửa ⇒ sửa nhiều lần / sửa rồi trả
//     về giá cũ đều ra cùng kết quả, không nợ trùng:
//       collected  = tiền đã thu lúc giao (phiếu REPAIR_SERVICE)
//                  + đã trả trên nợ giao máy CÔNG NỢ
//                  + đã trả trên nợ điều chỉnh khách-nợ − đã trả trên nợ shop-nợ
//       outstanding = giá mới − collected
//     - Có nợ giao máy (CÔNG NỢ): totalAmount = giá mới (không nhỏ hơn đã trả);
//       phần khách trả dư (giá mới < đã trả) ⇒ nợ SHOP_OWES điều chỉnh.
//     - Không có nợ giao máy: outstanding > 0 ⇒ nợ CUSTOMER_OWES điều chỉnh
//       (`debt_adj_cust_<repairId>`); outstanding < 0 ⇒ nợ SHOP_OWES điều chỉnh
//       (`debt_adj_shop_<repairId>`, shop phải trả lại khách, tất toán qua màn
//       Công nợ như mọi khoản nợ); = 0 ⇒ đóng nợ điều chỉnh.
//   * Không tạo phiếu thu/chi tự động (không có tiền thật đi qua tay) — tiền
//     chỉ ghi khi thu/trả nợ. Ghi local trước, đẩy cloud qua SyncOrchestrator
//     (CloudWritePolicy + SyncSignal đã có), phát `debts_changed`.
import 'package:flutter/foundation.dart';

import '../data/db_helper.dart';
import 'event_bus.dart';
import 'sync_orchestrator.dart';
import 'user_service.dart';

class RepairPriceAdjustmentResult {
  final int collected;
  final int outstanding;
  final String? customerDebtId;
  final String? shopDebtId;
  final String? deliveryDebtId;
  const RepairPriceAdjustmentResult({
    required this.collected,
    required this.outstanding,
    this.customerDebtId,
    this.shopDebtId,
    this.deliveryDebtId,
  });
}

class RepairPriceAdjustmentService {
  RepairPriceAdjustmentService._();

  static const String linkedType = 'REPAIR_PRICE_ADJUST';

  static String customerAdjId(String repairFid) => 'debt_adj_cust_$repairFid';
  static String shopAdjId(String repairFid) => 'debt_adj_shop_$repairFid';

  /// Áp dụng giá mới cho đơn đã giao. Trả về null nếu không áp dụng (đơn chưa
  /// giao / thiếu firestoreId).
  static Future<RepairPriceAdjustmentResult?> applyDeliveredPriceChange({
    required String repairFirestoreId,
    required int status,
    required int newPrice,
    required String customerName,
    required String phone,
    required String model,
    DBHelper? dbHelper,
    String? shopIdOverride, // test: không chạm Firebase
  }) async {
    if (status != 4) return null;
    final fid = repairFirestoreId.trim();
    if (fid.isEmpty) return null;
    final helper = dbHelper ?? DBHelper();
    final db = await helper.database;
    final shopId = shopIdOverride ?? await UserService.getCurrentShopId() ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;
    // Khách vãng lai không tên ⇒ ghi theo máy để màn Công nợ không hiện "N/A".
    final personName = customerName.trim().isNotEmpty
        ? customerName.trim()
        : (phone.trim().isNotEmpty ? phone.trim() : 'Khách lẻ ($model)');

    // 1. Tiền đã thu lúc giao (TIỀN MẶT / CK): phiếu REPAIR_SERVICE của đơn.
    final cashRows = await db.rawQuery(
      "SELECT IFNULL(SUM(amount),0) s FROM payment_intents "
      "WHERE status = 'COMPLETED' AND type = 'REPAIR_SERVICE' AND referenceId = ?",
      [fid],
    );
    final cashCollected = (cashRows.first['s'] as num?)?.toInt() ?? 0;

    // 2. Nợ giao máy (CÔNG NỢ) — CUSTOMER_OWES linkedId = đơn, không phải nợ điều chỉnh.
    final deliveryRows = await db.query(
      'debts',
      where:
          "linkedId = ? AND type = 'CUSTOMER_OWES' AND (linkedType IS NULL OR linkedType <> ?) AND (deleted = 0 OR deleted IS NULL)",
      whereArgs: [fid, linkedType],
      orderBy: 'createdAt ASC',
      limit: 1,
    );
    final delivery = deliveryRows.isEmpty ? null : deliveryRows.first;

    final custAdj = await helper.getDebtByFirestoreId(customerAdjId(fid));
    final shopAdj = await helper.getDebtByFirestoreId(shopAdjId(fid));
    int paidOf(Map<String, dynamic>? d) =>
        (d?['paidAmount'] as num?)?.toInt() ?? 0;
    bool alive(Map<String, dynamic>? d) =>
        d != null && ((d['deleted'] as num?)?.toInt() ?? 0) == 0;

    final collected = cashCollected +
        paidOf(delivery) +
        (alive(custAdj) ? paidOf(custAdj) : 0) -
        (alive(shopAdj) ? paidOf(shopAdj) : 0);
    final outstanding = newPrice - collected;

    Future<void> upsertAdj({
      required String id,
      required String type,
      required Map<String, dynamic>? existing,
      required int remaining, // phần còn phải thu/trả (>0 = mở, 0 = đóng)
    }) async {
      final paid = alive(existing) ? paidOf(existing) : 0;
      final total = paid + remaining;
      if (existing == null) {
        if (remaining <= 0) return; // chưa từng có, không cần tạo
        final row = {
          'firestoreId': id,
          'type': type,
          'debtType': type,
          'personName': personName,
          'phone': phone,
          'totalAmount': total,
          'paidAmount': 0,
          'status': 'ACTIVE',
          'note': type == 'CUSTOMER_OWES'
              ? 'Chênh lệch tăng giá sửa: $model'
              : 'Trả lại khách do giảm giá sửa: $model',
          'createdAt': now,
          'updatedAt': now,
          'shopId': shopId,
          'linkedId': fid,
          'linkedType': linkedType,
          'deleted': 0,
          'isSynced': 0,
        };
        final localId = await helper.insertDebt(row);
        if (localId > 0) {
          await SyncOrchestrator().enqueueDebt(
            localId,
            firestoreId: id,
            operation: SyncOperation.create,
          );
        }
        return;
      }
      final localId = (existing['id'] as num).toInt();
      if (remaining <= 0 && paid == 0) {
        // Không còn gì và chưa ai trả — xoá mềm, không để nợ 0đ lơ lửng.
        await helper.updateDebt({
          'id': localId,
          'totalAmount': 0,
          'status': 'PAID',
          'deleted': 1,
          'updatedAt': now,
          'isSynced': 0,
        });
        await SyncOrchestrator().enqueueDebt(
          localId,
          firestoreId: id,
          operation: SyncOperation.delete,
        );
        return;
      }
      await helper.updateDebt({
        'id': localId,
        'totalAmount': total,
        'status': remaining > 0 ? 'ACTIVE' : 'PAID',
        'deleted': 0,
        'updatedAt': now,
        'isSynced': 0,
      });
      await SyncOrchestrator().enqueueDebt(
        localId,
        firestoreId: id,
        operation: SyncOperation.update,
      );
    }

    if (delivery != null) {
      // Nợ giao máy: tổng = giá mới, nhưng không thấp hơn đã trả.
      final paid = paidOf(delivery);
      final newTotal = newPrice > paid ? newPrice : paid;
      await helper.updateDebt({
        'id': (delivery['id'] as num).toInt(),
        'totalAmount': newTotal,
        'status': newTotal > paid ? 'ACTIVE' : 'PAID',
        'updatedAt': now,
        'isSynced': 0,
      });
      await SyncOrchestrator().enqueueDebt(
        (delivery['id'] as num).toInt(),
        firestoreId: delivery['firestoreId'] as String?,
        operation: SyncOperation.update,
      );
      // Khách đã trả dư (giá mới < đã trả) ⇒ shop nợ lại khách phần dư.
      final over = paid - newPrice;
      await upsertAdj(
        id: shopAdjId(fid),
        type: 'SHOP_OWES',
        existing: shopAdj,
        remaining: over > 0 ? over : 0,
      );
      await upsertAdj(
        id: customerAdjId(fid),
        type: 'CUSTOMER_OWES',
        existing: custAdj,
        remaining: 0,
      );
    } else {
      await upsertAdj(
        id: customerAdjId(fid),
        type: 'CUSTOMER_OWES',
        existing: custAdj,
        remaining: outstanding > 0 ? outstanding : 0,
      );
      await upsertAdj(
        id: shopAdjId(fid),
        type: 'SHOP_OWES',
        existing: shopAdj,
        remaining: outstanding < 0 ? -outstanding : 0,
      );
    }

    EventBus().emit('debts_changed');
    debugPrint(
      '💱 RepairPriceAdjust $fid: price=$newPrice collected=$collected outstanding=$outstanding',
    );
    // Đẩy cloud ngay nếu có mạng (orchestrator tự gate/timeout/bump).
    // ignore: unawaited_futures
    SyncOrchestrator().syncAll();
    return RepairPriceAdjustmentResult(
      collected: collected,
      outstanding: outstanding,
      customerDebtId: customerAdjId(fid),
      shopDebtId: shopAdjId(fid),
      deliveryDebtId: delivery?['firestoreId'] as String?,
    );
  }
}
