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

/// Mở dialog sửa NCC/phương thức thanh toán của 1 phiếu nhập kho đã xác nhận
/// (gọi `StockEntryService.correctSupplierAndPayment` — tự khớp lại công nợ
/// NCC/sổ quỹ, xem chi tiết ở service đó). Dùng chung cho cả màn Chi tiết
/// phiếu nhập kho và màn Sửa sản phẩm (khi tìm được đúng phiếu gốc qua IMEI).
///
/// Trả về Map `{supplierId, supplierName, paymentMethod, paymentStatus}` nếu
/// lưu thành công để caller tự cập nhật UI, hoặc `null` nếu người dùng huỷ
/// hoặc lưu thất bại (đã tự hiện snackbar lỗi từ service).
Future<Map<String, dynamic>?> showCorrectSupplierPaymentDialog({
  required BuildContext context,
  required String entryId,
  String? currentSupplierId,
  required String currentSupplierName,
  required String currentPaymentMethod,
  int? importDateMs,
}) async {
  // Cảnh báo nếu ngày nhập kho đã chốt quỹ — số đã chốt sẽ không tự đổi theo
  if (importDateMs != null) {
    final dateKey =
        DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(importDateMs));
    final closing = await DBHelper().getClosingByDateKey(dateKey);
    if (closing != null && context.mounted) {
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

  String? pickedSupplierId = currentSupplierId;
  String pickedSupplierName = currentSupplierName;
  String pickedPaymentMethod =
      kPaymentMethods.contains(currentPaymentMethod) ? currentPaymentMethod : kPaymentMethods.first;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Sửa NCC / thanh toán'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nhà cung cấp', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showSupplierPickerSheet(ctx);
                if (picked == null) return;
                setDialogState(() {
                  pickedSupplierId = picked['id']?.toString();
                  pickedSupplierName = picked['name'] as String? ?? pickedSupplierName;
                });
              },
              icon: const Icon(Icons.store, size: 18),
              label: Text(
                pickedSupplierName.isEmpty ? 'Chọn nhà cung cấp' : pickedSupplierName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Phương thức thanh toán', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            DropdownButton<String>(
              value: pickedPaymentMethod,
              isExpanded: true,
              items: kPaymentMethods
                  .map((m) => DropdownMenuItem(value: m, child: Text(paymentMethodLabel(m))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setDialogState(() => pickedPaymentMethod = v);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return null;
  if (pickedSupplierName.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vui lòng chọn nhà cung cấp')),
    );
    return null;
  }

  final ok = await StockEntryService().correctSupplierAndPayment(
    entryId: entryId,
    newSupplierId: pickedSupplierId,
    newSupplierName: pickedSupplierName.trim(),
    newPaymentMethod: pickedPaymentMethod,
  );
  if (!ok) return null;

  return {
    'supplierId': pickedSupplierId,
    'supplierName': pickedSupplierName.trim(),
    'paymentMethod': pickedPaymentMethod,
    'paymentStatus': pickedPaymentMethod == 'CÔNG NỢ' ? 'DEBT' : 'PAID',
  };
}
