import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../services/firestore_service.dart';
import 'repair_detail_view.dart';
import 'create_repair_order_view.dart';
import 'global_search_view.dart';

class OrderListView extends StatefulWidget {
  final int? initialStatus;
  final bool todayOnly;
  final List<int>? statusFilter;
  final String role;
  const OrderListView({
    super.key,
    this.initialStatus,
    this.todayOnly = false,
    this.statusFilter,
    this.role = 'user',
  });

  @override
  State<OrderListView> createState() => OrderListViewState();
}

class OrderListViewState extends State<OrderListView> {
  final db = DBHelper();
  final ScrollController _scrollController = ScrollController();

  List<Repair> _displayedRepairs = [];
  bool _isLoading = true;

  bool get canDelete => widget.role == 'admin' || widget.role == 'owner';

  @override
  void initState() {
    super.initState();
    debugPrint(
      'OrderListView: initState - statusFilter: ${widget.statusFilter}, todayOnly: ${widget.todayOnly}, role: ${widget.role}',
    );
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final all = await db.getAllRepairs();
    debugPrint('OrderListView: Loaded ${all.length} repairs from DB');
    if (!mounted) return;
    final filtered = _applyFilters(all);
    debugPrint('OrderListView: After filtering: ${filtered.length} repairs');
    setState(() {
      _displayedRepairs = filtered;
      _isLoading = false;
    });
  }

  void _onSearch(String val) async {
    final all = await db.getAllRepairs();
    debugPrint(
      'OrderListView: _onSearch called with val: "$val", total repairs: ${all.length}',
    );
    setState(() {
      final filtered = _applyFilters(all);
      if (val.isEmpty) {
        _displayedRepairs = filtered;
        debugPrint(
          'OrderListView: Search empty, showing ${filtered.length} repairs',
        );
      } else {
        final searched = filtered
            .where(
              (r) =>
                  r.customerName.toLowerCase().contains(val.toLowerCase()) ||
                  r.phone.contains(val) ||
                  r.model.toLowerCase().contains(val.toLowerCase()),
            )
            .toList();
        _displayedRepairs = searched;
        debugPrint(
          'OrderListView: Search "$val" found ${searched.length} repairs',
        );
      }
    });
  }

  List<Repair> _applyFilters(List<Repair> list) {
    debugPrint('OrderListView: Applying filters to ${list.length} repairs');
    debugPrint(
      'OrderListView: statusFilter: ${widget.statusFilter}, todayOnly: ${widget.todayOnly}',
    );

    final filtered = list.where((r) {
      if (widget.statusFilter != null &&
          !widget.statusFilter!.contains(r.status)) {
        debugPrint(
          'OrderListView: Repair ${r.firestoreId} filtered out by status (status: ${r.status})',
        );
        return false;
      }
      if (widget.todayOnly) {
        final d = DateTime.fromMillisecondsSinceEpoch(r.createdAt);
        final now = DateTime.now();
        if (!(d.year == now.year && d.month == now.month && d.day == now.day)) {
          debugPrint(
            'OrderListView: Repair ${r.firestoreId} filtered out by date (created: ${d.toString()})',
          );
          return false;
        }
      }
      return true;
    }).toList();

    debugPrint(
      'OrderListView: After filtering: ${filtered.length} repairs remain',
    );
    return filtered;
  }

  void _confirmDelete(Repair r) {
    if (!canDelete) return;
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÁC NHẬN XÓA ĐƠN"),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          decoration: const InputDecoration(hintText: "Nhập mật khẩu quản lý"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("HỦY"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final user = FirebaseAuth.instance.currentUser;
              if (user == null || user.email == null) return;
              try {
                final navigator = Navigator.of(ctx);
                final cred = EmailAuthProvider.credential(
                  email: user.email!,
                  password: passCtrl.text,
                );
                await user.reauthenticateWithCredential(cred);
                await db.deleteRepairByFirestoreId(r.firestoreId ?? "");
                if (r.firestoreId != null) {
                  await FirestoreService.deleteRepair(r.firestoreId!);
                }
                navigator.pop();
                _loadInitialData();
                messenger.showSnackBar(
                  const SnackBar(content: Text('ĐÃ XÓA THÀNH CÔNG')),
                );
              } catch (_) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Mật khẩu sai')),
                );
              }
            },
            child: const Text("XÓA", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "DANH SÁCH MÁY SỬA",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GlobalSearchView(role: widget.role),
              ),
            ),
            icon: Icon(Icons.search, color: colorScheme.primary),
            tooltip: 'Tìm kiếm toàn app',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(15),
            ),
            child: TextField(
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: "Tìm khách, model, SĐT...",
                prefixIcon: const Icon(Icons.search),
                filled: false,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadInitialData,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _displayedRepairs.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) =>
                          _buildRepairCard(_displayedRepairs[i]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateRepairOrderView(role: widget.role),
            ),
          );
          debugPrint(
            'OrderListView: Returned from CreateRepairOrderView with result: $res',
          );
          if (res == true) {
            // Add small delay to ensure DB transaction completes
            await Future.delayed(const Duration(milliseconds: 500));
            debugPrint('OrderListView: Calling _loadInitialData after delay');
            _loadInitialData();
          }
        },
        label: const Text("NHẬN MÁY MỚI"),
        icon: const Icon(Icons.add_a_photo_rounded),
        backgroundColor: colorScheme.primary,
      ),
    );
  }

  Widget _buildRepairCard(Repair r) {
    return RepairListItem(
      repair: r,
      canDelete: canDelete,
      onTap: () async {
        final res = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RepairDetailView(repair: r)),
        );
        if (res == true) _loadInitialData();
      },
      onDelete: () => _confirmDelete(r),
    );
  }
}

class RepairListItem extends StatelessWidget {
  final Repair repair;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const RepairListItem({
    super.key,
    required this.repair,
    required this.canDelete,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final bool isDone = repair.status >= 3;
    final List<String> images = repair.receiveImages;
    final String firstImage = images.isNotEmpty ? images.first : "";
    final String errorText = repair.issue.split('|').first;
    final List<String> notes = repair.accessories.isNotEmpty
        ? repair.accessories.split(',').map((e) => e.trim()).toList()
        : [];

    return Dismissible(
      key: Key(repair.firestoreId ?? repair.createdAt.toString()),
      direction: canDelete
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_forever, color: Colors.white, size: 30),
      ),
      confirmDismiss: (_) async {
        if (!canDelete) return false;
        onDelete();
        return false;
      },
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 105,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bên trái: ảnh máy
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        image: firstImage.isNotEmpty
                            ? DecorationImage(
                                image: firstImage.startsWith('http')
                                    ? NetworkImage(firstImage)
                                    : FileImage(File(firstImage))
                                          as ImageProvider,
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: firstImage.isEmpty
                          ? const Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                    if (images.length > 1)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "+${images.length - 1}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 12),

                // Bên phải: thông tin
                Expanded(
                  child: SizedBox(
                    height: 81, // Container height 105 - padding 12*2 = 81
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dòng 1: Tên máy + trạng thái
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                repair.model.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: colorScheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: isDone
                                    ? Colors.green.shade100
                                    : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isDone ? "XONG" : "ĐANG SỬA",
                                style: TextStyle(
                                  color: isDone
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 2),

                        // Dòng 2: Khách hàng + ngày nhận
                        Text(
                          "Khách: ${repair.customerName} • ${DateFormat('dd/MM').format(DateTime.fromMillisecondsSinceEpoch(repair.createdAt))}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 1),

                        // Dòng 3: Lỗi chính
                        Text(
                          errorText,
                          style: const TextStyle(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 2),

                        // Dòng 4: Ghi chú dạng tag
                        if (notes.isNotEmpty) ...[
                          Wrap(
                            spacing: 3,
                            runSpacing: 1,
                            children: notes
                                .take(2)
                                .map(
                                  (note) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      note,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
