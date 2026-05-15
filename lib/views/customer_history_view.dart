import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as m;
import '../theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../core/utils/money_utils.dart';
import '../theme/app_text_styles.dart';
import '../models/shop_settings_model.dart';
import '../services/category_service.dart';
import '../services/storage_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/app_cached_image.dart';

import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import 'repair_detail_view.dart';
import 'sale_detail_view.dart';

class CustomerHistoryView extends StatefulWidget {
  final String phone;
  final String name;
  const CustomerHistoryView({
    super.key,
    required this.phone,
    required this.name,
  });

  @override
  State<CustomerHistoryView> createState() => _CustomerHistoryViewState();
}

class _CustomerHistoryViewState extends State<CustomerHistoryView> {
  final db = DBHelper();
  List<Map<String, dynamic>> combinedHistory = [];
  bool _isLoading = true;

  // Shop settings for multi-industry
  ShopSettings? _shopSettings;

  bool _isDirectDisplayUrl(String path) {
    final normalized = path.trim().toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://') ||
        normalized.startsWith('blob:') ||
        normalized.startsWith('data:');
  }

  Future<List<String>> _resolveGalleryImages(List<String> images) async {
    final resolvedImages = <String>[];
    for (final image in images) {
      final normalized = image.trim();
      if (normalized.isEmpty) continue;
      if (!StorageService.isResolvableDisplayPath(normalized)) continue;

      if (_isDirectDisplayUrl(normalized)) {
        resolvedImages.add(normalized);
        continue;
      }

      final resolved = await StorageService.resolveDisplayUrl(normalized);
      if (resolved != null && resolved.isNotEmpty) {
        resolvedImages.add(resolved);
      }
    }
    return resolvedImages;
  }

  m.Widget _buildThumbImage(String thumb) {
    if (!StorageService.isResolvableDisplayPath(thumb)) {
      return m.Container(
        color: AppColors.outline,
        child: m.Icon(
          m.Icons.photo_outlined,
          color: AppColors.textHint,
          size: 20,
        ),
      );
    }

    if (_isDirectDisplayUrl(thumb)) {
      return AppCachedImage(
        imageUrl: thumb,
        fit: m.BoxFit.cover,
        memCacheWidth: 110,
        memCacheHeight: 110,
      );
    }

    if (StorageService.isGsStoragePath(thumb) ||
        StorageService.isStorageRelativePath(thumb)) {
      return m.FutureBuilder<String?>(
        future: StorageService.resolveDisplayUrl(thumb),
        builder: (context, snapshot) {
          final url = snapshot.data;
          if (url == null || url.isEmpty) {
            return m.Container(
              color: AppColors.outline,
              child: m.Icon(
                m.Icons.broken_image,
                color: AppColors.textHint,
                size: 20,
              ),
            );
          }

          return AppCachedImage(
            imageUrl: url,
            fit: m.BoxFit.cover,
            memCacheWidth: 110,
            memCacheHeight: 110,
          );
        },
      );
    }

    if (kIsWeb) {
      return m.Container(
        color: AppColors.outline,
        child: m.Icon(m.Icons.image, color: AppColors.textHint, size: 20),
      );
    }
    return m.Image.file(File(thumb), fit: m.BoxFit.cover);
  }

  bool get _enableRepair => _shopSettings?.enableRepair ?? true;

  @override
  void initState() {
    super.initState();
    _loadShopSettings();
    _loadUnifiedHistory();
  }

  Future<void> _loadShopSettings() async {
    try {
      final settings = await CategoryService().getShopSettings();
      if (mounted) {
        setState(() => _shopSettings = settings);
        // Reload history after shop settings to filter correctly
        _loadUnifiedHistory();
      }
    } catch (e) {
      debugPrint('Error loading shop settings: $e');
    }
  }

  Future<void> _loadUnifiedHistory() async {
    setState(() => _isLoading = true);
    final repairs = await db.getAllRepairs();
    final sales = await db.getAllSales();

    List<Map<String, dynamic>> results = [];

    // Chỉ hiện lịch sử sửa chữa nếu shop hỗ trợ repair (electronics)
    if (_enableRepair) {
      for (var r in repairs.where((item) => item.phone == widget.phone)) {
        results.add({
          'type': 'REPAIR',
          'time': r.createdAt,
          'title': r.model,
          'subtitle': "Sửa: ${r.issue.split('|').first}",
          'status': r.status,
          'amount': r.price,
          'images': r.receiveImages
              .where(StorageService.isResolvableDisplayPath)
              .toList(),
          'data': r,
        });
      }
    }

    for (var s in sales.where((item) => item.phone == widget.phone)) {
      results.add({
        'type': 'SALE',
        'time': s.soldAt,
        'title': s.productNames,
        'subtitle': "Mua máy mới",
        'status': 4,
        'amount': s.finalPrice,
        'images': [],
        'data': s,
      });
    }

    results.sort((a, b) => (b['time'] as int).compareTo(a['time'] as int));

    setState(() {
      combinedHistory = results;
      _isLoading = false;
    });
  }

  Future<void> _openGallery(List<String> images, int index) async {
    final validImages = await _resolveGalleryImages(images);
    if (validImages.isEmpty) return;

    m.Navigator.push(
      context,
      m.MaterialPageRoute(
        builder: (_) => m.Scaffold(
          appBar: m.AppBar(
            backgroundColor: AppColors.textPrimary,
            iconTheme: const m.IconThemeData(color: AppColors.surface),
          ),
          backgroundColor: AppColors.textPrimary,
          body: PhotoViewGallery.builder(
            itemCount: validImages.length,
            builder: (context, i) => PhotoViewGalleryPageOptions(
              imageProvider: (_isDirectDisplayUrl(validImages[i]))
                  ? CachedNetworkImageProvider(validImages[i])
                  : kIsWeb
                      ? CachedNetworkImageProvider(validImages[i]) as m.ImageProvider
                      : m.FileImage(File(validImages[i])) as m.ImageProvider,
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
            ),
            pageController: PageController(
              initialPage: index.clamp(0, validImages.length - 1),
            ),
            scrollPhysics: const m.BouncingScrollPhysics(),
          ),
        ),
      ),
    );
  }

  String _fmtDate(int ms) => DateFormat(
    'dd/MM/yyyy HH:mm',
  ).format(DateTime.fromMillisecondsSinceEpoch(ms));

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Hồ sơ khách hàng"),
      ),
      child: m.Material(
        color: m.Colors.transparent,
        child: SafeArea(
          child: _isLoading
              ? const m.Center(child: m.CircularProgressIndicator())
              : combinedHistory.isEmpty
              ? const m.Center(child: Text("Chưa có lịch sử giao dịch"))
              : m.ListView.builder(
                  padding: const m.EdgeInsets.all(16),
                  itemCount: combinedHistory.length,
                  itemBuilder: (context, index) {
                    final item = combinedHistory[index];
                    final bool isRepair = item['type'] == 'REPAIR';
                    final List<String> imgs = List<String>.from(item['images']);
                    final String thumb = imgs.firstWhere(
                      (p) =>
                          _isDirectDisplayUrl(p) ||
                          StorageService.isGsStoragePath(p) ||
                          StorageService.isStorageRelativePath(p) ||
                          (!kIsWeb && File(p).existsSync()),
                      orElse: () => '',
                    );
                    final bool hasThumb = thumb.isNotEmpty;

                    return m.Container(
                      margin: const m.EdgeInsets.only(bottom: 12),
                      decoration: m.BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: m.BorderRadius.circular(15),
                        boxShadow: [
                          m.BoxShadow(
                            color: AppColors.textPrimary.withAlpha(5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: m.ListTile(
                        contentPadding: const m.EdgeInsets.all(12),
                        leading: m.GestureDetector(
                          onTap: imgs.isNotEmpty
                              ? () => _openGallery(imgs, 0)
                              : null,
                          child: m.Container(
                            width: 55,
                            height: 55,
                            decoration: m.BoxDecoration(
                              color: isRepair
                                  ? AppColors.warning.withAlpha(25)
                                  : AppColors.error.withAlpha(25),
                              borderRadius: m.BorderRadius.circular(10),
                            ),
                            child: hasThumb
                                ? m.ClipRRect(
                                    borderRadius: m.BorderRadius.circular(10),
                                    child: _buildThumbImage(thumb),
                                  )
                                : m.Icon(
                                    isRepair
                                        ? m.Icons.build
                                        : m.Icons.shopping_bag,
                                    color: isRepair
                                        ? AppColors.warning
                                        : AppColors.error,
                                    size: 24,
                                  ),
                          ),
                        ),
                        title: m.Text(
                          item['title'],
                          style: m.TextStyle(
                            fontWeight: m.FontWeight.bold,
                            fontSize: AppTextStyles.headline3.fontSize,
                          ),
                        ),
                        subtitle: m.Column(
                          crossAxisAlignment: m.CrossAxisAlignment.start,
                          children: [
                            m.Text(
                              "${item['subtitle']} - ${MoneyUtils.formatVND(item['amount'])}đ",
                              style: m.TextStyle(
                                fontSize: AppTextStyles.headline5.fontSize,
                              ),
                            ),
                            m.Text(
                              _fmtDate(item['time']),
                              style: m.TextStyle(
                                fontSize: AppTextStyles.body1.fontSize,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                        trailing: const m.Icon(m.Icons.chevron_right, size: 18),
                        onTap: () async {
                          try {
                            if (isRepair) {
                              final repair = item['data'];
                              if (repair == null || repair is! Repair) {
                                _showDataErrorDialog('Không thể mở chi tiết đơn sửa chữa. Dữ liệu bị thiếu hoặc lỗi.\n\nVui lòng đồng bộ lại dữ liệu hoặc liên hệ hỗ trợ.');
                                return;
                              }
                              await m.Navigator.push(
                                context,
                                m.MaterialPageRoute(
                                  builder: (_) => RepairDetailView(repair: repair),
                                ),
                              );
                            } else {
                              final sale = item['data'];
                              if (sale == null || sale is! SaleOrder) {
                                _showDataErrorDialog('Không thể mở chi tiết đơn bán. Dữ liệu bị thiếu hoặc lỗi.\n\nVui lòng đồng bộ lại dữ liệu sản phẩm hoặc liên hệ hỗ trợ.');
                                return;
                              }
                              // Kiểm tra sản phẩm có tồn tại không
                              if ((sale.productNames.trim().isEmpty) && ((sale.itemSnapshotsJson ?? '').trim().isEmpty)) {
                                _showDataErrorDialog('Không tìm thấy thông tin sản phẩm trong đơn bán này.\n\nBạn hãy đồng bộ lại dữ liệu sản phẩm (menu Cài đặt > Đồng bộ dữ liệu) hoặc kiểm tra lại dữ liệu gốc.');
                                return;
                              }
                              await m.Navigator.push(
                                context,
                                m.MaterialPageRoute(
                                  builder: (_) => SaleDetailView(sale: sale),
                                ),
                              );
                            }
                            _loadUnifiedHistory();
                          } catch (e) {
                            _showDataErrorDialog('Đã xảy ra lỗi khi mở chi tiết giao dịch.\n\nVui lòng đồng bộ lại dữ liệu hoặc liên hệ hỗ trợ.\n\nChi tiết: $e');
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _showDataErrorDialog(String message) {
    m.showDialog(
      context: context,
      builder: (ctx) => m.AlertDialog(
        title: const m.Text('Lỗi dữ liệu', style: m.TextStyle(color: AppColors.error)),
        content: m.Text(message),
        actions: [
          m.TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const m.Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
