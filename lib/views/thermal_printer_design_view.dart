import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../services/notification_service.dart';
import '../services/bluetooth_printer_service.dart';

class ThermalPrinterDesignView extends StatefulWidget {
  const ThermalPrinterDesignView({super.key});
  @override
  State<ThermalPrinterDesignView> createState() => _ThermalPrinterDesignViewState();
}

class _ThermalPrinterDesignViewState extends State<ThermalPrinterDesignView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final db = SharedPreferences.getInstance();

  // 1. KẾT NỐI
  final _ipCtrl = TextEditingController();
  final _backupIpCtrl = TextEditingController();
  String _logoPath = "";
  BluetoothPrinterConfig? _selectedBT;
  bool _isScanning = false;
  List<dynamic> _foundBT = [];

  // 2. THIẾT KẾ TEM
  String _paperSize = "80mm";
  double _labelFontSize = 14.0;
  bool _showLabelName = true;
  bool _showLabelIMEI = true;
  bool _showLabelPrice = true;
  bool _showLabelQR = true;
  final _labelCustomCtrl = TextEditingController();

  // 3. THIẾT KẾ HÓA ĐƠN
  bool _showRcLogo = true;
  bool _showRcPhone = true;
  bool _showRcQR = true;
  final _rcNoteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ipCtrl.text = prefs.getString('printer_ip') ?? "";
      _backupIpCtrl.text = prefs.getString('backup_printer_ip') ?? "";
      _logoPath = prefs.getString('shop_logo_path') ?? "";
      _paperSize = prefs.getString('paper_size') ?? "80mm";
      _labelFontSize = prefs.getDouble('label_font_size') ?? 14.0;
      _showLabelName = prefs.getBool('label_show_name') ?? true;
      _showLabelIMEI = prefs.getBool('label_show_imei') ?? true;
      _showLabelPrice = prefs.getBool('label_show_price') ?? true;
      _showLabelQR = prefs.getBool('label_show_qr') ?? true;
      _labelCustomCtrl.text = prefs.getString('label_custom_text') ?? "";
      _showRcLogo = prefs.getBool('receipt_show_logo') ?? true;
      _showRcPhone = prefs.getBool('receipt_show_phone') ?? true;
      _showRcQR = prefs.getBool('receipt_show_qr') ?? true;
      _rcNoteCtrl.text = prefs.getString('receipt_note') ?? "Cảm ơn quý khách!";
    });
    final savedBT = await BluetoothPrinterService.getSavedPrinter();
    setState(() => _selectedBT = savedBT);
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_ip', _ipCtrl.text.trim());
    await prefs.setString('backup_printer_ip', _backupIpCtrl.text.trim());
    await prefs.setString('paper_size', _paperSize);
    await prefs.setDouble('label_font_size', _labelFontSize);
    await prefs.setBool('label_show_name', _showLabelName);
    await prefs.setBool('label_show_imei', _showLabelIMEI);
    await prefs.setBool('label_show_price', _showLabelPrice);
    await prefs.setBool('label_show_qr', _showLabelQR);
    await prefs.setString('label_custom_text', _labelCustomCtrl.text);
    await prefs.setBool('receipt_show_logo', _showRcLogo);
    await prefs.setBool('receipt_show_phone', _showRcPhone);
    await prefs.setBool('receipt_show_qr', _showRcQR);
    await prefs.setString('receipt_note', _rcNoteCtrl.text);
    NotificationService.showSnackBar("ĐÃ LƯU TOÀN BỘ CẤU HÌNH IN", color: Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("SIÊU TRUNG TÂM IN ẤN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF2962FF),
          tabs: const [Tab(text: "KẾT NỐI"), Tab(text: "MẪU TEM"), Tab(text: "HÓA ĐƠN")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildConnectTab(), _buildLabelTab(), _buildReceiptTab()],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: ElevatedButton.icon(
          onPressed: _saveAll,
          icon: const Icon(Icons.save_rounded, color: Colors.white),
          label: const Text("LƯU & ÁP DỤNG HỆ THỐNG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF), minimumSize: const Size(double.infinity, 55)),
        ),
      ),
    );
  }

  Widget _buildConnectTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _sectionCard("MÁY IN CHÍNH (WIFI/LAN)", [
            TextField(controller: _ipCtrl, decoration: const InputDecoration(hintText: "192.168.1.XXX", prefixIcon: Icon(Icons.lan))),
          ], color: Colors.blue),
          const SizedBox(height: 15),
          _sectionCard("MÁY IN DỰ PHÒNG (WIFI/LAN)", [
            TextField(controller: _backupIpCtrl, decoration: const InputDecoration(hintText: "192.168.1.YYY", prefixIcon: Icon(Icons.backup))),
          ], color: Colors.orange),
          const SizedBox(height: 15),
          _sectionCard("LOGO CỬA HÀNG", [
            Row(children: [
              Container(width: 50, height: 50, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: _logoPath.isEmpty ? const Icon(Icons.image) : Image.file(File(_logoPath), fit: BoxFit.cover)),
              const SizedBox(width: 15),
              Expanded(child: const Text("In trên đầu hóa đơn", style: TextStyle(fontSize: 12, color: Colors.grey))),
              TextButton(onPressed: _pickLogo, child: const Text("CHỌN ẢNH"))
            ])
          ]),
          const SizedBox(height: 15),
          _sectionCard("MÁY IN BLUETOOTH", [
            if (_selectedBT != null) ListTile(title: Text(_selectedBT!.name), subtitle: Text(_selectedBT!.macAddress), trailing: const Icon(Icons.check_circle, color: Colors.green), contentPadding: EdgeInsets.zero),
            ElevatedButton.icon(
              onPressed: _scanBT,
              icon: _isScanning ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.bluetooth_searching),
              label: Text(_isScanning ? "ĐANG TÌM..." : "QUÉT MÁY IN BLUETOOTH"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
            ),
          ], color: Colors.blueGrey),
        ],
      ),
    );
  }

  Widget _buildLabelTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _labelPreview(),
          const SizedBox(height: 20),
          _sectionCard("CẤU HÌNH TEM", [
            _checkItem("Tên sản phẩm", _showLabelName, (v) => setState(() => _showLabelName = v!)),
            _checkItem("Số IMEI", _showLabelIMEI, (v) => setState(() => _showLabelIMEI = v!)),
            _checkItem("Giá bán", _showLabelPrice, (v) => setState(() => _showLabelPrice = v!)),
            _checkItem("Mã QR", _showLabelQR, (v) => setState(() => _showLabelQR = v!)),
            TextField(controller: _labelCustomCtrl, onChanged: (v)=>setState(() {}), decoration: const InputDecoration(labelText: "Nội dung tùy biến cuối tem")),
          ]),
        ],
      ),
    );
  }

  Widget _buildReceiptTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _receiptPreview(),
          const SizedBox(height: 20),
          _sectionCard("CẤU HÌNH HÓA ĐƠN", [
            _checkItem("Hiện Logo Shop", _showRcLogo, (v) => setState(() => _showRcLogo = v!)),
            _checkItem("Hiện SĐT & Địa chỉ", _showRcPhone, (v) => setState(() => _showRcPhone = v!)),
            _checkItem("Hiện QR Tra cứu", _showRcQR, (v) => setState(() => _showRcQR = v!)),
            TextField(controller: _rcNoteCtrl, onChanged: (v)=>setState(() {}), decoration: const InputDecoration(labelText: "Lời chúc cuối hóa đơn")),
          ]),
        ],
      ),
    );
  }

  Widget _labelPreview() {
    return Container(
      width: 200, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(children: [
        if (_showLabelName) const Text("IPHONE 14 PM", style: TextStyle(fontWeight: FontWeight.bold)),
        if (_showLabelIMEI) const Text("358901234567890", style: TextStyle(fontSize: 10)),
        if (_showLabelPrice) const Text("15.500.000 D", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        if (_showLabelQR) const Icon(Icons.qr_code_2, size: 50),
        if (_labelCustomCtrl.text.isNotEmpty) Text(_labelCustomCtrl.text.toUpperCase(), style: const TextStyle(fontSize: 8, color: Colors.blue))
      ]),
    );
  }

  Widget _receiptPreview() {
    return Container(
      width: 240, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300)),
      child: Column(children: [
        if (_showRcLogo) const Icon(Icons.store, color: Colors.blue),
        const Text("SHOP NEW", style: TextStyle(fontWeight: FontWeight.bold)),
        if (_showRcPhone) const Text("0123.456.789", style: TextStyle(fontSize: 9)),
        const Divider(),
        const Text("HOA DON BAN HANG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("iPhone 14 PM", style: TextStyle(fontSize: 8)), Text("15.500.000", style: TextStyle(fontSize: 8))]),
        if (_showRcQR) const Icon(Icons.qr_code_scanner, size: 40),
        Text(_rcNoteCtrl.text, style: const TextStyle(fontSize: 8, fontStyle: FontStyle.italic))
      ]),
    );
  }

  Widget _sectionCard(String title, List<Widget> children, {Color color = Colors.blueGrey}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 11)),
        const SizedBox(height: 12),
        ...children
      ]),
    );
  }

  Widget _checkItem(String l, bool v, Function(bool?) o) => CheckboxListTile(title: Text(l, style: const TextStyle(fontSize: 13)), value: v, onChanged: o, dense: true, contentPadding: EdgeInsets.zero);

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shop_logo_path', picked.path);
      setState(() => _logoPath = picked.path);
    }
  }

  Future<void> _scanBT() async {
    setState(() => _isScanning = true);
    final list = await BluetoothPrinterService.getPairedPrinters();
    setState(() { _foundBT = list; _isScanning = false; });
    if (list.isNotEmpty) {
      showModalBottomSheet(context: context, builder: (ctx) => ListView.builder(itemCount: list.length, itemBuilder: (c, i) => ListTile(title: Text(list[i].name), subtitle: Text(list[i].macAdress), onTap: () async {
        final config = BluetoothPrinterConfig(name: list[i].name, macAddress: list[i].macAdress);
        await BluetoothPrinterService.savePrinter(config);
        setState(() => _selectedBT = config);
        Navigator.pop(ctx);
      })));
    }
  }
}
