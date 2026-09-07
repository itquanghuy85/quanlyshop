import 'dart:async';
import 'package:flutter/material.dart';
import 'responsive_wrapper.dart';
import '../data/db_helper.dart';
import '../services/sync_service.dart';
import '../services/sync_orchestrator.dart';
import '../services/sync_health_check.dart';
import '../services/notification_service.dart';
import '../services/firestore_connectivity_service.dart';
import '../services/sync_domain_report_service.dart';
import '../views/firestore_connectivity_test_view.dart';
import '../views/firebase_rw_stats_view.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'package:intl/intl.dart';

/// Widget hiển thị nút sync thống nhất trên AppBar
/// Gom tất cả chức năng sync vào một nơi
class UnifiedSyncButton extends StatefulWidget {
  const UnifiedSyncButton({super.key});

  @override
  State<UnifiedSyncButton> createState() => _UnifiedSyncButtonState();
}

class _UnifiedSyncButtonState extends State<UnifiedSyncButton>
    with SingleTickerProviderStateMixin {
  final SyncOrchestrator _orchestrator = SyncOrchestrator();

  StreamSubscription<int>? _countSubscription;
  StreamSubscription<SyncStatus>? _statusSubscription;
  late AnimationController _animationController;

  int _pendingCount = 0;
  SyncStatus _status = SyncStatus.synced;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _pendingCount = _orchestrator.pendingCount;
    _countSubscription = _orchestrator.pendingCountStream.listen((count) {
      if (mounted) setState(() => _pendingCount = count);
    });

    _statusSubscription = _orchestrator.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() => _status = status);
        if (status == SyncStatus.syncing) {
          _animationController.repeat();
        } else {
          _animationController.stop();
          _animationController.reset();
        }
      }
    });
  }

  @override
  void dispose() {
    _countSubscription?.cancel();
    _statusSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;

    switch (_status) {
      case SyncStatus.synced:
        icon = Icons.cloud_done;
        iconColor = AppColors.success;
        break;
      case SyncStatus.hasPending:
        icon = Icons.cloud_upload;
        iconColor = Colors.orange;
        break;
      case SyncStatus.syncing:
        icon = Icons.sync;
        iconColor = AppColors.primary;
        break;
      case SyncStatus.noNetwork:
        icon = Icons.cloud_off;
        iconColor = Colors.grey;
        break;
      case SyncStatus.error:
        icon = Icons.cloud_off;
        iconColor = Colors.red;
        break;
    }

    Widget iconWidget = AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _status == SyncStatus.syncing
              ? _animationController.value * 2 * 3.14159
              : 0,
          child: Icon(icon, size: 24, color: iconColor),
        );
      },
    );

    // Badge khi có pending
    if (_pendingCount > 0 && _status != SyncStatus.syncing) {
      iconWidget = Badge(
        label: Text(
          _pendingCount > 99 ? '99+' : '$_pendingCount',
          style: const TextStyle(
            fontSize: AppTextStyles.overlineSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.red,
        child: iconWidget,
      );
    }

    return IconButton(
      onPressed: () => _showSyncCenter(context),
      icon: iconWidget,
      tooltip: 'Trung tâm đồng bộ',
    );
  }

  void _showSyncCenter(BuildContext context) {
    showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SyncCenterSheet(),
    );
  }
}

/// Bottom sheet chứa tất cả chức năng sync
class SyncCenterSheet extends StatefulWidget {
  const SyncCenterSheet({super.key});

  @override
  State<SyncCenterSheet> createState() => _SyncCenterSheetState();
}

class _SyncCenterSheetState extends State<SyncCenterSheet> {
  final SyncOrchestrator _orchestrator = SyncOrchestrator();

  bool _isLoading = false;
  String _loadingMessage = '';
  SyncHealthReport? _healthReport;
  FirestoreConnectivityReport? _firestoreConnectivityReport;
  SyncDomainReportSnapshot? _domainReport;
  Map<String, int>? _localStats;
  Map<String, int>? _syncQueueStats;

  /// Chi tiết "đang chờ đẩy" gom theo loại dữ liệu — để Trung tâm đồng bộ nói
  /// được 88 món đó LÀ GÌ, chứ không chỉ nêu con số.
  List<Map<String, dynamic>> _pendingBreakdown = const [];
  bool _isRealtimeSyncActive = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Đang kiểm tra...';
    });

    try {
      // Load local stats
      final db = DBHelper();
      final repairs = await db.getAllRepairs();
      final sales = await db.getAllSales();
      final products = await db.getAllProducts();
      final expenses = await db.getAllExpenses();
      final debts = await db.getAllDebts();

      _localStats = {
        'repairs': repairs.length,
        'sales': sales.length,
        'products': products.length,
        'expenses': expenses.length,
        'debts': debts.length,
      };

      // Load sync queue stats
      _syncQueueStats = await _orchestrator.getSyncStats();
      _pendingBreakdown = await _orchestrator.getPendingBreakdown();

      // Check realtime sync status
      _isRealtimeSyncActive = SyncService.isRealTimeSyncActive;

      // Load health check (quick)
      _healthReport = await SyncHealthCheck.runFullCheck(force: true);

      // Load Firestore connectivity diagnostics
      _firestoreConnectivityReport =
          await FirestoreConnectivityService.runDiagnostics();

      // Build domain-level sync report
      _domainReport = await SyncDomainReportService.buildReport(
        healthReport: _healthReport,
      );
    } catch (e) {
      debugPrint('Error loading sync data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        // `context` bên dưới bị shadow bởi tham số cùng tên — dùng
        // `this.context` (State) để tránh crash _dependents.isEmpty khi pop.
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_sync,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TRUNG TÂM ĐỒNG BỘ',
                            style: TextStyle(
                              fontSize: AppTextStyles.headline2.fontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Quản lý dữ liệu Local ↔ Cloud',
                            style: TextStyle(
                              fontSize: AppTextStyles.subtitle1.fontSize,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Content
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(_loadingMessage),
                          ],
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          16 + MediaQuery.paddingOf(this.context).bottom,
                        ),
                        children: [
                          // Health status card
                          _buildHealthStatusCard(),

                          const SizedBox(height: 16),

                          // Local stats
                          _buildLocalStatsCard(),

                          const SizedBox(height: 16),

                          // Domain sync report
                          _buildDomainSyncReportCard(),

                          const SizedBox(height: 16),

                          // Proactive stuck-sync alert banner
                          _buildOperationalAlertCard(),

                          if (_domainReport?.hasOperationalAlerts ?? false)
                            const SizedBox(height: 16),

                          // ── THAO TÁC ──
                          //
                          // Trước 06/09/2026 màn này có 8 nút, phần lớn trùng
                          // hoặc yếu hơn nhau:
                          // • "Tải từ Cloud" chỉ gọi downloadAllFromCloud —
                          //   KHÔNG xoá con trỏ đồng bộ nên bản ghi cũ hơn con
                          //   trỏ không bao giờ về. Đã bỏ, gộp vào "Đồng bộ lại
                          //   toàn bộ" (có reset con trỏ) vốn làm đúng việc đó.
                          // • "SỬA TỰ ĐỘNG" chạy trên danh sách 17 bảng chép
                          //   tay, thiếu 14 bảng ⇒ sửa xong vẫn thiếu dữ liệu
                          //   mà báo là đã xong. Đã bỏ.
                          // • "Kiểm tra kết nối Firestore" và "Thống kê Firebase
                          //   Read/Write" trùng nguyên vẹn 2 mục trong
                          //   Cài đặt → Dữ liệu & Hệ thống. Đã bỏ khỏi đây.
                          _buildMismatchBreakdownCard(),
                          _buildPendingBreakdownCard(),

                          const Text(
                            'THAO TÁC ĐỒNG BỘ',
                            style: TextStyle(
                              fontSize: AppTextStyles.subtitle1Size,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),

                          _buildActionTile(
                            icon: Icons.sync,
                            iconColor: Colors.blue,
                            title: 'Đồng bộ lại toàn bộ',
                            subtitle:
                                'Xoá mốc đồng bộ và tải lại đủ dữ liệu từ cloud',
                            onTap: _handleReinitializeSync,
                          ),

                          _buildActionTile(
                            icon: Icons.cloud_upload,
                            iconColor: Colors.green,
                            title: 'Đẩy dữ liệu máy này lên cloud',
                            subtitle:
                                'Dùng khi máy này có đơn chưa lên — không xoá gì trên cloud',
                            onTap: _handleUpload,
                          ),

                          // Chỉ hiện khi thật sự có item lỗi trong hàng đợi.
                          if (_syncQueueStats != null &&
                              (_syncQueueStats!['failed'] ?? 0) > 0)
                            _buildActionTile(
                              icon: Icons.refresh,
                              iconColor: Colors.orange,
                              title:
                                  'Thử lại ${_syncQueueStats!['failed']} mục lỗi',
                              subtitle: 'Đưa các mục sync thất bại về hàng đợi',
                              onTap: _handleRetryFailed,
                            ),

                          const SizedBox(height: 16),

                          const Text(
                            'KIỂM TRA',
                            style: TextStyle(
                              fontSize: AppTextStyles.subtitle1Size,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),

                          _buildActionTile(
                            icon: Icons.health_and_safety,
                            iconColor: Colors.teal,
                            title: 'Kiểm tra chi tiết',
                            subtitle:
                                'So sánh từng bảng Local vs Cloud (đọc nhiều, chỉ dùng khi nghi ngờ)',
                            onTap: _handleDetailedCheck,
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Tên tiếng Việt của từng loại dữ liệu trong hàng đợi đồng bộ.
  ///
  /// `entityType` lưu trong `sync_queue` là tên enum (`repair`, `debtPayment`…)
  /// — đọc thẳng lên màn hình thì người dùng không hiểu.
  static const Map<String, String> _entityLabels = {
    'repair': 'Đơn sửa',
    'sale': 'Đơn bán',
    'product': 'Sản phẩm',
    'expense': 'Thu / chi',
    'debt': 'Công nợ',
    'customer': 'Khách hàng',
    'supplier': 'Nhà cung cấp',
    'attendance': 'Chấm công',
    'repairPart': 'Phụ tùng đơn sửa',
    'quickInputCode': 'Mã nhập nhanh',
    'debtPayment': 'Phiếu thu/trả nợ',
    'supplierPayment': 'Thanh toán NCC',
    'partnerPayment': 'Thanh toán đối tác',
    'repairPartner': 'Đối tác sửa chữa',
    'auditLog': 'Nhật ký hệ thống',
    'cashClosing': 'Chốt quỹ',
    'adjustmentEntry': 'Bút toán điều chỉnh',
    'purchaseOrder': 'Đơn nhập hàng',
    'supplierImportHistory': 'Lịch sử nhập kho',
    'salvagePhone': 'Máy xác',
    'salesReturn': 'Trả hàng',
    'salesReturnItem': 'Chi tiết trả hàng',
    'priceCatalogItem': 'Bảng giá NCC',
  };

  static String _entityLabel(String raw) => _entityLabels[raw] ?? raw;

  /// Khối "ĐANG CHỜ ĐẨY LÊN CLOUD" — nói rõ hàng đợi đang kẹt những gì.
  ///
  /// Trước đây màn này chỉ hiện con số trên huy hiệu đỏ ("88") mà không cho
  /// biết 88 món đó là gì, nên không phân biệt được "88 dòng nhật ký lặt vặt"
  /// với "88 đơn bán chưa lên cloud" — hai tình huống nghiêm trọng khác hẳn
  /// nhau.
  /// Tên tiếng Việt của từng bảng dữ liệu khi so Local vs Cloud.
  static const Map<String, String> _collectionLabels = {
    'repairs': 'Đơn sửa',
    'sales': 'Đơn bán',
    'products': 'Sản phẩm',
    'expenses': 'Thu / chi',
    'debts': 'Công nợ',
    'debt_payments': 'Phiếu thu/trả nợ',
    'customers': 'Khách hàng',
    'suppliers': 'Nhà cung cấp',
    'supplier_payments': 'Thanh toán NCC',
    'repair_partners': 'Đối tác sửa chữa',
    'repair_partner_payments': 'Thanh toán đối tác',
    'attendance': 'Chấm công',
    'audit_logs': 'Nhật ký hệ thống',
    'cash_closings': 'Chốt quỹ',
    'purchase_orders': 'Đơn nhập hàng',
    'supplier_import_history': 'Lịch sử nhập kho',
    'salvage_phones': 'Máy xác',
    'sales_returns': 'Trả hàng',
    'price_catalog_items': 'Bảng giá NCC',
    'financial_activity_log': 'Nhật ký tài chính',
    'quick_input_codes': 'Mã nhập nhanh',
    'stock_entries': 'Phiếu nhập kho',
    'adjustment_entries': 'Bút toán điều chỉnh',
    'storage_locations': 'Vị trí lưu kho',
    'work_schedules': 'Lịch làm việc',
    'shop_settings': 'Cài đặt shop',
  };

  static String _collectionLabel(String raw) =>
      _collectionLabels[raw] ?? raw;

  /// Khối giải thích con số **"N bản ghi chưa khớp"** trên thẻ trạng thái.
  ///
  /// Thẻ trạng thái chỉ ghi *"CẦN ĐỒNG BỘ · 88 bản ghi chưa khớp"* — người dùng
  /// không biết 88 đó là **bảng nào**, và quan trọng hơn là **lệch chiều nào**:
  ///
  /// - *Chưa lên cloud* — có ở máy này, cloud chưa có ⇒ máy khác chưa thấy.
  /// - *Chưa về máy này* — cloud có, máy này chưa tải ⇒ mở ra thấy thiếu.
  ///
  /// Hai chiều đó xử lý bằng hai nút khác nhau ("Đẩy dữ liệu máy này lên cloud"
  /// vs "Đồng bộ lại toàn bộ"), nên gộp làm một con số thì không biết bấm nút
  /// nào. `SyncHealthReport.results` vốn đã có đủ số liệu, chỉ là chưa hiện ra.
  Widget _buildMismatchBreakdownCard() {
    final report = _healthReport;
    if (report == null || report.isFullyHealthy) return const SizedBox.shrink();

    final rows = report.results
        .where((r) => r.effectiveMismatchCount > 0)
        .toList()
      ..sort(
        (a, b) => b.effectiveMismatchCount.compareTo(a.effectiveMismatchCount),
      );
    if (rows.isEmpty) return const SizedBox.shrink();

    final upTotal = rows.fold<int>(
      0,
      (s, r) => s + r.localOnly + r.pendingCreateLocal + r.pendingUpdateLocal,
    );
    final downTotal = rows.fold<int>(0, (s, r) => s + r.cloudOnly);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.compare_arrows_rounded,
                size: 18,
                color: Colors.orange.shade800,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${report.totalMismatches} BẢN GHI CHƯA KHỚP — Ở ĐÂU',
                  style: TextStyle(
                    fontSize: AppTextStyles.subtitle1Size,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _collectionLabel(r.collection),
                      style: TextStyle(fontSize: AppTextStyles.body1.fontSize),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (r.localOnly + r.pendingCreateLocal + r.pendingUpdateLocal >
                      0) ...[
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 12,
                      color: Colors.blue.shade700,
                    ),
                    Text(
                      '${r.localOnly + r.pendingCreateLocal + r.pendingUpdateLocal}',
                      style: TextStyle(
                        fontSize: AppTextStyles.body1.fontSize,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (r.cloudOnly > 0) ...[
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: 12,
                      color: Colors.teal.shade700,
                    ),
                    Text(
                      '${r.cloudOnly}',
                      style: TextStyle(
                        fontSize: AppTextStyles.body1.fontSize,
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const Divider(height: 16),
          if (upTotal > 0)
            Row(
              children: [
                Icon(
                  Icons.arrow_upward_rounded,
                  size: 13,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$upTotal mục có ở máy này mà cloud chưa có — bấm '
                    '"Đẩy dữ liệu máy này lên cloud".',
                    style: TextStyle(
                      fontSize: AppTextStyles.caption.fontSize,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          if (downTotal > 0) ...[
            if (upTotal > 0) const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 13,
                  color: Colors.teal.shade700,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$downTotal mục cloud có mà máy này chưa tải — bấm '
                    '"Đồng bộ lại toàn bộ".',
                    style: TextStyle(
                      fontSize: AppTextStyles.caption.fontSize,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Dữ liệu KHÔNG mất — chỉ là hai bên chưa khớp nhau.',
            style: TextStyle(
              fontSize: AppTextStyles.caption.fontSize,
              color: Colors.grey.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingBreakdownCard() {
    if (_pendingBreakdown.isEmpty) return const SizedBox.shrink();

    final total = _pendingBreakdown.fold<int>(
      0,
      (s, e) => s + (e['count'] as int),
    );
    // Món cũ nhất còn kẹt + số lần thử lại nhiều nhất: hai dấu hiệu phân biệt
    // "mới xếp hàng, chờ chút là xong" với "kẹt lâu rồi, cần xử lý".
    final oldestAt = _pendingBreakdown
        .map((e) => e['oldestAt'] as int)
        .where((v) => v > 0)
        .fold<int>(0, (a, b) => a == 0 || b < a ? b : a);
    final maxRetry = _pendingBreakdown.fold<int>(
      0,
      (a, e) => (e['maxRetry'] as int) > a ? e['maxRetry'] as int : a,
    );
    final stuck = maxRetry >= 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (stuck ? Colors.orange : Colors.blue).shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (stuck ? Colors.orange : Colors.blue).shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                stuck ? Icons.warning_amber_rounded : Icons.cloud_upload_outlined,
                size: 18,
                color: (stuck ? Colors.orange : Colors.blue).shade700,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ĐANG CHỜ ĐẨY LÊN CLOUD: $total mục',
                  style: TextStyle(
                    fontSize: AppTextStyles.subtitle1Size,
                    fontWeight: FontWeight.bold,
                    color: (stuck ? Colors.orange : Colors.blue).shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final e in _pendingBreakdown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _entityLabel(e['entityType'] as String),
                      style: TextStyle(fontSize: AppTextStyles.body1.fontSize),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if ((e['maxRetry'] as int) > 0) ...[
                    Text(
                      'thử lại ${e['maxRetry']} lần',
                      style: TextStyle(
                        fontSize: AppTextStyles.caption.fontSize,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    '${e['count']}',
                    style: TextStyle(
                      fontSize: AppTextStyles.body1.fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          if (oldestAt > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Cũ nhất: ${DateFormat('dd/MM HH:mm').format(DateTime.fromMillisecondsSinceEpoch(oldestAt))}',
              style: TextStyle(
                fontSize: AppTextStyles.caption.fontSize,
                color: Colors.grey.shade700,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            stuck
                ? 'Đã thử lại nhiều lần mà chưa lên được — kiểm tra mạng rồi bấm '
                      '"Đẩy dữ liệu máy này lên cloud" bên dưới.'
                : 'Dữ liệu đã lưu an toàn trên máy, đang chờ đẩy lên. Có mạng là '
                      'tự lên; muốn đẩy ngay thì bấm "Đẩy dữ liệu máy này lên cloud".',
            style: TextStyle(
              fontSize: AppTextStyles.caption.fontSize,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthStatusCard() {
    final isHealthy = _healthReport?.isFullyHealthy ?? true;
    final color = isHealthy ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isHealthy ? Icons.check_circle : Icons.warning,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHealthy ? 'ĐỒNG BỘ TỐT' : 'CẦN ĐỒNG BỘ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: AppTextStyles.headline3.fontSize,
                  ),
                ),
                const SizedBox(height: 4),
                if (_healthReport != null) ...[
                  Text(
                    'Local: ${_healthReport!.totalLocalRecords} | Cloud: ${_healthReport!.totalCloudRecords}',
                    style: TextStyle(
                      fontSize: AppTextStyles.subtitle1.fontSize,
                    ),
                  ),
                  if (!isHealthy)
                    Text(
                      '${_healthReport!.totalMismatches} bản ghi chưa khớp',
                      style: TextStyle(
                        fontSize: AppTextStyles.body1.fontSize,
                        color: Colors.orange.shade700,
                      ),
                    ),
                ] else
                  Text(
                    'Đang kiểm tra...',
                    style: TextStyle(
                      fontSize: AppTextStyles.subtitle1.fontSize,
                    ),
                  ),
                // Show realtime sync status
                Row(
                  children: [
                    Icon(
                      _isRealtimeSyncActive ? Icons.wifi : Icons.wifi_off,
                      size: 12,
                      color: _isRealtimeSyncActive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isRealtimeSyncActive ? 'Realtime: ON' : 'Realtime: OFF',
                      style: TextStyle(
                        fontSize: AppTextStyles.body1.fontSize,
                        color: _isRealtimeSyncActive
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    if (_syncQueueStats != null &&
                        (_syncQueueStats!['pending'] ?? 0) > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '| Queue: ${_syncQueueStats!['pending']} pending',
                        style: TextStyle(
                          fontSize: AppTextStyles.body1.fontSize,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                    if (_syncQueueStats != null &&
                        (_syncQueueStats!['failed'] ?? 0) > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        ', ${_syncQueueStats!['failed']} failed',
                        style: TextStyle(
                          fontSize: AppTextStyles.body1.fontSize,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.storage, size: 18, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                'DỮ LIỆU LOCAL',
                style: TextStyle(
                  fontSize: AppTextStyles.subtitle1Size,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_localStats != null)
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildStatChip(
                  'Sửa chữa',
                  _localStats!['repairs'] ?? 0,
                  Icons.build,
                ),
                _buildStatChip(
                  'Bán hàng',
                  _localStats!['sales'] ?? 0,
                  Icons.shopping_cart,
                ),
                _buildStatChip(
                  'Sản phẩm',
                  _localStats!['products'] ?? 0,
                  Icons.inventory,
                ),
                _buildStatChip(
                  'Chi phí',
                  _localStats!['expenses'] ?? 0,
                  Icons.money_off,
                ),
                _buildStatChip(
                  'Công nợ',
                  _localStats!['debts'] ?? 0,
                  Icons.account_balance,
                ),
              ],
            )
          else
            const Text('Đang tải...'),
        ],
      ),
    );
  }

  Widget _buildDomainSyncReportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assessment, size: 18, color: Colors.black87),
              SizedBox(width: 8),
              Text(
                'BÁO CÁO SYNC THEO NGHIỆP VỤ',
                style: TextStyle(
                  fontSize: AppTextStyles.subtitle1Size,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_domainReport == null)
            const Text('Đang tổng hợp báo cáo...')
          else
            ..._domainReport!.domains.map(_buildDomainRow),
        ],
      ),
    );
  }

  Widget _buildDomainRow(DomainSyncReport domain) {
    final statusColor = _domainStatusColor(domain);
    final statusIcon = _domainStatusIcon(domain);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 18, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  domain.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: AppTextStyles.subtitle1Size,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  domain.statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: AppTextStyles.body1Size,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Queue: ${domain.pendingQueue} chờ | ${domain.processingQueue} đang xử lý | ${domain.failedQueue} lỗi',
            style: TextStyle(
              fontSize: AppTextStyles.body1.fontSize,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Local chưa sync: ${domain.unsyncedLocal} | Lệch local-cloud: ${domain.mismatchCount} | Tổng local: ${domain.totalLocalRecords}',
            style: TextStyle(
              fontSize: AppTextStyles.body1.fontSize,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '24h gần nhất: ${domain.recentSuccessCount} thành công | ${domain.recentRetryCount} retry | ${domain.recentFailedCount} lỗi',
            style: TextStyle(
              fontSize: AppTextStyles.body1.fontSize,
              color: domain.recentIssueCount > 0
                  ? Colors.orange.shade800
                  : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            domain.lastSyncAt != null
                ? 'Cập nhật cloud gần nhất: ${_formatSyncTime(domain.lastSyncAt!)}'
                : 'Cập nhật cloud gần nhất: chưa có mốc sync',
            style: TextStyle(
              fontSize: AppTextStyles.body1.fontSize,
              color: Colors.grey.shade700,
            ),
          ),
          if (domain.lastFailureAt != null)
            Text(
              'Lần lỗi gần nhất: ${_formatSyncTime(domain.lastFailureAt!)}',
              style: TextStyle(
                fontSize: AppTextStyles.body1.fontSize,
                color: Colors.red.shade700,
              ),
            )
          else if (domain.lastSuccessAt != null)
            Text(
              'Lần thành công gần nhất: ${_formatSyncTime(domain.lastSuccessAt!)}',
              style: TextStyle(
                fontSize: AppTextStyles.body1.fontSize,
                color: Colors.green.shade700,
              ),
            ),
          if (domain.hasStuckQueue)
            Text(
              'Cảnh báo kẹt sync: ${domain.stalePendingQueue} pending + ${domain.staleProcessingQueue} processing > ${SyncDomainReportService.stuckQueueThresholdMinutes} phút${domain.oldestQueueAgeMinutes != null ? ' (cũ nhất ${domain.oldestQueueAgeMinutes} phút)' : ''}',
              style: TextStyle(
                fontSize: AppTextStyles.body1.fontSize,
                color: Colors.deepOrange.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOperationalAlertCard() {
    final report = _domainReport;
    if (report == null || !report.hasOperationalAlerts) {
      return const SizedBox.shrink();
    }

    final alertDomains = report.alertDomains;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.deepOrange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepOrange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.deepOrange.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                'CẢNH BÁO VẬN HÀNH SYNC',
                style: TextStyle(
                  color: Colors.deepOrange.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: AppTextStyles.subtitle1Size,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Phát hiện ${report.totalStuckQueue} item kẹt > ${SyncDomainReportService.stuckQueueThresholdMinutes} phút và ${report.totalFailed} item failed trong queue.',
            style: TextStyle(
              fontSize: AppTextStyles.body1.fontSize,
              color: Colors.deepOrange.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ...alertDomains.map(
            (domain) => Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '• ${domain.title}: failed=${domain.failedQueue}, kẹt=${domain.staleQueueTotal}',
                style: TextStyle(
                  fontSize: AppTextStyles.body1.fontSize,
                  color: Colors.deepOrange.shade700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _domainStatusColor(DomainSyncReport domain) {
    if (domain.hasError) return Colors.red;
    if (domain.hasStuckQueue) return Colors.deepOrange;
    if (domain.hasPending) return Colors.orange;
    return Colors.green;
  }

  IconData _domainStatusIcon(DomainSyncReport domain) {
    if (domain.hasError) return Icons.cloud_off;
    if (domain.hasStuckQueue) return Icons.warning_amber_rounded;
    if (domain.hasPending) return Icons.cloud_upload;
    return Icons.cloud_done;
  }

  String _formatSyncTime(DateTime dateTime) {
    final d = dateTime.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _buildStatChip(String label, int count, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: AppTextStyles.headline5.fontSize,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTextStyles.body1.fontSize,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: AppTextStyles.subtitle1.fontSize),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Future<void> _handleUpload() async {
    final confirm = await _showConfirmDialog(
      title: '📤 ĐẨY LÊN CLOUD',
      message:
          'Upload dữ liệu chưa đồng bộ từ máy này lên đám mây.\n\nDữ liệu trên cloud sẽ KHÔNG bị xóa.',
      confirmText: 'UPLOAD',
      confirmColor: Colors.green,
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Đang đẩy lên Cloud...';
    });

    try {
      await SyncService.syncAllToCloud(force: true);
      // Also sync pending queue
      await _orchestrator.syncAll();
      if (mounted) {
        Navigator.pop(context);
        NotificationService.showSnackBar(
          '✅ Đã đồng bộ lên Cloud!',
          color: Colors.green,
        );
      }
    } catch (e) {
      NotificationService.showSnackBar('❌ Lỗi: $e', color: Colors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleReinitializeSync() async {
    final confirm = await _showConfirmDialog(
      title: '🔄 KHỞI ĐỘNG LẠI REALTIME SYNC',
      message:
          'Kết nối lại tất cả listeners để nhận dữ liệu mới từ máy khác.\n\nDùng khi:\n• Không nhận được đơn mới từ máy khác\n• Biểu tượng sync vàng không chuyển xanh\n• Sau khi mất mạng',
      confirmText: 'KHỞI ĐỘNG LẠI',
      confirmColor: Colors.blue,
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Đang khởi động lại listeners...';
    });

    try {
      // Check current sync status before reinit
      final isActive = SyncService.isRealTimeSyncActive;
      final status = SyncService.subscriptionStatus;
      debugPrint(
        '📊 Current sync status: isActive=$isActive, subscriptions=$status',
      );

      // Force reinitialize
      await SyncService.forceReinitializeSync();

      // Wait a moment for subscriptions to establish
      await Future.delayed(const Duration(seconds: 2));

      // Download latest data after reinit
      setState(() => _loadingMessage = 'Đang tải dữ liệu mới...');
      await SyncService.downloadAllFromCloud(force: true);

      if (mounted) {
        Navigator.pop(context);
        final newStatus = SyncService.subscriptionStatus;
        NotificationService.showSnackBar(
          '✅ Đã khởi động lại ${newStatus.length} listeners!',
          color: Colors.green,
        );
      }
    } catch (e) {
      NotificationService.showSnackBar('❌ Lỗi: $e', color: Colors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRetryFailed() async {
    final confirm = await _showConfirmDialog(
      title: '🔄 THỬ LẠI ITEMS LỖI',
      message:
          'Reset và sync lại tất cả items đã bị đánh dấu failed.\n\nCác items này sẽ được đưa trở lại hàng đợi sync.',
      confirmText: 'THỬ LẠI',
      confirmColor: Colors.orange,
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Đang reset...';
    });

    try {
      await _orchestrator.retryFailedItems();

      // Trigger sync after retry
      setState(() => _loadingMessage = 'Đang sync...');
      await _orchestrator.syncAll();

      // Reload stats
      _syncQueueStats = await _orchestrator.getSyncStats();
      _domainReport = await SyncDomainReportService.buildReport(
        healthReport: _healthReport,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        NotificationService.showSnackBar(
          '✅ Đã reset và thử sync lại!',
          color: Colors.green,
        );
      }
    } catch (e) {
      NotificationService.showSnackBar('❌ Lỗi: $e', color: Colors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDetailedCheck() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Đang kiểm tra chi tiết...';
    });

    try {
      final report = await SyncHealthCheck.runFullCheck(force: true);
      if (mounted) {
        _healthReport = report;
        _domainReport = await SyncDomainReportService.buildReport(
          healthReport: report,
        );
        setState(() => _isLoading = false);
        _showDetailedReportDialog(report);
      }
    } catch (e) {
      NotificationService.showSnackBar('❌ Lỗi: $e', color: Colors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFirestoreConnectivityTest() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Đang kiểm tra kết nối Firestore...';
    });

    try {
      final report = await FirestoreConnectivityService.runDiagnostics();
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _firestoreConnectivityReport = report;
      });

      _showFirestoreConnectivityDialog(report);
      NotificationService.showSnackBar(
        report.isHealthy
            ? '✅ Firestore kết nối ổn định'
            : '⚠️ Firestore cần kiểm tra thêm',
        color: report.isHealthy ? Colors.green : Colors.orange,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      NotificationService.showSnackBar(
        '❌ Lỗi kiểm tra kết nối: $e',
        color: Colors.red,
      );
    }
  }

  void _showDetailedReportDialog(SyncHealthReport report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              report.isFullyHealthy ? Icons.check_circle : Icons.warning,
              color: report.isFullyHealthy ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(
              report.isFullyHealthy ? 'ĐỒNG BỘ TỐT' : 'CẦN ĐỒNG BỘ',
              style: TextStyle(
                color: report.isFullyHealthy ? Colors.green : Colors.orange,
                fontSize: AppTextStyles.headline3.fontSize,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Shop ID: ${report.shopId ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: AppTextStyles.body1.fontSize,
                    color: Colors.grey,
                  ),
                ),
                const Divider(),
                ...report.results.map((r) => _buildReportRow(r)),
              ],
            ),
          ),
        ),
        actions: [
          if (!report.isFullyHealthy)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                // Trước đây gọi _handleFullSync (upload rồi download) — không
                // xoá con trỏ nên vẫn thiếu bản ghi cũ. Dùng đường đồng bộ lại
                // toàn bộ cho thống nhất với nút chính.
                await _handleReinitializeSync();
              },
              child: const Text('SỬA LỖI'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ĐÓNG'),
          ),
        ],
      ),
    );
  }

  void _showFirestoreConnectivityDialog(FirestoreConnectivityReport report) {
    final statusColor = report.isHealthy ? Colors.green : Colors.orange;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              report.isHealthy ? Icons.wifi : Icons.wifi_off,
              color: statusColor,
            ),
            const SizedBox(width: 8),
            Text(
              report.isHealthy
                  ? 'KẾT NỐI FIRESTORE TỐT'
                  : 'FIRESTORE CẦN KIỂM TRA',
              style: TextStyle(
                color: statusColor,
                fontSize: AppTextStyles.headline3.fontSize,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tổng quan: ${report.summary}',
                  style: TextStyle(fontSize: AppTextStyles.body1.fontSize),
                ),
                const SizedBox(height: 8),
                if (report.latencyMs > 0)
                  Text(
                    'Độ trễ trung bình: ${report.latencyMs} ms',
                    style: TextStyle(
                      fontSize: AppTextStyles.subtitle1.fontSize,
                      color: Colors.grey.shade700,
                    ),
                  ),
                const Divider(height: 20),
                _buildConnectivityCheckRow('Internet', report.hasNetwork),
                _buildConnectivityCheckRow(
                  'Đăng nhập Firebase Auth',
                  report.hasAuthenticatedUser,
                ),
                _buildConnectivityCheckRow(
                  'Kết nối Firestore server',
                  report.canReachFirestoreServer,
                ),
                _buildConnectivityCheckRow(
                  'Đọc hồ sơ người dùng',
                  report.canReadCurrentUserDocument,
                ),
                _buildConnectivityCheckRow(
                  report.hasShopContext
                      ? 'Đọc dữ liệu theo shop'
                      : 'Ngữ cảnh shop',
                  report.hasShopContext ? report.canReadShopScopedData : true,
                ),
                if (report.warnings.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Cảnh báo:',
                    style: TextStyle(
                      fontSize: AppTextStyles.subtitle1.fontSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  ...report.warnings.map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '• $w',
                        style: TextStyle(
                          fontSize: AppTextStyles.body1.fontSize,
                        ),
                      ),
                    ),
                  ),
                ],
                if (report.errors.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Lỗi phát hiện:',
                    style: TextStyle(
                      fontSize: AppTextStyles.subtitle1.fontSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                  ...report.errors.map(
                    (err) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '• $err',
                        style: TextStyle(
                          fontSize: AppTextStyles.body1.fontSize,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Khuyến nghị:',
                  style: TextStyle(
                    fontSize: AppTextStyles.subtitle1.fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ...report.recommendations.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• $tip',
                      style: TextStyle(fontSize: AppTextStyles.body1.fontSize),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleFirestoreConnectivityTest();
            },
            child: const Text('Kiểm tra lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectivityCheckRow(String title, bool ok) {
    final color = ok ? Colors.green : Colors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.error_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: AppTextStyles.body1.fontSize),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(SyncCheckResult r) {
    final isOk = r.isHealthy;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check : Icons.warning,
            color: isOk ? Colors.green : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.collection,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: AppTextStyles.headline5.fontSize,
                  ),
                ),
                Text(
                  'Local: ${r.localCount} | Cloud: ${r.cloudCount}',
                  style: TextStyle(
                    fontSize: AppTextStyles.body1.fontSize,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${r.displayPercentage}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isOk ? Colors.green : Colors.orange,
              fontSize: AppTextStyles.subtitle1.fontSize,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(color: confirmColor, fontWeight: FontWeight.bold),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            child: Text(
              confirmText,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
