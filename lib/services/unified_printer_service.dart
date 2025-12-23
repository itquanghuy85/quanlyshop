import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'bluetooth_printer_service.dart';
import 'wifi_printer_service.dart';
import '../models/repair_model.dart';

enum PrinterType { bluetooth, wifi, auto }

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
    return str;
  }

  static Future<bool> _sendToPrinter(
    List<int> bytes, {
    PrinterType? printerType, 
    String? wifiIp,
    dynamic bluetoothPrinter,
  }) async {
    try {
      if (printerType == PrinterType.wifi || (printerType == null && wifiIp != null)) {
        await WifiPrinterService.instance.connect(ip: wifiIp ?? "192.168.1.100", port: 9100);
        await WifiPrinterService.instance.printBytes(bytes);
        return true;
      }
      if (bluetoothPrinter != null) {
        final mac = bluetoothPrinter.macAddress;
        final ok = await BluetoothPrinterService.connect(mac);
        if (ok) return await BluetoothPrinterService.printBytes(bytes);
      }
      final hasBt = await BluetoothPrinterService.ensureConnection();
      if (hasBt) return await BluetoothPrinterService.printBytes(bytes);
      await WifiPrinterService.writeBytes(bytes);
      return true;
    } catch (_) { return false; }
  }

  // --- PHIẾU TIẾP NHẬN SỬA CHỮA CHUYÊN NGHIỆP ---
  static Future<bool> printRepairReceiptFromRepair(
    Repair repair, 
    Map<String, dynamic> shopInfo, {
    PrinterType? printerType,
    dynamic bluetoothPrinter,
    String? wifiIp,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];
    bytes.addAll(generator.reset());

    bytes.addAll(generator.text(_removeDiacritics(shopInfo['shopName'] ?? 'SHOP NEW'), styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2)));
    bytes.addAll(generator.text(_removeDiacritics(shopInfo['shopAddr'] ?? 'Chuyen Smartphone & Laptop'), styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.text("Hotline: ${shopInfo['shopPhone'] ?? '0123.456.789'}", styles: const PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(generator.hr());

    bytes.addAll(generator.text('PHIEU TIEP NHAN MAY', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2)));
    bytes.addAll(generator.text("Ma don: ${repair.firestoreId ?? repair.createdAt}", styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.text("Ngay nhan: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(repair.createdAt))}", styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.feed(1));

    bytes.addAll(generator.text(_removeDiacritics("KHACH HANG: ${repair.customerName}"), styles: const PosStyles(bold: true)));
    bytes.addAll(generator.text("SDT: ${repair.phone}"));
    bytes.addAll(generator.feed(1));

    bytes.addAll(generator.text(_removeDiacritics("MAY: ${repair.model}"), styles: const PosStyles(bold: true)));
    if (repair.imei != null && repair.imei!.isNotEmpty) bytes.addAll(generator.text("IMEI/SN: ${repair.imei}"));
    bytes.addAll(generator.text(_removeDiacritics("TINH TRANG: ${repair.issue}")));
    
    String subInfo = "";
    if (repair.color != null) subInfo += "Mau: ${repair.color} | ";
    if (repair.condition != null) subInfo += "Vo: ${repair.condition}";
    if (subInfo.isNotEmpty) bytes.addAll(generator.text(_removeDiacritics(subInfo), styles: const PosStyles(fontType: PosFontType.fontB)));
    
    bytes.addAll(generator.text(_removeDiacritics("PHU KIEN: ${repair.accessories}")));
    bytes.addAll(generator.feed(1));

    final priceStr = NumberFormat('#,###').format(repair.price);
    bytes.addAll(generator.text("GIA DU KIEN: $priceStr VND", styles: const PosStyles(bold: true, height: PosTextSize.size2)));
    bytes.addAll(generator.text(_removeDiacritics("Hinh thuc: ${repair.paymentMethod}")));
    bytes.addAll(generator.feed(1));

    bytes.addAll(generator.text(_removeDiacritics("Quet ma de tra cuu don hang:"), styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB)));
    // Đã sửa lỗi: Gỡ bỏ tham số size: QRSize.size4 gây lỗi
    bytes.addAll(generator.qrcode("repair_check:${repair.firestoreId ?? repair.createdAt}"));
    bytes.addAll(generator.feed(1));

    bytes.addAll(generator.text(_removeDiacritics("- Quy khach vui long giu phieu de nhan may."), styles: const PosStyles(fontType: PosFontType.fontB)));
    bytes.addAll(generator.text(_removeDiacritics("- Shop khong chiu trach nhiem ve du lieu trong may."), styles: const PosStyles(fontType: PosFontType.fontB)));
    bytes.addAll(generator.feed(1));
    
    bytes.addAll(generator.row([
      PosColumn(text: 'Khach hang', width: 6, styles: const PosStyles(align: PosAlign.center, bold: true)),
      PosColumn(text: 'Nhan vien', width: 6, styles: const PosStyles(align: PosAlign.center, bold: true)),
    ]));
    bytes.addAll(generator.feed(3));

    bytes.addAll(generator.text('CAM ON QUY KHACH!', styles: const PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return _sendToPrinter(bytes, printerType: printerType, bluetoothPrinter: bluetoothPrinter, wifiIp: wifiIp);
  }

  static Future<bool> printProductQRLabel(Map<String, dynamic> product) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];
    bytes.addAll(generator.reset());
    bytes.addAll(generator.text(_removeDiacritics(product['name'] ?? 'SAN PHAM'), styles: const PosStyles(bold: true, align: PosAlign.center)));
    // Đã sửa lỗi: Gỡ bỏ tham số size
    bytes.addAll(generator.qrcode("check_inv:${product['firestoreId'] ?? product['id']}")); 
    bytes.addAll(generator.cut());
    return _sendToPrinter(bytes);
  }

  static Future<bool> printRepairReceipt(Map<String, dynamic> data, PaperSize paper, {PrinterType? printerType, dynamic bluetoothPrinter, String? wifiIp}) async {
    return true; 
  }

  static Future<bool> printSaleReceipt(Map<String, dynamic> saleData, PaperSize paper, {PrinterType? printerType, dynamic bluetoothPrinter, String? wifiIp}) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paper, profile);
    List<int> bytes = [];
    bytes.addAll(generator.reset());
    bytes.addAll(generator.text(_removeDiacritics('HOA DON BAN HANG'), styles: const PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(generator.cut());
    return _sendToPrinter(bytes, printerType: printerType, bluetoothPrinter: bluetoothPrinter, wifiIp: wifiIp);
  }

  static Future<bool> printPhoneLabelToWifi(Map<String, dynamic> labelData, String ipAddress) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];
    bytes.addAll(generator.reset());
    bytes.addAll(generator.text(_removeDiacritics(labelData['name'] ?? 'TEM MAY'), styles: const PosStyles(bold: true)));
    bytes.addAll(generator.cut());
    return _sendToPrinter(bytes, wifiIp: ipAddress);
  }
}
