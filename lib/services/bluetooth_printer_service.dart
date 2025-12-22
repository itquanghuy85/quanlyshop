import 'dart:convert';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothPrinterConfig {
  final String name;
  final String macAddress;

  BluetoothPrinterConfig({required this.name, required this.macAddress});

  Map<String, dynamic> toJson() => {
        'name': name,
        'macAddress': macAddress,
      };

  factory BluetoothPrinterConfig.fromJson(Map<String, dynamic> json) =>
      BluetoothPrinterConfig(
        name: json['name'] as String,
        macAddress: json['macAddress'] as String,
      );
}

class BluetoothPrinterService {
  static const String _savedPrinterKey = 'saved_printer';

  // Helper function for logging (used in permission requests)
  static void _addLog(String message) {
    print('BluetoothPrinterService: $message');
  }

  // Lấy máy in đã lưu
  static Future<BluetoothPrinterConfig?> getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_savedPrinterKey);
    if (jsonString != null) {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return BluetoothPrinterConfig.fromJson(json);
    }
    return null;
  }

  // Lưu máy in
  static Future<void> savePrinter(BluetoothPrinterConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(config.toJson());
    await prefs.setString(_savedPrinterKey, jsonString);
  }

  // Xóa máy in đã lưu
  static Future<void> clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedPrinterKey);
  }

  // Kiểm tra quyền bluetooth
  static Future<bool> isPermissionBluetoothGranted() async {
    return await PrintBluetoothThermal.isPermissionBluetoothGranted;
  }

  // Yêu cầu quyền Bluetooth tối ưu cho từng phiên bản Android
  static Future<Map<String, dynamic>> requestBluetoothPermissionsOptimized() async {
    try {
      Map<String, dynamic> results = {
        'success': true,
        'permissions': <String, bool>{},
        'errors': <String>[],
        'warnings': <String>[],
      };

      // Kiểm tra phiên bản Android để áp dụng logic phù hợp
      // Trên Android 12+ (API 31+), Location permission không bắt buộc cho Bluetooth
      // Trên Android 6-11, Location permission vẫn cần thiết

      // 1. Quyền Location (quan trọng cho Android < 12)
      _addLog('Yêu cầu quyền vị trí...');
      final locationStatus = await Permission.location.request();
      results['permissions']['location'] = locationStatus.isGranted;

      if (!locationStatus.isGranted) {
        results['warnings'].add('Quyền vị trí bị từ chối - có thể ảnh hưởng đến việc tìm máy in trên Android cũ');
      }

      // 2. Quyền Bluetooth Connect (quan trọng nhất cho Android 12+)
      _addLog('Yêu cầu quyền Bluetooth Connect...');
      final bluetoothConnectStatus = await Permission.bluetoothConnect.request();
      results['permissions']['bluetoothConnect'] = bluetoothConnectStatus.isGranted;

      if (!bluetoothConnectStatus.isGranted) {
        results['errors'].add('Quyền Bluetooth Connect bị từ chối - không thể kết nối máy in');
        results['success'] = false;
      }

      // 3. Quyền Bluetooth Scan (quan trọng cho việc tìm máy in)
      _addLog('Yêu cầu quyền Bluetooth Scan...');
      final bluetoothScanStatus = await Permission.bluetoothScan.request();
      results['permissions']['bluetoothScan'] = bluetoothScanStatus.isGranted;

      if (!bluetoothScanStatus.isGranted) {
        results['errors'].add('Quyền Bluetooth Scan bị từ chối - không thể tìm máy in');
        results['success'] = false;
      }

      // 4. Quyền Bluetooth cơ bản (cho Android < 12)
      _addLog('Yêu cầu quyền Bluetooth cơ bản...');
      final bluetoothStatus = await Permission.bluetooth.request();
      results['permissions']['bluetooth'] = bluetoothStatus.isGranted;

      if (!bluetoothStatus.isGranted) {
        results['warnings'].add('Quyền Bluetooth cơ bản bị từ chối - có thể ảnh hưởng trên Android cũ');
      }

      // 5. Quyền Bluetooth Advertise (tùy chọn)
      final bluetoothAdvertiseStatus = await Permission.bluetoothAdvertise.request();
      results['permissions']['bluetoothAdvertise'] = bluetoothAdvertiseStatus.isGranted;

      if (!bluetoothAdvertiseStatus.isGranted) {
        results['warnings'].add('Quyền Bluetooth Advertise bị từ chối - một số thiết bị có thể không tương thích');
      }

      return results;
    } catch (e) {
      print('Lỗi khi yêu cầu quyền Bluetooth: $e');
      return {
        'success': false,
        'permissions': <String, bool>{},
        'errors': ['Lỗi hệ thống khi yêu cầu quyền: $e'],
        'warnings': <String>[],
      };
    }
  }

  // Yêu cầu quyền Bluetooth toàn diện (phương thức cũ)
  static Future<Map<String, dynamic>> requestBluetoothPermissionsComprehensive() async {
    return await requestBluetoothPermissionsOptimized();
  }

  // Yêu cầu quyền Bluetooth (phương thức cũ, giữ để tương thích)
  static Future<bool> requestBluetoothPermissions() async {
    final result = await requestBluetoothPermissionsComprehensive();
    return result['success'] as bool;
  }

  // Kiểm tra bluetooth có bật
  static Future<bool> isBluetoothEnabled() async {
    return await PrintBluetoothThermal.bluetoothEnabled;
  }

  // Kiểm tra kết nối
  static Future<bool> isConnected() async {
    return await PrintBluetoothThermal.connectionStatus;
  }

  // Lấy danh sách máy in đã pair
  static Future<List<BluetoothInfo>> getPairedPrinters() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  // Scan máy in Bluetooth mới (không chỉ paired)
  static Future<List<BluetoothInfo>> scanBluetoothPrinters() async {
    try {
      // Yêu cầu quyền trước
      final permissionsGranted = await requestBluetoothPermissions();
      if (!permissionsGranted) {
        throw Exception('Bluetooth permissions not granted');
      }

      // Bật Bluetooth nếu chưa bật
      final isEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!isEnabled) {
        // Thử bật Bluetooth
        await PrintBluetoothThermal.bluetoothEnabled;
        await Future.delayed(const Duration(seconds: 2)); // Đợi Bluetooth bật
      }

      // Sử dụng flutter_blue_plus để scan devices
      List<ScanResult> scanResults = [];
      try {
        // Start scan
        FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
        
        // Wait for scan to complete and get results
        await Future.delayed(const Duration(seconds: 10));
        scanResults = FlutterBluePlus.lastScanResults;
        
        await FlutterBluePlus.stopScan();
      } catch (e) {
        print('FlutterBluePlus scan failed: $e');
      }

      // Chuyển đổi sang BluetoothInfo format
      List<BluetoothInfo> printers = [];
      for (var result in scanResults) {
        // Lọc devices có thể là printer (có thể cải thiện logic này)
        final device = result.device;
        final name = device.name.isNotEmpty ? device.name : 'Unknown Device';
        printers.add(BluetoothInfo(
          name: name,
          macAdress: device.remoteId.str,
        ));
      }

      // Nếu không tìm thấy bằng flutter_blue_plus, thử lấy paired devices
      if (printers.isEmpty) {
        printers = await PrintBluetoothThermal.pairedBluetooths;
      }

      return printers;
    } catch (e) {
      print('Error scanning Bluetooth printers: $e');
      // Fallback to paired devices
      return await PrintBluetoothThermal.pairedBluetooths;
    }
  }

  // Kết nối đến máy in với kiểm tra chi tiết
  static Future<Map<String, dynamic>> connectWithStatus(String macAddress) async {
    try {
      print('DEBUG: Starting connection to printer $macAddress');

      // Kiểm tra quyền trước
      final permissionsGranted = await requestBluetoothPermissions();
      print('DEBUG: Bluetooth permissions granted: $permissionsGranted');
      if (!permissionsGranted) {
        return {'success': false, 'error': 'Bluetooth permissions not granted'};
      }

      // Kiểm tra Bluetooth có bật
      final isEnabled = await isBluetoothEnabled();
      print('DEBUG: Bluetooth enabled: $isEnabled');
      if (!isEnabled) {
        return {'success': false, 'error': 'Bluetooth is not enabled'};
      }

      // Kiểm tra máy in có trong danh sách paired không
      final pairedPrinters = await getPairedPrinters();
      print('DEBUG: Found ${pairedPrinters.length} paired printers');
      final isPaired = pairedPrinters.any((printer) => printer.macAdress == macAddress);
      print('DEBUG: Printer $macAddress is paired: $isPaired');
      if (!isPaired) {
        return {'success': false, 'error': 'Printer not paired. Please pair the printer first in device settings'};
      }

      // Thử kết nối
      print('DEBUG: Attempting to connect via PrintBluetoothThermal.connect');
      final connected = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      print('DEBUG: PrintBluetoothThermal.connect result: $connected');

      if (connected) {
        return {'success': true, 'message': 'Connected successfully'};
      } else {
        return {'success': false, 'error': 'Failed to connect to printer'};
      }
    } catch (e) {
      print('DEBUG: Exception during connection: $e');
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Kết nối đến máy in (giữ lại để tương thích)
  static Future<bool> connect(String macAddress) async {
    final result = await connectWithStatus(macAddress);
    return result['success'] ?? false;
  }

  // In dữ liệu
  static Future<bool> printBytes(List<int> bytes) async {
    return await PrintBluetoothThermal.writeBytes(bytes);
  }

  // Alias cho printBytes
  static Future<bool> writeBytes(List<int> bytes) async {
    return await printBytes(bytes);
  }

  // In tem điện thoại với máy in Bluetooth cụ thể
  // In tem điện thoại qua Bluetooth
  static Future<bool> printPhoneLabel(Map<String, dynamic> labelData, [String? macAddress]) async {
    try {
      print('DEBUG: printPhoneLabel called with data: $labelData');
      // Log chi tiết từng trường dữ liệu
      labelData.forEach((k, v) {
        print('DEBUG: labelData[$k] = ${v?.toString() ?? 'null'}');
      });

      bool connected = false;

      if (macAddress != null && macAddress.isNotEmpty) {
        final currentConnection = await isConnected();
        if (currentConnection) {
          final savedPrinter = await getSavedPrinter();
          if (savedPrinter != null && savedPrinter.macAddress == macAddress) {
            connected = true;
            print('DEBUG: Using existing connection to $macAddress');
          } else {
            print('DEBUG: Attempting to connect to new printer $macAddress');
            connected = await connect(macAddress);
            print('DEBUG: Connected to new printer $macAddress: $connected');
          }
        } else {
          print('DEBUG: No existing connection, connecting to $macAddress');
          connected = await connect(macAddress);
          print('DEBUG: Connected to printer $macAddress: $connected');
        }
      } else {
        print('DEBUG: No specific MAC address, using saved printer');
        connected = await ensureConnection();
        print('DEBUG: Using saved printer connection: $connected');
      }

      if (!connected) {
        print('DEBUG: No printer connected');
        return false;
      }

      // Tạo bytes cho tem
      List<int> bytes = [];
      try {
        bytes = await _generatePhoneLabelBytesSimple(labelData);
        print('DEBUG: Generated ${bytes.length} bytes for printing');
      } catch (genErr) {
        print('DEBUG: Error generating label bytes: $genErr');
        return false;
      }

      // In bytes
      bool success = false;
      try {
        success = await printBytes(bytes);
        print('DEBUG: Print result: $success');
      } catch (printErr) {
        print('DEBUG: Error sending bytes to printer: $printErr');
        return false;
      }

      // Nếu in thành công và có macAddress cụ thể, lưu làm máy in mặc định
      if (success && macAddress != null && macAddress.isNotEmpty) {
        try {
          final pairedPrinters = await getPairedPrinters();
          final printerInfo = pairedPrinters.firstWhere(
            (p) => p.macAdress == macAddress,
          );
          final config = BluetoothPrinterConfig(
            name: printerInfo.name,
            macAddress: printerInfo.macAdress,
          );
          await savePrinter(config);
          print('DEBUG: Saved printer $macAddress as default');
        } catch (saveErr) {
          print('DEBUG: Error saving default printer: $saveErr');
        }
      }

      return success;
    } catch (e, stack) {
      print('DEBUG: Error printing phone label: $e');
      print('DEBUG: Stacktrace: $stack');
      return false;
    }
  }

  // Tạo bytes cho tem điện thoại đơn giản (không QR để tránh lỗi máy in)
  static Future<List<int>> _generatePhoneLabelBytesSimple(Map<String, dynamic> labelData) async {
    // Hàm loại bỏ dấu tiếng Việt
    String removeVietnameseAccents(String str) {
      const vietnameseChars = 'àáảãạâầấẩẫậăằắẳẵặèéẻẽẹêềếểễệđìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵÀÁẢÃẠÂẦẤẨẪẬĂẰẮẲẴẶÈÉẺẼẸÊỀẾỂỄỆĐÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴ';
      const asciiChars = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeediiiiiooooooooooooooooouuuuuuuuuuuyyyyyAAAAAAAAAAAAAAAAAEEEEEEEEEEEDIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYY';
      var result = str;
      for (var i = 0; i < vietnameseChars.length; i++) {
        result = result.replaceAll(vietnameseChars[i], asciiChars[i]);
      }
      return result;
    }

    // Validate dữ liệu đầu vào
    final name = removeVietnameseAccents((labelData['name'] ?? 'N/A').toString().toUpperCase());
    final imei = (labelData['imei'] ?? 'N/A').toString();
    final color = removeVietnameseAccents((labelData['color'] ?? 'N/A').toString().toUpperCase());
    final capacity = removeVietnameseAccents((labelData['capacity'] ?? '').toString().toUpperCase());
    final cost = (labelData['cost'] ?? '0').toString();
    final price = (labelData['price'] ?? '0').toString(); // KPK
    final cpkPrice = (labelData['cpkPrice'] ?? cost).toString(); // CPK
    final condition = removeVietnameseAccents((labelData['condition'] ?? 'N/A').toString().toUpperCase());
    final accessories = labelData['accessories'] != null && labelData['accessories'].toString().isNotEmpty
        ? removeVietnameseAccents(labelData['accessories'].toString().toUpperCase())
        : 'KHONG CO';

    print('DEBUG: Simple label data - name: $name, imei: $imei, color: $color, capacity: $capacity, cost: $cost, price: $price, cpkPrice: $cpkPrice');

    // Import cần thiết cho generator
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    final bytes = <int>[];
    bytes.addAll(generator.reset());

    // Tên sản phẩm căn giữa
    final productInfo = capacity.isNotEmpty ? '$name $capacity' : name;
    bytes.addAll(generator.text(productInfo, styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1)));
    bytes.addAll(generator.feed(1));

    // IMEI căn giữa
    bytes.addAll(generator.text('IMEI: $imei', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1)));
    bytes.addAll(generator.feed(1));

    // KPK GIÁ
    bytes.addAll(generator.text('KPK GIÁ: $price VND', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1)));
    bytes.addAll(generator.feed(1));

    // PK GIÁ
    bytes.addAll(generator.text('PK GIÁ: $cpkPrice VND', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1)));
    bytes.addAll(generator.feed(1));

    // QR code căn giữa
    final qrData = {
      'type': 'phone_label',
      'name': name,
      'imei': imei,
      'color': color,
      'capacity': capacity,
      'kpk': price,
      'pk': cpkPrice,
      'condition': condition,
      'accessories': accessories,
    };

    try {
      final qrJson = jsonEncode(qrData);
      print('DEBUG: QR JSON length: ${qrJson.length}');
      if (qrJson.length < 200) { // Tăng giới hạn độ dài
        bytes.addAll(generator.feed(1));
        bytes.addAll(generator.qrcode(qrJson, size: QRSize.Size2)); // Tăng size QR
      } else {
        print('DEBUG: QR data too long, skipping QR code');
      }
    } catch (e) {
      print('DEBUG: Error encoding QR data: $e');
    }

    bytes.addAll(generator.feed(1)); // Giảm khoảng cách cuối
    bytes.addAll(generator.cut());

    print('DEBUG: Simple label bytes generated: ${bytes.length}');
    return bytes;
  }

  // Đảm bảo kết nối
  static Future<bool> ensureConnection() async {
    final connected = await isConnected();
    if (!connected) {
      final savedPrinter = await getSavedPrinter();
      if (savedPrinter != null) {
        return await connect(savedPrinter.macAddress);
      }
    }
    return connected;
  }
}
