import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import '../services/notification_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/thermal_printer_service.dart';
import '../services/wifi_printer_service.dart';
import '../services/network_printer_scanner.dart';
import '../services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'label_designer_view.dart';
import 'imei_qr_printer_view.dart';
import 'pty_print_designer_view.dart';
import 'repair_invoice_template_view.dart';
import 'sale_invoice_template_view.dart';

/// Màn hình cài đặt máy in - Đơn giản, tập trung vào kết nối
class PrinterSettingsView extends StatefulWidget {
  const PrinterSettingsView({super.key});

  @override
  State<PrinterSettingsView> createState() => _PrinterSettingsViewState();
}

class _PrinterSettingsViewState extends State<PrinterSettingsView> {
  // Wifi printer
  final _ipCtrl = TextEditingController();
  final _backupIpCtrl = TextEditingController();
  
  // Bluetooth printer
  BluetoothPrinterConfig? _selectedBT;
  bool _isScanning = false;
  List<BluetoothInfo> _btDevices = [];
  
  // Network printer scanner
  bool _isScanningNetwork = false;
  double _scanProgress = 0.0;
  List<DiscoveredPrinter> _discoveredPrinters = [];
  String? _localIp;
  String? _savedPrinterName;
  
  // Receipt settings
  final _rcNoteCtrl = TextEditingController();
  final _warrantyPolicyCtrl = TextEditingController();
  final _returnPolicyCtrl = TextEditingController();
  bool _showRcLogo = true;
  bool _showRcPhone = true;
  bool _showRcQR = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBT = await BluetoothPrinterService.getSavedPrinter();
    final localIp = await NetworkPrinterScanner.getLocalIp();
    
    if (!mounted) return;
    
    // If policies are empty, try loading from Firestore (new device)
    String warranty = prefs.getString('warranty_policy') ?? '';
    String returnP = prefs.getString('return_policy') ?? '';
    if (warranty.isEmpty && returnP.isEmpty) {
      try {
        final shopId = await UserService.getCurrentShopId();
        if (shopId != null && shopId.isNotEmpty) {
          final shopDoc = await FirebaseFirestore.instance
              .collection('shops')
              .doc(shopId)
              .get();
          final data = shopDoc.data();
          warranty = (data?['warrantyPolicy'] ?? '').toString();
          returnP = (data?['returnPolicy'] ?? '').toString();
          if (warranty.isNotEmpty || returnP.isNotEmpty) {
            await prefs.setString('warranty_policy', warranty);
            await prefs.setString('return_policy', returnP);
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _ipCtrl.text = prefs.getString('printer_ip') ?? '';
      _backupIpCtrl.text = prefs.getString('backup_printer_ip') ?? '';
      _selectedBT = savedBT;
      _showRcLogo = prefs.getBool('receipt_show_logo') ?? true;
      _showRcPhone = prefs.getBool('receipt_show_phone') ?? true;
      _showRcQR = prefs.getBool('receipt_show_qr') ?? true;
      _rcNoteCtrl.text = prefs.getString('receipt_note') ?? 'Cảm ơn quý khách!';
      _warrantyPolicyCtrl.text = warranty;
      _returnPolicyCtrl.text = returnP;
      _savedPrinterName = prefs.getString('printer_name');
      _localIp = localIp;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_ip', _ipCtrl.text.trim());
    await prefs.setString('backup_printer_ip', _backupIpCtrl.text.trim());
    if (_savedPrinterName != null) {
      await prefs.setString('printer_name', _savedPrinterName!);
    }
    await prefs.setBool('receipt_show_logo', _showRcLogo);
    await prefs.setBool('receipt_show_phone', _showRcPhone);
    await prefs.setBool('receipt_show_qr', _showRcQR);
    await prefs.setString('receipt_note', _rcNoteCtrl.text);
    await prefs.setString('warranty_policy', _warrantyPolicyCtrl.text);
    await prefs.setString('return_policy', _returnPolicyCtrl.text);

    // Sync policies to Firestore shop doc so all devices in the same shop
    // share the same warranty/return policy text.
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId != null && shopId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .set({
          'warrantyPolicy': _warrantyPolicyCtrl.text,
          'returnPolicy': _returnPolicyCtrl.text,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error syncing policies to Firestore: $e');
    }

    if (!mounted) return;
    NotificationService.showSnackBar(AppLocalizations.of(context)!.printerSettingsSaved, color: AppColors.success);
  }

  Future<void> _scanBluetooth() async {
    setState(() => _isScanning = true);
    
    try {
      final hasPermission = await BluetoothPrinterService.requestBluetoothPermissions();
      if (!hasPermission) {
        NotificationService.showSnackBar(AppLocalizations.of(context)!.bluetoothPermissionRequired, color: AppColors.warning);
        setState(() => _isScanning = false);
        return;
      }

      final isEnabled = await BluetoothPrinterService.isBluetoothEnabled();
      if (!isEnabled) {
        NotificationService.showSnackBar(AppLocalizations.of(context)!.enableBluetoothToScan, color: AppColors.warning);
        setState(() => _isScanning = false);
        return;
      }

      final devices = await BluetoothPrinterService.getPairedPrinters();
      
      if (!mounted) return;
      setState(() {
        _btDevices = devices;
        _isScanning = false;
      });

      if (devices.isEmpty) {
        NotificationService.showSnackBar(AppLocalizations.of(context)!.noDevicesFound, color: AppColors.warning);
      } else {
        _showBluetoothDevicesDialog();
      }
    } catch (e) {
      setState(() => _isScanning = false);
      NotificationService.showSnackBar(AppLocalizations.of(context)!.bluetoothScanError(e.toString()), color: AppColors.error);
    }
  }

  void _showBluetoothDevicesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.selectBluetoothPrinter),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _btDevices.length,
            itemBuilder: (_, i) {
              final device = _btDevices[i];
              final isSelected = _selectedBT?.macAddress == device.macAdress;
              return ListTile(
                leading: Icon(
                  Icons.print,
                  color: isSelected ? AppColors.success : AppColors.textHint,
                ),
                title: Text(device.name),
                subtitle: Text(device.macAdress),
                trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.success) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  final config = BluetoothPrinterConfig(
                    name: device.name,
                    macAddress: device.macAdress,
                  );
                  await BluetoothPrinterService.savePrinter(config);
                  if (device.name.toUpperCase().contains('PT-50DC')) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('label_paper_size', '50');
                    await prefs.setString('paper_size', '50mm');
                    await prefs.setBool('pt50dc_force_raster_qr', true);
                    await prefs.setString('label_code_type', 'qr');
                    NotificationService.showSnackBar(
                      'Đã áp dụng preset PT-50DC (khổ 50mm).',
                      color: AppColors.success,
                    );
                  }
                  setState(() => _selectedBT = config);
                  NotificationService.showSnackBar(AppLocalizations.of(context)!.selected(device.name), color: AppColors.success);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.close),
          ),
        ],
      ),
    );
  }

  Future<void> _testWifiPrinter() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) {
      NotificationService.showSnackBar(AppLocalizations.of(context)!.enterIpFirst, color: AppColors.warning);
      return;
    }
    
    // Save IP to SharedPreferences first so other screens can use it
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_ip', ip);
    if (_backupIpCtrl.text.trim().isNotEmpty) {
      await prefs.setString('backup_printer_ip', _backupIpCtrl.text.trim());
    }
    
    NotificationService.showSnackBar(AppLocalizations.of(context)!.testingConnection, color: AppColors.primary);
    try {
      print('WIFI_TEST: Connecting to $ip:9100...');
      // Test connection by trying to connect to printer port
      final socket = await Socket.connect(ip, 9100, timeout: const Duration(seconds: 8));
      print('WIFI_TEST: Socket connected, sending test print...');
      
      // Tạo lệnh ESC/POS test
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      final bytes = <int>[];
      bytes.addAll(generator.reset());
      bytes.addAll(generator.text('=== TEST WIFI PRINTER ===', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2)));
      bytes.addAll(generator.text('Shop Manager', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('IP: $ip', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('Time: ${DateTime.now().toString().substring(0, 19)}', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('------------------------', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('Ket noi WiFi thanh cong!', styles: const PosStyles(align: PosAlign.center, bold: true)));
      bytes.addAll(generator.feed(2));
      bytes.addAll(generator.cut());
      
      // Gửi dữ liệu
      socket.add(bytes);
      await socket.flush();
      print('WIFI_TEST: Data sent, ${bytes.length} bytes');
      
      await Future.delayed(const Duration(milliseconds: 500));
      await socket.close();
      print('WIFI_TEST: Socket closed');
      
      NotificationService.showSnackBar('✅ In thử WiFi thành công!', color: AppColors.success);
    } on SocketException catch (e) {
      print('WIFI_TEST: SocketException: $e');
      NotificationService.showSnackBar('❌ Lỗi kết nối: ${e.message}', color: AppColors.error);
    } on TimeoutException catch (e) {
      print('WIFI_TEST: Timeout: $e');
      NotificationService.showSnackBar('❌ Timeout: Không kết nối được $ip', color: AppColors.error);
    } catch (e) {
      print('WIFI_TEST: Error: $e');
      NotificationService.showSnackBar(AppLocalizations.of(context)!.connectionFailed(e.toString()), color: AppColors.error);
    }
  }

  /// Scan the local network for printers on port 9100
  Future<void> _scanNetworkPrinters() async {
    if (_isScanningNetwork) return;
    
    setState(() {
      _isScanningNetwork = true;
      _scanProgress = 0.0;
      _discoveredPrinters = [];
    });

    try {
      final results = await NetworkPrinterScanner.scanNetwork(
        onProgress: (progress) {
          if (mounted) setState(() => _scanProgress = progress);
        },
        onFound: (printer) {
          if (mounted) {
            setState(() => _discoveredPrinters = [..._discoveredPrinters, printer]);
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _discoveredPrinters = results;
        _isScanningNetwork = false;
      });

      if (results.isEmpty) {
        NotificationService.showSnackBar(
          'Không tìm thấy máy in nào trong mạng',
          color: AppColors.warning,
        );
      } else {
        _showDiscoveredPrintersDialog();
      }
    } catch (e) {
      if (mounted) setState(() => _isScanningNetwork = false);
      NotificationService.showSnackBar('Lỗi quét mạng: $e', color: AppColors.error);
    }
  }

  /// Show discovered printers dialog for selection
  void _showDiscoveredPrintersDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary, AppColors.info]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.print, color: AppColors.surface, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Máy in tìm thấy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  Text('${_discoveredPrinters.length} thiết bị', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _discoveredPrinters.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final printer = _discoveredPrinters[i];
              final isCurrentIp = _ipCtrl.text.trim() == printer.ip;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isCurrentIp ? AppColors.success : AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.print,
                    color: isCurrentIp ? AppColors.success : AppColors.primary,
                    size: 24,
                  ),
                ),
                title: Text(
                  printer.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isCurrentIp ? AppColors.success : null,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Icon(Icons.lan, size: 14, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(printer.ip, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Icon(Icons.speed, size: 14, color: AppColors.textHint),
                    const SizedBox(width: 2),
                    Text('${printer.responseTimeMs}ms', style: TextStyle(fontSize: 14, color: AppColors.textHint)),
                  ],
                ),
                trailing: isCurrentIp
                    ? const Icon(Icons.check_circle, color: AppColors.success)
                    : Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textHint),
                onTap: () async {
                  Navigator.pop(ctx);
                  // Set IP and save printer name
                  setState(() {
                    _ipCtrl.text = printer.ip;
                    _savedPrinterName = printer.name;
                  });
                  // Auto-save to SharedPreferences
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('printer_ip', printer.ip);
                  await prefs.setString('printer_name', printer.name);
                  NotificationService.showSnackBar(
                    '✅ Đã chọn ${printer.name} (${printer.ip})',
                    color: AppColors.success,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _scanNetworkPrinters();
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Quét lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _testBluetoothPrinter() async {
    if (_selectedBT == null) {
      NotificationService.showSnackBar(AppLocalizations.of(context)!.selectBluetoothPrinterFirst, color: AppColors.warning);
      return;
    }
    
    NotificationService.showSnackBar(AppLocalizations.of(context)!.testingConnection, color: AppColors.primary);
    print('BT_TEST: Connecting to ${_selectedBT!.macAddress}...');
    
    final success = await BluetoothPrinterService.connect(_selectedBT!.macAddress);
    print('BT_TEST: Connect result: $success');
    
    if (success) {
      // Tạo lệnh ESC/POS test
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      final bytes = <int>[];
      bytes.addAll(generator.reset());
      bytes.addAll(generator.text('=== TEST BLUETOOTH ===', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2)));
      bytes.addAll(generator.text('Shop Manager', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('Printer: ${_selectedBT!.name}', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('MAC: ${_selectedBT!.macAddress}', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('Time: ${DateTime.now().toString().substring(0, 19)}', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('------------------------', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text('Ket noi Bluetooth OK!', styles: const PosStyles(align: PosAlign.center, bold: true)));
      bytes.addAll(generator.feed(2));
      bytes.addAll(generator.cut());
      
      print('BT_TEST: Sending ${bytes.length} bytes...');
      final printResult = await BluetoothPrinterService.printBytes(bytes);
      print('BT_TEST: Print result: $printResult');
      
      if (printResult) {
        NotificationService.showSnackBar('✅ In thử Bluetooth thành công!', color: AppColors.success);
      } else {
        NotificationService.showSnackBar('❌ Kết nối OK nhưng gửi dữ liệu thất bại!', color: AppColors.warning);
      }
    } else {
      NotificationService.showSnackBar(AppLocalizations.of(context)!.bluetoothConnectionFailed, color: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.printerSettings,
          style: AppTextStyles.headline3.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: AppLocalizations.of(context)!.saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // THIẾT KẾ TEM - Card nổi bật
            _buildLabelDesignCard(),
            const SizedBox(height: AppSpacing.lg),
            
            // KẾT NỐI MÁY IN WIFI
            _buildWifiPrinterCard(),
            const SizedBox(height: AppSpacing.lg),
            
            // KẾT NỐI MÁY IN BLUETOOTH
            _buildBluetoothPrinterCard(),
            const SizedBox(height: AppSpacing.lg),
            
            // CÀI ĐẶT HÓA ĐƠN
            _buildReceiptSettingsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelDesignCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.lg)),
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.secondaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                  child: const Icon(Icons.design_services, color: AppColors.surface, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.productLabelDesign,
                        style: AppTextStyles.headline3.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)!.customizeContentAndFontSize,
                        style: AppTextStyles.body2.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            
            // Thiết kế tem PRO
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Icon(
                  Icons.tune,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              title: Text(
                AppLocalizations.of(context)!.labelDesignTitle,
                style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                AppLocalizations.of(context)!.layoutShopInfoFormula,
                style: AppTextStyles.body2,
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Text(
                  AppLocalizations.of(context)!.hot,
                  style: AppTextStyles.caption.copyWith(
                    color: Theme.of(context).colorScheme.tertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LabelDesignerView()),
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.print, color: AppColors.textPrimary, size: 20),
              ),
              title: const Text('PTY 1:1 Designer', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Thiết kế tem 1:1, kéo thả và in bitmap'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PtyPrintDesignerView()),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'MẪU IN HÓA ĐƠN',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.build_circle, color: AppColors.primary, size: 18),
                    ),
                    title: const Text('Mẫu phiếu sửa', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Chỉnh sửa mẫu in phiếu sửa chữa'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RepairInvoiceTemplateView()),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.shopping_bag, color: AppColors.success, size: 18),
                    ),
                    title: const Text('Mẫu hóa đơn bán', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Chỉnh sửa mẫu in hóa đơn bán hàng'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SaleInvoiceTemplateView()),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: AppSpacing.lg),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.qr_code_2, color: AppColors.success, size: 20),
              ),
              title: const Text(
                'In tem QR/Barcode IMEI hàng loạt',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Chọn IMEI và in hàng loạt qua Bluetooth/WiFi'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImeiQrPrinterView()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWifiPrinterCard() {
    final hasIp = _ipCtrl.text.trim().isNotEmpty;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.lg)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                  child: Icon(Icons.wifi, color: Theme.of(context).colorScheme.primary, size: 22),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.wifiPrinter,
                        style: AppTextStyles.headline3.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (_localIp != null)
                        Text('Mạng: $_localIp', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
                    ],
                  ),
                ),
                if (hasIp)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text('Đã cấu hình', style: TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Connected printer info
            if (hasIp && _savedPrinterName != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.info],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Row(
                  children: [
                    Icon(Icons.print, color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_savedPrinterName!, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                          Text(_ipCtrl.text.trim(), style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: AppColors.textHint),
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('printer_name');
                        setState(() => _savedPrinterName = null);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _ipCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.printerIpAddress,
                hintText: '192.168.1.xxx',
                prefixIcon: const Icon(Icons.router),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _backupIpCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.backupIpOptional,
                hintText: '192.168.1.xxx',
                prefixIcon: const Icon(Icons.router_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 14),

            // Scanner progress indicator
            if (_isScanningNetwork) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Đang quét mạng... ${(_scanProgress * 100).toInt()}%',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (_discoveredPrinters.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Tìm thấy ${_discoveredPrinters.length}',
                              style: TextStyle(fontSize: 14, color: AppColors.success, fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _scanProgress,
                        backgroundColor: AppColors.primary,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Buttons row: Scan Network + Test Connection
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanningNetwork ? null : _scanNetworkPrinters,
                    icon: _isScanningNetwork
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface))
                        : const Icon(Icons.radar, size: 20),
                    label: Text(_isScanningNetwork ? 'Đang quét...' : 'QUÉT TÌM MÁY IN'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      foregroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testWifiPrinter,
                    icon: const Icon(Icons.wifi_find, size: 20),
                    label: Text(AppLocalizations.of(context)!.testWifiConnection),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),

            // Show discovered printers inline if available and dialog was dismissed
            if (!_isScanningNetwork && _discoveredPrinters.isNotEmpty) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: _showDiscoveredPrintersDialog,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.devices, size: 18, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tìm thấy ${_discoveredPrinters.length} máy in - Nhấn để xem',
                          style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w500, fontSize: 14),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.success),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothPrinterCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bluetooth, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.bluetoothPrinter, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            const SizedBox(height: 12),
            
            // Máy in đã chọn
            if (_selectedBT != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedBT!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(_selectedBT!.macAddress, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () async {
                        await BluetoothPrinterService.clearSavedPrinter();
                        setState(() => _selectedBT = null);
                      },
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.textHint),
                    const SizedBox(width: 12),
                    Text(AppLocalizations.of(context)!.noBluetoothPrinterSelected, style: const TextStyle(color: AppColors.textHint)),
                  ],
                ),
              ),
            
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _scanBluetooth,
                    icon: _isScanning 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface))
                        : const Icon(Icons.bluetooth_searching),
                    label: Text(_isScanning ? AppLocalizations.of(context)!.scanning : AppLocalizations.of(context)!.scanBluetooth),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (_selectedBT != null) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _testBluetoothPrinter,
                    icon: const Icon(Icons.print),
                    label: Text(AppLocalizations.of(context)!.test),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptSettingsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: AppColors.warning),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.receiptSettings, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.showShopLogo),
              value: _showRcLogo,
              onChanged: (v) => setState(() => _showRcLogo = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.showPhoneAndAddress),
              value: _showRcPhone,
              onChanged: (v) => setState(() => _showRcPhone = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.showQrCodeLookup),
              value: _showRcQR,
              onChanged: (v) => setState(() => _showRcQR = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _rcNoteCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.receiptClosingMessage,
                hintText: AppLocalizations.of(context)!.thankYou,
                prefixIcon: const Icon(Icons.message),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _warrantyPolicyCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Chính sách bảo hành',
                hintText: 'VD: Bảo hành theo phiếu. Máy còn nguyên tem BH.',
                prefixIcon: const Icon(Icons.verified_user),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                helperText: 'Dùng {warrantyPolicy} trong mẫu hóa đơn',
                helperStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _returnPolicyCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Chính sách đổi trả',
                hintText: 'VD: Đổi trả trong 7 ngày. SP còn nguyên tem mác.',
                prefixIcon: const Icon(Icons.swap_horiz),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                helperText: 'Dùng {returnPolicy} trong mẫu hóa đơn',
                helperStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _backupIpCtrl.dispose();
    _rcNoteCtrl.dispose();
    _warrantyPolicyCtrl.dispose();
    _returnPolicyCtrl.dispose();
    super.dispose();
  }
}
