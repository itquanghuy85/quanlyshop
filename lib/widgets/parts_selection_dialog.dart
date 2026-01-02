import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';

class PartsSelectionDialog extends StatefulWidget {
  final List<Product> products;
  final String currentParts;
  
  const PartsSelectionDialog({required this.products, required this.currentParts});
  
  @override
  State<PartsSelectionDialog> createState() => _PartsSelectionDialogState();
}

class _PartsSelectionDialogState extends State<PartsSelectionDialog> {
  final List<Map<String, dynamic>> _selectedParts = [];
  String _searchQuery = "";
  
  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return widget.products;
    return widget.products.where((p) => 
      p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (p.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
    ).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Tooltip(
              message: "Chọn phụ tùng cần dùng cho đơn sửa.",
              child: const Text("CHỌN LINH KIỆN", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: "Tìm linh kiện...",
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Tổng chi phí: ${NumberFormat('#,###').format(_selectedParts.fold<int>(0, (sum, p) => sum + ((p['cost'] as int) * (p['quantity'] as int))))}.000đ",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: _selectedParts.isNotEmpty ? () => Navigator.pop(context, _selectedParts) : null,
                  child: const Text("XÁC NHẬN"),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredProducts.length,
                itemBuilder: (ctx, index) {
                  final product = _filteredProducts[index];
                  final isSelected = _selectedParts.any((p) => p['product'] == product);
                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text("${NumberFormat('#,###').format(product.price)}.000đ"),
                    trailing: isSelected
                        ? IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () => setState(() => _selectedParts.removeWhere((p) => p['product'] == product)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => setState(() => _selectedParts.add({
                              'product': product,
                              'cost': product.price, // Assuming cost is price for simplicity
                              'quantity': 1,
                            })),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}