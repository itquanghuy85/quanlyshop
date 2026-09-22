// Dialog chọn linh kiện dùng chung (2026-09-22): tách từ
// `repair_detail_view._PartsSelectionDialog` để dùng cả ở đơn sửa lẫn
// Sửa/Tân trang sản phẩm trong kho — cùng nguồn `getAllPartsUnified()`
// (repair_parts + products LINH_KIEN), cùng giao diện.
// Trả về Map<"source_id", qty>.
import 'package:flutter/material.dart';
import '../utils/money_utils.dart';
import '../l10n/app_localizations.dart';
import '../data/db_helper.dart';
import '../theme/app_text_styles.dart';

class PartsSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> parts;
  final Future<void> Function() onOpenPartsInventory;

  const PartsSelectionDialog({
    required this.parts,
    required this.onOpenPartsInventory,
  });

  @override
  State<PartsSelectionDialog> createState() => PartsSelectionDialogState();
}

class PartsSelectionDialogState extends State<PartsSelectionDialog> {
  AppLocalizations get loc => AppLocalizations.of(context)!;
  final TextEditingController _searchCtrl = TextEditingController();
  final Map<String, int> selectedQuantities = {};

  int get totalSelected => selectedQuantities.values.fold(0, (a, b) => a + b);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _searchCtrl.text.trim().toLowerCase();
    final filteredParts = widget.parts.where((p) {
      if (keyword.isEmpty) return true;
      final name = (p['partName'] ?? '').toString().toLowerCase();
      final supplier = (p['supplier'] ?? p['supplierName'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(keyword) || supplier.contains(keyword);
    }).toList();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.inventory_2, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(loc.selectPartsTitle, style: AppTextStyles.headline3),
          ),
          // Shortcut to add new part from PartsInventoryView
          Material(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                await widget.onOpenPartsInventory();
                // Refresh parts list after returning from PartsInventoryView
                if (mounted) {
                  final db = DBHelper();
                  final updatedParts = await db.getAllPartsUnified();
                  if (mounted) {
                    setState(() {
                      widget.parts
                        ..clear()
                        ..addAll(updatedParts);
                    });
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle,
                      color: Colors.orange.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'NHẬP LK MỚI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 460,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: loc.searchPartOrSupplier,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filteredParts.isEmpty
                  ? Center(
                      child: Text(
                        loc.noPartsFound,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredParts.length,
                      itemBuilder: (context, index) {
                        final part = filteredParts[index];
                        final partId = part['id'] as int;
                        final source = part['source'] as String;
                        final uniqueKey = "${source}_$partId";
                        final partName = part['partName'] ?? '';
                        final partQty = part['quantity'] as int? ?? 0;
                        final partCost = part['cost'] as int? ?? 0;
                        final partPrice = part['price'] as int? ?? 0;
                        final supplier =
                            (part['supplier'] ?? part['supplierName'] ?? '')
                                .toString();
                        final isFromProducts = source == 'products';
                        final currentQty = selectedQuantities[uniqueKey] ?? 0;

                        return Card(
                          color: currentQty > 0
                              ? Colors.green.shade50
                              : (isFromProducts ? Colors.blue.shade50 : null),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Dòng 1: Icon + Tên + Tag nguồn
                                Row(
                                  children: [
                                    Icon(
                                      isFromProducts
                                          ? Icons.inventory
                                          : Icons.build,
                                      color: isFromProducts
                                          ? Colors.blue
                                          : Colors.blue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        partName,
                                        style: AppTextStyles.subtitle1.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isFromProducts
                                            ? Colors.blue.withOpacity(0.2)
                                            : Colors.blue.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isFromProducts
                                            ? loc.mainWarehouse
                                            : loc.oldWarehouse,
                                        style: AppTextStyles.caption.copyWith(
                                          color: isFromProducts
                                              ? Colors.blue
                                              : Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Dòng 2: Supplier + tồn + giá
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (supplier.isNotEmpty)
                                      Chip(
                                        label: Text(
                                          supplier,
                                          style: AppTextStyles.caption,
                                        ),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    Text(
                                      loc.stockQty(partQty),
                                      style: AppTextStyles.body2.copyWith(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    Text(
                                      loc.costPrice(
                                        MoneyUtils.formatCurrency(partCost),
                                      ),
                                      style: AppTextStyles.caption,
                                    ),
                                    Text(
                                      loc.sellPrice(
                                        MoneyUtils.formatCurrency(partPrice),
                                      ),
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Dòng 3: Nút +/- (compact hơn)
                                if (partQty > 0)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Nút trừ (nhỏ gọn hơn)
                                      Material(
                                        color: currentQty > 0
                                            ? Colors.red
                                            : Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(5),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                          onTap: currentQty > 0
                                              ? () {
                                                  setState(() {
                                                    if (currentQty <= 1) {
                                                      selectedQuantities.remove(
                                                        uniqueKey,
                                                      );
                                                    } else {
                                                      selectedQuantities[uniqueKey] =
                                                          currentQty - 1;
                                                    }
                                                  });
                                                }
                                              : null,
                                          child: Container(
                                            width: 26,
                                            height: 22,
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.remove,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Số lượng
                                      Container(
                                        width: 38,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$currentQty',
                                          style: AppTextStyles.caption.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: currentQty > 0
                                                ? Colors.green.shade700
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                      // Nút cộng (nhỏ gọn hơn)
                                      Material(
                                        color: currentQty < partQty
                                            ? Colors.green
                                            : Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(5),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                          onTap: currentQty < partQty
                                              ? () {
                                                  setState(() {
                                                    selectedQuantities[uniqueKey] =
                                                        currentQty + 1;
                                                  });
                                                }
                                              : null,
                                          child: Container(
                                            width: 26,
                                            height: 22,
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.add,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      loc.outOfStock,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(loc.cancel),
        ),
        ElevatedButton(
          onPressed: totalSelected > 0
              ? () => Navigator.pop(
                  context,
                  Map<String, int>.from(selectedQuantities),
                )
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          child: Text(
            totalSelected > 0 ? loc.confirmQty(totalSelected) : loc.confirmBtn,
            style: TextStyle(
              color: totalSelected > 0 ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}
