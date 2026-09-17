import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/db_helper.dart';
import '../services/first_time_guide_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/skeleton_list.dart';
import '../models/repair_model.dart';
import '../services/event_bus.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';
import '../services/encryption_service.dart';
import '../services/sync_service.dart';
import '../services/sync_orchestrator.dart';
import '../services/firestore_service.dart';
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
import '../widgets/app_cached_image.dart';
import '../widgets/sync_status_bar.dart';
import '../services/connectivity_service.dart';
import '../services/customer_service.dart';
import '../models/customer_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _repairRealtimeSubscription;
  final Map<String, Repair> _repairsByFirestoreId = <String, Repair>{};
  String? _listeningShopId;
  bool _receivedServerSnapshot = false;
  bool _isRealtimeConnected = false;
  bool _useRealtimeIndexFallback = false;
  final int _indexedFetchLimit = 50;
  bool _isLoadingMoreRealtime = false;
  // SQLite-first pagination
  List<Repair> _sqliteRepairs = [];
  int _sqliteLoadedCount = 0;
  bool _hasMoreData = false;
  bool _isLoadingMore = false;
  static const int _kPageSize = 50;
  // Tracks which shopIds have had a full historical backfill this session.
  // Static so it survives widget rebuilds / navigate-back.
  static final Set<String> _backfilledShops = {};
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

  bool get canDelete => _canDelete;

  // Sort mặc định "Ưu tiên" (business priority) theo đặc tả:
  // 1. Tiếp nhận → 2. Đang sửa → 3. Y/c duyệt giao → 4. Giao máy →
  // 5. Quá hạn (UI computed, không đổi status) → 6. Xong. Trong cùng
  // state: đơn mới hơn trước. Các mode khác chỉ sắp theo createdAt.
  int _compareRepairs(Repair a, Repair b) {
    switch (_sortMode) {
      case 'newest':
        return b.createdAt.compareTo(a.createdAt);
      case 'oldest':
        return a.createdAt.compareTo(b.createdAt);
    }
    int priority(Repair r) {
      if (r.status == 1) return 1; // Tiếp nhận
      if (r.status == 2) return 2; // Đang sửa — giữ nguyên status/mapping có sẵn
      if (r.status == 3 && !r.pendingDeliveryApproval) return 3; // Xong
      if (r.status == 3 && r.pendingDeliveryApproval) return 4; // Y/c duyệt
      if (r.status == 4) return 5; // Giao
      return 6;
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

  /// Số ngày đơn đã treo ở trạng thái hiện tại (Tiếp nhận hoặc Sửa xong chưa
  /// giao) — null nếu không thuộc 2 trạng thái này hoặc thiếu mốc thời gian.
  int? _daysStuck(Repair repair) {
    if (repair.status == 4) return null;
    if (repair.status == 3 && repair.pendingDeliveryApproval) return null;
    if (repair.status != 1 && repair.status != 3) return null;

    final referenceMs = repair.status == 1
        ? repair.createdAt
        : (repair.finishedAt ?? repair.lastCaredAt ?? repair.createdAt);
    if (referenceMs <= 0) return null;

    return DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(referenceMs))
        .inDays;
  }

  /// Đơn "Tiếp nhận" hoặc "Sửa xong" (chưa giao) bị treo quá
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
    unawaited(_startRealtimeRepairsListener(forceRestart: true));
    WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstTimeGuide());

    // Chỉ rebind listener khi đổi shop — dataRefresh không cần restart vì
    // watchRepairsByShop đã nhận live updates, restart chỉ tốn thêm Firestore reads.
    _eventSubscription = EventBus().stream.listen((event) {
      if (!mounted) return;

      if (event == EventBus.shopChanged) {
        unawaited(_startRealtimeRepairsListener(forceRestart: true));
        return;
      }

      if (event == EventBus.repairsChanged) {
        unawaited(_showPendingLocalRepairsWhileWaitingRealtime());
      }
    });
  }

  Future<void> _loadDeletePermission() async {
    try {
      final results = await Future.wait([
        UserService.isCurrentUserAdmin(),
        UserService.getCurrentUserPermissions(forceRefresh: true),
      ]);
      if (!mounted) return;
      setState(() {
        _canDelete = results[0] as bool;
        final perms = results[1] as Map<String, dynamic>;
        _canViewCostPrice = perms['allowViewCostPrice'] == true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _canDelete = widget.role == 'admin' || widget.role == 'owner';
        _canViewCostPrice = false;
      });
    }
  }

  bool _isGsStoragePath(String path) {
    return StorageService.isGsStoragePath(path);
  }

  bool _isStorageRelativePath(String path) {
    return StorageService.isStorageRelativePath(path);
  }

  Future<String?> _resolveDisplayImagePath(String path) async {
    return StorageService.resolveDisplayUrl(path);
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
    _repairRealtimeSubscription?.cancel();
    _eventSubscription?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onListScroll() {
    if (!_listScrollController.hasClients ||
        _isLoadingMoreRealtime ||
        _isLoadingMore) {
      return;
    }

    final pos = _listScrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 220) return;

    // SQLite pagination: chỉ còn dùng để tải thêm lịch sử ĐÃ GIAO — đơn
    // CHƯA giao luôn được tải đầy đủ ngay từ đầu qua realtime listener
    // (watchRepairsByShop không giới hạn số lượng khi activeOnly), nên không
    // cần "load more" phía Firestore cho phần đó nữa.
    if (_hasMoreData) {
      unawaited(_loadMoreFromSQLite());
    }
  }

  void _onListScrollGridB() {
    if (!_listScrollControllerGridB.hasClients ||
        _isLoadingMoreRealtime ||
        _isLoadingMore) {
      return;
    }

    final pos = _listScrollControllerGridB.position;
    if (pos.pixels < pos.maxScrollExtent - 220) return;

    if (_hasMoreData) {
      unawaited(_loadMoreFromSQLite());
    }
  }

  Future<void> _startRealtimeRepairsListener({
    bool forceRestart = false,
  }) async {
    final shopId = (await UserService.getCurrentShopId())?.trim();
    if (!mounted) return;

    if (shopId == null || shopId.isEmpty) {
      setState(() {
        _isLoading = false;
        _isRealtimeConnected = false;
        _listeningShopId = null;
        _repairsByFirestoreId.clear();
        _displayedRepairs = [];
      });
      return;
    }

    if (!forceRestart &&
        _repairRealtimeSubscription != null &&
        _listeningShopId == shopId) {
      return;
    }

    await _repairRealtimeSubscription?.cancel();
    _repairRealtimeSubscription = null;
    _receivedServerSnapshot = false;

    // Reset SQLite pagination when switching shops
    final isNewShop = shopId != _listeningShopId;
    _listeningShopId = shopId;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _isRealtimeConnected = false;
        if (isNewShop) {
          _sqliteRepairs = [];
          _sqliteLoadedCount = 0;
          _hasMoreData = false;
          _isLoadingMore = false;
        }
      });
    }
    if (isNewShop) unawaited(_initFromSQLite());

    if (_useRealtimeIndexFallback) {
      // Fallback mode: avoid limit so newly-created orders are not missed.
      // We sort/filter on client side after snapshot is received.
      debugPrint(
        'ℹ️ [OrderListView] Realtime fallback mode active (no orderBy/limit) due missing index',
      );
    }

    _repairRealtimeSubscription =
        FirestoreService.watchRepairsByShop(
          shopId,
          useIndexedQuery: !_useRealtimeIndexFallback,
          indexedLimit: _indexedFetchLimit,
          // Chỉ live-listen đơn CHƯA giao — đơn đã giao (phần lớn dữ liệu)
          // đã được backfill sẵn vào SQLite (_doHistoricalBackfill) và phục vụ
          // qua _sqliteRepairs/sqliteExtra merge bên dưới, giảm mạnh số document
          // Firestore phải đọc lại mỗi khi có thay đổi mà vẫn giữ realtime cho
          // các đơn đang xử lý.
          activeOnly: true,
        ).listen(
          (snapshot) {
            unawaited(_handleRealtimeSnapshot(snapshot));
          },
          onError: (error) {
            debugPrint('❌ [OrderListView] Realtime listener lỗi: $error');

            final errorText = error.toString().toLowerCase();
            final isMissingIndex =
                (error is FirebaseException &&
                    error.code == 'failed-precondition') ||
                errorText.contains('requires an index');

            if (isMissingIndex && !_useRealtimeIndexFallback) {
              debugPrint(
                '⚠️ [OrderListView] Thiếu index cho query realtime, chuyển sang fallback không orderBy(updatedAt)',
              );
              _useRealtimeIndexFallback = true;
              unawaited(_startRealtimeRepairsListener(forceRestart: true));
              return;
            }

            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _isRealtimeConnected = false;
            });

            unawaited(_showPendingLocalRepairsWhileWaitingRealtime());
          },
        );

    unawaited(_showPendingLocalRepairsWhileWaitingRealtime());
  }

  int _parseTimestampSafe(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  int _extractCloudRepairTimeMs(Map<String, dynamic> cloudData) {
    final updatedAt = _parseTimestampSafe(cloudData['updatedAt']);
    if (updatedAt > 0) return updatedAt;

    final lastCaredAt = _parseTimestampSafe(cloudData['lastCaredAt']);
    if (lastCaredAt > 0) return lastCaredAt;

    final deliveredAt = _parseTimestampSafe(cloudData['deliveredAt']);
    if (deliveredAt > 0) return deliveredAt;

    final finishedAt = _parseTimestampSafe(cloudData['finishedAt']);
    if (finishedAt > 0) return finishedAt;

    return _parseTimestampSafe(cloudData['createdAt']);
  }

  Map<String, dynamic>? _decodeRepairDocPayload(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    try {
      final data = doc.data();
      if (data == null) return null;

      final raw = Map<String, dynamic>.from(data);
      final decrypted = EncryptionService.decryptMap(raw);
      if (decrypted['deleted'] == true) return null;

      SyncService.convertTimestampFieldsPublic(decrypted);
      decrypted['firestoreId'] = doc.id;
      decrypted['isSynced'] = 1;
      return decrypted;
    } catch (e) {
      debugPrint('⚠️ [OrderListView] Decode repair ${doc.id} lỗi: $e');
      return null;
    }
  }

  Repair? _parseRepairDoc(Map<String, dynamic> payload, String docId) {
    try {
      return Repair.fromMap(payload);
    } catch (e) {
      debugPrint('⚠️ [OrderListView] Parse repair $docId lỗi: $e');
      return null;
    }
  }

  /// Đơn vừa bị loại khỏi kết quả realtime (activeOnly: status<4) — refetch
  /// 1 lần để lưu đúng trạng thái mới nhất (VD "Đã giao") vào SQLite, tránh
  /// hiển thị lại trạng thái active cũ khi rơi về nguồn dữ liệu sqliteExtra.
  Future<void> _refreshRemovedRepairFromCloud(String firestoreId) async {
    try {
      final doc = await FirestoreService.getRepairDoc(firestoreId);
      if (!doc.exists) return;
      final payload = _decodeRepairDocPayload(doc);
      if (payload == null) return;
      final repair = _parseRepairDoc(payload, firestoreId);
      if (repair == null) return;
      await db.upsertRepair(repair);
    } catch (e) {
      debugPrint(
        '⚠️ [OrderListView] Refresh removed repair $firestoreId lỗi: $e',
      );
    }
  }

  Future<Repair?> _preferUnsyncedLocalRepair(
    String firestoreId,
    Map<String, dynamic> cloudData,
  ) async {
    final localRepair = await db.getRepairByFirestoreId(firestoreId);
    if (localRepair == null || localRepair.isSynced) {
      return null;
    }

    final localTime = localRepair.lastCaredAt ?? localRepair.createdAt;
    final cloudTime = _extractCloudRepairTimeMs(cloudData);

    // Nếu cloud không rõ ràng mới hơn local, giữ local unsynced để tránh mất
    // dữ liệu tài chính vừa sửa (price/cost bị bật về 0 từ cloud stale).
    const toleranceMs = 5000;
    final cloudClearlyNewer =
        cloudTime > 0 && cloudTime > localTime + toleranceMs;

    if (!cloudClearlyNewer) {
      debugPrint(
        '🛡️ [OrderListView] Keep local unsynced repair $firestoreId (local: $localTime, cloud: $cloudTime)',
      );
      return localRepair;
    }

    return null;
  }

  Future<void> _showPendingLocalRepairsWhileWaitingRealtime() async {
    unawaited(_refreshFromSQLite());
  }

  /// Load first page from SQLite — called on init or shop change.
  Future<void> _initFromSQLite() async {
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

  /// One-time backfill: fetch ALL repairs from Firestore (no orderBy → includes
  /// old docs without updatedAt field) and insert to SQLite so pagination works.
  /// Uses INSERT OR IGNORE — never overwrites unsynced local repairs.
  Future<void> _doHistoricalBackfill() async {
    final shopId = (_listeningShopId ?? '').trim();
    if (shopId.isEmpty || _backfilledShops.contains(shopId)) return;
    _backfilledShops.add(shopId);

    try {
      debugPrint('[OrderListView] Historical backfill start — shopId=$shopId');
      final docs = await FirestoreService.fetchAllRepairsByShop(shopId);
      debugPrint(
        '[OrderListView] Backfill: Firestore returned ${docs.length} docs',
      );

      if (docs.isEmpty) {
        if (mounted) unawaited(_refreshFromSQLite());
        return;
      }

      // Build repair list — decode once, reuse for both display and DB insert
      final repairs = <Repair>[];
      for (final doc in docs) {
        final payload = _decodeRepairDocPayload(doc);
        if (payload == null) continue;
        final repair = _parseRepairDoc(payload, doc.id);
        if (repair == null) continue;
        repairs.add(repair);
      }

      // Fast bulk insert — single schema check, batched transactions,
      // INSERT OR IGNORE protects unsynced local repairs from being overwritten
      final inserted = await db.bulkInsertRepairsIfNew(repairs);
      debugPrint(
        '[OrderListView] Backfill done: $inserted new repairs inserted (${docs.length} processed)',
      );

      if (!mounted) return;
      // Refresh display — SQLite now contains full history
      unawaited(_refreshFromSQLite());
    } catch (e) {
      debugPrint('⚠️ [OrderListView] Historical backfill lỗi: $e');
      _backfilledShops.remove(shopId); // Allow retry on next snapshot
    }
  }

  Future<void> _handleRealtimeSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    if (snapshot.metadata.isFromCache && _receivedServerSnapshot) {
      return;
    }

    if (!snapshot.metadata.isFromCache) {
      _receivedServerSnapshot = true;
      // Trigger one-time historical backfill on first real server snapshot
      unawaited(_doHistoricalBackfill());
    }

    final upsertFutures = <Future<void>>[];

    if (_repairsByFirestoreId.isEmpty &&
        snapshot.docChanges.length == snapshot.docs.length) {
      _repairsByFirestoreId.clear();
      for (final doc in snapshot.docs) {
        final payload = _decodeRepairDocPayload(doc);
        if (payload == null) continue;

        final preferredLocal = await _preferUnsyncedLocalRepair(
          doc.id,
          payload,
        );
        if (preferredLocal != null) {
          _repairsByFirestoreId[doc.id] = preferredLocal;
          continue;
        }

        final repair = _parseRepairDoc(payload, doc.id);
        if (repair == null) continue;

        _repairsByFirestoreId[doc.id] = repair;
        upsertFutures.add(db.upsertRepair(repair));
      }
    } else {
      for (final change in snapshot.docChanges) {
        final id = change.doc.id;
        if (change.type == DocumentChangeType.removed) {
          _repairsByFirestoreId.remove(id);
          // Đơn vừa rời khỏi cửa sổ theo dõi realtime (activeOnly: status<4)
          // — thường do trạng thái vừa chuyển sang "Đã giao" ở THIẾT BỊ
          // KHÁC. Nếu không làm gì thêm, bản ghi SQLite cũ (còn status active
          // trước đó, VD "Sửa xong") sẽ tiếp tục hiển thị qua nguồn
          // sqliteExtra — sai lệch với trạng thái thật trên cloud. Refetch 1
          // lần để cập nhật đúng trạng thái mới nhất vào SQLite.
          upsertFutures.add(_refreshRemovedRepairFromCloud(id));
          continue;
        }

        final payload = _decodeRepairDocPayload(change.doc);
        if (payload == null) {
          _repairsByFirestoreId.remove(id);
          continue;
        }

        final preferredLocal = await _preferUnsyncedLocalRepair(id, payload);
        if (preferredLocal != null) {
          _repairsByFirestoreId[id] = preferredLocal;
          continue;
        }

        final repair = _parseRepairDoc(payload, id);
        if (repair == null) continue;

        _repairsByFirestoreId[id] = repair;
        upsertFutures.add(db.upsertRepair(repair));
      }
    }

    if (upsertFutures.isNotEmpty) {
      await Future.wait(upsertFutures);
    }

    if (!mounted) return;

    // Reload display from SQLite — catches ALL history, not just Firestore window.
    // This also covers newly-upserted docs and local unsynced repairs.
    unawaited(_refreshFromSQLite());
  }

  /// Pool hợp nhất realtime cache + SQLite historical (dedup theo firestoreId)
  /// — nguồn dữ liệu duy nhất cho mọi tính toán hiển thị (thống kê, chip count).
  /// Không thêm bất kỳ read/listener Firestore nào.
  List<Repair> get _allRepairs {
    final firestoreIds = _repairsByFirestoreId.keys.toSet();
    final sqliteExtra = _sqliteRepairs.where((r) {
      final fid = (r.firestoreId ?? '').trim();
      return fid.isNotEmpty && !firestoreIds.contains(fid);
    }).toList();
    return [..._repairsByFirestoreId.values, ...sqliteExtra];
  }

  void _rebuildDisplayedRepairs({bool markLoaded = false}) {
    // Merge Firestore realtime cache + SQLite historical data (deduped by firestoreId).
    // Firestore values win for items in both sources.
    final all = _allRepairs..sort(_compareRepairs);
    debugPrint(
      '[OrderListView] Firestore count: ${_repairsByFirestoreId.length}',
    );
    debugPrint(
      '[OrderListView] SQLite count: ${_sqliteRepairs.length} (extra not in Firestore: ${_allRepairs.length - _repairsByFirestoreId.length})',
    );
    debugPrint(
      '[OrderListView] HasMore: $_hasMoreData | sqliteLoadedCount: $_sqliteLoadedCount',
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
      _isLoadingMoreRealtime = false;
      if (markLoaded || _isLoading || !_isRealtimeConnected) {
        _isLoading = false;
        _isRealtimeConnected = true;
      }
    });
  }

  void _removeRepairFromRealtimeCache(String? firestoreId) {
    final id = (firestoreId ?? '').trim();
    if (id.isEmpty) return;
    _repairsByFirestoreId.remove(id);
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
    // Debounce 300ms then search all local SQLite (bypasses Firestore limit)
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final keyword = val.trim();
      if (keyword.isEmpty || !mounted) return;
      final normalized = VietnameseUtils.normalize(keyword);
      if (mounted) setState(() => _isSearchingLocal = true);
      try {
        final results = await db.searchRepairs(keyword, normalized, limit: 200);
        if (!mounted || _currentSearch != val) return;
        setState(() {
          _displayedRepairs = results;
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
        await FirebaseFirestore.instance
            .collection('repairs')
            .doc(r.firestoreId)
            .update(encData);
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

      _rebuildDisplayedRepairs();
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
              TextField(
                controller: passCtrl,
                obscureText: true,
                enabled: !submitting,
                decoration: const InputDecoration(
                  hintText: "Nhập mật khẩu quản lý để xác nhận",
                  border: OutlineInputBorder(),
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return false;

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);

      // === HOÀN TRẢ PHỤ TÙNG VỀ KHO ===
      if (r.partsUsed.isNotEmpty) {
        await _restorePartsToInventory(r.partsUsed);
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
        userId: user.uid,
        userName: user.email?.split('@').first.toUpperCase() ?? 'NV',
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
      // Realtime listener sẽ tự đồng xóa local khi nhận deleted=true từ Firestore
      debugPrint(
        '✅ Repair deleted directly on Firestore - no need for sync queue',
      );

      _removeRepairFromRealtimeCache(repairFirestoreId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Hoàn trả phụ tùng về kho
  /// Format partsUsed: "Part1 x1, Part2 x2, ..."
  Future<void> _restorePartsToInventory(String partsUsed) async {
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

      // Tìm part trong kho và cộng số lượng
      await db.restorePartQuantityByName(partName, quantity);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mọi thống kê đều tính từ pool hiển thị thật (không thêm read Firestore).
    final pool = _allRepairs;
    final totalCount = pool.length;

    // Layout rộng (web / tablet / màn xoay ngang): header gọn + 2 cột đơn.
    final Size size = MediaQuery.sizeOf(context);
    final bool useGrid = size.width >= 900 ||
        (size.width > size.height && size.width >= 700);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: CustomAppBar.build(
        guideKey: FirstTimeGuideService.keyOrderList,
        title: "DANH SÁCH ĐƠN SỬA",
        subtitle: '$totalCount đơn',
        actions: [
          IconButton(
            onPressed: () => FirstTimeGuideService.reopenGuide(
              context,
              FirstTimeGuideService.keyOrderList,
            ),
            icon: const Icon(Icons.help_outline_rounded,
                color: Colors.white),
            tooltip: 'Hướng dẫn sử dụng',
          ),
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
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                    child: _buildSearchField(),
                  ),
            _buildStatusFilterChips(pool: pool),
            if (!useGrid)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SyncStatusBar(
                        isOnline: ConnectivityService.instance.isOnline,
                        isRealtimeConnected: _isRealtimeConnected,
                        itemCount: pool.length,
                        itemLabel: 'đơn',
                        modeDetail:
                            _useRealtimeIndexFallback ? 'fallback' : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildSyncButton(),
                    const SizedBox(width: 6),
                    _buildSortSelector(),
                  ],
                ),
              ),
            if (!ConnectivityService.instance.isOnline)
              _buildSyncBanner(
                icon: Icons.cloud_off_rounded,
                text: 'Ngoại tuyến — đang xem dữ liệu đã lưu',
              )
            else if (!_isRealtimeConnected &&
                _receivedServerSnapshot &&
                !_isLoading &&
                !_isSearchingLocal)
              _buildSyncBanner(
                icon: Icons.sync_problem_rounded,
                text: 'Không thể đồng bộ',
                onRetry: () =>
                    _startRealtimeRepairsListener(forceRestart: true),
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
        icon: Icons.add_rounded,
        label: 'Tạo đơn sửa',
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
              isRealtimeConnected: _isRealtimeConnected,
              itemCount: pool.length,
              itemLabel: 'đơn',
              modeDetail: _useRealtimeIndexFallback ? 'fallback' : null,
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
    final int allCount = pool.length;
    final int receivedCount = pool.where((r) => r.status == 1).length;
    final int repairingCount = pool.where((r) => r.status == 2).length;
    final int doneCount = pool.where((r) => r.status == 3 && !r.pendingDeliveryApproval).length;
    final int pendingCount = pool.where((r) => r.status == 3 && r.pendingDeliveryApproval).length;
    final int deliveredCount = pool.where((r) => r.status == 4).length;
    final int overdueCount = pool.where(_isOverdue).length;

    bool isAllSelected = _statusFilters.isEmpty && !_filterPendingApproval && !_filterOverdue;
    bool isPending = _filterPendingApproval;

    return SizedBox(
      height: 52,
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
          _filterChipItem('Đang sửa', repairingCount, AppColors.repairRepairing, _statusFilters.contains(2) && !isPending && !_filterOverdue, () {
            setState(() {
              if (_statusFilters.contains(2)) {
                _statusFilters.remove(2);
              } else {
                _statusFilters.add(2);
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : Colors.grey.shade300, width: 1.2),
            boxShadow: selected
                ? [BoxShadow(color: color.withValues(alpha:0.2), blurRadius: 4, offset: const Offset(0,2))]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check_circle_rounded, size: 13, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: selected ? Colors.white.withValues(alpha:0.25) : color.withValues(alpha:0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: selected ? Colors.white : color)),
            ),
          ],
        ),
      ),
      ),
    );
  }

  /// Bộ chọn kiểu sắp xếp (thuần UI — logic sort nằm ở _compareRepairs).
  Widget _buildSortSelector() {
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              'Sắp xếp: ${_sortLabel(_sortMode)}',
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

  /// Mã đơn — dùng cùng công thức với RepairDetailView (firestoreId ?? id)
  /// để hiển thị nhất quán trên list, detail và phiếu.
  String _orderCode(Repair r) {
    final id = r.firestoreId ?? (r.id != null ? r.id.toString() : '');
    return '#$id';
  }

  /// Thumbnail ảnh đơn sửa (reused: có thể tách file nếu sau này cần).
  Widget _buildRepairThumbnail(List<String> images, String firstImage, Color borderColor, int index, {bool showIndexBadge = true}) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              image: firstImage.isNotEmpty &&
                      !_isGsStoragePath(firstImage) &&
                      !_isStorageRelativePath(firstImage) &&
                      ((firstImage.startsWith('http') || firstImage.startsWith('blob:') || firstImage.startsWith('data:')) || !kIsWeb)
                  ? DecorationImage(
                      image: (firstImage.startsWith('http') || firstImage.startsWith('blob:') || firstImage.startsWith('data:'))
                          ? CachedNetworkImageProvider(firstImage)
                          : FileImage(File(firstImage)) as ImageProvider,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: firstImage.isEmpty
                ? Icon(Icons.phone_android_rounded, color: Colors.grey.shade400, size: 26)
                : (_isGsStoragePath(firstImage) || _isStorageRelativePath(firstImage))
                    ? FutureBuilder<String?>(
                        future: _resolveDisplayImagePath(firstImage),
                        builder: (context, snap) {
                          final url = snap.data;
                          if (url == null || url.isEmpty) return Icon(Icons.broken_image_rounded, color: Colors.grey.shade400, size: 22);
                          return ClipRRect(borderRadius: BorderRadius.circular(10), child: AppCachedImage(imageUrl: url, fit: BoxFit.cover, memCacheWidth: 104, memCacheHeight: 104));
                        },
                      )
                    : null,
          ),
          // STT badge overlay top-left
          if (showIndexBadge)
            Positioned(
            top: -5,
            left: -5,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(6), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)]),
              child: Center(child: Text('$index', style: AppTextStyles.overline.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0))),
            ),
          ),
          // "+N" photo count badge bottom-right
          if (images.length > 1)
            Positioned(
              bottom: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                child: Text('+${images.length - 1}', style: AppTextStyles.overline.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRepairCard(Repair r, int index) {
    final List<String> images = _collectRepairImages(r);
    final String firstImage = _pickBestPreviewImage(images);
    final int displayPrice = _displayedChargePrice(r);
    final bool hasRequestedCharge =
        r.pendingDeliveryApproval && r.requestedDeliveryPrice != null;

    final bool overdue = _isOverdue(r);
    final Color statusColor = overdue
        ? Colors.red.shade700
        : _getStatusColor(r.status, pendingApproval: r.pendingDeliveryApproval);

    // Chip thông tin phụ — chỉ hiện tối đa 3 để card compact, phần dư gom +N.
    final List<Widget> chips = <Widget>[];

    // Phụ tùng đã dùng
    if (r.partsUsed.isNotEmpty) {
      chips.add(_repairInfoChip(
        '🔩 ${r.partsUsed}',
        Colors.cyan.shade50,
        textColor: Colors.cyan.shade800,
        fontWeight: FontWeight.w600,
      ));
    }
    // Dịch vụ đã dùng
    if (r.services.isNotEmpty) {
      chips.add(_repairInfoChip(
        '🛠️ ${r.services.map((s) => s.serviceName).join(', ')}',
        Colors.teal.shade50,
        textColor: Colors.teal.shade800,
        fontWeight: FontWeight.w600,
      ));
    }

    const int chipCap = 3;
    final List<Widget> visibleChips = chips.take(chipCap).toList();
    final int hiddenChips = chips.length - visibleChips.length;
    if (hiddenChips > 0) {
      visibleChips.add(_repairInfoChip(
        '+$hiddenChips',
        Colors.grey.shade200,
        textColor: Colors.grey.shade700,
        fontWeight: FontWeight.bold,
      ));
    }

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
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_forever, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async {
        _confirmDelete(r);
        return false;
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: overdue ? Colors.red.shade200 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vạch trạng thái bên trái; đỏ đậm khi quá hạn (cảnh báo, không
            // tô đỏ toàn card).
            Container(
              width: overdue ? 6 : 4,
              color: overdue
                  ? Colors.red.shade600
                  : statusColor.withValues(alpha: 0.55),
            ),
            Expanded(
              child: InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RepairDetailView(repair: r),
                    ),
                  );
                  if (!mounted) return;
                  // Dùng firestoreId (không dùng r.id cục bộ — đơn đang xử lý
                  // dựng từ Firestore realtime thường chưa có r.id). Đơn ĐÃ
                  // GIAO thì bỏ khỏi cache active để rơi về nguồn SQLite.
                  final fid = (r.firestoreId ?? '').trim();
                  if (fid.isNotEmpty) {
                    final fresh = await db.getRepairByFirestoreId(fid);
                    if (fresh != null) {
                      if (fresh.status >= 4) {
                        _repairsByFirestoreId.remove(fid);
                      } else {
                        _repairsByFirestoreId[fid] = fresh;
                      }
                      _rebuildDisplayedRepairs();
                    }
                  }
                  unawaited(_refreshFromSQLite());
                },
                onLongPress: () {
                  if (!canDelete) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Chỉ quản lý/chủ shop mới có quyền xóa đơn',
                        ),
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
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Row 1: STT + Status badge + Time + Code + chevron ──
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$index',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStatusIcon(
                                    r.status,
                                    pendingApproval:
                                        r.pendingDeliveryApproval,
                                  ),
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getStatusLabel(
                                    r.status,
                                    pendingApproval:
                                        r.pendingDeliveryApproval,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              overdue
                                  ? '⏰ Quá hạn ${_daysStuck(r)} ngày'
                                  : '⏱ ${_timeLabel(r)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: overdue
                                    ? Colors.red.shade700
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              _orderCode(r),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9AA5B1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // ── Row 2: Thumbnail + Model + Issue + Customer + Price ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRepairThumbnail(
                            images,
                            firstImage,
                            statusColor,
                            index,
                            showIndexBadge: false,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.model,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.headline5.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                if (r.issue.trim().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    r.issue.replaceAll('|', ' ').trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person_outline_rounded,
                                      size: 13,
                                      color: Color(0xFF78909C),
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: r.customerName.trim().isNotEmpty
                                          ? Text(
                                              r.customerName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  AppTextStyles.body2.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.onSurface,
                                                fontSize: 12,
                                              ),
                                            )
                                          : GestureDetector(
                                              onTap: () =>
                                                  _addCustomerToRepair(r),
                                              child: Text(
                                                'Thêm khách hàng',
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style:
                                                    AppTextStyles.body2
                                                        .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors
                                                      .orange.shade800,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                    ),
                                    if (r.phone.trim().isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.phone_outlined,
                                        size: 11,
                                        color: Colors.blueGrey,
                                      ),
                                      const SizedBox(width: 2),
                                      Flexible(
                                        child: Text(
                                          r.phone,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.body2
                                              .copyWith(
                                            color:
                                                AppColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (displayPrice > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              hasRequestedCharge
                                  ? 'YC ${MoneyUtils.formatCompactCurrency(displayPrice)}đ'
                                  : '${MoneyUtils.formatCompactCurrency(displayPrice)}đ',
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0068FF),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (visibleChips.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: visibleChips,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  List<String> _collectRepairImages(Repair r) {
    final result = <String>[];

    void addCandidate(String? value) {
      if (value == null) return;
      var s = value.trim();
      if (s.isEmpty) return;
      if ((s.startsWith('"') && s.endsWith('"')) ||
          (s.startsWith("'") && s.endsWith("'"))) {
        s = s.substring(1, s.length - 1).trim();
      }
      if (s.startsWith('[') && s.endsWith(']')) {
        s = s.substring(1, s.length - 1).trim();
      }
      if (s.isEmpty) return;
      if (!result.contains(s)) {
        result.add(s);
      }
    }

    for (final image in r.receiveImages) {
      addCandidate(image);
    }

    final raw = (r.imagePath ?? '').trim();
    if (raw.isNotEmpty) {
      final parts = raw
          .split(RegExp(r'[,;\n]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      for (final part in parts) {
        addCandidate(part);
      }
    }

    return result.where((path) {
      if (StorageService.isResolvableDisplayPath(path)) return true;
      return !kIsWeb;
    }).toList();
  }

  String _pickBestPreviewImage(List<String> images) {
    if (images.isEmpty) return '';

    for (final image in images) {
      if (_isWebPreviewSource(image)) {
        return image;
      }
    }

    if (kIsWeb) {
      // On web, local file paths cannot be rendered across sessions/devices.
      return '';
    }

    return images.first;
  }

  bool _isWebPreviewSource(String path) {
    final lower = path.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('gs://') ||
        lower.startsWith('repairs/') ||
        lower.startsWith('/repairs/') ||
        lower.startsWith('blob:') ||
        lower.startsWith('data:');
  }

  Widget _repairInfoChip(
    String text,
    Color color, {
    Color textColor = Colors.black,
    FontWeight fontWeight = FontWeight.w500,
    int maxLines = 1,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: (MediaQuery.sizeOf(context).width - 100).clamp(
          0,
          400,
        ), // Prevent overflow
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: AppTextStyles.caption.copyWith(
            color: textColor,
            fontWeight: fontWeight,
          ),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
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

  IconData _getStatusIcon(int status, {bool pendingApproval = false}) {
    if (status == 1) return Icons.download_rounded;
    if (status == 2) return Icons.build_rounded;
    if (status == 3) {
      return pendingApproval ? Icons.block_rounded : Icons.check_circle_rounded;
    }
    if (status == 4) return Icons.local_shipping_rounded;
    return Icons.help_outline_rounded;
  }
}
