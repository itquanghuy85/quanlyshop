import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../models/product_model.dart';
import 'supplier_view.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';

class InventoryView extends StatefulWidget {
  const InventoryView({super.key});

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  final db = DBHelper();
  List<Product> _products = [];
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _refresh();
  }

  Future<void> _loadPermissions() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() {
      _isAdmin = perms['allowViewInventory'] ?? false;
    });
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final data = await db.getInStockProducts();
    final suppliers = await db.getSuppliers();
    setState(() { _products = data; _suppliers = suppliers; _isLoading = false; });
    if (_products.isEmpty) {
      _selectionMode = false;
      _selectedIds.clear();
    }
  }

  Future<void> _confirmDeleteProduct(Product p) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ tài khoản QUẢN LÝ mới được xóa hàng khỏi kho')), 
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÓA SẢN PHẨM KHỎI KHO"),
        content: Text("Bạn chắc chắn muốn xóa \"${p.name}\" khỏi danh sách kho? Hành động này không ảnh hưởng đến các đơn đã bán."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("XÓA")),
        ],
      ),
    );

    if (ok == true) {
      // Xóa trên Firestore nếu có firestoreId
      if (p.firestoreId != null) {
        await FirestoreService.deleteProduct(p.firestoreId!);
      }
      await db.deleteProduct(p.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ĐÃ XÓA SẢN PHẨM KHỎI KHO')), 
      );
      _refresh();
    }
  }

  Future<void> _confirmDeleteSelected() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ tài khoản QUẢN LÝ mới được xóa hàng khỏi kho')),
      );
      return;
    }
    if (_selectedIds.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÓA NHIỀU SẢN PHẨM"),
        content: Text("Bạn chắc chắn muốn xóa ${_selectedIds.length} sản phẩm đã chọn khỏi kho?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("XÓA")),
        ],
      ),
    );

    if (ok == true) {
      for (final id in _selectedIds) {
        await db.deleteProduct(id);
      }
      if (!mounted) return;
      _selectedIds.clear();
      _selectionMode = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ĐÃ XÓA CÁC SẢN PHẨM ĐÃ CHỌN')), 
      );
      _refresh();
    }
  }

  void _toggleSelection(Product p) {
    final id = p.id;
    if (id == null) return;
    setState(() {
      if (!_selectionMode) {
        _selectionMode = true;
      }
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..addAll(_products.where((p) => p.id != null).map((p) => p.id!));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _showAddProductDialog() {
    final nameC = TextEditingController();
    final imeiC = TextEditingController();
    final costC = TextEditingController();
    final priceC = TextEditingController();
    final qtyC = TextEditingController(text: "1");
    String type = "PHONE";
    String? supplier = _suppliers.isNotEmpty ? _suppliers.first['name'] as String : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text("NHẬP HÀNG VÀO KHO"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: "PHONE", child: Text("ĐIỆN THOẠI")),
                    DropdownMenuItem(value: "ACCESSORY", child: Text("PHỤ KIỆN")),
                  ],
                  onChanged: (v) => setModalState(() => type = v!),
                  decoration: const InputDecoration(labelText: "Loại hàng"),
                ),
                TextField(controller: nameC, decoration: const InputDecoration(labelText: "Tên máy/Linh kiện"), textCapitalization: TextCapitalization.characters),
                TextField(controller: imeiC, decoration: const InputDecoration(labelText: "Số IMEI (Nếu có)"), textCapitalization: TextCapitalization.characters),
                Row(children: [
                  Expanded(child: TextField(controller: costC, decoration: const InputDecoration(labelText: "Giá vốn", suffixText: ".000"), keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: priceC, decoration: const InputDecoration(labelText: "Giá bán", suffixText: ".000"), keyboardType: TextInputType.number)),
                ]),
                TextField(controller: qtyC, decoration: const InputDecoration(labelText: "Số lượng"), keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: supplier,
                  decoration: const InputDecoration(labelText: "Nhà cung cấp (bắt buộc)"),
                  items: _suppliers.map((s) => DropdownMenuItem(value: s['name'] as String, child: Text(s['name']))).toList(),
                  onChanged: (v) => setModalState(() => supplier = v),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final created = await _showQuickAddSupplier();
                      if (created != null) {
                        setModalState(() => supplier = created);
                      }
                    },
                    icon: const Icon(Icons.add_business, size: 18),
                    label: const Text("Thêm NCC nhanh"),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
            ElevatedButton(onPressed: () async {
              if (nameC.text.isEmpty || supplier == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("VUI LÒNG NHẬP TÊN HÀNG VÀ CHỌN NHÀ CUNG CẤP")));
                return;
              }
              final qty = int.tryParse(qtyC.text) ?? 1;
              final p = Product(
                name: nameC.text.toUpperCase(),
                imei: imeiC.text.toUpperCase(),
                cost: (int.tryParse(costC.text) ?? 0) * 1000,
                price: (int.tryParse(priceC.text) ?? 0) * 1000,
                quantity: qty,
                type: type,
                createdAt: DateTime.now().millisecondsSinceEpoch,
                status: 1,
                supplier: supplier,
              );
              await db.insertProduct(p);
              await db.incrementSupplierStats(supplier!, p.cost * qty);
              Navigator.pop(ctx);
              _refresh();
            }, child: const Text("NHẬP KHO")),
          ],
        ),
      ),
    );
  }

  Future<String?> _showQuickAddSupplier() async {
    final nameC = TextEditingController();
    final contactC = TextEditingController();
    final phoneC = TextEditingController();
    final addressC = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("THÊM NHÀ CUNG CẤP"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: "Tên NCC"), textCapitalization: TextCapitalization.characters),
              TextField(controller: contactC, decoration: const InputDecoration(labelText: "Người bán"), textCapitalization: TextCapitalization.characters),
              TextField(controller: phoneC, decoration: const InputDecoration(labelText: "SĐT"), keyboardType: TextInputType.phone),
              TextField(controller: addressC, decoration: const InputDecoration(labelText: "Địa chỉ"), textCapitalization: TextCapitalization.characters),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
          ElevatedButton(
            onPressed: () async {
              if (nameC.text.isEmpty) return;
              final supplierName = nameC.text.toUpperCase();
              await db.insertSupplier({
                'name': supplierName,
                'contactPerson': contactC.text.toUpperCase(),
                'phone': phoneC.text,
                'address': addressC.text.toUpperCase(),
                'items': "",
                'createdAt': DateTime.now().millisecondsSinceEpoch,
              });
              final list = await db.getSuppliers();
              setState(() => _suppliers = list);
              Navigator.pop(ctx, supplierName);
            },
            child: const Text("LƯU"),
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
        title: const Text("KHO"),
        actions: [
          IconButton(
            onPressed: () async {
              final perms = await UserService.getCurrentUserPermissions();
              final canView = perms['allowViewSuppliers'] ?? false;
              if (!canView) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Tài khoản này không được phép xem danh sách NHÀ PHÂN PHỐI. Liên hệ chủ shop để phân quyền.")),
                );
                return;
              }
              if (!mounted) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierView()));
            },
            icon: const Icon(Icons.business),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              if (_selectionMode)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.blue.withOpacity(0.06),
                  child: Row(
                    children: [
                      Text("Đã chọn: ${_selectedIds.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      TextButton.icon(
                        onPressed: _selectAll,
                        icon: const Icon(Icons.select_all, size: 18),
                        label: const Text("Chọn tất cả"),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: "Bỏ chọn",
                        onPressed: _clearSelection,
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(15, 15, 15, 100),
                  itemCount: _products.length,
                  itemBuilder: (ctx, i) {
                    final p = _products[i];
                    final isSelected = p.id != null && _selectedIds.contains(p.id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        onLongPress: () => _toggleSelection(p),
                        onTap: _selectionMode ? () => _toggleSelection(p) : null,
                        leading: _selectionMode
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleSelection(p),
                              )
                            : CircleAvatar(child: Icon(p.type == 'PHONE' ? Icons.phone_android : Icons.headset)),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("NCC: ${p.supplier ?? '---'}\nIMEI: ${p.imei ?? 'N/A'} | SL: ${p.quantity}"),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${NumberFormat('#,###').format(p.price)} đ",
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                            if (_isAdmin && !_selectionMode)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                tooltip: "Xóa khỏi kho",
                                onPressed: () => _confirmDeleteProduct(p),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectionMode && _isAdmin)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FloatingActionButton.extended(
                onPressed: _confirmDeleteSelected,
                backgroundColor: Colors.redAccent,
                icon: const Icon(Icons.delete_sweep_rounded),
                label: const Text("Xóa đã chọn"),
              ),
            ),
          FloatingActionButton.extended(
            onPressed: _showAddProductDialog,
            label: const Text("NHẬP HÀNG MỚI"),
            icon: const Icon(Icons.add),
            backgroundColor: Colors.blueAccent,
          ),
        ],
      ),
    );
  }
}
