import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/db_helper.dart';
import '../models/product_model.dart';
import '../services/notification_service.dart';

class FastInventoryCheckView extends StatefulWidget {
  const FastInventoryCheckView({super.key});

  @override
  State<FastInventoryCheckView> createState() => _FastInventoryCheckViewState();
}

class _FastInventoryCheckViewState extends State<FastInventoryCheckView> {
  final db = DBHelper();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String _selectedType = 'PHONE';
  bool _isScanning = false;
  final MobileScannerController _scannerController = MobileScannerController();

  // Track checked products
  final Set<String> _checkedProductIds = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await db.getInStockProducts();
      if (mounted) {
        setState(() {
          _products = products;
          _filterProducts();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showSnackBar('Lỗi tải sản phẩm: $e', color: Colors.red);
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterProducts() {
    _filteredProducts = _products.where((product) => product.type == _selectedType).toList();
  }

  void _toggleProductCheck(Product product) {
    final productKey = product.imei ?? product.firestoreId ?? product.id.toString();
    setState(() {
      if (_checkedProductIds.contains(productKey)) {
        _checkedProductIds.remove(productKey);
      } else {
        _checkedProductIds.add(productKey);
      }
    });
    HapticFeedback.lightImpact();
  }

  void _onQRDetected(BarcodeCapture capture) {
    final barcode = capture.barcodes.first;
    if (barcode.rawValue != null) {
      final scannedCode = barcode.rawValue!;
      final product = _filteredProducts.firstWhere(
        (p) => p.imei == scannedCode || p.firestoreId == scannedCode,
        orElse: () => Product(
          name: 'Không tìm thấy sản phẩm',
          brand: '',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          type: _selectedType,
        ),
      );

      if (product.imei != null || product.firestoreId != null) {
        final productKey = product.imei ?? product.firestoreId!;
        if (!_checkedProductIds.contains(productKey)) {
          _toggleProductCheck(product);
          NotificationService.showSnackBar('✅ Đã tick: ${product.name}');
        } else {
          NotificationService.showSnackBar('⚠️ Sản phẩm đã được tick: ${product.name}');
        }
      } else {
        NotificationService.showSnackBar('❌ Không tìm thấy sản phẩm với mã: $scannedCode', color: Colors.orange);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KIỂM KHO NHANH'),
        backgroundColor: const Color(0xFF2962FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.qr_code_scanner),
            onPressed: () {
              setState(() => _isScanning = !_isScanning);
              if (_isScanning) {
                _scannerController.start();
              } else {
                _scannerController.stop();
              }
            },
            tooltip: _isScanning ? 'Dừng scan' : 'Bắt đầu scan',
          ),
          if (_isScanning)
            IconButton(
              icon: const Icon(Icons.flashlight_on),
              onPressed: () => _scannerController.toggleTorch(),
              tooltip: 'Bật/tắt đèn flash',
            ),
        ],
      ),
      body: Column(
        children: [
          // Type selector
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
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: "Loại sản phẩm",
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: "PHONE", child: Text("📱 Điện thoại")),
                    DropdownMenuItem(value: "ACCESSORY", child: Text("🔧 Phụ kiện")),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedType = value;
                        _filterProducts();
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Progress summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _progressItem("Tổng", _filteredProducts.length.toString(), Icons.inventory),
                    _progressItem("Đã tick", _checkedProductIds.length.toString(), Icons.check_circle, Colors.green),
                    _progressItem("Chưa tick", (_filteredProducts.length - _checkedProductIds.length).toString(), Icons.radio_button_unchecked, Colors.orange),
                  ],
                ),
              ],
            ),
          ),

          // QR Scanner (when active)
          if (_isScanning)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.black,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: _onQRDetected,
                ),
              ),
            ),

          // Products list
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredProducts.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          "Không có sản phẩm nào",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      final productKey = product.imei ?? product.firestoreId ?? product.id.toString();
                      final isChecked = _checkedProductIds.contains(productKey);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          onTap: () => _toggleProductCheck(product),
                          title: Text(
                            product.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: isChecked ? TextDecoration.lineThrough : null,
                              color: isChecked ? Colors.grey : Colors.black,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("IMEI/SKU: ${product.imei ?? product.firestoreId ?? 'N/A'}"),
                              Text("SL: ${product.quantity}"),
                              if (product.supplier != null && product.supplier!.isNotEmpty)
                                Text("NCC: ${product.supplier}"),
                            ],
                          ),
                          leading: Icon(
                            isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: isChecked ? Colors.green : Colors.grey,
                            size: 28,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isChecked ? Colors.green.withAlpha(25) : Colors.grey.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isChecked ? "ĐÃ TICK" : "CHƯA TICK",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isChecked ? Colors.green : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _checkedProductIds.clear());
                      NotificationService.showSnackBar('Đã reset tất cả ticks');
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text("RESET"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final checkedCount = _checkedProductIds.length;
                      final totalCount = _filteredProducts.length;
                      NotificationService.showSnackBar(
                        'Hoàn thành: $checkedCount/$totalCount sản phẩm đã tick',
                        color: checkedCount == totalCount ? Colors.green : Colors.blue,
                      );
                    },
                    icon: const Icon(Icons.check),
                    label: const Text("HOÀN THÀNH"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2962FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _progressItem(String label, String value, IconData icon, [Color? color]) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.blue, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.blue,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}