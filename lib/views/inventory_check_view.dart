import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/db_helper.dart';
import '../models/inventory_check_model.dart';
import '../services/notification_service.dart';

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
    _initData();
  }

  Future<void> _initData() async {
    await _loadOrCreateCurrentCheck();
    await _loadItems();
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

    // Lấy dữ liệu Map từ DB và chuyển đổi sang Model thủ công để tránh lỗi type
    final List<Map<String, dynamic>> res = await _dbHelper.getInventoryChecks(
      checkType: _selectedType,
      isCompleted: false
    );

    InventoryCheck? todayCheck;
    for (var map in res) {
      final checkDate = DateTime.fromMillisecondsSinceEpoch(map['checkDate'] ?? 0);
      final checkDateKey = DateFormat('yyyy-MM-dd').format(checkDate);
      if (checkDateKey == todayKey) {
        // Parse itemsJson nếu cần
        List<InventoryCheckItem> items = [];
        if (map['itemsJson'] != null) {
          final decoded = jsonDecode(map['itemsJson']);
          items = (decoded as List).map((e) => InventoryCheckItem.fromMap(e)).toList();
        }
        todayCheck = InventoryCheck(
          id: map['id'],
          firestoreId: map['firestoreId'],
          checkType: map['type'] ?? 'PHONE',
          checkDate: map['checkDate'] ?? 0,
          checkedBy: map['createdBy'] ?? '',
          items: items,
          isCompleted: (map['isCompleted'] ?? 0) == 1,
          createdAt: map['checkDate'] ?? 0,
        );
        break;
      }
    }

    if (todayCheck != null) {
      setState(() {
        _currentCheck = todayCheck;
        _checkItems = todayCheck!.items;
      });
    } else {
      final newCheck = InventoryCheck(
        checkType: _selectedType,
        checkDate: today.millisecondsSinceEpoch,
        checkedBy: 'admin', 
        items: [],
        createdAt: today.millisecondsSinceEpoch,
      );
      final id = await _dbHelper.insertInventoryCheck(newCheck.toMap());
      newCheck.id = id;
      setState(() {
        _currentCheck = newCheck;
        _checkItems = [];
      });
    }
  }

  void _updateCheckItems() {
    setState(() {
      _checkItems = _items.map((item) {
        final String itemId = (item['firestoreId'] ?? item['id']).toString();
        final existing = _checkItems.where((ci) => ci.itemId == itemId).toList();
        if (existing.isNotEmpty) return existing.first;

        return InventoryCheckItem(
          itemId: itemId,
          itemName: (_selectedType == 'PHONE' ? item['name'] : item['partName']) ?? 'N/A',
          itemType: _selectedType,
          imei: item['imei'],
          color: item['color'],
          quantity: item['quantity'] ?? 1,
        );
      }).toList();
    });
  }

  Future<void> _saveCurrentCheck() async {
    if (_currentCheck != null) {
      final map = _currentCheck!.toMap();
      // Chuyển danh sách item sang JSON để lưu vào cột itemsJson
      map['itemsJson'] = jsonEncode(_checkItems.map((e) => e.toMap()).toList());
      map['type'] = _selectedType;
      map['createdBy'] = _currentCheck!.checkedBy;
      await _dbHelper.updateInventoryCheck(map);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _checkItems.where((item) {
      final name = item.itemName.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('KIỂM KHO'),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.qr_code_scanner),
            onPressed: () => setState(() => _isScanning = !_isScanning),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Tìm kiếm...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          if (_isScanning) Container(height: 200, child: MobileScanner(controller: _scannerController, onDetect: (c) {})),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
              itemCount: filteredItems.length,
              itemBuilder: (ctx, i) => _buildItemTile(filteredItems[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16), color: Colors.blue.shade50,
      child: Row(
        children: [
          Expanded(child: Text('Đã kiểm: ${_checkItems.where((e)=>e.isChecked).length}/${_checkItems.length}', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedType,
              items: const [DropdownMenuItem(value: 'PHONE', child: Text('Điện thoại')), DropdownMenuItem(value: 'ACCESSORY', child: Text('Phụ kiện'))],
              onChanged: (v) { if(v!=null) { setState(()=>_selectedType=v); _initData(); } },
            ),
          ),
        ],
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
          onChanged: (v) {
            setState(() { item.isChecked = v ?? false; item.checkedAt = v == true ? DateTime.now().millisecondsSinceEpoch : 0; });
            _saveCurrentCheck();
          },
        ),
        title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('SL: ${item.quantity} | IMEI: ${item.imei ?? "N/A"}'),
        trailing: item.isChecked ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.radio_button_unchecked),
      ),
    );
  }
}
