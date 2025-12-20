import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
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
    if (_useFilter) {
      final all = await db.getAllRepairs();
      setState(() {
        _displayedRepairs = _applyFilters(all);
      });
    } else {
      await _loadMoreData();
    }
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

  bool _isSameDay(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  List<Repair> _applyFilters(List<Repair> list) {
    return list.where((r) {
      if (widget.statusFilter != null && !widget.statusFilter!.contains(r.status)) return false;
      if (widget.todayOnly) {
        final baseTime = r.deliveredAt ?? r.finishedAt ?? r.createdAt;
        if (!_isSameDay(baseTime)) return false;
      }
      return true;
    }).toList();
  }

  void _confirmDelete(Repair r) {
    if (widget.role != 'admin') return;
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÁC NHẬN XÓA ĐƠN"),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          decoration: const InputDecoration(hintText: "Nhập lại mật khẩu tài khoản quản lý"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null || user.email == null) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không xác định được tài khoản hiện tại')));
                return;
              }
              try {
                final cred = EmailAuthProvider.credential(email: user.email!, password: passCtrl.text);
                await user.reauthenticateWithCredential(cred);
                await db.deleteRepair(r.id!);
                Navigator.pop(ctx);
                _loadInitialData();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ĐÃ XÓA ĐƠN SỬA')));
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu không đúng')));
              }
            },
            child: const Text("XÓA"),
          ),
        ],
      ),
    );
  }

  String _fmtDate(int ms) => DateFormat('dd/MM').format(DateTime.fromMillisecondsSinceEpoch(ms));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
                hintText: "Tìm máy, khách, SĐT...", 
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent), 
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
                itemCount: _displayedRepairs.length + (_hasMore ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == _displayedRepairs.length) return const Center(child: CircularProgressIndicator());
                  final r = _displayedRepairs[i];
                  final bool isDone = r.status >= 3; // 3: SỬA XONG, 4: ĐÃ GIAO

                  String statusText;
                  if (r.status == 1 || r.status == 2) {
                    statusText = "ĐANG SỬA";
                  } else if (r.status == 3) {
                    statusText = "SỬA XONG";
                  } else {
                    statusText = "ĐÃ GIAO";
                  }

                  return Card(
                    elevation: 2,
                    color: Colors.white, // Nền luôn trắng để nổi bật
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: ListTile(
                      onTap: () async {
                        final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => RepairDetailView(repair: r, role: widget.role)));
                        if (res == true) _loadInitialData();
                      },
                      onLongPress: () => _confirmDelete(r),
                      leading: Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          color: isDone ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), 
                          borderRadius: BorderRadius.circular(10)
                        ),
                        child: Icon(isDone ? Icons.check_circle : Icons.build_circle, color: isDone ? Colors.green : Colors.orange),
                      ),
                      title: Text("${r.customerName} - ${r.model}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Lỗi: ${r.issue.split('|').first}", maxLines: 1, style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: isDone ? Colors.green : Colors.orange, borderRadius: BorderRadius.circular(5)),
                            child: Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      trailing: Text(_fmtDate(r.createdAt), style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
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
