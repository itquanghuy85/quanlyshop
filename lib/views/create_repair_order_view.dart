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

  AppLocalizations get l10n => AppLocalizations.of(context)!;

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
      if (!mounted) return;
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
    final l10n = AppLocalizations.of(context)!;
    // Validate required fields
    final phoneError = UserService.validatePhone(phoneCtrl.text);
    final nameError = UserService.validateName(nameCtrl.text);
    final modelError = modelCtrl.text.trim().isEmpty ? l10n.modelRequired : null;
    final issueError = issueCtrl.text.trim().isEmpty ? l10n.issueRequired : null;

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.priceMustBePositive),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _saving = true);
    try {
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
      
      await NotificationService.sendCloudNotification(
        title: "ĐƠN MỚI", 
        body: "${r.createdBy} NHẬN ${r.model} CỦA KHÁCH ${r.customerName}"
      );
      
      if (!mounted) return;
      
      // Hỏi người dùng có muốn tạo đơn mới không
      final createNew = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // Không cho phép dismiss bằng cách tap outside
        builder: (ctx) => AlertDialog(
          title: Text(l10n.orderCreatedSuccessfully),
          content: Text(l10n.createNewOrderQuestion),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.back),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text("TẠO ĐƠN MỚI"),
            ),
          ],
        ),
      );
      
      if (createNew == true) {
        // Reset form để tạo đơn mới
        if (mounted) {
          setState(() {
            _images.clear();
            phoneCtrl.clear();
            nameCtrl.clear();
            addressCtrl.clear();
            modelCtrl.clear();
            issueCtrl.clear();
            appearanceCtrl.clear();
            accCtrl.clear();
            passCtrl.clear();
            priceCtrl.clear();
            _paymentMethod = "TIỀN MẶT";
            _saving = false;
          });
          // Focus lại vào trường phone để nhập khách hàng mới
          FocusScope.of(context).requestFocus(FocusNode());
        }
        return; // Không pop, ở lại màn hình này
      }
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.saveOrderError(e)),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF), // Đồng bộ với theme chính
      appBar: AppBar(
        title: Text(l10n.createRepairOrder, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent, // Màu chính cho đơn sửa chữa
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            onPressed: _save,
            icon: const Icon(Icons.check, size: 30),
            style: IconButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
          )
        ],
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
            ValidatedTextField(
              controller: nameCtrl,
              label: l10n.customerName,
              icon: Icons.person,
              inputFormatters: [TextInputFormatter.withFunction((oldValue, newValue) => TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection))],
            ),
            ValidatedTextField(
              controller: phoneCtrl,
              label: l10n.phoneNumber,
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              required: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
            ),
            ValidatedTextField(
              controller: addressCtrl,
              label: l10n.customerAddress,
              icon: Icons.location_on,
              inputFormatters: [TextInputFormatter.withFunction((oldValue, newValue) => TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection))],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _addCustomerToContactsFromRepair,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: Text(l10n.addToContacts, style: const TextStyle(fontSize: 12)),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final phone = phoneCtrl.text.trim();
                  if (phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.enterPhoneFirst)),
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
                label: Text(l10n.viewCustomerHistory, style: const TextStyle(fontSize: 12)),
              ),
            ),
            const Divider(height: 30),
            _quick(brands, modelCtrl, _modelFocus),
            _input(modelCtrl, l10n.deviceModel, Icons.phone_android, caps: true, requiredField: true, focusNode: _modelFocus),
            _quick(issues, issueCtrl, _issueFocus),
            _input(issueCtrl, l10n.deviceIssue, Icons.build, caps: true, requiredField: true, focusNode: _issueFocus),
            ValidatedTextField(
              controller: appearanceCtrl,
              label: l10n.appearanceCondition,
              hint: l10n.appearanceHint,
              inputFormatters: [TextInputFormatter.withFunction((oldValue, newValue) => TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection))],
            ),
            ValidatedTextField(
              controller: accCtrl,
              label: l10n.accessoriesIncluded,
              hint: l10n.accessoriesHint,
              inputFormatters: [TextInputFormatter.withFunction((oldValue, newValue) => TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection))],
            ),
            ValidatedTextField(
              controller: passCtrl,
              label: l10n.screenPassword,
              hint: l10n.passwordHint,
            ),
            ValidatedTextField(
              controller: priceCtrl,
              label: l10n.estimatedPrice,
              icon: Icons.monetization_on,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              hint: l10n.priceHint,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.paymentMethod, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        _payChip(l10n.cash),
                        _payChip(l10n.transfer),
                        _payChip(l10n.debt),
                        _payChip(l10n.installment),
                        _payChip(l10n.t86),
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
                label: Text(l10n.saveRepairOrder, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
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

    final tempAddressCtrl = TextEditingController(text: addressCtrl.text.trim());

    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("THÊM VÀO DANH BẠ"),
          content: TextField(
            controller: tempAddressCtrl,
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
        'address': tempAddressCtrl.text.trim().toUpperCase(),
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ĐÃ THÊM KHÁCH HÀNG VÀO DANH BẠ")),
      );
    }
    tempAddressCtrl.dispose();
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Strip all non-digit characters to get the raw number
    final String cleanedText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanedText.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final number = int.tryParse(cleanedText) ?? 0;
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
