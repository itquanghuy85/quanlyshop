import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bluetooth_printer_service.dart';
import 'wifi_printer_service.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';

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

  static String _fmt(int n) => NumberFormat('#,###').format(n);

  static Future<bool> _sendToPrinter(
    List<int> bytes, {
    PrinterType? printerType, 
    String? wifiIp,
    dynamic bluetoothPrinter,
  }) async {
    if (bytes.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    
    if (printerType == PrinterType.wifi || wifiIp != null) {
      final ip = wifiIp ?? prefs.getString('printer_ip') ?? "";
      if (ip.isNotEmpty) {
        try {
          await WifiPrinterService.instance.connect(ip: ip, port: 9100);
          await WifiPrinterService.instance.printBytes(bytes);
          return true;
        } catch (_) {}
      }
    }

    if (printerType == PrinterType.bluetooth || printerType == PrinterType.auto || printerType == null) {
      if (bluetoothPrinter != null) {
        final ok = await BluetoothPrinterService.connect(bluetoothPrinter.macAddress);
        if (ok) return await BluetoothPrinterService.printBytes(bytes);
      }
      final hasBt = await BluetoothPrinterService.ensureConnection();
      if (hasBt) return await BluetoothPrinterService.printBytes(bytes);
    }

    if (printerType == PrinterType.auto || printerType == null) {
      final ip = prefs.getString('printer_ip') ?? "";
      if (ip.isNotEmpty) {
        try {
          await WifiPrinterService.instance.connect(ip: ip, port: 9100);
          await WifiPrinterService.instance.printBytes(bytes);
          return true;
        } catch (_) {}
      }
    }

    return false;
  }

  // HÀM MỚI ĐỂ XÓA LỖI BUILD Ở SALE_DETAIL_VIEW
  static Future<bool> printSaleReceiptFromOrder(SaleOrder s, Map<String, dynamic> shop, {PrinterType? printerType, dynamic bluetoothPrinter, String? wifiIp}) async {
    final data = {
      'customerName': s.customerName,
      'productNames': s.productNames,
      'totalPrice': s.totalPrice,
      'id': s.firestoreId ?? s.soldAt.toString(),
    };
    return printSaleReceipt(data, PaperSize.mm80, printerType: printerType, bluetoothPrinter: bluetoothPrinter, wifiIp: wifiIp);
  }

  static Future<bool> printProductQRLabel(Map<String, dynamic> product) async {
    final prefs = await SharedPreferences.getInstance();
    final String pSize = prefs.getString('paper_size') ?? "80mm";
    final profile = await CapabilityProfile.load();
    final generator = Generator(pSize == "80mm" ? PaperSize.mm80 : PaperSize.mm58, profile);
    List<int> bytes = [];
    bytes.addAll(generator.reset());

    if (prefs.getBool('label_show_name') ?? true) {
      bytes.addAll(generator.text(_removeDiacritics(product['name'] ?? ''), styles: const PosStyles(bold: true, align: PosAlign.center)));
    }
    if (prefs.getBool('label_show_imei') ?? true && product['imei'] != null) {
      bytes.addAll(generator.text("IMEI: ${product['imei']}", styles: const PosStyles(align: PosAlign.center)));
    }
    if (prefs.getBool('label_show_price') ?? true) {
      bytes.addAll(generator.text("GIA: ${_fmt(product['price'] ?? 0)} D", styles: const PosStyles(bold: true, align: PosAlign.center)));
    }
    if (prefs.getBool('label_show_qr') ?? true) {
      bytes.addAll(generator.qrcode("inv:${product['firestoreId'] ?? product['id']}", align: PosAlign.center));
    }
    final String customText = prefs.getString('label_custom_text') ?? "";
    if (customText.isNotEmpty) {
      bytes.addAll(generator.text(_removeDiacritics(customText.toUpperCase()), styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB)));
    }
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
    return _sendToPrinter(bytes);
  }

  static Future<bool> printRepairReceipt(
    Map<String, dynamic> data, 
    PaperSize paper, {
    PrinterType? printerType,
    dynamic bluetoothPrinter,
    String? wifiIp,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paper, profile);
    List<int> bytes = [];
    bytes.addAll(generator.reset());
    bytes.addAll(generator.text(_removeDiacritics('PHIEU TIEP NHAN MAY'), styles: const PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(generator.text(_removeDiacritics('Khach hang: ${data['customerName']}')));
    bytes.addAll(generator.text('SDT: ${data['customerPhone']}'));
    bytes.addAll(generator.text(_removeDiacritics('Model: ${data['deviceModel']}')));
    bytes.addAll(generator.qrcode("check:${data['receiptCode'] ?? 'N/A'}", align: PosAlign.center));
    bytes.addAll(generator.cut());
    return _sendToPrinter(bytes, printerType: printerType, bluetoothPrinter: bluetoothPrinter, wifiIp: wifiIp);
  }

  static Future<bool> printRepairReceiptFromRepair(
    Repair repair, 
    Map<String, dynamic> shopInfo, {
    PrinterType? printerType,
    dynamic bluetoothPrinter,
    String? wifiIp,
  }) async {
    final data = { 
      'customerName': repair.customerName, 
      'customerPhone': repair.phone, 
      'deviceModel': repair.model,
      'receiptCode': repair.firestoreId
    };
    return printRepairReceipt(data, PaperSize.mm80, printerType: printerType, bluetoothPrinter: bluetoothPrinter, wifiIp: wifiIp);
  }

  static Future<bool> printSaleReceipt(
    Map<String, dynamic> saleData, 
    PaperSize paper, {
    PrinterType? printerType,
    dynamic bluetoothPrinter,
    String? wifiIp,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paper, profile);
    List<int> bytes = [];
    bytes.addAll(generator.reset());
    bytes.addAll(generator.text(_removeDiacritics('HOA DON BAN HANG'), styles: const PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(generator.text(_removeDiacritics('Khach: ${saleData['customerName']}')));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
    return _sendToPrinter(bytes, printerType: printerType, bluetoothPrinter: bluetoothPrinter, wifiIp: wifiIp);
  }

  static Future<bool> printPhoneLabelToWifi(Map<String, dynamic> labelData, String ipAddress) async {
    return printProductQRLabel(labelData);
  }
}
