import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'printer_setting_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final nameCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final footerCtrl = TextEditingController();
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nameCtrl.text = prefs.getString('shop_name') ?? "";
      addressCtrl.text = prefs.getString('shop_address') ?? "";
      phoneCtrl.text = prefs.getString('shop_phone') ?? "";
      footerCtrl.text = prefs.getString('invoice_footer') ?? "Cảm ơn quý khách đã tin tưởng!";
      _logoPath = prefs.getString('shop_logo');
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_name', nameCtrl.text.toUpperCase());
    await prefs.setString('shop_address', addressCtrl.text);
    await prefs.setString('shop_phone', phoneCtrl.text);
    await prefs.setString('invoice_footer', footerCtrl.text);
    if (_logoPath != null) await prefs.setString('shop_logo', _logoPath!);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ĐÃ LƯU THÔNG TIN CỬA HÀNG!")));
    }
  }

  Future<void> _pickLogo() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f != null) setState(() => _logoPath = f.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(title: const Text("CÀI ĐẶT HỆ THỐNG", style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle("THÔNG TIN THƯƠNG HIỆU"),
          const SizedBox(height: 15),
          Center(
            child: GestureDetector(
              onTap: _pickLogo,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                backgroundImage: _logoPath != null ? FileImage(File(_logoPath!)) : null,
                child: _logoPath == null ? const Icon(Icons.add_a_photo, size: 30, color: Colors.grey) : null,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _input(nameCtrl, "Tên cửa hàng (IN HOA)", Icons.storefront),
          _input(phoneCtrl, "Số điện thoại liên hệ", Icons.phone, type: TextInputType.phone),
          _input(addressCtrl, "Địa chỉ shop", Icons.location_on),
          
          const SizedBox(height: 30),
          _sectionTitle("CẤU HÌNH HÓA ĐƠN"),
          const SizedBox(height: 10),
          _input(footerCtrl, "Lời chào chân trang", Icons.chat_bubble_outline),
          
          const SizedBox(height: 20),
          _menuTile("Kết nối máy in nhiệt Bluetooth", Icons.print_rounded, Colors.blueAccent, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingView()));
          }),

          const SizedBox(height: 40),
          SizedBox(
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save_rounded),
              label: const Text("LƯU TOÀN BỘ CÀI ĐẶT", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey));
  
  Widget _input(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _menuTile(String title, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
