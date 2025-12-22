import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';
import 'repair_detail_view.dart';
import 'sale_detail_view.dart';

class WarrantyView extends StatefulWidget {
  const WarrantyView({super.key});
  @override
  State<WarrantyView> createState() => _WarrantyViewState();
}

class _WarrantyViewState extends State<WarrantyView> {
  final db = DBHelper();
  List<Map<String, dynamic>> _warrantyList = []; // Chứa cả Repair và SaleOrder
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _loadAllWarranty();
  }

  Future<void> _loadRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() {
      _isAdmin = perms['allowViewWarranty'] ?? false;
    });
  }

  Future<void> _loadAllWarranty() async {
    setState(() => _isLoading = true);
    final repairs = await db.getAllRepairs();
    final sales = await db.getAllSales();
    final now = DateTime.now();
    
    List<Map<String, dynamic>> results = [];

    // 1. Xử lý bảo hành máy SỬA (chỉ tính máy đã giao và có bảo hành)
    for (var r in repairs) {
      if (r.deliveredAt != null && r.warranty != "KO") {
        int months = int.tryParse(r.warranty.split(' ').first) ?? 0;
        if (months > 0) {
          DateTime delDate = DateTime.fromMillisecondsSinceEpoch(r.deliveredAt!);
          DateTime expDate = DateTime(delDate.year, delDate.month + months, delDate.day);
          if (expDate.isAfter(now)) {
            results.add({
              'type': 'REPAIR',
              'title': "${r.customerName} - ${r.model}",
              'expiry': expDate,
              'data': r,
            });
          }
        }
      }
    }

    // 2. Xử lý bảo hành máy BÁN
    for (var s in sales) {
      // Giả sử bảo hành máy bán được lưu trong notes hoặc mặc định 12 tháng nếu không ghi
      // Hiện tại ta lấy mặc định 12 tháng cho máy bán nếu có ghi chú trả góp/bảo hành
      DateTime saleDate = DateTime.fromMillisecondsSinceEpoch(s.soldAt);
      DateTime expDate = DateTime(saleDate.year + 1, saleDate.month, saleDate.day); // Mặc định 1 năm
      
      if (expDate.isAfter(now)) {
        results.add({
          'type': 'SALE',
          'title': "${s.customerName} - ${s.productNames}",
          'expiry': expDate,
          'data': s,
        });
      }
    }

    // Sắp xếp theo ngày hết hạn gần nhất lên đầu
    results.sort((a, b) => (a['expiry'] as DateTime).compareTo(b['expiry'] as DateTime));

    setState(() {
      _warrantyList = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(title: const Text("QUẢN LÝ BẢO HÀNH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _warrantyList.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.verified_user_outlined, size: 80, color: Colors.grey[300]), const SizedBox(height: 10), const Text("Không có máy nào trong hạn bảo hành", style: TextStyle(color: Colors.grey))]))
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _warrantyList.length,
              itemBuilder: (ctx, i) {
                final item = _warrantyList[i];
                final bool isSale = item['type'] == 'SALE';
                final DateTime expDate = item['expiry'];
                final int daysLeft = expDate.difference(DateTime.now()).inDays;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      backgroundColor: isSale ? Colors.pink.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      child: Icon(isSale ? Icons.shopping_bag : Icons.build, color: isSale ? Colors.pink : Colors.orange, size: 20),
                    ),
                    title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Hết hạn: ${DateFormat('dd/MM/yyyy').format(expDate)}", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                        Text("Còn lại: $daysLeft ngày", style: TextStyle(fontSize: 11, color: daysLeft < 7 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isAdmin)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            tooltip: "Gỡ khỏi danh sách bảo hành",
                            onPressed: () => _confirmRemoveWarranty(item),
                          ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () {
                      if (isSale) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailView(sale: item['data'] as SaleOrder)));
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => RepairDetailView(repair: item['data'] as Repair)));
                      }
                    },
                  ),
                );
              },
            ),
    );
  }

  Future<void> _confirmRemoveWarranty(Map<String, dynamic> item) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ tài khoản QUẢN LÝ mới được chỉnh sửa bảo hành')), 
      );
      return;
    }

    final bool isSale = item['type'] == 'SALE';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("GỠ KHỎI DANH SÁCH BẢO HÀNH"),
        content: Text(
          isSale
              ? "Bạn muốn kết thúc bảo hành cho đơn BÁN này? Máy sẽ không còn hiển thị trong danh sách bảo hành."
              : "Bạn muốn kết thúc bảo hành cho đơn SỬA này? Máy sẽ không còn hiển thị trong danh sách bảo hành.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("ĐỒNG Ý")),
        ],
      ),
    );

    if (ok == true) {
      if (isSale) {
        final s = item['data'] as SaleOrder;
        s.warranty = 'KO BH';
        await db.updateSale(s);
      } else {
        final r = item['data'] as Repair;
        r.warranty = 'KO BH';
        await db.updateRepair(r);
        await FirestoreService.upsertRepair(r);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ĐÃ GỠ MÁY KHỎI DANH SÁCH BẢO HÀNH')), 
      );
      _loadAllWarranty();
    }
  }
}
