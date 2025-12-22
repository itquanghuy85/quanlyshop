import 'dart:convert';
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

  // Yêu cầu quyền Bluetooth toàn diện
  static Future<Map<String, dynamic>> requestBluetoothPermissionsComprehensive() async {
    try {
      Map<String, dynamic> results = {
        'success': true,
        'permissions': <String, bool>{},
        'errors': <String>[],
      };

      // 1. Quyền Location (cần cho Bluetooth scanning)
      _addLog('Requesting location permissions...');
      final locationStatus = await Permission.location.request();
      results['permissions']['location'] = locationStatus.isGranted;
      if (!locationStatus.isGranted) {
        results['errors'].add('Location permission denied');
        results['success'] = false;
      }

      // 2. Quyền Location luôn cho phép (Android 10+)
      if (locationStatus.isGranted) {
        final locationAlwaysStatus = await Permission.locationAlways.request();
        results['permissions']['locationAlways'] = locationAlwaysStatus.isGranted;
        if (!locationAlwaysStatus.isGranted) {
          results['errors'].add('Location always permission denied (may affect background scanning)');
        }
      }

      // 3. Quyền Bluetooth cơ bản (cho Android < 12)
      final bluetoothStatus = await Permission.bluetooth.request();
      results['permissions']['bluetooth'] = bluetoothStatus.isGranted;
      if (!bluetoothStatus.isGranted) {
        results['errors'].add('Bluetooth permission denied');
        results['success'] = false;
      }

      // 4. Quyền Bluetooth Connect (Android 12+)
      final bluetoothConnectStatus = await Permission.bluetoothConnect.request();
      results['permissions']['bluetoothConnect'] = bluetoothConnectStatus.isGranted;
      if (!bluetoothConnectStatus.isGranted) {
        results['errors'].add('Bluetooth Connect permission denied');
        results['success'] = false;
      }

      // 5. Quyền Bluetooth Scan (Android 12+)
      final bluetoothScanStatus = await Permission.bluetoothScan.request();
      results['permissions']['bluetoothScan'] = bluetoothScanStatus.isGranted;
      if (!bluetoothScanStatus.isGranted) {
        results['errors'].add('Bluetooth Scan permission denied');
        results['success'] = false;
      }

      // 6. Quyền Bluetooth Advertise (Android 12+)
      final bluetoothAdvertiseStatus = await Permission.bluetoothAdvertise.request();
      results['permissions']['bluetoothAdvertise'] = bluetoothAdvertiseStatus.isGranted;
      if (!bluetoothAdvertiseStatus.isGranted) {
        results['errors'].add('Bluetooth Advertise permission denied (may affect some devices)');
      }

      return results;
    } catch (e) {
      print('Error requesting comprehensive Bluetooth permissions: $e');
      return {
        'success': false,
        'permissions': <String, bool>{},
        'errors': ['Exception during permission request: $e'],
      };
    }
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
