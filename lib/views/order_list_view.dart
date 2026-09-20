import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/cloud_write_policy.dart';
import '../data/db_helper.dart';
import '../services/first_time_guide_service.dart';
import '../services/app_session.dart';
import '../services/owner_reauth_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/skeleton_list.dart';
import '../models/repair_model.dart';
import '../models/part_used_detail_model.dart';
import '../services/event_bus.dart';
import '../services/user_service.dart';
import '../services/encryption_service.dart';
import '../services/sync_service.dart';
import '../services/sync_orchestrator.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_cached_image.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/empty_state_widget.dart';
import '../utils/vietnamese_utils.dart';
import '../utils/money_utils.dart';
import '../widgets/gradient_fab.dart';
import '../services/notification_service.dart';
import '../services/firestore_write_helper.dart';
import 'repair_detail_view.dart';
import 'create_repair_order_view.dart';
import 'global_search_view.dart';
import '../theme/app_colors.dart';
import '../widgets/responsive_wrapper.dart';
import '../widgets/sync_status_bar.dart';
import '../services/connectivity_service.dart';
import '../services/customer_service.dart';
import '../models/customer_model.dart';

class OrderListView extends StatefulWidget {
  final int? initialStatus;
  final bool todayOnly;
  final List<int>? statusFilter;
  final String role;

  /// Chỉ hiện đơn đã giao (status 4) nhưng chưa ghi nhận giá vốn (cost = 0).
  final bool filterMissingCost;
  const OrderListView({
    super.key,
    this.initialStatus,
    this.todayOnly = false,
    this.statusFilter,
    this.role = 'user',
    this.filterMissingCost = false,
  });

  @override
  State<OrderListView> createState() => OrderListViewState();
}

class OrderListViewState extends State<OrderListView> {
  final db = DBHelper();
  final ScrollController _listScrollController = ScrollController();
  // Second list controller used by the 2-column grid layout (right column).
  final ScrollController _listScrollControllerGridB = ScrollController();
  StreamSubscription<String>? _eventSubscription;
  // SQLite-first pagination. Nguồn dữ liệu DUY NHẤT cho list: toàn bộ thay
  // đổi cloud do SyncService đổ về SQLite rồi bắn EventBus.repairsChanged.
  List<Repair> _sqliteRepairs = [];
  int _sqliteLoadedCount = 0;
  bool _hasMoreData = false;
  bool _isLoadingMore = false;
  static const int _kPageSize = 50;
  static const int _kMaxSearchResults = 5000;
  Timer? _searchDebounce;
  bool _isSearchingLocal = false;
  final TextEditingController _searchController = TextEditingController();

  // Sort mode: 'priority' (business priority), 'newest', 'oldest'
  String _sortMode = 'priority';
  bool _isManualSyncing = false;

  AppLocalizations get loc => AppLocalizations.of(context)!;

  List<Repair> _displayedRepairs = [];
  bool _isLoading = true;
  String _currentSearch = "";

  // Date filter
  String _timeFilter = 'all'; // all, today, week, month, custom
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Status filter - Set để cho phép chọn nhiều trạng thái
  Set<int> _statusFilters = {}; // Empty = all, {1,2} = tiếp nhận + đang sửa
  bool _filterPendingApproval = false; // Lọc đơn chờ duyệt giao
  // UI-only filter theo cờ "Quá hạn" (computed _isOverdue) — KHÔNG tạo status mới.
  bool _filterOverdue = false;
  bool _canDelete = false;
  bool _canViewCostPrice = false;
  bool _canViewRevenue = false;

  /// Đếm theo trạng thái bằng SQL trên TOÀN BỘ đơn của shop (không phải cửa
  /// sổ 50 đơn đã nạp) — nạp lại cùng lúc với danh sách.
  Map<String, int> _counts = const {};

  /// Sau khi mở app, SyncService cần vài giây mới lập xong listener — trong
  /// lúc đó `isRealTimeSyncActive` = false. Không hiện banner "Không thể
  /// đồng bộ" trong khoảng này (trước đây cứ mở list ngay sau khi mở app là
  /// thấy banner cam dù mạng bình thường).
  final DateTime _syncBannerGraceUntil =
      DateTime.now().add(const Duration(seconds: 20));

  bool get canDelete => _canDelete;

  // Sort mặc định "Ưu tiên" (business priority) theo đặc tả CHỦ SHOP duyệt
  // 2026-09-17: 1. Tiếp nhận (gộp luôn Đang sửa) → 2. Sửa xong → 3. Y/c duyệt
  // giao → 4. Quá hạn (UI computed _isOverdue, không đổi status) → 5. Đã giao.
  // Trong cùng state: đơn mới hơn trước. Các mode khác chỉ sắp theo createdAt.
  int _compareRepairs(Repair a, Repair b) {
    switch (_sortMode) {
      case 'newest':
        return b.createdAt.compareTo(a.createdAt);
      case 'oldest':
        return a.createdAt.compareTo(b.createdAt);
    }
    int priority(Repair r) {
      if (r.status >= 4) return 5; // Đã giao
      if (_isOverdue(r)) return 4; // Quá hạn — bất kỳ đơn chưa giao treo > 7 ngày
      if (r.status == 3 && r.pendingDeliveryApproval) return 3; // Y/c duyệt
      if (r.status == 3) return 2; // Sửa xong
      return 1; // Tiếp nhận + Đang sửa (không tách riêng theo đặc tả)
    }

    final pa = priority(a);
    final pb = priority(b);
    if (pa != pb) return pa.compareTo(pb);
    return b.createdAt.compareTo(a.createdAt); // Mới nhất trước
  }

  int _displayedChargePrice(Repair repair) {
    final requested = repair.requestedDeliveryPrice;
    if (repair.pendingDeliveryApproval && requested != null) {
      return requested;
    }
    return repair.price;
  }

  static const int _overdueThresholdDays = 7;

  /// Số ngày đơn đã treo ở trạng thái hiện tại (chưa giao) — null nếu không
  /// thuộc các trạng thái tính quá hạn hoặc thiếu mốc thời gian.
  int? _daysStuck(Repair repair) {
    if (repair.status == 4) return null;
    if (repair.status == 3 && repair.pendingDeliveryApproval) return null;
    if (repair.status != 1 && repair.status != 2 && repair.status != 3) {
      return null;
    }

    final referenceMs = repair.status == 1
        ? repair.createdAt
        : (repair.startedAt ?? repair.lastCaredAt ?? repair.createdAt);
    if (referenceMs <= 0) return null;

    return DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(referenceMs))
        .inDays;
  }

  /// Đơn chưa giao (Tiếp nhận / Đang sửa / Sửa xong) bị treo quá
  /// [_overdueThresholdDays] ngày mà chưa xử lý tiếp.
  bool _isOverdue(Repair repair) {
    final days = _daysStuck(repair);
    return days != null && days > _overdueThresholdDays;
  }

  @override
  void initState() {
    super.initState();
    _listScrollController.addListener(_onListScroll);
    _listScrollControllerGridB.addListener(_onListScrollGridB);
    _loadDeletePermission();
    unawaited(_initFromSQLite());
    WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstTimeGuide());

    // Nguồn dữ liệu duy nhất là SQLite: SyncService đổ cloud về rồi bắn
    // repairsChanged; list chỉ đọc lại SQLite, KHÔNG mở listener Firestore.
    _eventSubscription = EventBus().stream.listen((event) {
      if (!mounted) return;

      if (event == EventBus.shopChanged) {
        unawaited(_onShopChanged());
        return;
      }

      if (event == EventBus.repairsChanged) {
        unawaited(_refreshFromSQLite());
      }
    });
  }

  /// Chuyển shop (super admin hoặc đổi quyền): reset phân trang rồi nạp lại
  /// trang đầu từ SQLite cho shop mới.
  Future<void> _onShopChanged() async {
    setState(() {
      _sqliteRepairs = [];
      _sqliteLoadedCount = 0;
      _hasMoreData = false;
      _isLoadingMore = false;
      _isLoading = true;
    });
    await _initFromSQLite();
  }

  Future<void> _loadDeletePermission() async {
    try {
final results = await Future.wait([
      UserService.isCurrentUserAdmin(),
      UserService.getCurrentUserPermissions(),
    ]);
      if (!mounted) return;
      setState(() {
        _canDelete = results[0] as bool;
        final perms = results[1] as Map<String, dynamic>;
        _canViewCostPrice = perms['allowViewCostPrice'] == true;
        _canViewRevenue = perms['allowViewRevenue'] == true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _canDelete = widget.role == 'admin' || widget.role == 'owner';
        _canViewCostPrice = false;
        _canViewRevenue = false;
      });
    }
  }

  Future<void> _showFirstTimeGuide() async {
    await FirstTimeGuideService.showGuideIfNeeded(
      context: context,
      screenKey: FirstTimeGuideService.keyOrderList,
      title: 'Danh Sách Đơn Sửa',
      icon: Icons.build_rounded,
      color: Colors.deepOrange,
      steps: [
        const GuideStep(
          title: '📋 Tất cả đơn sửa chữa',
          description:
              'Xem toàn bộ đơn sửa theo thời gian thực. Danh sách tự động cập nhật khi có đơn mới.',
          icon: Icons.list_alt_rounded,
          iconColor: Colors.deepOrange,
        ),
        const GuideStep(
          title: '🔍 Tìm kiếm nhanh',
          description:
              'Tìm đơn theo tên khách hàng, số điện thoại hoặc mã đơn sửa.',
          icon: Icons.search_rounded,
          iconColor: Colors.blue,
        ),
        const GuideStep(
          title: '🔄 Lọc theo trạng thái',
          description:
              'Lọc đơn theo Chờ sửa → Đang sửa → Hoàn thành → Đã giao để quản lý từng bước.',
          icon: Icons.filter_list_rounded,
          iconColor: Colors.green,
        ),
        const GuideStep(
          title: '📱 Cập nhật tiến độ',
          description:
              'Nhấn vào bất kỳ đơn nào để xem chi tiết, cập nhật trạng thái hoặc in phiếu.',
          icon: Icons.touch_app_rounded,
          iconColor: Colors.purple,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _listScrollController.removeListener(_onListScroll);
    _listScrollController.dispose();
    _listScrollControllerGridB.removeListener(_onListScrollGridB);
    _listScrollControllerGridB.dispose();
    _eventSubscription?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onListScroll() {
    if (!_listScrollController.hasClients || _isLoadingMore) {
      return;
    }

    final pos = _listScrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 220) return;

    // SQLite pagination: tải thêm lịch sử cũ hơn (ĐÃ GIAO, đơn cũ) khi cuộn.
    if (_hasMoreData) {
      unawaited(_loadMoreFromSQLite());
    }
  }

  void _onListScrollGridB() {
    if (!_listScrollControllerGridB.hasClients || _isLoadingMore) {
      return;
    }

    final pos = _listScrollControllerGridB.position;
    if (pos.pixels < pos.maxScrollExtent - 220) return;

    if (_hasMoreData) {
      unawaited(_loadMoreFromSQLite());
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // Nguồn DỮ LIỆU DUY NHẤT: SQLite.
  // Mọi thay đổi cloud do SyncService đồng bộ xuống SQLite rồi bắn
  // EventBus.repairsChanged → list chỉ việc đọc lại SQLite. Không mở thêm
  // listener/watch Firestore nào phía list (giảm Firestore reads, tránh hai
  // nguồn sự thật, hết lỗi lệch trạng thái giữa cache realtime vs sqliteExtra).
  // Backfill lịch sử (đơn cũ thiếu updatedAt) do SyncService lo khi khởi động.
  // ══════════════════════════════════════════════════════════════════════

  /// Load first page from SQLite — called on init or shop change.
  /// "52 điện thoại · 2 đang xử lý · ⚠ 3 quá hạn" — từ SQL COUNT.
  String _headerSubtitle(int total) {
    final processing = (_counts['received'] ?? 0) + (_counts['repairing'] ?? 0);
    final overdue = _counts['overdue'] ?? 0;
    final parts = <String>['$total điện thoại'];
    if (processing > 0) parts.add('$processing đang xử lý');
    if (overdue > 0) parts.add('⚠ $overdue quá hạn');
    return parts.join(' · ');
  }

  Future<void> _reloadCounts() async {
    try {
      final c = await db.getRepairStatusCounts(
        overdueDays: _overdueThresholdDays,
      );
      if (mounted) setState(() => _counts = c);
    } catch (e) {
      debugPrint('⚠️ [OrderListView] _reloadCounts lỗi: $e');
    }
  }

  Future<void> _initFromSQLite() async {
    unawaited(_reloadCounts());
    try {
      final repairs = await db.getRepairsPaged(_kPageSize, 0);
      if (!mounted) return;
      setState(() {
        _sqliteRepairs = repairs;
        _sqliteLoadedCount = repairs.length;
        _hasMoreData = repairs.length == _kPageSize;
      });
      _rebuildDisplayedRepairs(markLoaded: true);
    } catch (e) {
      debugPrint('⚠️ [OrderListView] _initFromSQLite lỗi: $e');
      if (mounted) _rebuildDisplayedRepairs(markLoaded: true);
    }
  }

  /// Reload the already-loaded window from SQLite (called after Firestore upserts
  /// and after historical backfill completes).
  Future<void> _refreshFromSQLite() async {
    // Capture window size before the DB await — load-more may change
    // _sqliteLoadedCount while we are suspended.
    final windowSize = _sqliteLoadedCount.clamp(_kPageSize, 9999);
    unawaited(_reloadCounts());
    try {
      final repairs = await db.getRepairsPaged(windowSize, 0);
      if (!mounted) return;

      if (_isLoadingMore) {
        // Load-more is mid-flight: don't touch pagination state, just
        // trigger a display rebuild so new Firestore items appear.
        _rebuildDisplayedRepairs(markLoaded: true);
        return;
      }

      setState(() {
        // If load-more COMPLETED while we were awaiting, _sqliteLoadedCount
        // is now larger than windowSize and _sqliteRepairs already has page 1+
        // data.  In that case keep the richer state; only update when our
        // query covers everything that is currently tracked.
        if (repairs.length >= _sqliteLoadedCount) {
          _sqliteRepairs = repairs;
          _sqliteLoadedCount = repairs.length;
          _hasMoreData = repairs.length == windowSize;
        }
        // else: load-more data is more complete — only rebuild display below
      });
      _rebuildDisplayedRepairs(markLoaded: true);
    } catch (e) {
      debugPrint('⚠️ [OrderListView] _refreshFromSQLite lỗi: $e');
      if (mounted) _rebuildDisplayedRepairs(markLoaded: true);
    }
  }

  /// Load the next page from SQLite (scroll pagination).
  Future<void> _loadMoreFromSQLite() async {
    if (_isLoadingMore || !_hasMoreData) return;
    debugPrint('[OrderListView] LOAD MORE TRIGGERED');
    debugPrint(
      '[OrderListView] Before load: ${_displayedRepairs.length} displayed, sqliteLoadedCount=$_sqliteLoadedCount',
    );
    setState(() => _isLoadingMore = true);
    try {
      final repairs = await db.getRepairsPaged(_kPageSize, _sqliteLoadedCount);
      debugPrint(
        '[OrderListView] SQLite page returned ${repairs.length} repairs at offset $_sqliteLoadedCount',
      );
      if (!mounted) return;
      setState(() {
        _sqliteRepairs.addAll(repairs);
        _sqliteLoadedCount += repairs.length;
        _hasMoreData = repairs.length == _kPageSize;
        _isLoadingMore = false;
      });
      _rebuildDisplayedRepairs();
      debugPrint(
        '[OrderListView] After load: ${_displayedRepairs.length} displayed',
      );
    } catch (e) {
      debugPrint('⚠️ [OrderListView] _loadMoreFromSQLite lỗi: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// Pool hiển thị — chính là cửa sổ SQLite (nguồn dữ liệu duy nhất, đã được
  /// SyncService đồng bộ realtime từ cloud). KHÔNG merge thêm cache Firestore
  /// nào → không còn hai nguồn sự thật, không lệch trạng thái.
  List<Repair> get _allRepairs => _sqliteRepairs;

  void _rebuildDisplayedRepairs({bool markLoaded = false}) {
    final all = _allRepairs..sort(_compareRepairs);
    debugPrint(
      '[OrderListView] SQLite count: ${_sqliteRepairs.length} (window $_sqliteLoadedCount) | HasMore: $_hasMoreData',
    );
    final filtered = _applyFilters(all);
    final keyword = _currentSearch.trim();

    final searched = keyword.isEmpty
        ? filtered
        : filtered
              .where(
                (r) =>
                    VietnameseUtils.containsVietnamese(
                      r.customerName,
                      keyword,
                    ) ||
                    r.phone.contains(keyword) ||
                    VietnameseUtils.containsVietnamese(r.model, keyword) ||
                    VietnameseUtils.containsVietnamese(r.issue, keyword) ||
                    (r.notes != null &&
                        VietnameseUtils.containsVietnamese(r.notes!, keyword)),
              )
              .toList();

    if (!mounted) return;

    debugPrint('[OrderListView] Displayed count: ${searched.length}');
    setState(() {
      _displayedRepairs = searched;
      if (markLoaded || _isLoading) _isLoading = false;
    });
  }

  /// Xoá đơn khỏi danh sách local sau khi xoá trên Firestore (soft delete/skip).
  void _removeRepairFromLocalCache(String? firestoreId) {
    final id = (firestoreId ?? '').trim();
    if (id.isEmpty) return;
    setState(() {
      _sqliteRepairs.removeWhere((r) => (r.firestoreId ?? '').trim() == id);
      _sqliteLoadedCount = _sqliteRepairs.length;
    });
    _rebuildDisplayedRepairs();
  }

  void _onSearch(String val) {
    _currentSearch = val;
    _searchDebounce?.cancel();
    if (val.trim().isEmpty) {
      _rebuildDisplayedRepairs();
      return;
    }
    // Debounce 300ms rồi tìm trong toàn bộ SQLite (không còn giới hạn 200 —
    // giới hạn cũ bỏ sót đơn cũ khi filter theo status). Kết quả vẫn qua
    // cùng pipeline sort + lọc để nhất quán với chế độ duyệt thường.
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final keyword = val.trim();
      if (keyword.isEmpty || !mounted) return;
      final normalized = VietnameseUtils.normalize(keyword);
      if (mounted) setState(() => _isSearchingLocal = true);
      try {
        final results = await db.searchRepairs(
          keyword,
          normalized,
          limit: _kMaxSearchResults,
        );
        if (!mounted || _currentSearch != val) return;
        results.sort(_compareRepairs);
        final filtered = _applyFilters(results);
        setState(() {
          _displayedRepairs = filtered;
          _isSearchingLocal = false;
        });
      } catch (_) {
        if (mounted) setState(() => _isSearchingLocal = false);
      }
    });
  }

  List<Repair> _applyFilters(List<Repair> list) {
    return list.where((r) {
      // Widget-level status filter (from constructor)
      if (widget.statusFilter != null &&
          !widget.statusFilter!.contains(r.status)) {
        return false;
      }
      if (widget.filterMissingCost && (r.status != 4 || r.totalCost > 0)) {
        return false;
      }
      // Lọc đơn quá hạn (UI-only, computed từ _isOverdue — không đổi status)
      if (_filterOverdue) {
        if (!_isOverdue(r)) return false;
      } else if (_filterPendingApproval) {
        // Lọc đơn chờ duyệt giao
        if (!r.pendingDeliveryApproval) return false;
      } else {
        // User-selected status filter - cho phép chọn nhiều trạng thái
        if (_statusFilters.isNotEmpty && !_statusFilters.contains(r.status)) {
          return false;
        }
      }
      if (widget.todayOnly) {
        final d = DateTime.fromMillisecondsSinceEpoch(r.createdAt);
        final now = DateTime.now();
        if (!(d.year == now.year && d.month == now.month && d.day == now.day)) {
          return false;
        }
      }
      // Time filter
      if (_timeFilter != 'all' && !widget.todayOnly) {
        final d = DateTime.fromMillisecondsSinceEpoch(r.createdAt);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        switch (_timeFilter) {
          case 'today':
            final itemDay = DateTime(d.year, d.month, d.day);
            if (itemDay != today) return false;
            break;
          case 'week':
            final weekAgo = today.subtract(const Duration(days: 7));
            if (d.isBefore(weekAgo)) return false;
            break;
          case 'month':
            final monthStart = DateTime(now.year, now.month, 1);
            if (d.isBefore(monthStart)) return false;
            break;
          case 'custom':
            if (_customStartDate != null && d.isBefore(_customStartDate!)) {
              return false;
            }
            if (_customEndDate != null &&
                d.isAfter(_customEndDate!.add(const Duration(days: 1)))) {
              return false;
            }
            break;
        }
      }
      return true;
    }).toList();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_timeFilter != 'all' && !widget.todayOnly) count++;
    if (_statusFilters.isNotEmpty) count++;
    if (_filterPendingApproval) count++;
    if (_filterOverdue) count++;
    return count;
  }

  String _getTimeFilterLabel() {
    switch (_timeFilter) {
      case 'today':
        return 'Hôm nay';
      case 'week':
        return '7 ngày';
      case 'month':
        return 'Tháng này';
      case 'custom':
        return 'Tùy chọn';
      default:
        return 'Tất cả';
    }
  }

  void _showFilterSheet() {
    showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          // Đọc từ `context` ngoài (không phải `ctx`) để tránh crash
          // _dependents.isEmpty khi pop — xem repair_detail_view.dart.
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.viewInsetsOf(context).bottom +
                MediaQuery.paddingOf(context).bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BỘ LỌC',
                      style: AppTextStyles.headline3.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          _timeFilter = 'all';
                          _customStartDate = null;
                          _customEndDate = null;
                          _statusFilters = {};
                          _filterPendingApproval = false;
                          _filterOverdue = false;
                        });
                      },
                      child: Text(loc.resetAll),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // STATUS FILTER - CHO PHÉP CHỌN NHIỀU
                Text(
                  loc.statusSelectMultiple,
                  style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusChipMulti(loc.all, null, setSheetState),
                    _statusChipMulti(
                      loc.received,
                      1,
                      setSheetState,
                      AppColors.repairReceived,
                    ),
                    _statusChipMulti(
                      loc.repairing,
                      2,
                      setSheetState,
                      AppColors.repairRepairing,
                    ),
                    _statusChipMulti(
                      loc.repairDone,
                      3,
                      setSheetState,
                      AppColors.repairDone,
                    ),
                    _pendingApprovalChip(setSheetState),
                    _statusChipMulti(
                      loc.delivered,
                      4,
                      setSheetState,
                      AppColors.repairDelivered,
                    ),
                  ],
                ),
                if (_statusFilters.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      loc.selectedStatuses(_statusFilters.length),
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),

                // TIME FILTER
                Text(
                  loc.timeFilter,
                  style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip('Tất cả', 'all', setSheetState),
                    _filterChip('Hôm nay', 'today', setSheetState),
                    _filterChip('7 ngày', 'week', setSheetState),
                    _filterChip('Tháng này', 'month', setSheetState),
                    GestureDetector(
                      onTap: () async {
                        final range = await showDateRangePicker(
                          context: ctx,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDateRange:
                              _customStartDate != null && _customEndDate != null
                              ? DateTimeRange(
                                  start: _customStartDate!,
                                  end: _customEndDate!,
                                )
                              : null,
                          locale: const Locale('vi', 'VN'),
                        );
                        if (range != null) {
                          setSheetState(() {
                            _timeFilter = 'custom';
                            _customStartDate = range.start;
                            _customEndDate = range.end;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _timeFilter == 'custom'
                              ? const Color(0xFF2962FF)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _timeFilter == 'custom'
                                ? const Color(0xFF2962FF)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_month,
                              size: 16,
                              color: _timeFilter == 'custom'
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tùy chọn',
                              style: TextStyle(
                                color: _timeFilter == 'custom'
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: _timeFilter == 'custom'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_timeFilter == 'custom' &&
                    _customStartDate != null &&
                    _customEndDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '${DateFormat('dd/MM/yyyy').format(_customStartDate!)} - ${DateFormat('dd/MM/yyyy').format(_customEndDate!)}',
                      style: const TextStyle(
                        color: Color(0xFF2962FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _onSearch(_currentSearch);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2962FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      loc.apply,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChipMulti(
    String label,
    int? value,
    StateSetter setSheetState, [
    Color? activeColor,
  ]) {
    // null = "Tất cả" - khi bấm sẽ clear hết selection
    final isSelected = value == null
        ? _statusFilters.isEmpty &&
              !_filterPendingApproval &&
              !_filterOverdue
        : _statusFilters.contains(value);
    final color = activeColor ?? const Color(0xFF2962FF);
    return GestureDetector(
      onTap: () {
        setSheetState(() {
          if (value == null) {
            // Bấm "Tất cả" -> clear hết
            _statusFilters = {};
            _filterPendingApproval = false;
            _filterOverdue = false;
          } else {
            // Toggle trạng thái được chọn
            if (_statusFilters.contains(value)) {
              _statusFilters.remove(value);
            } else {
              _statusFilters.add(value);
            }
            _filterPendingApproval = false; // Reset pending filter
            _filterOverdue = false; // Reset overdue filter
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected && value != null)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.check_circle, size: 14, color: Colors.white),
              ),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingApprovalChip(StateSetter setSheetState) {
    final isSelected = _filterPendingApproval;
    const color = Colors.deepOrange;
    return GestureDetector(
      onTap: () {
        setSheetState(() {
          _filterPendingApproval = !_filterPendingApproval;
          if (_filterPendingApproval) {
            _statusFilters = {}; // Clear other filters when selecting pending
            _filterOverdue = false;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.check_circle, size: 14, color: Colors.white),
              ),
            Text(
              'Chờ duyệt',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value, StateSetter setSheetState) {
    final isSelected = _timeFilter == value;
    return GestureDetector(
      onTap: () => setSheetState(() => _timeFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2962FF) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2962FF) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _addCustomerToRepair(Repair r) async {
    final phoneCtrl = TextEditingController(text: r.phone);
    final nameCtrl = TextEditingController(text: r.customerName);
    final addressCtrl = TextEditingController(text: r.address);
    final notesCtrl = TextEditingController(text: r.notes ?? '');
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    Timer? searchTimer;
    bool dialogActive = true;
    final shopId = await UserService.getCurrentShopId();

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          void doSearch(String q) {
            searchTimer?.cancel();
            if (q.trim().isEmpty) {
              setS(() => searchResults = []);
              return;
            }
            searchTimer = Timer(const Duration(milliseconds: 300), () async {
              // `dialogActive` KHÔNG đủ: cờ đó chỉ được tắt trong 2 nút
              // Huỷ/Lưu, mà dialog này `barrierDismissible` mặc định = true —
              // chạm ra ngoài hoặc bấm Back thì cờ vẫn còn true. Khi đó timer
              // vẫn gọi setState lên element ĐÃ CHẾT ⇒ rebuild giữa lúc
              // teardown ⇒ subtree (Divider/InkWell → Theme.of) đăng ký
              // dependency mới vào InheritedElement đang deactivate ⇒ nổ
              // `assert(_dependents.isEmpty)` (framework.dart). `try/catch`
              // quanh setState KHÔNG bắt được vì assert nổ ở pha build sau.
              // `ctx.mounted` mới là chốt đúng cho MỌI đường đóng dialog.
              if (!dialogActive || !ctx.mounted) return;
              final results = await db.searchCustomers(q.trim(), shopId);
              if (!dialogActive || !ctx.mounted) return;
              setS(() => searchResults = results.take(6).toList());
            });
          }

          // Build search result tiles as Column (tránh ListView lồng trong SingleChildScrollView)
          Widget buildSearchResults() {
            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
                color: Colors.blue.shade50,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: searchResults.asMap().entries.map((entry) {
                  final i = entry.key;
                  final c = entry.value;
                  final cName = (c['name'] as String?) ?? '';
                  final cPhone = (c['phone'] as String?) ?? '';
                  final cAddress = (c['address'] as String?) ?? '';
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (i > 0)
                        Divider(height: 1, color: Colors.blue.shade100),
                      InkWell(
                        onTap: () {
                          phoneCtrl.text = cPhone;
                          nameCtrl.text = cName;
                          if (cAddress.isNotEmpty) addressCtrl.text = cAddress;
                          searchCtrl.clear();
                          setS(() => searchResults = []);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  cName.isNotEmpty ? cName[0] : '?',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      cPhone,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            );
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.person_add, size: 20),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Thêm thông tin khách hàng',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Tìm khách hàng cũ (SĐT hoặc tên)...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        border: const OutlineInputBorder(),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                      onChanged: doSearch,
                    ),
                    if (searchResults.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      buildSearchResults(),
                    ],
                    const Divider(height: 20),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Tên khách hàng',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: addressCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Địa chỉ (tùy chọn)',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú (tùy chọn)',
                        prefixIcon: Icon(Icons.note_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  FocusScope.of(ctx).unfocus();
                  dialogActive = false;
                  searchTimer?.cancel();
                  await Future.delayed(Duration.zero);
                  if (ctx.mounted) Navigator.pop(ctx, false);
                },
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () async {
                  FocusScope.of(ctx).unfocus();
                  dialogActive = false;
                  searchTimer?.cancel();
                  await Future.delayed(Duration.zero);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      ),
    );
    dialogActive = false;
    searchTimer?.cancel();
    // Read values before deferring disposal (dialog close animation not yet complete)
    final newPhone = phoneCtrl.text.trim();
    final newName = nameCtrl.text.trim().toUpperCase();
    final newAddress = addressCtrl.text.trim();
    final newNotes = notesCtrl.text.trim();
    // Defer dispose to let dialog widgets fully detach before notifying listeners
    Future.delayed(Duration.zero, () {
      phoneCtrl.dispose();
      nameCtrl.dispose();
      addressCtrl.dispose();
      notesCtrl.dispose();
      searchCtrl.dispose();
    });

    if (confirmed != true || !mounted) return;

    if (newPhone.isEmpty && newName.isEmpty) return;

    try {
      // 1. Cập nhật đơn sửa
      final updatedRepair = r.copyWith(
        customerName: newName,
        phone: newPhone,
        address: newAddress.isNotEmpty ? newAddress : r.address,
        notes: newNotes.isNotEmpty ? newNotes : r.notes,
        isWalkIn: newPhone.isEmpty && newName.isEmpty,
      );
      await db.upsertRepair(updatedRepair);

      if (r.firestoreId != null && r.firestoreId!.isNotEmpty) {
        final encData = EncryptionService.encryptMap({
          'customerName': newName,
          'phone': newPhone,
          if (newAddress.isNotEmpty) 'address': newAddress,
          if (newNotes.isNotEmpty) 'notes': newNotes,
          'isWalkIn': newPhone.isEmpty && newName.isEmpty,
          'updatedAt': FirestoreWriteHelper.serverUpdatedAt(),
        });
        if (AppSession.syncEnabled) {
          await CloudWritePolicy.guard(
            () => FirebaseFirestore.instance
                .collection('repairs')
                .doc(r.firestoreId)
                .update(encData),
            context: 'repairs',
          );
        }
      }

      // 2. Lưu vào danh sách khách hàng + tính lại stats từ tất cả đơn cũ
      if (newPhone.isNotEmpty) {
        final customerService = CustomerService();
        final shopId = await UserService.getCurrentShopId();

        // Tính lại totalRepairs/totalSpent từ tất cả đơn sửa theo phone
        final allRepairs = await db.getCustomerRepairsHistory(newPhone, shopId);
        final validRepairs = allRepairs
            .where((rep) => (rep['deleted'] ?? 0) != 1)
            .toList();
        final totalRepairs = validRepairs.length;
        final totalRepairCost = validRepairs.fold<int>(
          0,
          (acc, rep) => acc + ((rep['price'] as num?)?.toInt() ?? 0),
        );
        final lastVisit = validRepairs.isNotEmpty
            ? validRepairs
                  .map((r) => (r['createdAt'] as num?)?.toInt() ?? 0)
                  .reduce((a, b) => a > b ? a : b)
            : DateTime.now().millisecondsSinceEpoch;

        final existing = shopId != null
            ? await db.getCustomerByPhone(newPhone, shopId)
            : <Map<String, dynamic>>[];

        if (existing.isEmpty) {
          await customerService.addCustomer(
            Customer(
              name: newName.isNotEmpty ? newName : newPhone,
              phone: newPhone,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              totalRepairs: totalRepairs,
              totalRepairCost: totalRepairCost,
              lastVisitAt: lastVisit,
            ),
          );
        } else {
          final existingId = (existing.first['id'] as num?)?.toInt();
          if (existingId != null) {
            await db.updateCustomer(existingId, {
              if (newName.isNotEmpty) 'name': newName,
              'totalRepairs': totalRepairs,
              'totalRepairCost': totalRepairCost,
              'lastVisitAt': lastVisit,
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
            });
          }
        }
      }

      await _refreshFromSQLite();
      if (mounted) {
        NotificationService.showSnackBar(
          'Đã cập nhật thông tin khách hàng',
          color: Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showSnackBar('Lỗi: $e', color: Colors.red);
      }
    }
  }

  Future<void> _confirmDelete(Repair r) async {
    if (!canDelete) return;

    final displayPrice = _displayedChargePrice(r);

    // === KIỂM TRA ĐIỀU KIỆN XÓA ===
    // 1. Chỉ xóa đơn chưa giao (status < 4)
    if (r.status >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Không thể xóa đơn ĐÃ GIAO. Chỉ xóa đơn chưa giao.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. Cảnh báo nếu đơn đã có giá (có số liệu kế toán)
    final hasAccountingData = displayPrice > 0 || r.cost > 0;
    final hasPartsUsed = r.partsUsed.isNotEmpty;

    final passCtrl = TextEditingController();
    String? errorText;
    bool submitting = false;
    // Dialog CHỈ đóng khi xóa thành công — không đóng dialog rồi mới xác
    // thực (đóng route đang có TextField mật khẩu giữ focus dễ trúng crash
    // "_dependents.isEmpty" đã ghi nhận ở sale_detail_view). Sai mật khẩu ->
    // hiện lỗi ngay TRONG dialog (luôn thấy được, không bị gì che khuất) và
    // dialog vẫn mở để nhập lại.
    final deleted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                hasAccountingData || hasPartsUsed
                    ? Icons.warning_amber_rounded
                    : Icons.delete_forever,
                color: Colors.red,
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text("XÁC NHẬN XÓA ĐƠN")),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thông tin đơn
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.model,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('${r.customerName} - ${r.phone}'),
                    Text('Trạng thái: ${_getStatusText(r.status)}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Cảnh báo nếu có số liệu
              if (hasAccountingData)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.attach_money,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _canViewCostPrice
                              ? loc.orderHasAccounting(
                                  _formatMoney(displayPrice),
                                  _formatMoney(r.cost),
                                )
                              : loc.orderHasAccounting(
                                  _formatMoney(displayPrice),
                                  '***',
                                ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

              // Cảnh báo nếu có phụ tùng
              if (hasPartsUsed)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.build, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            loc.orderHasParts,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        r.partsUsed,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loc.partsWillReturn,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),
              // Offline session without a local PIN: no password to ask for.
              if (!OwnerReauthService.shouldSkipPromptSync)
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  enabled: !submitting,
                  decoration: InputDecoration(
                    hintText: AppSession.isOffline
                        ? "Nhập mật khẩu bảo vệ để xác nhận"
                        : "Nhập mật khẩu quản lý để xác nhận",
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    errorText!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx, false),
              child: const Text("HỦY"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: submitting
                  ? null
                  : () async {
                      setDialogState(() {
                        submitting = true;
                        errorText = null;
                      });
                      final ok = await _executeDelete(r, passCtrl.text);
                      if (!ctx.mounted) return;
                      if (ok) {
                        Navigator.pop(ctx, true);
                      } else {
                        setDialogState(() {
                          submitting = false;
                          errorText = "❌ Mật khẩu sai";
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("XÓA", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    passCtrl.dispose();
    if (deleted != true) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasPartsUsed
              ? '✅ Đã xóa đơn và hoàn trả phụ tùng về kho'
              : '✅ Đã xóa đơn thành công',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _getStatusText(int status) {
    switch (status) {
      case 1:
        return loc.received;
      case 2:
        return loc.repairing;
      case 3:
        return loc.repairDone;
      case 4:
        return loc.delivered;
      default:
        return 'Unknown';
    }
  }

  String _formatMoney(int amount) {
    if (amount == 0) return '0đ';
    return '${NumberFormat('#,###', 'vi_VN').format(amount)}đ';
  }

  /// Thực hiện xóa đơn — trả về true nếu thành công. KHÔNG tự đóng dialog
  /// hay show SnackBar; caller (`_confirmDelete`) xử lý cả hai sau khi hàm
  /// này trả về, để tránh đóng dialog xác thực sớm (crash _dependents khi
  /// route dialog có TextField focus bị gỡ giữa chừng).
  Future<bool> _executeDelete(Repair r, String password) async {
    // Online: Firebase re-auth. Offline: local PIN (or nothing configured).
    if (!await OwnerReauthService.verify(password)) return false;

    try {

      // === HOÀN TRẢ PHỤ TÙNG VỀ KHO ===
      if (r.partsUsed.isNotEmpty) {
        await _restorePartsToInventory(r.partsUsed, r.partsUsedDetailed);
      }

      // Lưu id trước khi xóa để dùng cho sync
      final repairId = r.id;
      final repairFirestoreId = r.firestoreId;

      // Nếu có firestoreId, xóa trực tiếp trên Firestore trước
      if (repairFirestoreId != null && repairFirestoreId.isNotEmpty) {
        try {
          await FirestoreService.deleteRepair(repairFirestoreId);
        } catch (e) {
          debugPrint('❌ Failed to soft delete on Firestore: $e');
          // Cloud delete lỗi (mạng/timeout) — vẫn xóa local theo đúng thao
          // tác user vừa xác nhận, nhưng xếp hàng đợi retry để cloud không
          // mồ côi document vĩnh viễn (trước đây bỏ qua bước này, khiến
          // "Trung tâm đồng bộ" báo lệch Local/Cloud kéo dài không tự hết).
          if (repairId != null) {
            await SyncOrchestrator().enqueueRepair(
              repairId,
              firestoreId: repairFirestoreId,
              operation: SyncOperation.delete,
            );
          }
        }
      }

      // Xóa local
      if (repairFirestoreId != null && repairFirestoreId.isNotEmpty) {
        await db.deleteRepairByFirestoreId(repairFirestoreId);
      } else if (repairId != null) {
        await db.deleteRepair(repairId);
      }

      // Ghi nhật ký
      final partsInfo = r.partsUsed.isNotEmpty
          ? loc.returnedParts(r.partsUsed)
          : '';
      await db.logAction(
        userId: AppSession.userId ?? '0',
        userName:
            AppSession.userEmail?.split('@').first.toUpperCase() ?? 'NV',
        action: loc.deleteRepairAction,
        type: 'REPAIR',
        targetId: repairFirestoreId,
        desc: loc.deletedRepairDesc(
          r.model,
          r.customerName,
          r.phone,
          partsInfo,
        ),
      );

      // KHÔNG cần enqueue delete nữa vì đã soft delete trực tiếp trên Firestore rồi
      // Việc enqueue delete sẽ tạo pending sync không cần thiết
      // SyncService sẽ đồng xóa local khi nhận deleted=true từ Firestore
      debugPrint(
        '✅ Repair deleted directly on Firestore - no need for sync queue',
      );

      _removeRepairFromLocalCache(repairFirestoreId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Hoàn trả phụ tùng về kho
  /// Format partsUsed: "Part1 x1, Part2 x2, ..."
  Future<void> _restorePartsToInventory(
    String partsUsed, [
    List<PartUsedDetail> detailed = const [],
  ]) async {
    if (partsUsed.isEmpty) return;

    // Parse partsUsed
    final parts = partsUsed.split(', ');
    for (final part in parts) {
      // Parse "PartName x2" hoặc "PartName"
      final match = RegExp(r'^(.+?)\s*x(\d+)$').firstMatch(part.trim());
      String partName;
      int quantity;

      if (match != null) {
        partName = match.group(1)!.trim();
        quantity = int.tryParse(match.group(2)!) ?? 1;
      } else {
        partName = part.trim();
        quantity = 1;
      }

      if (partName.isEmpty) continue;

      // Tìm part trong kho và cộng số lượng — ưu tiên khoá cloud trong
      // snapshot (BUG-07); đơn cũ không có snapshot thì theo tên như trước.
      PartUsedDetail? detail;
      for (final d in detailed) {
        if (d.name.trim().toUpperCase() == partName.toUpperCase()) {
          detail = d;
          break;
        }
      }
      await db.restorePartQuantityByDetail(detail, partName, quantity);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Danh sách = cửa sổ SQLite đã nạp; số đếm chip = SQL COUNT toàn shop.
    final pool = _allRepairs;
    final totalCount = _counts['total'] ?? pool.length;

    // Layout rộng (web / tablet / màn xoay ngang): header gọn + 2 cột đơn.
    final Size size = MediaQuery.sizeOf(context);
    final bool useGrid = size.width >= 900 ||
        (size.width > size.height && size.width >= 700);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: CustomAppBar.build(
        guideKey: FirstTimeGuideService.keyOrderList,
        title: "DANH SÁCH ĐIỆN THOẠI",
        subtitle: _headerSubtitle(totalCount),
        actions: [
          // Nút "?" đã có sẵn qua `guideKey` — bản cũ thêm nút thứ 2 trùng.
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GlobalSearchView(role: widget.role),
              ),
            ),
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            tooltip: 'Tìm kiếm toàn app',
          ),
          if (!widget.todayOnly)
            Stack(
              children: [
                IconButton(
                  onPressed: _showFilterSheet,
                  icon: const Icon(
                    Icons.filter_list_rounded,
                    color: Colors.white,
                  ),
                  tooltip: 'Lọc theo thời gian',
                ),
                if (_activeFilterCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_activeFilterCount',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            // Active filter chip
            if (_activeFilterCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.blue.shade50,
                child: Row(
                  children: [
                    const Icon(
                      Icons.filter_list,
                      size: 16,
                      color: Color(0xFF2962FF),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Lọc: ${_getTimeFilterLabel()}',
                      style: AppTextStyles.subtitle1.copyWith(
                        color: const Color(0xFF2962FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _timeFilter = 'all';
                          _customStartDate = null;
                          _customEndDate = null;
                        });
                        _onSearch(_currentSearch);
                      },
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Color(0xFF2962FF),
                      ),
                    ),
                  ],
                ),
              ),
            useGrid
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: _buildSearchField(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildSortSelector(),
                        const SizedBox(width: 6),
                        _buildSyncButton(),
                      ],
                    ),
                  )
                : Padding(
                    // Tìm + sắp xếp + đồng bộ trên MỘT hàng; bỏ hàng
                    // "Realtime Firestore • N đơn" (list đọc SQLite, nhãn
                    // đó vừa sai vừa chiếm chỗ) — trạng thái mạng chỉ hiện
                    // khi thực sự có vấn đề (banner bên dưới).
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Row(
                      children: [
                        Expanded(child: _buildSearchField()),
                        const SizedBox(width: 6),
                        _buildSortSelector(compact: true),
                        const SizedBox(width: 6),
                        _buildSyncButton(),
                      ],
                    ),
                  ),
            _buildStatusFilterChips(pool: pool),
            if (!ConnectivityService.instance.isOnline)
              _buildSyncBanner(
                icon: Icons.cloud_off_rounded,
                text: 'Ngoại tuyến — đang xem dữ liệu đã lưu',
              )
            else if (!SyncService.isRealTimeSyncActive &&
                !_isLoading &&
                !_isSearchingLocal &&
                DateTime.now().isAfter(_syncBannerGraceUntil))
              _buildSyncBanner(
                icon: Icons.sync_problem_rounded,
                text: 'Không thể đồng bộ',
                onRetry: () => SyncService.refreshCollectionNow('repairs'),
              ),
            Expanded(
              child: _buildListBody(
                useGrid: useGrid,
                pool: pool,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: GradientFab.purple(
        onPressed: _openCreateOrder,
        icon: Icons.phone_android_rounded,
        label: 'Nhận điện thoại',
      ),
    );
  }

  Future<void> _openCreateOrder() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateRepairOrderView(role: widget.role),
      ),
    );
    if (res == true) {
      unawaited(_refreshFromSQLite());
    }
  }

  // ─── UI Helper: Adaptive Search + List (mobile / xoay ngang / web) ─────────
  Widget _buildSearchField() {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearch,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Tìm khách hàng, model, lỗi, SĐT, mã đơn...',
          prefixIcon: const Icon(Icons.search_rounded, size: 22),
          suffixIcon: _currentSearch.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Xoá tìm kiếm',
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF2962FF),
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  /// Vùng danh sách theo layout: 1 cột (mobile dọc) hoặc 2 cột chia parity
  /// (web / tablet / xoay ngang — tận dụng màn rộng, giữ STT toàn cục).
  Widget _buildListBody({
    required bool useGrid,
    required List<Repair> pool,
  }) {
    if (_isLoading || _isSearchingLocal) {
      return const SkeletonListView(
        variant: SkeletonVariant.repairCard,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      );
    }
    if (_displayedRepairs.isEmpty) {
      final bool filtering = _statusFilters.isNotEmpty ||
          _filterPendingApproval ||
          _filterOverdue;
      return EmptyStateWidget(
        icon: Icons.build_circle_outlined,
        title: filtering ? 'Không có đơn phù hợp' : loc.noRepairOrders,
        subtitle: filtering ? 'Thử bỏ lọc để xem tất cả đơn' : null,
        actionLabel: filtering ? 'Bỏ lọc' : '+ Tạo đơn sửa',
        onAction: filtering
            ? () {
                setState(() {
                  _statusFilters.clear();
                  _filterPendingApproval = false;
                  _filterOverdue = false;
                  _timeFilter = 'all';
                  _customStartDate = null;
                  _customEndDate = null;
                });
                _onSearch(_currentSearch);
              }
            : _openCreateOrder,
      );
    }

    if (useGrid) {
      final List<Repair> colA = <Repair>[];
      final List<Repair> colB = <Repair>[];
      for (int i = 0; i < _displayedRepairs.length; i++) {
        if (i.isEven) {
          colA.add(_displayedRepairs[i]);
        } else {
          colB.add(_displayedRepairs[i]);
        }
      }
      return Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _listScrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 6, 12),
                    itemCount: colA.length,
                    itemBuilder: (_, j) =>
                        _buildRepairCard(colA[j], (j * 2) + 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ListView.builder(
                    controller: _listScrollControllerGridB,
                    padding: const EdgeInsets.fromLTRB(6, 4, 16, 12),
                    itemCount: colB.length,
                    itemBuilder: (_, j) =>
                        _buildRepairCard(colB[j], (j * 2) + 2),
                  ),
                ),
              ],
            ),
          ),
          _buildGridFooter(pool: pool),
        ],
      );
    }

    return ListView.builder(
      controller: _listScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _displayedRepairs.length + 1,
      itemBuilder: (ctx, i) {
        if (i < _displayedRepairs.length) {
          return _buildRepairCard(_displayedRepairs[i], i + 1);
        }
        if (_isLoadingMore) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (_hasMoreData) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: OutlinedButton.icon(
              onPressed: _loadMoreFromSQLite,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
              ),
              label: const Text('Tải thêm'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
                side: BorderSide(color: Colors.blue.shade200),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                ),
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              loc.displayedRepairs(_displayedRepairs.length),
              style: AppTextStyles.caption.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Thanh chân dưới của layout 2 cột: trạng thái đồng bộ trái, tải thêm/
  /// đếm đơn phải (thay cho footer lồng trong từng danh sách như 1 cột).
  Widget _buildGridFooter({required List<Repair> pool}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: SyncStatusBar(
              isOnline: ConnectivityService.instance.isOnline,
              isRealtimeConnected: SyncService.isRealTimeSyncActive,
              itemCount: pool.length,
              itemLabel: 'đơn',
            ),
          ),
          const SizedBox(width: 8),
          if (_isLoadingMore)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.6),
            )
          else if (_hasMoreData)
            OutlinedButton.icon(
              onPressed: _loadMoreFromSQLite,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                size: 16,
              ),
              label: const Text('Tải thêm'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
                side: BorderSide(color: Colors.blue.shade200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: const Size(0, 32),
              ),
            )
          else
            Text(
              loc.displayedRepairs(_displayedRepairs.length),
              style: AppTextStyles.caption.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
        ],
      ),
    );
  }

  // ─── UI Helper: Status Filter Chips Row ────────────────────────────────────
  Widget _buildStatusFilterChips({required List<Repair> pool}) {
    // SQL COUNT toàn shop (xem `_reloadCounts`); rơi về cửa sổ đã nạp khi
    // chưa kịp đếm.
    final bool hasCounts = _counts.isNotEmpty;
    final int allCount = hasCounts ? _counts['total']! : pool.length;
    final int receivedCount = hasCounts
        ? (_counts['received']! + _counts['repairing']!)
        : pool.where((r) => r.status == 1 || r.status == 2).length;
    final int doneCount = hasCounts
        ? _counts['done']!
        : pool.where((r) => r.status == 3 && !r.pendingDeliveryApproval).length;
    final int pendingCount = hasCounts
        ? _counts['pending']!
        : pool.where((r) => r.status == 3 && r.pendingDeliveryApproval).length;
    final int deliveredCount = hasCounts
        ? _counts['delivered']!
        : pool.where((r) => r.status >= 4).length;
    final int overdueCount =
        hasCounts ? _counts['overdue']! : pool.where(_isOverdue).length;

    bool isAllSelected = _statusFilters.isEmpty && !_filterPendingApproval && !_filterOverdue;
    bool isPending = _filterPendingApproval;

    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
          _filterChipItem('Tất cả', allCount, const Color(0xFF2962FF), isAllSelected, () {
            setState(() {
              _statusFilters.clear();
              _filterPendingApproval = false;
              _filterOverdue = false;
            });
            _rebuildDisplayedRepairs();
          }),
          _filterChipItem('Tiếp nhận', receivedCount, AppColors.repairReceived, _statusFilters.contains(1) && !isPending && !_filterOverdue, () {
            setState(() {
              if (_statusFilters.contains(1)) {
                _statusFilters.remove(1);
              } else {
                _statusFilters.add(1);
              }
              _filterPendingApproval = false;
              _filterOverdue = false;
            });
            _rebuildDisplayedRepairs();
          }),
          _filterChipItem('Sửa xong', doneCount, AppColors.repairDone, _statusFilters.contains(3) && !isPending && !_filterOverdue, () {
            setState(() {
              if (_statusFilters.contains(3)) {
                _statusFilters.remove(3);
              } else {
                _statusFilters.add(3);
              }
              _filterPendingApproval = false;
              _filterOverdue = false;
            });
            _rebuildDisplayedRepairs();
          }),
          _filterChipItem('Y/c duyệt', pendingCount, AppColors.repairPendingApproval, isPending, () {
            setState(() {
              _filterPendingApproval = !_filterPendingApproval;
              if (_filterPendingApproval) {
                _statusFilters.clear();
                _filterOverdue = false;
              }
            });
            _rebuildDisplayedRepairs();
          }),
          _filterChipItem('Giao', deliveredCount, AppColors.repairDelivered, _statusFilters.contains(4) && !isPending && !_filterOverdue, () {
            setState(() {
              if (_statusFilters.contains(4)) {
                _statusFilters.remove(4);
              } else {
                _statusFilters.add(4);
              }
              _filterPendingApproval = false;
              _filterOverdue = false;
            });
            _rebuildDisplayedRepairs();
          }),
          _filterChipItem('Quá hạn', overdueCount, Colors.red.shade700, _filterOverdue, () {
            setState(() {
              _filterOverdue = !_filterOverdue;
              if (_filterOverdue) {
                _statusFilters.clear();
                _filterPendingApproval = false;
              }
            });
            _rebuildDisplayedRepairs();
          }),
        ],
      ),
      ),
    );
  }

  Widget _filterChipItem(String label, int count, Color color, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? color : Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(width: 5),
              Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: selected ? Colors.white.withValues(alpha: 0.9) : color)),
          ],
        ),
      ),
      ),
    );
  }

  /// Bộ chọn kiểu sắp xếp (thuần UI — logic sort nằm ở _compareRepairs).
  Widget _buildSortSelector({bool compact = false}) {
    return PopupMenuButton<String>(
      tooltip: 'Sắp xếp',
      offset: const Offset(0, 40),
      onSelected: (value) {
        if (_sortMode == value) return;
        setState(() => _sortMode = value);
        _rebuildDisplayedRepairs();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'priority',
          child: Text('Ưu tiên', style: TextStyle(fontSize: 13)),
        ),
        const PopupMenuItem(
          value: 'newest',
          child: Text('Mới nhất', style: TextStyle(fontSize: 13)),
        ),
        const PopupMenuItem(
          value: 'oldest',
          child: Text('Cũ nhất', style: TextStyle(fontSize: 13)),
        ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 14, color: Color(0xFF2962FF)),
            const SizedBox(width: 4),
            Text(
              compact ? _sortLabel(_sortMode) : 'Sắp xếp: ${_sortLabel(_sortMode)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  String _sortLabel(String mode) {
    switch (mode) {
      case 'newest':
        return 'Mới nhất';
      case 'oldest':
        return 'Cũ nhất';
      default:
        return 'Ưu tiên';
    }
  }

  /// Nút [↻ Đồng bộ]: push dữ liệu local chưa đồng bộ lên cloud (write,
  /// KHÔNG thêm read cho UI) sau đó nạp lại SQLite — không tạo listener mới.
  Widget _buildSyncButton() {
    return IconButton(
      onPressed: _isManualSyncing ? null : _manualSync,
      tooltip: 'Đồng bộ',
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        side: BorderSide(color: Colors.grey.shade200),
        minimumSize: const Size(36, 36),
        fixedSize: const Size(36, 36),
        padding: EdgeInsets.zero,
      ),
      icon: _isManualSyncing
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.6),
            )
          : const Icon(Icons.sync_rounded, size: 17, color: Color(0xFF2962FF)),
    );
  }

  Future<void> _manualSync() async {
    if (!ConnectivityService.instance.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ngoại tuyến — dữ liệu vẫn còn trong máy'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_isManualSyncing) return;
    setState(() => _isManualSyncing = true);
    try {
      await SyncService.syncAllToCloud();
      await _refreshFromSQLite();
      if (!mounted) return;
      _rebuildDisplayedRepairs();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đồng bộ'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể đồng bộ — $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _isManualSyncing = false);
    }
  }

  /// Banner trạng thái đồng bộ (giữ nguyên list local, không phải error page).
  Widget _buildSyncBanner({
    required IconData icon,
    required String text,
    VoidCallback? onRetry,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade900,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Thử lại', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  /// Label thời gian compact cho header card: "Hôm nay 10:15" / "Hôm qua 10:15"
  /// / "dd/MM HH:mm".
  String _timeLabel(Repair r) {
    final dt = DateTime.fromMillisecondsSinceEpoch(r.createdAt);
    final now = DateTime.now();
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day) {
      return 'Hôm nay ${DateFormat('HH:mm').format(dt)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Hôm qua ${DateFormat('HH:mm').format(dt)}';
    }
    return DateFormat('dd/MM HH:mm').format(dt);
  }



  /// Thẻ đơn kiểu "chip" (chủ shop chọn lại 2026-09-19 theo bản cũ): STT +
  /// ảnh (+N) + model + chip lỗi + chip KTV ở đầu; bên dưới là các chip
  /// trạng thái · quá hạn · khách · SĐT · giờ · giá thu · vốn/lãi (theo
  /// quyền) · phụ tùng · dịch vụ · ghi chú · phụ kiện/MK · vị trí. Nền thẻ
  /// nhạt theo trạng thái. Chỉ vẽ từ dữ liệu đã có trong `Repair` — không
  /// đọc thêm gì.
  Widget _buildRepairCard(Repair r, int index) {
    final List<String> images = _collectRepairImages(r);
    final int displayCost = r.totalCost;
    final int displayPrice = _displayedChargePrice(r);
    final int displayProfit = displayPrice - displayCost;
    // CLAUDE.md §9: vốn/lãi chỉ hiện khi có quyền giá vốn (và doanh thu).
    final bool canShowCost = _canViewCostPrice && _canViewRevenue;
    final bool hasRequestedCharge =
        r.pendingDeliveryApproval && r.requestedDeliveryPrice != null;
    final bool overdue = _isOverdue(r);

    Color bgColor;
    Color borderColor;
    switch (r.status) {
      case 1:
        bgColor = const Color(0xFFEAF2FF);
        borderColor = Colors.blue.shade300;
        break;
      case 2:
        bgColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade300;
        break;
      case 3:
        bgColor = r.pendingDeliveryApproval
            ? Colors.deepOrange.shade50
            : const Color(0xFFEAF7EE);
        borderColor = r.pendingDeliveryApproval
            ? Colors.deepOrange.shade300
            : Colors.green.shade300;
        break;
      case 4:
        bgColor = const Color(0xFFF1F5F9);
        borderColor = Colors.blueGrey.shade200;
        break;
      default:
        bgColor = Colors.grey.shade50;
        borderColor = Colors.grey.shade300;
    }
    if (overdue) borderColor = Colors.red.shade300;

    final String ktv = (r.repairedBy ?? '').trim();
    // `accessories` đã chứa cả "… | MK: …" (create_repair_order_view) —
    // bỏ phần rỗng ("| MK:" khi không nhập gì) để không hiện chip trống.
    final String accLine = r.accessories
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.toUpperCase() != 'MK:')
        .join(' | ');

    return Dismissible(
      key: Key(r.firestoreId ?? r.createdAt.toString()),
      direction: canDelete
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_forever, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async {
        _confirmDelete(r);
        return false;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RepairDetailView(repair: r)),
            );
            if (!mounted) return;
            // Đơn có thể đổi trạng thái trong màn chi tiết → đọc lại SQLite.
            unawaited(_refreshFromSQLite());
          },
          onLongPress: () {
            if (!canDelete) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chỉ quản lý/chủ shop mới có quyền xóa đơn'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            if (r.status >= 4) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '❌ Không thể xóa đơn ĐÃ GIAO. Chỉ xóa đơn chưa giao.',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            _confirmDelete(r);
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Đầu thẻ: STT · ảnh · model + lỗi · KTV ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: borderColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$index',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: borderColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: Stack(
                        children: [
                          _buildRepairThumbnail(r, size: 52),
                          if (images.length > 1)
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '+${images.length - 1}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            r.model.trim().isEmpty ? 'Thiết bị' : r.model,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (r.issue.trim().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDECEC),
                                border: Border.all(
                                  color: const Color(0xFFFFCDD2),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.build_rounded,
                                    size: 10,
                                    color: Color(0xFFD32F2F),
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      r.issue.split('|').first.trim(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFD32F2F),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _repairInfoChip(
                      ktv.isNotEmpty ? '👨‍🔧 $ktv' : '👨‍🔧 Chưa có KTV',
                      ktv.isNotEmpty ? Colors.purple.shade100 : Colors.grey.shade200,
                      textColor: ktv.isNotEmpty
                          ? Colors.purple.shade800
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                // ── Các chip thông tin ──
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _repairInfoChip(
                      _getStatusLabel(
                        r.status,
                        pendingApproval: r.pendingDeliveryApproval,
                      ),
                      _getStatusColor(
                        r.status,
                        pendingApproval: r.pendingDeliveryApproval,
                      ),
                      textColor: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    if (overdue)
                      _repairInfoChip(
                        '⚠️ QUÁ HẠN ${_daysStuck(r)} NGÀY',
                        Colors.red.shade100,
                        textColor: Colors.red.shade900,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    if (r.customerName.trim().isNotEmpty)
                      _repairInfoChip(
                        '👤 ${r.customerName}',
                        Colors.blueGrey.shade50,
                        textColor: Colors.blueGrey.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      )
                    else
                      GestureDetector(
                        onTap: () => _addCustomerToRepair(r),
                        child: _repairInfoChip(
                          '👤 Thêm khách hàng',
                          Colors.orange.shade50,
                          textColor: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    if (r.phone.trim().isNotEmpty)
                      _repairInfoChip(
                        '📞 ${r.phone}',
                        Colors.blueGrey.shade50,
                        textColor: Colors.blueGrey.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    _repairInfoChip(
                      '⏱ ${_timeLabel(r)}',
                      Colors.blueGrey.shade50,
                      textColor: Colors.blueGrey.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    if (displayPrice > 0)
                      _repairInfoChip(
                        '💰 ${hasRequestedCharge ? 'YC ' : ''}'
                        '${MoneyUtils.formatCompactCurrency(displayPrice)}đ',
                        Colors.green.shade100,
                        textColor: Colors.green.shade800,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    if (canShowCost && displayCost > 0)
                      _repairInfoChip(
                        '🏷 Vốn ${MoneyUtils.formatCompactCurrency(displayCost)}đ',
                        Colors.blue.shade50,
                        textColor: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    if (canShowCost && r.status == 4 && displayCost == 0)
                      _repairInfoChip(
                        '⚠ Vốn 0đ — cần bổ sung',
                        Colors.red.shade50,
                        textColor: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    if (canShowCost && displayPrice > 0 && displayCost > 0)
                      _repairInfoChip(
                        displayProfit >= 0
                            ? '📈 Lãi ${MoneyUtils.formatCompactCurrency(displayProfit)}đ'
                            : '📉 Lỗ ${MoneyUtils.formatCompactCurrency(displayProfit.abs())}đ',
                        displayProfit >= 0
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        textColor: displayProfit >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    if (r.partsUsed.trim().isNotEmpty)
                      _repairInfoChip(
                        '🔩 ${r.partsUsed.trim()}',
                        Colors.cyan.shade50,
                        textColor: Colors.cyan.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        maxLines: 2,
                      ),
                    if (r.services.isNotEmpty)
                      _repairInfoChip(
                        '🛠️ ${r.services.map((s) => s.serviceName).join(', ')}',
                        Colors.teal.shade50,
                        textColor: Colors.teal.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        maxLines: 2,
                      ),
                    if ((r.notes ?? '').trim().isNotEmpty)
                      _repairInfoChip(
                        '📝 ${r.notes!.trim()}',
                        Colors.amber.shade100,
                        textColor: Colors.amber.shade900,
                        fontSize: 11,
                        maxLines: 2,
                      ),
                    if (accLine.isNotEmpty)
                      _repairInfoChip(
                        '🧰 $accLine',
                        Colors.blue.shade100,
                        textColor: Colors.blue.shade900,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    if ((r.storageLocationCode ?? '').isNotEmpty)
                      _repairInfoChip(
                        '📍 ${r.storageLocationCode}',
                        Colors.indigo.shade50,
                        textColor: Colors.indigo.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _repairInfoChip(
    String text,
    Color color, {
    Color textColor = Colors.black,
    FontWeight fontWeight = FontWeight.w500,
    double fontSize = 11,
    int maxLines = 1,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: (MediaQuery.sizeOf(context).width - 100).clamp(0, 400),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            color: textColor,
            fontWeight: fontWeight,
            height: 1.2,
          ),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// Thu ảnh đơn sửa làm thumbnail: ưu tiên ảnh nhận máy (receiveImages),
  /// bổ sung rơi vào imagePath (JSON array hoặc danh sách ngăn cách , ; \n).
  List<String> _collectRepairImages(Repair r) {
    final result = <String>[];

    void addCandidate(String value) {
      var s = value.trim();
      if (s.isEmpty) return;
      if ((s.startsWith('"') && s.endsWith('"')) ||
          (s.startsWith("'") && s.endsWith("'"))) {
        s = s.substring(1, s.length - 1).trim();
      }
      if (s.startsWith('[') && s.endsWith(']')) {
        s = s.substring(1, s.length - 1).trim();
      }
      if (s.isEmpty || result.contains(s)) return;
      result.add(s);
    }

    for (final image in r.receiveImages) {
      addCandidate(image);
    }
    final raw = (r.imagePath ?? '').trim();
    if (raw.isNotEmpty) {
      for (final part in raw.split(RegExp(r'[,;\n]'))) {
        addCandidate(part);
      }
    }
    return result;
  }

  /// Chọn ảnh hiển thị: ưu tiên nguồn render được mọi máy (http/gs/blob/data);
  /// trên web bỏ path local vì không xuyên máy/session được.
  String _pickBestPreviewImage(List<String> images) {
    if (images.isEmpty) return '';
    for (final image in images) {
      if (_isWebPreviewSource(image)) return image;
    }
    if (kIsWeb) return '';
    return images.first;
  }

  bool _isWebPreviewSource(String path) {
    final lower = path.toLowerCase();
    return StorageService.isDisplayableCloudPath(path) ||
        lower.startsWith('blob:') ||
        lower.startsWith('data:');
  }

  /// Ảnh nhỏ 40px trên card đơn sửa — chỉ UI, resolve local/cloud/gs qua
  /// StorageService; không phải đường đọc Firestore.
  Widget _buildRepairThumbnail(Repair r, {double size = 36}) {
    final String first = _pickBestPreviewImage(_collectRepairImages(r));

    if (first.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.phone_android_rounded,
          size: 20,
          color: Colors.grey.shade400,
        ),
      );
    }

    Widget content;
    if (StorageService.isGsStoragePath(first) ||
        StorageService.isStorageRelativePath(first)) {
      content = FutureBuilder<String?>(
        future: StorageService.resolveDisplayUrl(first),
        builder: (context, snap) {
          final url = snap.data;
          if (url == null || url.isEmpty) {
            return const Icon(Icons.broken_image_rounded,
                size: 20, color: Colors.grey);
          }
          return AppCachedImage(
            imageUrl: url,
            fit: BoxFit.cover,
            memCacheWidth: 160,
          );
        },
      );
    } else if (first.startsWith('http') ||
        first.startsWith('blob:') ||
        first.startsWith('data:')) {
      content = AppCachedImage(
        imageUrl: first,
        fit: BoxFit.cover,
        memCacheWidth: 160,
      );
    } else if (kIsWeb) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.phone_android_rounded,
          size: 20,
          color: Colors.grey.shade400,
        ),
      );
    } else {
      final file = File(first);
      if (!file.existsSync()) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.phone_android_rounded,
            size: 20,
            color: Colors.grey.shade400,
          ),
        );
      }
      content = Image.file(file, fit: BoxFit.cover);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: Container(color: Colors.grey.shade100, child: content),
      ),
    );
  }

  String _getStatusLabel(int status, {bool pendingApproval = false}) {
    if (status == 3 && pendingApproval) {
      return loc.statusPendingApproval;
    }
    switch (status) {
      case 1:
        return loc.statusReceivedUpper;
      case 2:
        return loc.statusRepairingUpper;
      case 3:
        return loc.statusRepairDoneUpper;
      case 4:
        return loc.statusDeliveredUpper;
      default:
        return loc.statusOther;
    }
  }

  Color _getStatusColor(int status, {bool pendingApproval = false}) {
    if (status == 3 && pendingApproval) {
      return AppColors.repairPendingApproval;
    }
    switch (status) {
      case 1:
        return AppColors.repairReceived;
      case 2:
        return AppColors.repairRepairing;
      case 3:
        return AppColors.repairDone;
      case 4:
        return AppColors.repairDelivered;
      default:
        return Colors.grey;
    }
  }


}
