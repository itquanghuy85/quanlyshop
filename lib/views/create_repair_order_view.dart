import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/app_localizations.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import 'customer_history_view.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';
import '../services/unified_printer_service.dart';

class CreateRepairOrderView extends StatefulWidget {
  final String role;
  const CreateRepairOrderView({super.key, this.role = 'user'});

  @override
  State<CreateRepairOrderView> createState() => _CreateRepairOrderViewState();
}

class _CreateRepairOrderViewState extends State<CreateRepairOrderView> {
  final db = DBHelper();
  final List<File> _images = [];
  bool _saving = false;

  final phoneCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final modelCtrl = TextEditingController();
  final issueCtrl = TextEditingController();
  final appearanceCtrl = TextEditingController();
  final accCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  final phoneF = FocusNode();
  final nameF = FocusNode();
  final modelF = FocusNode();
  final issueF = FocusNode();
  final priceF = FocusNode();
  final passF = FocusNode();
  final appearanceF = FocusNode();
  final accF = FocusNode();

  String _paymentMethod = "TIỀN MẶT";
  List<Map<String, dynamic>> _recentDevices = [];

  final List<String> brands = ["IPHONE", "SAMSUNG", "OPPO", "REDMI", "VIVO"];
  final List<String> commonIssues = ["THAY PIN", "ÉP KÍNH", "THAY MÀN", "MẤT NGUỒN", "LOA/MIC", "SẠC", "PHẦN MỀM"];

  @override
  void initState() {
    super.initState();
    phoneCtrl.addListener(() {
      if (phoneCtrl.text.length == 10) _smartFill();
    });
  }

  @override
  void dispose() {
    phoneCtrl.dispose(); nameCtrl.dispose(); addressCtrl.dispose();
    modelCtrl.dispose(); issueCtrl.dispose(); appearanceCtrl.dispose();
    accCtrl.dispose(); passCtrl.dispose(); priceCtrl.dispose();
    phoneF.dispose(); nameF.dispose(); modelF.dispose(); issueF.dispose();
    priceF.dispose(); passF.dispose(); appearanceF.dispose(); accF.dispose();
    super.dispose();
  }

  void _smartFill() async {
    final res = await db.getUniqueCustomersAll();
    final find = res.where((c) => c['phone'] == phoneCtrl.text).toList();
    if (find.isNotEmpty) {
      setState(() {
        nameCtrl.text = find.first['customerName'] ?? "";
        addressCtrl.text = (find.first['address'] ?? "").toString();
      });
      final repairs = await db.getAllRepairs();
      final devices = repairs.where((r) => r.phone == phoneCtrl.text).map((r) => {'model': r.model}).toSet().toList();
      setState(() => _recentDevices = devices.take(3).toList());
    }
  }

  // LOGIC XỬ LÝ TIỀN TỆ QUY ƯỚC "K"
  int _parseKValue(String text) {
    if (text.isEmpty) return 0;
    final clean = text.replaceAll(RegExp(r'[^\d]'), '');
    int value = int.tryParse(clean) ?? 0;
    // Nếu nhập dưới 100.000 thì mặc định hiểu là hàng nghìn (quy ước K)
    if (value > 0 && value < 100000) {
      return value * 1000;
    }
    return value;
  }

  Future<Repair?> _onlySave() async {
    if (_saving) return null;
    if (phoneCtrl.text.isEmpty || modelCtrl.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng nhập SĐT và Model máy", color: Colors.red);
      return null;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final String uniqueId = "${now}_${phoneCtrl.text}";

      final r = Repair(
        firestoreId: uniqueId,
        customerName: nameCtrl.text.toUpperCase(),
        phone: phoneCtrl.text,
        model: modelCtrl.text.toUpperCase(),
        issue: issueCtrl.text.toUpperCase(),
        accessories: "${accCtrl.text} | MK: ${passCtrl.text}".toUpperCase(),
        address: addressCtrl.text.toUpperCase(),
        paymentMethod: _paymentMethod,
        price: _parseKValue(priceCtrl.text), // Chuyển đổi K thành tiền thật khi lưu
        createdAt: now,
        imagePath: _images.map((e) => e.path).join(','),
        createdBy: FirebaseAuth.instance.currentUser?.email?.split('@').first.toUpperCase() ?? "NV",
      );

      await db.upsertRepair(r);
      await FirestoreService.addRepair(r);
      return r;
    } catch (e) {
      NotificationService.showSnackBar("Lỗi: $e", color: Colors.red);
      return null;
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _saveAndPrint() async {
    final saved = await _onlySave();
    if (saved != null) {
      try {
        final shopInfo = {'shopName': 'SHOP NEW', 'shopAddr': addressCtrl.text, 'shopPhone': '0123.456.789'};
        await UnifiedPrinterService.printRepairReceiptFromRepair(saved, shopInfo);
      } catch (_) {}
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("TIẾP NHẬN MÁY", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _saveAndPrint, icon: const Icon(Icons.print, color: Colors.blueAccent))],
      ),
      body: _saving ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _sectionTitle("1. KHÁCH HÀNG"),
            _input(phoneCtrl, "SỐ ĐIỆN THOẠI *", Icons.phone, type: TextInputType.phone, f: phoneF, next: nameF),
            _input(nameCtrl, "TÊN KHÁCH HÀNG", Icons.person, caps: true, f: nameF, next: modelF),
            
            const SizedBox(height: 20),
            _sectionTitle("2. THÔNG TIN MÁY"),
            _quick(brands, modelCtrl, issueF),
            _input(modelCtrl, "MODEL MÁY *", Icons.phone_android, caps: true, f: modelF, next: issueF),
            
            if (_recentDevices.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(spacing: 8, children: _recentDevices.map((d) => ActionChip(label: Text(d['model'], style: const TextStyle(fontSize: 10)), onPressed: () => setState(() => modelCtrl.text = d['model']))).toList()),
            ],

            _sectionTitle("3. TÌNH TRẠNG & GIÁ"),
            _quick(commonIssues, issueCtrl, priceF),
            _input(issueCtrl, "LỖI MÁY *", Icons.build, caps: true, f: issueF, next: priceF),
            
            // Ô NHẬP GIÁ VỚI QUY ƯỚC K
            _input(
              priceCtrl, "GIÁ DỰ KIẾN", Icons.monetization_on, 
              type: TextInputType.number, 
              f: priceF, next: passF,
              suffix: "k", // Hiện chữ k đằng sau để nhắc nhở
              hint: "Ví dụ: 500 = 500.000"
            ),
            
            ExpansionTile(
              title: const Text("THÔNG TIN THÊM", style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
              children: [
                _input(passCtrl, "MẬT KHẨU MÀN HÌNH", Icons.lock, f: passF, next: appearanceF),
                _input(appearanceCtrl, "NGOẠI QUAN", Icons.remove_red_eye, f: appearanceF, next: accF),
                _input(accCtrl, "PHỤ KIỆN", Icons.headphones, f: accF),
              ],
            ),
            
            const SizedBox(height: 20),
            _imageRow(),
            
            const SizedBox(height: 30),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: _saving ? null : () async { final ok = await _onlySave(); if (ok != null && mounted) Navigator.pop(context, true); }, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text("CHỈ LƯU"))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton.icon(onPressed: _saving ? null : _saveAndPrint, icon: const Icon(Icons.print, color: Colors.white), label: const Text("LƯU & IN PHIẾU", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 12))));

  Widget _input(TextEditingController c, String l, IconData i, {bool caps = false, TextInputType type = TextInputType.text, FocusNode? f, FocusNode? next, String? suffix, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c, focusNode: f, keyboardType: type,
        textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.none,
        onSubmitted: (_) { if (next != null) FocusScope.of(context).requestFocus(next); },
        decoration: InputDecoration(
          labelText: l, hintText: hint, prefixIcon: Icon(i, size: 20, color: Colors.blueAccent),
          suffixText: suffix,
          suffixStyle: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true, fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _quick(List<String> items, TextEditingController target, FocusNode? nextF) {
    return Container(
      height: 38, margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (ctx, i) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(items[i], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () {
              setState(() => target.text = items[i]);
              if (nextF != null) FocusScope.of(context).requestFocus(nextF);
            },
          ),
        ),
      ),
    );
  }

  Widget _imageRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        ..._images.map((f) => Container(margin: const EdgeInsets.only(right: 10), width: 70, height: 70, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(f, fit: BoxFit.cover)))),
        GestureDetector(onTap: () async {
          final f = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 40);
          if (f != null) setState(() => _images.add(File(f.path)));
        }, child: Container(width: 70, height: 70, decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add_a_photo, color: Colors.blueAccent))),
      ]),
    );
  }
}
