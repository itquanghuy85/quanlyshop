import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../l10n/app_localizations.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import 'customer_history_view.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';
import '../services/unified_printer_service.dart';
import '../widgets/validated_text_field.dart';

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
  final imeiCtrl = TextEditingController();

  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _modelFocus = FocusNode();
  final FocusNode _priceFocus = FocusNode();

  String _paymentMethod = "TIỀN MẶT";
  List<Map<String, dynamic>> _recentDevices = [];

  final List<String> brands = ["IPHONE", "SAMSUNG", "OPPO", "REDMI", "VIVO"];
  final List<String> commonIssues = ["THAY PIN", "ÉP KÍNH", "THAY MÀN", "MẤT NGUỒN", "LOA/MIC", "SẠC", "PHẦN MỀM"];

  @override
  void initState() {
    super.initState();
    phoneCtrl.addListener(_smartFill);
  }

  @override
  void dispose() {
    phoneCtrl.dispose(); nameCtrl.dispose(); addressCtrl.dispose();
    modelCtrl.dispose(); issueCtrl.dispose(); appearanceCtrl.dispose();
    accCtrl.dispose(); passCtrl.dispose(); priceCtrl.dispose(); imeiCtrl.dispose();
    _phoneFocus.dispose(); _modelFocus.dispose(); _priceFocus.dispose();
    super.dispose();
  }

  void _smartFill() async {
    if (phoneCtrl.text.length >= 10) {
      final res = await db.getUniqueCustomersAll();
      final find = res.where((c) => c['phone'] == phoneCtrl.text).toList();
      if (find.isNotEmpty) {
        setState(() {
          nameCtrl.text = find.first['customerName'] ?? "";
          addressCtrl.text = (find.first['address'] ?? "").toString();
        });
        final repairs = await db.getAllRepairs();
        final devices = repairs.where((r) => r.phone == phoneCtrl.text).map((r) => {'model': r.model, 'imei': r.imei}).toSet().toList();
        setState(() => _recentDevices = devices.take(3).toList());
      }
    }
  }

  Future<void> _saveAndPrint() async {
    if (phoneCtrl.text.isEmpty || modelCtrl.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng nhập SĐT và Model máy", color: Colors.red);
      return;
    }

    setState(() => _saving = true);
    try {
      final price = int.tryParse(priceCtrl.text.replaceAll('.', '')) ?? 0;
      final r = Repair(
        customerName: nameCtrl.text.toUpperCase(),
        phone: phoneCtrl.text,
        model: modelCtrl.text.toUpperCase(),
        issue: issueCtrl.text.toUpperCase(),
        accessories: "${accCtrl.text} | MK: ${passCtrl.text}".toUpperCase(),
        address: addressCtrl.text.toUpperCase(),
        paymentMethod: _paymentMethod,
        price: price,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        imagePath: _images.map((e) => e.path).join(','),
        createdBy: FirebaseAuth.instance.currentUser?.email?.split('@').first.toUpperCase() ?? "NV",
        imei: imeiCtrl.text.toUpperCase(),
        condition: appearanceCtrl.text.toUpperCase(),
      );

      // 1. Lưu SQLite
      await db.insertRepair(r);
      
      // 2. Đẩy Cloud
      final docId = await FirestoreService.addRepair(r);
      if (docId != null) { r.firestoreId = docId; r.isSynced = true; await db.upsertRepair(r); }

      // 3. Gọi lệnh in Phiếu Tiếp Nhận (Hợp nhất từ RepairReceiptView)
      final shopInfo = {
        'shopName': 'SHOP NEW', // Bạn có thể lấy từ Settings sau
        'shopAddr': addressCtrl.text.isNotEmpty ? addressCtrl.text : 'Hồ Chí Minh',
        'shopPhone': '0123.456.789'
      };
      
      await UnifiedPrinterService.printRepairReceiptFromRepair(r, shopInfo);

      NotificationService.showSnackBar("ĐÃ LƯU & ĐANG IN PHIẾU TIẾP NHẬN", color: Colors.green);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      NotificationService.showSnackBar("LỖI: $e", color: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("TIẾP NHẬN & IN PHIẾU", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _saveAndPrint, icon: const Icon(Icons.print, size: 28, color: Colors.green))],
      ),
      body: _saving ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _sectionTitle("1. KHÁCH HÀNG"),
            _input(phoneCtrl, "SỐ ĐIỆN THOẠI *", Icons.phone, type: TextInputType.phone, focusNode: _phoneFocus),
            _input(nameCtrl, "TÊN KHÁCH HÀNG", Icons.person, caps: true),
            
            if (_recentDevices.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: _recentDevices.map((d) => ActionChip(
                label: Text(d['model'], style: const TextStyle(fontSize: 11)),
                onPressed: () => setState(() { modelCtrl.text = d['model']; imeiCtrl.text = d['imei'] ?? ""; }),
              )).toList()),
            ],

            const SizedBox(height: 20),
            _sectionTitle("2. THÔNG TIN MÁY"),
            _quick(brands, modelCtrl, _modelFocus),
            Row(children: [
              Expanded(child: _input(modelCtrl, "MODEL MÁY *", Icons.phone_android, caps: true, focusNode: _modelFocus)),
              const SizedBox(width: 8),
              IconButton(onPressed: () async {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (ctx) => Scaffold(
                  appBar: AppBar(title: const Text("QUÉT IMEI/SERIAL")),
                  body: MobileScanner(onDetect: (cap) {
                    final code = cap.barcodes.first.rawValue;
                    if (code != null) Navigator.pop(ctx, code);
                  }),
                )));
                if (res != null) setState(() => imeiCtrl.text = res.toString().toUpperCase());
              }, icon: const Icon(Icons.qr_code_scanner, color: Colors.blueAccent, size: 30)),
            ]),
            _input(imeiCtrl, "SỐ IMEI / SERIAL", Icons.fingerprint, caps: true),
            
            _sectionTitle("3. TÌNH TRẠNG & GIÁ"),
            _quick(commonIssues, issueCtrl, null),
            _input(issueCtrl, "LỖI MÁY *", Icons.build, caps: true),
            _input(priceCtrl, "GIÁ DỰ KIẾN (VNĐ)", Icons.monetization_on, type: TextInputType.number, formatters: [CurrencyInputFormatter()], focusNode: _priceFocus),
            
            ExpansionTile(
              title: const Text("THÔNG TIN BỔ SUNG", style: TextStyle(fontSize: 13, color: Colors.blue)),
              children: [
                _input(passCtrl, "MẬT KHẨU MÁY", Icons.lock),
                _input(appearanceCtrl, "NGOẠI QUAN", Icons.remove_red_eye),
                _input(accCtrl, "PHỤ KIỆN", Icons.headphones),
                _input(addressCtrl, "ĐỊA CHỈ", Icons.map),
              ],
            ),
            
            const SizedBox(height: 20),
            _imageRow(),
            
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton.icon(
                onPressed: _saveAndPrint,
                icon: const Icon(Icons.print, color: Colors.white),
                label: const Text("LƯU & IN PHIẾU TIẾP NHẬN", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 13))));

  Widget _input(TextEditingController c, String l, IconData i, {bool caps = false, TextInputType type = TextInputType.text, FocusNode? focusNode, List<TextInputFormatter>? formatters}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c, focusNode: focusNode, keyboardType: type,
        textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.none,
        inputFormatters: formatters,
        onSubmitted: (_) { if (focusNode != null) FocusScope.of(context).nextFocus(); },
        decoration: InputDecoration(
          labelText: l, prefixIcon: Icon(i, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true, fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  Widget _quick(List<String> items, TextEditingController target, FocusNode? nextFocus) {
    return Container(
      height: 40, margin: const EdgeInsets.only(bottom: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (ctx, i) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(items[i], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () {
              setState(() => target.text = items[i]);
              if (nextFocus != null) FocusScope.of(context).requestFocus(nextFocus);
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
        ..._images.map((f) => Stack(children: [
          Container(margin: const EdgeInsets.only(right: 10), width: 80, height: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(f, fit: BoxFit.cover))),
          Positioned(right: 5, top: 0, child: GestureDetector(onTap: () => setState(() => _images.remove(f)), child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)))),
        ])),
        GestureDetector(
          onTap: () async {
            final f = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 40);
            if (f != null) setState(() => _images.add(File(f.path)));
          },
          child: Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add_a_photo, color: Colors.blueAccent)),
        ),
      ]),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final String cleanedText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanedText.isEmpty) return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    final number = int.tryParse(cleanedText) ?? 0;
    final formatted = _formatCurrency(number);
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
  String _formatCurrency(int number) {
    if (number == 0) return '0';
    final String numberStr = number.toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = numberStr.length - 1, count = 0; i >= 0; i--, count++) {
      buffer.write(numberStr[i]);
      if ((count + 1) % 3 == 0 && i > 0) buffer.write('.');
    }
    return buffer.toString().split('').reversed.join('');
  }
}
