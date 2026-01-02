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

  final phoneF = FocusNode();
  final nameF = FocusNode();
  final modelF = FocusNode();
  final issueF = FocusNode();
  final priceF = FocusNode();
  final passF = FocusNode();
  final appearanceF = FocusNode();
  final accF = FocusNode();

  // Partner selection
  bool _sendToPartner = false;
  RepairPartner? _selectedPartner;
  final partnerCostCtrl = TextEditingController();
  final repairContentCtrl = TextEditingController();
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
      final formatted = "${NumberFormat('#,###').format(num)}.000";
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
    int v = MoneyUtils.parseMoney(text);
    return (v > 0 && v < 100000) ? v * 1000 : v;
  }

  Future<Repair?> _saveOrderProcess() async {
    if (phoneCtrl.text.isEmpty || modelCtrl.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng nhập SĐT và Model máy", color: Colors.red);
      return null;
    }
    
    // Validate partner fields if outsourcing is selected
    if (_sendToPartner) {
      if (_selectedPartner == null) {
        NotificationService.showSnackBar("Vui lòng chọn đối tác sửa chữa", color: Colors.red);
        return null;
      }
      if (partnerCostCtrl.text.isEmpty) {
        NotificationService.showSnackBar("Vui lòng nhập chi phí đối tác", color: Colors.red);
        return null;
      }
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
      final r = Repair(
        firestoreId: "rep_${now}_${phoneCtrl.text}",
        customerName: nameCtrl.text.trim().toUpperCase(),
        phone: phoneCtrl.text.trim(),
        model: modelCtrl.text.trim().toUpperCase(),
        issue: issueCtrl.text.trim().toUpperCase(),
        accessories: "$finalAccs | MK: ${passCtrl.text}".trim().toUpperCase(),
        address: addressCtrl.text.trim().toUpperCase(),
        price: _parseFinalPrice(priceCtrl.text),
        createdAt: now,
        imagePath: cloudImagePaths,
        createdBy: FirebaseAuth.instance.currentUser?.email?.split('@').first.toUpperCase() ?? "NV",
      );

      await db.upsertRepair(r);
      final cloudDocId = await FirestoreService.addRepair(r);
      if (cloudDocId == null) throw Exception('Lỗi đồng bộ đám mây');
      await db.logAction(userId: FirebaseAuth.instance.currentUser?.uid ?? "0", userName: r.createdBy ?? "NV", action: "NHẬP ĐƠN SỬA", type: "REPAIR", targetId: r.firestoreId, desc: "Đã nhập đơn sửa ${r.model} cho khách ${r.customerName}");
      
      // Handle partner outsourcing if selected
      if (_sendToPartner && _selectedPartner != null) {
        final service = RepairPartnerService();
        final success = await service.createPartnerHistoryForRepair(
          repairOrderId: cloudDocId,
          partnerId: _selectedPartner!.id!,
          partnerCost: _parseFinalPrice(partnerCostCtrl.text),
          customerName: r.customerName,
          deviceModel: r.model,
          issue: r.issue,
          repairContent: repairContentCtrl.text.trim().isNotEmpty ? repairContentCtrl.text.trim() : null,
        );
        
        if (!success) {
          // Log warning but don't fail the repair creation
          debugPrint('Warning: Partner history creation failed, but repair was created');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("NHẬP ĐƠN SỬA CHỮA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                _input(priceCtrl, "GIÁ DỰ KIẾN (k)", Icons.monetization_on, type: TextInputType.number, f: priceF, next: passF, suffix: "k"),
                
                const SizedBox(height: 15),
                _sectionTitle("GỬI ĐỐI TÁC SỬA CHỮA"),
                CheckboxListTile(
                  title: Text("Gửi đối tác ngoài sửa chữa", style: TextStyle(fontWeight: FontWeight.bold)),
                  value: _sendToPartner,
                  onChanged: (value) {
                    setState(() {
                      _sendToPartner = value ?? false;
                      if (!_sendToPartner) {
                        _selectedPartner = null;
                        partnerCostCtrl.clear();
                        repairContentCtrl.clear();
                      }
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                
                if (_sendToPartner) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<RepairPartner>(
                    decoration: InputDecoration(
                      labelText: "Chọn đối tác *",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    value: _selectedPartner,
                    items: _partners.map((partner) {
                      return DropdownMenuItem(
                        value: partner,
                        child: Text("${partner.name} ${partner.phone?.isNotEmpty == true ? '(${partner.phone})' : ''}"),
                      );
                    }).toList(),
                    onChanged: (partner) {
                      setState(() {
                        _selectedPartner = partner;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 10),
                  _input(partnerCostCtrl, "Chi phí đối tác (k)", Icons.monetization_on, type: TextInputType.number, suffix: "k"),
                  
                  const SizedBox(height: 10),
                  _input(repairContentCtrl, "Nội dung sửa chữa", Icons.description, caps: true, maxLines: 2),
                ],
                
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
                  Expanded(child: OutlinedButton.icon(onPressed: _saving ? null : _onlySave, icon: const Icon(Icons.save_rounded), label: const Text("LƯU ĐƠN", style: TextStyle(fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton.icon(onPressed: _saving ? null : _saveAndPrint, icon: const Icon(Icons.print_rounded), label: const Text("LƯU & IN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 4, 12, 247), elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), padding: const EdgeInsets.symmetric(vertical: 16)))),
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

  Widget _sectionTitle(String title) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 11)));

  Widget _input(TextEditingController c, String l, IconData i, {bool caps = false, TextInputType type = TextInputType.text, FocusNode? f, FocusNode? next, String? suffix, int? maxLines}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: ValidatedTextField(controller: c, label: l.replaceAll(' *', ''), icon: i, keyboardType: type, uppercase: caps, required: l.contains('*'), maxLines: maxLines, onSubmitted: () { if (next != null) FocusScope.of(context).requestFocus(next); }));
  }

  Widget _quick(List<String> items, TextEditingController target, FocusNode? nextF) {
    return Container(height: 38, margin: const EdgeInsets.only(bottom: 8), child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: items.length, itemBuilder: (ctx, i) => Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(items[i], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), onPressed: () { setState(() => target.text = items[i]); if (nextF != null) FocusScope.of(context).requestFocus(nextF); }))));
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
