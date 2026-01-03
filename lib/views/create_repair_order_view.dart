import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/unified_printer_service.dart';
import '../utils/money_utils.dart';
import '../widgets/validated_text_field.dart';
import '../models/repair_partner_model.dart';
import '../services/repair_partner_service.dart';
import '../models/repair_service_model.dart';

class CreateRepairOrderView extends StatefulWidget {
  final String role;
  const CreateRepairOrderView({super.key, this.role = 'user'});

  @override
  State<CreateRepairOrderView> createState() => _CreateRepairOrderViewState();
}

class _CreateRepairOrderViewState extends State<CreateRepairOrderView> {
  final NumberFormat currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
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

  final phoneF = FocusNode();
  final nameF = FocusNode();
  final modelF = FocusNode();
  final issueF = FocusNode();
  final priceF = FocusNode();
  final passF = FocusNode();
  final appearanceF = FocusNode();
  final accF = FocusNode();

  // Services with partners
  List<RepairService> _services = [];
  List<RepairPartner> _partners = [];

  final List<String> brands = ["IPHONE", "SAMSUNG", "OPPO", "REDMI", "VIVO"];
  final List<String> commonIssues = ["THAY PIN", "ÉP KÍNH", "THAY MÀN", "MẤT NGUỒN", "LOA/MIC", "SẠC", "PHẦN MỀM"];
  
  final List<String> quickAccs = [ "SIM", "ỐP LƯNG",  "KO PHỤ KIỆN"];
  final Set<String> _selectedAccs = {};

  @override
  void initState() {
    super.initState();
    phoneCtrl.addListener(() {
      if (phoneCtrl.text.length == 10) _smartFill();
    });
    priceCtrl.addListener(_formatPrice);
    _loadPartners();
  }

  void _loadPartners() async {
    try {
      final service = RepairPartnerService();
      final partners = await service.getRepairPartners();
      setState(() {
        _partners = partners.where((p) => p.active).toList();
      });
    } catch (e) {
      debugPrint('Error loading partners: $e');
    }
  }

  void _formatPrice() {
    final text = priceCtrl.text;
    if (text.isEmpty) return;
    final clean = text.replaceAll(',', '').split('.').first;
    final num = int.tryParse(clean);
    if (num != null) {
      final formatted = "${NumberFormat('#,###').format(num)}";
      if (formatted != text) {
        priceCtrl.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length - 4),
        );
      }
    }
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
    int v = int.tryParse(text.replaceAll(',', '').replaceAll('.', '')) ?? 0;
    return v * 1000;
  }

  Future<Repair?> _saveOrderProcess() async {
    if (phoneCtrl.text.isEmpty || modelCtrl.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng nhập SĐT và Model máy", color: Colors.red);
      return null;
    }
    
    if (_services.isEmpty) {
      NotificationService.showSnackBar("Vui lòng thêm ít nhất một dịch vụ sửa chữa", color: Colors.red);
      return null;
    }

    setState(() { _saving = true; _uploadStatus = "Đang đồng bộ dữ liệu đám mây..."; });
    try {
      String cloudImagePaths = "";
      if (_images.isNotEmpty) {
        List<String> localPaths = _images.map((e) => e.path).toList();
        cloudImagePaths = await StorageService.uploadMultipleAndJoin(localPaths.join(','), 'repairs');
      }

      String finalAccs = _selectedAccs.join(', ');
      if (accCtrl.text.isNotEmpty) {
        finalAccs = finalAccs.isEmpty ? accCtrl.text.toUpperCase() : "$finalAccs, ${accCtrl.text.toUpperCase()}";
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final totalCost = _services.fold(0, (sum, s) => sum + s.cost);
      final r = Repair(
        firestoreId: "rep_${now}_${phoneCtrl.text}",
        customerName: nameCtrl.text.trim().toUpperCase(),
        phone: phoneCtrl.text.trim(),
        model: modelCtrl.text.trim().toUpperCase(),
        issue: issueCtrl.text.trim().toUpperCase(),
        accessories: "$finalAccs | MK: ${passCtrl.text}".trim().toUpperCase(),
        address: addressCtrl.text.trim().toUpperCase(),
        price: _parseFinalPrice(priceCtrl.text),
        cost: totalCost,
        createdAt: now,
        imagePath: cloudImagePaths,
        createdBy: FirebaseAuth.instance.currentUser?.email?.split('@').first.toUpperCase() ?? "NV",
        services: _services,
      );

      await db.upsertRepair(r);
      final cloudDocId = await FirestoreService.addRepair(r);
      if (cloudDocId == null) throw Exception('Lỗi đồng bộ đám mây');
      await db.logAction(userId: FirebaseAuth.instance.currentUser?.uid ?? "0", userName: r.createdBy ?? "NV", action: "NHẬP ĐƠN SỬA", type: "REPAIR", targetId: r.firestoreId, desc: "Đã nhập đơn sửa ${r.model} cho khách ${r.customerName}");
      
      // Handle partner outsourcing for services that have partners
      final service = RepairPartnerService();
      for (var s in _services.where((s) => s.partnerId != null)) {
        final success = await service.createPartnerHistoryForRepair(
          repairOrderId: cloudDocId,
          partnerId: s.partnerId!,
          partnerCost: s.cost,
          customerName: r.customerName,
          deviceModel: r.model,
          issue: s.serviceName,
          repairContent: s.serviceName,
        );
        if (!success) {
          debugPrint('Warning: Partner history creation failed for service ${s.serviceName}');
        }
      }
      
      // Trigger new order notification
      try {
        await NotificationService.sendNewOrderNotification(cloudDocId, r.customerName, r.price);
      } catch (e) {
        debugPrint('Failed to send new order notification: $e');
        // Don't fail the repair creation if notification fails
      }
      
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

  List<Widget> _buildServicesSection() {
    return [
      if (_services.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: _services.map((service) => ListTile(
              title: Text(service.serviceName),
              subtitle: service.partnerName != null 
                ? Text("Đối tác: ${service.partnerName} - Chi phí: ${currencyFormat.format(service.cost)}")
                : Text("Chi phí: ${currencyFormat.format(service.cost)}"),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => setState(() => _services.remove(service)),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Text("Tổng chi phí: ${currencyFormat.format(_services.fold(0, (sum, s) => sum + s.cost))}", 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        const SizedBox(height: 10),
      ],
      ElevatedButton.icon(
        onPressed: _showAddServiceDialog,
        icon: const Icon(Icons.add),
        label: const Text("THÊM DỊCH VỤ"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
    ];
  }

  void _showAddServiceDialog([RepairService? editService]) {
    final serviceCtrl = TextEditingController(text: editService?.serviceName ?? '');
    final costCtrl = TextEditingController(text: editService != null ? (editService.cost ~/ 1000).toString() : '');
    RepairPartner? selectedPartner = editService != null ? _partners.firstWhere((p) => p.id == editService.partnerId) : null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(editService != null ? "Sửa dịch vụ" : "Thêm dịch vụ"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: serviceCtrl,
              decoration: const InputDecoration(labelText: "Tên dịch vụ *"),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: costCtrl,
              decoration: const InputDecoration(labelText: "Chi phí (,000) *", suffixText: ",000"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<RepairPartner>(
              decoration: const InputDecoration(labelText: "Đối tác (tùy chọn)"),
              value: selectedPartner,
              items: [
                const DropdownMenuItem(value: null, child: Text("Không có đối tác")),
                ..._partners.map((p) => DropdownMenuItem(value: p, child: Text(p.name))),
              ],
              onChanged: (p) => selectedPartner = p,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () {
              if (serviceCtrl.text.isEmpty || costCtrl.text.isEmpty) {
                NotificationService.showSnackBar("Vui lòng nhập tên dịch vụ và chi phí", color: Colors.red);
                return;
              }
              final cost = int.tryParse(costCtrl.text) ?? 0;
              final service = RepairService(
                serviceName: serviceCtrl.text.trim().toUpperCase(),
                cost: cost * 1000,
                partnerId: selectedPartner?.id,
                partnerName: selectedPartner?.name,
              );
              setState(() {
                if (editService != null) {
                  final index = _services.indexOf(editService);
                  _services[index] = service;
                } else {
                  _services.add(service);
                }
              });
              Navigator.pop(ctx);
            },
            child: Text(editService != null ? "Cập nhật" : "Thêm"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("NHẬP ĐƠN SỬA CHỮA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        automaticallyImplyLeading: true,
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
                _input(priceCtrl, "GIÁ DỰ KIẾN (,000)", Icons.monetization_on, type: TextInputType.number, f: priceF, next: passF, suffix: ",000"),
                
                const SizedBox(height: 15),
                _sectionTitle("DỊCH VỤ SỬA CHỮA"),
                ..._buildServicesSection(),
                
                _input(passCtrl, "MẬT KHẨU MÀN HÌNH", Icons.lock, f: passF),
                
                const SizedBox(height: 15),
                _sectionTitle("PHỤ KIỆN ĐI KÈM"),
                // HÀNG NÚT CHỌN NHANH ƯU TIÊN THEO YÊU CẦU
                Row(
                  children: [
                    _priorityChip("CHỈ SIM", () { setState(() { _selectedAccs.clear(); _selectedAccs.add("SIM"); }); }),
                    const SizedBox(width: 8),
                    _priorityChip("CHỈ ỐP", () { setState(() { _selectedAccs.clear(); _selectedAccs.add("ỐP LƯNG"); }); }),
                    const SizedBox(width: 8),
                    _priorityChip("CẢ SIM & ỐP", () { setState(() { _selectedAccs.clear(); _selectedAccs.add("SIM"); _selectedAccs.add("ỐP LƯNG"); }); }),
                  ],
                ),
                const SizedBox(height: 10),
                _buildQuickAccs(),
                _input(accCtrl, "PHỤ KIỆN KHÁC", Icons.add_box_outlined, caps: true),

                const SizedBox(height: 20),
                const Text("HÌNH ẢNH HIỆN TRẠNG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                const SizedBox(height: 10),
                _imageRow(),
                const SizedBox(height: 40),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: _saving ? null : _onlySave, icon: const Icon(Icons.save_rounded), label: const Text("LƯU ĐƠN", style: TextStyle(fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton.icon(onPressed: _saving ? null : _saveAndPrint, icon: const Icon(Icons.print_rounded), label: const Text("LƯU & IN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 4, 12, 247), elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), padding: const EdgeInsets.symmetric(vertical: 12)))),
                ]),
              ],
            ),
          ),
    );
  }

  Widget _priorityChip(String label, VoidCallback onTap) {
    return Expanded(
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.orange.shade700,
        padding: const EdgeInsets.all(0),
        onPressed: () {
          HapticFeedback.lightImpact();
          onTap();
        },
      ),
    );
  }

  Widget _buildQuickAccs() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Wrap(
        spacing: 8, runSpacing: 0,
        children: quickAccs.map((acc) {
          final isSelected = _selectedAccs.contains(acc);
          return FilterChip(
            label: Text(acc, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : Colors.black87)),
            selected: isSelected,
            onSelected: (v) {
              HapticFeedback.lightImpact();
              setState(() { v ? _selectedAccs.add(acc) : _selectedAccs.remove(acc); });
            },
            selectedColor: const Color(0xFF2962FF),
            checkmarkColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 10)));

  Widget _input(TextEditingController c, String l, IconData i, {bool caps = false, TextInputType type = TextInputType.text, FocusNode? f, FocusNode? next, String? suffix, int? maxLines}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: ValidatedTextField(controller: c, label: l.replaceAll(' *', ''), icon: i, keyboardType: type, uppercase: caps, required: l.contains('*'), maxLines: maxLines, onSubmitted: () { if (next != null) FocusScope.of(context).requestFocus(next); }));
  }

  Widget _quick(List<String> items, TextEditingController target, FocusNode? nextF) {
    return Container(height: 38, margin: const EdgeInsets.only(bottom: 8), child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: items.length, itemBuilder: (ctx, i) => Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(items[i], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), onPressed: () { setState(() => target.text = items[i]); if (nextF != null) FocusScope.of(context).requestFocus(nextF); }))));
  }

  Widget _imageRow() {
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [..._images.map((f) => Container(margin: const EdgeInsets.only(right: 10), width: 80, height: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(f, fit: BoxFit.cover)))), GestureDetector(onTap: () async { final f = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 40); if (f != null) setState(() => _images.add(File(f.path))); }, child: Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.blue.withAlpha(13), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add_a_photo, color: Colors.blue)))]));
  }

  @override
  void dispose() {
    priceCtrl.removeListener(_formatPrice);
    super.dispose();
  }
}
