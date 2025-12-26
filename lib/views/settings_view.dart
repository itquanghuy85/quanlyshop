import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../data/db_helper.dart';

class SettingsView extends StatefulWidget {
  final void Function(Locale)? setLocale;
  const SettingsView({super.key, this.setLocale});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  String _role = 'user';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final role = await UserService.getUserRole(user.uid);
      setState(() { _role = role; _loading = false; });
    }
  }

  // HÀM XỬ LÝ XÓA TRẮNG SHOP (BẢO MẬT TUYỆT ĐỐI)
  Future<void> _handleResetShop() async {
    final confirmTextC = TextEditingController();
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ CẢNH BÁO NGUY HIỂM", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Hành động này sẽ xóa sạch 100% dữ liệu Đơn hàng, Kho, Nợ và Nhật ký của Shop trên cả Đám mây và Máy này. KHÔNG THỂ KHÔI PHỤC!"),
            const SizedBox(height: 15),
            const Text("Nhập chữ 'XOA HET' để xác nhận:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            TextField(controller: confirmTextC, decoration: const InputDecoration(hintText: "XOA HET"), textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, confirmTextC.text.trim() == "XOA HET"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("XÁC NHẬN XÓA SẠCH", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );

    if (result == true) {
      setState(() => _loading = true);
      final successCloud = await FirestoreService.resetEntireShopData();
      await DBHelper().clearAllData();
      
      NotificationService.showSnackBar("ĐÃ XÓA SẠCH DỮ LIỆU SHOP!", color: Colors.green);
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("CÀI ĐẶT HỆ THỐNG")),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection("NGÔN NGỮ & GIAO DIỆN"),
          ListTile(
            leading: const Icon(Icons.language, color: Colors.blue),
            title: const Text("Ngôn ngữ ứng dụng"),
            trailing: const Text("Tiếng Việt"),
            onTap: () {
              if (widget.setLocale != null) widget.setLocale!(const Locale('vi'));
            },
          ),
          const Divider(),
          _buildSection("TÀI KHOẢN & BẢO MẬT"),
          ListTile(
            leading: const Icon(Icons.person_pin, color: Colors.teal),
            title: const Text("Vai trò của bạn"),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
              child: Text(_role.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.blue)),
            ),
          ),
          
          // NÚT XÓA TRẮNG CHỈ HIỆN CHO CHỦ SHOP
          if (_role == 'owner' || UserService.isCurrentUserSuperAdmin()) ...[
            const SizedBox(height: 30),
            _buildSection("QUẢN TRỊ NÂNG CAO"),
            Card(
              color: Colors.red.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.red.shade200)),
              child: ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text("XÓA TRẮNG DỮ LIỆU SHOP", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                subtitle: const Text("Dùng khi muốn khởi tạo lại toàn bộ dữ liệu cửa hàng", style: TextStyle(fontSize: 11)),
                onTap: _handleResetShop,
              ),
            ),
          ],
          
          const SizedBox(height: 50),
          Center(child: Text("Phiên bản 1.0.0+7", style: TextStyle(color: Colors.grey.shade400, fontSize: 10))),
        ],
      ),
    );
  }

  Widget _buildSection(String title) => Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)));
}
