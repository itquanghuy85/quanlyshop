import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import 'customer_history_view.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../services/audit_service.dart';
import '../services/user_service.dart';
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

  final phoneCtrl = TextEditingController(); // SĐT LÊN TRƯỚC
  final nameCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final modelCtrl = TextEditingController();
  final issueCtrl = TextEditingController();
  final appearanceCtrl = TextEditingController(); // GHI CHÚ NGOẠI QUAN (TRẦY, BỂ...)
  final accCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  final FocusNode _modelFocus = FocusNode();
  final FocusNode _issueFocus = FocusNode();

  String _paymentMethod = "TIỀN MẶT";

  final List<String> brands = ["IPHONE", "SAMSUNG", "OPPO", "REDMI", "VIVO"];
  final List<String> issues = ["NGUỒN", "MÀN HÌNH", "PIN", "ÉP KÍNH", "SẠC", "MẤT SÓNG", "LOA", "MIC", "CAMERA"];

  @override
  void initState() {
    super.initState();
    phoneCtrl.addListener(_smartFill);
  }

  @override
  void dispose() {
    phoneCtrl.removeListener(_smartFill);
    phoneCtrl.dispose();
    nameCtrl.dispose();
    addressCtrl.dispose();
    modelCtrl.dispose();
    issueCtrl.dispose();
    appearanceCtrl.dispose();
    accCtrl.dispose();
    passCtrl.dispose();
    priceCtrl.dispose();
    _modelFocus.dispose();
    _issueFocus.dispose();
    super.dispose();
  }

  void _smartFill() async {
    if (phoneCtrl.text.length >= 10) {
      final res = await db.getUniqueCustomersAll();
      final find = res.where((c) => c['phone'] == phoneCtrl.text).toList();
      if (find.isNotEmpty) {
        setState(() {
          nameCtrl.text = find.first['customerName'];
          addressCtrl.text = (find.first['address'] ?? "").toString();
        });
      }
    }
  }

  int _parseCurrency(String text) {
    final cleaned = text.replaceAll('.', '');
    return int.tryParse(cleaned) ?? 0;
  }

  Future<void> _save() async {
    // Validate required fields
    final phoneError = UserService.validatePhone(phoneCtrl.text);
    final nameError = UserService.validateName(nameCtrl.text);
    final modelError = modelCtrl.text.trim().isEmpty ? 'Mô hình máy không được để trống' : null;
    final issueError = issueCtrl.text.trim().isEmpty ? 'Lỗi máy không được để trống' : null;

    if (phoneError != null || nameError != null || modelError != null || issueError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(phoneError ?? nameError ?? modelError ?? issueError!),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Validate price
    final price = _parseCurrency(priceCtrl.text);
    if (price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("GIÁ TIẾP NHẬN PHẢI LỚN HƠN HOẶC BẰNG 0!"),
        backgroundColor: Colors.red,
      ));
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
      address: addressCtrl.text.toUpperCase(),
      paymentMethod: _paymentMethod,
      price: price,
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
    AuditService.logAction(
      action: 'CREATE_REPAIR',
      entityType: 'repair',
      entityId: r.firestoreId ?? "repair_${r.createdAt}_${r.phone}",
      summary: "${r.customerName} - ${r.model}",
      payload: {'paymentMethod': r.paymentMethod, 'price': r.price},
    );
    await NotificationService.sendCloudNotification(title: "ĐƠN MỚI", body: "${r.createdBy} NHẬN ${r.model} CỦA KHÁCH ${r.customerName}");
    if (!mounted) return;
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
            ValidatedTextField(
              controller: nameCtrl,
              label: "TÊN KHÁCH HÀNG",
              icon: Icons.person,
              inputFormatters: [TextInputFormatter.withFunction((oldValue, newValue) => TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection))],
            ),
            ValidatedTextField(
              controller: phoneCtrl,
              label: "SỐ ĐIỆN THOẠI",
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              required: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
            ),
            ValidatedTextField(
              controller: addressCtrl,
              label: "ĐỊA CHỈ KHÁCH HÀNG",
              icon: Icons.location_on,
              inputFormatters: [TextInputFormatter.withFunction((oldValue, newValue) => TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection))],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _addCustomerToContactsFromRepair,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text("THÊM VÀO DANH BẠ", style: TextStyle(fontSize: 12)),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final phone = phoneCtrl.text.trim();
                  if (phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("VUI LÒNG NHẬP SỐ ĐIỆN THOẠI TRƯỚC")),
                    );
                    return;
                  }
                  final name = nameCtrl.text.trim().isEmpty ? phone : nameCtrl.text.trim().toUpperCase();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerHistoryView(phone: phone, name: name),
                    ),
                  );
                },
                icon: const Icon(Icons.history, size: 18),
                label: const Text("XEM LỊCH SỬ KHÁCH NÀY", style: TextStyle(fontSize: 12)),
              ),
            ),
            const Divider(height: 30),
            _quick(brands, modelCtrl, _modelFocus),
            _input(modelCtrl, "MODEL MÁY *", Icons.phone_android, caps: true, requiredField: true, focusNode: _modelFocus),
            _quick(issues, issueCtrl, _issueFocus),
            _input(issueCtrl, "LỖI MÁY *", Icons.build, caps: true, requiredField: true, focusNode: _issueFocus),
            ValidatedTextField(
              controller: appearanceCtrl,
              label: "TÌNH TRẠNG NGOẠI QUAN",
              hint: "Ví dụ: TRẦY, BỂ, VÊNH...",
              inputFormatters: [TextInputFormatter.withFunction((oldValue, newValue) => TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection))],
            ),
            ValidatedTextField(
              controller: accCtrl,
              label: "PHỤ KIỆN ĐI KÈM",
              hint: "Ví dụ: SẠC, TAI NGHE...",
              inputFormatters: [TextInputFormatter.withFunction((oldValue, newValue) => TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection))],
            ),
            ValidatedTextField(
              controller: passCtrl,
              label: "MẬT KHẨU MÀN HÌNH",
              hint: "Nhập mật khẩu nếu có",
            ),
            ValidatedTextField(
              controller: priceCtrl,
              label: "GIÁ DỰ KIẾN",
              icon: Icons.monetization_on,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              hint: "Nhập giá dự kiến",
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("HÌNH THỨC THANH TOÁN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        _payChip("TIỀN MẶT"),
                        _payChip("CHUYỂN KHOẢN"),
                        _payChip("CÔNG NỢ"),
                        _payChip("TRẢ GÓP (NH)"),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _imageRow(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text("LƯU ĐƠN TIẾP NHẬN", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String l, IconData i, {bool caps = false, TextInputType type = TextInputType.text, String? suffix, bool requiredField = false, FocusNode? focusNode, List<TextInputFormatter>? inputFormatters}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: c,
        focusNode: focusNode,
        keyboardType: type,
        textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.none,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: l,
          prefixIcon: Icon(i, size: 20, color: requiredField ? Colors.redAccent : null),
          suffixText: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _quick(List<String> items, TextEditingController target, FocusNode focusNode) {
    return Container(
      alignment: Alignment.centerLeft,
      height: 44,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (ctx, i) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(items[i], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () {
              final base = target.text.trim();
              final next = base.isEmpty ? "${items[i]} " : "$base ${items[i]} ";
              setState(() => target.text = next.toUpperCase());
              target.selection = TextSelection.fromPosition(TextPosition(offset: target.text.length));
              FocusScope.of(context).requestFocus(focusNode);
            },
          ),
        ),
      ),
    );
  }

  Widget _payChip(String label) {
    final isSelected = _paymentMethod == label;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
      selected: isSelected,
      selectedColor: Colors.blueAccent,
      backgroundColor: Colors.grey.shade200,
      onSelected: (_) => setState(() => _paymentMethod = label),
    );
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
    if (!mounted) return;
    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("KHÁCH HÀNG NÀY ĐÃ CÓ TRONG DANH BẠ")),
      );
      return;
    }

    final addressCtrl = TextEditingController(text: this.addressCtrl.text.trim());

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

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Allow only numbers
    final regEx = RegExp(r'^\d+$');
    if (!regEx.hasMatch(newValue.text)) {
      return oldValue;
    }

    // Format with dots every 3 digits
    final number = int.tryParse(newValue.text) ?? 0;
    final formatted = _formatCurrency(number);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatCurrency(int number) {
    if (number == 0) return '0';

    final String numberStr = number.toString();
    final StringBuffer buffer = StringBuffer();

    for (int i = numberStr.length - 1, count = 0; i >= 0; i--, count++) {
      buffer.write(numberStr[i]);
      if ((count + 1) % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }

    return buffer.toString().split('').reversed.join('');
  }
}
