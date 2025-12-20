import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';

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

  final phoneCtrl = TextEditingController(); // SĐT LÊN TRƯỚC
  final nameCtrl = TextEditingController();
  final modelCtrl = TextEditingController();
  final issueCtrl = TextEditingController();
  final appearanceCtrl = TextEditingController(); // GHI CHÚ NGOẠI QUAN (TRẦY, BỂ...)
  final accCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  final List<String> brands = ["IPHONE", "SAMSUNG", "OPPO", "REDMI", "VIVO"];
  final List<String> issues = ["NGUỒN", "MÀN HÌNH", "PIN", "ÉP KÍNH", "SẠC"];

  @override
  void initState() {
    super.initState();
    phoneCtrl.addListener(_smartFill);
  }

  void _smartFill() async {
    if (phoneCtrl.text.length >= 10) {
      final res = await db.getUniqueCustomersAll();
      final find = res.where((c) => c['phone'] == phoneCtrl.text).toList();
      if (find.isNotEmpty) {
        setState(() {
          nameCtrl.text = find.first['customerName'];
        });
      }
    }
  }

  Future<void> _save() async {
    if (phoneCtrl.text.isEmpty || modelCtrl.text.isEmpty || issueCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("BẮT BUỘC: SĐT, MÁY VÀ LỖI!"), backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    final user = FirebaseAuth.instance.currentUser;
    final r = Repair(
      customerName: nameCtrl.text.toUpperCase(),
      phone: phoneCtrl.text,
      model: modelCtrl.text.toUpperCase(),
      issue: "${issueCtrl.text.toUpperCase()} | NGOẠI QUAN: ${appearanceCtrl.text.toUpperCase()} | MK: ${passCtrl.text}",
      accessories: accCtrl.text.toUpperCase(),
      price: (int.tryParse(priceCtrl.text) ?? 0) * 1000,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      imagePath: _images.map((e) => e.path).join(','),
      createdBy: user?.email?.split('@').first.toUpperCase() ?? "NV",
    );
    await db.insertRepair(r);

    // Đẩy ngay lên Cloud để máy khác nhận được
    final docId = await FirestoreService.addRepair(r);
    if (docId != null) {
      r.firestoreId = docId;
      r.isSynced = true;
      await db.updateRepair(r);
    }
    await NotificationService.sendCloudNotification(title: "ĐƠN MỚI", body: "${r.createdBy} NHẬN ${r.model} CỦA KHÁCH ${r.customerName}");
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("TIẾP NHẬN MÁY MỚI"), actions: [IconButton(onPressed: _save, icon: const Icon(Icons.check, color: Colors.green, size: 30))]),
      body: _saving ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            _input(phoneCtrl, "SỐ ĐIỆN THOẠI *", Icons.phone, type: TextInputType.phone),
            _input(nameCtrl, "TÊN KHÁCH HÀNG", Icons.person, caps: true),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _addCustomerToContactsFromRepair,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text("THÊM VÀO DANH BẠ", style: TextStyle(fontSize: 12)),
              ),
            ),
            const Divider(height: 30),
            _input(modelCtrl, "MODEL MÁY *", Icons.phone_android, caps: true),
            _quick(brands, (v) => modelCtrl.text = v),
            _input(issueCtrl, "LỖI MÁY *", Icons.build, caps: true),
            _quick(issues, (v) => issueCtrl.text = v),
            _input(appearanceCtrl, "TÌNH TRẠNG NGOẠI QUAN (TRẦY, BỂ...)", Icons.visibility),
            _input(accCtrl, "PHỤ KIỆN ĐI KÈM", Icons.usb),
            _input(passCtrl, "MẬT KHẨU MÀN HÌNH", Icons.lock_open),
            _input(priceCtrl, "GIÁ DỰ KIẾN", Icons.monetization_on, type: TextInputType.number, suffix: ".000 Đ"),
            const SizedBox(height: 20),
            _imageRow(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String l, IconData i, {bool caps = false, TextInputType type = TextInputType.text, String? suffix}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: c, keyboardType: type, textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.none,
        decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, size: 20), suffixText: suffix, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Widget _quick(List<String> items, Function(String) onSelect) {
    return SizedBox(height: 40, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: items.length, itemBuilder: (ctx, i) => Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(items[i], style: const TextStyle(fontSize: 10)), onPressed: () => setState(() => onSelect(items[i]))))));
  }

  Widget _imageRow() {
    return Row(children: [
      ..._images.map((f) => Container(margin: const EdgeInsets.only(right: 10), width: 60, height: 60, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey)), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(f, fit: BoxFit.cover)))),
      GestureDetector(onTap: () async {
        final f = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 50);
        if (f != null) setState(() => _images.add(File(f.path)));
      }, child: Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add_a_photo, color: Colors.grey))),
    ]);
  }

  Future<void> _addCustomerToContactsFromRepair() async {
    final phone = phoneCtrl.text.trim();
    final name = nameCtrl.text.trim().toUpperCase();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("VUI LÒNG NHẬP SỐ ĐIỆN THOẠI TRƯỚC")),
      );
      return;
    }

    final existing = await db.getCustomerByPhone(phone);
    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("KHÁCH HÀNG NÀY ĐÃ CÓ TRONG DANH BẠ")),
      );
      return;
    }

    final addressCtrl = TextEditingController();

    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("THÊM VÀO DANH BẠ"),
          content: TextField(
            controller: addressCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: "ĐỊA CHỈ KHÁCH HÀNG"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("LƯU")),
          ],
        );
      },
    );

    if (result == true) {
      await db.insertCustomer({
        'name': (name.isEmpty ? phone : name),
        'phone': phone,
        'address': addressCtrl.text.trim().toUpperCase(),
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ĐÃ THÊM KHÁCH HÀNG VÀO DANH BẠ")),
      );
    }
  }
}
