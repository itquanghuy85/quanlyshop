import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/db_helper.dart';
import '../models/inventory_check_model.dart';
import '../models/product_model.dart';
import '../services/notification_service.dart';
import '../widgets/perpetual_calendar.dart';

class InventoryCheckView extends StatefulWidget {
  const InventoryCheckView({super.key});

  @override
  State<InventoryCheckView> createState() => _InventoryCheckViewState();
}

class _InventoryCheckViewState extends State<InventoryCheckView> {
  final DBHelper _dbHelper = DBHelper();
  String _selectedType = 'PHONE';
  List<Map<String, dynamic>> _items = [];
  List<InventoryCheckItem> _checkItems = [];
  bool _isLoading = false;
  bool _isScanning = false;
  final MobileScannerController _scannerController = MobileScannerController();
  String _searchQuery = '';
  InventoryCheck? _currentCheck;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadOrCreateCurrentCheck();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      _items = await _dbHelper.getItemsForInventoryCheck(_selectedType);
      _updateCheckItems();
    } catch (e) {
      NotificationService.showSnackBar('Lỗi tải danh sách: $e', color: Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOrCreateCurrentCheck() async {
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);

    final existingChecks = await _dbHelper.getInventoryChecks(
      checkType: _selectedType,
      isCompleted: false
    );

    // Tìm check chưa hoàn thành cho ngày hôm nay
    final todayCheck = existingChecks.where((check) {
      final checkDate = DateTime.fromMillisecondsSinceEpoch(check.checkDate);
      final checkDateKey = DateFormat('yyyy-MM-dd').format(checkDate);
      return checkDateKey == todayKey && !check.isCompleted;
    }).toList();

    if (todayCheck.isNotEmpty) {
      _currentCheck = todayCheck.first;
      _checkItems = _currentCheck!.items;
    } else {
      // Tạo check mới
      _currentCheck = InventoryCheck(
        checkType: _selectedType,
        checkDate: today.millisecondsSinceEpoch,
        checkedBy: 'admin@huluca.com', // TODO: Get current user
        items: [],
        createdAt: today.millisecondsSinceEpoch,
      );
      await _dbHelper.insertInventoryCheck(_currentCheck!);
    }
  }

  void _updateCheckItems() {
    _checkItems = _items.map((item) {
      final existingItem = _checkItems.where((checkItem) =>
        checkItem.itemId == item['firestoreId'] ||
        checkItem.itemId == item['id'].toString()
      ).toList();

      if (existingItem.isNotEmpty) {
        return existingItem.first;
      }

      return InventoryCheckItem(
        itemId: item['firestoreId'] ?? item['id'].toString(),
        itemName: _selectedType == 'PHONE' ? item['name'] : item['partName'],
        itemType: _selectedType,
        imei: item['imei'],
        color: item['color'],
        quantity: item['quantity'] ?? 1,
      );
    }).toList();
  }

  Future<void> _onQrDetected(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        await _processQrCode(barcode.rawValue!);
      }
    }
  }

  Future<void> _processQrCode(String qrData) async {
    try {
      // Parse QR data (từ tem điện thoại hoặc phụ kiện)
      final qrMap = _parseQrData(qrData);
      if (qrMap == null) return;

      final itemId = qrMap['itemId'];
      final itemIndex = _checkItems.indexWhere((item) => item.itemId == itemId);

      if (itemIndex != -1) {
        setState(() {
          _checkItems[itemIndex].isChecked = true;
          _checkItems[itemIndex].checkedAt = DateTime.now().millisecondsSinceEpoch;
        });

        // Haptic feedback và thông báo
        NotificationService.showSnackBar('✅ CHECK OK: ${_checkItems[itemIndex].itemName}');

        // Lưu thay đổi
        await _saveCurrentCheck();
      } else {
        NotificationService.showSnackBar('❌ Item không tìm thấy trong danh sách kiểm kho', color: Colors.orange);
      }
    } catch (e) {
      NotificationService.showSnackBar('❌ Lỗi xử lý QR: $e', color: Colors.red);
    }
  }

  Map<String, dynamic>? _parseQrData(String qrData) {
    try {
      // QR từ tem điện thoại: JSON format
      if (qrData.startsWith('{')) {
        final qrMap = qrData.replaceAll('{', '').replaceAll('}', '').split(', ');
        final parsed = <String, dynamic>{};
        for (final pair in qrMap) {
          final parts = pair.split(': ');
          if (parts.length == 2) {
            parsed[parts[0]] = parts[1];
          }
        }
        return parsed;
      }

      // QR đơn giản: chỉ itemId
      return {'itemId': qrData};
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveCurrentCheck() async {
    if (_currentCheck != null) {
      _currentCheck!.items = _checkItems;
      await _dbHelper.updateInventoryCheck(_currentCheck!);
    }
  }

  Future<void> _completeCheck() async {
    if (_currentCheck != null) {
      final checkedCount = _checkItems.where((item) => item.isChecked).length;
      final totalCount = _checkItems.length;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('HOÀN THÀNH KIỂM KHO'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Đã kiểm: $checkedCount/$totalCount items'),
              const SizedBox(height: 10),
              Text('Tỷ lệ: ${(checkedCount / totalCount * 100).toStringAsFixed(1)}%'),
              const SizedBox(height: 10),
              const Text('Bạn có muốn hoàn thành phiên kiểm kho này?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('HỦY'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('HOÀN THÀNH'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        _currentCheck!.isCompleted = true;
        await _dbHelper.updateInventoryCheck(_currentCheck!);
        NotificationService.showSnackBar('✅ Đã hoàn thành kiểm kho!');
        _loadOrCreateCurrentCheck(); // Tạo phiên mới
      }
    }
  }

  void _toggleScanMode() {
    setState(() => _isScanning = !_isScanning);
  }

  void _checkAllItems() {
    setState(() {
      for (var item in _checkItems) {
        item.isChecked = true;
        item.checkedAt = DateTime.now().millisecondsSinceEpoch;
      }
    });
    _saveCurrentCheck();
    NotificationService.showSnackBar('✅ Đã check tất cả items');
  }

  void _uncheckAllItems() {
    setState(() {
      for (var item in _checkItems) {
        item.isChecked = false;
        item.checkedAt = 0;
      }
    });
    _saveCurrentCheck();
    NotificationService.showSnackBar('🔄 Đã bỏ check tất cả items');
  }

  List<InventoryCheckItem> _getFilteredItems() {
    if (_searchQuery.isEmpty) return _checkItems;

    return _checkItems.where((item) {
      final name = item.itemName.toLowerCase();
      final imei = item.imei?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return name.contains(query) || imei.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();
    final checkedCount = _checkItems.where((item) => item.isChecked).length;
    final totalCount = _checkItems.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KIỂM KHO'),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.qr_code_scanner : Icons.qr_code),
            onPressed: _toggleScanMode,
            tooltip: _isScanning ? 'Tắt scanner' : 'Bật scanner',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'check_all':
                  _checkAllItems();
                  break;
                case 'uncheck_all':
                  _uncheckAllItems();
                  break;
                case 'complete':
                  _completeCheck();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'check_all',
                child: Text('Check tất cả'),
              ),
              const PopupMenuItem(
                value: 'uncheck_all',
                child: Text('Bỏ check tất cả'),
              ),
              const PopupMenuItem(
                value: 'complete',
                child: Text('Hoàn thành kiểm kho'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Header với thống kê
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$checkedCount/$totalCount',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        'Đã kiểm (${(checkedCount / (totalCount == 0 ? 1 : totalCount) * 100).toStringAsFixed(1)}%)',
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Loại kiểm kho',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'PHONE', child: Text('Điện thoại')),
                      DropdownMenuItem(value: 'ACCESSORY', child: Text('Phụ kiện')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedType = value);
                        _loadItems();
                        _loadOrCreateCurrentCheck();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm theo tên hoặc IMEI...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // QR Scanner (nếu đang bật)
          if (_isScanning)
            Container(
              height: 200,
              margin: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: _onQrDetected,
                ),
              ),
            ),

          // Danh sách items
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredItems.isEmpty
                ? const Center(child: Text('Không có item nào để kiểm kho'))
                : ListView.builder(
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _buildItemTile(item);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleScanMode,
        child: Icon(_isScanning ? Icons.stop : Icons.qr_code_scanner),
        tooltip: _isScanning ? 'Dừng quét' : 'Quét QR',
      ),
    );
  }

  Widget _buildItemTile(InventoryCheckItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: item.isChecked ? Colors.green.shade50 : Colors.white,
      child: ListTile(
        leading: Checkbox(
          value: item.isChecked,
          onChanged: (checked) {
            setState(() {
              item.isChecked = checked ?? false;
              item.checkedAt = checked == true
                ? DateTime.now().millisecondsSinceEpoch
                : 0;
            });
            _saveCurrentCheck();
          },
        ),
        title: Text(
          item.itemName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: item.isChecked ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imei != null && item.imei!.isNotEmpty)
              Text('IMEI: ${item.imei}'),
            if (item.color != null && item.color!.isNotEmpty)
              Text('Màu: ${item.color}'),
            Text('SL: ${item.quantity}'),
            if (item.isChecked && item.checkedAt > 0)
              Text(
                'Checked: ${DateFormat('HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(item.checkedAt))}',
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
          ],
        ),
        trailing: item.isChecked
          ? const Icon(Icons.check_circle, color: Colors.green)
          : const Icon(Icons.radio_button_unchecked),
      ),
    );
  }
}