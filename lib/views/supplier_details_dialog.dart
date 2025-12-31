import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';

class SupplierDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> supplier;

  const SupplierDetailsDialog({super.key, required this.supplier});

  @override
  State<SupplierDetailsDialog> createState() => _SupplierDetailsDialogState();
}

class _SupplierDetailsDialogState extends State<SupplierDetailsDialog> with SingleTickerProviderStateMixin {
  final db = DBHelper();
  late TabController _tabController;

  List<Map<String, dynamic>> _importHistory = [];
  List<Map<String, dynamic>> _productPrices = [];
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final supplierId = widget.supplier['id'];
      if (supplierId != null) {
        final history = await db.getSupplierImportHistory(supplierId, limit: 50);
        final prices = await db.getSupplierProductPrices(supplierId);
        final stats = await db.getSupplierImportStats(supplierId);

        setState(() {
          _importHistory = history;
          _productPrices = prices;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading supplier details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.business, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.supplier['name'] ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (_stats != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _statChip('Tổng nhập', '${_stats!['totalImports'] ?? 0} lần'),
                        const SizedBox(width: 8),
                        _statChip('Tổng tiền', '${NumberFormat('#,###').format(_stats!['totalAmount'] ?? 0)} đ'),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Tab bar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Lịch sử nhập hàng', icon: Icon(Icons.history)),
                Tab(text: 'Giá sản phẩm', icon: Icon(Icons.price_change)),
              ],
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
            ),

            // Tab content
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildImportHistoryTab(),
                      _buildProductPricesTab(),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildImportHistoryTab() {
    if (_importHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Chưa có lịch sử nhập hàng', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _importHistory.length,
      itemBuilder: (context, index) {
        final item = _importHistory[index];
        final date = DateTime.fromMillisecondsSinceEpoch(item['importDate']);
        final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['productName'] ?? 'N/A',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('IMEI: ${item['imei'] ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 16),
                    Text('SL: ${item['quantity'] ?? 0}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Giá: ${NumberFormat('#,###').format(item['costPrice'] ?? 0)} đ',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Tổng: ${NumberFormat('#,###').format(item['totalAmount'] ?? 0)} đ',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (item['notes'] != null && item['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Ghi chú: ${item['notes']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductPricesTab() {
    if (_productPrices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.price_change, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Chưa có thông tin giá sản phẩm', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _productPrices.length,
      itemBuilder: (context, index) {
        final price = _productPrices[index];
        final lastUpdated = DateTime.fromMillisecondsSinceEpoch(price['lastUpdated']);
        final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(lastUpdated);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price['productName'] ?? 'N/A',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Thương hiệu: ${price['productBrand'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (price['productModel'] != null) ...[
                      const SizedBox(width: 16),
                      Text(
                        'Model: ${price['productModel']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Giá nhập: ${NumberFormat('#,###').format(price['costPrice'] ?? 0)} đ',
                      style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Cập nhật: $formattedDate',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}