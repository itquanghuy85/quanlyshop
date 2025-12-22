import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import 'repair_detail_view.dart';
import 'sale_detail_view.dart';

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
    if (key.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR không hợp lệ')),
        );
      }
      if (mounted) setState(() => _handling = false);
      return;
    }

    try {
      // Ưu tiên tìm đơn sửa, sau đó đến đơn bán
      final Repair? r = await _db.getRepairByFirestoreId(key);
      if (!mounted) return;
      if (r != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RepairDetailView(repair: r),
          ),
        );
        if (mounted) setState(() => _handling = false);
        return;
      }

      final SaleOrder? s = await _db.getSaleByFirestoreId(key);
      if (!mounted) return;
      if (s != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SaleDetailView(sale: s),
          ),
        );
        if (mounted) setState(() => _handling = false);
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tìm thấy đơn tương ứng với QR: $key')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xử lý QR: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _handling = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handling) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    _handleBarcode(raw);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QUÉT QR ĐƠN HÀNG'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 3),
              ),
            ),
          ),
          if (_handling)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Đang mở đơn, vui lòng chờ...',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
