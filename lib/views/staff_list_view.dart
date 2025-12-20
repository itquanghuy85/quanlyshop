import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/user_service.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import 'repair_detail_view.dart';
import 'sale_detail_view.dart';

class StaffListView extends StatefulWidget {
  const StaffListView({super.key});

  @override
  State<StaffListView> createState() => _StaffListViewState();
}

class _StaffListViewState extends State<StaffListView> {
  final db = DBHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(title: const Text("QUẢN LÝ NHÂN VIÊN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      body: StreamBuilder<QuerySnapshot>(
        stream: UserService.getAllUsersStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final users = snapshot.data!.docs;
          if (users.isEmpty) {
            return const Center(
              child: Text(
                "Chưa có dữ liệu nhân viên\nMỗi tài khoản sẽ tự xuất hiện sau khi đăng nhập",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: users.length,
            itemBuilder: (ctx, i) {
              final userData = users[i].data() as Map<String, dynamic>;
              final uid = users[i].id;
              final email = userData['email'] ?? "Chưa có email";
              final role = userData['role'] ?? 'user';
              final displayName = userData['displayName'] ?? email.split('@').first.toUpperCase();
              final phone = userData['phone'] ?? "Chưa có SĐT";
              final photoUrl = userData['photoUrl'];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: photoUrl != null ? FileImage(File(photoUrl)) : null,
                    backgroundColor: role == 'admin' ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                    child: photoUrl == null ? Icon(role == 'admin' ? Icons.admin_panel_settings : Icons.person, color: role == 'admin' ? Colors.red : Colors.blue) : null,
                  ),
                  title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text("$email\nSĐT: $phone", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  isThreeLine: true,
                  trailing: Icon(Icons.edit_note_rounded, color: Colors.blueAccent),
                  onTap: () => _showStaffActivityCenter(uid, displayName, email, role, userData),
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
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StaffActivityCenter(uid: uid, name: name, email: email, role: currentRole, fullData: fullData),
    );
  }
}

class _StaffActivityCenter extends StatefulWidget {
  final String uid, name, email, role;
  final Map<String, dynamic> fullData;
  const _StaffActivityCenter({required this.uid, required this.name, required this.email, required this.role, required this.fullData});

  @override
  State<_StaffActivityCenter> createState() => _StaffActivityCenterState();
}

class _StaffActivityCenterState extends State<_StaffActivityCenter> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final db = DBHelper();
  
  // Controllers cho phần chỉnh sửa thông tin
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  String? _photoPath;
  String _selectedRole = 'user';
  bool _isEditing = false;

  List<Repair> _repairsReceived = [];
  List<Repair> _repairsDelivered = [];
  List<SaleOrder> _sales = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Gán dữ liệu ban đầu
    nameCtrl.text = widget.fullData['displayName'] ?? widget.name;
    phoneCtrl.text = widget.fullData['phone'] ?? "";
    addressCtrl.text = widget.fullData['address'] ?? "";
    _photoPath = widget.fullData['photoUrl'];
    _selectedRole = widget.role;

    _loadAllStaffData();
  }

  Future<void> _loadAllStaffData() async {
    final allR = await db.getAllRepairs();
    final allS = await db.getAllSales();
    setState(() {
      _repairsReceived = allR.where((r) => r.createdBy?.toUpperCase() == widget.name).toList();
      _repairsDelivered = allR.where((r) => r.deliveredBy?.toUpperCase() == widget.name).toList();
      _sales = allS.where((s) => s.sellerName.toUpperCase() == widget.name).toList();
    });
  }

  Future<void> _pickPhoto() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (f != null) setState(() => _photoPath = f.path);
  }

  Future<void> _saveStaffInfo() async {
    await UserService.updateUserInfo(
      uid: widget.uid,
      name: nameCtrl.text,
      phone: phoneCtrl.text,
      address: addressCtrl.text,
      role: _selectedRole,
      photoUrl: _photoPath,
    );
    setState(() => _isEditing = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ĐÃ CẬP NHẬT HỒ SƠ NHÂN VIÊN!")));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _isEditing ? _pickPhoto : null,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage: _photoPath != null ? FileImage(File(_photoPath!)) : null,
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: _photoPath == null ? const Icon(Icons.camera_alt, color: Colors.blue) : null,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(widget.email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_isEditing ? Icons.check_circle : Icons.edit, color: _isEditing ? Colors.green : Colors.blue),
                  onPressed: () {
                    if (_isEditing) _saveStaffInfo();
                    else setState(() => _isEditing = true);
                  },
                )
              ],
            ),
          ),

          if (_isEditing) 
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _editInput(nameCtrl, "Họ và tên nhân viên", Icons.person_outline),
                  _editInput(phoneCtrl, "Số điện thoại liên hệ", Icons.phone_android_outlined, type: TextInputType.phone),
                  _editInput(addressCtrl, "Địa chỉ thường trú", Icons.location_on_outlined),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Quyền hệ thống:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: _selectedRole,
                        items: const [
                          DropdownMenuItem(value: 'user', child: Text("NHÂN VIÊN")),
                          DropdownMenuItem(value: 'admin', child: Text("QUẢN LÝ")),
                        ],
                        onChanged: (v) => setState(() => _selectedRole = v!),
                      ),
                    ],
                  ),
                  const Divider(),
                ],
              ),
            ),

          const SizedBox(height: 10),
          TabBar(
            controller: _tabController,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "ĐÃ NHẬN", icon: Icon(Icons.move_to_inbox_rounded, size: 20)),
              Tab(text: "ĐÃ GIAO", icon: Icon(Icons.outbox_rounded, size: 20)),
              Tab(text: "ĐÃ BÁN", icon: Icon(Icons.shopping_cart_checkout_rounded, size: 20)),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRepairList(_repairsReceived),
                _buildRepairList(_repairsDelivered),
                _buildSaleList(_sales),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editInput(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.all(10),
        ),
      ),
    );
  }

  Widget _buildRepairList(List<Repair> list) {
    if (list.isEmpty) return const Center(child: Text("Không có dữ liệu", style: TextStyle(color: Colors.grey, fontSize: 12)));
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: list.length,
      itemBuilder: (ctx, i) => ListTile(
        title: Text(list[i].model, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text("KH: ${list[i].customerName} | ${DateFormat('dd/MM').format(DateTime.fromMillisecondsSinceEpoch(list[i].createdAt))}"),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RepairDetailView(repair: list[i], role: 'admin'))),
      ),
    );
  }

  Widget _buildSaleList(List<SaleOrder> list) {
    if (list.isEmpty) return const Center(child: Text("Không có dữ liệu", style: TextStyle(color: Colors.grey, fontSize: 12)));
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: list.length,
      itemBuilder: (ctx, i) => ListTile(
        title: Text(list[i].productNames, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text("KH: ${list[i].customerName} | ${NumberFormat('#,###').format(list[i].totalPrice)} đ"),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailView(sale: list[i], role: 'admin'))),
      ),
    );
  }
}
