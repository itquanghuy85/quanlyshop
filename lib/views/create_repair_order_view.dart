import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/unified_printer_service.dart';
import '../widgets/validated_text_field.dart';
import '../widgets/currency_text_field.dart';

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
  String _uploadStatus = "";

  final phoneCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final modelCtrl = TextEditingController();
  final issueCtrl = TextEditingController();
  final appearanceCtrl = TextEditingController();
  final accCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final warrantyCtrl = TextEditingController(text: "Không bảo hành");

  final phoneF = FocusNode();
  final nameF = FocusNode();
  final modelF = FocusNode();
  final issueF = FocusNode();
  final priceF = FocusNode();
  final passF = FocusNode();
  final appearanceF = FocusNode();
  final accF = FocusNode();
  final warrantyF = FocusNode();

  final List<String> brands = ["IPHONE", "SAMSUNG", "OPPO", "REDMI", "VIVO"];
  final List<String> commonIssues = ["THAY PIN", "ÉP KÍNH", "THAY MÀN", "MẤT NGUỒN", "LOA/MIC", "SẠC", "PHẦN MỀM"];
  final List<String> warrantyOptions = ["Không bảo hành", "6 tháng", "12 tháng", "24 tháng"];

  @override
  void initState() {
    super.initState();
    phoneCtrl.addListener(() {
      if (phoneCtrl.text.length == 10) _smartFill();
    });
  }

  void _smartFill() async {
    final res = await db.getUniqueCustomersAll();
    final find = res.where((c) => c['phone'] == phoneCtrl.text).toList();
    if (find.isNotEmpty) {
      setState(() {
        nameCtrl.text = find.first['customerName'] ?? "";
        addressCtrl.text = (find.first['address'] ?? "").toString();
      });
    }
  }

  int _parseFinalPrice(String text) {
    final clean = text.replaceAll(RegExp(r'[^\d]'), '');
    int v = int.tryParse(clean) ?? 0;
    return (v > 0 && v < 100000) ? v * 1000 : v;
  }

  // TÁCH HÀM LƯU RIÊNG BIỆT ĐỂ DÙNG CHUNG
  Future<Repair?> _saveOrderProcess() async {
    if (phoneCtrl.text.isEmpty || modelCtrl.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng nhập SĐT và Model máy", color: Colors.red);
      return null;
    }

    setState(() { _saving = true; _uploadStatus = "Đang đồng bộ dữ liệu đám mây..."; });
    try {
      String cloudImagePaths = "";
      if (_images.isNotEmpty) {
        List<String> localPaths = _images.map((e) => e.path).toList();
        cloudImagePaths = await StorageService.uploadMultipleAndJoin(localPaths.join(','), 'repairs');
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final r = Repair(
        firestoreId: "rep_${now}_${phoneCtrl.text}",
        customerName: nameCtrl.text.trim().toUpperCase(),
        phone: phoneCtrl.text.trim(),
        model: modelCtrl.text.trim().toUpperCase(),
        issue: issueCtrl.text.trim().toUpperCase(),
        accessories: "${accCtrl.text} | MK: ${passCtrl.text}".trim().toUpperCase(),
        address: addressCtrl.text.trim().toUpperCase(),
        price: _parseFinalPrice(priceCtrl.text),
        warranty: warrantyCtrl.text,
        createdAt: now,
        imagePath: cloudImagePaths,
        createdBy: FirebaseAuth.instance.currentUser?.email?.split('@').first.toUpperCase() ?? "NV",
      );

      await db.upsertRepair(r);
      await FirestoreService.addRepair(r);
      await db.logAction(userId: FirebaseAuth.instance.currentUser?.uid ?? "0", userName: r.createdBy ?? "NV", action: "NHẬP ĐƠN SỬA", type: "REPAIR", targetId: r.firestoreId, desc: "Đã nhập đơn sửa ${r.model} cho khách ${r.customerName}");
      
      return r;
    } catch (e) {
      NotificationService.showSnackBar("Lỗi: $e", color: Colors.red);
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onlySave() async {
    final r = await _saveOrderProcess();
    if (r != null) {
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
      NotificationService.showSnackBar("ĐÃ LƯU ĐƠN THÀNH CÔNG", color: Colors.green);
    }
  }

  Future<void> _saveAndPrint() async {
    final r = await _saveOrderProcess();
    if (r != null) {
      HapticFeedback.mediumImpact();
      NotificationService.showSnackBar("Đang gửi lệnh in phiếu...", color: Colors.blue);
      await UnifiedPrinterService.printRepairReceiptFromRepair(r, {'shopName': 'QUANG HUY', 'shopAddr': 'HÀ NỘI', 'shopPhone': '0964095979'});
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("NHẬP ĐƠN SỬA CHỮA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [IconButton(onPressed: _saveAndPrint, icon: const Icon(Icons.print, color: Color(0xFF2962FF)))],
      ),
      body: _saving 
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text(_uploadStatus, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))]))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle("THÔNG TIN KHÁCH HÀNG"),
                _input(phoneCtrl, "SỐ ĐIỆN THOẠI *", Icons.phone, type: TextInputType.phone, f: phoneF, next: nameF),
                _input(nameCtrl, "TÊN KHÁCH HÀNG", Icons.person, caps: true, f: nameF, next: modelF),
                const SizedBox(height: 15),
                _sectionTitle("THÔNG TIN MÁY"),
                _quick(brands, modelCtrl, issueF),
                _input(modelCtrl, "MODEL MÁY *", Icons.phone_android, caps: true, f: modelF, next: issueF),
                const SizedBox(height: 15),
                _sectionTitle("TÌNH TRẠNG LỖI"),
                _quick(commonIssues, issueCtrl, priceF),
                _input(issueCtrl, "LỖI MÁY *", Icons.build, caps: true, f: issueF, next: priceF),
                _input(priceCtrl, "GIÁ DỰ KIẾN (k)", Icons.monetization_on, type: TextInputType.number, f: priceF, next: warrantyF, suffix: "k"),
                const SizedBox(height: 15),
                _sectionTitle("BẢO HÀNH"),
                _quick(warrantyOptions, warrantyCtrl, passF),
                _input(warrantyCtrl, "THỜI HẠN BẢO HÀNH", Icons.verified_user, f: warrantyF, next: passF),
                _input(passCtrl, "MẬT KHẨU MÀN HÌNH", Icons.lock, f: passF),
                const SizedBox(height: 20),
                const Text("HÌNH ẢNH HIỆN TRẠNG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                const SizedBox(height: 10),
                _imageRow(),
                const SizedBox(height: 40),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _onlySave,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text("CHỈ LƯU ĐƠN", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveAndPrint,
                      icon: const Icon(Icons.print_rounded),
                      label: const Text("LƯU & IN PHIẾU", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF), elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
    );
  }

  Widget _sectionTitle(String title) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 11)));

  Widget _input(TextEditingController c, String l, IconData i, {bool caps = false, TextInputType type = TextInputType.text, FocusNode? f, FocusNode? next, String? suffix}) {
    if (type == TextInputType.number && (l.contains('GIÁ') || l.contains('TIỀN'))) {
      // Use CurrencyTextField for price fields
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CurrencyTextField(
          controller: c,
          label: l,
          icon: i,
          onSubmitted: () { if (next != null) FocusScope.of(context).requestFocus(next); },
        ),
      );
    } else {
      // Use ValidatedTextField for text fields
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ValidatedTextField(
          controller: c,
          label: l,
          icon: i,
          keyboardType: type,
          uppercase: caps,
          onSubmitted: () { if (next != null) FocusScope.of(context).requestFocus(next); },
        ),
      );
    }
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
        ..._images.map((f) => Container(margin: const EdgeInsets.only(right: 10), width: 80, height: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(f, fit: BoxFit.cover)))),
        GestureDetector(onTap: () async {
          final f = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 40);
          if (f != null) setState(() => _images.add(File(f.path)));
        }, child: Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add_a_photo, color: Colors.blue))),
      ]),
    );
  }
}
