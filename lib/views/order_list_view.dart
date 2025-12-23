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

  // Multi-select mode
  bool _isMultiSelectMode = false;
  Set<int> _selectedIndices = {}; // Store indices of selected items

  // Theme colors cho màn hình danh sách đơn hàng
  final Color _primaryColor = Colors.teal; // Màu chính cho danh sách đơn hàng
  final Color _accentColor = Colors.teal.shade600;
  final Color _backgroundColor = const Color(0xFFF8FAFF);

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

  Future<void> _toggleCheckRepair(int index) async {
    final repair = _displayedRepairs[index];
    // Toggle status: nếu đang sửa (2) thì đánh dấu hoàn thành (3), nếu đã hoàn thành thì chuyển về đang sửa (2)
    final newStatus = repair.status == 2 ? 3 : 2;

    repair.status = newStatus;
    repair.isSynced = false;

    await db.upsertRepair(repair);
    await FirestoreService.upsertRepair(repair);

    setState(() {
      // Update local list
      _displayedRepairs[index] = repair;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(newStatus == 3 ? 'Đã đánh dấu hoàn thành' : 'Đã chuyển về đang sửa')),
    );
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
            const Text("Nhập mật khẩu tài khoản quản lý để xóa:"),
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
                await db.deleteRepair(r.id!);                if (r.firestoreId != null) await FirestoreService.deleteRepair(r.firestoreId!);                Navigator.pop(ctx);
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

  // Multi-select methods
  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedIndices.clear();
      }
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIndices.length == _displayedRepairs.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices = Set.from(List.generate(_displayedRepairs.length, (i) => i));
      }
    });
  }

  Future<void> _deleteSelectedRepairs() async {
    if (_selectedIndices.isEmpty || widget.role != 'admin') return;

    final selectedRepairs = _selectedIndices.map((i) => _displayedRepairs[i]).toList();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÁC NHẬN XÓA NHIỀU ĐƠN"),
        content: Text("Bạn có chắc muốn xóa ${_selectedIndices.length} đơn sửa chữa đã chọn?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("XÓA", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show password dialog for confirmation
    final passCtrl = TextEditingController();
    final passwordConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÁC NHẬN MẬT KHẨU"),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          decoration: const InputDecoration(hintText: "Nhập mật khẩu quản lý"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null || user.email == null) {
                Navigator.pop(ctx, false);
                return;
              }
              try {
                final cred = EmailAuthProvider.credential(email: user.email!, password: passCtrl.text);
                await user.reauthenticateWithCredential(cred);
                Navigator.pop(ctx, true);
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mật khẩu không đúng'))
                );
                Navigator.pop(ctx, false);
              }
            },
            child: const Text("XÁC NHẬN"),
          ),
        ],
      ),
    );

    if (passwordConfirmed != true) return;

    // Delete selected repairs
    try {
      for (var repair in selectedRepairs) {
        await db.deleteRepair(repair.id!);
        if (repair.firestoreId != null) {
          await FirestoreService.deleteRepair(repair.firestoreId!);
        }
      }
      
      setState(() {
        _selectedIndices.clear();
        _isMultiSelectMode = false;
      });
      
      _loadInitialData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ĐÃ XÓA ${_selectedIndices.length} ĐƠN SỬA'))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa: $e'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          _isMultiSelectMode ? "ĐÃ CHỌN ${_selectedIndices.length}" : "DANH SÁCH SỬA CHỮA",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        ),
        elevation: 0,
        leading: _isMultiSelectMode ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: _toggleMultiSelectMode,
          tooltip: 'Thoát chế độ chọn',
        ) : null,
        actions: [
          if (_isMultiSelectMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _selectAll,
              tooltip: _selectedIndices.length == _displayedRepairs.length ? 'Bỏ chọn tất cả' : 'Chọn tất cả',
            ),
            if (widget.role == 'admin' && _selectedIndices.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                onPressed: _deleteSelectedRepairs,
                tooltip: 'Xóa các đơn đã chọn',
              ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: _toggleMultiSelectMode,
              tooltip: 'Chế độ chọn nhiều',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: "Tìm máy, khách, SĐT...",
                prefixIcon: Icon(Icons.search, color: _primaryColor),
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
                    color: _isMultiSelectMode && _selectedIndices.contains(i) ? _primaryColor.withOpacity(0.1) : Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: ListTile(
                      onTap: _isMultiSelectMode 
                        ? () => _toggleSelection(i)
                        : () async {
                            final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => RepairDetailView(repair: r)));
                            if (res == true) _loadInitialData();
                          },
                      onLongPress: _isMultiSelectMode ? null : () => _toggleCheckRepair(i),
                      leading: _isMultiSelectMode
                        ? Checkbox(
                            value: _selectedIndices.contains(i),
                            onChanged: (bool? value) => _toggleSelection(i),
                            activeColor: _primaryColor,
                          )
                        : Container(
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_fmtDate(r.createdAt), style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                          if (widget.role == 'admin' && !_isMultiSelectMode) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                              onPressed: () => _confirmDelete(r),
                              tooltip: 'Xóa đơn sửa',
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _isMultiSelectMode ? null : FloatingActionButton.extended(
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
