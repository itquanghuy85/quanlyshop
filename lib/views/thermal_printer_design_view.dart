import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../services/bluetooth_printer_service.dart';

class ThermalPrinterDesignView extends StatefulWidget {
  const ThermalPrinterDesignView({super.key});

  @override
  State<ThermalPrinterDesignView> createState() => _ThermalPrinterDesignViewState();
}

class _ThermalPrinterDesignViewState extends State<ThermalPrinterDesignView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Cài đặt chung
  BluetoothPrinterConfig? _selectedPrinter;
  bool _isTesting = false;
  bool _isScanning = false;
  List<BluetoothInfo> _availablePrinters = [];

  // Cài đặt mẫu tem
  String _selectedSize = '3x4'; // 3x4, 4x6, 2x4
  bool _showColor = true;
  bool _showIMEI = true;
  bool _showCondition = true;
  bool _showPrice = true;
  bool _showAccessories = true;
  String _fontSize = 'medium'; // small, medium, large

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPrinter = await BluetoothPrinterService.getSavedPrinter();
    setState(() {
      _selectedPrinter = savedPrinter;
      _selectedSize = prefs.getString('thermal_label_size') ?? '3x4';
      _showColor = prefs.getBool('thermal_show_color') ?? true;
      _showIMEI = prefs.getBool('thermal_show_imei') ?? true;
      _showCondition = prefs.getBool('thermal_show_condition') ?? true;
      _showPrice = prefs.getBool('thermal_show_price') ?? true;
      _showAccessories = prefs.getBool('thermal_show_accessories') ?? true;
      _fontSize = prefs.getString('thermal_font_size') ?? 'medium';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('thermal_label_size', _selectedSize);
    await prefs.setBool('thermal_show_color', _showColor);
    await prefs.setBool('thermal_show_imei', _showIMEI);
    await prefs.setBool('thermal_show_condition', _showCondition);
    await prefs.setBool('thermal_show_price', _showPrice);
    await prefs.setBool('thermal_show_accessories', _showAccessories);
    await prefs.setString('thermal_font_size', _fontSize);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã lưu cài đặt máy in nhiệt!"))
      );
    }
  }

  Future<void> _scanBluetoothPrinters() async {
    setState(() => _isScanning = true);

    try {
      // Yêu cầu quyền Bluetooth
      final permissionsGranted = await BluetoothPrinterService.requestBluetoothPermissions();
      if (!permissionsGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Không thể cấp quyền Bluetooth! Vui lòng cấp quyền trong cài đặt thiết bị."))
          );
        }
        return;
      }

      // Kiểm tra Bluetooth có bật
      final isEnabled = await BluetoothPrinterService.isBluetoothEnabled();
      if (!isEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Vui lòng bật Bluetooth trước khi scan!"))
          );
        }
        return;
      }

      // Scan máy in Bluetooth
      final printers = await BluetoothPrinterService.scanBluetoothPrinters();
      setState(() {
        _availablePrinters = printers;
      });

      if (printers.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Không tìm thấy máy in Bluetooth nào! Kiểm tra máy in có bật và trong phạm vi không."))
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Tìm thấy ${printers.length} máy in Bluetooth"))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi scan máy in: $e"))
        );
      }
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _selectPrinter(BluetoothInfo printer) async {
    final config = BluetoothPrinterConfig(name: printer.name, macAddress: printer.macAdress);
    await BluetoothPrinterService.savePrinter(config);
    setState(() {
      _selectedPrinter = config;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã chọn máy in: ${printer.name}"))
      );
    }
  }

  Future<void> _testThermalPrint() async {
    if (_selectedPrinter == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vui lòng chọn máy in Bluetooth trước!"))
        );
      }
      return;
    }

    setState(() => _isTesting = true);

    try {
      // Kết nối đến máy in
      final connected = await BluetoothPrinterService.connect(_selectedPrinter!.macAddress);
      if (!connected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Không thể kết nối đến máy in Bluetooth!"))
          );
        }
        return;
      }

      // Tạo dữ liệu test
      const PaperSize paper = PaperSize.mm58;
      final profile = await CapabilityProfile.load();
      final generator = Generator(paper, profile);

      List<int> bytes = [];
      bytes += generator.text('TEST KET NOI BLUETOOTH', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.feed(2);
      bytes += generator.cut();

      // In test
      final success = await BluetoothPrinterService.printBytes(bytes);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Đã in mẫu tem test thành công!"))
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Lỗi in mẫu tem test!"))
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi kết nối máy in: $e"))
        );
      }
    } finally {
      setState(() => _isTesting = false);
    }
  }

  Widget _buildPrinterSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
            ),
            child: Column(
              children: [
                const Icon(Icons.bluetooth, size: 60, color: Colors.blueAccent),
                const SizedBox(height: 15),
                const Text("MÁY IN BLUETOOTH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Text("In tem thông tin máy, phụ kiện", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Text("MÁY IN BLUETOOTH", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 10),

          // Hiển thị máy in đã chọn
          if (_selectedPrinter != null) ...[
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bluetooth_connected, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedPrinter!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(_selectedPrinter!.macAddress, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _selectedPrinter = null),
                    icon: const Icon(Icons.clear, color: Colors.red),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
          ],

          // Nút scan máy in
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isScanning ? null : _scanBluetoothPrinters,
              icon: _isScanning
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.bluetooth_searching),
              label: Text(_isScanning ? "ĐANG QUÉT..." : "QUÉT MÁY IN BLUETOOTH", style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
            ),
          ),

          // Danh sách máy in tìm được
          if (_availablePrinters.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text("MÁY IN TÌM THẤY", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _availablePrinters.length,
                itemBuilder: (context, index) {
                  final printer = _availablePrinters[index];
                  return ListTile(
                    leading: const Icon(Icons.print, color: Colors.blue),
                    title: Text(printer.name),
                    subtitle: Text(printer.macAdress),
                    onTap: () => _selectPrinter(printer),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _isTesting ? null : _testThermalPrint,
              icon: _isTesting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.print_rounded),
              label: Text(_isTesting ? "ĐANG IN THỬ..." : "IN MẪU TEM TEST", style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("THIẾT KẾ MẪU TEM", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // Chọn size giấy
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("KÍCH THƯỚC GIẤY", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _buildSizeOption('2x4', '2x4 cm'),
                    const SizedBox(width: 10),
                    _buildSizeOption('3x4', '3x4 cm'),
                    const SizedBox(width: 10),
                    _buildSizeOption('4x6', '4x6 cm'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Cài đặt hiển thị thông tin
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("THÔNG TIN HIỂN THỊ", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                _buildInfoToggle('Màu sắc máy', _showColor, (v) => setState(() => _showColor = v)),
                _buildInfoToggle('Số IMEI', _showIMEI, (v) => setState(() => _showIMEI = v)),
                _buildInfoToggle('Tình trạng máy', _showCondition, (v) => setState(() => _showCondition = v)),
                _buildInfoToggle('Giá bán', _showPrice, (v) => setState(() => _showPrice = v)),
                _buildInfoToggle('Có phụ kiện hay không', _showAccessories, (v) => setState(() => _showAccessories = v)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Cài đặt font size
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("CỠ CHỮ", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _buildFontSizeOption('small', 'Nhỏ'),
                    const SizedBox(width: 10),
                    _buildFontSizeOption('medium', 'Trung bình'),
                    const SizedBox(width: 10),
                    _buildFontSizeOption('large', 'Lớn'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Xem trước mẫu tem
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("XEM TRƯỚC MẪU TEM", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('iPhone 14 Pro Max', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_showColor) Text('Màu: Đen', style: _getFontStyle()),
                      if (_showIMEI) Text('IMEI: 123456789012345', style: _getFontStyle()),
                      if (_showCondition) Text('Tình trạng: 99%', style: _getFontStyle()),
                      if (_showPrice) Text('Giá: 5.000.000 VND', style: _getFontStyle()),
                      if (_showAccessories) Text('Phụ kiện: Có', style: _getFontStyle()),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save_rounded),
              label: const Text("LƯU CÀI ĐẶT", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeOption(String size, String label) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedSize = size),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: _selectedSize == size ? Colors.redAccent : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _selectedSize == size ? Colors.redAccent : Colors.grey.shade300
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _selectedSize == size ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFontSizeOption(String size, String label) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _fontSize = size),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: _fontSize == size ? Colors.blueAccent : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _fontSize == size ? Colors.blueAccent : Colors.grey.shade300
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _fontSize == size ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoToggle(String label, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.redAccent,
        ),
      ],
    );
  }

  TextStyle _getFontStyle() {
    double fontSize;
    switch (_fontSize) {
      case 'small':
        fontSize = 12;
        break;
      case 'large':
        fontSize = 16;
        break;
      default:
        fontSize = 14;
    }
    return TextStyle(fontSize: fontSize, fontFamily: 'monospace');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("MÁY IN NHIỆT & TEM", style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "MÁY IN", icon: Icon(Icons.thermostat_rounded)),
            Tab(text: "THIẾT KẾ TEM", icon: Icon(Icons.design_services_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPrinterSettingsTab(),
          _buildDesignSettingsTab(),
        ],
      ),
    );
  }
}