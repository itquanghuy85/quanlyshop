import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/quick_input_code_model.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../data/db_helper.dart';

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
  List<QuickInputCode> _localCodes = [];

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
      // Load local data after getting shopId
      await _loadLocalCodes();
    }
  }

  Future<void> _loadLocalCodes() async {
    if (shopId == null) return;
    try {
      final db = DBHelper();
      final codes = await db.getQuickInputCodes();
      if (mounted) {
        setState(() {
          _localCodes = codes.where((code) => code.shopId == shopId).toList();
        });
      }
      debugPrint('Loaded ${_localCodes.length} local quick input codes');
    } catch (e) {
      debugPrint('Error loading local codes: $e');
    }
  }

  List<QuickInputCode> _combineData(List<QuickInputCode> cloudCodes) {
    final combined = <String, QuickInputCode>{};

    // Add local codes first
    for (final code in _localCodes) {
      final key = code.firestoreId ?? code.code ?? 'local_${code.id}';
      combined[key] = code;
    }

    // Add/override with cloud codes (cloud takes precedence)
    for (final code in cloudCodes) {
      final key = code.firestoreId ?? code.code ?? 'cloud_${code.id}';
      combined[key] = code;
    }

    return combined.values.toList();
  }

  Widget _buildListView(List<QuickInputCode> codes) {
    final filteredCodes = codes.where((code) {
      if (_searchQuery.isEmpty) return true;
      final codeStr = code.code?.toLowerCase() ?? '';
      final name = code.name?.toLowerCase() ?? '';
      final type = code.type?.toLowerCase() ?? '';
      return codeStr.contains(_searchQuery) ||
             name.contains(_searchQuery) ||
             type.contains(_searchQuery);
    }).toList();

    if (filteredCodes.isEmpty) {
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
            ] else ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _createSampleData,
                icon: const Icon(Icons.add),
                label: const Text('Tạo mẫu dữ liệu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredCodes.length,
      itemBuilder: (context, index) {
        final code = filteredCodes[index];
        return _buildQuickInputCodeCardFromModel(code);
      },
    );
  }

  Widget _buildQuickInputCodeCardFromModel(QuickInputCode code) {
    final codeStr = code.code ?? 'N/A';
    final name = code.name ?? 'Không có tên';
    final type = code.type ?? 'UNKNOWN';
    final createdDateTime = code.createdAt != null ? DateTime.fromMillisecondsSinceEpoch(code.createdAt) : null;
    final createdDate = createdDateTime != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(createdDateTime)
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
        onTap: () => _showQuickInputCodeDetailsFromModel(code),
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
                            codeStr,
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
                onSelected: (value) => _handleMenuActionFromModel(value, code),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mã Nhập Nhanh'),
          backgroundColor: Colors.blue.shade700,
          automaticallyImplyLeading: true,
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
          automaticallyImplyLeading: true,
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
        automaticallyImplyLeading: true,
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
            // Even if there's an error, show local data
            final combinedCodes = _combineData([]);
            return _buildListView(combinedCodes);
          }

          if (snapshot.connectionState == ConnectionState.waiting && _localCodes.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final cloudCodes = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return QuickInputCode.fromMap(data)..firestoreId = doc.id;
          }).toList();

          final combinedCodes = _combineData(cloudCodes);
          return _buildListView(combinedCodes);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateQuickInputCodeDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tạo Mã Mới'),
        backgroundColor: Colors.blue.shade700,
      ),
    );
  }



  void _showQuickInputCodeDetailsFromModel(QuickInputCode code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chi tiết Mã Nhập Nhanh'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Mã', code.code ?? 'N/A'),
              _detailRow('Tên', code.name ?? 'N/A'),
              _detailRow('Loại', code.type ?? 'N/A'),
              if (code.brand != null) _detailRow('Thương hiệu', code.brand!),
              if (code.model != null) _detailRow('Model', code.model!),
              if (code.capacity != null) _detailRow('Dung lượng', code.capacity!),
              if (code.color != null) _detailRow('Màu sắc', code.color!),
              if (code.condition != null) _detailRow('Tình trạng', code.condition!),
              if (code.cost != null) _detailRow('Giá nhập', '${NumberFormat('#,###').format(code.cost)}đ'),
              if (code.price != null) _detailRow('Giá bán', '${NumberFormat('#,###').format(code.price)}đ'),
              if (code.description != null) _detailRow('Mô tả', code.description!),
              if (code.supplier != null) _detailRow('Nhà cung cấp', code.supplier!),
              if (code.paymentMethod != null) _detailRow('Thanh toán', code.paymentMethod!),
              if (code.createdAt != null)
                _detailRow('Ngày tạo', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(code.createdAt))),
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

  Future<void> _createSampleData() async {
    try {
      final samples = [
        QuickInputCode(
          name: 'iPhone 15 Pro Max',
          type: 'PHONE',
          brand: 'Apple',
          model: 'iPhone 15 Pro Max',
          capacity: '256GB',
          color: 'Titan Tự Nhiên',
          condition: 'Mới 100%',
          cost: 25000000,
          price: 28000000,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
        QuickInputCode(
          name: 'Samsung Galaxy S24 Ultra',
          type: 'PHONE',
          brand: 'Samsung',
          model: 'Galaxy S24 Ultra',
          capacity: '512GB',
          color: 'Titan Đen',
          condition: 'Mới 100%',
          cost: 22000000,
          price: 25000000,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
        QuickInputCode(
          name: 'Ốp lưng iPhone',
          type: 'ACCESSORY',
          description: 'Ốp lưng silicone cho iPhone',
          cost: 50000,
          price: 100000,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      ];

      for (final sample in samples) {
        await FirestoreService.addQuickInputCode(sample);
      }

      NotificationService.showSnackBar('Đã tạo ${samples.length} mẫu dữ liệu thành công');
    } catch (e) {
      NotificationService.showSnackBar('Lỗi tạo mẫu dữ liệu: $e', color: Colors.red);
    }
  }

  void _showCreateQuickInputCodeDialog() {
    final nameController = TextEditingController();
    String selectedType = 'PHONE';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Tạo Mã Nhập Nhanh Mới'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên template',
                  hintText: 'Ví dụ: iPhone 15 Pro Max',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Loại',
                ),
                items: const [
                  DropdownMenuItem(value: 'PHONE', child: Text('Điện thoại')),
                  DropdownMenuItem(value: 'ACCESSORY', child: Text('Linh phụ kiện')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedType = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  NotificationService.showSnackBar('Vui lòng nhập tên template', color: Colors.red);
                  return;
                }

                try {
                  final code = QuickInputCode(
                    name: nameController.text.trim(),
                    type: selectedType,
                    createdAt: DateTime.now().millisecondsSinceEpoch,
                  );

                  final result = await FirestoreService.addQuickInputCode(code);
                  if (result != null) {
                    Navigator.pop(context);
                    NotificationService.showSnackBar('Đã tạo mã nhập nhanh thành công');
                  } else {
                    NotificationService.showSnackBar('Lỗi khi tạo mã nhập nhanh', color: Colors.red);
                  }
                } catch (e) {
                  NotificationService.showSnackBar('Lỗi: $e', color: Colors.red);
                }
              },
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuActionFromModel(String action, QuickInputCode code) async {
    switch (action) {
      case 'copy':
        final codeStr = code.code ?? '';
        await Clipboard.setData(ClipboardData(text: codeStr));
        NotificationService.showSnackBar('Đã sao chép mã: $codeStr');
        break;

      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: Text('Bạn có chắc muốn xóa mã "${code.code}"?'),
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
            // Delete from both local and cloud
            if (code.id != null) {
              final db = DBHelper();
              await db.deleteQuickInputCode(code.id!);
            }

            if (code.firestoreId != null) {
              await FirebaseFirestore.instance
                  .collection('quick_input_codes')
                  .doc(code.firestoreId)
                  .delete();
            }

            // Reload local data
            await _loadLocalCodes();
            NotificationService.showSnackBar('Đã xóa mã nhập nhanh');
          } catch (e) {
            NotificationService.showSnackBar('Lỗi khi xóa: $e', color: Colors.red);
          }
        }
        break;
    }
  }
}