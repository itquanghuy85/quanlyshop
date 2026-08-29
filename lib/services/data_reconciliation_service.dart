import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/db_helper.dart';
import '../models/product_model.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import 'audit_service.dart';
import 'customer_service.dart';
import 'financial_activity_service.dart';
import 'firestore_service.dart';
import 'firestore_write_helper.dart';
import 'payment_intent_service.dart';
import 'sync_orchestrator.dart';
import 'user_service.dart';

/// Kết quả tóm tắt sau khi thực hiện 1 thao tác xóa/điều chỉnh — dùng để
/// hiện cho user xác nhận/biết đã ảnh hưởng những gì.
class ReconciliationResult {
  ReconciliationResult({
    this.inventoryRestored = 0,
    this.debtsRemoved = 0,
    this.debtAmountRemoved = 0,
    this.intentsHandled = 0,
    this.offsetAmount = 0,
    this.note,
  });

  final int inventoryRestored;
  final int debtsRemoved;
  final int debtAmountRemoved;
  final int intentsHandled;
  final int offsetAmount;
  final String? note;
}

/// Công cụ điều chỉnh dữ liệu — dùng cho việc dọn dữ liệu test/nhập nhầm
/// (đơn sửa, đơn bán, công nợ, kho/linh kiện) mà KHÔNG đụng tới các luồng
/// xóa hiện có (order_list_view.dart, sale_detail_view.dart) để tránh rủi
/// ro hồi quy lên tính năng đang chạy thật.
///
/// Mỗi thao tác xóa có 2 biến thể:
/// - `*WithReversal`: tự tìm và đảo ngược công nợ/payment/kho liên quan.
/// - `*KeepBooks`: chỉ xóa dữ liệu, giữ nguyên sổ sách (dùng khi ngày đó
///   đã báo cáo/chốt, không muốn động vào số liệu cũ).
class DataReconciliationService {
  static final DBHelper _db = DBHelper();

  // ─────────────────────────── ĐƠN SỬA CHỮA ───────────────────────────

  static Future<ReconciliationResult> deleteRepairWithReversal(Repair r) async {
    int restoredCount = 0;
    int debtDeleted = 0;
    int debtAmount = 0;
    int intentsHandled = 0;
    int offsetAmount = 0;

    // 1. Hoàn phụ tùng về kho
    if (r.partsUsed.isNotEmpty) {
      restoredCount = await _restorePartsToInventory(r.partsUsed);
    }

    // 2. Xóa công nợ liên quan + các phiếu thu/trả nợ đã ghi cho công nợ đó
    if (r.firestoreId != null && r.firestoreId!.isNotEmpty) {
      final linkedDebts = await _db.getDebtsByLinkedId(r.firestoreId!);
      for (final debt in linkedDebts) {
        final debtId = debt['id'] as int?;
        if (debtId == null) continue;
        final total = (debt['totalAmount'] as int?) ?? 0;
        final paid = (debt['paidAmount'] as int?) ?? 0;
        debtAmount += (total - paid).clamp(0, total);
        await _softDeleteDebtPaymentsForDebt(debt);
        await _db.softDeleteDebt(
          debtId,
          reason: 'Xóa kèm hoàn tài chính từ Công cụ điều chỉnh dữ liệu',
        );
        debtDeleted++;
      }
    }

    // 3. Xử lý PaymentIntent liên quan: hủy PENDING, bù trừ COMPLETED
    if (r.firestoreId != null && r.firestoreId!.isNotEmpty) {
      final allIntents = await PaymentIntentService.getAllIntents();
      final related = allIntents.where((i) => i.referenceId == r.firestoreId);
      for (final intent in related) {
        if (intent.canExecute) {
          await PaymentIntentService.cancelIntent(
            intent.id,
            reason: 'Xóa đơn sửa từ Công cụ điều chỉnh dữ liệu',
          );
          intentsHandled++;
        } else if (intent.isCompleted) {
          offsetAmount += intent.amount;
          intentsHandled++;
        }
      }
    }

    if (offsetAmount > 0) {
      try {
        await FinancialActivityService.logCustomActivity(
          activityType: 'REPAIR_VOID',
          amount: offsetAmount,
          direction: 'OUT',
          paymentMethod: r.paymentMethod,
          title: 'HỦY ĐƠN SỬA (điều chỉnh dữ liệu)',
          description: 'Xóa đơn: ${r.model}. KH: ${r.customerName}',
          customerName: r.customerName,
          phone: r.walkInPhone ?? r.phone,
          productInfo: r.model,
          referenceType: 'repair',
          referenceId: r.firestoreId,
        );
      } catch (e) {
        debugPrint('⚠️ DataReconciliation: failed to log REPAIR_VOID: $e');
      }
    }

    await _deleteRepairRecord(r);

    await AuditService.logAction(
      action: 'RECONCILE_DELETE_REPAIR',
      entityType: 'repair',
      entityId: r.firestoreId ?? 'repair_${r.id}',
      summary: '${r.customerName} - ${r.model} (kèm hoàn tài chính)',
      payload: {
        'model': r.model,
        'price': r.price,
        'cost': r.cost,
        'inventoryRestored': restoredCount,
        'debtsRemoved': debtDeleted,
        'debtAmountRemoved': debtAmount,
        'intentsHandled': intentsHandled,
        'offsetAmount': offsetAmount,
      },
    );

    return ReconciliationResult(
      inventoryRestored: restoredCount,
      debtsRemoved: debtDeleted,
      debtAmountRemoved: debtAmount,
      intentsHandled: intentsHandled,
      offsetAmount: offsetAmount,
    );
  }

  static Future<ReconciliationResult> deleteRepairKeepBooks(Repair r) async {
    await _deleteRepairRecord(r);

    await AuditService.logAction(
      action: 'RECONCILE_DELETE_REPAIR',
      entityType: 'repair',
      entityId: r.firestoreId ?? 'repair_${r.id}',
      summary: '${r.customerName} - ${r.model} (giữ nguyên sổ sách)',
      payload: {'model': r.model, 'price': r.price, 'cost': r.cost},
    );

    return ReconciliationResult(
      note: 'Đã xóa đơn, giữ nguyên công nợ/tài chính liên quan',
    );
  }

  /// Soft-delete các phiếu thu/trả nợ (`debt_payments`) gắn với 1 công nợ sắp
  /// bị xóa/miễn, và xếp hàng đồng bộ xóa từng phiếu. Nếu bỏ sót, phiếu mồ côi
  /// vẫn được `analyze()`/FinanceV2 tính là "tiền vào" vĩnh viễn.
  static Future<void> _softDeleteDebtPaymentsForDebt(
    Map<String, dynamic> debt,
  ) async {
    final debtFId = debt['firestoreId'] as String?;
    if (debtFId == null || debtFId.isEmpty) return;
    final linkedPayments = await _db.getDebtPaymentsByDebtFirestoreId(debtFId);
    if (linkedPayments.isEmpty) return;
    await _db.softDeleteDebtPaymentsByDebtFirestoreId(debtFId);
    for (final p in linkedPayments) {
      final pId = p['id'] as int?;
      if (pId == null) continue;
      await SyncOrchestrator().enqueue(
        entityType: SyncEntityType.debtPayment,
        entityId: pId,
        firestoreId: p['firestoreId'] as String?,
        operation: SyncOperation.delete,
        data: {...p, 'deleted': true},
      );
    }
  }

  static Future<void> _deleteRepairRecord(Repair r) async {
    if (r.firestoreId != null && r.firestoreId!.isNotEmpty) {
      try {
        await FirestoreService.deleteRepair(r.firestoreId!);
      } catch (e) {
        debugPrint('⚠️ DataReconciliation: cloud delete repair failed: $e');
        // Cloud delete lỗi (mạng/timeout) — vẫn xóa local theo đúng mục đích
        // công cụ này (dọn dữ liệu ngay), nhưng xếp hàng đợi retry để cloud
        // không mồ côi document vĩnh viễn (trước đây bỏ qua bước này, gây
        // lệch "Local/Cloud" kéo dài sau mỗi lần xóa hàng loạt).
        if (r.id != null) {
          await SyncOrchestrator().enqueueRepair(
            r.id!,
            firestoreId: r.firestoreId,
            operation: SyncOperation.delete,
          );
        }
      }
      await _db.deleteRepairByFirestoreId(r.firestoreId!);
    } else if (r.id != null) {
      await _db.deleteRepair(r.id!);
    }
  }

  /// Hoàn trả phụ tùng về kho — mirror logic của
  /// order_list_view.dart:_restorePartsToInventory.
  static Future<int> _restorePartsToInventory(String partsUsed) async {
    if (partsUsed.isEmpty) return 0;
    int restored = 0;
    final parts = partsUsed.split(', ');
    for (final part in parts) {
      final match = RegExp(r'^(.+?)\s*x(\d+)$').firstMatch(part.trim());
      String partName;
      int quantity;
      if (match != null) {
        partName = match.group(1)!.trim();
        quantity = int.tryParse(match.group(2)!) ?? 1;
      } else {
        partName = part.trim();
        quantity = 1;
      }
      if (partName.isEmpty) continue;
      final ok = await _db.restorePartQuantityByName(partName, quantity);
      if (ok) restored += quantity;
    }
    return restored;
  }

  // ──────────────────────────── ĐƠN BÁN HÀNG ───────────────────────────

  static Future<ReconciliationResult> deleteSaleWithReversal(
    SaleOrder s,
  ) async {
    final saleRef = s.firestoreId ?? 'sale_${s.soldAt}';
    final finalPrice = s.finalPrice;
    int restoredCount = 0;
    int debtDeleted = 0;
    int debtAmount = 0;
    int intentDeleted = 0;

    // 1. Khôi phục inventory (theo IMEI hoặc tên sản phẩm)
    final imeis = s.productImeis.split(RegExp(r'\s*,\s*'));
    final names = s.productNames.split(RegExp(r'\s*,\s*'));
    for (int i = 0; i < imeis.length; i++) {
      final imei = imeis[i].trim();
      if (imei.isEmpty) continue;

      Product? product;
      int qtyToRestore = 1;

      if (imei.toUpperCase().startsWith('PKX') || imei == 'NO_IMEI') {
        if (imei.toUpperCase().startsWith('PKX')) {
          qtyToRestore =
              int.tryParse(imei.toUpperCase().replaceAll('PKX', '')) ?? 1;
        }
        if (i < names.length) {
          final nameEntry = names[i].trim();
          final nameMatch = RegExp(r'^(.+?)\s+[xX]\d+').firstMatch(nameEntry);
          var productName = nameMatch != null
              ? nameMatch.group(1)!.trim()
              : nameEntry;
          productName = productName.replaceAll(
            RegExp(r'\s*\(TẶNG\)\s*$', caseSensitive: false),
            '',
          );
          productName = productName.replaceAll(
            RegExp(r'\s*\(GIẢM\s+[\d,.]+\)\s*$', caseSensitive: false),
            '',
          );
          productName = productName.trim();
          product = await _db.getProductByName(productName);
        }
      } else {
        product = await _db.getProductByImei(imei);
      }

      if (product != null) {
        await _db.addProductQuantity(product.id!, qtyToRestore);
        product.quantity += qtyToRestore;
        if (product.status == 0 && product.quantity > 0) {
          product.status = 1;
          await _db.updateProductStatus(product.id!, 1);
        }
        if (product.firestoreId != null && product.firestoreId!.isNotEmpty) {
          try {
            await FirebaseFirestore.instance
                .collection('products')
                .doc(product.firestoreId)
                .update({
                  'quantity': product.quantity,
                  'status': product.status,
                  'updatedAt': FirestoreWriteHelper.serverUpdatedAt(),
                });
          } catch (e) {
            await SyncOrchestrator().enqueue(
              entityType: SyncEntityType.product,
              entityId: product.id!,
              firestoreId: product.firestoreId,
              operation: SyncOperation.update,
              data: product.toMap(),
            );
          }
        }
        restoredCount += qtyToRestore;
      }
    }

    // 2. Xóa công nợ liên quan + các phiếu thu/trả nợ đã ghi cho công nợ đó
    if (s.firestoreId != null) {
      final linkedDebts = await _db.getDebtsByLinkedId(s.firestoreId ?? '');
      for (final debt in linkedDebts) {
        final debtFId = debt['firestoreId'] as String?;
        final total = (debt['totalAmount'] as int?) ?? 0;
        final paid = (debt['paidAmount'] as int?) ?? 0;
        debtAmount += (total - paid).clamp(0, total);
        if (debtFId != null) {
          await _softDeleteDebtPaymentsForDebt(debt);
          await _db.deleteDebtByFirestoreId(debtFId);
          await SyncOrchestrator().enqueue(
            entityType: SyncEntityType.debt,
            entityId: debt['id'] as int,
            firestoreId: debtFId,
            operation: SyncOperation.delete,
            data: {...debt, 'deleted': true},
          );
        }
        debtDeleted++;
      }
    }

    // 3. Xóa PaymentIntents liên quan
    try {
      intentDeleted = await _db.deletePaymentIntentsByReferenceId(saleRef);
    } catch (e) {
      debugPrint('⚠️ DataReconciliation: delete payment intents failed: $e');
    }

    // 4. Trừ lại chi tiêu khách hàng
    try {
      final phone = s.walkInPhone ?? s.phone;
      if (phone.isNotEmpty) {
        final customerService = CustomerService();
        final customer = await customerService.getCustomerByPhone(phone);
        if (customer != null && finalPrice > 0) {
          final newTotal = (customer.totalSpent - finalPrice)
              .clamp(0, double.maxFinite)
              .toInt();
          await customerService.updateCustomer(
            customer.copyWith(totalSpent: newTotal),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ DataReconciliation: revert customer stats failed: $e');
    }

    // 5. Ghi bút toán bù trừ
    try {
      await FinancialActivityService.logCustomActivity(
        activityType: 'SALE_VOID',
        amount: finalPrice,
        direction: 'OUT',
        paymentMethod: s.paymentMethod,
        title: 'HỦY ĐƠN BÁN (điều chỉnh dữ liệu)',
        description: 'Xóa đơn: ${s.productNamesDisplay}. KH: ${s.customerName}',
        customerName: s.customerName,
        phone: s.walkInPhone ?? s.phone,
        productInfo: s.productNamesDisplay,
        referenceType: 'sale',
        referenceId: s.firestoreId,
      );
    } catch (e) {
      debugPrint('⚠️ DataReconciliation: log SALE_VOID failed: $e');
    }

    await _deleteSaleRecord(s);

    await AuditService.logAction(
      action: 'RECONCILE_DELETE_SALE',
      entityType: 'sale',
      entityId: saleRef,
      summary:
          '${s.customerName} - ${s.productNamesDisplay} (kèm hoàn tài chính)',
      payload: {
        'totalPrice': s.totalPrice,
        'finalPrice': finalPrice,
        'inventoryRestored': restoredCount,
        'debtsRemoved': debtDeleted,
        'debtAmountRemoved': debtAmount,
        'intentsDeleted': intentDeleted,
      },
    );

    return ReconciliationResult(
      inventoryRestored: restoredCount,
      debtsRemoved: debtDeleted,
      debtAmountRemoved: debtAmount,
      intentsHandled: intentDeleted,
    );
  }

  static Future<ReconciliationResult> deleteSaleKeepBooks(SaleOrder s) async {
    final saleRef = s.firestoreId ?? 'sale_${s.soldAt}';
    await _deleteSaleRecord(s);

    await AuditService.logAction(
      action: 'RECONCILE_DELETE_SALE',
      entityType: 'sale',
      entityId: saleRef,
      summary:
          '${s.customerName} - ${s.productNamesDisplay} (giữ nguyên sổ sách)',
      payload: {'totalPrice': s.totalPrice, 'finalPrice': s.finalPrice},
    );

    return ReconciliationResult(
      note: 'Đã xóa đơn, giữ nguyên công nợ/tài chính liên quan',
    );
  }

  static Future<void> _deleteSaleRecord(SaleOrder s) async {
    if (s.firestoreId != null) {
      try {
        await FirestoreService.deleteSale(s.firestoreId!);
      } catch (e) {
        await SyncOrchestrator().enqueue(
          entityType: SyncEntityType.sale,
          entityId: s.id!,
          firestoreId: s.firestoreId,
          operation: SyncOperation.delete,
          data: {'firestoreId': s.firestoreId},
        );
      }
    }
    await _db.deleteSale(s.id!);
  }

  // ────────────────────────────── CÔNG NỢ ──────────────────────────────

  /// Miễn nợ — soft-delete, lưu lý do vào cột `note`. KHÔNG ghi bút toán
  /// tiền mặt vì miễn nợ không phải là thu tiền thật.
  static Future<void> writeOffDebt(
    int debtId, {
    required String reason,
    required String personName,
  }) async {
    await _db.softDeleteDebt(debtId, reason: 'Miễn nợ: $reason');
    await AuditService.logAction(
      action: 'RECONCILE_WRITE_OFF_DEBT',
      entityType: 'debt',
      entityId: 'debt_$debtId',
      summary: '$personName - $reason',
      payload: {'reason': reason},
    );
  }

  // ─────────────────── DỌN DỮ LIỆU TÀI CHÍNH (AUDIT) ──────────────────

  /// Phiếu thu/trả nợ MỒ CÔI: còn `deleted=0` nhưng `debtFirestoreId` lẫn
  /// `debtId` đều không khớp công nợ nào (thường do VOID đơn TRƯỚC bản vá
  /// PHASE 1.2 — công nợ bị xóa, phiếu ở lại, vẫn được `analyze()`/FinanceV2
  /// tính là "tiền vào"). Trả về danh sách map thô của `debt_payments`.
  static Future<List<Map<String, dynamic>>> findOrphanDebtPayments() async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT p.*
      FROM debt_payments p
      WHERE COALESCE(p.deleted, 0) != 1
        AND NOT EXISTS (
          SELECT 1 FROM debts d
          WHERE (d.firestoreId IS NOT NULL AND d.firestoreId != ''
                 AND d.firestoreId = p.debtFirestoreId)
             OR (p.debtId IS NOT NULL AND p.debtId != 0 AND d.id = p.debtId)
        )
      ORDER BY p.paidAt DESC
    ''');
  }

  /// Soft-delete 1 phiếu mồ côi + xếp hàng đồng bộ xóa.
  static Future<void> cleanOrphanDebtPayment(
    Map<String, dynamic> payment, {
    required String reason,
  }) async {
    final id = payment['id'] as int?;
    if (id == null) return;
    final db = await _db.database;
    await db.update(
      'debt_payments',
      {
        'deleted': 1,
        'isSynced': 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await SyncOrchestrator().enqueue(
      entityType: SyncEntityType.debtPayment,
      entityId: id,
      firestoreId: payment['firestoreId'] as String?,
      operation: SyncOperation.delete,
      data: {...payment, 'deleted': true},
    );
    await AuditService.logAction(
      action: 'RECONCILE_CLEAN_ORPHAN_DEBT_PAYMENT',
      entityType: 'debt_payment',
      entityId: (payment['firestoreId'] as String?) ?? 'dp_$id',
      summary:
          'Xóa phiếu mồ côi ${(payment['amount'] as int?) ?? 0}đ (debt ${payment['debtFirestoreId']}) — $reason',
      payload: {
        'amount': payment['amount'],
        'debtFirestoreId': payment['debtFirestoreId'],
        'reason': reason,
      },
    );
  }

  /// Công nợ KHÁCH có `totalAmount <= 0` nhưng đơn bán liên kết có
  /// `finalPrice > 0` → khoản khách nợ "tàng hình" ở tab Nợ phải thu.
  /// Trả về map công nợ kèm cột phụ `saleFinalPrice`.
  static Future<List<Map<String, dynamic>>>
  findZeroAmountCustomerDebts() async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT d.*,
        (COALESCE(s.totalPrice, 0) - COALESCE(s.discount, 0)) AS saleFinalPrice
      FROM debts d
      JOIN sales s ON s.firestoreId = d.linkedId
      WHERE COALESCE(d.deleted, 0) != 1
        AND (d.type = 'CUSTOMER_OWES' OR d.debtType = 'CUSTOMER_OWES')
        AND COALESCE(d.totalAmount, 0) <= 0
        AND (COALESCE(s.totalPrice, 0) - COALESCE(s.discount, 0)) > 0
        AND (s.deleted IS NULL OR s.deleted != 1)
      ORDER BY d.createdAt DESC
    ''');
  }

  /// Đặt lại `totalAmount` của công nợ về `finalPrice` của đơn bán + xếp hàng
  /// đồng bộ. `paidAmount` KHÔNG đụng (đã tính lại ở luồng thu tiền, PHASE 1.4).
  static Future<void> fixZeroAmountDebt(
    Map<String, dynamic> debt,
    int newAmount, {
    required String reason,
  }) async {
    final id = debt['id'] as int?;
    if (id == null || newAmount <= 0) return;
    final paid = (debt['paidAmount'] as int?) ?? 0;
    final newStatus = paid >= newAmount ? 'PAID' : 'ACTIVE';
    final db = await _db.database;
    await db.update(
      'debts',
      {
        'totalAmount': newAmount,
        'status': newStatus,
        'isSynced': 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await SyncOrchestrator().enqueue(
      entityType: SyncEntityType.debt,
      entityId: id,
      firestoreId: debt['firestoreId'] as String?,
      operation: SyncOperation.update,
      data: {...debt, 'totalAmount': newAmount, 'status': newStatus},
    );
    await AuditService.logAction(
      action: 'RECONCILE_FIX_ZERO_DEBT',
      entityType: 'debt',
      entityId: (debt['firestoreId'] as String?) ?? 'debt_$id',
      summary:
          '${debt['personName']}: totalAmount 0 → $newAmountđ — $reason',
      payload: {'newAmount': newAmount, 'reason': reason},
    );
  }

  // ══════════════════ AUDIT 2026-08-29: D-2 / D-3 / D-4 / L-4 ══════════════════

  /// D-2 — item trả hàng MỒ CÔI của shop hiện tại (không có phiếu cha).
  static Future<List<Map<String, dynamic>>> findOrphanSalesReturnItems() =>
      _db.findOrphanSalesReturnItems();

  /// D-2 — item trả hàng thuộc SHOP KHÁC còn sót trong local DB.
  static Future<List<Map<String, dynamic>>>
      findForeignShopSalesReturnItems() => _db.findForeignShopSalesReturnItems();

  /// Soft-delete 1 item trả hàng mồ côi + enqueue sync + audit. KHÔNG đụng tồn
  /// kho / tài chính: item mồ côi (không phiếu cha) đã không được `analyze()`
  /// tính (nó đọc bảng `sales_returns`) nên chỉ là rác dữ liệu.
  static Future<void> cleanOrphanSalesReturnItem(
    Map<String, dynamic> item, {
    required String reason,
  }) async {
    final id = item['id'] as int?;
    if (id == null) return;
    await _db.softDeleteSalesReturnItemById(id);
    await SyncOrchestrator().enqueue(
      entityType: SyncEntityType.salesReturnItem,
      entityId: id,
      firestoreId: item['firestoreId'] as String?,
      operation: SyncOperation.delete,
      data: {...item, 'deleted': true},
    );
    await AuditService.logAction(
      action: 'RECONCILE_CLEAN_ORPHAN_RETURN_ITEM',
      entityType: 'sales_return_item',
      entityId: (item['firestoreId'] as String?) ?? 'sri_$id',
      summary:
          'Xóa item trả hàng mồ côi ${(item['amount'] as int?) ?? 0}đ '
          '(${item['productName']}, phiếu ${item['salesReturnFirestoreId']}) — $reason',
      payload: {'amount': item['amount'], 'reason': reason},
    );
  }

  /// Xóa CỨNG item trả hàng của shop khác lọt vào local DB (rác account-switch).
  /// Hard-delete an toàn: bản ghi có shopId của shop khác → không phải dữ liệu
  /// của shop hiện tại, không sync đi đâu.
  static Future<int> removeForeignShopSalesReturnItems() async {
    final rows = await _db.findForeignShopSalesReturnItems();
    if (rows.isEmpty) return 0;
    final db = await _db.database;
    int n = 0;
    for (final r in rows) {
      final id = r['id'] as int?;
      if (id == null) continue;
      n += await db.delete('sales_return_items', where: 'id = ?', whereArgs: [id]);
    }
    await AuditService.logAction(
      action: 'RECONCILE_REMOVE_FOREIGN_RETURN_ITEMS',
      entityType: 'sales_return_item',
      entityId: 'batch',
      summary: 'Xóa $n item trả hàng của shop khác lọt vào local DB',
      payload: {'count': n},
    );
    return n;
  }

  /// D-3 — dòng `financial_activity_log` ghi CHI PHÍ nhưng KHÔNG có `expenses`
  /// tương ứng (chi phí bị xóa cứng / insert thất bại) → sổ đối soát dư 1
  /// khoản chi ma.
  static Future<List<Map<String, dynamic>>> findOrphanExpenseActivity() async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT f.* FROM financial_activity_log f
      WHERE f.activityType IN ('OPERATING_EXPENSE','UTILITY_EXPENSE','OTHER_EXPENSE','SALARY_PAYMENT')
        AND f.direction = 'OUT'
        AND NOT EXISTS (
          SELECT 1 FROM expenses e
          WHERE (e.deleted IS NULL OR e.deleted != 1)
            AND (
              e.firestoreId = 'exp_' || REPLACE(f.referenceId, 'expense_', 'pi_direct_operating_expense_expense_')
              OR e.firestoreId LIKE '%' || f.referenceId || '%'
              OR (e.amount = f.amount AND ABS(COALESCE(e.date, e.createdAt) - f.createdAt) < 86400000)
            )
        )
      ORDER BY f.createdAt DESC
    ''');
  }

  /// Đảo ngược 1 khoản chi ma: KHÔNG xóa dòng `financial_activity_log` (append-
  /// only) — thay vào đó ghi 1 dòng bù (IN cùng số tiền, type
  /// `EXPENSE_REVERSAL`) để net = 0, và hủy `payment_intents` liên quan.
  static Future<void> reverseOrphanExpenseActivity(
    Map<String, dynamic> fal, {
    required String reason,
  }) async {
    final amount = (fal['amount'] as num?)?.toInt() ?? 0;
    if (amount <= 0) return;
    final refId = fal['referenceId'] as String?;
    await FinancialActivityService.logCustomActivity(
      activityType: 'EXPENSE_REVERSAL',
      amount: amount,
      direction: 'IN',
      paymentMethod: (fal['paymentMethod'] as String?) ?? 'TIỀN MẶT',
      title: 'Đảo khoản chi ma: ${fal['title'] ?? ''}',
      description: reason,
      referenceType: 'reconcile_reversal',
      referenceId: refId,
    );
    // Hủy payment_intent COMPLETED/PENDING trỏ tới cùng referenceId.
    if (refId != null && refId.isNotEmpty) {
      final db = await _db.database;
      await db.update(
        'payment_intents',
        {'status': 'CANCELLED', 'isSynced': 0, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
        where: "referenceId = ? AND status != 'CANCELLED'",
        whereArgs: [refId],
      );
    }
    await AuditService.logAction(
      action: 'RECONCILE_REVERSE_ORPHAN_EXPENSE',
      entityType: 'financial_activity_log',
      entityId: (fal['firestoreId'] as String?) ?? 'fal_${fal['id']}',
      summary: 'Đảo khoản chi ma ${amount}đ (${fal['title']}) — $reason',
      payload: {'amount': amount, 'referenceId': refId, 'reason': reason},
    );
  }

  /// D-4 — sản phẩm có `status` mâu thuẫn `quantity`: status=0 (đã bán/ẩn) mà
  /// quantity>0 (còn hàng). KHÔNG tự sửa số lượng — chỉ liệt kê để user kiểm kho
  /// thực tế. Báo cáo VỐN TỒN KHO của app vốn đã lọc `status` nên không tính
  /// nhầm các SKU này.
  static Future<List<Map<String, dynamic>>> findStockStatusMismatch() async {
    final db = await _db.database;
    final shopId = UserService.getShopIdSync();
    return db.rawQuery('''
      SELECT * FROM products
      WHERE (deleted IS NULL OR deleted != 1)
        AND (shopId IS NULL OR shopId = '' OR shopId = ?)
        AND status = 0 AND COALESCE(quantity, 0) > 0
      ORDER BY COALESCE(quantity,0) * COALESCE(cost,0) DESC
    ''', [shopId ?? '']);
  }

  /// L-4 — payment_intent còn "sống" (COMPLETED/PENDING) của 1 giao dịch đã
  /// VOID (có `SALE_VOID`/`REPAIR_VOID` trong `financial_activity_log`). Chỉ
  /// lấy intent trỏ tới giao dịch VOID *tường minh* — không đụng intent cũ hợp lệ.
  static Future<List<Map<String, dynamic>>> findVoidedTxnPaymentIntents() async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT pi.* FROM payment_intents pi
      WHERE pi.status IN ('COMPLETED','PENDING')
        AND pi.referenceId IS NOT NULL AND pi.referenceId != ''
        AND EXISTS (
          SELECT 1 FROM financial_activity_log f
          WHERE f.activityType IN ('SALE_VOID','REPAIR_VOID')
            AND (f.referenceId = pi.referenceId
                 OR pi.referenceId LIKE '%' || f.referenceId || '%'
                 OR f.referenceId LIKE '%' || pi.referenceId || '%')
        )
      ORDER BY pi.createdAt DESC
    ''');
  }

  /// Hủy 1 payment_intent của giao dịch đã VOID (chỉ đổi status → CANCELLED,
  /// KHÔNG đụng tiền: engine không SUM payment_intents; đây chỉ là dọn lifecycle).
  static Future<void> cancelVoidedTxnPaymentIntent(
    Map<String, dynamic> pi, {
    required String reason,
  }) async {
    final id = pi['id'] as int?;
    if (id == null) return;
    final db = await _db.database;
    await db.update(
      'payment_intents',
      {'status': 'CANCELLED', 'isSynced': 0, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
    await AuditService.logAction(
      action: 'RECONCILE_CANCEL_VOIDED_INTENT',
      entityType: 'payment_intent',
      entityId: (pi['firestoreId'] as String?) ?? (pi['intentId'] as String?) ?? 'pi_$id',
      summary:
          'Hủy payment_intent ${(pi['amount'] as num?)?.toInt() ?? 0} đ '
          'của giao dịch đã VOID (${pi['referenceId']}) — $reason',
      payload: {'amount': pi['amount'], 'referenceId': pi['referenceId'], 'reason': reason},
    );
  }

  // ─────────────────────────── KHO & SẢN PHẨM ──────────────────────────

  static Future<void> adjustPartQuantity(
    int partId, {
    required int newQuantity,
    required String reason,
    required String partName,
  }) async {
    final oldPart = await _db.getPartById(partId);
    final oldQuantity = oldPart?['quantity'] as int? ?? 0;
    await _db.updatePart(partId, {'quantity': newQuantity});
    await AuditService.logAction(
      action: 'STOCK_ADJUSTMENT',
      entityType: 'part',
      entityId: 'part_$partId',
      summary: '$partName: $oldQuantity → $newQuantity',
      payload: {
        'oldQuantity': oldQuantity,
        'newQuantity': newQuantity,
        'reason': reason,
      },
    );
  }

  static Future<void> adjustProductQuantity(
    Product p, {
    required int newQuantity,
    required String reason,
  }) async {
    final oldQuantity = p.quantity;
    await _db.updateProductMap(p.id!, {
      'quantity': newQuantity,
      'status': newQuantity > 0 ? 1 : 0,
      'isSynced': 0,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await AuditService.logAction(
      action: 'STOCK_ADJUSTMENT',
      entityType: 'product',
      entityId: p.firestoreId ?? 'product_${p.id}',
      summary: '${p.name}: $oldQuantity → $newQuantity',
      payload: {
        'oldQuantity': oldQuantity,
        'newQuantity': newQuantity,
        'reason': reason,
      },
    );
  }

  /// Trả về số công nợ NCC còn liên kết với linh kiện này (nếu có) để cảnh
  /// báo trước khi xóa — không chặn, chỉ cảnh báo.
  static Future<int> countLinkedSupplierDebtsForPart(String partId) async {
    if (partId.isEmpty) return 0;
    final debts = await _db.getDebtsByProductId(partId);
    return debts.length;
  }

  static Future<void> deletePart(int partId, {required String partName}) async {
    await _db.updatePart(partId, {'deleted': 1});
    await AuditService.logAction(
      action: 'RECONCILE_DELETE_PART',
      entityType: 'part',
      entityId: 'part_$partId',
      summary: partName,
    );
  }

  static Future<void> deleteProduct(Product p) async {
    await _db.softDeleteProduct(p.id!);
    await AuditService.logAction(
      action: 'RECONCILE_DELETE_PRODUCT',
      entityType: 'product',
      entityId: p.firestoreId ?? 'product_${p.id}',
      summary: p.name,
    );
  }
}
