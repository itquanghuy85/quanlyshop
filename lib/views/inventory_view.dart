import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../models/product_model.dart';
import 'supplier_view.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';
import '../services/unified_printer_service.dart';
import '../services/bluetooth_printer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PrinterType { bluetooth, wifi, none }

class PrinterOption {
  final PrinterType type;
  final String name;
  final String address;

  PrinterOption({required this.type, required this.name, required this.address});
}

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

  // Theme colors cho màn hình nhập kho
  final Color _primaryColor = Colors.green; // Màu chính cho nhập kho
  final Color _accentColor = Colors.green.shade600;
  final Color _backgroundColor = const Color(0xFFF8FAFF);

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _refresh();
  }

  Future<void> _loadPermissions() async {
    final perms = await UserService.getCurrentUserPermissions();
    print('DEBUG: User permissions: $perms');
    print('DEBUG: allowViewInventory: ${perms['allowViewInventory']}');
    if (!mounted) return;
    setState(() {
      _isAdmin = perms['allowViewInventory'] ?? false;
    });
    print('DEBUG: _isAdmin set to: $_isAdmin');
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
    final kpkPriceC = TextEditingController(); // Giá bán kèm phụ kiện
    final pkPriceC = TextEditingController(); // Giá phụ kiện
    final capacityC = TextEditingController(); // Dung lượng
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
                  Expanded(child: TextField(controller: kpkPriceC, decoration: const InputDecoration(labelText: "Giá KPK", suffixText: ".000"), keyboardType: TextInputType.number)),
                ]),
                TextField(controller: pkPriceC, decoration: const InputDecoration(labelText: "Giá PK", suffixText: ".000"), keyboardType: TextInputType.number),
                TextField(controller: capacityC, decoration: const InputDecoration(labelText: "Dung lượng (ví dụ: 64GB, 128GB)"), textCapitalization: TextCapitalization.characters),
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
                price: (int.tryParse(pkPriceC.text) ?? 0) * 1000, // Giá bán = giá PK
                capacity: capacityC.text.isNotEmpty ? capacityC.text.toUpperCase() : null,
                kpkPrice: kpkPriceC.text.isNotEmpty ? (int.tryParse(kpkPriceC.text) ?? 0) * 1000 : null,
                pkPrice: (int.tryParse(pkPriceC.text) ?? 0) * 1000,
                quantity: qty,
                type: type,
                createdAt: DateTime.now().millisecondsSinceEpoch,
                status: 1,
                supplier: supplier,
              );
              
              // Upload lên Firestore trước
              final firestoreId = await FirestoreService.addProduct(p);
              if (firestoreId != null) {
                p.firestoreId = firestoreId;
              }
              
              await db.upsertProduct(p);
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

  Future<List<PrinterOption>> _getAvailablePrinters() async {
    final printers = <PrinterOption>[];

    // Thêm máy in Bluetooth
    final bluetoothPrinters = await BluetoothPrinterService.getPairedPrinters();
    print('DEBUG: Found ${bluetoothPrinters.length} Bluetooth printers');
    for (final device in bluetoothPrinters) {
      printers.add(PrinterOption(
        type: PrinterType.bluetooth,
        name: device.name ?? 'Unknown Bluetooth Printer',
        address: device.macAdress ?? '',
      ));
    }

    // Thêm máy in WiFi từ SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final wifiPrinters = prefs.getStringList('wifi_printers') ?? [];
    print('DEBUG: Found ${wifiPrinters.length} WiFi printers: $wifiPrinters');
    for (final ip in wifiPrinters) {
      printers.add(PrinterOption(
        type: PrinterType.wifi,
        name: 'WiFi Printer ($ip)',
        address: ip,
      ));
    }

    // TEST: Thêm máy in giả để test dialog
    if (printers.isEmpty) {
      print('DEBUG: Adding test printers for testing');
      printers.add(PrinterOption(
        type: PrinterType.bluetooth,
        name: 'Test Bluetooth Printer',
        address: '00:11:22:33:44:55',
      ));
      printers.add(PrinterOption(
        type: PrinterType.wifi,
        name: 'Test WiFi Printer (192.168.1.100)',
        address: '192.168.1.100',
      ));
    }

    print('DEBUG: Total printers available: ${printers.length}');
    return printers;
  }

  Future<PrinterOption?> _showPrinterSelectionDialog() async {
    final printers = await _getAvailablePrinters();

    if (printers.isEmpty) {
      print('DEBUG: No printers found, showing snackbar');
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy máy in nào. Vui lòng kết nối máy in trước.')),
      );
      return null;
    }

    return showDialog<PrinterOption>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CHỌN MÁY IN'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: printers.length,
            itemBuilder: (context, index) {
              final printer = printers[index];
              return ListTile(
                leading: Icon(
                  printer.type == PrinterType.bluetooth
                      ? Icons.bluetooth
                      : Icons.wifi,
                ),
                title: Text(printer.name),
                subtitle: Text(printer.address),
                onTap: () => Navigator.pop(ctx, printer),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('HỦY'),
          ),
        ],
      ),
    );
  }

  Future<void> _printPhoneLabel(Product product) async {
    print('DEBUG: _printPhoneLabel called for product: ${product.name}');
    try {
      // Hiển thị dialog xác nhận
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("IN TEM ĐIỆN THOẠI"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Tên: ${product.name.toUpperCase()}"),
              Text("IMEI: ${product.imei?.toUpperCase() ?? 'N/A'}"),
              Text("Màu: ${product.color?.toUpperCase() ?? 'N/A'}"),
              Text("Giá: ${NumberFormat('#,###').format(product.price)} đ"),
              Text("Tình trạng: ${product.condition.toUpperCase()}"),
              if (product.description.isNotEmpty)
                Text("Phụ kiện: ${product.description.toUpperCase()}"),
              const SizedBox(height: 10),
              const Text("Bạn có muốn in tem cho điện thoại này?"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("HỦY"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("IN TEM"),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Chọn máy in
      final selectedPrinter = await _showPrinterSelectionDialog();
      if (selectedPrinter == null) return;

      // Tạo dữ liệu tem
      final labelData = {
        'name': product.name.toUpperCase(),
        'imei': product.imei?.toUpperCase() ?? 'N/A',
        'color': product.color?.toUpperCase() ?? 'N/A',
        'capacity': product.capacity?.toUpperCase() ?? '',
        'cost': NumberFormat('#,###').format(product.cost),
        'kpkPrice': NumberFormat('#,###').format(product.kpkPrice ?? product.price),
        'pkPrice': NumberFormat('#,###').format(product.pkPrice ?? product.price),
        'condition': product.condition.toUpperCase(),
        'accessories': product.description.isNotEmpty ? product.description.toUpperCase() : 'KHÔNG CÓ',
      };

      // In tem với máy in đã chọn
      bool printSuccess = false;
      if (selectedPrinter.type == PrinterType.bluetooth) {
        printSuccess = await BluetoothPrinterService.printPhoneLabel(labelData, selectedPrinter.address);
      } else if (selectedPrinter.type == PrinterType.wifi) {
        printSuccess = await UnifiedPrinterService.printPhoneLabelToWifi(labelData, selectedPrinter.address);
      }

      if (!mounted) return;
      
      if (printSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ĐÃ IN TEM THÀNH CÔNG")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("IN TEM THẤT BẠI - KIỂM TRA MÁY IN")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("LỖI KHI IN TEM: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text("KHO HÀNG", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
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
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            if (_isAdmin && !_selectionMode)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (p.type == 'PHONE')
                                    IconButton(
                                      icon: const Icon(Icons.label_outline, size: 16, color: Colors.blue),
                                      tooltip: "In tem điện thoại",
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _printPhoneLabel(p),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                                    tooltip: "Xóa khỏi kho",
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _confirmDeleteProduct(p),
                                  ),
                                ],
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
