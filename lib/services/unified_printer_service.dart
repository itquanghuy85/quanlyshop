import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'bluetooth_printer_service.dart';
import 'wifi_printer_service.dart';

class UnifiedPrinterService {
  static Future<bool> printRepairReceipt(
    Map<String, dynamic> repairData,
    PaperSize paper,
  ) async {
    final bytes = await _generateRepairReceiptBytes(repairData, paper);

    // Try Bluetooth first (if connected), fallback to WiFi
    try {
      final btConnected = await BluetoothPrinterService.ensureConnection();
      if (btConnected) {
        final success = await BluetoothPrinterService.printBytes(bytes);
        if (success) return true;
      }
    } catch (e) {
      debugPrint('Bluetooth print failed, trying WiFi: $e');
    }

    // Fallback to WiFi
    try {
      await WifiPrinterService.writeBytes(bytes);
      return true;
    } catch (e) {
      debugPrint('WiFi print failed: $e');
      return false;
    }
  }

  static Future<bool> printSaleReceipt(
    Map<String, dynamic> saleData,
    PaperSize paper,
  ) async {
    final bytes = await _generateSaleReceiptBytes(saleData, paper);

    // Try Bluetooth first (if connected), fallback to WiFi
    try {
      final btConnected = await BluetoothPrinterService.ensureConnection();
      if (btConnected) {
        final success = await BluetoothPrinterService.printBytes(bytes);
        if (success) return true;
      }
    } catch (e) {
      debugPrint('Bluetooth print failed, trying WiFi: $e');
    }

    // Fallback to WiFi
    try {
      await WifiPrinterService.writeBytes(bytes);
      return true;
    } catch (e) {
      debugPrint('WiFi print failed: $e');
      return false;
    }
  }

  static Future<List<int>> _generateRepairReceiptBytes(
    Map<String, dynamic> repairData,
    PaperSize paper,
  ) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paper, profile);

    final bytes = <int>[];
    bytes.addAll(generator.reset());

    // Header
    bytes.addAll(generator.text(
      'PHIEU SUA CHUA',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
    ));

    bytes.addAll(generator.text(
      'Shop New - Sua Chua Dien Thoai',
      styles: const PosStyles(align: PosAlign.center),
    ));

    bytes.addAll(generator.feed(1));

    // Repair details
    bytes.addAll(generator.text('Ma don: ${repairData['id'] ?? ''}'));
    bytes.addAll(generator.text('Khach hang: ${repairData['customerName'] ?? ''}'));
    bytes.addAll(generator.text('SDT: ${repairData['customerPhone'] ?? ''}'));
    bytes.addAll(generator.text('Thiet bi: ${repairData['deviceModel'] ?? ''}'));
    bytes.addAll(generator.text('Van de: ${repairData['issue'] ?? ''}'));

    if (repairData['estimatedCost'] != null) {
      bytes.addAll(generator.text('Phi du kien: ${repairData['estimatedCost']} VND'));
    }

    if (repairData['notes'] != null && repairData['notes'].isNotEmpty) {
      bytes.addAll(generator.feed(1));
      bytes.addAll(generator.text('Ghi chu: ${repairData['notes']}'));
    }

    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(
      'Cam on quy khach!',
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

    // Header
    bytes.addAll(generator.text(
      'PHIEU BAN HANG',
      styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size2, bold: true),
    ));

    bytes.addAll(generator.text(
      'Shop New - Phu Kien Dien Thoai',
      styles: const PosStyles(align: PosAlign.center),
    ));

    bytes.addAll(generator.feed(1));

    // Sale details
    bytes.addAll(generator.text('Ma don: ${saleData['id'] ?? ''}'));
    bytes.addAll(generator.text('Khach hang: ${saleData['customerName'] ?? ''}'));
    bytes.addAll(generator.text('SDT: ${saleData['customerPhone'] ?? ''}'));

    // Items
    if (saleData['items'] != null) {
      bytes.addAll(generator.feed(1));
      bytes.addAll(generator.text('Danh sach san pham:', styles: const PosStyles(bold: true)));

      for (var item in saleData['items']) {
        bytes.addAll(generator.text('${item['name'] ?? ''} x${item['quantity'] ?? 1}'));
        bytes.addAll(generator.text('  Don gia: ${item['price'] ?? 0} VND'));
      }
    }

    if (saleData['totalAmount'] != null) {
      bytes.addAll(generator.feed(1));
      bytes.addAll(generator.text(
        'Tong tien: ${saleData['totalAmount']} VND',
        styles: const PosStyles(bold: true),
      ));
    }

    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(
      'Cam on quy khach!',
      styles: const PosStyles(align: PosAlign.center),
    ));

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }
}