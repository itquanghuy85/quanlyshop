import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../data/db_helper.dart';
import '../models/sale_order_model.dart';
import 'sale_detail_view.dart';
import 'create_sale_view.dart';
import 'global_search_view.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_button_styles.dart';

class SaleListView extends StatefulWidget {
  final bool todayOnly;
  const SaleListView({super.key, this.todayOnly = false});

  @override
  State<SaleListView> createState() => _SaleListViewState();
}

class _SaleListViewState extends State<SaleListView> {
  final db = DBHelper();
  List<SaleOrder> _sales = [];
  bool _loading = true;
  String _search = "";

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final data = await db.getAllSales();
    if (!mounted) return;
    setState(() { _sales = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    var list = _sales.where((s) {
      final searchLower = _search.toUpperCase();
      return s.customerName.contains(searchLower) || 
             s.productNames.contains(searchLower) || 
             s.productImeis.contains(searchLower);
    }).toList();

    if (widget.todayOnly) {
      list = list.where((s) => DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(s.soldAt)) == nowStr).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Tooltip(
          message: "Xem, tìm kiếm và theo dõi tất cả đơn bán hàng.",
          child: Text(widget.todayOnly ? "DOANH SỐ HÔM NAY" : "QUẢN LÝ ĐƠN BÁN HÀNG", style: AppTextStyles.headline6),
        ),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateSaleView())).then((_) => _refresh()),
            icon: Icon(Icons.add_shopping_cart, color: AppColors.success),
            tooltip: "Tạo đơn bán hàng mới",
          ),
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchView(role: 'user'))),
            icon: Icon(Icons.search, color: AppColors.secondary),
            tooltip: 'Tìm kiếm toàn app',
          ),
          IconButton(onPressed: _refresh, icon: Icon(Icons.refresh, color: AppColors.primary)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: "Tìm theo tên khách, máy hoặc IMEI...", 
                prefixIcon: const Icon(Icons.search), 
                filled: true, fillColor: AppColors.surface, 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
              ),
            ),
          ),
        ),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : list.isEmpty 
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shopping_bag_outlined, size: 80, color: AppColors.onSurface.withOpacity(0.3)), Text("Chưa có dữ liệu đơn hàng", style: AppTextStyles.body1.copyWith(color: AppColors.onSurface.withOpacity(0.6)))]))
        : ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final s = list[i];
              final date = DateFormat('HH:mm - dd/MM/yy').format(DateTime.fromMillisecondsSinceEpoch(s.soldAt));
              final remain = s.totalPrice - s.downPayment;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface, 
                  borderRadius: BorderRadius.circular(20), 
                  boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10)]
                ),
                child: ListTile(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailView(sale: s))).then((_) => _refresh());
                  },
                  contentPadding: const EdgeInsets.all(15),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(s.customerName.toUpperCase(), style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                      Text(date, style: AppTextStyles.overline.copyWith(color: AppColors.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(s.productNames, style: AppTextStyles.body2.copyWith(color: AppColors.primary, fontWeight: FontWeight.w900)),
                      Text("IMEI: ${s.productImeis}", style: AppTextStyles.caption.copyWith(color: AppColors.onSurface)),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statItem("TỔNG TIỀN", fmt.format(s.totalPrice), AppColors.onSurface),
                          _statItem("ĐÃ THU", fmt.format(s.downPayment), AppColors.success),
                          if (remain > 0) _statItem("CÒN NỢ", fmt.format(remain), AppColors.error),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: _getPayColor(s.paymentMethod).withAlpha(25), borderRadius: BorderRadius.circular(8)),
                            child: Text(s.paymentMethod, style: AppTextStyles.overline.copyWith(color: _getPayColor(s.paymentMethod), fontWeight: FontWeight.bold)),
                          ),
                          Text("NV: ${s.sellerName}", style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic, color: AppColors.onSurface.withOpacity(0.6))),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.overline.copyWith(color: AppColors.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold)),
        Text("$value đ", style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  Color _getPayColor(String m) {
    if (m.contains("TIỀN MẶT")) return AppColors.success;
    if (m.contains("CHUYỂN KHOẢN")) return AppColors.primary;
    if (m.contains("TRẢ GÓP")) return AppColors.warning;
    return AppColors.error;
  }
}
