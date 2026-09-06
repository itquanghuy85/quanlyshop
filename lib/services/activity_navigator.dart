import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/repair_partner_model.dart';
import '../models/sale_order_model.dart';
import '../models/supplier_model.dart';
import '../services/repair_partner_service.dart';
import '../services/supplier_service.dart';
import '../views/debt_view.dart';
import '../views/expense_view.dart';
import '../views/payment_request_chat_view.dart';
import '../views/repair_detail_view.dart';
import '../views/repair_partner_detail_view.dart';
import '../views/sale_detail_view.dart';
import '../views/supplier_detail_view.dart';

/// Mở màn chi tiết từ một dòng hoạt động, dùng chung cho MỌI danh sách hoạt
/// động trong app.
///
/// Trước đây mỗi danh sách tự viết lấy một đoạn `switch` riêng và mỗi đoạn hiểu
/// được một tập loại khác nhau:
///
/// - `ActivityFeedCard` ("HOẠT ĐỘNG HÔM NAY" ở Trang chủ) chỉ mở được `sale` và
///   `repair`. Năm loại còn lại — chi phí, thu/trả nợ, trả NCC, thanh toán đối
///   tác, công nợ mới — bấm vào **không có gì xảy ra**, mà nhìn cũng không biết
///   là bấm được hay không.
/// - `RecentActivityView` ("HOẠT ĐỘNG GẦN ĐÂY", mở từ nút *Xem tất cả*) thì
///   **không có dòng nào bấm được**: model `RecentActivityItem` còn chẳng mang
///   theo mã tham chiếu.
/// - `main.dart` có sẵn một bộ điều hướng thứ ba cho thông báo đẩy, cũng chỉ
///   biết `sale` và `repair`.
///
/// Gom về một chỗ để thêm một loại đích là cả ba danh sách cùng mở được, không
/// còn cảnh sửa một nơi quên hai nơi kia.
class ActivityNavigator {
  ActivityNavigator._();

  /// Chuẩn hoá tên loại: dữ liệu thật ghi lẫn lộn `'REPAIR'` và `'repair'`,
  /// `'debt_payment'` và `'debtPayment'`.
  static String _norm(String? raw) =>
      (raw ?? '').trim().toLowerCase().replaceAll('-', '_');

  /// Đích đến cho từng loại. `null` = chưa mở được.
  ///
  /// Giữ một bảng duy nhất để `canOpen` và `open` không bao giờ lệch nhau —
  /// lệch là ra đúng cái lỗi đang phải sửa: hiện mũi tên ">" mà bấm không đi
  /// đâu, hoặc mở được nhưng không hiện mũi tên nên không ai biết mà bấm.
  static const Map<String, String> _targets = <String, String>{
    'sale': 'sale',
    'sales': 'sale',
    'repair': 'repair',
    'repairs': 'repair',
    // `parts_payment` ghi `referenceId = repair.firestoreId` (xem
    // `repair_detail_view`), nên đích của nó là chính đơn sửa đó.
    'parts_payment': 'repair',
    'expense': 'expense',
    'expenses': 'expense',
    'quick_income': 'expense',
    'quick_expense': 'expense',
    'debt': 'debt',
    'debts': 'debt',
    'debt_payment': 'debt',
    'debtpayment': 'debt',
    'debt_payments': 'debt',
    'repair_debt': 'debt',
    'customer_debt': 'debt',
    'shop_owes': 'debt_payable',
    'supplier_debt': 'debt_payable',
    'supplier_payment': 'supplier',
    'supplier_payments': 'supplier',
    'supplier': 'supplier',
    'partner_payment': 'partner',
    'repair_partner_payment': 'partner',
    'repair_partner_service': 'partner',
    'repair_partner': 'partner',
    'payment_request': 'payment_request',
  };

  /// Những loại CỐ Ý chưa mở được, ghi ra để lần sau khỏi tưởng là bỏ sót:
  ///
  /// - `stock_entry`, `purchase_order` — `referenceId` là mã phiếu nhập / mã
  ///   thanh toán, chưa có hàm tra ra `ImportOrder` từ mã đó.
  /// - `reconcile_reversal`, `payment_intent_failed` — là bản ghi đối soát /
  ///   lỗi, không trỏ tới một chứng từ nào để mở.
  ///
  /// Các loại này `canOpen` trả về false ⇒ không hiện mũi tên, không bấm được —
  /// đúng thực tế, hơn là hiện mũi tên rồi bấm không đi đâu.

  /// Loại này có mở được màn chi tiết không.
  ///
  /// `sale` / `repair` cần mã tham chiếu mới tra được bản ghi; các loại còn lại
  /// mở màn danh sách nên không cần mã.
  static bool canOpen({String? type, String? firestoreId, int? localId}) {
    final target = _targets[_norm(type)];
    if (target == null) return false;
    if (target == 'sale' || target == 'repair') {
      return (firestoreId ?? '').trim().isNotEmpty;
    }
    if (target == 'supplier' || target == 'partner') {
      // Không có id thì vẫn mở được, chỉ là về màn danh sách chung.
      return true;
    }
    return true;
  }

  /// Mở màn chi tiết tương ứng.
  ///
  /// [firestoreId] dùng cho đơn bán / đơn sửa. [localId] là khoá SQLite của
  /// nhà cung cấp hoặc đối tác sửa chữa. [expenseMode] là `'THU'` / `'CHI'` để
  /// màn Thu Chi mở đúng tab.
  static Future<void> open(
    BuildContext context, {
    required String? type,
    String? firestoreId,
    int? localId,
    String? expenseMode,
    /// `true` khi dòng hoạt động là khoản SHOP NỢ (phải trả) — để màn Công nợ
    /// mở thẳng tab "Phải trả" thay vì tab "Phải thu" mặc định.
    bool payable = false,
  }) async {
    final target = _targets[_norm(type)];
    if (target == null) return;

    final db = DBHelper();
    final id = (firestoreId ?? '').trim();

    try {
      switch (target) {
        case 'sale':
          final sale = await _findSale(db, id);
          if (!context.mounted) return;
          if (sale == null) {
            _notFound(context, 'đơn bán');
            return;
          }
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SaleDetailView(sale: sale)),
          );
          return;

        case 'repair':
          final repair = await _findRepair(db, id);
          if (!context.mounted) return;
          if (repair == null) {
            _notFound(context, 'đơn sửa');
            return;
          }
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RepairDetailView(repair: repair)),
          );
          return;

        case 'expense':
          if (!context.mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExpenseView(
                initialMode: (expenseMode ?? 'CHI').toUpperCase() == 'THU'
                    ? 'THU'
                    : 'CHI',
              ),
            ),
          );
          return;

        case 'debt':
        case 'debt_payable':
          // Chưa có màn chi tiết cho từng khoản nợ — đưa về màn Công nợ, mở
          // đúng tab Phải thu / Phải trả. Vẫn hơn hẳn bấm mà đứng im.
          if (!context.mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DebtView(
                initialTab: (payable || target == 'debt_payable') ? 1 : 0,
              ),
            ),
          );
          return;

        case 'supplier':
          final supplier = await _findSupplier(localId);
          if (!context.mounted) return;
          if (supplier == null) {
            _notFound(context, 'nhà cung cấp');
            return;
          }
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SupplierDetailView(supplier: supplier),
            ),
          );
          return;

        case 'payment_request':
          if (!context.mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaymentRequestChatView()),
          );
          return;

        case 'partner':
          final partner = await _findPartner(localId);
          if (!context.mounted) return;
          if (partner == null) {
            _notFound(context, 'đối tác sửa chữa');
            return;
          }
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RepairPartnerDetailView(partner: partner),
            ),
          );
          return;
      }
    } catch (e) {
      debugPrint('ActivityNavigator.open($type/$id) error: $e');
      if (!context.mounted) return;
      _notFound(context, 'mục này');
    }
  }

  /// Tra đơn bán theo mã — thử `firestoreId` trước, rồi tới khoá SQLite.
  ///
  /// Hai nguồn ghi mã theo hai kiểu khác nhau:
  /// `financial_activity_log.referenceId` là **firestoreId**, còn
  /// `audit_logs.targetId` lại là **id nội bộ** (`r.id.toString()`, xem
  /// `AuditService.logAction` được gọi ở `repair_detail_view`). Chỉ tra theo
  /// firestoreId thì mọi dòng đến từ nhật ký hệ thống đều bấm không ra gì —
  /// mà vẫn hiện mũi tên ">", đúng kiểu lỗi đang phải sửa.
  static Future<SaleOrder?> _findSale(DBHelper db, String id) async {
    if (id.isEmpty) return null;
    final byFid = await db.getSaleByFirestoreId(id);
    if (byFid != null) return byFid;
    final localId = int.tryParse(id);
    return localId == null ? null : db.getSaleById(localId);
  }

  static Future<Repair?> _findRepair(DBHelper db, String id) async {
    if (id.isEmpty) return null;
    final byFid = await db.getRepairByFirestoreId(id);
    if (byFid != null) return byFid;
    final localId = int.tryParse(id);
    return localId == null ? null : db.getRepairById(localId);
  }

  static Future<Supplier?> _findSupplier(int? id) async {
    if (id == null) return null;
    final list = await SupplierService().getSuppliers();
    for (final s in list) {
      if (s.id == id) return s;
    }
    return null;
  }

  static Future<RepairPartner?> _findPartner(int? id) async {
    if (id == null) return null;
    return RepairPartnerService().getRepairPartnerById(id);
  }

  /// Nói rõ vì sao không mở được, thay vì im lặng.
  ///
  /// Bản cũ `return` không kèm gì khi tra không ra bản ghi (thường là do máy
  /// này chưa đồng bộ xong), nên người dùng bấm mãi mà tưởng app đơ.
  static void _notFound(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Không tìm thấy $what để mở — có thể máy chưa đồng bộ xong.'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
