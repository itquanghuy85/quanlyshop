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

  // Yêu cầu quyền Bluetooth
  static Future<bool> requestBluetoothPermissions() async {
    try {
      // Yêu cầu quyền location (cần cho scan Bluetooth)
      final locationStatus = await Permission.location.request();
      if (!locationStatus.isGranted) {
        return false;
      }

      // Yêu cầu quyền Bluetooth (cho Android 12+)
      if (await Permission.bluetooth.isRestricted || await Permission.bluetooth.isDenied) {
        final bluetoothStatus = await Permission.bluetooth.request();
        if (!bluetoothStatus.isGranted) {
          return false;
        }
      }

      // Yêu cầu quyền Bluetooth connect (cho Android 12+)
      if (await Permission.bluetoothConnect.isRestricted || await Permission.bluetoothConnect.isDenied) {
        final connectStatus = await Permission.bluetoothConnect.request();
        if (!connectStatus.isGranted) {
          return false;
        }
      }

      return true;
    } catch (e) {
      print('Error requesting Bluetooth permissions: $e');
      return false;
    }
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

  // Kết nối đến máy in
  static Future<bool> connect(String macAddress) async {
    return await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
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
