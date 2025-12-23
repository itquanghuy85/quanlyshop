import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/repair_model.dart';
import '../data/db_helper.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';
import '../services/thermal_printer_service.dart';
import '../services/user_service.dart';
import '../services/audit_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/unified_printer_service.dart';
import '../widgets/printer_selection_dialog.dart';

class RepairDetailView extends StatefulWidget {
  final Repair repair;
  const RepairDetailView({super.key, required this.repair});

  @override
  State<RepairDetailView> createState() => _RepairDetailViewState();
}

class _RepairDetailViewState extends State<RepairDetailView> {
  final db = DBHelper();
  bool _isAdmin = false;
  late Repair r;
  
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final modelCtrl = TextEditingController();
  final issueCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  final colorCtrl = TextEditingController();
  final imeiCtrl = TextEditingController();
  final conditionCtrl = TextEditingController();
  
  final List<File> _receiveImages = [];
  final List<File> _deliveryImages = [];
  bool _isSaving = false;
  final ScreenshotController _shareController = ScreenshotController();

  // Theme colors cho màn hình chi tiết đơn sửa chữa
  final Color _primaryColor = Colors.blue; // Đồng bộ với create_repair_order_view
  final Color _accentColor = Colors.blue.shade600;
  final Color _backgroundColor = const Color(0xFFF8FAFF);

  final List<String> warrantyOptions = ["KO BH", "1 tháng", "3 tháng", "6 tháng", "12 tháng"];
  String _selectedWarranty = "KO BH";

  bool get isAdmin => _isAdmin;
  bool _managerUnlocked = false;
  bool _checkingManager = false;
  bool get isReadOnly => !(_managerUnlocked || isAdmin) && r.status >= 3; // Chỉ khóa khi chưa mở khóa quản lý

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    r = widget.repair;
    _fillData();
  }

  Future<void> _loadPermissions() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() {
      _isAdmin = perms['allowViewRepairs'] ?? false; // Assuming admin permission for repairs
    });
  }

  String _normalizeWarranty(String w) {
    final upper = w.trim().toUpperCase();
    if (upper.isEmpty) return "KO BH";
    if (upper.contains("KHONG") || upper.contains("KHÔNG") || upper.contains("KO")) return "KO BH";
    for (final opt in warrantyOptions) {
      if (opt.toUpperCase() == upper) return opt;
    }
    return "KO BH";
  }

  void _fillData() {
    nameCtrl.text = r.customerName;
    phoneCtrl.text = r.phone;
    modelCtrl.text = r.model;
    issueCtrl.text = r.issue;
    priceCtrl.text = r.price > 0 ? (r.price / 1000).toStringAsFixed(0) : "";
    costCtrl.text = r.cost > 0 ? (r.cost / 1000).toStringAsFixed(0) : "";
    colorCtrl.text = r.color ?? "";
    imeiCtrl.text = r.imei ?? "";
    conditionCtrl.text = r.condition ?? "";
    _selectedWarranty = _normalizeWarranty(r.warranty);
  }

  Future<void> _unlockManager() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("CẦN ĐĂNG NHẬP TÀI KHOẢN QUẢN LÝ")));
      return;
    }
    final perms = await UserService.getCurrentUserPermissions();
    final isSuper = UserService.isCurrentUserSuperAdmin();
    if (!(perms['allowViewRepairs'] ?? false) && !isSuper) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chỉ tài khoản quản lý mới được sửa/xóa")));
      return;
    }

    final passCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÁC THỰC QUẢN LÝ"),
        content: TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Mật khẩu quản lý")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("XÁC NHẬN")),
        ],
      ),
    );

    if (ok != true) return;

    try {
      setState(() => _checkingManager = true);
      final cred = EmailAuthProvider.credential(email: user.email ?? '', password: passCtrl.text);
      await user.reauthenticateWithCredential(cred);
      if (mounted) {
        setState(() {
          _managerUnlocked = true;
          _checkingManager = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ĐÃ MỞ KHÓA CHỈNH SỬA")));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _checkingManager = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sai mật khẩu quản lý")));
      }
    }
  }

  // --- LOGIC CHUYỂN TRẠNG THÁI CHUẨN ---
  Future<void> _updateStatus(int newStatus) async {
    final user = FirebaseAuth.instance.currentUser;
    String userName = user?.email?.split('@').first.toUpperCase() ?? "NV";
    int now = DateTime.now().millisecondsSinceEpoch;

    setState(() {
      r.status = newStatus;
      if (newStatus == 2) { r.startedAt = now; r.repairedBy = userName; }
      else if (newStatus == 3) { r.finishedAt = now; }
      else if (newStatus == 4) { 
        r.deliveredAt = now; 
        r.deliveredBy = userName;
        r.warranty = _normalizeWarranty(_selectedWarranty);
      }
    });
    await db.upsertRepair(r);
    await FirestoreService.upsertRepair(r);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ĐÃ CHUYỂN: ${_getStatusLabel(newStatus)}")));
  }

  String _getStatusLabel(int s) {
    if (s == 1) return "MỚI NHẬN";
    if (s == 2) return "ĐANG SỬA";
    if (s == 3) return "SỬA XONG";
    if (s == 4) return "ĐÃ GIAO";
    return "MỚI NHẬN";
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    if (_receiveImages.isNotEmpty) {
      List<String> urls = await StorageService.uploadMultipleImages(_receiveImages.map((e) => e.path).toList(), 'repairs/${r.createdAt}');
      r.imagePath = (r.imagePath == null || r.imagePath!.isEmpty) ? urls.join(',') : "${r.imagePath},${urls.join(',')}";
    }
    if (_deliveryImages.isNotEmpty) {
      List<String> urls = await StorageService.uploadMultipleImages(_deliveryImages.map((e) => e.path).toList(), 'repairs/${r.createdAt}/delivery');
      r.deliveredImage = (r.deliveredImage == null || r.deliveredImage!.isEmpty) ? urls.join(',') : "${r.deliveredImage},${urls.join(',')}";
    }

    r.customerName = nameCtrl.text.toUpperCase();
    r.phone = phoneCtrl.text;
    r.model = modelCtrl.text.toUpperCase();
    r.issue = issueCtrl.text.toUpperCase();
    r.price = (int.tryParse(priceCtrl.text) ?? 0) * 1000;
    r.cost = (int.tryParse(costCtrl.text) ?? 0) * 1000;
    r.color = colorCtrl.text.isNotEmpty ? colorCtrl.text : null;
    r.imei = imeiCtrl.text.isNotEmpty ? imeiCtrl.text : null;
    r.condition = conditionCtrl.text.isNotEmpty ? conditionCtrl.text : null;
    r.warranty = _normalizeWarranty(_selectedWarranty);
    r.isSynced = false;

    await db.upsertRepair(r);
    await FirestoreService.upsertRepair(r);
    setState(() => _isSaving = false);
    AuditService.logAction(
      action: 'UPDATE_REPAIR',
      entityType: 'repair',
      entityId: r.firestoreId ?? "repair_${r.createdAt}_${r.phone}",
      summary: r.customerName,
      payload: {'status': r.status, 'price': r.price},
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        title: const Text("CHI TIẾT ĐƠN HÀNG", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_checkingManager)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ),
          if (!_managerUnlocked)
            IconButton(onPressed: _unlockManager, icon: const Icon(Icons.edit, color: Colors.white)),
          IconButton(onPressed: _callCustomer, icon: const Icon(Icons.call, color: Colors.white)),
          IconButton(onPressed: _sendSmsToCustomer, icon: const Icon(Icons.sms_outlined, color: Colors.white)),
          IconButton(onPressed: _sendToChat, icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white)),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'print':
                  _printWifi();
                  break;
                case 'share':
                  _shareRepair();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print_rounded),
                    SizedBox(width: 8),
                    Text('In WiFi'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_rounded),
                    SizedBox(width: 8),
                    Text('Chia sẻ'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
          if (_managerUnlocked)
            IconButton(onPressed: _deleteRepair, icon: const Icon(Icons.delete_forever, color: Colors.white)),
        ],
      ),
      body: _isSaving ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. TIMELINE & TRẠNG THÁI
          _card("TIẾN ĐỘ VẬN HÀNH", Column(
            children: [
              _timeItem("Nhận", r.createdAt, r.createdBy ?? "NV", true),
              _timeItem("Sửa", r.startedAt, r.repairedBy ?? "---", r.status >= 2),
              _timeItem("Xong", r.finishedAt, "HT", r.status >= 3),
              _timeItem("Giao", r.deliveredAt, r.deliveredBy ?? "---", r.status >= 4),
              const SizedBox(height: 15),
              if (!isReadOnly) Row(children: [
                if (r.status == 1) Expanded(child: _actionBtn("BẮT ĐẦU SỬA", _accentColor, () => _updateStatus(2))),
                if (r.status == 2) Expanded(child: _actionBtn("XÁC NHẬN XONG", Colors.green, () => _updateStatus(3))),
                if (r.status == 3) ...[
                  Expanded(child: _actionBtn("GIAO MÁY", _primaryColor, () => _updateStatus(4))),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _selectedWarranty,
                    items: warrantyOptions.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setState(() => _selectedWarranty = v!),
                  )
                ]
              ]),
            ],
          )),

          // 2. THÔNG TIN KHÁCH & ẢNH NHẬN
          _card("THÔNG TIN KHÁCH & ẢNH NHẬN", Column(
            children: [
              _input(phoneCtrl, "Số điện thoại", Icons.phone, type: TextInputType.phone, readOnly: isReadOnly),
              const SizedBox(height: 10),
              _input(nameCtrl, "Tên khách hàng", Icons.person, caps: true, readOnly: isReadOnly),
              const SizedBox(height: 15),
              _imageGrid(r.receiveImages, _receiveImages, false),
            ],
          )),

          // 3. THIẾT BỊ & ẢNH GIAO
          _card("THIẾT BỊ & ẢNH GIAO", Column(
            children: [
              _input(modelCtrl, "Model máy", Icons.phone_android, caps: true, readOnly: isReadOnly),
              const SizedBox(height: 10),
              _input(issueCtrl, "Lỗi máy", Icons.build, caps: true, readOnly: isReadOnly),
              const SizedBox(height: 10),
              _input(colorCtrl, "Màu sắc", Icons.color_lens, caps: true, readOnly: isReadOnly),
              const SizedBox(height: 10),
              _input(imeiCtrl, "Số IMEI", Icons.perm_device_information, readOnly: isReadOnly),
              const SizedBox(height: 10),
              _input(conditionCtrl, "Tình trạng", Icons.stars, caps: true, readOnly: isReadOnly),
              const SizedBox(height: 15),
              _imageGrid(r.deliverImages, _deliveryImages, true),
            ],
          )),

          // 4. THANH TOÁN
          _card("THANH TOÁN", Row(
            children: [
              Expanded(child: _input(priceCtrl, "Giá sửa", Icons.monetization_on, type: TextInputType.number, suffix: "k", readOnly: isReadOnly)),
              if (isAdmin) const SizedBox(width: 10),
              if (isAdmin) Expanded(child: _input(costCtrl, "Giá vốn", Icons.account_balance_wallet, type: TextInputType.number, suffix: "k", readOnly: !isAdmin)),
            ],
          )),
        ],
      ),
    );
  }

  Widget _timeItem(String lab, int? t, String u, bool act) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Icon(act ? Icons.check_circle : Icons.radio_button_off, size: 14, color: act ? Colors.green : Colors.grey), const SizedBox(width: 10), Text(lab, style: TextStyle(fontSize: 12, fontWeight: act ? FontWeight.bold : FontWeight.normal)), const Spacer(), Text(t == null ? "--:--" : DateFormat('HH:mm dd/MM').format(DateTime.fromMillisecondsSinceEpoch(t)), style: const TextStyle(fontSize: 11, color: Colors.grey)), const SizedBox(width: 10), Text(u, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue))]));
  Widget _actionBtn(String l, Color c, VoidCallback o) => ElevatedButton(onPressed: o, style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text(l, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)));
  Widget _card(String t, Widget c) => Container(margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)), const Divider(), c]));
  Widget _input(TextEditingController c, String h, IconData i, {bool caps = false, TextInputType type = TextInputType.text, String? suffix, bool readOnly = false}) => TextField(controller: c, keyboardType: type, textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.none, readOnly: readOnly, decoration: InputDecoration(labelText: h, prefixIcon: Icon(i, size: 18), suffixText: suffix, border: const OutlineInputBorder()));
  Widget _imageGrid(List<String> cloud, List<File> local, bool isDel) => SizedBox(height: 80, child: ListView(scrollDirection: Axis.horizontal, children: [...cloud.map((url) => GestureDetector(onTap: () => _openGallery(cloud, cloud.indexOf(url)), child: Container(margin: const EdgeInsets.only(right: 8), width: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blueAccent)), child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(url, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image)))))), ...local.map((f) => Container(margin: const EdgeInsets.only(right: 8), width: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)), child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.file(f, fit: BoxFit.cover)))), GestureDetector(onTap: () async { final f = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 50); if (f != null) setState(() { if (isDel) _deliveryImages.add(File(f.path)); else _receiveImages.add(File(f.path)); }); }, child: Container(width: 80, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.add_a_photo, color: Colors.grey)))]));

  Future<void> _printWifi() async {
    // Show printer selection dialog
    final printerConfig = await showPrinterSelectionDialog(context);
    if (printerConfig == null) return; // User cancelled

    final prefs = await SharedPreferences.getInstance();
    final shopInfo = {
      'shopName': prefs.getString('shop_name') ?? 'TEN SHOP',
      'shopAddr': prefs.getString('shop_address') ?? 'DIA CHI',
      'shopPhone': prefs.getString('shop_phone') ?? 'SDT',
    };

    // Extract printer configuration
    final printerType = printerConfig['type'] as PrinterType?;
    final bluetoothPrinter = printerConfig['bluetoothPrinter'] as BluetoothPrinterConfig?;
    final wifiIp = printerConfig['wifiIp'] as String?;

    try {
      final success = await UnifiedPrinterService.printRepairReceiptFromRepair(
        r,
        shopInfo,
        printerType: printerType,
        bluetoothPrinter: bluetoothPrinter,
        wifiIp: wifiIp,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã in phiếu sửa chữa thành công!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('In thất bại! Vui lòng kiểm tra cài đặt máy in.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi in: $e')),
        );
      }
    }
  }

  Future<void> _printThermalLabel() async {
    // Show printer selection dialog
    final printerConfig = await showPrinterSelectionDialog(context);
    if (printerConfig == null) return; // User cancelled

    // Extract printer configuration
    final printerType = printerConfig['type'] as PrinterType?;
    final bluetoothPrinter = printerConfig['bluetoothPrinter'] as BluetoothPrinterConfig?;
    final wifiIp = printerConfig['wifiIp'] as String?;

    try {
      // For thermal labels, we primarily use Bluetooth printers
      // But we can extend this to support other types in the future
      bool success = false;

      if (printerType == PrinterType.bluetooth && bluetoothPrinter != null) {
        // Use specific Bluetooth printer
        final connected = await BluetoothPrinterService.connect(bluetoothPrinter.macAddress);
        if (connected) {
          success = await ThermalPrinterService.printDeviceLabel(
            deviceName: r.model,
            color: r.color,
            imei: r.imei,
            condition: r.condition,
            price: r.price != null ? '${NumberFormat('#,###').format(r.price)} VND' : null,
            accessories: r.accessories,
          );
        }
      } else {
        // Use default/saved printer
        success = await ThermalPrinterService.printDeviceLabel(
          deviceName: r.model,
          color: r.color,
          imei: r.imei,
          condition: r.condition,
          price: r.price != null ? '${NumberFormat('#,###').format(r.price)} VND' : null,
          accessories: r.accessories,
        );
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã in tem thông tin máy thành công!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('IN TEM THẤT BẠI: Vui lòng kiểm tra cài đặt máy in nhiệt.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('LỖI KHI IN TEM: $e')),
        );
      }
    }
  }

  Future<void> _sendToChat() async {
    final user = FirebaseAuth.instance.currentUser;
    final senderId = user?.uid ?? 'guest';
    final senderName = user?.email?.split('@').first.toUpperCase() ?? 'KHACH';
    final key = r.firestoreId ?? "${r.createdAt}_${r.phone}";
    final summary = "ĐƠN SỬA - ${r.customerName} - ${r.phone} - ${r.model}";
    final msg = "Trao đổi về $summary";

    await FirestoreService.sendChat(
      message: msg,
      senderId: senderId,
      senderName: senderName,
      linkedType: 'repair',
      linkedKey: key,
      linkedSummary: summary,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ĐÃ GIM ĐƠN SỬA VÀO CHAT NỘI BỘ")),
      );
    }
  }

  Future<void> _sendSmsToCustomer() async {
    final phone = r.phone.trim();
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("KHÔNG CÓ SỐ ĐIỆN THOẠI KHÁCH")),
      );
      return;
    }

    final customer = r.customerName.isNotEmpty ? r.customerName : phone;
    final body = "SHOP xin chào $customer, máy ${r.model} đã sửa xong/đang chờ giao. Anh/chị sắp xếp ghé nhận khi tiện nhé. Cảm ơn!";

    await Clipboard.setData(ClipboardData(text: body));

    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': body},
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ĐÃ MỞ ỨNG DỤNG NHẮN TIN (nội dung đã copy sẵn).")),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("KHÔNG MỞ ĐƯỢC ỨNG DỤNG NHẮN TIN, anh/chị dán nội dung vào Zalo/SMS giúp em.")),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("LỖI KHI GỬI TIN NHẮN, nhưng nội dung đã được copy sẵn.")),
      );
    }
  }

  Future<void> _callCustomer() async {
    final phone = r.phone.trim();
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("KHÔNG CÓ SỐ ĐIỆN THOẠI KHÁCH")),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("KHÔNG THỂ GỌI ĐƯỢC SỐ NÀY")),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("LỖI KHI GỌI")),
      );
    }
  }

  Future<void> _deleteRepair() async {
    if (r.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÓA ĐƠN SỬA"),
        content: const Text("Bạn chắc chắn muốn xóa đơn này?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("XÓA")),
        ],
      ),
    );

    if (ok == true) {
      await db.deleteRepair(r.id!);
      AuditService.logAction(
        action: 'DELETE_REPAIR',
        entityType: 'repair',
        entityId: r.firestoreId ?? "repair_${r.createdAt}_${r.phone}",
        summary: r.customerName,
        payload: {'model': r.model},
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _shareRepair() async {
    final dir = (await getApplicationDocumentsDirectory()).path;
    final fileName = 'PHIEU_SUA_${r.customerName.replaceAll(' ', '_')}.png';
    final summary = Container(
      width: 420,
      padding: const EdgeInsets.all(18),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Text('PHIẾU SỬA CHỮA', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue))),
          const SizedBox(height: 12),
          _shareRow('KHÁCH', r.customerName),
          _shareRow('SĐT', r.phone),
          _shareRow('MÁY', r.model),
          _shareRow('LỖI', r.issue),
          _shareRow('BẢO HÀNH', _normalizeWarranty(_selectedWarranty)),
          _shareRow('TRẠNG THÁI', _getStatusLabel(r.status)),
          _shareRow('NHÂN VIÊN', (r.deliveredBy ?? r.repairedBy ?? r.createdBy ?? '---').toUpperCase()),
          _shareRow('GIÁ SỬA', '${NumberFormat('#,###').format(r.price)} đ'),
          if (r.receiveImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('ẢNH TRƯỚC KHI NHẬN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: r.receiveImages
                  .take(4)
                  .map((url) => ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(url, width: 70, height: 70, fit: BoxFit.cover),
                      ))
                  .toList(),
            ),
          ],
          if (r.deliverImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('ẢNH SAU KHI GIAO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: r.deliverImages
                  .take(4)
                  .map((url) => ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(url, width: 70, height: 70, fit: BoxFit.cover),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Center(child: QrImageView(data: r.firestoreId ?? r.id?.toString() ?? 'REPAIR', size: 100)),
          const SizedBox(height: 8),
          const Center(child: Text('CẢM ƠN QUÝ KHÁCH!')),
        ],
      ),
    );

    final bytes = await _shareController.captureFromWidget(summary);
    final imgPath = '$dir/$fileName';
    await File(imgPath).writeAsBytes(bytes);
    await Share.shareXFiles([XFile(imgPath)], text: 'PHIẾU SỬA ${r.customerName}');
  }

  Widget _shareRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(fontWeight: FontWeight.bold)), Flexible(child: Text(v, textAlign: TextAlign.right))]),
  );

  void _openGallery(List<String> images, int index) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)), body: PhotoViewGallery.builder(itemCount: images.length, builder: (ctx, i) => PhotoViewGalleryPageOptions(imageProvider: NetworkImage(images[i]), initialScale: PhotoViewComputedScale.contained), pageController: PageController(initialPage: index)))));
  }
}
