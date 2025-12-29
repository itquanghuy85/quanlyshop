import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';
import 'repair_detail_view.dart';

class CustomerListView extends StatefulWidget {
  final String role;
  const CustomerListView({super.key, this.role = 'user'});

  @override
  State<CustomerListView> createState() => _CustomerListViewState();
}

class _CustomerListViewState extends State<CustomerListView> {
  final db = DBHelper();
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  bool _showUnassignedOnly = false; // Thêm biến này
  
  // Multi-select state
  bool _isSelectionMode = false;
  Set<int> _selectedIndices = {};
  bool _isDeleting = false;

  // Theme colors cho màn hình quản lý khách hàng
  final Color _primaryColor = Colors.pink; // Màu hồng cho customer management
  final Color _accentColor = Colors.pink.shade600;
  final Color _backgroundColor = const Color(0xFFF8FAFF);

  @override
  void initState() {
    super.initState();
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

    // Lấy toàn bộ repairs và sales
    final allRepairs = await db.getAllRepairs();
    final allSales = await db.getAllSales();

    // Map<phone, customer info>
    final Map<String, Map<String, dynamic>> customerMap = {};

    // Gộp từ repairs
    for (var r in allRepairs) {
      final phone = r.phone;
      if (phone.isNotEmpty) {
        final key = phone;
        customerMap.putIfAbsent(key, () => {
          'customerName': r.customerName,
          'phone': phone,
          'address': r.address,
          'totalSpent': 0,
          'repairCount': 0,
          'saleCount': 0,
        });
        customerMap[key]!['totalSpent'] = (customerMap[key]!['totalSpent'] as int) + r.price;
        customerMap[key]!['repairCount'] = (customerMap[key]!['repairCount'] as int) + 1;
      }
    }

    // Gộp từ sales
    for (var s in allSales) {
      final phone = s.phone;
      if (phone.isNotEmpty) {
        final key = phone;
        customerMap.putIfAbsent(key, () => {
          'customerName': s.customerName,
          'phone': phone,
          'address': s.address,
          'totalSpent': 0,
          'repairCount': 0,
          'saleCount': 0,
        });
        customerMap[key]!['totalSpent'] = (customerMap[key]!['totalSpent'] as int) + s.totalPrice;
        customerMap[key]!['saleCount'] = (customerMap[key]!['saleCount'] as int) + 1;
      }
    }

    // Nếu lọc khách chưa gán shop, chỉ lấy từ bảng customers chưa có shopId
    List<Map<String, dynamic>> result;
    if (_showUnassignedOnly) {
      final unassigned = await db.getCustomersWithoutShop();
      // Chỉ lấy những khách chưa gán shop có trong customerMap
      result = unassigned.where((c) => customerMap.containsKey(c['phone'])).map((c) {
        final merged = Map<String, dynamic>.from(customerMap[c['phone']]!);
        merged['customerName'] = c['customerName'] ?? merged['customerName'];
        merged['address'] = c['address'] ?? merged['address'];
        return merged;
      }).toList();
    } else {
      result = customerMap.values.toList();
    }

    // Sắp xếp theo tên khách hàng
    result.sort((a, b) => (a['customerName'] ?? '').toString().compareTo((b['customerName'] ?? '').toString()));

    setState(() {
      _customers = result;
      _isLoading = false;
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _startSelection(int index) {
    setState(() {
      _isSelectionMode = true;
      _selectedIndices.add(index);
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
  }

  Future<void> _deleteSelectedCustomers() async {
    if (_selectedIndices.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);

    // Xác thực mật khẩu admin
    final password = await _showPasswordDialog();
    if (password == null || password.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Re-authenticate với mật khẩu
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: password,
      );
      await currentUser.reauthenticateWithCredential(credential);
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Mật khẩu không đúng!"))
      );
      return;
    }

    setState(() => _isDeleting = true);

    try {
      final selectedCustomers = _selectedIndices.map((i) => _customers[i]).toList();
      
      for (final customer in selectedCustomers) {
        // Xóa tất cả repairs và sales của customer này
        await db.deleteCustomerData(customer['customerName'], customer['phone']);
      }

      await _refresh();
      _cancelSelection();

      messenger.showSnackBar(
        SnackBar(content: Text("Đã xóa ${selectedCustomers.length} khách hàng"))
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Lỗi khi xóa: $e"))
      );
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  Future<String?> _showPasswordDialog() async {
    String password = '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận xóa"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Nhập mật khẩu tài khoản chủ shop để xóa:"),
            const SizedBox(height: 10),
            TextField(
              obscureText: true,
              onChanged: (value) => password = value,
              decoration: const InputDecoration(
                hintText: "Mật khẩu",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, password),
            child: const Text("Xác nhận"),
          ),
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
        title: Text(
          _isSelectionMode 
            ? "Đã chọn ${_selectedIndices.length} khách hàng"
            : _showUnassignedOnly 
              ? "KHÁCH HÀNG CHƯA GÁN SHOP (${_customers.length})"
              : "HỆ THỐNG KHÁCH HÀNG (${_customers.length})", 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        ),
        actions: _isSelectionMode ? [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _cancelSelection,
            tooltip: "Hủy chọn",
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              onPressed: _isDeleting ? null : _deleteSelectedCustomers,
              tooltip: "Xóa các khách đã chọn",
            ),
        ] : [
          IconButton(
            icon: Icon(_showUnassignedOnly ? Icons.group : Icons.group_off, color: Colors.white),
            onPressed: () {
              setState(() => _showUnassignedOnly = !_showUnassignedOnly);
              _refresh();
            },
            tooltip: _showUnassignedOnly ? "Xem tất cả khách hàng" : "Xem khách chưa gán shop",
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _customers.isEmpty
          ? const Center(child: Text("Chưa có dữ liệu khách hàng"))
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _customers.length,
              itemBuilder: (ctx, i) {
                final c = _customers[i];
                return _customerCard(c, i);
              },
            ),
    );
  }

  Widget _customerCard(Map<String, dynamic> c, int index) {
    final bool canDelete = _isAdmin && (c['repairCount'] as int? ?? 0) == 0 && (c['saleCount'] as int? ?? 0) == 0;
    final bool isSelected = _selectedIndices.contains(index);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: isSelected ? Colors.blue.shade50 : null,
      child: InkWell(
        onTap: _isSelectionMode 
          ? () => _toggleSelection(index)
          : () => _showCustomerFullHistory(c),
        onLongPress: _isSelectionMode 
          ? null 
          : () => _startSelection(index),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_isSelectionMode)
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) => _toggleSelection(index),
                    ),
                  Expanded(
                    child: Text(
                      "${c['customerName']}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 15, 
                        color: isSelected ? Colors.blue : Colors.blueAccent
                      ),
                    ),
                  ),
                  if (!_isSelectionMode && canDelete)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      tooltip: "Xóa khách khỏi danh sách",
                      onPressed: () => _confirmDeleteCustomer(c),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${NumberFormat('#,###').format(c['totalSpent'] ?? 0)} đ",
                      style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text("SĐT: ${c['phone']}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
              if ((c['address'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    "Địa chỉ: ${c['address']}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              const Divider(height: 20),
              Row(
                children: [
                  _miniStat(Icons.build_circle_outlined, "${c['repairCount'] ?? 0} lần sửa", Colors.blue),
                  const SizedBox(width: 20),
                  _miniStat(Icons.shopping_bag_outlined, "${c['saleCount'] ?? 0} máy đã mua", Colors.pink),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _showCustomerFullHistory(Map<String, dynamic> c) async {
    final allRepairs = await db.getAllRepairs();
    final allSales = await db.getAllSales();
    
    final repairHistory = allRepairs.where((r) => r.phone == c['phone']).toList();
    final saleHistory = allSales.where((s) => s.phone == c['phone']).toList();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(c['customerName'].toString().toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Tổng chi tiêu: ${NumberFormat('#,###').format(c['totalSpent'] ?? 0)} đ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Colors.blueAccent,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.blueAccent,
                      tabs: [
                        Tab(text: "LỊCH SỬ SỬA MÁY"),
                        Tab(text: "MÁY ĐÃ MUA"),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildRepairHistoryList(repairHistory),
                          _buildSaleHistoryList(saleHistory),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepairHistoryList(List<Repair> list) {
    if (list.isEmpty) return const Center(child: Text("Chưa có lịch sử sửa chữa"));
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final r = list[i];
        return ListTile(
          title: Text(r.model, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text("Lỗi: ${r.issue.split('|').first}\nNgày: ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(r.createdAt))}"),
          trailing: Text("${NumberFormat('#,###').format(r.price)} đ", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          onTap: () {
            Navigator.pop(ctx);
            Navigator.push(context, MaterialPageRoute(builder: (_) => RepairDetailView(repair: r)));
          },
        );
      },
    );
  }

  Widget _buildSaleHistoryList(List<SaleOrder> list) {
    if (list.isEmpty) return const Center(child: Text("Chưa có máy đã mua"));
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final s = list[i];
        return ListTile(
          leading: const Icon(Icons.phone_iphone, color: Colors.pink),
          title: Text(s.productNames, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text("IMEI: ${s.productImeis}\nNgày mua: ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(s.soldAt))}"),
          trailing: Text("${NumberFormat('#,###').format(s.totalPrice)} đ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Future<void> _confirmDeleteCustomer(Map<String, dynamic> c) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ tài khoản QUẢN LÝ mới được xóa khách hàng khỏi danh sách')),
      );
      return;
    }

    final hasHistory = (c['repairCount'] as int? ?? 0) > 0 || (c['saleCount'] as int? ?? 0) > 0;
    if (hasHistory) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xóa khách đã có lịch sử sửa/bán.')), 
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÓA KHÁCH HÀNG"),
        content: Text(
          "Bạn chắc chắn muốn xóa khách ${c['customerName']} (${c['phone']}) khỏi danh sách? Hành động này chỉ xóa khỏi DANH BẠ, không xóa lịch sử sửa/bán.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("XÓA")),
        ],
      ),
    );

    if (ok == true) {
      final firestoreId = c['firestoreId'] as String?;
      if (firestoreId != null) {
        await FirestoreService.deleteCustomer(firestoreId);
      }
      await db.deleteCustomerByPhone(c['phone'] as String);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ĐÃ XÓA KHÁCH KHỎI DANH BẠ')), 
      );
      _refresh();
    }
  }
}
