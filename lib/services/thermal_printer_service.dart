import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'bluetooth_printer_service.dart';

class ThermalPrinterService {
  static Future<String?> getPrinterIP() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('thermal_printer_ip');
  }

  static Future<Map<String, dynamic>> getDesignSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'size': prefs.getString('thermal_label_size') ?? '3x4',
      'showColor': prefs.getBool('thermal_show_color') ?? true,
      'showIMEI': prefs.getBool('thermal_show_imei') ?? true,
      'showCondition': prefs.getBool('thermal_show_condition') ?? true,
      'showPrice': prefs.getBool('thermal_show_price') ?? true,
      'showAccessories': prefs.getBool('thermal_show_accessories') ?? true,
      'fontSize': prefs.getString('thermal_font_size') ?? 'medium',
    };
  }

  static Future<bool> printDeviceLabel({
    required String deviceName,
    String? color,
    String? imei,
    String? condition,
    String? price,
    String? accessories,
  }) async {
    final printer = await BluetoothPrinterService.getSavedPrinter();
    if (printer == null) return false;

    final settings = await getDesignSettings();

    // Kết nối máy in
    final connected = await BluetoothPrinterService.connect(printer.macAddress);
    if (!connected) return false;

    const PaperSize paper = PaperSize.mm58;
    final profile = await CapabilityProfile.load();
    final generator = Generator(paper, profile);

    List<int> bytes = [];

    // In tiêu đề
    bytes += generator.text(deviceName, styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.feed(1);

    // In thông tin theo cài đặt
    if (settings['showColor'] == true && color != null && color.isNotEmpty) {
      bytes += generator.text('Mau: $color');
    }
    if (settings['showIMEI'] == true && imei != null && imei.isNotEmpty) {
      bytes += generator.text('IMEI: $imei');
    }
    if (settings['showCondition'] == true && condition != null && condition.isNotEmpty) {
      bytes += generator.text('Tinh trang: $condition');
    }
    if (settings['showPrice'] == true && price != null && price.isNotEmpty) {
      bytes += generator.text('Gia: $price');
    }
    if (settings['showAccessories'] == true && accessories != null && accessories.isNotEmpty) {
      bytes += generator.text('Phu kien: $accessories');
    }

    bytes += generator.feed(2);
    bytes += generator.cut();

    return await BluetoothPrinterService.printBytes(bytes);
  }

  static Future<bool> testConnection() async {
    final printer = await BluetoothPrinterService.getSavedPrinter();
    if (printer == null) return false;

    final connected = await BluetoothPrinterService.connect(printer.macAddress);
    if (!connected) return false;

    const PaperSize paper = PaperSize.mm58;
    final profile = await CapabilityProfile.load();
    final generator = Generator(paper, profile);

    List<int> bytes = [];
    bytes += generator.text('TEST KET NOI BLUETOOTH', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.feed(2);
    bytes += generator.cut();

    return await BluetoothPrinterService.printBytes(bytes);
  }
}
