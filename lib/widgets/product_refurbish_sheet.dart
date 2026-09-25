// Sheet "Tân trang sản phẩm" dùng chung (2026-09-22): Kho → chi tiết SP,
// và lối tắt từ Nhập kho mới / Nhập nhanh sau khi tạo SP.
//
// - Dịch vụ/Đối tác/Khác: ghi chi phí (nợ đối tác hoặc phiếu chi).
// - Linh kiện kho PT: dùng đúng `PartsSelectionDialog` của đơn sửa.
// - Lịch sử: sửa/xoá dịch vụ, đổi/xoá phụ tùng. Sheet KHÔNG tự đóng sau khi
//   lưu — nạp lại lịch sử tại chỗ (yêu cầu 2026-09-22).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/db_helper.dart';
import '../models/product_model.dart';
import '../models/repair_partner_model.dart';
import '../services/notification_service.dart';
import '../services/product_refurbish_service.dart';
import '../services/repair_partner_service.dart';
import '../services/user_service.dart';
import '../theme/app_text_styles.dart';
import '../theme/popup_theme.dart';
import '../utils/money_utils.dart';
import '../views/parts_inventory_view.dart';
import 'currency_text_field.dart';
import 'parts_selection_dialog.dart';

/// Trả về true nếu có thay đổi (caller nên refresh list).
Future<bool> showProductRefurbishSheet(BuildContext context, Product p) async {
  // Nhân viên không có quyền giá vốn VẪN tân trang được (yêu cầu 2026-09-22)
  // — chỉ ẩn các con số giá vốn/chi phí bên trong sheet (CLAUDE.md §9).
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProductRefurbishSheet(product: p),
  );
  return changed == true;
}

class ProductRefurbishSheet extends StatefulWidget {
  final Product product;
  const ProductRefurbishSheet({super.key, required this.product});

  @override
  State<ProductRefurbishSheet> createState() => _ProductRefurbishSheetState();
}

class _ProductRefurbishSheetState extends State<ProductRefurbishSheet> {
  final db = DBHelper();
  late Product p = widget.product;
  int section = 0;
  bool changed = false;

  final descCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  String paymentMethod = 'TIỀN MẶT';
  RepairPartner? selectedPartner;
  List<RepairPartner> partners = [];
  List<Map<String, dynamic>> history = [];
  bool _canViewCost = false; // mặc định ẩn tới khi đọc xong quyền

  @override
  void initState() {
    super.initState();
    UserService.canViewCostPrice().then((v) {
      if (mounted) setState(() => _canViewCost = v);
    });
    RepairPartnerService().getRepairPartners().then((list) {
      if (mounted) setState(() => partners = list);
    });
    _reload();
  }

  @override
  void dispose() {
    descCtrl.dispose();
    amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (p.id == null) return;
    final items = await ProductRefurbishService.getHistory(p.id!);
    final fresh = await db.getProductById(p.id!);
    if (!mounted) return;
    setState(() {
      history = items;
      if (fresh != null) p = fresh;
    });
  }

  void _afterChange(String msg, {Color color = Colors.green}) {
    changed = true;
    NotificationService.showSnackBar(msg, color: color);
    _reload();
  }

  Future<void> _saveService() async {
    final desc = descCtrl.text.trim();
    final amount = CurrencyTextField.parseValue(amountCtrl.text);
    if (desc.isEmpty) {
      NotificationService.showSnackBar('Nhập mô tả dịch vụ/chi phí', color: Colors.orange);
      return;
    }
    if (amount <= 0) {
      NotificationService.showSnackBar('Nhập số tiền hợp lệ', color: Colors.orange);
      return;
    }
    final r = await ProductRefurbishService.addServiceOrOtherCost(
      productId: p.id!,
      productFirestoreId: p.firestoreId,
      description: desc,
      partnerId: selectedPartner?.id,
      partnerName: selectedPartner?.name,
      amount: amount,
      paymentMethod: paymentMethod,
    );
    if (!mounted) return;
    if (r.success) {
      descCtrl.clear();
      amountCtrl.clear();
      _afterChange('✅ Đã ghi ${MoneyUtils.formatCurrency(amount)}đ vào chi phí tân trang');
    } else {
      NotificationService.showSnackBar('❌ ${r.error}', color: Colors.red);
    }
  }

  Future<void> _pickParts() async {
    final allParts = await db.getAllPartsUnified();
    if (!mounted) return;
    final result = await showDialog<Map<String, int>?>(
      context: context,
      builder: (_) => PartsSelectionDialog(
        parts: allParts,
        onOpenPartsInventory: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PartsInventoryView()),
          );
        },
      ),
    );
    if (result == null || result.isEmpty) return;
    int ok = 0;
    final errors = <String>[];
    for (final e in result.entries) {
      final idx = e.key.lastIndexOf('_');
      final source = e.key.substring(0, idx);
      final partId = int.parse(e.key.substring(idx + 1));
      final part = allParts.firstWhere(
        (x) => x['id'] == partId && x['source'] == source,
      );
      final r = await ProductRefurbishService.addPartCost(
        productId: p.id!,
        productFirestoreId: p.firestoreId,
        partId: partId,
        source: source,
        partName: part['partName'] as String? ?? '',
        quantity: e.value,
      );
      if (r.success) {
        ok++;
      } else {
        errors.add(r.error ?? '');
      }
    }
    if (!mounted) return;
    if (ok > 0) {
      _afterChange(
        '✅ Đã trừ kho $ok linh kiện, cộng vào chi phí tân trang'
        '${errors.isNotEmpty ? ' · Lỗi: ${errors.join('; ')}' : ''}',
        color: errors.isEmpty ? Colors.green : Colors.orange,
      );
    } else {
      NotificationService.showSnackBar('❌ ${errors.join('; ')}', color: Colors.red);
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá khoản tân trang?'),
        content: Text(
          it['type'] == 'PART'
              ? 'Hoàn ${it['quantity']} ${it['partName']} về kho phụ tùng và trừ khoản này khỏi chi phí tân trang.'
              : 'Huỷ nợ/phiếu chi tương ứng và trừ khoản này khỏi chi phí tân trang.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xoá', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ProductRefurbishService.deleteItem(it['id'] as int);
    if (!mounted) return;
    if (r.success) {
      _afterChange('✅ Đã xoá khoản');
    } else {
      NotificationService.showSnackBar('❌ ${r.error}', color: Colors.red);
    }
  }

  Future<void> _swapPart(Map<String, dynamic> it) async {
    final r = await ProductRefurbishService.deleteItem(it['id'] as int);
    if (!mounted) return;
    if (!r.success) {
      NotificationService.showSnackBar('❌ ${r.error}', color: Colors.red);
      return;
    }
    changed = true;
    await _reload();
    await _pickParts();
  }

  Future<void> _editService(Map<String, dynamic> it) async {
    final dCtrl = TextEditingController(text: it['description'] as String? ?? '');
    final aCtrl = TextEditingController(
      text: CurrencyTextField.formatDisplay((it['amount'] as num?)?.toInt() ?? 0),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa khoản dịch vụ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dCtrl,
              decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            CurrencyTextField(controller: aCtrl, label: 'Số tiền', icon: Icons.monetization_on),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ProductRefurbishService.updateServiceItem(
      itemId: it['id'] as int,
      description: dCtrl.text.trim(),
      amount: CurrencyTextField.parseValue(aCtrl.text),
    );
    if (!mounted) return;
    if (r.success) {
      _afterChange('✅ Đã cập nhật');
    } else {
      NotificationService.showSnackBar('❌ ${r.error}', color: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCost = p.cost + p.refurbishCost;
    return DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tân trang: ${p.name}',
                      style: AppTextStyles.headline4.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, changed),
                  ),
                ],
              ),
              if (_canViewCost)
                Text(
                  'Giá vốn gốc ${MoneyUtils.formatCurrency(p.cost)}đ'
                  '${p.refurbishCost > 0 ? ' · Tân trang ${MoneyUtils.formatCurrency(p.refurbishCost)}đ' : ''}'
                  ' · Tổng ${MoneyUtils.formatCurrency(totalCost)}đ',
                  style: AppTextStyles.body2.copyWith(color: Colors.grey[700]),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Dịch vụ / Đối tác / Khác'),
                      selected: section == 0,
                      onSelected: (_) => setState(() => section = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Linh kiện kho PT'),
                      selected: section == 1,
                      onSelected: (_) => setState(() => section = 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (section == 0) ...[
                DropdownButtonFormField<RepairPartner?>(
                  initialValue: selectedPartner,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Đối tác (bỏ trống nếu tự làm)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<RepairPartner?>(
                      value: null,
                      child: Text('— Không chọn NCC —'),
                    ),
                    ...partners.map(
                      (x) => DropdownMenuItem<RepairPartner?>(value: x, child: Text(x.name)),
                    ),
                  ],
                  onChanged: (v) => setState(() => selectedPartner = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả dịch vụ / lý do chi phí',
                    hintText: 'VD: Ép kính, sửa pan sạc mainboard...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                CurrencyTextField(controller: amountCtrl, label: 'Số tiền', icon: Icons.monetization_on),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['TIỀN MẶT', 'CHUYỂN KHOẢN', 'CÔNG NỢ']
                      .map(
                        (m) => ChoiceChip(
                          label: Text(m),
                          selected: paymentMethod == m,
                          onSelected: (_) => setState(() => paymentMethod = m),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveService,
                    icon: const Icon(Icons.save_outlined, color: Colors.white),
                    label: const Text('Lưu, cộng vào chi phí tân trang',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: PopupTheme.orange),
                  ),
                ),
              ] else ...[
                Text(
                  'Chọn linh kiện từ Kho phụ tùng — mỗi món trừ tồn ngay và tự cộng '
                  'vào chi phí tân trang.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickParts,
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: const Text('Chọn linh kiện từ kho'),
                    style: OutlinedButton.styleFrom(foregroundColor: PopupTheme.orange),
                  ),
                ),
              ],
              if (history.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Divider(),
                Text(
                  'Lịch sử tân trang',
                  style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...history.map((it) {
                  final isPart = it['type'] == 'PART';
                  final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                  final who = (it['partnerName'] as String?)?.trim();
                  // Người thực hiện: hiện cho MỌI vai trò (không phải con số
                  // nên không được ẩn theo quyền giá vốn — yêu cầu 2026-09-24).
                  final by = (it['createdBy'] as String?)?.trim();
                  final title = isPart && qty > 1
                      ? '${it['description']} x$qty'
                      : (it['description'] as String? ?? '');
                  final sub = [
                    if (by != null && by.isNotEmpty) 'Người TC: $by',
                    if (who != null && who.isNotEmpty) who,
                    if (!isPart && it['paymentMethod'] != null) it['paymentMethod'].toString(),
                    DateFormat('dd/MM/yyyy HH:mm').format(
                      DateTime.fromMillisecondsSinceEpoch((it['createdAt'] as num?)?.toInt() ?? 0),
                    ),
                  ].join(' · ');
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isPart ? Icons.memory : Icons.handyman_outlined,
                      size: 18,
                      color: PopupTheme.orange,
                    ),
                    title: Text(title, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(sub, style: const TextStyle(fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_canViewCost)
                          Text(
                            '${MoneyUtils.formatCurrency((it['amount'] as num?)?.toInt() ?? 0)}đ',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          onSelected: (v) {
                            if (v == 'delete') _deleteItem(it);
                            if (v == 'swap') _swapPart(it);
                            if (v == 'edit') _editService(it);
                          },
                          itemBuilder: (_) => [
                            if (isPart)
                              const PopupMenuItem(value: 'swap', child: Text('Đổi phụ tùng'))
                            else
                              const PopupMenuItem(value: 'edit', child: Text('Sửa dịch vụ')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(isPart ? 'Xoá phụ tùng' : 'Xoá dịch vụ'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
    );
  }
}
