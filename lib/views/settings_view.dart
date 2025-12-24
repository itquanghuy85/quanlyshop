import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';
import '../l10n/app_localizations.dart';
import 'staff_list_view.dart';

class SettingsView extends StatefulWidget {
  final void Function(Locale)? setLocale;
  const SettingsView({super.key, this.setLocale});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  Locale _selectedLocale = const Locale('vi');
  final nameCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final footerCtrl = TextEditingController();
  String? _logoPath;
  bool _cleanupEnabled = false;
  int _cleanupDays = 30;

  final ownerNameCtrl = TextEditingController();
  final ownerPhoneCtrl = TextEditingController();
  final ownerEmailCtrl = TextEditingController();
  final ownerAddressCtrl = TextEditingController();
  final ownerBusinessLicenseCtrl = TextEditingController();
  final ownerTaxCodeCtrl = TextEditingController();

  String? _userRole;

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
    await _loadOwnerInfo();
  }

  Future<void> _loadOwnerInfo() async {
    try {
      final shopInfo = await FirestoreService.getCurrentShopInfo();
      if (shopInfo != null) {
        setState(() {
          ownerNameCtrl.text = shopInfo['ownerName'] ?? '';
          ownerPhoneCtrl.text = shopInfo['ownerPhone'] ?? '';
          ownerEmailCtrl.text = shopInfo['ownerEmail'] ?? '';
          ownerAddressCtrl.text = shopInfo['ownerAddress'] ?? '';
          ownerBusinessLicenseCtrl.text = shopInfo['ownerBusinessLicense'] ?? '';
          ownerTaxCodeCtrl.text = shopInfo['ownerTaxCode'] ?? '';
        });
      }
    } catch (_) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userInfo = await UserService.getUserInfo(currentUser.uid);
        setState(() {
          ownerNameCtrl.text = userInfo['displayName'] ?? '';
          ownerPhoneCtrl.text = userInfo['phone'] ?? '';
          ownerEmailCtrl.text = currentUser.email ?? '';
          ownerAddressCtrl.text = userInfo['address'] ?? '';
        });
      }
    }
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _userRole = await UserService.getUserRole(currentUser.uid);
      setState(() {});
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_name', nameCtrl.text.toUpperCase());
    await prefs.setString('shop_address', addressCtrl.text);
    await prefs.setString('shop_phone', phoneCtrl.text);
    await prefs.setString('invoice_footer', footerCtrl.text);
    if (_logoPath != null) await prefs.setString('shop_logo', _logoPath!);
    await _saveShopInfoToFirestore();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.shopInfoSaved)));
    }
  }

  Future<void> _saveShopInfoToFirestore() async {
    try {
      final shopData = {
        'name': nameCtrl.text.toUpperCase(),
        'address': addressCtrl.text,
        'phone': phoneCtrl.text,
        'logoPath': _logoPath,
        'ownerName': ownerNameCtrl.text.toUpperCase(),
        'ownerPhone': ownerPhoneCtrl.text,
        'ownerEmail': ownerEmailCtrl.text,
        'ownerAddress': ownerAddressCtrl.text,
        'ownerBusinessLicense': ownerBusinessLicenseCtrl.text,
        'ownerTaxCode': ownerTaxCodeCtrl.text,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await FirestoreService.updateCurrentShopInfo(shopData);
    } catch (_) {}
  }

  Future<void> _pickLogo() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f != null) setState(() => _logoPath = f.path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(l10n.settingsTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          _buildDeveloperCard(), // THÊM CARD NHÀ PHÁT TRIỂN LÊN ĐẦU
          const SizedBox(height: 25),
          
          _sectionTitle(l10n.languageLabel.toUpperCase()),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: const Icon(Icons.language, color: Colors.blueAccent),
              title: Text(l10n.languageLabel),
              trailing: DropdownButton<Locale>(
                value: _selectedLocale, underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: const Locale('vi'), child: Text(l10n.vietnamese)),
                  DropdownMenuItem(value: const Locale('en'), child: Text(l10n.english)),
                ],
                onChanged: (locale) {
                  if (locale != null) {
                    setState(() => _selectedLocale = locale);
                    widget.setLocale?.call(locale);
                  }
                },
              ),
            ),
          ),
          
          const SizedBox(height: 25),
          _sectionTitle(l10n.brandInfoSection.toUpperCase()),
          const SizedBox(height: 15),
          Center(
            child: GestureDetector(
              onTap: _pickLogo,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 55, backgroundColor: Colors.white,
                    backgroundImage: _logoPath != null && File(_logoPath!).existsSync() ? FileImage(File(_logoPath!)) : null,
                    child: _logoPath == null ? const Icon(Icons.store, size: 40, color: Colors.grey) : null,
                  ),
                  Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.white, size: 16)))
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _input(nameCtrl, l10n.shopNameLabel, Icons.storefront),
          _input(phoneCtrl, l10n.shopPhoneLabel, Icons.phone, type: TextInputType.phone),
          _input(addressCtrl, l10n.shopAddressLabel, Icons.location_on),
          
          const SizedBox(height: 25),
          _sectionTitle("THÔNG TIN CHỦ CỬA HÀNG"),
          const SizedBox(height: 10),
          _input(ownerNameCtrl, 'Tên chủ cửa hàng', Icons.person_outline),
          _input(ownerPhoneCtrl, 'Số điện thoại cá nhân', Icons.phone_iphone, type: TextInputType.phone),
          
          const SizedBox(height: 25),
          _sectionTitle(l10n.invoiceConfigSection.toUpperCase()),
          const SizedBox(height: 10),
          _input(footerCtrl, l10n.invoiceFooterLabel, Icons.auto_awesome),
          
          const SizedBox(height: 20),
          _menuTile(l10n.joinShopCode, Icons.group_add, Colors.orange, _joinShopDialog),
          _menuTile(l10n.cleanupManagement, Icons.cleaning_services_rounded, Colors.purple, _openCleanupDialog),
          if (_userRole == 'owner')
            _menuTile('Quản lý nhân viên', Icons.people_alt, Colors.indigo, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffListView()));
            }),

          const SizedBox(height: 40),
          SizedBox(
            height: 60,
            child: ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('LƯU VÀ CẬP NHẬT HỆ THỐNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 4),
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildDeveloperCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2962FF), Color(0xFF00B0FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Positioned(right: -20, top: -20, child: Icon(Icons.code, size: 100, color: Colors.white.withOpacity(0.1))),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text("NHÀ PHÁT TRIỂN CHÍNH", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text("QUANG HUY", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                const Text("Expert Flutter Developer & UI/UX Designer", style: TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _devContactButton(Icons.phone, "GỌI NGAY", () => _launchURL("tel:0964095979")),
                    const SizedBox(width: 12),
                    _devContactButton(Icons.chat, "ZALO", () => _launchURL("https://zalo.me/0964095979")),
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Text("Tư vấn phần mềm chuyên nghiệp cho Shop & Store", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _devContactButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF2962FF)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Color(0xFF2962FF), fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _aboutRow(IconData i, String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Icon(i, size: 18, color: Colors.blueAccent), const SizedBox(width: 10), Text(t, style: const TextStyle(fontSize: 13))]));

  Widget _sectionTitle(String title) => Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)));
  
  Widget _input(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: TextField(controller: ctrl, keyboardType: type, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20, color: Colors.blueGrey), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.blueAccent, width: 1)))));
  }

  Widget _menuTile(String title, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(tileColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey), onTap: onTap),
    );
  }

  void _joinShopDialog() {
    final codeCtrl = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(title: Text(AppLocalizations.of(context)!.enterInviteCode), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: codeCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context)!.inviteCode8Chars), textCapitalization: TextCapitalization.characters), const SizedBox(height: 10), ElevatedButton.icon(onPressed: () async { final result = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const _QRScanView())); if (result != null) codeCtrl.text = result; }, icon: const Icon(Icons.qr_code_scanner), label: Text(AppLocalizations.of(context)!.scanQR))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.cancel)), ElevatedButton(onPressed: () async { final code = codeCtrl.text.trim().toUpperCase(); if (code.length != 8) return; final currentUser = FirebaseAuth.instance.currentUser; if (currentUser == null) return; final success = await UserService.useInviteCode(code, currentUser.uid); if (success) Navigator.pop(context); }, child: Text(AppLocalizations.of(context)!.join))]));
  }

  Future<void> _loadCleanupConfig() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!(perms['allowViewSettings'] ?? false)) return;
    final doc = await FirebaseFirestore.instance.doc('settings/cleanup').get();
    if (doc.exists) setState(() { _cleanupEnabled = doc.data()?['enabled'] ?? false; _cleanupDays = doc.data()?['repairRetentionDays'] ?? 30; });
  }

  Future<void> _saveCleanupConfig(bool enabled, int days) async {
    await FirebaseFirestore.instance.doc('settings/cleanup').set({'enabled': enabled, 'repairRetentionDays': days}, SetOptions(merge: true));
    setState(() { _cleanupEnabled = enabled; _cleanupDays = days; });
  }

  void _openCleanupDialog() async {
    final daysCtrl = TextEditingController(text: _cleanupDays.toString());
    bool tempEnabled = _cleanupEnabled;
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Dọn dẹp dữ liệu"), content: Column(mainAxisSize: MainAxisSize.min, children: [Row(children: [const Text("Bật tự động xóa"), const Spacer(), Switch(value: tempEnabled, onChanged: (v) => setState(() => tempEnabled = v))]), TextField(controller: daysCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Xóa sau bao nhiêu ngày"))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")), ElevatedButton(onPressed: () async { await _saveCleanupConfig(tempEnabled, int.tryParse(daysCtrl.text) ?? 30); Navigator.pop(ctx); }, child: const Text("Lưu"))]));
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
    return Scaffold(appBar: AppBar(title: const Text("Quét mã")), body: MobileScanner(controller: controller, onDetect: (capture) { final List<Barcode> barcodes = capture.barcodes; for (final barcode in barcodes) { if (barcode.rawValue != null) { Navigator.pop(context, barcode.rawValue); break; } } }));
  }
  @override
  void dispose() { controller.dispose(); super.dispose(); }
}
