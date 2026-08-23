import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../services/stock_entry_service.dart';
import 'supplier_picker_sheet.dart';

const kPaymentMethods = ['TIỀN MẶT', 'CHUYỂN KHOẢN', 'CÔNG NỢ'];

String paymentMethodLabel(String? method) {
  switch (method) {
    case 'CÔNG NỢ':
      return 'Công nợ';
    case 'CHUYỂN KHOẢN':
      return 'Chuyển khoản';
    case 'TIỀN MẶT':
      return 'Tiền mặt';
    default:
      return method ?? 'Không rõ';
  }
}

/// Sửa NCC của 1 phiếu nhập kho — mở thẳng bộ chọn NCC (không qua dialog
/// trung gian), rồi áp dụng ngay khi chọn xong. `resolveEntryId` cho phép
/// tra cứu entryId có độ trễ (vd. tìm qua IMEI) — chỉ chạy SAU khi người
/// dùng đã chọn xong NCC, tránh tra cứu thừa nếu họ huỷ giữa chừng.
/// Trả về Map kết quả nếu lưu thành công (caller tự cập nhật UI), `null`
/// nếu huỷ/không tìm thấy phiếu gốc/lưu thất bại.
Future<Map<String, dynamic>?> pickAndApplySupplierCorrection({
  required BuildContext context,
  required Future<String?> Function() resolveEntryId,
  required String currentPaymentMethod,
  void Function()? onEntryNotFound,
}) async {
  final picked = await showSupplierPickerSheet(context);
  if (picked == null || !context.mounted) return null;
  final newSupplierName = (picked['name'] as String?)?.trim() ?? '';
  if (newSupplierName.isEmpty) return null;

  final entryId = await resolveEntryId();
  if (entryId == null) {
    onEntryNotFound?.call();
    return null;
  }
  if (!context.mounted) return null;

  return _applyCorrection(
    context: context,
    entryId: entryId,
    newSupplierId: picked['id']?.toString(),
    newSupplierName: newSupplierName,
    newPaymentMethod: currentPaymentMethod,
  );
}

/// Sửa phương thức thanh toán — hiện dropdown 3 lựa chọn ngay tại vị trí đã
/// bấm (dùng `PopupMenuButton`, không qua dialog trung gian). Bọc widget
/// hiện tại (vd. ô hiển thị phương thức) làm `child` để trở thành nút bấm.
class PaymentMethodPickerMenu extends StatelessWidget {
  final Future<String?> Function() resolveEntryId;
  final String currentSupplierName;
  final String currentPaymentMethod;
  final Widget child;
  final void Function(Map<String, dynamic> result) onApplied;
  final void Function()? onEntryNotFound;

  const PaymentMethodPickerMenu({
    super.key,
    required this.resolveEntryId,
    required this.currentSupplierName,
    required this.currentPaymentMethod,
    required this.child,
    required this.onApplied,
    this.onEntryNotFound,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      itemBuilder: (ctx) => kPaymentMethods
          .map((m) => PopupMenuItem(value: m, child: Text(paymentMethodLabel(m))))
          .toList(),
      onSelected: (selected) async {
        if (selected == currentPaymentMethod) return;
        final entryId = await resolveEntryId();
        if (entryId == null) {
          onEntryNotFound?.call();
          return;
        }
        if (!context.mounted) return;
        final result = await _applyCorrection(
          context: context,
          entryId: entryId,
          newSupplierId: null,
          newSupplierName: currentSupplierName,
          newPaymentMethod: selected,
        );
        if (result != null) onApplied(result);
      },
      child: child,
    );
  }
}

/// Bottom sheet gọn 2 dòng "Nhà cung cấp"/"Phương thức thanh toán" — bấm
/// dòng nào sửa ngay dòng đó (không có bước Lưu/Huỷ riêng, chọn xong là lưu
/// luôn). Dùng cho nơi không có sẵn 1 field cụ thể để bọc trực tiếp (vd. mở
/// từ icon sửa trên AppBar). Trả về Map kết quả của lần sửa cuối cùng nếu có
/// ít nhất 1 lần sửa thành công, `null` nếu đóng sheet mà không đổi gì.
Future<Map<String, dynamic>?> showCorrectSupplierPaymentSheet({
  required BuildContext context,
  required String entryId,
  required String currentSupplierName,
  required String currentPaymentMethod,
}) async {
  Map<String, dynamic>? lastResult;
  Future<String?> resolveEntryId() async => entryId;

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final supplierName = (lastResult?['supplierName'] as String?) ?? currentSupplierName;
          final paymentMethod = (lastResult?['paymentMethod'] as String?) ?? currentPaymentMethod;
          return SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sửa NCC / thanh toán',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      final result = await pickAndApplySupplierCorrection(
                        context: sheetCtx,
                        resolveEntryId: resolveEntryId,
                        currentPaymentMethod: paymentMethod,
                      );
                      if (result != null) {
                        lastResult = result;
                        setSheetState(() {});
                      }
                    },
                    child: sheetPickerRow(Icons.store_outlined, 'Nhà cung cấp', supplierName),
                  ),
                  const SizedBox(height: 8),
                  PaymentMethodPickerMenu(
                    resolveEntryId: resolveEntryId,
                    currentSupplierName: supplierName,
                    currentPaymentMethod: paymentMethod,
                    onApplied: (result) {
                      lastResult = result;
                      setSheetState(() {});
                    },
                    child: sheetPickerRow(
                      Icons.payments_outlined,
                      'Phương thức thanh toán',
                      paymentMethodLabel(paymentMethod),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  return lastResult;
}

/// Ô hiển thị dạng "tappable" màu indigo dùng chung cho NCC/thanh toán —
/// export để `inventory_view.dart` dùng lại đúng kiểu dáng.
Widget sheetPickerRow(IconData icon, String label, String value) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.indigo.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Colors.indigo),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.indigo.shade300)),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.indigo),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const Icon(Icons.edit_outlined, size: 16, color: Colors.indigo),
      ],
    ),
  );
}

/// Cảnh báo nếu ngày phiếu đã chốt quỹ, rồi gọi
/// `StockEntryService.correctSupplierAndPayment`. Dùng chung cho cả 2 kiểu
/// sửa (NCC riêng / phương thức thanh toán riêng) ở trên.
Future<Map<String, dynamic>?> _applyCorrection({
  required BuildContext context,
  required String entryId,
  String? newSupplierId,
  required String newSupplierName,
  required String newPaymentMethod,
}) async {
  final entry = await StockEntryService().getEntry(entryId);
  final confirmedAt = entry?.confirmedAt;
  if (confirmedAt != null) {
    final dateKey = DateFormat('yyyy-MM-dd').format(confirmedAt);
    final closing = await DBHelper().getClosingByDateKey(dateKey);
    if (closing != null) {
      if (!context.mounted) return null;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ngày này đã chốt quỹ'),
          content: const Text(
            'Ngày nhập kho của phiếu này đã được chốt quỹ. Số liệu đã chốt sẽ KHÔNG tự thay đổi theo — chỉ công nợ/sổ quỹ hiện tại được cập nhật. Vẫn muốn tiếp tục sửa?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tiếp tục')),
          ],
        ),
      );
      if (proceed != true) return null;
    }
  }
  if (!context.mounted) return null;

  final ok = await StockEntryService().correctSupplierAndPayment(
    entryId: entryId,
    newSupplierId: newSupplierId,
    newSupplierName: newSupplierName,
    newPaymentMethod: newPaymentMethod,
  );
  if (!ok) return null;

  return {
    'supplierId': newSupplierId,
    'supplierName': newSupplierName,
    'paymentMethod': newPaymentMethod,
    'paymentStatus': newPaymentMethod == 'CÔNG NỢ' ? 'DEBT' : 'PAID',
  };
}
