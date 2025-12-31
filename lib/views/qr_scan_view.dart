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

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

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

      // Kiểm tra QR kiểm tra sản phẩm trong kho
      if (key.startsWith('check_inv:')) {
        await _handleInventoryCheckQR(key);
        if (mounted) setState(() => _handling = false);
        return;
      }

      // Kiểm tra QR đơn hàng (có thể là repair_ hoặc sale_)
      if (key.startsWith('repair_') || key.startsWith('sale_') || key.startsWith('inv_check_')) {
        await _handleOrderQR(key);
        if (mounted) setState(() => _handling = false);
        return;
      }

      // Kiểm tra xem có phải là ID đơn hàng không (firestoreId)
      if (key.length > 10 && (key.startsWith('rep_') || key.startsWith('sale_') || key.contains('_'))) {
        await _handleOrderQR(key);
        if (mounted) setState(() => _handling = false);
        return;
      }

      // Ưu tiên tìm đơn sửa, sau đó đến đơn bán
      Repair? r;
      try {
        r = await _db.getRepairByFirestoreId(key);
      } catch (e) {
        debugPrint('DB error getting repair: $e');
        r = null;
      }
      if (!mounted) return;
      if (r != null) {
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => RepairDetailView(repair: r!),
          ),
        );
        if (mounted) setState(() => _handling = false);
        return;
      }

      SaleOrder? s;
      try {
        s = await _db.getSaleByFirestoreId(key);
      } catch (e) {
        debugPrint('DB error getting sale: $e');
        s = null;
      }
      if (!mounted) return;
      if (s != null) {
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => SaleDetailView(sale: s!),
          ),
        );
        if (mounted) setState(() => _handling = false);
        return;
      }

      // Nếu không tìm thấy gì, hiển thị thông báo với gợi ý
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Không tìm thấy thông tin tương ứng với QR: ${key.length > 20 ? key.substring(0, 20) + "..." : key}'),
            action: SnackBarAction(
              label: 'Đóng',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
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
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final docId = await _db.insertRepair(repair);

      messenger.showSnackBar(
        const SnackBar(content: Text('Đã tạo đơn hàng từ tem điện thoại!')),
      );

      // Mở chi tiết đơn hàng vừa tạo
      final createdRepair = await _db.getRepairById(docId);
      if (createdRepair != null) {
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => RepairDetailView(repair: createdRepair),
          ),
        );
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
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
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
      final join = await showDialog<bool> (
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
          messenger.showSnackBar(
            const SnackBar(content: Text('Cần đăng nhập để tham gia shop')),
          );
        }
        return;
      }

      final success = await UserService.useInviteCode(code, user.uid);
      if (success && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Đã tham gia shop "$shopName" thành công!')),
        );
        // Có thể navigate về home hoặc refresh app state
        navigator.pop(); // Đóng scanner
      } else {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Mã mời không hợp lệ hoặc đã được sử dụng')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
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

  Future<void> _handleInventoryCheckQR(String qrData) async {
    try {
      // Parse QR format: check_inv:firestoreId
      final parts = qrData.split(':');
      if (parts.length != 2 || parts[0] != 'check_inv') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR kiểm tra kho không hợp lệ')),
          );
        }
        return;
      }

      final productId = parts[1];
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      // Tìm sản phẩm trong database
      final product = await _db.getProductByFirestoreId(productId);
      if (product == null) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Không tìm thấy sản phẩm với ID: $productId')),
          );
        }
        return;
      }

      // Hiển thị thông tin sản phẩm
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('THÔNG TIN SẢN PHẨM'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tên: ${product.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('IMEI: ${product.imei ?? "N/A"}'),
              Text('Màu: ${product.color ?? "N/A"}'),
              Text('Giá: ${product.price != null ? "${NumberFormat('#,###').format(product.price)} đ" : "N/A"}'),
              Text('Tình trạng: ${product.condition ?? "N/A"}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ĐÓNG'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('XEM CHI TIẾT'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Chuyển đến trang chi tiết sản phẩm trong kho
        // Vì không có trang chi tiết sản phẩm riêng, có thể mở dialog xem sản phẩm
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(product.name),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Tên sản phẩm', product.name),
                  _buildDetailRow('IMEI/Serial', product.imei ?? 'N/A'),
                  _buildDetailRow('Màu sắc', product.color ?? 'N/A'),
                  _buildDetailRow('Dung lượng', product.capacity ?? 'N/A'),
                  _buildDetailRow('Tình trạng', product.condition ?? 'N/A'),
                  _buildDetailRow('Giá bán lẻ', '${NumberFormat('#,###').format(product.price)} đ'),
                  _buildDetailRow('Giá bán buôn', '${NumberFormat('#,###').format(product.kpkPrice ?? 0)} đ'),
                  _buildDetailRow('Nhà cung cấp', product.supplier ?? 'N/A'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ĐÓNG'),
              ),
            ],
          ),
        );
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Đã quét sản phẩm: ${product.name}')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xử lý QR kiểm tra kho: $e')),
        );
      }
    }
  }

  Future<void> _handleOrderQR(String qrData) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // Xử lý các loại đơn hàng
      if (qrData.startsWith('repair_') || qrData.startsWith('rep_')) {
        // Tìm đơn sửa chữa
        Repair? repair;
        try {
          repair = await _db.getRepairByFirestoreId(qrData);
        } catch (e) {
          debugPrint('DB error getting repair: $e');
        }

        if (repair != null) {
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => RepairDetailView(repair: repair!),
            ),
          );
          return;
        }
      }

      if (qrData.startsWith('sale_')) {
        // Tìm đơn bán hàng
        SaleOrder? sale;
        try {
          sale = await _db.getSaleByFirestoreId(qrData);
        } catch (e) {
          debugPrint('DB error getting sale: $e');
        }

        if (sale != null) {
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => SaleDetailView(sale: sale!),
            ),
          );
          return;
        }
      }

      if (qrData.startsWith('inv_check_')) {
        // Có thể xử lý kiểm tra kho trong tương lai
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Tính năng kiểm tra kho sẽ được cập nhật')),
          );
        }
        return;
      }

      // Thử tìm theo ID bất kỳ
      Repair? r;
      try {
        r = await _db.getRepairByFirestoreId(qrData);
      } catch (e) {
        r = null;
      }
      if (r != null) {
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => RepairDetailView(repair: r!),
          ),
        );
        return;
      }

      SaleOrder? s;
      try {
        s = await _db.getSaleByFirestoreId(qrData);
      } catch (e) {
        s = null;
      }
      if (s != null) {
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => SaleDetailView(sale: s!),
          ),
        );
        return;
      }

      // Không tìm thấy
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Không tìm thấy đơn hàng với ID: $qrData')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Lỗi xử lý QR đơn hàng: $e')),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    try {
      if (_handling) return;
      final barcodes = capture.barcodes;
      if (barcodes.isEmpty) return;
      final raw = barcodes.first.rawValue;
      if (raw == null || raw.isEmpty) return;
      _handleBarcode(raw);
    } catch (e) {
      debugPrint('Scanner detection error: $e');
    }
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
        title: const Text('QUÉT QR - ĐƠN HÀNG & SẢN PHẨM'),
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
                border: Border.all(color: Colors.white.withAlpha(204), width: 3),
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
                    color: Colors.black.withAlpha(153),
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
