import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../services/firestore_service.dart';
import 'repair_detail_view.dart';
import 'create_repair_order_view.dart';

class OrderListView extends StatefulWidget {
  final int? initialStatus;
  final bool todayOnly;
  final List<int>? statusFilter;
  final String role; 
  const OrderListView({super.key, this.initialStatus, this.todayOnly = false, this.statusFilter, this.role = 'user'});

  @override
  State<OrderListView> createState() => OrderListViewState();
}

class OrderListViewState extends State<OrderListView> {
  final db = DBHelper();
  final ScrollController _scrollController = ScrollController();
  
  List<Repair> _displayedRepairs = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  final int _pageSize = 20;
  
  String _currentSearch = "";
  bool get _useFilter => widget.statusFilter != null || widget.todayOnly;

  // Quyền xóa dành cho Admin và Chủ shop
  bool get canDelete => widget.role == 'admin' || widget.role == 'owner';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMore && _currentSearch.isEmpty) {
          _loadMoreData();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _currentOffset = 0;
      _displayedRepairs = [];
      _hasMore = !_useFilter;
    });
    final all = await db.getAllRepairs();
    setState(() {
      _displayedRepairs = _applyFilters(all);
    });
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || _useFilter) return;
    setState(() => _isLoadingMore = true);
    final newData = await db.getRepairsPaged(_pageSize, _currentOffset);
    setState(() {
      _currentOffset += _pageSize;
      _displayedRepairs.addAll(newData);
      _isLoadingMore = false;
      if (newData.length < _pageSize) _hasMore = false;
    });
  }

  void _onSearch(String val) async {
    setState(() => _currentSearch = val);
    if (val.isEmpty) {
      _loadInitialData();
    } else {
      final all = await db.getAllRepairs();
      setState(() {
        final filtered = _applyFilters(all);
        _displayedRepairs = filtered.where((r) => 
          r.customerName.toLowerCase().contains(val.toLowerCase()) || 
          r.phone.contains(val) || 
          r.model.toLowerCase().contains(val.toLowerCase())
        ).toList();
        _hasMore = false;
      });
    }
  }

  List<Repair> _applyFilters(List<Repair> list) {
    return list.where((r) {
      if (widget.statusFilter != null && !widget.statusFilter!.contains(r.status)) return false;
      if (widget.todayOnly) {
        final d = DateTime.fromMillisecondsSinceEpoch(r.createdAt);
        final now = DateTime.now();
        if (!(d.year == now.year && d.month == now.month && d.day == now.day)) return false;
      }
      return true;
    }).toList();
  }

  void _confirmDelete(Repair r) {
    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("BẠN KHÔNG CÓ QUYỀN XÓA ĐƠN")));
      return;
    }
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÁC NHẬN XÓA ĐƠN"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Xóa đơn của khách: ${r.customerName}"),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(hintText: "Nhập lại mật khẩu để xác nhận"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null || user.email == null) return;
              try {
                final cred = EmailAuthProvider.credential(email: user.email!, password: passCtrl.text);
                await user.reauthenticateWithCredential(cred);
                
                await db.deleteRepairByFirestoreId(r.firestoreId ?? "");
                if (r.firestoreId != null) await FirestoreService.deleteRepair(r.firestoreId!);
                
                Navigator.pop(ctx);
                _loadInitialData();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ĐÃ XÓA ĐƠN THÀNH CÔNG')));
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu không chính xác')));
              }
            },
            child: const Text("XÓA VĨNH VIỄN", style: TextStyle(color: Colors.white)),
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
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        title: const Text("DANH SÁCH SỬA CHỮA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: "Tìm khách, model, SĐT...",
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                filled: true, fillColor: Colors.white
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadInitialData,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _displayedRepairs.length,
                itemBuilder: (ctx, i) {
                  final r = _displayedRepairs[i];
                  return Dismissible(
                    key: Key(r.id.toString() + r.createdAt.toString()),
                    direction: canDelete ? DismissDirection.endToStart : DismissDirection.none,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(15)),
                      child: const Icon(Icons.delete_forever, color: Colors.white, size: 30),
                    ),
                    confirmDismiss: (dir) async {
                      _confirmDelete(r);
                      return false; // Không xóa ngay, đợi confirm từ dialog
                    },
                    child: Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        onTap: () async {
                          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => RepairDetailView(repair: r)));
                          if (res == true) _loadInitialData();
                        },
                        leading: CircleAvatar(
                          backgroundColor: r.status >= 3 ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                          child: Icon(r.status >= 3 ? Icons.check_circle : Icons.build_circle, color: r.status >= 3 ? Colors.green : Colors.orange),
                        ),
                        title: Text("${r.customerName} - ${r.model}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text("Lỗi: ${r.issue.split('|').first}", maxLines: 1, style: const TextStyle(fontSize: 12)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(DateFormat('dd/MM').format(DateTime.fromMillisecondsSinceEpoch(r.createdAt)), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            if (canDelete) const Icon(Icons.swipe_left, size: 14, color: Colors.redAccent),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => CreateRepairOrderView(role: widget.role)));
          if (res == true) _loadInitialData();
        },
        label: const Text("NHẬN MÁY"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}
