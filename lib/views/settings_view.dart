import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import 'printer_setting_view.dart';
import 'invoice_template_view.dart';

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
  // Cleanup config
  bool _cleanupEnabled = false;
  int _cleanupDays = 30;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadCleanupConfig();
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
                backgroundImage: _logoPath != null && File(_logoPath!).existsSync() ? FileImage(File(_logoPath!)) : null,
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
          _menuTile("Tạo mẫu hóa đơn", Icons.receipt_long, Colors.green, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceTemplateView()));
          }),
          _menuTile("Nhập mã mời tham gia shop", Icons.group_add, Colors.orange, _joinShopDialog),
          _menuTile("Quản lý cleanup: Xóa lịch sửa cũ (tùy chọn)", Icons.cleaning_services_rounded, Colors.purple, _openCleanupDialog),

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

  void _joinShopDialog() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập mã mời'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: 'Mã mời (8 ký tự)'),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (_) => const _QRScanView()),
                );
                if (result != null) {
                  codeCtrl.text = result;
                }
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Quét QR'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeCtrl.text.trim().toUpperCase();
              if (code.length != 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mã phải 8 ký tự')),
                );
                return;
              }
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser == null) return;
              final success = await UserService.useInviteCode(code, currentUser.uid);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã tham gia shop thành công!')),
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mã không hợp lệ hoặc đã hết hạn')),
                );
              }
            },
            child: const Text('THAM GIA'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCleanupConfig() async {
    try {
      final perms = await UserService.getCurrentUserPermissions();
      if (!(perms['allowViewSettings'] ?? false)) {
        // không có quyền
        return;
      }
      final doc = await FirebaseFirestore.instance.doc('settings/cleanup').get();
      final data = doc.exists ? (doc.data() ?? {}) : {};
      setState(() {
        _cleanupEnabled = (data['enabled'] as bool?) ?? false;
        _cleanupDays = (data['repairRetentionDays'] as int?) ?? 30;
      });
    } catch (e) {
      // Handle error silently or log if needed
    }
  }

  Future<void> _saveCleanupConfig(bool enabled, int days) async {
    await FirebaseFirestore.instance.doc('settings/cleanup').set({
      'enabled': enabled,
      'repairRetentionDays': days,
    }, SetOptions(merge: true));
    setState(() {
      _cleanupEnabled = enabled;
      _cleanupDays = days;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu cấu hình cleanup')));
  }

  void _openCleanupDialog() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!(perms['allowViewSettings'] ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tài khoản không có quyền cấu hình')));
      return;
    }

    final daysCtrl = TextEditingController(text: _cleanupDays.toString());
    bool tempEnabled = _cleanupEnabled;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cấu hình Cleanup (opt-in)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Bật cleanup'),
                const Spacer(),
                Switch(
                  value: tempEnabled,
                  onChanged: (v) => setState(() => tempEnabled = v),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: daysCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Số ngày (xóa sau N ngày)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('HỦY')),
          ElevatedButton(
            onPressed: () async {
              final d = int.tryParse(daysCtrl.text) ?? 30;
              await _saveCleanupConfig(tempEnabled, d);
              Navigator.pop(ctx);
            },
            child: const Text('LƯU'),
          ),
        ],
      ),
    );
  }
}

class _QRScanView extends StatefulWidget {
  const _QRScanView();

  @override
  State<_QRScanView> createState() => _QRScanViewState();
}

class _QRScanViewState extends State<_QRScanView> {
  final MobileScannerController controller = MobileScannerController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét mã QR')),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              Navigator.pop(context, barcode.rawValue);
              break;
            }
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
