import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../theme/app_text_styles.dart';
import '../models/purchase_order_model.dart';
import '../services/user_service.dart';
import '../services/first_time_guide_service.dart';
import 'create_purchase_order_view.dart';
import '../widgets/validated_text_field.dart';
import '../widgets/responsive_wrapper.dart';
import '../widgets/custom_app_bar.dart';

class PurchaseOrderListView extends StatefulWidget {
  const PurchaseOrderListView({super.key});

  @override
  State<PurchaseOrderListView> createState() => _PurchaseOrderListViewState();
}

class _PurchaseOrderListViewState extends State<PurchaseOrderListView> {
  final db = DBHelper();
  List<PurchaseOrder> _orders = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _hasCreatePermission = false;
  final searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstTimeGuide());
  }

  Future<void> _showFirstTimeGuide() async {
    await FirstTimeGuideService.showGuideIfNeeded(
      context: context,
      screenKey: FirstTimeGuideService.keyPurchaseOrderList,
      title: 'Đơn Nhập Hàng',
      icon: Icons.local_shipping_rounded,
      color: Colors.brown,
      steps: [
        const GuideStep(
          title: '📦 Quản lý đơn nhập',
          description: 'Xem tất cả đơn đặt hàng từ nhà cung cấp: trạng thái, số lượng và giá trị từng đơn.',
          icon: Icons.inventory_2_rounded,
          iconColor: Colors.brown,
        ),
        const GuideStep(
          title: '✅ Theo dõi trạng thái',
          description: 'Đơn nhập đi qua các bước: Chờ xác nhận → Đang giao → Đã nhận hàng.',
          icon: Icons.track_changes_rounded,
          iconColor: Colors.blue,
        ),
        const GuideStep(
          title: '🏪 Nhập kho tự động',
          description: 'Khi xác nhận đã nhận hàng, tồn kho tự động cập nhật theo số lượng trong đơn nhập.',
          icon: Icons.warehouse_rounded,
          iconColor: Colors.green,
        ),
        const GuideStep(
          title: '💳 Công nợ nhà cung cấp',
          description: 'Nếu chưa thanh toán, hệ thống tự tạo khoản nợ NCC để theo dõi trong màn hình Công Nợ.',
          icon: Icons.account_balance_rounded,
          iconColor: Colors.orange,
        ),
      ],
    );
  }

  Future<void> _loadData() async {
    try {
      final perms = await UserService.getCurrentUserPermissions();
      final hasPermission = perms['allowViewPurchaseOrders'] ?? false;
      final hasCreatePermission = perms['allowCreatePurchaseOrders'] ?? false;

      if (!hasPermission) {
        setState(() {
          _hasPermission = false;
          _hasCreatePermission = false;
          _isLoading = false;
        });
        return;
      }

      final orders = await db.getAllPurchaseOrders();

      setState(() {
        _hasPermission = true;
        _hasCreatePermission = hasCreatePermission;
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    await _loadData();
  }

  List<PurchaseOrder> get _filteredOrders {
    if (searchCtrl.text.isEmpty) return _orders;
    return _orders.where((order) =>
      order.orderCode.toLowerCase().contains(searchCtrl.text.toLowerCase()) ||
      order.supplierName.toLowerCase().contains(searchCtrl.text.toLowerCase())
    ).toList();
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case 'PENDING':
        color = Colors.orange;
        text = 'CHỜ NHẬN';
        break;
      case 'RECEIVED':
        color = Colors.green;
        text = 'ĐÃ NHẬN';
        break;
      case 'CANCELLED':
        color = Colors.red;
        text = 'ĐÃ HỦY';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Chip(
      label: Text(text, style: TextStyle(color: Colors.white, fontSize: AppTextStyles.subtitle1.fontSize)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildOrderCard(PurchaseOrder order) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(
          order.orderCode,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("NCC: ${order.supplierName}"),
            Text("Người tạo: ${order.createdBy} - ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(order.createdAt))}"),
            Text("${order.totalAmount} sản phẩm - ${NumberFormat('#,###').format(order.totalCost)}đ"),
            if (order.paymentMethod != null) Text("Thanh toán: ${order.paymentMethod}"),
          ],
        ),
        trailing: _buildStatusChip(order.status),
        onTap: () {
          // TODO: Navigate to detail view
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Chi tiết đơn ${order.orderCode} - Chức năng đang phát triển"))
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: AppTextStyles.headline1.fontSize,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(fontSize: AppTextStyles.subtitle1.fontSize, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasPermission) {
      return Scaffold(
        appBar: CustomAppBar.build(title: 'ĐƠN NHẬP HÀNG'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                "Bạn không có quyền xem đơn nhập hàng",
                style: TextStyle(fontSize: AppTextStyles.headline3.fontSize, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar.build(
        guideKey: FirstTimeGuideService.keyPurchaseOrderList,
        title: 'ĐƠN NHẬP HÀNG',
        actions: _hasCreatePermission ? [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatePurchaseOrderView())
            ).then((_) => _refresh()),
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: "Tạo đơn nhập",
          ),
        ] : null,
      ),
      body: ResponsiveCenter(
        child: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.all(16),
            child: ValidatedTextField(
              controller: searchCtrl,
              label: "TÌM KIẾM THEO MÃ ĐƠN, NHÀ CUNG CẤP...",
              icon: Icons.search,
              uppercase: true,
              onChanged: (value) => setState(() {}),
            ),
          ),

          // Summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildSummaryCard("Tổng đơn", _orders.length.toString(), Colors.blue),
                const SizedBox(width: 8),
                _buildSummaryCard("Chờ nhận", _orders.where((o) => o.status == 'PENDING').length.toString(), Colors.orange),
                const SizedBox(width: 8),
                _buildSummaryCard("Đã nhận", _orders.where((o) => o.status == 'RECEIVED').length.toString(), Colors.green),
              ],
            ),
          ),

          // Orders list
          Expanded(
            child: _filteredOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        searchCtrl.text.isEmpty ? "Chưa có đơn nhập hàng nào" : "Không tìm thấy đơn nhập hàng",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    itemCount: _filteredOrders.length,
                    itemBuilder: (context, index) => _buildOrderCard(_filteredOrders[index]),
                  ),
                ),
          ),
        ],
      )),
    );
  }
}
