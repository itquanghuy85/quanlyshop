import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';

class QuickInputCodesView extends StatefulWidget {
  const QuickInputCodesView({super.key});

  @override
  State<QuickInputCodesView> createState() => _QuickInputCodesViewState();
}

class _QuickInputCodesViewState extends State<QuickInputCodesView> {
  String? shopId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShopId();
  }

  Future<void> _loadShopId() async {
    final id = await UserService.getCurrentShopId();
    if (mounted) {
      setState(() {
        shopId = id;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mã Nhập Nhanh'),
          backgroundColor: Colors.blue.shade700,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (shopId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mã Nhập Nhanh'),
          backgroundColor: Colors.blue.shade700,
        ),
        body: const Center(
          child: Text('Không thể tải dữ liệu shop'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mã Nhập Nhanh'),
        backgroundColor: Colors.blue.shade700,
        elevation: 2,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm mã nhập nhanh...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('quick_input_codes')
            .where('shopId', isEqualTo: shopId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Lỗi tải dữ liệu: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final filteredDocs = docs.where((doc) {
            if (_searchQuery.isEmpty) return true;
            final data = doc.data() as Map<String, dynamic>;
            final code = data['code']?.toString().toLowerCase() ?? '';
            final name = data['name']?.toString().toLowerCase() ?? '';
            final type = data['type']?.toString().toLowerCase() ?? '';
            return code.contains(_searchQuery) ||
                   name.contains(_searchQuery) ||
                   type.contains(_searchQuery);
          }).toList();

          if (filteredDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'Chưa có mã nhập nhanh nào'
                        : 'Không tìm thấy mã nhập nhanh phù hợp',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                      child: const Text('Xóa bộ lọc'),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildQuickInputCodeCard(data, doc.id);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to create new quick input code
          Navigator.pushNamed(context, '/fast_inventory_input');
        },
        icon: const Icon(Icons.add),
        label: const Text('Tạo Mã Mới'),
        backgroundColor: Colors.blue.shade700,
      ),
    );
  }

  Widget _buildQuickInputCodeCard(Map<String, dynamic> data, String docId) {
    final code = data['code'] ?? 'N/A';
    final name = data['name'] ?? 'Không có tên';
    final type = data['type'] ?? 'UNKNOWN';
    final createdAt = data['createdAt'] as Timestamp?;
    final createdDate = createdAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toDate())
        : 'N/A';

    Color typeColor;
    IconData typeIcon;
    String typeText;

    switch (type.toUpperCase()) {
      case 'PHONE':
        typeColor = Colors.blue;
        typeIcon = Icons.phone_android;
        typeText = 'Điện thoại';
        break;
      case 'ACCESSORY':
        typeColor = Colors.green;
        typeIcon = Icons.headphones;
        typeText = 'Phụ kiện';
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.device_unknown;
        typeText = 'Khác';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showQuickInputCodeDetails(data, docId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // QR Code Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  typeIcon,
                  color: typeColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Code and Type
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            code,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            typeText,
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Name
                    Text(
                      name,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Date
                    Text(
                      'Tạo: $createdDate',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Menu
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(value, data, docId),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 20),
                        SizedBox(width: 8),
                        Text('Sao chép mã'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Xóa', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickInputCodeDetails(Map<String, dynamic> data, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chi tiết Mã Nhập Nhanh'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Mã', data['code'] ?? 'N/A'),
              _detailRow('Tên', data['name'] ?? 'N/A'),
              _detailRow('Loại', data['type'] ?? 'N/A'),
              if (data['imei'] != null) _detailRow('IMEI', data['imei']),
              if (data['model'] != null) _detailRow('Model', data['model']),
              if (data['info'] != null) _detailRow('Thông tin', data['info']),
              if (data['cost'] != null) _detailRow('Giá nhập', '${NumberFormat('#,###').format(data['cost'])}đ'),
              if (data['retail'] != null) _detailRow('Giá bán', '${NumberFormat('#,###').format(data['retail'])}đ'),
              if (data['createdAt'] != null)
                _detailRow('Ngày tạo', DateFormat('dd/MM/yyyy HH:mm').format((data['createdAt'] as Timestamp).toDate())),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, Map<String, dynamic> data, String docId) async {
    switch (action) {
      case 'copy':
        final code = data['code'] ?? '';
        await Clipboard.setData(ClipboardData(text: code));
        NotificationService.showSnackBar('Đã sao chép mã: $code');
        break;

      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: Text('Bạn có chắc muốn xóa mã "${data['code']}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Xóa'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          try {
            await FirebaseFirestore.instance
                .collection('quick_input_codes')
                .doc(docId)
                .delete();
            NotificationService.showSnackBar('Đã xóa mã nhập nhanh');
          } catch (e) {
            NotificationService.showSnackBar('Lỗi khi xóa: $e', color: Colors.red);
          }
        }
        break;
    }
  }
}