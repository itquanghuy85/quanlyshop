import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import '../models/product_model.dart';
import '../services/user_service.dart';
import 'repair_detail_view.dart';
import 'sale_detail_view.dart';
import 'inventory_view.dart';

class QrScanView extends StatefulWidget {
  final String role;
  const QrScanView({super.key, this.role = 'user'});

  @override
  State<QrScanView> createState() => _QrScanViewState();
}

class _QrScanViewState extends State<QrScanView> {
  final MobileScannerController _controller = MobileScannerController();
  final DBHelper _db = DBHelper();
  bool _handling = false;

  Future<void> _handleBarcode(String raw) async {
    if (_handling) return;
    setState(() => _handling = true);

    final key = raw.trim();
    print("QR_SCAN: Đang xử lý mã: $key");

    try {
      // 1. XỬ LÝ MÃ QR ĐƠN SỬA CHỮA (Tiền tố 'check:')
      if (key.startsWith('check:')) {
        final fId = key.replaceAll('check:', '');
        final Repair? r = await _db.getRepairByFirestoreId(fId);
        if (r != null && mounted) {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => RepairDetailView(repair: r)));
          if (mounted) Navigator.pop(context);
          return;
        }
      }

      // 2. XỬ LÝ MÃ QR ĐƠN BÁN HÀNG (Tiền tố 'sale:')
      if (key.startsWith('sale:')) {
        final fId = key.replaceAll('sale:', '');
        final SaleOrder? s = await _db.getSaleByFirestoreId(fId);
        if (s != null && mounted) {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailView(sale: s)));
          if (mounted) Navigator.pop(context);
          return;
        }
      }

      // 3. XỬ LÝ MÃ QR SẢN PHẨM / IMEI (Dùng cho tem kho)
      final allProds = await _db.getAllProducts();
      final findProd = allProds.where((p) => p.imei == key || p.firestoreId == key).toList();
      if (findProd.isNotEmpty && mounted) {
        // Mở màn hình kho và focus vào sản phẩm này (hoặc hiện thông báo nhanh)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("TÌM THẤY MÁY: ${findProd.first.name}"), backgroundColor: Colors.blue));
        if (mounted) Navigator.pop(context, findProd.first.imei); // Trả về IMEI để màn hình gọi xử lý
        return;
      }

      // 4. KIỂM TRA MÃ MỜI SHOP
      if (key.startsWith('{') && key.contains('invite_code')) {
        // Logic mời shop cũ của bạn...
      }

      // NẾU KHÔNG TÌM THẤY GÌ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KHÔNG TÌM THẤY DỮ LIỆU TƯƠNG ỨNG'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _handling = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handling) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw != null) _handleBarcode(raw);
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QUÉT MÃ QR THÔNG MINH'), actions: [IconButton(icon: const Icon(Icons.flash_on), onPressed: () => _controller.toggleTorch())]),
      body: Stack(children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        Center(child: Container(width: 260, height: 260, decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 4)))),
        if (_handling) const Center(child: CircularProgressIndicator()),
      ]),
    );
  }
}
