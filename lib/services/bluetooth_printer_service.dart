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
      // Kiểm tra quyền trước
      final permissionsGranted = await requestBluetoothPermissions();
      if (!permissionsGranted) {
        return {'success': false, 'error': 'Bluetooth permissions not granted'};
      }

      // Kiểm tra Bluetooth có bật
      final isEnabled = await isBluetoothEnabled();
      if (!isEnabled) {
        return {'success': false, 'error': 'Bluetooth is not enabled'};
      }

      // Kiểm tra máy in có trong danh sách paired không
      final pairedPrinters = await getPairedPrinters();
      final isPaired = pairedPrinters.any((printer) => printer.macAdress == macAddress);
      if (!isPaired) {
        return {'success': false, 'error': 'Printer not paired. Please pair the printer first in device settings'};
      }

      // Thử kết nối
      final connected = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      if (connected) {
        return {'success': true, 'message': 'Connected successfully'};
      } else {
        return {'success': false, 'error': 'Failed to connect to printer'};
      }
    } catch (e) {
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
      
      bool connected = false;
      
      if (macAddress != null && macAddress.isNotEmpty) {
        // Kiểm tra xem đã kết nối đến máy in này chưa
        final currentConnection = await isConnected();
        if (currentConnection) {
          // Đã có kết nối, kiểm tra xem có phải máy in được yêu cầu không
          final savedPrinter = await getSavedPrinter();
          if (savedPrinter != null && savedPrinter.macAddress == macAddress) {
            connected = true;
            print('DEBUG: Using existing connection to $macAddress');
          } else {
            // Ngắt kết nối cũ và kết nối đến máy in mới
            // await PrintBluetoothThermal.disconnect(); // Có thể không cần
            connected = await connect(macAddress);
            print('DEBUG: Connected to new printer $macAddress: $connected');
          }
        } else {
          // Chưa có kết nối, kết nối đến máy in được chỉ định
          connected = await connect(macAddress);
          print('DEBUG: Connected to printer $macAddress: $connected');
        }
      } else {
        // Sử dụng máy in đã lưu
        connected = await ensureConnection();
        print('DEBUG: Using saved printer connection: $connected');
      }

      if (!connected) {
        print('DEBUG: No printer connected');
        return false;
      }

      // Tạo bytes cho tem
      final bytes = await _generatePhoneLabelBytes(labelData);
      print('DEBUG: Generated ${bytes.length} bytes for printing');

      // In bytes
      final success = await printBytes(bytes);
      print('DEBUG: Print result: $success');
      
      // Nếu in thành công và có macAddress cụ thể, lưu làm máy in mặc định
      if (success && macAddress != null && macAddress.isNotEmpty) {
        final pairedPrinters = await getPairedPrinters();
        final printerInfo = pairedPrinters.firstWhere(
          (p) => p.macAdress == macAddress,
        );
        if (printerInfo != null) {
          final config = BluetoothPrinterConfig(
            name: printerInfo.name ?? 'Unknown',
            macAddress: printerInfo.macAdress ?? macAddress,
          );
          await savePrinter(config);
          print('DEBUG: Saved printer $macAddress as default');
        }
      }
      
      return success;
    } catch (e) {
      print('DEBUG: Error printing phone label: $e');
      return false;
    }
  }

  // Tạo bytes cho tem điện thoại (tương tự như trong UnifiedPrinterService)
  static Future<List<int>> _generatePhoneLabelBytes(Map<String, dynamic> labelData) async {
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

    // Import cần thiết cho generator
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

    // Thông tin điện thoại - tất cả chữ hoa, loại bỏ dấu
    bytes.addAll(generator.text('TEN: ${removeVietnameseAccents((labelData['name'] ?? '').toString().toUpperCase())}', styles: const PosStyles(bold: true)));
    bytes.addAll(generator.text('IMEI: ${labelData['imei'] ?? ''}'));
    bytes.addAll(generator.text('MAU: ${removeVietnameseAccents((labelData['color'] ?? '').toString().toUpperCase())}'));

    // Giá trên 2 dòng - KPK và CPK
    bytes.addAll(generator.text('KPK: ${(labelData['cost'] ?? 0).toString()} VND', styles: const PosStyles(bold: true)));
    bytes.addAll(generator.text('CPK: ${(labelData['price'] ?? 0).toString()} VND', styles: const PosStyles(bold: true)));

    bytes.addAll(generator.text('TINH TRANG: ${removeVietnameseAccents((labelData['condition'] ?? '').toString().toUpperCase())}'));

    if (labelData['accessories'] != null && labelData['accessories'].toString().isNotEmpty) {
      bytes.addAll(generator.text('PHU KIEN: ${removeVietnameseAccents((labelData['accessories'] ?? '').toString().toUpperCase())}'));
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
    };

    final qrJson = jsonEncode(qrData);
    bytes.addAll(generator.text('QR DATA:', styles: const PosStyles(bold: true)));
    bytes.addAll(generator.text(qrJson, styles: const PosStyles(fontType: PosFontType.fontB)));

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

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
