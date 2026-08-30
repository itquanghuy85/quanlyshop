import 'package:flutter/material.dart';
import '../widgets/keyboard_aware_padding.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/app_localizations.dart';
import '../utils/money_utils.dart';
import '../widgets/currency_text_field.dart';
import '../data/db_helper.dart';
import '../services/notification_service.dart';
import '../widgets/custom_app_bar.dart';
import '../services/sync_service.dart';
import '../services/sync_orchestrator.dart';
import '../services/encryption_service.dart';
import '../services/user_service.dart';
import '../services/event_bus.dart';
import '../services/adjustment_service.dart';
import '../services/first_time_guide_service.dart';
import '../services/debt_summary_service.dart';
import '../services/repair_partner_service.dart';
import '../models/repair_partner_model.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_colors.dart';
import '../theme/popup_theme.dart';
import '../widgets/app_popup.dart';
import '../widgets/debt_payment_sheet.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/skeleton_list.dart';
import '../models/shop_settings_model.dart';
import '../services/category_service.dart';
import '../widgets/responsive_wrapper.dart';
import 'sale_detail_view.dart';
import 'repair_detail_view.dart';
import 'repair_partner_detail_view.dart';
import '../utils/excel_export_helper.dart';
import '../utils/vietnamese_utils.dart';
import '../widgets/export_date_filter_dialog.dart';
import '../finance_v2/finance_v2_theme.dart';
import 'money_reconcile_view.dart';
import 'package:url_launcher/url_launcher.dart';

class DebtView extends StatefulWidget {
  const DebtView({super.key});
  @override
  State<DebtView> createState() => _DebtViewState();
}

class _DebtViewState extends State<DebtView>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final db = DBHelper();
  final _partnerService = RepairPartnerService();
  final _debtSummaryService = DebtSummaryService();
  TabController? _tabController;
  List<Map<String, dynamic>> _debts = [];
  List<Map<String, dynamic>> _partnerDebts = []; // Công nợ đối tác sửa chữa
  bool _isLoading = true;
  bool _isSyncing = false;
  String _syncStatus = '';
  StreamSubscription<String>? _eventSub;
  Timer? _reloadDebounce;

  String _plainText(dynamic value) {
    final raw = (value ?? '').toString();
    if (raw.isEmpty) return raw;
    return EncryptionService.decrypt(raw).trim();
  }

  String _debtPersonName(Map<String, dynamic> debt) {
    final plain = _plainText(debt['personName']);
    return plain.isEmpty ? 'N/A' : plain;
  }

  String _debtPhone(Map<String, dynamic> debt) {
    return _plainText(debt['phone']);
  }

  // Shop settings for multi-industry
  ShopSettings? _shopSettings;
  bool get _enableRepair => _shopSettings?.enableRepair ?? true;
  bool _hasPermission = false;

  // Tìm kiếm và lọc
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showPaidDebts = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _loadShopSettings();
    _loadRole();
    _refresh();

    // Listen to global events (e.g., debts changed) to refresh the list when other parts of the app write debts
    _eventSub = EventBus().stream
        .where((e) => e == 'debts_changed' || e == 'repair_partners_changed')
        .listen((_) {
          _debouncedRefresh();
        });

    // Hiển thị hướng dẫn cho người dùng mới
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFirstTimeGuide();
    });
  }

  Future<void> _loadShopSettings() async {
    try {
      final settings = await CategoryService().getShopSettings();
      if (mounted) {
        setState(() {
          _shopSettings = settings;
          _tabController = TabController(length: 2, vsync: this)
            ..addListener(_onTabChanged);
        });
      }
    } catch (e) {
      debugPrint('Error loading shop settings: $e');
      if (mounted) {
        setState(() {
          _tabController = TabController(length: 2, vsync: this)
            ..addListener(_onTabChanged);
        });
      }
    }
  }

  /// Đảm bảo FAB (phụ thuộc tab đang chọn) cập nhật ngay khi đổi tab bằng vuốt,
  /// không chỉ khi bấm trực tiếp vào Tab.
  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  /// Hiển thị hướng dẫn lần đầu
  Future<void> _showFirstTimeGuide() async {
    final l10n = AppLocalizations.of(context)!;
    await FirstTimeGuideService.showGuideIfNeeded(
      context: context,
      screenKey: FirstTimeGuideService.keyDebtManagement,
      title: l10n.debtGuideTitle,
      icon: Icons.account_balance_wallet,
      color: Colors.red,
      steps: [
        const GuideStep(
          title: '🎯 Màn này để làm gì?',
          description:
              'ĐỂ LÀM GÌ: theo dõi ai đang nợ shop (PHẢI THU) và shop đang nợ ai (PHẢI TRẢ), ghi nhận khi thu/trả tiền.\n'
              'KHI NÀO DÙNG: xem còn phải đòi/phải trả bao nhiêu; bấm "Thu nợ"/"Thanh toán nợ" mỗi lần nhận hoặc trả tiền (được trả từng phần).\n'
              'VÍ DỤ: khách ABC nợ 4tr → nhận 1tr → bấm Thu nợ 1tr, còn nợ 3tr. Số "đã trả" tự cộng dồn và đồng bộ mọi thiết bị.',
          icon: Icons.lightbulb_outline,
          iconColor: Colors.amber,
        ),
        GuideStep(
          title: _enableRepair
              ? l10n.debtGuideStep1Title3Types
              : l10n.debtGuideStep1Title2Types,
          description: _enableRepair
              ? l10n.debtGuideStep1Desc3Types
              : l10n.debtGuideStep1Desc2Types,
          icon: Icons.category,
          iconColor: Colors.blue,
        ),
        GuideStep(
          title: l10n.debtGuideStep2Title,
          description: l10n.debtGuideStep2Desc,
          icon: Icons.payment,
          iconColor: Colors.green,
        ),
        GuideStep(
          title: l10n.debtGuideStep3Title,
          description: l10n.debtGuideStep3Desc,
          icon: Icons.event,
          iconColor: Colors.orange,
        ),
        GuideStep(
          title: l10n.debtGuideStep4Title,
          description: l10n.debtGuideStep4Desc,
          icon: Icons.auto_mode,
          iconColor: Colors.blue,
        ),
      ],
    );
  }

  void _debouncedRefresh() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    _eventSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    // Role loading not needed for current functionality
  }

  Future<void> _checkPermission() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() => _hasPermission = perms['allowViewDebts'] ?? false);
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);

    // Load regular debts
    final data = await db.getAllDebts();
    debugPrint('DebtView: getAllDebts returned ${data.length} debts');
    for (final d in data) {
      debugPrint(
        '  - type=${d['type']}, personName=${d['personName']}, totalAmount=${d['totalAmount']}, deleted=${d['deleted']}, firestoreId=${d['firestoreId']}',
      );
    }

    final partnerDebts = await _debtSummaryService.loadPartnerDebts(
      allDebts: data,
    );

    final manualPartnerDebts = partnerDebts
        .where((d) => d['source'] == 'manual')
        .toList();

    debugPrint(
      'DebtView: Found ${manualPartnerDebts.length} manual REPAIR_PARTNER debts',
    );
    for (final d in manualPartnerDebts) {
      debugPrint('  - ${d['partnerName']}: ${d['totalAmount']}');
    }

    if (!mounted) return;
    setState(() {
      _debts = _debtSummaryService.filterStandardDebts(data);
      _partnerDebts = partnerDebts;
      _isLoading = false;
    });
  }

  Future<void> _syncWithFirebase() async {
    if (_isSyncing) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSyncing = true;
      _syncStatus = l10n.syncingStatus;
    });

    try {
      await SyncService.syncAllToCloud();
      // Real-time listeners handle downloads — chỉ push local changes

      // Reload data after sync
      await _refresh();

      if (mounted) {
        setState(() {
          _syncStatus = AppLocalizations.of(context)!.syncedStatus;
        });
      }
    } catch (e) {
      debugPrint('Sync error: $e');
      if (mounted) {
        setState(() {
          _syncStatus = AppLocalizations.of(context)!.syncErrorStatus;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _showDebtHistory(Map<String, dynamic> debt) async {
    final payments = await db.getDebtPayments(debt['id']);
    if (!mounted) return;

    showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => KeyboardAwarePadding(
        child: Container(
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(ctx)!.paymentHistoryTitle,
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Text(
                _debtPersonName(debt).toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.onSurface.withOpacity(0.7),
                ),
              ),
              if (((debt['linkedId'] as String?) ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () => _openSourceOrder(ctx, debt),
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: const Text('Xem đơn gốc'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
              const Divider(height: 30),
              if (payments.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    AppLocalizations.of(ctx)!.noPaymentHistory,
                    style: AppTextStyles.body1.copyWith(
                      color: AppColors.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: ListView.builder(
                    itemCount: payments.length,
                    itemBuilder: (ctx, i) {
                      final p = payments[i];
                      final date = DateFormat('HH:mm - dd/MM/yyyy').format(
                        DateTime.fromMillisecondsSinceEpoch(p['paidAt']),
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(13),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "+ ${MoneyUtils.formatCurrency(p['amount'])}",
                                  style: AppTextStyles.priceStyle,
                                ),
                                Text(
                                  date,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  p['createdBy'] ?? "NV",
                                  style: AppTextStyles.caption.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  p['paymentMethod'] == 'CHUYỂN KHOẢN'
                                      ? AppLocalizations.of(ctx)!.bankTransfer
                                      : AppLocalizations.of(ctx)!.cash,
                                  style: AppTextStyles.overline.copyWith(
                                    color: AppColors.onSurface.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _payDebt(debt),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2962FF),
                ),
                child: Text(
                  AppLocalizations.of(ctx)!.payDebtButton,
                  style: AppTextStyles.button,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _payDebt(Map<String, dynamic> debt) async {
    final didPay = await DebtPaymentSheet.show(
      context,
      debt,
      onSuccess: _refresh,
    );
    if (didPay && mounted) await _refresh();
  }

  /// Mở nguồn gốc của khoản nợ. Nợ bán/sửa CÔNG NỢ → mở đơn bán/sửa. Nợ
  /// phát sinh khi NHẬP KHO / bổ sung giá vốn / nhập linh kiện thì KHÔNG có
  /// "đơn" riêng để mở (phiếu nhập nằm trên cloud, không lưu local) — hiện
  /// bảng thông tin nguồn thay vì báo "không tìm thấy" gây hiểu nhầm là
  /// dữ liệu bị xoá.
  Future<void> _openSourceOrder(
    BuildContext sheetCtx,
    Map<String, dynamic> debt,
  ) async {
    Navigator.pop(sheetCtx);
    final linkedId = ((debt['linkedId'] as String?) ?? '').trim();
    final fid = (debt['firestoreId'] as String?) ?? '';

    if (linkedId.isNotEmpty) {
      final sale = await db.getSaleByFirestoreId(linkedId);
      if (!mounted) return;
      if (sale != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SaleDetailView(sale: sale)),
        );
        return;
      }

      final repair = await db.getRepairByFirestoreId(linkedId);
      if (!mounted) return;
      if (repair != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RepairDetailView(repair: repair)),
        );
        return;
      }
    }

    if (!mounted) return;

    // Suy loại nguồn từ tiền tố firestoreId của khoản nợ.
    String source;
    if (fid.startsWith('debt_stock_')) {
      source = 'Nhập kho (phiếu nhập hàng từ NCC)';
    } else if (fid.startsWith('debt_cost_')) {
      source = 'Bổ sung giá vốn sản phẩm';
    } else if (fid.startsWith('debt_part_') ||
        fid.startsWith('debt_quick_part_')) {
      source = 'Nhập linh kiện từ NCC';
    } else if (fid.startsWith('debt_repair_') ||
        fid.startsWith('debt_partner_debt_')) {
      source = 'Đơn sửa chữa (đơn gốc có thể đã bị xoá)';
    } else if (fid.startsWith('debt_customer_') || linkedId.isNotEmpty) {
      source = 'Bán hàng CÔNG NỢ (đơn gốc có thể đã bị xoá)';
    } else {
      source = 'Tạo tay trong mục Công nợ';
    }

    final total = _toInt(debt['totalAmount']);
    final paid = _toInt(debt['paidAmount']);
    final createdAt = _toInt(debt['createdAt']);
    final dateStr = createdAt > 0
        ? DateFormat('HH:mm - dd/MM/yyyy')
            .format(DateTime.fromMillisecondsSinceEpoch(createdAt))
        : '—';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nguồn khoản nợ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _srcRow('Phát sinh từ', source),
            _srcRow('Đối tượng', (debt['personName'] ?? '').toString()),
            if ((debt['note'] ?? '').toString().trim().isNotEmpty)
              _srcRow('Nội dung', debt['note'].toString()),
            _srcRow('Tổng nợ', '${MoneyUtils.formatCurrency(total)}đ'),
            _srcRow('Đã trả', '${MoneyUtils.formatCurrency(paid)}đ'),
            _srcRow('Còn nợ', '${MoneyUtils.formatCurrency(total - paid)}đ'),
            _srcRow('Ngày tạo', dateStr),
            const SizedBox(height: 8),
            if (fid.startsWith('debt_stock_') ||
                fid.startsWith('debt_part_') ||
                fid.startsWith('debt_quick_part_') ||
                fid.startsWith('debt_cost_'))
              Text(
                'Khoản nợ này phát sinh khi nhập hàng — không tách thành đơn '
                'riêng để mở. Sản phẩm/linh kiện vẫn còn trong kho.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ĐÓNG'),
          ),
        ],
      ),
    );
  }

  Widget _srcRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 88,
              child: Text(
                k,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            Expanded(
              child: Text(
                v.isEmpty ? '—' : v,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final l10n = AppLocalizations.of(context)!;

    if (!_hasPermission) {
      return Scaffold(
        backgroundColor: FinanceV2Theme.pageBg,
        appBar: CustomAppBar.build(
          title: l10n.debtManagementTitle,
          accentColor: AppBarAccents.customer,
        ),
        body: Center(
          child: Text(
            l10n.noAccessPermission,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Chờ shop settings load xong
    if (_tabController == null) {
      return const Scaffold(
        body: SkeletonListView(
          variant: SkeletonVariant.debtCard,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      );
    }

    // Đếm số công nợ còn hiệu lực (bao gồm cả partner debts nếu có repair)
    final activeDebtsCount =
        _debts.where(_isActiveDebt).length +
        (_enableRepair ? _partnerDebts.length : 0);

    return Scaffold(
      backgroundColor: FinanceV2Theme.pageBg,
      appBar: CustomAppBar.buildWithTabs(
        guideKey: FirstTimeGuideService.keyDebtManagement,
        title: l10n.debtManagementTitle,
        subtitle: l10n.activeDebtsCount(activeDebtsCount),
        tabController: _tabController!,
        tabs: [
          Tab(text: l10n.debtReceivable),
          Tab(text: l10n.debtPayable),
        ],
        accentColor: AppBarAccents.customer,
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _syncStatus.isEmpty ? l10n.syncedStatus : _syncStatus,
                style: AppTextStyles.caption.copyWith(
                  color: _syncStatus == l10n.syncErrorStatus
                      ? Colors.orange
                      : Colors.white70,
                  fontWeight: _isSyncing ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isSyncing ? null : _syncWithFirebase,
                icon: Icon(
                  _isSyncing ? Icons.sync : Icons.sync_outlined,
                  color: _isSyncing ? Colors.orange : Colors.white,
                ),
                tooltip: l10n.syncWithFirebase,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.fact_check_outlined, color: Colors.white),
            tooltip: 'Đối soát tiền về',
            onPressed: () => openMoneyReconcile(context),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            tooltip: l10n.exportExcelDebt,
            onPressed: () async {
              final result = await ExportDateFilterDialog.show(
                context,
                title: l10n.exportDebtTitle,
              );
              if (result == null) return;
              if (!mounted) return;
              await ExcelExportHelper.exportDebts(
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
            ? const SkeletonListView(
                variant: SkeletonVariant.debtCard,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildDebtList('RECEIVABLE'),
                  _buildDebtList('PAYABLE'),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _showCreateDebtChooser(isReceivable: _tabController?.index == 0),
        backgroundColor: _tabController?.index == 0
            ? Colors.redAccent
            : Colors.blueAccent,
        tooltip: _tabController?.index == 0
            ? l10n.createCustomerDebtTooltip
            : l10n.createSupplierDebtTooltip,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Kiểm tra công nợ còn hiệu lực (chưa thanh toán hết và chưa bị hủy)
  bool _isActiveDebt(Map<String, dynamic> d) {
    return DebtSummaryService.isActiveDebt(d);
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  int _remainingDebt(Map<String, dynamic> debt) {
    final total = _toInt(debt['totalAmount']);
    final paid = _toInt(debt['paidAmount']);
    return (total - paid).clamp(0, total);
  }

  Widget _buildDebtList(String direction) {
    final l10n = AppLocalizations.of(context)!;
    final bool isReceivable = direction == 'RECEIVABLE';

    // Phải thu: khách nợ shop (CUSTOMER_OWES / legacy OWE) + nợ khác (thu).
    // Phải trả: shop nợ NCC (SHOP_OWES / legacy OWED) + nợ khác (trả).
    bool matchesDirection(String t) => isReceivable
        ? (t == 'CUSTOMER_OWES' || t == 'OWE' || t == 'OTHER_CUSTOMER_OWES')
        : (t == 'SHOP_OWES' || t == 'OWED' || t == 'OTHER_SHOP_OWES');

    List<Map<String, dynamic>> list = _debts.where((d) {
      final debtType = d['type']?.toString() ?? '';
      return matchesDirection(debtType) && (_showPaidDebts || _isActiveDebt(d));
    }).toList();

    // Khối nợ đối tác sửa chữa: số liệu tổng hợp riêng, chỉ có ở chiều Phải trả.
    final bool showPartnerSection = !isReceivable && _enableRepair;

    // KPI stats from full (unfiltered) active list
    final activeList = list.where(_isActiveDebt).toList();
    final kpiTotal = activeList.fold(0, (s, d) => s + _remainingDebt(d));
    int kpiOverdue = 0;
    int kpiUrgent = 0;
    for (final d in activeList) {
      final createdAt = _toInt(d['createdAt']);
      if (createdAt <= 0) continue;
      final days = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(createdAt))
          .inDays;
      if (days > 60) {
        kpiOverdue++;
      } else if (days > 30) {
        kpiUrgent++;
      }
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      list = list.where((d) {
        return VietnameseUtils.containsVietnamese(
              _debtPersonName(d),
              _searchQuery,
            ) ||
            VietnameseUtils.containsVietnamese(_debtPhone(d), _searchQuery) ||
            VietnameseUtils.containsVietnamese(
              d['note']?.toString() ?? '',
              _searchQuery,
            );
      }).toList();
    }

    int urgencyRank(Map<String, dynamic> d) {
      if (!_isActiveDebt(d)) return 3; // paid → bottom
      final createdAt = _toInt(d['createdAt']);
      if (createdAt <= 0) return 2; // no date → treat as normal
      final days = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(createdAt))
          .inDays;
      if (days > 60) return 0; // very urgent → top
      if (days > 30) return 1; // urgent
      return 2; // normal
    }

    list.sort((a, b) {
      final rankCmp = urgencyRank(a).compareTo(urgencyRank(b));
      if (rankCmp != 0) return rankCmp;
      // Within same urgency tier: higher remaining amount first
      final remainCmp = _remainingDebt(b).compareTo(_remainingDebt(a));
      if (remainCmp != 0) return remainCmp;
      return _toInt(b['createdAt']).compareTo(_toInt(a['createdAt']));
    });

    return Column(
      children: [
        // Search bar + toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: FinanceV2Theme.bodyMd,
                  decoration: InputDecoration(
                    hintText: l10n.searchNamePhone,
                    hintStyle: FinanceV2Theme.bodyMd.copyWith(
                      color: FinanceV2Theme.subInk,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: FinanceV2Theme.subInk,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFDDE3EF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFDDE3EF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: FinanceV2Theme.accent,
                      ),
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(
                  l10n.filterPaid,
                  style: const TextStyle(fontSize: 12),
                ),
                avatar: Icon(
                  Icons.filter_alt_outlined,
                  size: 16,
                  color: _showPaidDebts
                      ? Colors.green.shade700
                      : FinanceV2Theme.subInk,
                ),
                selected: _showPaidDebts,
                onSelected: (v) => setState(() => _showPaidDebts = v),
                selectedColor: Colors.green.shade100,
                checkmarkColor: Colors.green.shade700,
              ),
            ],
          ),
        ),
        // KPI row — tổng nợ còn + urgency counts (không tính nợ đối tác, đã có tổng riêng)
        if (activeList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              children: [
                _kpiChip(
                  label: isReceivable ? l10n.debtReceivable : l10n.debtPayable,
                  value: MoneyUtils.formatCompactCurrency(kpiTotal),
                  color: isReceivable
                      ? Colors.red.shade700
                      : Colors.blue.shade700,
                  icon: isReceivable
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                ),
                if (kpiOverdue > 0) ...[
                  const SizedBox(width: 6),
                  _kpiChip(
                    label: l10n.overdueDebts,
                    value: l10n.overdueCountDays(kpiOverdue),
                    color: Colors.red.shade700,
                    icon: Icons.warning_rounded,
                  ),
                ],
                if (kpiUrgent > 0) ...[
                  const SizedBox(width: 6),
                  _kpiChip(
                    label: l10n.needsHandling,
                    value: l10n.urgentCountDays(kpiUrgent),
                    color: Colors.orange.shade700,
                    icon: Icons.schedule_rounded,
                  ),
                ],
              ],
            ),
          ),

        if (list.isEmpty && (!showPartnerSection || _partnerDebts.isEmpty))
          Expanded(
            child: EmptyStateWidget(
              icon: Icons.receipt_long_outlined,
              title: _searchQuery.isNotEmpty
                  ? l10n.noDebtFound
                  : l10n.noDebtYet,
              subtitle: _searchQuery.isNotEmpty
                  ? l10n.trySearchOther
                  : _showPaidDebts
                  ? null
                  : (isReceivable
                      ? 'Khoản khách nợ shop tự hiện ở đây khi bán hàng chọn "CÔNG NỢ". '
                          'Bạn cũng có thể tự thêm bằng nút +. Bật "Hiện đã trả" để xem lịch sử.'
                      : 'Khoản shop nợ NCC/đối tác tự hiện ở đây khi nhập kho chọn "CÔNG NỢ". '
                          'Bạn cũng có thể tự thêm bằng nút +. Bật "Hiện đã trả" để xem lịch sử.'),
              onAction: (_searchQuery.isEmpty && !_showPaidDebts)
                  ? () => _showCreateDebtChooser(isReceivable: isReceivable)
                  : null,
              actionLabel: (_searchQuery.isEmpty && !_showPaidDebts)
                  ? 'Thêm khoản nợ'
                  : null,
            ),
          )
        else
          // Gộp 2 danh sách (nợ thường + nợ đối tác sửa chữa) vào 1 khung
          // cuộn liền mạch duy nhất, cao theo đúng nội dung thay vì chia
          // theo tỷ lệ cố định (3:2) — tỷ lệ cố định trước đây khiến danh
          // sách ngắn vẫn bị ép cắt cụt ngay trước khối tổng phía dưới.
          Expanded(
            child: ListView(
              // padding-bottom chừa chỗ cho nút "+" nổi, tránh che thẻ cuối
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                if (list.isNotEmpty) ..._buildSimpleDebtItems(list),
                if (showPartnerSection && _partnerDebts.isNotEmpty)
                  ..._buildPartnerDebtItems(),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _buildSimpleDebtItems(List<Map<String, dynamic>> list) {
    final l10n = AppLocalizations.of(context)!;
    final activeList = list.where(_isActiveDebt).toList();
    final totalRemain = activeList.fold(0, (sum, d) => sum + _remainingDebt(d));

    // Urgency triage counts
    int veryUrgentCount = 0;
    int urgentCount = 0;
    for (final d in activeList) {
      final createdAt = _toInt(d['createdAt']);
      if (createdAt <= 0) continue;
      final days = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(createdAt))
          .inDays;
      if (days > 60) {
        veryUrgentCount++;
      } else if (days > 30) {
        urgentCount++;
      }
    }
    final hasUrgency = veryUrgentCount > 0 || urgentCount > 0;

    return [
      _summaryHeader(l10n.totalRemainingDebt, totalRemain, Colors.redAccent),
      if (hasUrgency)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(
            children: [
              if (veryUrgentCount > 0)
                _urgencyChip(
                  l10n.overdueCountDays(veryUrgentCount),
                  Colors.red.shade100,
                  Colors.red.shade700,
                  Icons.warning_rounded,
                ),
              if (veryUrgentCount > 0 && urgentCount > 0)
                const SizedBox(width: 6),
              if (urgentCount > 0)
                _urgencyChip(
                  l10n.urgentCountDays(urgentCount),
                  Colors.orange.shade100,
                  Colors.orange.shade700,
                  Icons.schedule_rounded,
                ),
            ],
          ),
        ),
      if (hasUrgency) const SizedBox(height: 4) else const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            for (int i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _debtCard(list[i], i + 1),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _urgencyChip(String label, Color bg, Color fg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiChip({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build danh sách công nợ đối tác sửa chữa
  List<Widget> _buildPartnerDebtItems() {
    final l10n = AppLocalizations.of(context)!;
    if (_partnerDebts.isEmpty) {
      return [
        EmptyStateWidget(
          icon: Icons.handshake_outlined,
          title: l10n.noPartnerDebt,
          subtitle: l10n.partnerDebtManageGuide,
        ),
      ];
    }

    // Tính tổng còn nợ
    int totalRemain = _partnerDebts.fold(0, (sum, p) {
      return sum + (p['remainingDebt'] as int? ?? 0);
    });

    return [
      _summaryHeader(l10n.totalPartnerRepairDebt, totalRemain, Colors.orange),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            for (int i = 0; i < _partnerDebts.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _partnerDebtCard(_partnerDebts[i], i + 1),
              ),
          ],
        ),
      ),
    ];
  }

  /// Card hiển thị công nợ đối tác - style giống pending_stock_list_view
  Widget _partnerDebtCard(Map<String, dynamic> partner, int index) {
    final l10n = AppLocalizations.of(context)!;
    final name = partner['name'] ?? l10n.debtPartnerDefaultName(index);
    final phone = partner['phone'] ?? '';
    final totalRepairs = _toInt(partner['totalRepairs']);
    final totalCost = _toInt(partner['totalCost']);
    final totalPaid = _toInt(partner['totalPaid']);
    final remainingDebt = _toInt(partner['remainingDebt']);
    final note = partner['note']?.toString() ?? '';
    final source = partner['source'] ?? 'repairs';
    final isMissing = partner['missingPartner'] == true;
    final isAltRow = index.isEven;
    final hasMeaningfulNote =
        note.trim().isNotEmpty && note.trim().toLowerCase() != 'nợ';

    return Card(
      margin: const EdgeInsets.only(bottom: 3),
      color: isAltRow
          ? Color.alphaBlend(Colors.orange.withOpacity(0.03), Colors.white)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: InkWell(
        onTap: () => _navigateToPartnerDetail(partner),
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Type icon (warning if partner document missing) — bỏ số
                  // thứ tự vì không mang ý nghĩa gì với người dùng
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isMissing
                          ? Colors.red.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      isMissing ? Icons.warning_amber_rounded : Icons.handshake,
                      color: isMissing
                          ? Colors.red.shade700
                          : Colors.orange.shade800,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Name and phone
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppTextStyles.headline5.fontSize,
                                  color: isMissing ? Colors.red.shade700 : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isMissing)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Tooltip(
                                  message: l10n.partnerNotInSystemTooltip,
                                  child: Icon(
                                    Icons.info_outline,
                                    size: 14,
                                    color: Colors.red.shade400,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (phone.isNotEmpty)
                          Text(
                            '📞 $phone',
                            style: TextStyle(
                              fontSize: AppTextStyles.caption.fontSize,
                              color: Colors.grey.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Order count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.ordersCountLabel(totalRepairs),
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: AppTextStyles.caption.fontSize,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Info chips row
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _debtInfoChip(
                    l10n.partnerRepairType,
                    Colors.orange.withValues(alpha: 0.14),
                    Colors.orange.shade800,
                  ),
                  _debtInfoChip(
                    source == 'manual' ? l10n.manualSource : l10n.autoSource,
                    Colors.grey.shade200,
                    Colors.grey.shade700,
                  ),
                ],
              ),

              if (hasMeaningfulNote) ...[
                const SizedBox(height: 6),
                Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTextStyles.caption.fontSize,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],

              const Divider(height: 12),

              // Amount row
              Row(
                children: [
                  Expanded(
                    child: _amountPill(
                      label: l10n.totalFeeLabel,
                      amount: totalCost,
                      valueColor: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _amountPill(
                      label: l10n.paidAmountLabel,
                      amount: totalPaid,
                      valueColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _amountPill(
                      label: l10n.remainingDebtLabel,
                      amount: remainingDebt,
                      valueColor: Colors.white,
                      bgColor: Colors.orange,
                      labelColor: Colors.white70,
                    ),
                  ),
                ],
              ),

              // Action button
              if (remainingDebt > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _navigateToPartnerDetail(partner),
                      icon: const Icon(Icons.visibility, size: 15),
                      label: Text(
                        l10n.paymentAction,
                        style: TextStyle(
                          fontSize: AppTextStyles.body1.fontSize,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Điều hướng đến trang chi tiết đối tác để thanh toán.
  /// Nếu đối tác đã bị xóa / không tìm thấy, vẫn hiển thị thông báo rõ ràng
  /// thay vì xóa bản ghi nợ khỏi màn hình.
  Future<void> _navigateToPartnerDetail(Map<String, dynamic> partner) async {
    final l10n = AppLocalizations.of(context)!;
    final partnerId = partner['partnerId'] ?? partner['id'];
    final partnerName = partner['name']?.toString() ?? '';
    final isMissing = partner['missingPartner'] == true;
    final source = partner['source'] ?? 'repairs';

    // Manual debts may not have a valid partnerId — try to find by name first
    if (partnerId == null || isMissing) {
      debugPrint(
        '⚠️ [DebtView] partner not found: id=$partnerId name="$partnerName" source=$source',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.partnerNotInSystem(partnerName)),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    try {
      // Lấy thông tin đối tác đầy đủ từ service
      RepairPartner? partnerObj = await _partnerService.getRepairPartnerById(
        partnerId,
      );

      // Fallback: search by name if ID lookup failed (e.g. after reinstall/re-sync)
      if (partnerObj == null && partnerName.isNotEmpty) {
        debugPrint(
          '⚠️ [DebtView] ID lookup failed for id=$partnerId, trying by name "$partnerName"',
        );
        final all = await _partnerService.getRepairPartners();
        final upper = partnerName.trim().toUpperCase();
        try {
          partnerObj = all.firstWhere(
            (p) => p.name.trim().toUpperCase() == upper,
          );
        } catch (_) {
          partnerObj = null;
        }
      }

      if (partnerObj != null && mounted) {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => RepairPartnerDetailView(partner: partnerObj!),
          ),
        );
        if (result == true) _refresh();
      } else if (mounted) {
        debugPrint(
          '⚠️ [DebtView] Partner not found after fallback: id=$partnerId name="$partnerName"',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.partnerDebtNotFound(partnerName)),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.debtGenericError(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _summaryHeader(String label, int amount, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(FinanceV2Theme.radiusControl),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: FinanceV2Theme.micro.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            MoneyUtils.formatCompactCurrency(amount),
            style: FinanceV2Theme.amountLg.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _debtCard(Map<String, dynamic> d, [int? index]) {
    final l10n = AppLocalizations.of(context)!;
    final int total = _toInt(d['totalAmount']);
    final int paid = _toInt(d['paidAmount']);
    final int remain = (total - paid).clamp(0, total);
    final createdAt = _toInt(d['createdAt']);
    final hasCreatedAt = createdAt > 0;
    final date = hasCreatedAt
        ? DateFormat(
            'dd/MM/yyyy',
          ).format(DateTime.fromMillisecondsSinceEpoch(createdAt))
        : '--/--/----';
    final time = hasCreatedAt
        ? DateFormat(
            'HH:mm',
          ).format(DateTime.fromMillisecondsSinceEpoch(createdAt))
        : '--:--';
    final personName = _debtPersonName(d);
    final phone = _debtPhone(d);
    final note = d['note']?.toString() ?? '';
    final debtType = d['type']?.toString() ?? 'CUSTOMER_OWES';

    // Determine colors based on debt type
    final isCustomerDebt =
        debtType == 'CUSTOMER_OWES' ||
        debtType == 'OWE' ||
        debtType == 'OTHER_CUSTOMER_OWES';
    final mainColor = isCustomerDebt ? Colors.red : Colors.blue;
    final borderColor = isCustomerDebt
        ? Colors.red.shade200
        : Colors.blue.shade200;

    // Calculate days since creation for urgency
    final daysSince = hasCreatedAt
        ? DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(createdAt))
              .inDays
        : 0;
    final isUrgent = daysSince > 30;
    final isVeryUrgent = daysSince > 60;
    final isAltRow = (index ?? 0).isEven;
    final hasMeaningfulNote =
        note.trim().isNotEmpty && note.trim().toLowerCase() != 'nợ';
    final zebraBg = isAltRow
        ? Color.alphaBlend(mainColor.withOpacity(0.03), Colors.white)
        : Colors.white;

    return Card(
      margin: const EdgeInsets.only(bottom: 3),
      color: zebraBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FinanceV2Theme.radiusControl),
        side: BorderSide(
          color: isVeryUrgent
              ? Colors.red.shade400
              : (isUrgent ? Colors.orange.shade300 : borderColor),
          width: isVeryUrgent ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showDebtHistory(d),
        borderRadius: BorderRadius.circular(FinanceV2Theme.radiusControl),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Type icon (đủ để phân biệt phải thu/phải trả — không cần
                  // thêm số thứ tự vì đang lọc theo tab, số 1,2,3.. không có
                  // ý nghĩa gì với người dùng)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: mainColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      isCustomerDebt
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      color: mainColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Name and phone
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          personName.toUpperCase(),
                          style: FinanceV2Theme.bodyMd.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (phone.isNotEmpty)
                          GestureDetector(
                            onTap: () =>
                                launchUrl(Uri(scheme: 'tel', path: phone)),
                            child: Text(
                              '📞 $phone',
                              style: FinanceV2Theme.micro.copyWith(
                                color: Colors.blue.shade600,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.blue.shade300,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Date and time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        date,
                        style: FinanceV2Theme.micro.copyWith(
                          fontWeight: FontWeight.w500,
                          color: FinanceV2Theme.subInk,
                        ),
                      ),
                      Text(
                        time,
                        style: FinanceV2Theme.caption.copyWith(
                          color: FinanceV2Theme.subInk,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Bỏ chip "Phải thu/Phải trả" ở đây vì đã lặp lại đúng thông
              // tin của icon mũi tên bên trên + đang lọc theo tab rồi — chỉ
              // còn hiện chip khi có điều thật sự cần báo (đã trả đủ/quá
              // hạn), tránh dòng trống vô nghĩa khi đơn bình thường.
              if (remain == 0 || isVeryUrgent || isUrgent) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (remain == 0)
                      _debtInfoChip(
                        l10n.paidFullLabel,
                        Colors.green.shade100,
                        Colors.green.shade700,
                      )
                    else if (isVeryUrgent)
                      _debtInfoChip(
                        l10n.overdueDaysLabel(daysSince),
                        Colors.red.shade100,
                        Colors.red.shade800,
                      )
                    else if (isUrgent)
                      _debtInfoChip(
                        l10n.daysLabel(daysSince),
                        Colors.orange.shade100,
                        Colors.orange.shade800,
                      ),
                  ],
                ),
              ],

              if (hasMeaningfulNote) ...[
                const SizedBox(height: 4),
                Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTextStyles.caption.fontSize,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],

              const Divider(height: 10),

              // Amount row
              Row(
                children: [
                  Expanded(
                    child: _amountPill(
                      label: l10n.totalDebtLabel,
                      amount: total,
                      valueColor: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _amountPill(
                      label: l10n.paidAmountLabel,
                      amount: paid,
                      valueColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _amountPill(
                      label: l10n.remainingDebtLabel,
                      amount: remain,
                      valueColor: Colors.white,
                      bgColor: mainColor,
                      labelColor: Colors.white70,
                    ),
                  ),
                ],
              ),

              // Action button
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showDebtHistory(d),
                    icon: const Icon(Icons.history, size: 14),
                    label: Text(
                      l10n.historyButton,
                      style: TextStyle(fontSize: AppTextStyles.body1.fontSize),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: () => _payDebt(d),
                    icon: Icon(
                      isCustomerDebt ? Icons.call_received : Icons.call_made,
                      size: 14,
                    ),
                    label: Text(
                      isCustomerDebt
                          ? l10n.collectDebtAction
                          : l10n.payDebtAction,
                      style: FinanceV2Theme.bodySm,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  Widget _debtInfoChip(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: FinanceV2Theme.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _amountPill({
    required String label,
    required int amount,
    required Color valueColor,
    Color? bgColor,
    Color? labelColor,
  }) {
    final chipBg = bgColor ?? Colors.grey.shade100;
    final chipLabelColor = labelColor ?? Colors.grey.shade600;
    final borderColor = bgColor == null
        ? Colors.grey.shade200
        : chipBg.withOpacity(0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: FinanceV2Theme.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: chipLabelColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            MoneyUtils.formatCompactCurrency(amount),
            style: FinanceV2Theme.amountMd.copyWith(color: valueColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Bảng chọn nhanh loại nợ cần tạo, theo chiều tiền của tab đang mở.
  void _showCreateDebtChooser({required bool isReceivable}) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // Đã tự vẽ PopupDragHandle() riêng — tắt drag handle mặc định của theme
      // (bottomSheetTheme.showDragHandle=true) để tránh 2 lớp handle chồng
      // nhau ăn mất không gian, đẩy nút Hủy/Xác nhận ra ngoài vùng hiển thị
      // trên máy có màn hình thấp (đã xác nhận qua test thực tế).
      showDragHandle: false,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: PopupTheme.bgDark,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(PopupTheme.radiusSheet),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        // 2 nút xếp ngang thay vì ListTile xếp dọc để tổng chiều cao sheet luôn
        // rất thấp, chắc chắn không bao giờ chạm ngưỡng bị che bởi vùng hệ
        // thống ở đáy màn hình (xem debt_payment_sheet.dart về cùng vấn đề).
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PopupDragHandle(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DebtChooserOption(
                    icon: isReceivable
                        ? Icons.person_outline
                        : Icons.local_shipping_outlined,
                    color: isReceivable ? Colors.redAccent : Colors.blueAccent,
                    label: isReceivable ? l10n.tabCustomer : l10n.tabSupplier,
                    onTap: () {
                      Navigator.pop(ctx);
                      isReceivable
                          ? _createCustomerDebt()
                          : _createSupplierDebt();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DebtChooserOption(
                    icon: Icons.more_horiz,
                    color: PopupTheme.blue,
                    label: l10n.tabOther,
                    onTap: () {
                      Navigator.pop(ctx);
                      _createOtherDebt(
                        initialType: isReceivable
                            ? 'CUSTOMER_OWES'
                            : 'SHOP_OWES',
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _createOtherDebt({String initialType = 'CUSTOMER_OWES'}) async {
    // Kiểm tra ngày hôm nay đã chốt quỹ chưa
    final l10n = AppLocalizations.of(context)!;
    final today = DateTime.now();
    final canEdit = await AdjustmentService.canEditDirectly(
      today.millisecondsSinceEpoch,
    );
    if (!canEdit && mounted) {
      NotificationService.showSnackBar(
        l10n.closedTodayCreateDebt,
        color: Colors.red,
      );
      return;
    }

    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String debtType = initialType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // Đã tự vẽ PopupDragHandle() riêng — tắt drag handle mặc định của theme
      // (bottomSheetTheme.showDragHandle=true) để tránh 2 lớp handle chồng
      // nhau ăn mất không gian, đẩy nút Hủy/Xác nhận ra ngoài vùng hiển thị
      // trên máy có màn hình thấp (đã xác nhận qua test thực tế).
      showDragHandle: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return KeyboardAwarePadding(
            child: Container(
              decoration: const BoxDecoration(
                color: PopupTheme.bgDark,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(PopupTheme.radiusSheet),
                ),
              ),
              child: Form(
                key: formKey,
                // Cuộn toàn bộ nội dung (kể cả hàng nút Hủy/Tạo) trong 1
                // SingleChildScrollView duy nhất — xem debt_payment_sheet.dart
                // để biết lý do (nút bị đẩy ra ngoài vùng hiển thị nếu chỉ cuộn
                // riêng phần giữa bằng Flexible).
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PopupDragHandle(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.add_circle_outline,
                              color: PopupTheme.blue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.createOtherDebtTitle,
                              style: const TextStyle(
                                color: PopupTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: nameC,
                                    style: const TextStyle(
                                      color: PopupTheme.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: l10n.debtorNameLabel,
                                      isDense: true,
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? l10n.pleaseEnterDebtorName
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: phoneC,
                                    style: const TextStyle(
                                      color: PopupTheme.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: l10n.phoneNumberLabel,
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.phone,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: CurrencyTextField(
                                    controller: amountC,
                                    label: l10n.debtAmountVnd,
                                    validator: (v) => MoneyUtils.validateAmount(
                                      v ?? '',
                                      min: 1,
                                      fieldName: l10n.debtAmountFieldName,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: noteC,
                                    style: const TextStyle(
                                      color: PopupTheme.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: l10n.note,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.debtFormTypeLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: PopupTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setS(() => debtType = "CUSTOMER_OWES"),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: debtType == "CUSTOMER_OWES"
                                            ? Colors.red.withValues(alpha: 0.15)
                                            : Colors.grey.withValues(
                                                alpha: 0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: debtType == "CUSTOMER_OWES"
                                              ? Colors.red
                                              : Colors.grey.shade300,
                                          width: debtType == "CUSTOMER_OWES"
                                              ? 2
                                              : 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.arrow_downward,
                                            color: debtType == "CUSTOMER_OWES"
                                                ? Colors.red
                                                : Colors.grey,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            l10n.receivableDebt,
                                            style: TextStyle(
                                              fontSize:
                                                  AppTextStyles.body1.fontSize,
                                              fontWeight: FontWeight.bold,
                                              color: debtType == "CUSTOMER_OWES"
                                                  ? Colors.red
                                                  : Colors.grey,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          Text(
                                            l10n.customerOwesShop,
                                            style: const TextStyle(
                                              fontSize:
                                                  AppTextStyles.overlineSize,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setS(() => debtType = "SHOP_OWES"),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: debtType == "SHOP_OWES"
                                            ? Colors.blue.withValues(
                                                alpha: 0.15,
                                              )
                                            : Colors.grey.withValues(
                                                alpha: 0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: debtType == "SHOP_OWES"
                                              ? Colors.blue
                                              : Colors.grey.shade300,
                                          width: debtType == "SHOP_OWES"
                                              ? 2
                                              : 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.arrow_upward,
                                            color: debtType == "SHOP_OWES"
                                                ? Colors.blue
                                                : Colors.grey,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            l10n.payableDebt,
                                            style: TextStyle(
                                              fontSize:
                                                  AppTextStyles.body1.fontSize,
                                              fontWeight: FontWeight.bold,
                                              color: debtType == "SHOP_OWES"
                                                  ? Colors.blue
                                                  : Colors.grey,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          Text(
                                            l10n.shopOwesOther,
                                            style: const TextStyle(
                                              fontSize:
                                                  AppTextStyles.overlineSize,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  await Future.delayed(Duration.zero);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                                child: Text(l10n.cancelButton),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: PopupTheme.blue,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  if (!(formKey.currentState?.validate() ??
                                      false))
                                    return;

                                  final debtAmount = MoneyUtils.parseCurrency(
                                    amountC.text,
                                  );
                                  if (debtAmount <= 0) return;

                                  final user =
                                      FirebaseAuth.instance.currentUser;
                                  final userName =
                                      user?.email
                                          ?.split('@')
                                          .first
                                          .toUpperCase() ??
                                      "NV";
                                  final now =
                                      DateTime.now().millisecondsSinceEpoch;
                                  final shopId =
                                      await UserService.getCurrentShopId() ??
                                      '';

                                  final newDebtData = {
                                    'firestoreId': "debt_other_$now",
                                    'personName': nameC.text.trim(),
                                    'phone': phoneC.text.trim(),
                                    'totalAmount': debtAmount,
                                    'paidAmount': 0,
                                    'type': 'OTHER_$debtType',
                                    'status': 'ACTIVE',
                                    'createdAt': now,
                                    'note': noteC.text.trim().isEmpty
                                        ? null
                                        : noteC.text.trim(),
                                    'createdBy': userName,
                                    'shopId': shopId,
                                    'deleted': 0,
                                    'isSynced': 0,
                                  };

                                  final debtId = await db.insertDebt(
                                    newDebtData,
                                  );
                                  await SyncOrchestrator().enqueue(
                                    entityType: SyncEntityType.debt,
                                    entityId: debtId,
                                    firestoreId:
                                        newDebtData['firestoreId'] as String,
                                    operation: SyncOperation.create,
                                    data: newDebtData,
                                  );

                                  EventBus().emit('debts_changed');
                                  if (!mounted) return;
                                  if (ctx.mounted) {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    Navigator.pop(ctx);
                                  }
                                  NotificationService.showSnackBar(
                                    l10n.debtCreated,
                                    color: Colors.green,
                                  );
                                  await _refresh();
                                },
                                child: Text(l10n.createButton),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _createCustomerDebt() async {
    final l10n = AppLocalizations.of(context)!;
    // Kiểm tra ngày hôm nay đã chốt quỹ chưa
    final today = DateTime.now();
    final canEdit = await AdjustmentService.canEditDirectly(
      today.millisecondsSinceEpoch,
    );
    if (!canEdit && mounted) {
      NotificationService.showSnackBar(
        l10n.closedTodayCreateDebt,
        color: Colors.red,
      );
      return;
    }

    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // Đã tự vẽ PopupDragHandle() riêng — tắt drag handle mặc định của theme
      // (bottomSheetTheme.showDragHandle=true) để tránh 2 lớp handle chồng
      // nhau ăn mất không gian, đẩy nút Hủy/Xác nhận ra ngoài vùng hiển thị
      // trên máy có màn hình thấp (đã xác nhận qua test thực tế).
      showDragHandle: false,
      builder: (ctx) => KeyboardAwarePadding(
        child: Container(
          decoration: const BoxDecoration(
            color: PopupTheme.bgDark,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(PopupTheme.radiusSheet),
            ),
          ),
          child: Form(
            key: formKey,
            // Cuộn toàn bộ nội dung (kể cả hàng nút Hủy/Tạo) trong 1
            // SingleChildScrollView duy nhất — xem debt_payment_sheet.dart
            // để biết lý do (nút bị đẩy ra ngoài vùng hiển thị nếu chỉ cuộn
            // riêng phần giữa bằng Flexible).
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PopupDragHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_downward, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          l10n.createReceivableDebtTitle,
                          style: const TextStyle(
                            color: PopupTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: nameC,
                                style: const TextStyle(
                                  color: PopupTheme.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  labelText: l10n.customerNameLabel,
                                  isDense: true,
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? l10n.pleaseEnterCustomerNameDebt
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: phoneC,
                                style: const TextStyle(
                                  color: PopupTheme.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  labelText: l10n.phoneNumberLabel,
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: CurrencyTextField(
                                controller: amountC,
                                label: l10n.debtAmountVnd,
                                validator: (v) => MoneyUtils.validateAmount(
                                  v ?? '',
                                  min: 1,
                                  fieldName: l10n.debtAmountFieldName,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: noteC,
                                style: const TextStyle(
                                  color: PopupTheme.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  labelText: l10n.note,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              FocusManager.instance.primaryFocus?.unfocus();
                              await Future.delayed(Duration.zero);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: Text(l10n.cancelButton),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              if (!(formKey.currentState?.validate() ?? false))
                                return;

                              try {
                                final debtAmount = MoneyUtils.parseCurrency(
                                  amountC.text,
                                );
                                if (debtAmount <= 0) return;

                                final user = FirebaseAuth.instance.currentUser;
                                final userName =
                                    user?.email
                                        ?.split('@')
                                        .first
                                        .toUpperCase() ??
                                    "NV";
                                final now =
                                    DateTime.now().millisecondsSinceEpoch;
                                final shopId =
                                    await UserService.getCurrentShopId() ?? '';

                                final newDebtData = {
                                  'firestoreId': "debt_customer_$now",
                                  'personName': nameC.text.trim(),
                                  'phone': phoneC.text.trim(),
                                  'totalAmount': debtAmount,
                                  'paidAmount': 0,
                                  'type': 'CUSTOMER_OWES',
                                  'status': 'ACTIVE',
                                  'createdAt': now,
                                  'note': noteC.text.trim(),
                                  'createdBy': userName,
                                  'shopId': shopId,
                                  'deleted': 0,
                                  'isSynced': 0,
                                };

                                final debtId = await db.insertDebt(newDebtData);
                                await SyncOrchestrator().enqueue(
                                  entityType: SyncEntityType.debt,
                                  entityId: debtId,
                                  firestoreId:
                                      newDebtData['firestoreId'] as String,
                                  operation: SyncOperation.create,
                                  data: newDebtData,
                                );

                                await db.logAction(
                                  userId: user?.uid ?? "0",
                                  userName: userName,
                                  action: "TẠO NỢ",
                                  type: "DEBT",
                                  targetId:
                                      newDebtData['firestoreId'] as String,
                                  desc:
                                      "Tạo nợ khách hàng: ${nameC.text} - ${MoneyUtils.formatCurrency(debtAmount)}.",
                                );

                                EventBus().emit('debts_changed');
                                if (!mounted) return;
                                FocusManager.instance.primaryFocus?.unfocus();
                                if (ctx.mounted) Navigator.pop(ctx);
                                NotificationService.showSnackBar(
                                  l10n.customerDebtCreated,
                                  color: Colors.green,
                                );
                                await _refresh();
                              } catch (e) {
                                if (!mounted) return;
                                NotificationService.showSnackBar(
                                  l10n.createDebtError(e.toString()),
                                  color: Colors.red,
                                );
                              }
                            },
                            child: Text(l10n.createButton),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _createSupplierDebt() async {
    final l10n = AppLocalizations.of(context)!;
    final today = DateTime.now();
    final canEdit = await AdjustmentService.canEditDirectly(
      today.millisecondsSinceEpoch,
    );
    if (!canEdit && mounted) {
      NotificationService.showSnackBar(
        l10n.closedTodayCreateDebt,
        color: Colors.red,
      );
      return;
    }

    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // Đã tự vẽ PopupDragHandle() riêng — tắt drag handle mặc định của theme
      // (bottomSheetTheme.showDragHandle=true) để tránh 2 lớp handle chồng
      // nhau ăn mất không gian, đẩy nút Hủy/Xác nhận ra ngoài vùng hiển thị
      // trên máy có màn hình thấp (đã xác nhận qua test thực tế).
      showDragHandle: false,
      builder: (ctx) => KeyboardAwarePadding(
        child: Container(
          decoration: const BoxDecoration(
            color: PopupTheme.bgDark,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(PopupTheme.radiusSheet),
            ),
          ),
          child: Form(
            key: formKey,
            // Cuộn toàn bộ nội dung (kể cả hàng nút Hủy/Tạo) trong 1
            // SingleChildScrollView duy nhất — xem debt_payment_sheet.dart
            // để biết lý do (nút bị đẩy ra ngoài vùng hiển thị nếu chỉ cuộn
            // riêng phần giữa bằng Flexible).
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PopupDragHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_upward, color: PopupTheme.blue),
                        const SizedBox(width: 8),
                        Text(
                          l10n.createPayableDebtTitle,
                          style: const TextStyle(
                            color: PopupTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: nameC,
                                style: const TextStyle(
                                  color: PopupTheme.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  labelText: l10n.supplierNameLabel,
                                  isDense: true,
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? l10n.pleaseEnterSupplierNameDebt
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: phoneC,
                                style: const TextStyle(
                                  color: PopupTheme.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  labelText: l10n.phoneNumberLabel,
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: CurrencyTextField(
                                controller: amountC,
                                label: l10n.debtAmountVnd,
                                validator: (v) => MoneyUtils.validateAmount(
                                  v ?? '',
                                  min: 1,
                                  fieldName: l10n.debtAmountFieldName,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: noteC,
                                style: const TextStyle(
                                  color: PopupTheme.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  labelText: l10n.note,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              FocusManager.instance.primaryFocus?.unfocus();
                              await Future.delayed(Duration.zero);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: Text(l10n.cancelButton),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PopupTheme.blue,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              if (!(formKey.currentState?.validate() ?? false))
                                return;

                              try {
                                final debtAmount = MoneyUtils.parseCurrency(
                                  amountC.text,
                                );
                                if (debtAmount <= 0) return;

                                final user = FirebaseAuth.instance.currentUser;
                                final userName =
                                    user?.email
                                        ?.split('@')
                                        .first
                                        .toUpperCase() ??
                                    "NV";
                                final now =
                                    DateTime.now().millisecondsSinceEpoch;
                                final shopId =
                                    await UserService.getCurrentShopId() ?? '';

                                final newDebtData = {
                                  'firestoreId': "debt_supplier_$now",
                                  'personName': nameC.text.trim(),
                                  'phone': phoneC.text.trim(),
                                  'totalAmount': debtAmount,
                                  'paidAmount': 0,
                                  'type': 'SHOP_OWES',
                                  'status': 'ACTIVE',
                                  'createdAt': now,
                                  'note': noteC.text.trim(),
                                  'createdBy': userName,
                                  'shopId': shopId,
                                  'deleted': 0,
                                  'isSynced': 0,
                                };

                                final debtId = await db.insertDebt(newDebtData);
                                await SyncOrchestrator().enqueue(
                                  entityType: SyncEntityType.debt,
                                  entityId: debtId,
                                  firestoreId:
                                      newDebtData['firestoreId'] as String,
                                  operation: SyncOperation.create,
                                  data: newDebtData,
                                );

                                await db.logAction(
                                  userId: user?.uid ?? "0",
                                  userName: userName,
                                  action: "TẠO NỢ",
                                  type: "DEBT",
                                  targetId:
                                      newDebtData['firestoreId'] as String,
                                  desc:
                                      "Tạo nợ nhà cung cấp: ${nameC.text} - ${MoneyUtils.formatCurrency(debtAmount)}.",
                                );

                                EventBus().emit('debts_changed');
                                if (!mounted) return;
                                FocusManager.instance.primaryFocus?.unfocus();
                                if (ctx.mounted) Navigator.pop(ctx);
                                NotificationService.showSnackBar(
                                  l10n.supplierDebtCreated,
                                  color: Colors.green,
                                );
                                await _refresh();
                              } catch (e) {
                                if (!mounted) return;
                                NotificationService.showSnackBar(
                                  l10n.createDebtError(e.toString()),
                                  color: Colors.red,
                                );
                              }
                            },
                            child: Text(l10n.createButton),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô lựa chọn trong bảng chọn nhanh loại nợ (_showCreateDebtChooser) — layout
/// ngang, gọn, để bảng chọn luôn thấp và không phụ thuộc vào việc cuộn.
class _DebtChooserOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _DebtChooserOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
