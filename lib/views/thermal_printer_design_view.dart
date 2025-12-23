import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class ThermalPrinterDesignView extends StatefulWidget {
  const ThermalPrinterDesignView({super.key});
  @override
  State<ThermalPrinterDesignView> createState() => _ThermalPrinterDesignViewState();
}

class _ThermalPrinterDesignViewState extends State<ThermalPrinterDesignView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  String _selectedPaperSize = "80mm";
  double _fontSize = 14.0;
  bool _showLabelName = true;
  bool _showLabelIMEI = true;
  bool _showLabelPrice = true;
  bool _showLabelQR = true;
  bool _showLabelColor = true;
  bool _showLabelSupplier = false;
  final _labelCustomTextCtrl = TextEditingController();
  
  bool _showReceiptLogo = true;
  bool _showReceiptPhone = true;
  bool _showReceiptQR = true;
  bool _showReceiptWarranty = true;
  final _receiptNoteCtrl = TextEditingController();
  
  String _primaryPrinterIP = "";
  String _backupPrinterIP = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedPaperSize = prefs.getString('paper_size') ?? "80mm";
      _fontSize = prefs.getDouble('label_font_size') ?? 14.0;
      _showLabelName = prefs.getBool('label_show_name') ?? true;
      _showLabelIMEI = prefs.getBool('label_show_imei') ?? true;
      _showLabelPrice = prefs.getBool('label_show_price') ?? true;
      _showLabelQR = prefs.getBool('label_show_qr') ?? true;
      _showLabelColor = prefs.getBool('label_show_color') ?? true;
      _showLabelSupplier = prefs.getBool('label_show_supplier') ?? false;
      _labelCustomTextCtrl.text = prefs.getString('label_custom_text') ?? "";
      _showReceiptLogo = prefs.getBool('receipt_show_logo') ?? true;
      _showReceiptPhone = prefs.getBool('receipt_show_phone') ?? true;
      _showReceiptQR = prefs.getBool('receipt_show_qr') ?? true;
      _showReceiptWarranty = prefs.getBool('receipt_show_warranty') ?? true;
      _receiptNoteCtrl.text = prefs.getString('receipt_note') ?? "Cảm ơn Quý khách - Hẹn gặp lại!";
      _primaryPrinterIP = prefs.getString('printer_ip') ?? "";
      _backupPrinterIP = prefs.getString('backup_printer_ip') ?? "";
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('paper_size', _selectedPaperSize);
    await prefs.setDouble('label_font_size', _fontSize);
    await prefs.setBool('label_show_name', _showLabelName);
    await prefs.setBool('label_show_imei', _showLabelIMEI);
    await prefs.setBool('label_show_price', _showLabelPrice);
    await prefs.setBool('label_show_qr', _showLabelQR);
    await prefs.setBool('label_show_color', _showLabelColor);
    await prefs.setBool('label_show_supplier', _showLabelSupplier);
    await prefs.setString('label_custom_text', _labelCustomTextCtrl.text);
    await prefs.setBool('receipt_show_logo', _showReceiptLogo);
    await prefs.setBool('receipt_show_phone', _showReceiptPhone);
    await prefs.setBool('receipt_show_qr', _showReceiptQR);
    await prefs.setBool('receipt_show_warranty', _showReceiptWarranty);
    await prefs.setString('receipt_note', _receiptNoteCtrl.text);
    await prefs.setString('backup_printer_ip', _backupPrinterIP);
    NotificationService.showSnackBar("Đã lưu cài đặt!", color: Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("STUDIO THIẾT KẾ IN ẤN"),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [Tab(text: "MẪU TEM"), Tab(text: "MẪU HÓA ĐƠN"), Tab(text: "HỆ THỐNG IN")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _wrapScroll(_buildLabelTab()),
          _wrapScroll(_buildReceiptTab()),
          _wrapScroll(_buildBackupPrinterTab()),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(onPressed: _saveSettings, child: const Text("LƯU & ÁP DỤNG")),
      ),
    );
  }

  Widget _wrapScroll(Widget child) => SingleChildScrollView(child: child);

  Widget _buildLabelTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildPreviewCard("XEM TRƯỚC TEM", Column(children: [
            if (_showLabelName) const Text("IPHONE 14 PRO MAX", style: TextStyle(fontWeight: FontWeight.bold)),
            if (_showLabelPrice) const Text("GIÁ: 15.500.000 Đ", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            if (_showLabelQR) const Icon(Icons.qr_code_2, size: 60),
          ])),
          const SizedBox(height: 20),
          _configCard([
            _checkItem("Tên sản phẩm", _showLabelName, (v) => setState(() => _showLabelName = v!)),
            _checkItem("Số IMEI", _showLabelIMEI, (v) => setState(() => _showLabelIMEI = v!)),
            _checkItem("Giá bán", _showLabelPrice, (v) => setState(() => _showLabelPrice = v!)),
            _checkItem("Mã QR", _showLabelQR, (v) => setState(() => _showLabelQR = v!)),
          ]),
        ],
      ),
    );
  }

  Widget _buildReceiptTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _configCard([
            _checkItem("Hiện Logo Shop", _showReceiptLogo, (v) => setState(() => _showReceiptLogo = v!)),
            _checkItem("Hiện SĐT Shop", _showReceiptPhone, (v) => setState(() => _showReceiptPhone = v!)),
            _checkItem("Hiện QR Thanh toán", _showReceiptQR, (v) => setState(() => _showReceiptQR = v!)),
          ]),
          const SizedBox(height: 20),
          TextField(controller: _receiptNoteCtrl, decoration: const InputDecoration(labelText: "Lời chúc cuối phiếu")),
        ],
      ),
    );
  }

  Widget _buildBackupPrinterTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(onChanged: (v) => _primaryPrinterIP = v, decoration: const InputDecoration(labelText: "IP Máy in chính")),
          const SizedBox(height: 15),
          TextField(onChanged: (v) => _backupPrinterIP = v, decoration: const InputDecoration(labelText: "IP Máy in phụ")),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(String title, Widget content) => Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)), child: content);
  Widget _configCard(List<Widget> children) => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Column(children: children));
  Widget _checkItem(String l, bool v, Function(bool?) o) => CheckboxListTile(title: Text(l), value: v, onChanged: o, dense: true, contentPadding: EdgeInsets.zero);
}
