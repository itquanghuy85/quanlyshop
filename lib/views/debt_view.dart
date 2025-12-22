import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../services/user_service.dart';

class DebtView extends StatefulWidget {
  const DebtView({super.key});

  @override
  State<DebtView> createState() => _DebtViewState();
}

class _DebtViewState extends State<DebtView> with SingleTickerProviderStateMixin {
  final db = DBHelper();
  late TabController _tabController;
  List<Map<String, dynamic>> _debts = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  // Theme colors cho màn hình quản lý nợ
  final Color _primaryColor = Colors.red; // Màu đỏ cho debt management
  final Color _accentColor = Colors.red.shade600;
  final Color _backgroundColor = const Color(0xFFF8FAFF);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRole();
    _refresh();
  }

  Future<void> _loadRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final role = await UserService.getUserRole(uid);
    if (!mounted) return;
    setState(() {
      _isAdmin = role == 'admin';
    });
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final data = await db.getAllDebts();
    setState(() {
      _debts = data;
      _isLoading = false;
    });
  }

  void _addDebt() {
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    String type = 'CUSTOMER';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("TẠO KHOẢN NỢ MỚI"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'CUSTOMER', child: Text("KHÁCH NỢ SHOP")),
                  DropdownMenuItem(value: 'SUPPLIER', child: Text("SHOP NỢ NCC")),
                ],
                onChanged: (v) => type = v!,
              ),
              TextField(controller: nameC, decoration: const InputDecoration(labelText: "Họ và tên"), textCapitalization: TextCapitalization.characters),
              TextField(controller: phoneC, decoration: const InputDecoration(labelText: "Số điện thoại"), keyboardType: TextInputType.phone),
              TextField(controller: amountC, decoration: const InputDecoration(labelText: "Tổng số tiền nợ", suffixText: ".000 đ"), keyboardType: TextInputType.number),
              TextField(controller: noteC, decoration: const InputDecoration(labelText: "Lý do nợ")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
          ElevatedButton(onPressed: () async {
            if (nameC.text.isEmpty || amountC.text.isEmpty) return;
            await db.insertDebt({
              'personName': nameC.text.toUpperCase(),
              'phone': phoneC.text,
              'totalAmount': (int.tryParse(amountC.text) ?? 0) * 1000,
              'type': type,
              'status': 'NỢ',
              'createdAt': DateTime.now().millisecondsSinceEpoch,
              'note': noteC.text,
            });
            if (!mounted) return;
            Navigator.pop(ctx);
            _refresh();
          }, child: const Text("LƯU SỔ")),
        ],
      ),
    );
  }

  void _payDebt(Map<String, dynamic> debt) {
    final payC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("CẬP NHẬT TRẢ NỢ"),
        content: TextField(controller: payC, decoration: const InputDecoration(labelText: "Số tiền trả thêm", suffixText: ".000 đ"), keyboardType: TextInputType.number, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
          ElevatedButton(onPressed: () async {
            await db.updateDebtPaid(debt['id'], (int.tryParse(payC.text) ?? 0) * 1000);
            if (!mounted) return;
            Navigator.pop(ctx);
            _refresh();
          }, child: const Text("XÁC NHẬN")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        title: const Text("SỔ CÔNG NỢ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: "KHÁCH NỢ"), Tab(text: "NỢ NCC")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDebtList('CUSTOMER'),
          _buildDebtList('SUPPLIER'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDebt,
        backgroundColor: _accentColor,
        child: const Icon(Icons.note_add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildDebtList(String type) {
    final list = _debts.where((d) => d['type'] == type).toList();
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (list.isEmpty) return const Center(child: Text("Không có dữ liệu nợ"));

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final d = list[i];
        final remaining = d['totalAmount'] - d['paidAmount'];
        final isPaid = d['status'] == 'ĐÃ TRẢ';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            title: Text(d['personName'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Tổng nợ: ${NumberFormat('#,###').format(d['totalAmount'])} đ"),
                Text("Đã trả: ${NumberFormat('#,###').format(d['paidAmount'])} đ", style: const TextStyle(color: Colors.green, fontSize: 11)),
                if (remaining > 0) Text("CÒN LẠI: ${NumberFormat('#,###').format(remaining)} đ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            trailing: isPaid 
              ? const Icon(Icons.check_circle, color: Colors.green)
              : ElevatedButton(
                  onPressed: () => _payDebt(d),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10)),
                  child: const Text("TRẢ NỢ", style: TextStyle(fontSize: 10)),
                ),
            onLongPress: () async {
              _confirmDeleteDebt(d);
            },
          ),
        );
      },
    );
  }

  void _confirmDeleteDebt(Map<String, dynamic> d) {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chỉ tài khoản quản lý mới được xóa sổ nợ')));
      return;
    }
    final passC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÓA KHOẢN NỢ"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Bạn muốn xóa nợ của ${d['personName']}?"),
            const SizedBox(height: 15),
            TextField(
              controller: passC,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "Nhập lại mật khẩu tài khoản quản lý",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null || user.email == null) {
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không xác định được tài khoản hiện tại')));
                return;
              }
              try {
                final cred = EmailAuthProvider.credential(email: user.email!, password: passC.text);
                await user.reauthenticateWithCredential(cred);
                await db.deleteDebt(d['id']);
                if (!mounted) return;
                Navigator.pop(ctx);
                _refresh();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ĐÃ XÓA SỔ NỢ')));
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu không đúng')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("XÓA NGAY"),
          )
        ],
      ),
    );
  }
}
