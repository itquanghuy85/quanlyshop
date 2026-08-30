import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../theme/app_text_styles.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import '../models/shop_settings_model.dart';
import '../services/first_time_guide_service.dart';
import '../services/category_service.dart';
import '../services/business_type_helper.dart';
import '../widgets/responsive_wrapper.dart';
import 'repair_detail_view.dart';
import 'sale_detail_view.dart';
import '../utils/excel_export_helper.dart';
import '../widgets/export_date_filter_dialog.dart';
import '../widgets/custom_app_bar.dart';

class WarrantyView extends StatefulWidget {
  const WarrantyView({super.key});
  @override
  State<WarrantyView> createState() => _WarrantyViewState();
}

class _WarrantyViewState extends State<WarrantyView> {
  final db = DBHelper();
  List<Map<String, dynamic>> _warrantyList = [];
  bool _isLoading = true;
  ShopSettings? _shopSettings;

  BusinessTerminology get _terms => BusinessTypeHelper.instance.getTerminology(_shopSettings);

  @override
  void initState() {
    super.initState();
    _loadShopSettings();
    _loadAllWarranty();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstTimeGuide());
  }

  Future<void> _showFirstTimeGuide() async {
    await FirstTimeGuideService.showGuideIfNeeded(
      context: context,
      screenKey: FirstTimeGuideService.keyWarrantyView,
      title: 'Quản Lý Bảo Hành',
      icon: Icons.verified_user_rounded,
      color: Colors.green,
      steps: [
        const GuideStep(
          title: '🛡️ Theo dõi bảo hành',
          description: 'Xem danh sách tất cả sản phẩm và đơn sửa chữa còn trong thời gian bảo hành.',
          icon: Icons.shield_rounded,
          iconColor: Colors.green,
        ),
        const GuideStep(
          title: '⚠️ Cảnh báo sắp hết hạn',
          description: 'Bảo hành sắp hết được tô màu vàng, đã hết hạn màu đỏ để dễ phát hiện và xử lý kịp thời.',
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.orange,
        ),
        const GuideStep(
          title: '🔄 Tự động tạo bảo hành',
          description: 'Khi tạo đơn sửa hoặc hóa đơn bán có khai báo bảo hành, hệ thống tự thêm vào danh sách này.',
          icon: Icons.autorenew_rounded,
          iconColor: Colors.blue,
        ),
        const GuideStep(
          title: '📋 Xử lý bảo hành',
          description: 'Nhấn vào mục bảo hành để xem chi tiết, liên hệ khách hàng hoặc tạo đơn sửa bảo hành mới.',
          icon: Icons.build_circle_rounded,
          iconColor: Colors.teal,
        ),
      ],
    );
  }

  Future<void> _loadShopSettings() async {
    try {
      final settings = await CategoryService().getShopSettings();
      if (mounted) {
        setState(() => _shopSettings = settings);
      }
    } catch (e) {
      debugPrint('Error loading shop settings: $e');
    }
  }

  Future<void> _loadAllWarranty() async {
    setState(() => _isLoading = true);
    // Chỉ tải đơn có bảo hành còn hiệu lực (12 tháng qua), không load toàn bộ DB
    final repairs = await db.getActiveWarrantyRepairs();
    final sales = await db.getActiveWarrantySales();
    final now = DateTime.now();

    List<Map<String, dynamic>> results = [];

    // 1. BẢO HÀNH MÁY SỬA
    for (var r in repairs) {
      if (r.deliveredAt != null &&
          r.warranty.isNotEmpty &&
          r.warranty != "KO BH") {
        int months = int.tryParse(r.warranty.split(' ').first) ?? 0;
        if (months > 0) {
          DateTime delDate = DateTime.fromMillisecondsSinceEpoch(
            r.deliveredAt!,
          );
          DateTime expDate = DateTime(
            delDate.year,
            delDate.month + months,
            delDate.day,
          );
          if (expDate.isAfter(now)) {
            results.add({
              'type': 'REPAIR',
              'customer': r.customerName,
              'phone': r.phone,
              'model': r.model,
              'imei': r.imei ?? "N/A",
              'warranty': r.warranty,
              'issue': r.issue,
              'startDate': delDate,
              'expiry': expDate,
              'data': r,
            });
          }
        }
      }
    }

    // 2. BẢO HÀNH MÁY BÁN
    for (var s in sales) {
      if (s.warranty.isNotEmpty && s.warranty != "KO BH") {
        int months =
            int.tryParse(s.warranty.split(' ').first) ??
            12; // Mặc định 12th nếu lỗi parse
        DateTime saleDate = DateTime.fromMillisecondsSinceEpoch(s.soldAt);
        DateTime expDate = DateTime(
          saleDate.year,
          saleDate.month + months,
          saleDate.day,
        );

        if (expDate.isAfter(now)) {
          results.add({
            'type': 'SALE',
            'customer': s.customerName,
            'phone': s.phone,
            'model': s.productNames,
            'imei': s.productImeis,
            'warranty': s.warranty,
            'issue': '',
            'startDate': saleDate,
            'expiry': expDate,
            'data': s,
          });
        }
      }
    }

    results.sort(
      (a, b) => (a['expiry'] as DateTime).compareTo(b['expiry'] as DateTime),
    );
    if (mounted) {
      setState(() {
        _warrantyList = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: CustomAppBar.build(
        guideKey: FirstTimeGuideService.keyWarrantyView,
        title: 'SIÊU TRUNG TÂM BẢO HÀNH',
        actions: [
          IconButton(
            onPressed: _loadAllWarranty,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            tooltip: 'Xuất Excel bảo hành',
            onPressed: () async {
              final result = await ExportDateFilterDialog.show(context, title: 'Xuất bảo hành');
              if (result == null) return;
              if (!mounted) return;
              await ExcelExportHelper.exportWarranty(
                context,
                startMs: result['startMs'],
                endMs: result['endMs'],
              );
            },
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _warrantyList.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _warrantyList.length,
              itemBuilder: (ctx, i) =>
                  _buildWarrantyCard(_warrantyList[i], i + 1),
            ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 100,
            color: Colors.blue.withAlpha(51),
          ),
          const SizedBox(height: 15),
          Text(
            "KHÔNG CÓ ${_terms.productLabel.toUpperCase()} NÀO TRONG HẠN BẢO HÀNH",
            style: TextStyle(
              color: Colors.blueGrey,
              fontWeight: FontWeight.bold,
              fontSize: AppTextStyles.headline5.fontSize,
            ),
          ),
          Text(
            "Mọi đơn hàng đã hết hạn hoặc chưa được giao.",
            style: TextStyle(color: Colors.grey, fontSize: AppTextStyles.body1.fontSize),
          ),
        ],
      ),
    );
  }

  Widget _buildWarrantyCard(Map<String, dynamic> item, int index) {
    final bool isSale = item['type'] == 'SALE';
    final DateTime expDate = item['expiry'];
    final DateTime startDate = item['startDate'];
    final int totalDays = expDate.difference(startDate).inDays;
    final int daysLeft = expDate.difference(DateTime.now()).inDays;
    final double progress = (daysLeft / (totalDays > 0 ? totalDays : 1)).clamp(
      0.0,
      1.0,
    );

    // Colors based on urgency
    final urgentColor = daysLeft < 10
        ? Colors.red
        : (daysLeft < 30 ? Colors.orange : Colors.green);
    final bgColor = daysLeft < 10 ? Colors.red.shade50 : Colors.white;
    final borderColor = daysLeft < 10
        ? Colors.red.shade200
        : Colors.grey.shade200;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: 1),
      ),
      elevation: 1,
      color: bgColor,
      child: InkWell(
        onTap: () {
          if (isSale) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SaleDetailView(sale: item['data'] as SaleOrder),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    RepairDetailView(repair: item['data'] as Repair),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // STT + Type icon
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: (isSale ? Colors.pink : Colors.orange).withOpacity(
                        0.15,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '$index',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppTextStyles.caption.fontSize,
                          color: isSale
                              ? Colors.pink.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    isSale ? '📱' : '🔧',
                    style: TextStyle(fontSize: AppTextStyles.headline3.fontSize),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: isSale ? Colors.pink : Colors.orange,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                isSale ? 'BÁN' : 'SỬA',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: AppTextStyles.overlineSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item['model'].toString().toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppTextStyles.subtitle1.fontSize,
                                  color: const Color(0xFF1A237E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        // Khách + SĐT
                        Text(
                          '${item['customer']}'
                          '${(item['phone'] ?? '').toString().trim().isNotEmpty ? '  •  📞 ${item['phone']}' : ''}',
                          style: TextStyle(
                            fontSize: AppTextStyles.caption.fontSize,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // IMEI + thời hạn BH
                        Text(
                          'IMEI: ${item['imei']}'
                          '${(item['warranty'] ?? '').toString().trim().isNotEmpty ? '  •  BH ${item['warranty']}' : ''}',
                          style: TextStyle(
                            fontSize: AppTextStyles.overlineSize,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Lỗi/nội dung sửa (chỉ đơn sửa)
                        if ((item['issue'] ?? '').toString().trim().isNotEmpty)
                          Text(
                            '🔧 ${item['issue']}',
                            style: TextStyle(
                              fontSize: AppTextStyles.overlineSize,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // Days badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: urgentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: urgentColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$daysLeft',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: AppTextStyles.subtitle1.fontSize,
                                color: urgentColor,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'ngày',
                              style: TextStyle(fontSize: AppTextStyles.overlineSize, color: urgentColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd/MM/yy').format(expDate),
                        style: TextStyle(
                          fontSize: AppTextStyles.overlineSize,
                          color: urgentColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Progress bar row
              Row(
                children: [
                  Text(
                    DateFormat('dd/MM').format(startDate),
                    style: TextStyle(fontSize: AppTextStyles.overlineSize, color: Colors.grey.shade500),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: Colors.grey.shade200,
                        color: urgentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd/MM').format(expDate),
                    style: TextStyle(
                      fontSize: AppTextStyles.overlineSize,
                      color: urgentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}
