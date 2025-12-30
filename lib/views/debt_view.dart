import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../services/event_bus.dart';
import '../widgets/currency_text_field.dart';

class DebtView extends StatefulWidget {
  const DebtView({super.key});
  @override
  State<DebtView> createState() => _DebtViewState();
}

class _DebtViewState extends State<DebtView> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final db = DBHelper();
  late TabController _tabController;
  List<Map<String, dynamic>> _debts = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  StreamSubscription<String>? _eventSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRole();
    _refresh();

    // Listen to global events (e.g., debts changed) to refresh the list when other parts of the app write debts
    _eventSub = EventBus().stream.where((e) => e == 'debts_changed').listen((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() => _isAdmin = perms['allowViewDebts'] ?? false);
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final data = await db.getAllDebts();
    if (!mounted) return;
    setState(() { _debts = data; _isLoading = false; });
  }

  void _showDebtHistory(Map<String, dynamic> debt) async {
    final payments = await db.getDebtPayments(debt['id']);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            const Text("LỊCH SỬ THANH TOÁN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A237E))),
            Text(debt['personName'].toString().toUpperCase(), style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
            const Divider(height: 30),
            if (payments.isEmpty)
              const Padding(padding: EdgeInsets.all(40), child: Text("Chưa có lịch sử trả nợ", style: TextStyle(color: Colors.grey)))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: payments.length,
                  itemBuilder: (ctx, i) {
                    final p = payments[i];
                    final date = DateFormat('HH:mm - dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(p['paidAt']));
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green.withAlpha(13), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("+ ${NumberFormat('#,###').format(p['amount'])} đ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            Text(date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ]),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(p['createdBy'] ?? "NV", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            Text(p['paymentMethod'] ?? "TIỀN MẶT", style: const TextStyle(fontSize: 9, color: Colors.blueGrey)),
                          ]),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _payDebt(debt); },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF)),
              child: const Text("THU TIỀN TRẢ NỢ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _payDebt(Map<String, dynamic> debt) {
    final payC = TextEditingController();
    String method = "TIỀN MẶT";
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text("THU TIỀN TRẢ NỢ"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CurrencyTextField(controller: payC, label: "SỐ TIỀN THU (Ví dụ: 500 = 500k)"),
              const SizedBox(height: 15),
              Wrap(spacing: 8, children: ["TIỀN MẶT", "CHUYỂN KHOẢN"].map((m) => ChoiceChip(
                label: Text(m, style: const TextStyle(fontSize: 10)), selected: method == m,
                onSelected: (v) => setS(() => method = m),
              )).toList()),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
            ElevatedButton(onPressed: () async {
              // --- XỬ LÝ QUY ƯỚC NHẬP NHANH (x1000) ---
              int rawAmount = int.tryParse(payC.text.replaceAll('.', '')) ?? 0;
              if (rawAmount <= 0) return;
              
              // Nếu nhập số nhỏ (dưới 100k) thì tự động nhân 1000
              int payAmount = (rawAmount > 0 && rawAmount < 100000) ? rawAmount * 1000 : rawAmount;

              final user = FirebaseAuth.instance.currentUser;
              final userName = user?.email?.split('@').first.toUpperCase() ?? "NV";
              final now = DateTime.now().millisecondsSinceEpoch;

              int total = debt['totalAmount'];
              int alreadyPaid = debt['paidAmount'] ?? 0;
              int remain = total - alreadyPaid;

              if (payAmount > remain) {
                NotificationService.showSnackBar("Số tiền trả không được vượt số nợ còn lại!", color: Colors.red);
                return;
              }

              // 1. Lưu lịch sử chi tiết
              await db.insertDebtPayment({
                'firestoreId': "pay_${now}_${user?.uid}",
                'debtId': debt['id'],
                'debtFirestoreId': debt['firestoreId'],
                'amount': payAmount,
                'paidAt': now,
                'paymentMethod': method,
                'createdBy': userName,
              });

              // 2. LOGIC TỰ TẠO ĐƠN NỢ MỚI NẾU CHƯA HẾT
              if (payAmount < remain) {
                await db.updateDebtPaid(debt['id'], remain);
                int newDebtAmount = remain - payAmount;
                final newDebtData = {
                  'firestoreId': "debt_${now}_carried",
                  'personName': debt['personName'],
                  'phone': debt['phone'],
                  'totalAmount': newDebtAmount,
                  'paidAmount': 0,
                  'type': debt['type'],
                  'status': 'unpaid',
                  'createdAt': now,
                  'note': "Dư nợ chuyển sang từ đơn ngày ${DateFormat('dd/MM').format(DateTime.fromMillisecondsSinceEpoch(debt['createdAt']))}",
                  'linkedId': debt['linkedId'],
                };
                await db.insertDebt(newDebtData);
                await FirestoreService.addDebtCloud(newDebtData);
              } else {
                await db.updateDebtPaid(debt['id'], payAmount);
              }

              // 3. Cập nhật đơn hàng liên kết (nếu có)
              if (debt['linkedId'] != null) {
                await db.updateOrderStatusFromDebt(debt['linkedId'], alreadyPaid + payAmount);
                // Cập nhật Cloud cho order
                if (debt['linkedId'].startsWith('sale_')) {
                  final sales = await db.getAllSales();
                  final matching = sales.where((s) => s.firestoreId == debt['linkedId']);
                  final sale = matching.isNotEmpty ? matching.first : null;
                  if (sale != null) await FirestoreService.updateSaleCloud(sale);
                } else if (debt['linkedId'].startsWith('rep_')) {
                  final repairs = await db.getAllRepairs();
                  final matching = repairs.where((r) => r.firestoreId == debt['linkedId']);
                  final repair = matching.isNotEmpty ? matching.first : null;
                  if (repair != null) await FirestoreService.upsertRepair(repair);
                } else {
                  // Assume it's a purchase order code
                  final purchases = await db.getAllPurchaseOrders();
                  final matching = purchases.where((p) => p.orderCode == debt['linkedId']);
                  final purchase = matching.isNotEmpty ? matching.first : null;
                  if (purchase != null) {
                    purchase.status = 'RECEIVED';
                    await db.updatePurchaseOrder(purchase);
                    await FirestoreService.addPurchaseOrder(purchase);
                  }
                }
              }

              // 4. Đồng bộ Cloud
              final allDebts = await db.getAllDebts();
              final updatedOldDebt = allDebts.firstWhere((e) => e['id'] == debt['id']);
              await FirestoreService.addDebtCloud(Map<String, dynamic>.from(updatedOldDebt));

              // 5. Nhật ký
              await db.logAction(userId: user?.uid ?? "0", userName: userName, action: "THU NỢ", type: "DEBT", targetId: debt['firestoreId'], desc: "Khách trả ${NumberFormat('#,###').format(payAmount)} đ.");

              if (!mounted) return;
              Navigator.pop(context);
              _refresh();
              NotificationService.showSnackBar("Đã thu nợ và đồng bộ hệ thống!", color: Colors.green);
            }, child: const Text("XÁC NHẬN")),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("QUẢN LÝ CÔNG NỢ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2962FF),
          indicatorColor: const Color(0xFF2962FF),
          tabs: const [Tab(text: "KHÁCH NỢ"), Tab(text: "SHOP NỢ NCC")],
        ),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : TabBarView(
        controller: _tabController,
        children: [_buildDebtList('CUSTOMER_OWES'), _buildDebtList('SHOP_OWES')],
      ),
    );
  }

  Widget _buildDebtList(String type) {
    final list = _debts.where((d) => d['type'] == type && (d['status'] != 'paid')).toList();
    if (list.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]), const SizedBox(height: 10), const Text("Hiện tại không có khoản nợ nào", style: TextStyle(color: Colors.grey))]));
    }

    int totalRemain = list.fold(0, (sum, d) {
      final int total = d['totalAmount'] as int;
      final int paid = d['paidAmount'] as int? ?? 0;
      final int remain = total - paid;
      return remain > 0 ? sum + remain : sum;
    });

    return Column(
      children: [
        _summaryHeader(type == 'CUSTOMER_OWES' ? "TỔNG KHÁCH ĐANG NỢ" : "TỔNG SHOP ĐANG NỢ NCC", totalRemain, type == 'CUSTOMER_OWES' ? Colors.redAccent : Colors.blueAccent),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (ctx, i) => _debtCard(list[i]),
          ),
        ),
      ],
    );
  }

  Widget _summaryHeader(String label, int amount, Color color) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withAlpha(77))),
      child: Column(children: [Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)), const SizedBox(height: 4), Text("${NumberFormat('#,###').format(amount)} đ", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 24))]),
    );
  }

  Widget _debtCard(Map<String, dynamic> d) {
    final int total = d['totalAmount'];
    final int paid = d['paidAmount'] ?? 0;
    final int remain = total - paid;
    final date = DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(d['createdAt']));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10)]),
      child: ListTile(
        onTap: () => _showDebtHistory(d),
        contentPadding: const EdgeInsets.all(15),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text((d['personName'] ?? 'N/A').toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
            Text(date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (d['phone'] != null) Text("SĐT: ${d['phone']}", style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            Text("Nội dung: ${d['note'] ?? ''}", style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _miniValue("ĐÃ TRẢ", paid, Colors.green),
              _miniValue("CÒN NỢ", remain, Colors.red),
            ]),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }

  Widget _miniValue(String l, int v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)), Text(NumberFormat('#,###').format(v), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c))]);
}
