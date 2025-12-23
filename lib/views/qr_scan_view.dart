import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import '../services/user_service.dart';
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
      // Kiểm tra xem có phải là QR từ tem điện thoại không
      if (key.startsWith('{') && key.contains('phone_label')) {
        await _handlePhoneLabelQR(key);
        if (mounted) setState(() => _handling = false);
        return;
      }

      // Kiểm tra xem có phải là QR mã mời không
      if (key.startsWith('{') && key.contains('invite_code')) {
        await _handleInviteCodeQR(key);
        if (mounted) setState(() => _handling = false);
        return;
      }

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

  Future<void> _handlePhoneLabelQR(String qrData) async {
    try {
      // Parse JSON data từ QR
      final data = _parsePhoneLabelData(qrData);
      if (data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dữ liệu QR tem điện thoại không hợp lệ')),
          );
        }
        return;
      }

      // Tạo đơn hàng sửa chữa nhanh từ thông tin tem
      final repair = Repair(
        customerName: 'KHÁCH HÀNG QUÉT TEM',
        phone: 'CHƯA CÓ',
        model: data['name'] ?? 'Điện thoại từ tem',
        issue: 'Sửa chữa điện thoại từ tem QR',
        accessories: data['accessories'] ?? '',
        address: 'CHƯA CÓ',
        price: int.tryParse(data['price']?.replaceAll(',', '') ?? '0') ?? 0,
        status: 0, // Received
        createdAt: DateTime.now().millisecondsSinceEpoch,
        lastCaredAt: DateTime.now().millisecondsSinceEpoch,
        isSynced: false,
        deleted: false,
        imei: data['imei'],
        color: data['color'],
        condition: data['condition'],
      );

      // Lưu vào database
      final docId = await _db.insertRepair(repair);

      if (docId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo đơn hàng từ tem điện thoại!')),
        );

        // Mở chi tiết đơn hàng vừa tạo
        final createdRepair = await _db.getRepairById(docId);
        if (createdRepair != null && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RepairDetailView(repair: createdRepair),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lỗi khi tạo đơn hàng từ tem')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xử lý tem điện thoại: $e')),
        );
      }
    }
  }

  Map<String, dynamic>? _parsePhoneLabelData(String qrData) {
    try {
      // Simple JSON parsing - tìm các trường trong string
      final Map<String, dynamic> data = {};

      // Extract type
      if (!qrData.contains('phone_label')) return null;

      // Extract name
      final nameMatch = RegExp(r'name: ([^,}]+)').firstMatch(qrData);
      if (nameMatch != null) {
        data['name'] = nameMatch.group(1)?.replaceAll("'", '').trim();
      }

      // Extract imei
      final imeiMatch = RegExp(r'imei: ([^,}]+)').firstMatch(qrData);
      if (imeiMatch != null) {
        data['imei'] = imeiMatch.group(1)?.replaceAll("'", '').trim();
      }

      // Extract color
      final colorMatch = RegExp(r'color: ([^,}]+)').firstMatch(qrData);
      if (colorMatch != null) {
        data['color'] = colorMatch.group(1)?.replaceAll("'", '').trim();
      }

      // Extract price
      final priceMatch = RegExp(r'price: ([^,}]+)').firstMatch(qrData);
      if (priceMatch != null) {
        data['price'] = priceMatch.group(1)?.replaceAll("'", '').trim();
      }

      // Extract condition
      final conditionMatch = RegExp(r'condition: ([^,}]+)').firstMatch(qrData);
      if (conditionMatch != null) {
        data['condition'] = conditionMatch.group(1)?.replaceAll("'", '').trim();
      }

      // Extract accessories
      final accessoriesMatch = RegExp(r'accessories: ([^,}]+)').firstMatch(qrData);
      if (accessoriesMatch != null) {
        data['accessories'] = accessoriesMatch.group(1)?.replaceAll("'", '').trim();
      }

      return data;
    } catch (e) {
      return null;
    }
  }

  Future<void> _handleInviteCodeQR(String qrData) async {
    try {
      // Parse JSON data từ QR mã mời
      final data = _parseInviteCodeData(qrData);
      if (data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dữ liệu QR mã mời không hợp lệ')),
          );
        }
        return;
      }

      final code = data['code'];
      final shopName = data['shopName'];

      // Hiển thị dialog xác nhận tham gia shop
      final join = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('THAM GIA SHOP'),
          content: Text('Bạn có muốn tham gia shop "$shopName" không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('HỦY'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('THAM GIA'),
            ),
          ],
        ),
      );

      if (join != true) return;

      // Sử dụng mã mời
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cần đăng nhập để tham gia shop')),
          );
        }
        return;
      }

      final success = await UserService.useInviteCode(code, user.uid);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã tham gia shop "$shopName" thành công!')),
        );
        // Có thể navigate về home hoặc refresh app state
        Navigator.of(context).pop(); // Đóng scanner
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mã mời không hợp lệ hoặc đã được sử dụng')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xử lý mã mời: $e')),
        );
      }
    }
  }

  Map<String, dynamic>? _parseInviteCodeData(String qrData) {
    try {
      // Parse JSON từ QR
      final jsonStart = qrData.indexOf('{');
      final jsonEnd = qrData.lastIndexOf('}') + 1;
      if (jsonStart == -1 || jsonEnd == -1) return null;

      final jsonStr = qrData.substring(jsonStart, jsonEnd);
      // Simple JSON parsing cho invite code
      final Map<String, dynamic> data = {};

      // Extract type
      if (!jsonStr.contains('invite_code')) return null;

      // Extract code
      final codeMatch = RegExp(r'"code"\s*:\s*"([^"]+)"').firstMatch(jsonStr);
      if (codeMatch != null) {
        data['code'] = codeMatch.group(1);
      }

      // Extract shopName
      final shopMatch = RegExp(r'"shopName"\s*:\s*"([^"]+)"').firstMatch(jsonStr);
      if (shopMatch != null) {
        data['shopName'] = shopMatch.group(1);
      }

      return data['code'] != null && data['shopName'] != null ? data : null;
    } catch (e) {
      return null;
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
        title: const Text('QUÉT QR ĐƠN HÀNG & TEM'),
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
