import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../l10n/app_localizations.dart';
import 'invoice_template_view.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.shopInfoSaved)));
    }
  }

  Future<void> _pickLogo() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f != null) setState(() => _logoPath = f.path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(title: Text(l10n.settingsTitle, style: const TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Language switcher
          Row(
            children: [
              const Icon(Icons.language, color: Colors.blueAccent),
              const SizedBox(width: 10),
              Text(l10n.languageLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              DropdownButton<Locale>(
                value: _selectedLocale,
                items: [
                DropdownMenuItem(value: const Locale('vi'), child: Text(AppLocalizations.of(context)!.vietnamese)),
                DropdownMenuItem(value: const Locale('en'), child: Text(AppLocalizations.of(context)!.english)),
                ],
                onChanged: (locale) {
                  if (locale != null) {
                    setState(() => _selectedLocale = locale);
                    widget.setLocale?.call(locale);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle(l10n.brandInfoSection),
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
          _input(nameCtrl, l10n.shopNameLabel, Icons.storefront),
          _input(phoneCtrl, l10n.shopPhoneLabel, Icons.phone, type: TextInputType.phone),
          _input(addressCtrl, l10n.shopAddressLabel, Icons.location_on),
          
          const SizedBox(height: 30),
          _sectionTitle(l10n.invoiceConfigSection),
          const SizedBox(height: 10),
          _input(footerCtrl, l10n.invoiceFooterLabel, Icons.chat_bubble_outline),
          
          const SizedBox(height: 20),
          _menuTile(l10n.createInvoiceTemplate, Icons.receipt_long, Colors.green, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceTemplateView()));
          }),
          _menuTile(l10n.joinShopCode, Icons.group_add, Colors.orange, _joinShopDialog),
          _menuTile(l10n.cleanupManagement, Icons.cleaning_services_rounded, Colors.purple, _openCleanupDialog),

          const SizedBox(height: 30),
          _sectionTitle(l10n.aboutSection),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05 * 255), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                // Logo và tên app
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.3 * 255), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.phone_android, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.appName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent.shade700)),
                          Text(l10n.appDescription, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Thông tin phiên bản
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1 * 255),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blueAccent.shade700, size: 20),
                      const SizedBox(width: 10),
                      Text("${l10n.version}: ${l10n.versionNumber}", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.blueAccent.shade700)),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                // Thông tin liên hệ
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1 * 255),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.contact_support, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 10),
                          Text(l10n.contactSupport, style: TextStyle(fontWeight: FontWeight.w500, color: Colors.green.shade700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("👨‍💻 ${l10n.developerName}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      Text(l10n.contactPhone, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      Text(l10n.technicalSupport, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                // Thông tin developer
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1 * 255),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.code, color: Colors.purple.shade700, size: 20),
                          const SizedBox(width: 10),
                          Text(l10n.developer, style: TextStyle(fontWeight: FontWeight.w500, color: Colors.purple.shade700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("👨‍💻 ${l10n.developerName}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      Text("🚀 ${l10n.developerRole}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      Text(l10n.contactPhone, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      Text("💡 ${l10n.businessSolutions}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
          SizedBox(
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save_rounded),
              label: Text(l10n.saveAllSettings, style: const TextStyle(fontWeight: FontWeight.bold)),
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
        title: Text(AppLocalizations.of(context)!.enterInviteCode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.inviteCode8Chars),
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
              label: Text(AppLocalizations.of(context)!.scanQR),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final l10n = AppLocalizations.of(context)!;
              final code = codeCtrl.text.trim().toUpperCase();
              if (code.length != 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.codeMustBe8Chars)),
                );
                return;
              }
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser == null) return;
              final success = await UserService.useInviteCode(code, currentUser.uid);
              if (!mounted) return;
              if (success) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.joinedShopSuccessfully)),
                );
                Navigator.pop(context);
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.invalidOrExpiredCode)),
                );
              }
            },
            child: Text(AppLocalizations.of(context)!.join),
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
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _cleanupEnabled = enabled;
      _cleanupDays = days;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.cleanupConfigSaved)));
  }

  void _openCleanupDialog() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (!(perms['allowViewSettings'] ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.noPermissionToConfigure)));
      return;
    }

    final daysCtrl = TextEditingController(text: _cleanupDays.toString());
    bool tempEnabled = _cleanupEnabled;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cleanupConfigOptIn),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(l10n.enableCleanup),
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
              decoration: InputDecoration(labelText: l10n.daysToDeleteAfter),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              final d = int.tryParse(daysCtrl.text) ?? 30;
              await _saveCleanupConfig(tempEnabled, d);
              Navigator.pop(ctx);
            },
            child: Text(l10n.save),
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
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.scanQRCode)),
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
