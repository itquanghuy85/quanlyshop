import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'bluetooth_printer_service.dart';
import 'wifi_printer_service.dart';

class UnifiedPrinterService {
  // Hàm chuyển đổi Tiếng Việt sang không dấu để máy in nhiệt không bị lỗi font
  static String _removeDiacritics(String str) {
    const vietnamese = 'aAeEoOuUiIdDyY';
    final vietnameseRegex = <RegExp>[
      RegExp(r'à|á|ạ|ả|ã|â|ầ|ấ|ậ|ẩ|ẫ|ă|ằ|ắ|ặ|ẳ|ẵ'),
      RegExp(r'À|Á|Ạ|Ả|Ã|Â|Ầ|Ấ|Ậ|Ẩ|Ẫ|Ă|Ằ|Ắ|Ặ|Ẳ|Ẵ'),
      RegExp(r'è|é|ẹ|ẻ|ẽ|ê|ề|ế|ệ|ể|ễ'),
      RegExp(r'È|É|Ạ|Ẻ|Ẽ|Ê|Ề|Ế|Ệ|Ể|Ễ'),
      RegExp(r'ò|ó|ọ|ỏ|õ|ô|ồ|ố|ộ|ổ|ỗ|ơ|ờ|ớ|ợ|ở|ỡ'),
      RegExp(r'Ò|Ó|Ọ|Ỏ|Õ|Ô|Ồ|Ố|Ộ|Ổ|Ỗ|Ơ|Ờ|Ớ|Ợ|Ở|Ỡ'),
      RegExp(r'ù|ú|ụ|ủ|ũ|ư|ừ|ứ|ự|ử|ữ'),
      RegExp(r'Ù|Ú|Ụ|Ủ|Ũ|Ư|Ừ|Ứ|Ự|Ử|Ữ'),
      RegExp(r'ì|í|ị|ỉ|ĩ'),
      RegExp(r'Ì|Í|Ị|Ỉ|Ĩ'),
      RegExp(r'đ'),
      RegExp(r'Đ'),
      RegExp(r'ỳ|ý|ỵ|ỷ|ỹ'),
      RegExp(r'Ỳ|Ý|Ỵ|Ỷ|Ỹ'),
    ];

    for (var i = 0; i < vietnameseRegex.length; i++) {
      str = str.replaceAll(vietnameseRegex[i], vietnamese[i]);
    }
    return str;
  }

  static Future<bool> printRepairReceipt(
    Map<String, dynamic> repairData,
    PaperSize paper,
  ) async {
    final bytes = await _generateRepairReceiptBytes(repairData, paper);
    return _sendToPrinter(bytes);
  }

  static Future<bool> printSaleReceipt(
    Map<String, dynamic> saleData,
    PaperSize paper,
  ) async {
    final bytes = await _generateSaleReceiptBytes(saleData, paper);
    return _sendToPrinter(bytes);
  }

  // Cơ chế gửi lệnh in thông minh: Thử Bluetooth nếu có cấu hình, nếu không thử WiFi
  static Future<bool> _sendToPrinter(List<int> bytes) async {
    bool printed = false;

    // 1. Thử in qua Bluetooth
    try {
      // Kiểm tra xem có máy in Bluetooth nào đang được kết nối/cấu hình không
      final hasBt = await BluetoothPrinterService.ensureConnection();
      if (hasBt) {
        printed = await BluetoothPrinterService.printBytes(bytes);
        if (printed) return true;
      }
    } catch (e) {
      debugPrint('Bluetooth print failed: $e');
    }

    // 2. Nếu Bluetooth thất bại hoặc không có, thử WiFi
    try {
      // WiFi Service nên có cơ chế timeout nhanh
      await WifiPrinterService.writeBytes(bytes);
      return true; // Assume success if no exception
    } catch (e) {
      debugPrint('WiFi print failed: $e');
    }

    return false;
  }

  static Future<List<int>> _generateRepairReceiptBytes(
    Map<String, dynamic> repairData,
    PaperSize paper,
  ) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paper, profile);

    final bytes = <int>[];
    bytes.addAll(generator.reset());

    // Header - Luôn chuyển sang không dấu
    bytes.addAll(generator.text(
      _removeDiacritics('PHIEU TIEP NHAN SUA CHUA'),
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
    ));

    bytes.addAll(generator.text(
      _removeDiacritics('Shop New - Chuyen Smartphone'),
      styles: const PosStyles(align: PosAlign.center),
    ));

    bytes.addAll(generator.feed(1));

    // Mã phiếu tiếp nhận
    if (repairData['receiptCode'] != null) {
      bytes.addAll(generator.text(
        'Ma phieu: ${repairData['receiptCode']}',
        styles: const PosStyles(bold: true),
      ));
    }

    // Ngày giờ nhận
    if (repairData['receivedDate'] != null) {
      bytes.addAll(generator.text('Ngay nhan: ${repairData['receivedDate']}'));
    }

    bytes.addAll(generator.feed(1));

    // Thông tin khách hàng
    bytes.addAll(generator.text(_removeDiacritics('Khach hang: ${repairData['customerName'] ?? ''}')));
    bytes.addAll(generator.text('SDT: ${repairData['customerPhone'] ?? ''}'));

    if (repairData['customerAddress'] != null && repairData['customerAddress'].toString().isNotEmpty) {
      bytes.addAll(generator.text(_removeDiacritics('Dia chi: ${repairData['customerAddress']}')));
    }

    bytes.addAll(generator.feed(1));

    // Thông tin thiết bị
    bytes.addAll(generator.text(_removeDiacritics('Model: ${repairData['deviceModel'] ?? ''}')));
    bytes.addAll(generator.text(_removeDiacritics('Tinh trang: ${repairData['issue'] ?? ''}')));

    if (repairData['accessories'] != null && repairData['accessories'].toString().isNotEmpty) {
      bytes.addAll(generator.text(_removeDiacritics('Phu kien: ${repairData['accessories']}')));
    }

    bytes.addAll(generator.feed(1));

    // Giá dự kiến
    if (repairData['estimatedCost'] != null && repairData['estimatedCost'] != 0) {
      final cost = repairData['estimatedCost'];
      bytes.addAll(generator.text(_removeDiacritics('Gia du kien: $cost VND')));
    }

    bytes.addAll(generator.feed(1));

    // Thông tin quan trọng
    bytes.addAll(generator.text(
      _removeDiacritics('LUU Y:'),
      styles: const PosStyles(bold: true),
    ));
    bytes.addAll(generator.text(_removeDiacritics('- Giu giay nay de nhan lai may')));
    bytes.addAll(generator.text(_removeDiacritics('- Thoi gian sua khoang 2-7 ngay')));
    bytes.addAll(generator.text(_removeDiacritics('- Lien he: 0123 456 789')));

    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(
      _removeDiacritics('Cam on quy khach!'),
      styles: const PosStyles(align: PosAlign.center),
    ));

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }

  static Future<List<int>> _generateSaleReceiptBytes(
    Map<String, dynamic> saleData,
    PaperSize paper,
  ) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paper, profile);

    final bytes = <int>[];
    bytes.addAll(generator.reset());

    bytes.addAll(generator.text(
      _removeDiacritics('HOA DON BAN HANG'),
      styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size2, bold: true),
    ));

    bytes.addAll(generator.feed(1));

    bytes.addAll(generator.text(_removeDiacritics('Khach hang: ${saleData['customerName'] ?? ''}')));
    bytes.addAll(generator.text('SDT: ${saleData['customerPhone'] ?? ''}'));

    if (saleData['items'] != null) {
      bytes.addAll(generator.feed(1));
      for (var item in saleData['items']) {
        bytes.addAll(generator.text(_removeDiacritics('${item['name'] ?? ''} x${item['quantity'] ?? 1}')));
        bytes.addAll(generator.text('  Gia: ${item['price'] ?? 0}'));
      }
    }

    if (saleData['totalAmount'] != null) {
      bytes.addAll(generator.feed(1));
      bytes.addAll(generator.text(
        _removeDiacritics('TONG CONG: ${saleData['totalAmount']} VND'),
        styles: const PosStyles(bold: true),
      ));
    }

    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(
      _removeDiacritics('Hen gap lai quy khach!'),
      styles: const PosStyles(align: PosAlign.center),
    ));

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }

  static Future<bool> printPhoneLabel(Map<String, dynamic> labelData) async {
    final bytes = await _generatePhoneLabelBytes(labelData);
    return _sendToPrinter(bytes);
  }

  static Future<bool> printPhoneLabelToWifi(Map<String, dynamic> labelData, String ipAddress) async {
    final bytes = await _generatePhoneLabelBytes(labelData);
    return _sendToWifiPrinter(bytes, ipAddress);
  }

  static Future<bool> _sendToWifiPrinter(List<int> bytes, String ipAddress) async {
    try {
      // Kết nối trực tiếp đến máy in WiFi với IP cụ thể
      final wifiService = WifiPrinterService.instance;
      await wifiService.connect(ip: ipAddress, port: 9100); // Port mặc định cho máy in nhiệt
      await wifiService.printBytes(bytes);
      await wifiService.disconnect();
      return true;
    } catch (e) {
      debugPrint('WiFi print to $ipAddress failed: $e');
      return false;
    }
  }

  static Future<List<int>> _generatePhoneLabelBytes(Map<String, dynamic> labelData) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    final bytes = <int>[];
    bytes.addAll(generator.reset());

    // Header - TEM DIEN THOAI (chữ hoa)
    bytes.addAll(generator.text(
      'TEM DIEN THOAI',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
    ));

    bytes.addAll(generator.feed(1));

    // Thông tin điện thoại - tất cả chữ hoa
    bytes.addAll(generator.text('TEN: ${labelData['name'] ?? ''}', styles: const PosStyles(bold: true)));
    bytes.addAll(generator.text('IMEI: ${labelData['imei'] ?? ''}'));
    bytes.addAll(generator.text('MAU: ${labelData['color'] ?? ''}'));
    
    // Giá trên 2 dòng - KPK và CPK
    bytes.addAll(generator.text('KPK: ${(labelData['cost'] ?? 0).toString()} VND', styles: const PosStyles(bold: true)));
    bytes.addAll(generator.text('CPK: ${(labelData['price'] ?? 0).toString()} VND', styles: const PosStyles(bold: true)));
    
    bytes.addAll(generator.text('TINH TRANG: ${labelData['condition'] ?? ''}'));

    if (labelData['accessories'] != null && labelData['accessories'].toString().isNotEmpty) {
      bytes.addAll(generator.text('PHU KIEN: ${labelData['accessories']}'));
    }

    bytes.addAll(generator.feed(1));

    // QR Code Data - JSON format để quét tạo đơn hàng nhanh
    final qrData = {
      'type': 'phone_label',
      'name': labelData['name'] ?? '',
      'imei': labelData['imei'] ?? '',
      'color': labelData['color'] ?? '',
      'cost': labelData['cost'] ?? 0,
      'price': labelData['price'] ?? 0,
      'condition': labelData['condition'] ?? '',
      'accessories': labelData['accessories'] ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final qrJson = qrData.toString();
    bytes.addAll(generator.text(
      'QR DATA:',
      styles: const PosStyles(bold: true),
    ));
    bytes.addAll(generator.text(qrJson, styles: const PosStyles(fontType: PosFontType.fontB)));

    bytes.addAll(generator.feed(1));

    // Footer
    bytes.addAll(generator.text(
      'SHOP NEW',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }
}
