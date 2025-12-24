import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../services/user_service.dart';
import '../data/db_helper.dart';
import '../services/storage_service.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import 'repair_detail_view.dart';
import 'sale_detail_view.dart';

ImageProvider? _safeImageProvider(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return NetworkImage(path);
  final file = File(path);
  return file.existsSync() ? FileImage(file) : null;
}

class StaffListView extends StatefulWidget {
  const StaffListView({super.key});

  @override
  State<StaffListView> createState() => _StaffListViewState();
}

class _StaffListViewState extends State<StaffListView> {
  final db = DBHelper();
  String? _currentRole;
  String? _currentShopId;
  bool _isSuperAdmin = false;
  bool _loadingRole = true;
  
  String? _currentInviteCode;
  String? _currentShopName;
  bool _generatingInvite = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserRole();
  }

  Future<void> _loadCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    if (user == null) {
      setState(() => _loadingRole = false);
      return;
    }

    final role = await UserService.getUserRole(user.uid);
    final shopId = await UserService.getCurrentShopId();

    if (!mounted) return;
    setState(() {
      _currentRole = role;
      _currentShopId = shopId;
      _isSuperAdmin = UserService.isCurrentUserSuperAdmin();
      _loadingRole = false;
    });

    if (role == 'owner' && shopId != null) {
      _loadCurrentInviteCode();
      _loadShopName();
    }
  }

  Future<void> _loadShopName() async {
    if (_currentShopId == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('shops').doc(_currentShopId).get();
      if (doc.exists) {
        final data = doc.data();
        setState(() => _currentShopName = data?['name'] ?? 'Shop không tên');
      }
    } catch (_) {}
  }

  Future<void> _loadCurrentInviteCode() async {
    if (_currentShopId == null) return;
    try {
      final query = await FirebaseFirestore.instance
          .collection('invites')
          .where('shopId', isEqualTo: _currentShopId)
          .where('used', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(1).get();
      if (query.docs.isNotEmpty) {
        final inviteData = query.docs.first.data();
        final expiresAt = DateTime.parse(inviteData['expiresAt']);
        if (expiresAt.isAfter(DateTime.now())) {
          setState(() => _currentInviteCode = query.docs.first.id);
        }
      }
    } catch (_) {}
  }

  bool get _canManageStaff => _isSuperAdmin || _currentRole == 'owner' || _currentRole == 'manager';

  Future<void> _generateInviteCode() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_currentShopId == null) return;
    setState(() => _generatingInvite = true);
    try {
      final code = await UserService.createInviteCode(_currentShopId!);
      setState(() => _currentInviteCode = code);
      messenger.showSnackBar(const SnackBar(content: Text('Đã tạo mã mời mới!')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _generatingInvite = false);
    }
  }

  void _showInviteQRDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('MÃ MỜI THAM GIA SHOP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentInviteCode != null) ...[
              const Text('Quét mã để tham gia shop:', textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
              const SizedBox(height: 20),
              QrImageView(
                data: '{"type":"invite_code","code":"$_currentInviteCode","shopName":"$_currentShopName"}',
                size: 200, backgroundColor: Colors.white,
              ),
              const SizedBox(height: 15),
              SelectableText(_currentInviteCode!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue, letterSpacing: 3)),
            ] else const Text('Chưa có mã mời nào được tạo'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ĐÓNG')),
          ElevatedButton(onPressed: _generatingInvite ? null : _generateInviteCode, child: const Text('TẠO MÃ MỚI')),
        ],
      ),
    );
  }

  void _openCreateStaffDialog() {
    final emailC = TextEditingController();
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        String role = 'employee';
        bool submitting = false;
        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: const Text('THÊM NHÂN VIÊN MỚI'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: emailC, decoration: const InputDecoration(labelText: 'Email đăng nhập')),
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Họ tên')),
                TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'SĐT')),
                DropdownButtonFormField<String>(
                  value: role,
                  items: const [
                    DropdownMenuItem(value: 'employee', child: Text('Nhân viên')),
                    DropdownMenuItem(value: 'technician', child: Text('Kỹ thuật')),
                    DropdownMenuItem(value: 'manager', child: Text('Quản lý')),
                  ],
                  onChanged: (v) => setS(() => role = v!),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('HỦY')),
              ElevatedButton(onPressed: submitting ? null : () async {
                setS(() => submitting = true);
                try {
                  final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1').httpsCallable('createStaffAccount');
                  await callable.call({
                    'email': emailC.text.trim(),
                    'password': '12345678', // Mặc định
                    'displayName': nameC.text.trim(),
                    'phone': phoneC.text.trim(),
                    'role': role,
                    'shopId': _currentShopId,
                  });
                  if (mounted) Navigator.pop(ctx);
                } catch (e) {
                  setS(() => submitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
                }
              }, child: const Text('TẠO')),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(title: const Text("QUẢN LÝ NHÂN VIÊN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      floatingActionButton: _canManageStaff ? FloatingActionButton.extended(onPressed: _openCreateStaffDialog, label: const Text("Thêm nhân viên"), icon: const Icon(Icons.person_add)) : null,
      body: _loadingRole ? const Center(child: CircularProgressIndicator()) : StreamBuilder<QuerySnapshot>(
        stream: UserService.getAllUsersStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final users = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: users.length,
            itemBuilder: (ctx, i) {
              final userData = users[i].data() as Map<String, dynamic>;
              final uid = users[i].id;
              final role = userData['role'] ?? 'user';
              final displayName = userData['displayName'] ?? "Nhân viên";
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: CircleAvatar(backgroundImage: _safeImageProvider(userData['photoUrl'])),
                  title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Vai trò: $role\nSĐT: ${userData['phone'] ?? ''}"),
                  trailing: const Icon(Icons.history_edu_rounded, color: Colors.blue),
                  onTap: () => _showStaffActivityCenter(uid, displayName, userData['email'] ?? "", role, userData),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showStaffActivityCenter(String uid, String name, String email, String currentRole, Map<String, dynamic> fullData) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => _StaffActivityCenter(uid: uid, name: name, email: email, role: currentRole, fullData: fullData, isSuperAdmin: _isSuperAdmin),
    );
  }
}

class _StaffActivityCenter extends StatefulWidget {
  final String uid, name, email, role;
  final Map<String, dynamic> fullData;
  final bool isSuperAdmin;
  const _StaffActivityCenter({required this.uid, required this.name, required this.email, required this.role, required this.fullData, required this.isSuperAdmin});
  @override
  State<_StaffActivityCenter> createState() => _StaffActivityCenterState();
}

class _StaffActivityCenterState extends State<_StaffActivityCenter> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final db = DBHelper();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  String _selectedRole = 'employee';
  bool _isSaving = false;

  // Quyền hạn
  bool _vSales = true; bool _vRepairs = true; bool _vInv = true; bool _vRev = false;
  bool _vParts = true; bool _vSup = true; bool _vCust = true; bool _vWar = true;
  bool _vChat = true; bool _vPrint = true; bool _vExp = false; bool _vDebts = false;

  // Lịch sử chấm công
  List<Map<String, dynamic>> _attendanceHistory = [];
  bool _loadingAttendance = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    nameCtrl.text = widget.fullData['displayName'] ?? widget.name;
    phoneCtrl.text = widget.fullData['phone'] ?? "";
    addressCtrl.text = widget.fullData['address'] ?? "";
    
    const validRoles = ['owner', 'manager', 'employee', 'technician', 'user', 'admin'];
    _selectedRole = validRoles.contains(widget.role) ? widget.role : 'employee';

    _vSales = widget.fullData['allowViewSales'] ?? true;
    _vRepairs = widget.fullData['allowViewRepairs'] ?? true;
    _vInv = widget.fullData['allowViewInventory'] ?? true;
    _vRev = widget.fullData['allowViewRevenue'] ?? false;
    _vParts = widget.fullData['allowViewParts'] ?? true;
    _vSup = widget.fullData['allowViewSuppliers'] ?? true;
    _vCust = widget.fullData['allowViewCustomers'] ?? true;
    _vWar = widget.fullData['allowViewWarranty'] ?? true;
    _vChat = widget.fullData['allowViewChat'] ?? true;
    _vPrint = widget.fullData['allowViewPrinter'] ?? true;
    _vExp = widget.fullData['allowViewExpenses'] ?? false;
    _vDebts = widget.fullData['allowViewDebts'] ?? false;

    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    final list = await db.getAttendanceByUser(widget.uid);
    if (mounted) setState(() { _attendanceHistory = list; _loadingAttendance = false; });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await UserService.updateUserInfo(uid: widget.uid, name: nameCtrl.text, phone: phoneCtrl.text, address: addressCtrl.text, role: _selectedRole);
      await UserService.updateUserPermissions(uid: widget.uid, allowViewSales: _vSales, allowViewRepairs: _vRepairs, allowViewInventory: _vInv, allowViewParts: _vParts, allowViewSuppliers: _vSup, allowViewCustomers: _vCust, allowViewWarranty: _vWar, allowViewChat: _vChat, allowViewPrinter: _vPrint, allowViewRevenue: _vRev, allowViewExpenses: _vExp, allowViewDebts: _vDebts);
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ĐÃ CẬP NHẬT NHÂN VIÊN")));
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const CircleAvatar(radius: 25, child: Icon(Icons.person)),
                const SizedBox(width: 15),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(widget.email, style: const TextStyle(fontSize: 11, color: Colors.grey))])),
                ElevatedButton(onPressed: _isSaving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), child: const Text("LƯU", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: Colors.blue, unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            tabs: const [Tab(text: "THÔNG TIN"), Tab(text: "PHÂN QUYỀN"), Tab(text: "LỊCH CHẤM CÔNG")],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(),
                _buildPermTab(),
                _buildAttendanceTab(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _input(nameCtrl, "Họ và tên", Icons.person_outline),
          _input(phoneCtrl, "Số điện thoại", Icons.phone_android, type: TextInputType.phone),
          _input(addressCtrl, "Địa chỉ", Icons.map_outlined),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: const InputDecoration(labelText: "Vai trò hệ thống", border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'owner', child: Text("CHỦ SHOP")),
              DropdownMenuItem(value: 'manager', child: Text("QUẢN LÝ")),
              DropdownMenuItem(value: 'employee', child: Text("NHÂN VIÊN")),
              DropdownMenuItem(value: 'technician', child: Text("KỸ THUẬT")),
              DropdownMenuItem(value: 'user', child: Text("TÀI KHOẢN CŨ (User)")),
              DropdownMenuItem(value: 'admin', child: Text("QUẢN TRỊ (Admin)")),
            ],
            onChanged: (v) => setState(() => _selectedRole = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildPermTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Align(alignment: Alignment.centerLeft, child: Text("PHÂN QUYỀN NỘI DUNG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange))),
          _switch("Xem Bán hàng", _vSales, (v) => setState(() => _vSales = v)),
          _switch("Xem Sửa chữa", _vRepairs, (v) => setState(() => _vRepairs = v)),
          _switch("Xem Kho hàng", _vInv, (v) => setState(() => _vInv = v)),
          _switch("Xem Linh kiện", _vParts, (v) => setState(() => _vParts = v)),
          _switch("Xem Nhà cung cấp", _vSup, (v) => setState(() => _vSup = v)),
          _switch("Xem Khách hàng", _vCust, (v) => setState(() => _vCust = v)),
          _switch("Xem Bảo hành", _vWar, (v) => setState(() => _vWar = v)),
          _switch("Dùng Chat nội bộ", _vChat, (v) => setState(() => _vChat = v)),
          _switch("Dùng Máy in", _vPrint, (v) => setState(() => _vPrint = v)),
          const Divider(),
          const Align(alignment: Alignment.centerLeft, child: Text("DỮ LIỆU NHẠY CẢM", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.red))),
          _switch("Xem Doanh thu / Lời lỗ", _vRev, (v) => setState(() => _vRev = v)),
          _switch("Xem & Quản lý Chi phí", _vExp, (v) => setState(() => _vExp = v)),
          _switch("Xem & Quản lý Công nợ", _vDebts, (v) => setState(() => _vDebts = v)),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    if (_loadingAttendance) return const Center(child: CircularProgressIndicator());
    if (_attendanceHistory.isEmpty) return const Center(child: Text("Chưa có lịch sử chấm công", style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _attendanceHistory.length,
      itemBuilder: (ctx, i) {
        final a = _attendanceHistory[i];
        final checkIn = DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(a['checkInAt']));
        final checkOut = a['checkOutAt'] != null ? DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(a['checkOutAt'])) : "--:--";
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(Icons.event_available, color: Colors.green),
            title: Text(a['dateKey'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Vào: $checkIn - Ra: $checkOut"),
            trailing: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(5)), child: const Text("HỢP LỆ", style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold))),
          ),
        );
      },
    );
  }

  Widget _input(TextEditingController c, String l, IconData i, {TextInputType type = TextInputType.text}) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: TextField(controller: c, keyboardType: type, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))));
  Widget _switch(String l, bool v, Function(bool) o) => SwitchListTile(title: Text(l, style: const TextStyle(fontSize: 13)), value: v, onChanged: o, dense: true, contentPadding: EdgeInsets.zero);
}
