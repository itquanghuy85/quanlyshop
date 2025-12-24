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
      RegExp(r'è|é|ẹ|ẻ|ẽ|ê|ề|ế|ệ|ể|ễ'), RegExp(r'È|É|Ạ|Ẻ|Ẽ|Ê|Ề|Ế|Ệ|Ể|Ễ'),
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

  static Future<bool> _sendToPrinter(List<int> bytes) async {
    if (bytes.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
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

  static Future<bool> printProductQRLabel(Map<String, dynamic> product) async {
    final prefs = await SharedPreferences.getInstance();
    final pSize = (prefs.getString('paper_size') ?? "80mm") == "80mm" ? PaperSize.mm80 : PaperSize.mm58;
    final fontScale = prefs.getDouble('label_font_scale') ?? 1.0;
    
    final profile = await CapabilityProfile.load();
    final generator = Generator(pSize, profile);
    List<int> bytes = [];
    bytes.addAll(generator.reset());

    // Cấu hình size chữ dựa trên Slider
    PosTextSize mainSize = PosTextSize.size1;
    PosTextSize subSize = PosTextSize.size1;

    if (fontScale >= 2.0) {
      mainSize = PosTextSize.size2;
    }
    if (fontScale >= 3.0) {
      subSize = PosTextSize.size2;
    }

    // 1. TÊN MÁY
    if (prefs.getBool('label_show_name') ?? true) {
      bytes.addAll(generator.text(
        _removeDiacritics(product['name'] ?? ''), 
        styles: PosStyles(bold: true, align: PosAlign.center, height: mainSize, width: mainSize)
      ));
    }
    
    // 2. CHI TIẾT GỘP
    String detail = "${product['capacity'] ?? ''} ${product['color'] ?? ''} ${product['condition'] ?? ''}".trim();
    if (detail.isNotEmpty && (prefs.getBool('label_show_detail') ?? true)) {
      bytes.addAll(generator.text(
        _removeDiacritics(detail), 
        styles: PosStyles(align: PosAlign.center, bold: true, height: subSize)
      ));
    }

    // 3. GIÁ KPK
    if (prefs.getBool('label_show_price_kpk') ?? true) {
      bytes.addAll(generator.text(
        "GIA KPK: ${_fmt(product['kpkPrice'] ?? 0)}", 
        styles: PosStyles(bold: true, align: PosAlign.center, height: mainSize)
      ));
    }

    // 4. GIÁ CPK
    if (prefs.getBool('label_show_price_cpk') ?? true) {
      bytes.addAll(generator.text(
        "GIA CPK: ${_fmt(product['price'] ?? 0)}", 
        styles: const PosStyles(bold: true, align: PosAlign.center)
      ));
    }

    // 5. QR CODE
    if (prefs.getBool('label_show_qr') ?? true) {
      bytes.addAll(generator.qrcode(
        (product['imei'] ?? product['id']).toString(), 
        align: PosAlign.center,
        size: fontScale >= 2.0 ? QRSize.Size4 : QRSize.Size3
      ));
    }

    // 6. IMEI
    if (prefs.getBool('label_show_imei') ?? true && product['imei'] != null) {
      bytes.addAll(generator.text(
        "IMEI: ${product['imei']}", 
        styles: const PosStyles(align: PosAlign.center, bold: true, fontType: PosFontType.fontB)
      ));
    }

    // 7. TÙY BIẾN
    String custom = prefs.getString('label_custom_text') ?? "";
    if (custom.isNotEmpty) {
      bytes.addAll(generator.text(_removeDiacritics(custom), styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB)));
    }

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
    return _sendToPrinter(bytes);
  }

  // Giữ lại các hàm khác để không lỗi build
  static Future<bool> printRepairReceiptFromRepair(Repair r, Map<String, dynamic> shop) async {
    final prefs = await SharedPreferences.getInstance();
    final pSize = (prefs.getString('paper_size') ?? "80mm") == "80mm" ? PaperSize.mm80 : PaperSize.mm58;
    final profile = await CapabilityProfile.load();
    final generator = Generator(pSize, profile);
    List<int> bytes = [];
    bytes.addAll(generator.reset());
    bytes.addAll(generator.text(_removeDiacritics(shop['shopName'] ?? 'SHOP NEW'), styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2)));
    bytes.addAll(generator.text(_removeDiacritics(shop['shopAddr'] ?? ''), styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text(_removeDiacritics("KHACH: ${r.customerName}")));
    bytes.addAll(generator.text("MAY: ${r.model}"));
    bytes.addAll(generator.text("GIA: ${_fmt(r.price)} D", styles: const PosStyles(bold: true)));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
    return _sendToPrinter(bytes);
  }

  static Future<bool> printSaleReceiptFromOrder(SaleOrder s, Map<String, dynamic> shop) async {
    final prefs = await SharedPreferences.getInstance();
    final pSize = (prefs.getString('paper_size') ?? "80mm") == "80mm" ? PaperSize.mm80 : PaperSize.mm58;
    final profile = await CapabilityProfile.load();
    final generator = Generator(pSize, profile);
    List<int> bytes = [];
    bytes.addAll(generator.reset());
    bytes.addAll(generator.text(_removeDiacritics('HOA DON BAN HANG'), styles: const PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(generator.text(_removeDiacritics("SP: ${s.productNames}")));
    bytes.addAll(generator.text("TONG: ${_fmt(s.totalPrice)} D", styles: const PosStyles(bold: true)));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
    return _sendToPrinter(bytes);
  }
}
