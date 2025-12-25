import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bluetooth_printer_service.dart';
import 'wifi_printer_service.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';

class UnifiedPrinterService {
  static String _removeDiacritics(String str) {
    const vietnamese = 'aAeEoOuUiIdDyY';
    final vietnameseRegex = [
      RegExp(r'à|á|ạ|ả|ã|â|ầ|ấ|ậ|ẩ|ẫ|ă|ằ|ắ|ặ|ẳ|ẵ'), RegExp(r'À|Á|Ạ|Ả|Ã|Â|Ầ|Ấ|Ậ|Ẩ|Ẫ|Ă|Ằ|Ắ|Ặ|Ẳ|Ẵ'),
      RegExp(r'è|é|ẹ|ẻ|ẽ|ê|ề|ế|ệ|ể|ễ'), RegExp(r'È|È|Ạ|Ẻ|Ẽ|Ê|Ề|Ế|Ệ|Ể|Ễ'),
      RegExp(r'ò|ó|ọ|ỏ|õ|ô|ồ|ố|ộ|ổ|ỗ|ơ|ờ|ớ|ợ|ở|ỡ'), RegExp(r'Ò|Ó|Ọ|Ỏ|Õ|Ô|Ồ|Ố|Ộ|Ổ|Ỗ|Ơ|Ờ|Ớ|Ợ|Ở|Ỡ'),
      RegExp(r'ù|ú|ụ|ủ|ũ|ư|ừ|ứ|ự|ử|ữ'), RegExp(r'Ù|Ú|Ụ|Ủ|Ũ|Ư|Ừ|Ứ|Ự|Ử|Ữ'),
      RegExp(r'ì|í|ị|ỉ|ĩ'), RegExp(r'Ì|Í|Ị|Ỉ|Ĩ'),
      RegExp(r'đ'), RegExp(r'Đ'), RegExp(r'ỳ|ý|ỵ|ỷ|ỹ'), RegExp(r'Ỳ|Ý|Ỵ|Ỷ|Ỹ'),
    ];
    for (var i = 0; i < vietnameseRegex.length; i++) {
      str = str.replaceAll(vietnameseRegex[i], vietnamese[i]);
    }
    return str.toUpperCase();
  }

  static String _fmt(int n) => NumberFormat('#,###').format(n);

  static Future<bool> _sendToPrinter(List<int> bytes, {String? customMac, String? customIp}) async {
    if (bytes.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    
    // TRƯỜNG HỢP 1: IN QUA MÁY IN BLUETOOTH CHỈ ĐỊNH (MÁY IN KHÁC)
    if (customMac != null) {
      final ok = await BluetoothPrinterService.connect(customMac);
      if (ok) return await BluetoothPrinterService.printBytes(bytes);
    }

    // TRƯỜNG HỢP 2: IN QUA MÁY IN WIFI CHỈ ĐỊNH
    if (customIp != null) {
      try {
        final ok = await WifiPrinterService.instance.connect(ip: customIp, port: 9100);
        if (ok) {
          await WifiPrinterService.instance.printBytes(bytes);
          return true;
        }
      } catch (_) {}
    }

    // MẶC ĐỊNH: Dùng cấu hình trong máy
    final hasBt = await BluetoothPrinterService.ensureConnection();
    if (hasBt) return await BluetoothPrinterService.printBytes(bytes);

    final ip = prefs.getString('printer_ip') ?? "";
    if (ip.isNotEmpty) {
      try {
        final ok = await WifiPrinterService.instance.connect(ip: ip, port: 9100);
        if (ok) {
          await WifiPrinterService.instance.printBytes(bytes);
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  // CẬP NHẬT: Thêm tùy chọn in qua máy in khác
  static Future<bool> printProductQRLabel(Map<String, dynamic> product, {String? customMac, String? customIp}) async {
    final prefs = await SharedPreferences.getInstance();
    final pSize = (prefs.getString('paper_size') ?? "80mm") == "80mm" ? PaperSize.mm80 : PaperSize.mm58;
    final fontScale = prefs.getDouble('label_font_scale') ?? 1.0;
    
    final profile = await CapabilityProfile.load();
    final generator = Generator(pSize, profile);
    List<int> bytes = [];
    bytes.addAll(generator.reset());

    PosTextSize mainSize = fontScale >= 2.0 ? PosTextSize.size2 : PosTextSize.size1;
    PosTextSize subSize = fontScale >= 2.0 ? PosTextSize.size2 : PosTextSize.size1;

    if (prefs.getBool('label_show_name') ?? true) {
      bytes.addAll(generator.text(_removeDiacritics(product['name'] ?? ''), styles: PosStyles(bold: true, align: PosAlign.center, height: mainSize, width: mainSize)));
    }
    
    String detail = "${product['capacity'] ?? ''} ${product['color'] ?? ''} ${product['condition'] ?? ''}".trim();
    if (detail.isNotEmpty && (prefs.getBool('label_show_detail') ?? true)) {
      bytes.addAll(generator.text(_removeDiacritics(detail), styles: PosStyles(align: PosAlign.center, bold: true, height: subSize)));
    }

    if (prefs.getBool('label_show_price_kpk') ?? true) {
      bytes.addAll(generator.text("GIA KPK: ${_fmt(product['kpkPrice'] ?? 0)}", styles: PosStyles(bold: true, align: PosAlign.center, height: mainSize)));
    }

    if (prefs.getBool('label_show_price_cpk') ?? true) {
      bytes.addAll(generator.text("GIA CPK: ${_fmt(product['price'] ?? 0)}", styles: PosStyles(bold: true, align: PosAlign.center, height: subSize)));
    }

    if (prefs.getBool('label_show_qr') ?? true) {
      bytes.addAll(generator.qrcode((product['imei'] ?? product['id']).toString(), align: PosAlign.center, size: fontScale >= 2.0 ? QRSize.Size4 : QRSize.Size3));
    }

    if (prefs.getBool('label_show_imei') ?? true && product['imei'] != null) {
      bytes.addAll(generator.text("IMEI: ${product['imei']}", styles: const PosStyles(align: PosAlign.center, bold: true, fontType: PosFontType.fontB)));
    }

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
    return _sendToPrinter(bytes, customMac: customMac, customIp: customIp);
  }

  static Future<bool> printRepairReceiptFromRepair(Repair r, Map<String, dynamic> shop) async {
    final prefs = await SharedPreferences.getInstance();
    final pSize = (prefs.getString('paper_size') ?? "80mm") == "80mm" ? PaperSize.mm80 : PaperSize.mm58;
    final fontScale = prefs.getDouble('label_font_scale') ?? 1.0;
    final profile = await CapabilityProfile.load();
    final generator = Generator(pSize, profile);
    List<int> bytes = [];
    bytes.addAll(generator.reset());
    PosTextSize headerSize = fontScale >= 2.0 ? PosTextSize.size2 : PosTextSize.size1;
    if (prefs.getBool('receipt_show_logo') ?? true) {
      bytes.addAll(generator.text(_removeDiacritics(shop['shopName'] ?? 'SHOP NEW'), styles: PosStyles(align: PosAlign.center, bold: true, height: headerSize)));
    }
    bytes.addAll(generator.text(_removeDiacritics(shop['shopAddr'] ?? ''), styles: const PosStyles(align: PosAlign.center)));
    if (prefs.getBool('receipt_show_phone') ?? true) {
      bytes.addAll(generator.text("HOTLINE: ${shop['shopPhone'] ?? ''}", styles: const PosStyles(align: PosAlign.center, bold: true)));
    }
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text('PHIEU TIEP NHAN', styles: PosStyles(align: PosAlign.center, bold: true, height: headerSize)));
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(_removeDiacritics("KHACH: ${r.customerName}")));
    bytes.addAll(generator.text("SDT: ${r.phone}"));
    bytes.addAll(generator.text(_removeDiacritics("MAY: ${r.model}")));
    bytes.addAll(generator.text(_removeDiacritics("LOI: ${r.issue}")));
    bytes.addAll(generator.text("GIA: ${_fmt(r.price)} VND", styles: const PosStyles(bold: true)));
    bytes.addAll(generator.text("BH: ${r.warranty}", styles: const PosStyles(bold: true)));
    if (prefs.getBool('receipt_show_qr') ?? true) {
      bytes.addAll(generator.qrcode("check:${r.firestoreId ?? r.createdAt}", align: PosAlign.center));
    }
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
    return _sendToPrinter(bytes);
  }

  static Future<bool> printSaleReceiptFromOrder(SaleOrder s, Map<String, dynamic> shop) async {
    final prefs = await SharedPreferences.getInstance();
    final pSize = (prefs.getString('paper_size') ?? "80mm") == "80mm" ? PaperSize.mm80 : PaperSize.mm58;
    final fontScale = prefs.getDouble('label_font_scale') ?? 1.0;
    final profile = await CapabilityProfile.load();
    final generator = Generator(pSize, profile);
    List<int> bytes = [];
    bytes.addAll(generator.reset());
    PosTextSize headerSize = fontScale >= 2.0 ? PosTextSize.size2 : PosTextSize.size1;
    bytes.addAll(generator.text(_removeDiacritics(shop['shopName'] ?? 'SHOP NEW'), styles: PosStyles(align: PosAlign.center, bold: true, height: headerSize)));
    bytes.addAll(generator.text(_removeDiacritics(shop['shopAddr'] ?? ''), styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.text("SDT: ${shop['shopPhone'] ?? ''}", styles: const PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text('HOA DON BAN HANG', styles: PosStyles(align: PosAlign.center, bold: true, height: headerSize)));
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(_removeDiacritics("KHACH HANG: ${s.customerName}")));
    bytes.addAll(generator.text("DIEN THOAI: ${s.phone}"));
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text(_removeDiacritics("SAN PHAM: ${s.productNames}")));
    bytes.addAll(generator.text("IMEI: ${s.productImeis}"));
    bytes.addAll(generator.text("BAO HANH: ${s.warranty}"));
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text("TONG CONG: ${_fmt(s.totalPrice)} VND", styles: PosStyles(bold: true, height: headerSize)));
    if (s.paymentMethod == "CÔNG NỢ" || s.downPayment < s.totalPrice) {
      bytes.addAll(generator.text("DA TRA: ${_fmt(s.downPayment)} VND"));
      bytes.addAll(generator.text("CON THIEU: ${_fmt(s.totalPrice - s.downPayment)} VND", styles: const PosStyles(bold: true)));
    }
    if (prefs.getBool('receipt_show_qr') ?? true) {
      bytes.addAll(generator.qrcode("sale:${s.firestoreId ?? s.soldAt}", align: PosAlign.center));
    }
    String note = prefs.getString('receipt_note') ?? "CAM ON QUY KHACH!";
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(_removeDiacritics(note), styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB)));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
    return _sendToPrinter(bytes);
  }
}
