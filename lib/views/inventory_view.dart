import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/db_helper.dart';
import '../models/product_model.dart';
import '../models/inventory_check_model.dart';
import 'supplier_view.dart';
import 'create_sale_view.dart';
import '../services/firestore_service.dart';
import '../services/unified_printer_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../utils/sku_generator.dart';
import '../widgets/printer_selection_dialog.dart';
import '../models/printer_types.dart';
import 'fast_inventory_input_view.dart';
import 'stock_in_view.dart';
import 'global_search_view.dart';
import 'fast_stock_in_view.dart';
import 'quick_input_library_view.dart';
import '../widgets/currency_text_field.dart';
import '../widgets/validated_text_field.dart';

class InventoryView extends StatefulWidget {
  final String role;
  const InventoryView({super.key, required this.role});
  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> with TickerProviderStateMixin {
  final db = DBHelper();
  List<Product> _products = [];
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  bool _hasInventoryAccess = false;
  String _searchQuery = "";
  
  final Set<int> _selectedIds = {};
  bool _isSelectionMode = false;

  // Tab controller
  late TabController _tabController;

  // Inventory check variables
  String _selectedType = 'PHONE';
  List<Map<String, dynamic>> _items = [];
  List<InventoryCheckItem> _checkItems = [];
  bool _isCheckingLoading = false;
  bool _isScanning = false;
  final MobileScannerController _scannerController = MobileScannerController();
  final String _checkSearchQuery = '';
  InventoryCheck? _currentCheck;

  // Layout sizing constants
  final double _pad = 12.0;
  final double _cardPadding = 12.0;
  final double _iconSize = 20.0;
  final double _titleFontSize = 18.0;
  final double _subtitleFontSize = 12.0;
  final double _smallFontSize = 11.0;
  final double _btnMinHeight = 44.0;
  

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    // ensure UI updates when user switches tabs
    _tabController.addListener(() { 
      if (mounted) setState(() {}); 
    });
    _init();
    // Re-enable inventory check initialization for QR check
    _initCheckData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Widget _input(TextEditingController c, String l, IconData i, {FocusNode? f, FocusNode? next, TextInputType type = TextInputType.text, String? suffix, bool caps = false, bool isBig = false, bool readOnly = false}) {
    if (type == TextInputType.number && (l.contains('GIÁ') || l.contains('TIỀN') || suffix == 'k')) {
      // Use CurrencyTextField for price fields
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: CurrencyTextField(
          controller: c,
          label: l,
          icon: i,
          onSubmitted: () { if (next != null) FocusScope.of(context).requestFocus(next); },
        ),
      );
    } else {
      // Use ValidatedTextField for text fields
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ValidatedTextField(
          controller: c,
          label: l,
          icon: i,
          keyboardType: type,
          uppercase: caps,
          onSubmitted: () { if (next != null) FocusScope.of(context).requestFocus(next); },
        ),
      );
    }
  }

  void _showProductDetail(Product p) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25))
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10)
                )
              )
            ),
            const SizedBox(height: 20),
            Text(
              p.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2962FF)
              )
            ),
            const SizedBox(height: 15),
            _detailItem("Chi tiết máy", p.capacity ?? ""),
            _detailItem("IMEI/Serial", p.imei ?? "N/A"),
            _detailItem("Nhà cung cấp", p.supplier ?? "N/A"),
            _detailItem("Giá bán", "${NumberFormat('#,###').format(p.price)} đ", color: Colors.red),
            const Divider(height: 30),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      // Show printer selection dialog directly
                      try {
                        final printerConfig = await showPrinterSelectionDialog(context);
                        if (printerConfig != null) {
                          final printerType = printerConfig['type'] as PrinterType?;
                          final bluetoothPrinter = printerConfig['bluetoothPrinter'] as BluetoothPrinterConfig?;
                          final wifiIp = printerConfig['wifiIp'] as String?;
                          final success = await UnifiedPrinterService.printProductQRLabel(
                            p.toMap(),
                            customMac: bluetoothPrinter?.macAddress,
                            printerType: printerType,
                            wifiIp: wifiIp,
                          );
                          if (success) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã in tem thành công!')),
                              );
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('In tem thất bại!')),
                              );
                            }
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.qr_code_2, color: Colors.white),
                    label: const Text(
                      "IN TEM QR",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 15)
                    )
                  )
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _createSaleOrder(p);
                    },
                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                    label: const Text(
                      "TẠO ĐƠN HÀNG",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2962FF),
                      padding: const EdgeInsets.symmetric(vertical: 15)
                    )
                  )
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                    label: const Text("ĐÓNG"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15)
                    )
                  )
                )
              ]
            )
          ]
        )
      )
    );
  }

  void _createSaleOrder(Product p) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateSaleView()),
    ).then((_) => _refresh());
  }

  void _showEditProductDialog(Product p) {
    final nameCtrl = TextEditingController(text: p.name);
    final capacityCtrl = TextEditingController(text: p.capacity ?? '');
    final imeiCtrl = TextEditingController(text: p.imei ?? '');
    final supplierCtrl = TextEditingController(text: p.supplier ?? '');
    final costCtrl = TextEditingController(text: p.cost != null ? NumberFormat('#,###').format(p.cost) : '');
    final priceCtrl = TextEditingController(text: p.price != null ? NumberFormat('#,###').format(p.price) : '');
    final quantityCtrl = TextEditingController(text: (p.quantity ?? 1).toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chỉnh sửa sản phẩm'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValidatedTextField(
                controller: nameCtrl,
                label: 'Tên sản phẩm',
                uppercase: true,
                customValidator: (val) => val?.isEmpty ?? true ? 'Vui lòng nhập tên sản phẩm' : null,
              ),
              const SizedBox(height: 12),
              ValidatedTextField(
                controller: capacityCtrl,
                label: 'Chi tiết máy',
              ),
              const SizedBox(height: 12),
              ValidatedTextField(
                controller: imeiCtrl,
                label: 'IMEI/Serial',
              ),
              const SizedBox(height: 12),
              ValidatedTextField(
                controller: supplierCtrl,
                label: 'Nhà cung cấp',
              ),
              const SizedBox(height: 12),
              CurrencyTextField(
                controller: costCtrl,
                label: 'Giá nhập (VNĐ)',
              ),
              const SizedBox(height: 12),
              CurrencyTextField(
                controller: priceCtrl,
                label: 'Giá bán (VNĐ)',
              ),
              const SizedBox(height: 12),
              ValidatedTextField(
                controller: quantityCtrl,
                label: 'Số lượng',
                keyboardType: TextInputType.number,
                customValidator: (val) {
                  final qty = int.tryParse(val ?? '');
                  if (qty == null || qty < 0) return 'Số lượng phải là số không âm';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validate form
              final qty = int.tryParse(quantityCtrl.text);
              if (qty == null || qty < 0) {
                NotificationService.showSnackBar('Số lượng không hợp lệ', color: Colors.red);
                return;
              }

              try {
                final updatedProduct = p.copyWith(
                  name: nameCtrl.text.trim().toUpperCase(),
                  capacity: capacityCtrl.text.trim(),
                  imei: imeiCtrl.text.trim(),
                  supplier: supplierCtrl.text.trim(),
                  cost: int.tryParse(costCtrl.text.replaceAll(',', '')),
                  price: int.tryParse(priceCtrl.text.replaceAll(',', '')),
                  quantity: qty,
                  updatedAt: DateTime.now().millisecondsSinceEpoch,
                  isSynced: false,
                );

                await db.updateProduct(updatedProduct);
                await _refresh();
                Navigator.pop(ctx);
                NotificationService.showSnackBar('Đã cập nhật sản phẩm', color: Colors.green);
              } catch (e) {
                NotificationService.showSnackBar('Lỗi cập nhật sản phẩm: $e', color: Colors.red);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Widget _detailItem(String l, String v, {Color? color}) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.blueGrey, fontSize: 13)), Text(v, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color))]));

  Color _getBrandColor(String name) {
    String n = name.toUpperCase();
    if (n.startsWith("IP-")) return Colors.blueGrey; // iPhone
    if (n.startsWith("SS-")) return Colors.blue; // Samsung
    if (n.startsWith("PIN-")) return Colors.green; // Pin/Linh kiện
    if (n.startsWith("MH-")) return Colors.orange; // Máy khác
    if (n.startsWith("PK-")) return Colors.purple; // Phụ kiện
    // Fallback cho tên cũ
    if (n.contains("IPHONE")) return Colors.blueGrey;
    if (n.contains("SAMSUNG")) return Colors.blue;
    if (n.contains("OPPO")) return Colors.green;
    if (n.contains("XIAOMI") || n.contains("REDMI")) return Colors.orange;
    return const Color(0xFF2962FF);
  }



  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]), const SizedBox(height: 10), const Text("KHO HÀNG ĐANG TRỐNG", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))]));
  }

  Future<void> _init() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() {
      _isAdmin = perms['allowViewInventory'] ?? false;
      _hasInventoryAccess = perms['allowViewInventory'] ?? false;
    });
    _refresh();
  }

  Future<void> _initCheckData() async {
    await _loadOrCreateCurrentCheck();
    await _loadCheckItems();
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    final data = await db.getInStockProducts();
    final suppliers = await db.getSuppliers();
    if (!mounted) return;
    setState(() { _products = data; _suppliers = suppliers; _isLoading = false; });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÁC NHẬN XÓA"),
        content: Text("Bạn có chắc chắn muốn xóa ${_selectedIds.length} mặt hàng đã chọn không?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("XÓA NGAY", style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        final userName = user?.email?.split('@').first.toUpperCase() ?? "ADMIN";
        for (int id in _selectedIds) {
          final p = _products.firstWhere((element) => element.id == id);
          await db.logAction(userId: user?.uid ?? "0", userName: userName, action: "XÓA KHO", type: "PRODUCT", targetId: p.imei, desc: "Đã xóa ${p.name} (IMEI: ${p.imei})");
          await db.deleteProduct(id);
          if (p.firestoreId != null) await FirestoreService.deleteProduct(p.firestoreId!);
        }
        HapticFeedback.mediumImpact();
        _refresh();
      } catch (e) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleSelection(int id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  // ===== INVENTORY CHECK METHODS =====
  Future<void> _loadOrCreateCurrentCheck() async {
    try {
      final checks = await db.getInventoryChecks();
      final today = DateTime.now();
      final todayKey = DateFormat('yyyy-MM-dd').format(today);

      // Find today's check or create new one
      _currentCheck = checks.cast<InventoryCheck?>().firstWhere(
        (check) => check != null && DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(check.createdAt)) == todayKey,
        orElse: () => null,
      );

      if (_currentCheck == null) {
        _currentCheck = InventoryCheck(
          checkType: _selectedType,
          checkDate: today.millisecondsSinceEpoch,
          checkedBy: FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
          items: [],
          createdAt: today.millisecondsSinceEpoch,
        );
        await db.insertInventoryCheck(_currentCheck!.toMap());
      }
    } catch (e) {
      print('Error loading current check: $e');
    }
  }

  Future<void> _loadCheckItems() async {
    setState(() => _isCheckingLoading = true);
    try {
      _items = await db.getItemsForInventoryCheck(_selectedType);
      _updateCheckItems();
    } catch (e) {
      NotificationService.showSnackBar('Lỗi tải danh sách: $e', color: Colors.red);
    } finally {
      setState(() => _isCheckingLoading = false);
    }
  }

  void _updateCheckItems() {
    _checkItems = _items.map((item) {
      final existingItem = _currentCheck?.items.firstWhere(
        (checkItem) => checkItem.itemId == item['id'].toString(),
        orElse: () => InventoryCheckItem(
          itemId: item['id'].toString(),
          itemName: item['name'] ?? '',
          itemType: _selectedType,
          imei: item['imei'],
          quantity: item['quantity'] ?? 0,
        ),
      );
      return existingItem ?? InventoryCheckItem(
        itemId: item['id'].toString(),
        itemName: item['name'] ?? '',
        itemType: _selectedType,
        imei: item['imei'],
        quantity: item['quantity'] ?? 0,
      );
    }).toList();
  }

  void _updateItemQuantity(String itemId, int quantity) {
    quantity = quantity < 0 ? 0 : quantity;
    setState(() {
      final index = _checkItems.indexWhere((item) => item.itemId == itemId);
      if (index != -1) {
        _checkItems[index] = InventoryCheckItem(
          itemId: _checkItems[index].itemId,
          itemName: _checkItems[index].itemName,
          itemType: _checkItems[index].itemType,
          imei: _checkItems[index].imei,
          color: _checkItems[index].color,
          quantity: quantity,
          isChecked: quantity > 0,
          checkedAt: quantity > 0 ? DateTime.now().millisecondsSinceEpoch : 0,
        );
      }
    });
  }

  Future<void> _saveCheck() async {
    if (_currentCheck == null) return;

    setState(() => _isCheckingLoading = true);
    try {
      _currentCheck = InventoryCheck(
        id: _currentCheck!.id,
        firestoreId: _currentCheck!.firestoreId,
        checkType: _currentCheck!.checkType,
        checkDate: _currentCheck!.checkDate,
        checkedBy: _currentCheck!.checkedBy,
        items: _checkItems,
        isCompleted: true,
        isSynced: _currentCheck!.isSynced,
        createdAt: _currentCheck!.createdAt,
      );

      await db.updateInventoryCheck(_currentCheck!.toMap());
      NotificationService.showSnackBar('Đã lưu kiểm kho thành công!', color: Colors.green);
    } catch (e) {
      NotificationService.showSnackBar('Lỗi lưu kiểm kho: $e', color: Colors.red);
    } finally {
      setState(() => _isCheckingLoading = false);
    }
  }

  void _onQRDetected(BarcodeCapture capture) {
    final barcode = capture.barcodes.first;
    if (barcode.rawValue != null) {
      final imei = barcode.rawValue!;
      final item = _checkItems.firstWhere(
        (item) => item.imei == imei,
        orElse: () => InventoryCheckItem(
          itemId: imei,
          itemName: 'Sản phẩm quét: $imei',
          itemType: _selectedType,
          quantity: 1,
          isChecked: true,
          checkedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      if (!item.isChecked) {
        _updateItemQuantity(item.itemId, item.quantity + 1);
        HapticFeedback.vibrate();
        NotificationService.showSnackBar('Đã quét: ${item.itemName}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kiểm tra quyền truy cập
    if (!_hasInventoryAccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("QUẢN LÝ KHO TỔNG"),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "Bạn không có quyền truy cập\nmàn hình quản lý kho",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(
          "QUẢN LÝ KHO",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: _titleFontSize, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () { HapticFeedback.mediumImpact(); Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateSaleView())).then((_) => _refresh()); },
            icon: const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.pinkAccent),
            tooltip: 'Bán hàng nhanh',
          ),
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GlobalSearchView(role: widget.role))),
            icon: const Icon(Icons.search, color: Color(0xFF9C27B0)),
            tooltip: 'Tìm kiếm toàn app',
          ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: Colors.blue),
            tooltip: 'Làm mới',
          ),
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierView())).then((_) => _refresh()),
            icon: const Icon(Icons.business_center, size: 18, color: Colors.black87),
            label: const Text('NCC', style: TextStyle(fontSize: 12, color: Colors.black87)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
          ),
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickInputLibraryView())),
            icon: const Icon(Icons.library_books, color: Colors.teal),
            tooltip: 'Thư viện mã nhập nhanh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInventoryTab(),
              ],
            ),
          ),
          // Bottom navigation row (KIỂM KHO removed)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Thư viện mã nhập nhanh button (primary)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickInputLibraryView())).then((_) => _refresh()),
                    icon: Icon(Icons.library_books, size: _iconSize),
                    label: Text("THƯ VIỆN", style: TextStyle(fontSize: _smallFontSize)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2962FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      minimumSize: Size(double.infinity, _btnMinHeight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Nhập kho nhanh button (thu nhỏ)
                SizedBox(
                  width: 84,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockInView())).then((_) => _refresh()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2962FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                      minimumSize: Size(0, _btnMinHeight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_box_rounded, size: _iconSize - 4),
                        const SizedBox(height: 2),
                        Text("NHẬP KHO", style: TextStyle(fontSize: _smallFontSize)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Nhập nhanh button
                SizedBox(
                  width: 84,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FastStockInView())).then((_) => _refresh()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 3, 57, 255),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                      minimumSize: Size(0, _btnMinHeight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flash_on, size: _iconSize - 4),
                        const SizedBox(height: 2),
                        Text("NHẬP NHANH", style: TextStyle(fontSize: _smallFontSize - 2)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTab() {
    final filteredList = _products.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || (p.imei ?? "").contains(_searchQuery)).toList();
    int totalQty = filteredList.length;
    int totalCapital = filteredList.fold(0, (sum, item) => sum + item.cost);

    return Stack(
      children: [
        Column(
          children: [
            // App Bar Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (_isSelectionMode) ...[
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() {
                        _isSelectionMode = false;
                        _selectedIds.clear();
                      }),
                    ),
                    Text(
                      "ĐÃ CHỌN ${_selectedIds.length}",
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _deleteSelected,
                      icon: const Icon(Icons.delete_forever, color: Colors.red, size: 28),
                    ),
                  ] else ...[
                    // Quick action buttons moved to AppBar; keep header minimal
                    const Spacer(),
                  ],
                ],
              ),
            ),

            // Summary Section
            if (!_isSelectionMode) _buildInventorySummary(totalQty, totalCapital),

            // Search Box
            _buildSearchBox(),

            // Product List
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredList.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: filteredList.length,
                        itemBuilder: (ctx, i) => _buildProfessionalCard(filteredList[i])
                      )
                    )
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInventoryCheckTab() {
    return Column(
      children: [
        // Type selector and Scanner Controls
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 8)],
          ),
          child: Column(
            children: [
              // Type selector
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: InputDecoration(
                  labelText: "Loại sản phẩm kiểm kho",
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: "PHONE", child: Text("📱 Điện thoại")),
                  DropdownMenuItem(value: "ACCESSORY", child: Text("🔧 Phụ kiện")),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                    _initCheckData();
                  }
                },
              ),

              const SizedBox(height: 16),

              // Scanner Controls
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _isScanning = !_isScanning);
                        if (_isScanning) {
                          _scannerController.start();
                        } else {
                          _scannerController.stop();
                        }
                      },
                      icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow, size: _iconSize),
                      label: Text(_isScanning ? "DỪNG SCAN" : "BẮT ĐẦU SCAN", style: TextStyle(fontSize: _smallFontSize)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isScanning ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size(double.infinity, _btnMinHeight),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () => _scannerController.toggleTorch(),
                    icon: const Icon(Icons.flashlight_on),
                    tooltip: "Bật/tắt đèn flash",
                  ),
                ],
              ),
            ],
          ),
        ),

        // QR Scanner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _isScanning ? Colors.transparent : Colors.black,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _isScanning
              ? MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) => _onQRDetected(capture),
                )
              : Container(
                  color: Colors.black,
                  child: const Center(
                    child: Text(
                      "Camera chưa được khởi động",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
          ),
        ),

        // Progress Summary
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 8)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _progressItem("Tổng sản phẩm", _checkItems.length.toString(), Icons.inventory),
              _progressItem("Đã kiểm", _checkItems.where((item) => item.isChecked).length.toString(), Icons.check_circle, Colors.green),
              _progressItem("Chưa kiểm", _checkItems.where((item) => !item.isChecked).length.toString(), Icons.radio_button_unchecked, Colors.orange),
            ],
          ),
        ),

        // Check items list
        Expanded(
          child: _isCheckingLoading
            ? const Center(child: CircularProgressIndicator())
            : _checkItems.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        "Chưa có dữ liệu kiểm kho",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _checkItems.length,
                  itemBuilder: (context, index) {
                    final item = _checkItems[index];
                    final isComplete = item.isChecked;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(
                          item.itemName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("IMEI: ${item.imei ?? 'N/A'}"),
                            Text(
                              "SL hiện tại: ${item.quantity}",
                              style: TextStyle(
                                color: isComplete ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: item.quantity > 0
                                ? () => _updateItemQuantity(item.itemId, item.quantity - 1)
                                : null,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isComplete ? Colors.green.withAlpha(25) : Colors.grey.withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "${item.quantity}",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isComplete ? Colors.green : Colors.grey,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => _updateItemQuantity(item.itemId, item.quantity + 1),
                            ),
                          ],
                        ),
                        leading: Icon(
                          isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isComplete ? Colors.green : Colors.grey,
                          size: _iconSize,
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Save button
        Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _saveCheck,
            icon: const Icon(Icons.save),
            label: const Text("LƯU KIỂM KHO"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2962FF),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInventorySummary(int qty, int capital) {
    final fmt = NumberFormat('#,###');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF2962FF)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.blue.withAlpha(46), blurRadius: 6, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _summaryItemCompact("TỔNG KHO", "$qty", Icons.inventory),
          Container(width: 1, height: 36, color: Colors.white24),
          _summaryItemCompact("VỐN TỒN KHO", "${fmt.format(capital)} đ", Icons.account_balance_wallet),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String val, IconData icon) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: Colors.white70, size: 14), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold))]), const SizedBox(height: 4), Text(val, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))]);
  }

  // Compact summary used in the smaller header
  Widget _summaryItemCompact(String label, String val, IconData icon) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: Colors.white70, size: 12), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w700))]), const SizedBox(height: 2), Text(val, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800))]);
  }

  Widget _progressItem(String label, String val, IconData icon, [Color? color]) {
    return Column(
      children: [
        Icon(icon, color: color ?? const Color(0xFF2962FF), size: 24),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(
            color: color ?? const Color(0xFF2962FF),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: "Tìm máy, phụ kiện hoặc IMEI...",
          prefixIcon: const Icon(Icons.search, color: Color(0xFF2962FF)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildProfessionalCard(Product p) {
    final bool isSelected = _selectedIds.contains(p.id);
    final fmt = NumberFormat('#,###');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.red : Colors.transparent,
          width: 2,
        ),
      ),
      elevation: 2,
      child: InkWell(
        onLongPress: () {
          HapticFeedback.heavyImpact();
          // Check if user is owner or manager for edit functionality
          if (widget.role == 'owner' || widget.role == 'manager' || UserService.isCurrentUserSuperAdmin()) {
            _showEditProductDialog(p);
          } else {
            _toggleSelection(p.id!);
          }
        },
        onTap: () => _isSelectionMode ? _toggleSelection(p.id!) : _showProductDetail(p),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(_cardPadding),
          child: Row(
            children: [
              // Brand Icon
              Container(
                padding: EdgeInsets.all(_cardPadding - 2),
                decoration: BoxDecoration(
                  color: _getBrandColor(p.name).withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  p.type == 'PHONE' ? Icons.phone_iphone : Icons.headset_mic,
                  color: _getBrandColor(p.name),
                  size: _iconSize,
                ),
              ),

              SizedBox(width: _pad),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: _titleFontSize - 2,
                        color: const Color(0xFF1A237E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),                    const SizedBox(height: 4),
                    Text(
                      p.capacity ?? "Chi tiết trống",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.fingerprint, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            p.imei ?? "N/A",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Price and Quantity
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${fmt.format(p.price)} đ",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: _smallFontSize + 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "TỒN: ${p.quantity}",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: _smallFontSize - 1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              // Selection indicator
              if (isSelected) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.check_circle,
                  color: Colors.red,
                  size: 24,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }



  void _showAddProductDialog() {
    final nameC = TextEditingController(); final imeiC = TextEditingController();
    final costC = TextEditingController();
    final priceC = TextEditingController();
    final detailC = TextEditingController();
    final qtyC = TextEditingController(text: "1");
    final nameF = FocusNode(); final imeiF = FocusNode(); final costF = FocusNode();
    final priceF = FocusNode(); final qtyF = FocusNode();
    
    // SKU fields
    String selectedNhom = 'IP'; // Default nhóm
    final modelC = TextEditingController();
    final thongtinC = TextEditingController();
    final skuC = TextEditingController(); // Generated SKU display/edit
    final skuF = FocusNode();
    
    String type = "PHONE"; String payMethod = "TIỀN MẶT";
    String? supplier = _suppliers.isNotEmpty ? _suppliers.first['name'] as String : null;
    bool isSaving = false;

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      Future<void> generateSKU() async {
        if (selectedNhom.isEmpty) {
          NotificationService.showSnackBar("Vui lòng chọn nhóm sản phẩm!", color: Colors.red);
          return;
        }
        
        try {
          final generatedSKU = await SKUGenerator.generateSKU(
            nhom: selectedNhom,
            model: modelC.text.trim().isNotEmpty ? modelC.text.trim() : null,
            thongtin: thongtinC.text.trim().isNotEmpty ? thongtinC.text.trim() : null,
            dbHelper: db,
            firestoreService: null,
          );
          
          setS(() => skuC.text = generatedSKU);
          NotificationService.showSnackBar("Đã tạo mã hàng: $generatedSKU", color: Colors.blue);
        } catch (e) {
          NotificationService.showSnackBar("Lỗi tạo mã hàng: $e", color: Colors.red);
        }
      }

      Future<void> saveProcess({bool next = false}) async {
        if (skuC.text.isEmpty) { 
          NotificationService.showSnackBar("Vui lòng tạo mã hàng trước!", color: Colors.red); 
          return; 
        }
        if (supplier == null) { 
          NotificationService.showSnackBar("Vui lòng chọn Nhà cung cấp!", color: Colors.red); 
          return; 
        }
        if (isSaving) return; setS(() => isSaving = true);
        try {
          int parseK(String t) { final c = t.replaceAll('.', '').replaceAll(RegExp(r'[^\d]'), ''); int v = int.tryParse(c) ?? 0; return (v > 0 && v < 100000) ? v * 1000 : v; }
          final int ts = DateTime.now().millisecondsSinceEpoch;
          final String imei = imeiC.text.trim();
          final String fId = "prod_${ts}_${imei.isNotEmpty ? imei : ts}";
          final p = Product(firestoreId: fId, name: skuC.text.toUpperCase(), model: modelC.text.trim().isNotEmpty ? modelC.text.trim() : null, imei: imei, cost: parseK(costC.text), price: parseK(priceC.text), capacity: detailC.text.toUpperCase(), quantity: int.tryParse(qtyC.text) ?? 1, type: type, createdAt: ts, supplier: supplier, status: 1);
          final user = FirebaseAuth.instance.currentUser;
          final userName = user?.email?.split('@').first.toUpperCase() ?? "NV";
          await db.logAction(userId: user?.uid ?? "0", userName: userName, action: "NHẬP KHO", type: "PRODUCT", targetId: p.imei, desc: "Đã nhập máy ${p.name}");
          if (payMethod != "CÔNG NỢ") {
            await db.insertExpense({'title': "NHẬP HÀNG: ${p.name}", 'amount': p.cost * p.quantity, 'category': "NHẬP HÀNG", 'date': ts, 'paymentMethod': payMethod, 'note': "Nhập từ $supplier"});
          } else {
            await db.insertDebt({'personName': supplier, 'totalAmount': p.cost * p.quantity, 'paidAmount': 0, 'type': "SHOP_OWES", 'status': "unpaid", 'createdAt': ts, 'note': "Nợ tiền máy ${p.name}"});
          }
          await db.upsertProduct(p); await FirestoreService.addProduct(p);

          // Lưu lịch sử nhập hàng từ nhà cung cấp
          if (supplier?.isNotEmpty == true) {
            final suppliers = await db.getSuppliers();
            final supplierData = suppliers.firstWhere((s) => s['name'] == supplier, orElse: () => {});
            final supplierId = supplierData['id'];
            if (supplierId != null) {
              final importHistory = {
                'firestoreId': "import_${ts}_${p.imei ?? ts}",
                'supplierId': supplierId,
                'supplierName': supplier,
                'productName': p.name,
                'productBrand': p.brand ?? '',
                'productModel': p.model,
                'imei': p.imei,
                'quantity': p.quantity,
                'costPrice': p.cost,
                'totalAmount': p.cost * p.quantity,
                'paymentMethod': payMethod,
                'importDate': ts,
                'importedBy': userName,
                'notes': 'Nhập từ Inventory View',
                'isSynced': 0,
              };
              await db.insertSupplierImportHistory(importHistory);

              // Cập nhật giá nhà cung cấp
              await db.deactivateSupplierProductPrice(supplierId, p.name, p.brand ?? '', p.model);
              final supplierPrice = {
                'supplierId': supplierId,
                'productName': p.name,
                'productBrand': p.brand ?? '',
                'productModel': p.model,
                'costPrice': p.cost,
                'lastUpdated': ts,
                'createdAt': ts,
                'isActive': 1,
              };
              await db.insertSupplierProductPrice(supplierPrice);

              // Cập nhật thống kê nhà cung cấp
              await db.updateSupplierStats(supplierId);
            }
          }

          HapticFeedback.lightImpact();
          if (next) { imeiC.clear(); setS(() => isSaving = false); if (mounted) { FocusScope.of(context).requestFocus(imeiF); NotificationService.showSnackBar("ĐÃ THÊM MÁY", color: Colors.blue); } }
          else { if (mounted) { Navigator.of(context).pop(); _refresh(); NotificationService.showSnackBar("NHẬP KHO THÀNH CÔNG", color: Colors.green); } }
        } catch (e) { setS(() => isSaving = false); }
      }
      return AlertDialog(
        title: const Text("NHẬP KHO SIÊU TỐC", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2962FF))),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Loại hàng
          DropdownButtonFormField<String>(
            initialValue: type,
            items: const [
              DropdownMenuItem(value: "PHONE", child: Text("ĐIỆN THOẠI")),
              DropdownMenuItem(value: "ACCESSORY", child: Text("PHỤ KIỆN"))
            ],
            onChanged: (v) => setS(() => type = v!),
            decoration: const InputDecoration(labelText: "Loại hàng")
          ),

          // Tên máy
          _input(nameC, "Tên máy *", Icons.phone_android, f: nameF, next: imeiF, caps: true),

          // Chi tiết
          _input(detailC, "Chi tiết (Dung lượng - Màu...)", Icons.info_outline, caps: true),

          // IMEI/Serial
          _input(imeiC, "Số IMEI / Serial", Icons.fingerprint, f: imeiF, next: costF, type: TextInputType.number),

          // Giá vốn
          _input(costC, "Giá vốn (k)", Icons.money, f: costF, next: priceF, type: TextInputType.number, suffix: "k"),

          // Giá bán
          _input(priceC, "Giá bán (k)", Icons.sell, f: priceF, next: qtyF, type: TextInputType.number, suffix: "k"),

          // Số lượng và Nhà cung cấp
          Row(children: [
            Expanded(flex: 1, child: _input(qtyC, "SL", Icons.add_box, f: qtyF, isBig: true)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: DropdownButtonFormField<String>(
              initialValue: supplier,
              isExpanded: true,
              decoration: const InputDecoration(labelText: "Nhà cung cấp *"),
              items: _suppliers.map((s) => DropdownMenuItem(value: s['name'] as String, child: Text(s['name']))).toList(),
              onChanged: (v) => setS(() => supplier = v)
            ))
          ]),
          
          // SKU Section
          const Divider(height: 30, thickness: 1),
          const Text("MÃ HÀNG", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2962FF))),
          const SizedBox(height: 10),

          // Nhóm
          DropdownButtonFormField<String>(
            initialValue: selectedNhom,
            decoration: const InputDecoration(labelText: "Nhóm *", prefixIcon: Icon(Icons.category, size: 18)),
            items: const [
              DropdownMenuItem(value: "IP", child: Text("IP - iPhone")),
              DropdownMenuItem(value: "SS", child: Text("SS - Samsung")),
              DropdownMenuItem(value: "PIN", child: Text("PIN - Pin sạc")),
              DropdownMenuItem(value: "MH", child: Text("MH - Màn hình")),
              DropdownMenuItem(value: "PK", child: Text("PK - Phụ kiện")),
            ],
            onChanged: (v) => setS(() => selectedNhom = v!),
          ),

          // Model
          _input(modelC, "Model (vd: IP12PM)", Icons.smartphone, caps: true),

          // Thông tin
          _input(thongtinC, "Thông tin (vd: 256GB)", Icons.info, caps: true),

          // Mã hàng và nút tạo
          Row(children: [
            Expanded(flex: 2, child: _input(skuC, "Mã hàng được tạo", Icons.qr_code, f: skuF, caps: true, readOnly: true)),
            const SizedBox(width: 8),
            Expanded(flex: 1, child: ElevatedButton.icon(
              onPressed: () => generateSKU(),
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: const Text("TẠO MÃ"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2962FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            )),
          ]),
          
          const SizedBox(height: 15),
          Wrap(spacing: 8, children: ["TIỀN MẶT", "CHUYỂN KHOẢN", "CÔNG NỢ"].map((m) => ChoiceChip(label: Text(m, style: const TextStyle(fontSize: 11)), selected: payMethod == m, onSelected: (v) => setS(() => payMethod = m), selectedColor: Colors.blueAccent)).toList()),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")), OutlinedButton(onPressed: isSaving ? null : () => saveProcess(next: true), child: const Text("NHẬP TIẾP")), ElevatedButton(onPressed: isSaving ? null : () => saveProcess(), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF)), child: const Text("HOÀN TẤT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))],
      );
    }));
  }
}
