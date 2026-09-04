import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_write_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';
import '../models/expense_model.dart';
import '../models/debt_model.dart';
import '../models/attendance_model.dart';
import '../models/leave_request_model.dart';
import '../models/quick_input_code_model.dart';
import 'storage_service.dart';
import 'product_image_service.dart';
import 'payment_intent_service.dart';
import 'user_service.dart';
import 'encryption_service.dart';
import 'sync_orchestrator.dart';
import 'event_bus.dart';
import 'claims_service.dart';
import 'shop_deletion_service.dart';
import 'firebase_usage_stats_service.dart';
import 'connectivity_service.dart';
import '../utils/perf_monitor.dart';

class SyncService {
  static final _db = FirebaseFirestore.instance;
  static final List<StreamSubscription> _subscriptions = [];
  static final List<Timer> _pollingTimers = [];
  static final Map<String, Future<void> Function()> _collectionRefreshers = {};
  static final Map<String, int> _collectionFetchCounts = {};
  static bool _isRefreshingCollections = false;
  static DateTime? _lastRefreshCollectionsAt;
  static bool _isReinitializingAfterAccessChange = false;
  static DateTime? _lastAccessChangeReinitAt;
  static const Duration _accessChangeReinitCooldown = Duration(seconds: 20);
  static String? _lastUserPermissionSignature;
  static String? _lastShopRestrictionSignature;

  // Track active subscriptions and their status for debugging
  static final Map<String, bool> _subscriptionStatus = {};
  static VoidCallback? _onDataChangedCallback;
  static String? _currentShopId;
  static bool _isInitialized = false;

  static bool _hasPermission(Map<String, dynamic> permissions, String key) {
    return permissions[key] == true;
  }

  static String _normalizeSignatureValue(dynamic value) {
    if (value is List) {
      return value.map(_normalizeSignatureValue).join(',');
    }
    return value?.toString() ?? '';
  }

  static String _buildUserPermissionSignature(Map<String, dynamic> data) {
    const keys = [
      'role',
      'shopId',
      'allowViewSales',
      'allowViewRepairs',
      'allowViewInventory',
      'allowViewParts',
      'allowViewSuppliers',
      'allowViewCustomers',
      'allowViewPurchaseOrders',
      'allowCreatePurchaseOrders',
      'allowViewWarranty',
      'allowViewChat',
      'allowSendChat',
      'allowPinChat',
      'allowDeleteOtherChat',
      'allowCloudAI',
      'allowViewAttendance',
      'allowViewPrinter',
      'allowViewRevenue',
      'allowViewExpenses',
      'allowViewDebts',
      'allowViewCostPrice',
      'allowViewSettings',
      'allowManageStaff',
    ];

    return keys
        .map((key) => '$key=${_normalizeSignatureValue(data[key])}')
        .join('|');
  }

  static String _buildShopRestrictionSignature(Map<String, dynamic> data) {
    const keys = [
      'appLocked',
      'adminFinanceLocked',
      'staffSalesLocked',
      'staffInventoryLocked',
      'staffDebtLocked',
      'staffSettingsLocked',
    ];

    return keys
        .map((key) => '$key=${_normalizeSignatureValue(data[key])}')
        .join('|');
  }

  static Future<void> _refreshSyncAfterAccessChange(String reason) async {
    if (_isReinitializingAfterAccessChange) {
      return;
    }
    if (_isInitializingRealtime) {
      debugPrint('⏭️ $reason: sync init đang chạy, bỏ qua reinit');
      return;
    }
    if (!_isInitialized) {
      debugPrint('⏭️ $reason: sync chưa sẵn sàng, bỏ qua reinit');
      return;
    }

    final now = DateTime.now();
    if (_lastAccessChangeReinitAt != null &&
        now.difference(_lastAccessChangeReinitAt!) <
            _accessChangeReinitCooldown) {
      debugPrint('⏭️ $reason: access-change reinit cooldown active, bỏ qua');
      return;
    }

    _isReinitializingAfterAccessChange = true;
    try {
      _lastAccessChangeReinitAt = now;
      debugPrint('🔄 Refreshing sync scope after $reason...');
      await forceReinitializeSync();
    } finally {
      _isReinitializingAfterAccessChange = false;
    }
  }

  static bool _isManagerLike(String role, bool isSuperAdmin) {
    return isSuperAdmin ||
        role == 'admin' ||
        role == 'owner' ||
        role == 'manager';
  }

  static bool _isStaffLike(String role, bool isSuperAdmin) {
    return _isManagerLike(role, isSuperAdmin) ||
        role == 'employee' ||
        role == 'technician';
  }

  static bool _canSubscribeCollection({
    required String collection,
    required Map<String, dynamic> permissions,
    required String role,
    required bool isSuperAdmin,
  }) {
    if (isSuperAdmin) return true;

    switch (collection) {
      case 'repairs':
      case 'repair_parts':
      case 'repair_partners':
      case 'partner_repair_history':
      case 'salvage_phones':
        return _hasPermission(permissions, 'allowViewRepairs');
      case 'sales':
      case 'customers':
      case 'payment_requests':
      case 'sales_returns':
      case 'sales_return_items':
        return _hasPermission(permissions, 'allowViewSales');
      case 'storage_locations':
        return true; // visible to all roles — used for repair/product location assignment
      case 'products':
      case 'product_variants':
      case 'quick_input_codes':
      case 'supplier_import_history':
      case 'supplier_product_prices':
      case 'import_orders':
      case 'import_order_items':
        return _hasPermission(permissions, 'allowViewInventory');
      case 'suppliers':
        return _hasPermission(permissions, 'allowViewSuppliers');
      // Danh mục giá từ hoá đơn NCC: nhân viên VẪN cần tải về để tra Giá thu
      // khách khi báo giá. Giá vốn nằm cùng bản ghi nhưng bị che ở tầng
      // service/UI (PriceCatalogService.canViewCost) — quyền xem giá vốn KHÔNG
      // dùng để chặn sync, nếu chặn thì nhân viên mất luôn giá báo khách.
      case 'price_catalog_items':
        return true;
      case 'expenses':
        return _hasPermission(permissions, 'allowViewExpenses') &&
            _isManagerLike(role, isSuperAdmin);
      case 'debts':
        return _hasPermission(permissions, 'allowViewDebts') ||
            _hasPermission(permissions, 'allowViewSales');
      case 'debt_payments':
      case 'payment_intents':
        return _isStaffLike(role, isSuperAdmin);
      case 'attendance':
      case 'leave_requests':
      case 'audit_logs':
      case 'supplier_payments':
      case 'repair_partner_payments':
      case 'cash_closings':
      case 'adjustment_entries':
      case 'purchase_orders':
      case 'employee_salary_settings':
        return _isManagerLike(role, isSuperAdmin);
      case 'work_schedules':
        return _hasPermission(permissions, 'allowViewAttendance');
      default:
        return true;
    }
  }

  static Future<List<String>> filterCollectionsForCurrentUser(
    Iterable<String> collections,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const [];

    final isSuperAdmin = UserService.isCurrentUserSuperAdmin();
    if (isSuperAdmin) {
      return collections.toList();
    }

    final permissions = await UserService.getCurrentUserPermissions();
    final role = await UserService.getUserRole(currentUser.uid);

    return collections.where((collection) {
      return _canSubscribeCollection(
        collection: collection,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
      );
    }).toList();
  }

  static bool _canSubscribeShopSubcollection({
    required String subcollection,
    required Map<String, dynamic> permissions,
    required String role,
    required bool isSuperAdmin,
  }) {
    if (isSuperAdmin) return true;

    switch (subcollection) {
      case 'product_categories':
        return _hasPermission(permissions, 'allowViewInventory');
      case 'settings':
        return _isManagerLike(role, isSuperAdmin) ||
            _hasPermission(permissions, 'allowViewSettings');
      default:
        return true;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DOWNLOAD THROTTLING: Prevent cascade calls to downloadAllFromCloud
  // ═══════════════════════════════════════════════════════════════════════
  static DateTime? _lastDownloadTime;
  static bool _isDownloading = false;
  static bool _isInitializingRealtime = false;
  static String? _lastRealtimeInitSignature;
  static const _downloadCooldown = Duration(seconds: 60);
  static bool _isSyncingAllToCloud = false;
  static DateTime? _lastSyncAllToCloudAt;
  static const _syncAllToCloudCooldown = Duration(seconds: 12);
  static const int _collectionPollLimit = 20;
  static const Duration _collectionRefreshCooldown = Duration(seconds: 120);
  // Nhịp nền chỉ bắt kịp riêng "repairs" — collection duy nhất user báo bị
  // trễ (đơn mới/đổi trạng thái ở máy khác không thấy tới khi thoát app vào
  // lại). Cố tình KHÔNG áp dụng cho tất cả ~20 collection đang polling để
  // tránh đội read cost trở lại đúng thứ đợt tối ưu trước đã giảm.
  static const Duration _periodicRepairsRefreshInterval = Duration(seconds: 45);
  static const Duration _cloudReadTimeout = Duration(seconds: 20);
  static const Duration _cloudReadLogCooldown = Duration(seconds: 15);
  static DateTime? _lastCloudReadTimeoutLogAt;

  /// Key prefix for storing last sync timestamps per collection in SharedPreferences
  static const _lastSyncPrefix = 'lastSync_';
  static const _realtimeCursorPrefix = 'rtCursor_';
  static const Set<String> _incrementalRealtimeCollections = {
    'attendance',
    'audit_logs',
    'cash_closings',
    'customers',
    'debts',
    'debt_payments',
    'expenses',
    'import_order_items',
    'import_orders',
    'payment_intents',
    'payment_requests',
    'products',
    'quick_input_codes',
    'repair_parts',
    'repair_partner_payments',
    'repairs',
    'sales',
    'sales_return_items',
    'sales_returns',
    'salvage_phones',
    'supplier_import_history',
    'suppliers',
    'price_catalog_items',
    'purchase_orders',
    'product_categories',
    'supplier_payments',
    // storage_locations intentionally excluded: small dataset, always full-fetch to avoid
    // requiring a composite (shopId, updatedAt) Firestore index that is hard to deploy.
  };
  static final Map<String, int> _realtimeCursorCache = <String, int>{};
  static final Set<String> _incrementalRealtimeDisabled = <String>{};

  /// Check if real-time sync is initialized and active
  static bool get isRealTimeSyncActive =>
      _isInitialized && _subscriptions.isNotEmpty;

  /// Check if real-time sync setup is currently running.
  static bool get isRealtimeInitializationInProgress => _isInitializingRealtime;

  /// Get subscription status for debugging
  static Map<String, bool> get subscriptionStatus =>
      Map.unmodifiable(_subscriptionStatus);

  static void _logCollectionFetch({
    required String collection,
    required String reason,
  }) {
    final next = (_collectionFetchCounts[collection] ?? 0) + 1;
    _collectionFetchCounts[collection] = next;
    debugPrint(
      '[SYNC][FETCH] collection=$collection count=$next reason=$reason limit=$_collectionPollLimit',
    );
  }

  static bool _shouldLogCloudReadTimeout() {
    final now = DateTime.now();
    if (_lastCloudReadTimeoutLogAt == null ||
        now.difference(_lastCloudReadTimeoutLogAt!) >= _cloudReadLogCooldown) {
      _lastCloudReadTimeoutLogAt = now;
      return true;
    }
    return false;
  }

  static String _buildRealtimeInitSignature({
    required String uid,
    required String? shopId,
    required String role,
    required bool isSuperAdmin,
    required Map<String, dynamic> permissions,
  }) {
    final permissionBits =
        permissions.entries
            .map((entry) => '${entry.key}=${entry.value}')
            .toList()
          ..sort();
    return [
      uid,
      shopId ?? '',
      role.toLowerCase(),
      isSuperAdmin ? '1' : '0',
      permissionBits.join('|'),
    ].join('::');
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> _getQueryWithTimeout({
    required Query<Map<String, dynamic>> query,
    required String context,
    int? limit,
  }) async {
    final effectiveQuery = limit != null ? query.limit(limit) : query;
    try {
      return await effectiveQuery.get().timeout(_cloudReadTimeout);
    } on TimeoutException {
      if (_shouldLogCloudReadTimeout()) {
        debugPrint(
          '⏱️ Cloud read timeout in $context after ${_cloudReadTimeout.inSeconds}s',
        );
      }
      rethrow;
    }
  }

  /// Trigger one-shot cloud fetch for active collections.
  /// Used by open screen, pull-to-refresh, and resume events.
  static Future<void> refreshCloudCollections({
    String reason = 'manual',
    bool force = false,
  }) async {
    if (_collectionRefreshers.isEmpty) {
      debugPrint('⏭️ refreshCloudCollections: no active collections');
      return;
    }

    if (_isRefreshingCollections) {
      debugPrint('⏭️ refreshCloudCollections: already running ($reason)');
      return;
    }

    final now = DateTime.now();
    if (!force &&
        _lastRefreshCollectionsAt != null &&
        now.difference(_lastRefreshCollectionsAt!) <
            _collectionRefreshCooldown) {
      debugPrint('⏭️ refreshCloudCollections: cooldown active ($reason)');
      return;
    }

    _isRefreshingCollections = true;
    try {
      debugPrint(
        '🔄 refreshCloudCollections: reason=$reason total=${_collectionRefreshers.length}',
      );
      for (final entry in _collectionRefreshers.entries) {
        try {
          await entry.value();
        } catch (e) {
          debugPrint('❌ refreshCloudCollections error in ${entry.key}: $e');
        }
      }
      _lastRefreshCollectionsAt = DateTime.now();
      EventBus().emit(EventBus.dataRefresh);
    } finally {
      _isRefreshingCollections = false;
    }
  }

  /// Helper: Lấy timestamp từ data (hỗ trợ cả Timestamp và int)
  static int _getTimestamp(dynamic value) {
    if (value == null) return 0;
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is String) {
      final parsedInt = int.tryParse(value.trim());
      if (parsedInt != null) return parsedInt;
      final parsedDouble = double.tryParse(value.trim());
      if (parsedDouble != null) return parsedDouble.toInt();
    }
    return 0;
  }

  static int _asInt(dynamic value) => _getTimestamp(value);

  static bool _asBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == '1' ||
          normalized == 'true' ||
          normalized == 'yes' ||
          normalized == 'y';
    }
    return false;
  }

  static int _normalizeRepairStatusValue(dynamic value) {
    final numeric = _asInt(value);
    if (numeric >= 1 && numeric <= 4) return numeric;

    if (value is String) {
      final normalized = value.trim().toLowerCase();
      switch (normalized) {
        case 'may cho':
        case 'cho sua':
        case 'pending':
        case 'received':
        case 'new':
          return 1;
        case 'dang sua':
        case 'repairing':
        case 'in_progress':
        case 'repair':
          return 2;
        case 'da xong':
        case 'hoan thanh':
        case 'completed':
        case 'done':
          return 3;
        case 'da giao':
        case 'delivered':
        case 'closed':
          return 4;
      }
    }

    return 1;
  }

  static void _normalizeRepairPayload(Map<String, dynamic> data) {
    var status = _normalizeRepairStatusValue(data['status']);
    final createdAt = _asInt(data['createdAt']);
    final finishedAt = _asInt(data['finishedAt']);
    var deliveredAt = _asInt(data['deliveredAt']);
    final lastCaredAt = _asInt(data['lastCaredAt']);
    final pendingApproval = _asBool(data['pendingDeliveryApproval']);

    // If deliveredAt already exists AND repair is NOT in pending approval state, status must be delivered.
    // NOTE: deliveredAt is also set when staff REQUESTS delivery approval (pendingDeliveryApproval=true),
    // so we must NOT auto-upgrade to status=4 while the repair is still pending approval.
    if (deliveredAt > 0 && status < 4 && !pendingApproval) {
      status = 4;
    }

    if (status == 4) {
      if (deliveredAt <= 0) {
        deliveredAt = lastCaredAt > 0
            ? lastCaredAt
            : (finishedAt > 0 ? finishedAt : createdAt);
      }
      data['pendingDeliveryApproval'] = 0;
      data['deliveredAt'] = deliveredAt;
    } else {
      data['pendingDeliveryApproval'] = status == 3 && pendingApproval ? 1 : 0;
    }

    data['status'] = status;
  }

  static Future<void> _dropStaleRepairQueueEntry(
    String firestoreId, {
    int? localId,
  }) async {
    try {
      final db = await DBHelper().database;
      int removed = 0;

      if (localId != null) {
        removed = await db.delete(
          'sync_queue',
          where: 'entityType = ? AND (firestoreId = ? OR entityId = ?)',
          whereArgs: ['repair', firestoreId, localId],
        );
      } else {
        removed = await db.delete(
          'sync_queue',
          where: 'entityType = ? AND firestoreId = ?',
          whereArgs: ['repair', firestoreId],
        );
      }

      if (removed > 0) {
        debugPrint(
          '🧹 SYNC: dropped $removed stale repair queue item(s) for $firestoreId',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to drop stale repair queue for $firestoreId: $e');
    }
  }

  /// Helper: Chuyển đổi tất cả Timestamp fields trong map sang milliseconds
  /// Để lưu vào SQLite (không hỗ trợ Firestore Timestamp)
  static void _convertTimestampFields(Map<String, dynamic> data) {
    final timestampFields = [
      'createdAt',
      'updatedAt',
      'checkInAt',
      'checkOutAt',
      'approvedAt',
      'startedAt',
      'finishedAt',
      'deliveredAt',
      'lastCaredAt',
      'soldAt',
      'paidAt',
      'lastVisitAt',
      'settlementPlannedAt',
      'settlementReceivedAt',
      'returnDate',
    ];
    for (final field in timestampFields) {
      if (data[field] is Timestamp) {
        data[field] = (data[field] as Timestamp).millisecondsSinceEpoch;
      }
    }
  }

  static String _realtimeCursorKey(String collection, String shopId) =>
      '$_realtimeCursorPrefix${collection}_$shopId';

  static Future<void> _warmRealtimeCursorCache(String shopId) async {
    if (shopId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    for (final collection in _incrementalRealtimeCollections) {
      final key = _realtimeCursorKey(collection, shopId);
      final cursorMs = prefs.getInt(key) ?? 0;
      if (cursorMs > 0) {
        _realtimeCursorCache[key] = cursorMs;
      }
    }
  }

  static int _realtimeCursorMs(String collection, String shopId) {
    if (shopId.isEmpty) return 0;
    return _realtimeCursorCache[_realtimeCursorKey(collection, shopId)] ?? 0;
  }

  static int _normalizeRealtimeCursorMs(int rawMs) {
    if (rawMs <= 0) return 0;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final maxAllowedMs = nowMs + const Duration(days: 1).inMilliseconds;
    if (rawMs > maxAllowedMs) {
      return maxAllowedMs;
    }
    return rawMs;
  }

  static Future<void> _saveRealtimeCursorMs({
    required String collection,
    required String shopId,
    required int cursorMs,
  }) async {
    if (shopId.isEmpty) return;

    final normalizedMs = _normalizeRealtimeCursorMs(cursorMs);
    if (normalizedMs <= 0) return;

    final key = _realtimeCursorKey(collection, shopId);
    final currentMs = _realtimeCursorCache[key] ?? 0;
    if (normalizedMs <= currentMs) return;

    _realtimeCursorCache[key] = normalizedMs;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, normalizedMs);
  }

  static int _extractRealtimeCursorMs(Map<String, dynamic> data) {
    var maxMs = _getTimestamp(data['updatedAt']);
    final createdAtMs = _getTimestamp(data['createdAt']);
    final syncedAtMs = _getTimestamp(data['syncedAt']);

    if (createdAtMs > maxMs) {
      maxMs = createdAtMs;
    }
    if (syncedAtMs > maxMs) {
      maxMs = syncedAtMs;
    }

    return _normalizeRealtimeCursorMs(maxMs);
  }

  static bool _canUseIncrementalRealtime({
    required String collection,
    required String? shopId,
  }) {
    if (shopId == null || shopId.isEmpty) return false;
    if (!_incrementalRealtimeCollections.contains(collection)) return false;
    if (_incrementalRealtimeDisabled.contains(collection)) return false;

    return _realtimeCursorMs(collection, shopId) > 0;
  }

  static List<String> _splitImagePaths(String? csv) {
    if (csv == null || csv.trim().isEmpty) return const [];

    final raw = csv.trim();
    final output = <String>[];

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
      if (!output.contains(s)) {
        output.add(s);
      }
    }

    if (raw.startsWith('[') && raw.endsWith(']')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            addCandidate(item?.toString());
          }
          if (output.isNotEmpty) return output;
        }
      } catch (_) {
        // Continue with delimiter fallback.
      }
    }

    for (final part in raw.split(RegExp(r'[,;\n]'))) {
      addCandidate(part);
    }

    return output;
  }

  static bool _isCloudImagePath(String path) {
    return path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('gs://');
  }

  static bool _hasLocalImagePath(String? csv) {
    return _splitImagePaths(csv).any((p) => !_isCloudImagePath(p));
  }

  static Future<String> _normalizeRepairImagePathsForCloud(
    String? rawImagePath,
    int createdAt,
  ) async {
    final allPaths = _splitImagePaths(rawImagePath);
    if (allPaths.isEmpty) return '';

    final cloudPaths = allPaths.where(_isCloudImagePath).toList();
    final localPaths = allPaths.where((p) => !_isCloudImagePath(p)).toList();
    if (localPaths.isEmpty) {
      return cloudPaths.join(',');
    }

    final uploadedUrls = await StorageService.uploadMultipleImages(
      localPaths,
      'repairs/$createdAt',
    );

    if (uploadedUrls.length < localPaths.length) {
      throw Exception(
        'Repair images not fully uploaded (${uploadedUrls.length}/${localPaths.length})',
      );
    }

    return [...cloudPaths, ...uploadedUrls].join(',');
  }

  static String _normalizeLegacyShopName(String? rawName) {
    final name = (rawName ?? '').trim();
    if (name.isEmpty) return 'Quản Lý Shop';
    final lower = name.toLowerCase();
    if (lower == 'shop new' || lower == 'shop_new' || lower == 'shopnew') {
      return 'Quản Lý Shop';
    }
    return name;
  }

  /// Public wrapper cho _convertTimestampFields (dùng bởi SyncHealthCheck.autoFix)
  static void convertTimestampFieldsPublic(Map<String, dynamic> data) =>
      _convertTimestampFields(data);

  /// Tách `yyyy-MM-dd` từ docId chốt quỹ dạng `closing_<shopId>_<yyyy-MM-dd>`.
  static String? _dateKeyFromClosingDocId(String docId) {
    final m = RegExp(r'(\d{4}-\d{2}-\d{2})$').firstMatch(docId);
    return m?.group(1);
  }

  /// Helper: So sánh updatedAt để quyết định có ghi đè local hay không
  /// Returns: true nếu cloud data mới hơn hoặc bằng, false nếu local mới hơn
  static Future<bool> _shouldAcceptCloudData({
    required String collection,
    required String firestoreId,
    required Map<String, dynamic> cloudData,
  }) async {
    final db = DBHelper();
    final cloudUpdatedAt = _getTimestamp(cloudData['updatedAt']);

    // Nếu cloud không có updatedAt, dùng createdAt
    final cloudTime = cloudUpdatedAt > 0
        ? cloudUpdatedAt
        : _getTimestamp(cloudData['createdAt']);

    int localUpdatedAt = 0;
    bool localIsSynced = true;
    int? localEntityId;
    int localRepairStatus = -1;

    try {
      switch (collection) {
        case 'repairs':
          final local = await db.getRepairByFirestoreId(firestoreId);
          if (local != null) {
            // Repair model doesn't have updatedAt, use lastCaredAt or createdAt
            localUpdatedAt = local.lastCaredAt ?? local.createdAt;
            localIsSynced = local.isSynced;
            localEntityId = local.id;
            localRepairStatus = local.status;
          }
          break;
        case 'sales':
          final local = await db.getSaleByFirestoreId(firestoreId);
          if (local != null) {
            // SaleOrder model doesn't have updatedAt, use soldAt
            localUpdatedAt = local.soldAt;
            localIsSynced = local.isSynced;
          }
          break;
        case 'products':
          final local = await db.getProductByFirestoreId(firestoreId);
          if (local != null) {
            localUpdatedAt = local.updatedAt ?? local.createdAt;
            localIsSynced = local.isSynced;
          }
          break;
        case 'expenses':
          final local = await db.getExpenseByFirestoreId(firestoreId);
          if (local != null) {
            // Expense model không có updatedAt, dùng date làm thời gian tham chiếu
            localUpdatedAt = local.date;
            localIsSynced = local.isSynced;
          }
          break;
        case 'debts':
          final local = await db.getDebtByFirestoreId(firestoreId);
          if (local != null) {
            localUpdatedAt =
                local['updatedAt'] as int? ?? local['createdAt'] as int? ?? 0;
            localIsSynced = (local['isSynced'] as int?) == 1;
          }
          break;
        default:
          // Các collection khác: luôn accept cloud data
          return true;
      }
    } catch (e) {
      debugPrint('⚠️ Conflict check error for $collection/$firestoreId: $e');
      return true; // Nếu lỗi, accept cloud data
    }

    // Nếu local chưa tồn tại → accept cloud
    if (localUpdatedAt == 0) {
      debugPrint(
        '✅ SYNC: $collection/$firestoreId - Local không tồn tại, accept cloud',
      );
      return true;
    }

    // TRẠNG THÁI CUỐI: đơn sửa "Đã giao" (status 4) không đảo ngược qua sync.
    // Nếu cloud = 4 mà local < 4 → LUÔN nhận cloud, bất kể timestamp / isSynced /
    // lệch giờ máy. Đây là fix "máy khác duyệt giao rồi mà máy này vẫn chưa giao".
    if (collection == 'repairs' && localRepairStatus >= 0) {
      final cloudStatus = _normalizeRepairStatusValue(cloudData['status']);
      final cloudPending = _asBool(cloudData['pendingDeliveryApproval']);
      if (cloudStatus >= 4 && !cloudPending && localRepairStatus < 4) {
        debugPrint(
          '⬇️ SYNC: repairs/$firestoreId - Cloud ĐÃ GIAO (4), local $localRepairStatus → accept cloud (trạng thái cuối)',
        );
        await _dropStaleRepairQueueEntry(firestoreId, localId: localEntityId);
        return true;
      }
    }

    // Nếu local đã sync (không có thay đổi pending) → accept cloud
    // Ngoại lệ: repairs + debts — so sánh timestamp để tránh 1 echo CŨ của
    // Firestore ghi đè thay đổi vừa xảy ra cục bộ (repairs: status mới; debts:
    // paidAmount vừa cập nhật sau khi thu/trả nợ — "thanh toán xong không trừ
    // nợ" chính là echo cũ này reset paidAmount về số trước đó).
    if (localIsSynced) {
      if ((collection == 'repairs' || collection == 'debts') &&
          cloudTime > 0 &&
          localUpdatedAt > 0) {
        const toleranceMs = 3000;
        if (localUpdatedAt > cloudTime + toleranceMs) {
          debugPrint(
            '🔒 SYNC: $collection/$firestoreId - Local mới hơn cloud dù isSynced=true, skip (local: $localUpdatedAt, cloud: $cloudTime)',
          );
          return false;
        }
      }
      debugPrint(
        '✅ SYNC: $collection/$firestoreId - Local đã sync, accept cloud',
      );
      return true;
    }

    // Repair-specific guard: local unsynced does not always mean local is newest.
    // If cloud updatedAt is clearly newer, accept cloud and drop stale queued local write.
    if (collection == 'repairs' && cloudTime > 0 && localUpdatedAt > 0) {
      const toleranceMs = 5000;
      if (cloudTime > localUpdatedAt + toleranceMs) {
        debugPrint(
          '⬇️ SYNC: repairs/$firestoreId - Cloud newer than unsynced local (cloud: $cloudTime, local: $localUpdatedAt), accept cloud',
        );
        await _dropStaleRepairQueueEntry(firestoreId, localId: localEntityId);
        return true;
      }
    }

    // Local có thay đổi chưa sync (isSynced=false) → LUÔN giữ local
    // Đây là fix cho race condition: khi vừa cập nhật status, cloud listener
    // có thể trả về data cũ (echo) và ghi đè local changes
    debugPrint(
      '🔒 SYNC: $collection/$firestoreId - Local chưa sync (isSynced=false), SKIP cloud (cloud: $cloudTime, local: $localUpdatedAt), enqueue local',
    );
    // Enqueue local data để push lên cloud
    await _enqueueLocalForSync(collection, firestoreId);
    return false;
  }

  /// Helper: Enqueue local data để push lên cloud khi local mới hơn
  static Future<void> _enqueueLocalForSync(
    String collection,
    String firestoreId,
  ) async {
    final db = DBHelper();
    final orchestrator = SyncOrchestrator();

    try {
      switch (collection) {
        case 'repairs':
          final local = await db.getRepairByFirestoreId(firestoreId);
          if (local != null && local.id != null) {
            await orchestrator.enqueue(
              entityType: SyncEntityType.repair,
              entityId: local.id!,
              firestoreId: firestoreId,
              operation: SyncOperation.update,
              data: local.toMap(),
            );
          }
          break;
        case 'sales':
          final local = await db.getSaleByFirestoreId(firestoreId);
          if (local != null && local.id != null) {
            await orchestrator.enqueue(
              entityType: SyncEntityType.sale,
              entityId: local.id!,
              firestoreId: firestoreId,
              operation: SyncOperation.update,
              data: local.toMap(),
            );
          }
          break;
        case 'products':
          final local = await db.getProductByFirestoreId(firestoreId);
          if (local != null && local.id != null) {
            await orchestrator.enqueue(
              entityType: SyncEntityType.product,
              entityId: local.id!,
              firestoreId: firestoreId,
              operation: SyncOperation.update,
              data: local.toMap(),
            );
          }
          break;
        case 'expenses':
          final local = await db.getExpenseByFirestoreId(firestoreId);
          if (local != null && local.id != null) {
            await orchestrator.enqueue(
              entityType: SyncEntityType.expense,
              entityId: local.id!,
              firestoreId: firestoreId,
              operation: SyncOperation.update,
              data: local.toMap(),
            );
          }
          break;
        case 'debts':
          final local = await db.getDebtByFirestoreId(firestoreId);
          if (local != null && local['id'] != null) {
            await orchestrator.enqueue(
              entityType: SyncEntityType.debt,
              entityId: local['id'] as int,
              firestoreId: firestoreId,
              operation: SyncOperation.update,
              data: local,
            );
          }
          break;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to enqueue local $collection/$firestoreId: $e');
    }

    // Best-effort: nếu đã enqueue thì cố gắng đẩy ngay lên cloud (tránh tình trạng "lúc được lúc không")
    // ignore: unawaited_futures
    orchestrator.syncAll();
  }

  /// Sau khi nhận 1 dòng `debt_payments` từ cloud (mới/xóa), tự khớp lại
  /// `debts.paidAmount` của khoản nợ liên quan từ TỔNG sổ cái `debt_payments`
  /// local — KHÔNG chờ doc `debts` riêng của máy nguồn về (có thể trượt/kẹt
  /// conflict). Đây là gốc rễ của "mỗi máy một số công nợ": trước đây listener
  /// chỉ upsert dòng phiếu, không đụng `paidAmount`.
  ///
  /// `markUnsynced: false` — giá trị bằng đúng số máy nguồn đã tính, không
  /// re-push để tránh ping-pong echo.
  static Future<void> _reconcileDebtFromPaymentRow(
    DBHelper db,
    Map<String, dynamic> paymentRow,
  ) async {
    try {
      final fidRaw = paymentRow['debtFirestoreId'];
      final fid = fidRaw is String ? fidRaw.trim() : null;
      final rawId = paymentRow['debtId'];
      int? debtId;
      if (rawId is int) {
        debtId = rawId;
      } else if (rawId is num) {
        debtId = rawId.toInt();
      } else if (rawId is String) {
        debtId = int.tryParse(rawId.trim());
      }
      if ((fid == null || fid.isEmpty) && debtId == null) return;
      await db.updateDebtPaid(
        debtId,
        firestoreId: (fid != null && fid.isNotEmpty) ? fid : null,
        markUnsynced: false,
      );
    } catch (e) {
      debugPrint('⚠️ _reconcileDebtFromPaymentRow: $e');
    }
  }

  /// Khởi tạo đồng bộ thời gian thực
  static Future<void> initRealTimeSync(VoidCallback onDataChanged) async {
    if (_isInitializingRealtime) {
      debugPrint('⏸️ initRealTimeSync: đang khởi tạo, bỏ qua lần gọi trùng');
      return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("initRealTimeSync: Không có user, bỏ qua");
        return;
      }

      final bool isSuperAdmin = UserService.isCurrentUserSuperAdmin();
      final permissions = await UserService.getCurrentUserPermissions();
      final role = await UserService.getUserRole(user.uid);
      // Super admin cũng cần shopId nếu đã chọn shop
      final String? shopId = await UserService.getCurrentShopId();
      final initSignature = _buildRealtimeInitSignature(
        uid: user.uid,
        shopId: shopId,
        role: role,
        isSuperAdmin: isSuperAdmin,
        permissions: permissions,
      );

      if (isRealTimeSyncActive && _lastRealtimeInitSignature == initSignature) {
        debugPrint(
          '⏭️ initRealTimeSync: duplicate init for same user/shop/permissions skipped',
        );
        return;
      }

      _isInitializingRealtime = true;
      PerfMonitor.start('initRealTimeSync');
      debugPrint("Khởi tạo real-time sync...");
      // Hủy các subscription cũ nếu có để tránh rò rỉ bộ nhớ hoặc lặp sự kiện
      await cancelAllSubscriptions();

      // Store callback for potential reinitialization
      _onDataChangedCallback = onDataChanged;

      // Baseline signature sẽ lấy từ users stream lần đầu để tránh lệch nguồn
      // giữa quyền đã chuẩn hóa và dữ liệu profile thô gây reinit giả.
      _lastUserPermissionSignature = null;
      _lastShopRestrictionSignature = null;

      // Store shopId for later reference
      _currentShopId = shopId;

      // LOG QUAN TRỌNG: Hiển thị shopId được sử dụng để filter
      debugPrint(
        "⚡ initRealTimeSync: user=${user.uid}, email=${user.email}, shopId=$shopId, isSuperAdmin=$isSuperAdmin",
      );

      // ═══════════════════════════════════════════════════════════════════════
      // QUAN TRỌNG: Kiểm tra và refresh Custom Claims nếu cần
      // Firestore Rules yêu cầu token phải có shopId claim để truy cập data
      // ═══════════════════════════════════════════════════════════════════════
      if (!isSuperAdmin && shopId != null) {
        try {
          // Lấy claims từ token để kiểm tra
          final claims = await ClaimsService().getClaimsFromToken(
            forceRefresh: true,
          );
          final tokenShopId = claims?['shopId'];

          debugPrint(
            "🔑 Token claims: shopId=$tokenShopId, role=${claims?['role']}",
          );

          // Nếu shopId trong token không khớp với shopId từ Firestore, refresh claims
          if (tokenShopId != shopId) {
            debugPrint(
              "⚠️ Token shopId ($tokenShopId) != Firestore shopId ($shopId), refreshing claims...",
            );

            // Gọi Cloud Function để refresh claims
            final result = await ClaimsService().refreshMyClaims();
            debugPrint("🔄 refreshMyClaims result: $result");

            // Chờ và refresh token lại
            await Future.delayed(const Duration(seconds: 1));
            await user.getIdToken(true);

            // Kiểm tra lại claims sau khi refresh
            final newClaims = await ClaimsService().getClaimsFromToken(
              forceRefresh: true,
            );
            debugPrint(
              "✅ New token claims after refresh: shopId=${newClaims?['shopId']}, role=${newClaims?['role']}",
            );
          }
        } catch (e) {
          debugPrint("⚠️ Error checking/refreshing claims: $e");
        }
      }

      // Super admin phải chọn shop trước khi init real-time sync
      if (shopId == null) {
        if (isSuperAdmin) {
          debugPrint("⚠️ initRealTimeSync: Super admin chưa chọn shop, bỏ qua");
        } else {
          debugPrint("⚠️ initRealTimeSync: Không có shopId, bỏ qua");
        }
        return;
      }

      await _warmRealtimeCursorCache(shopId);

      // AUTO-CLEANUP: Xóa orphan repair_parts bị stuck (không có firestoreId)
      // force mark các records có firestoreId là đã sync
      // và fix records bị stuck deleted=1 do bug cũ
      try {
        final dbHelper = DBHelper();
        final deduped = await dbHelper.cleanupCloudShadowDuplicates();
        final orphansCleaned = await dbHelper.cleanupOrphanRepairParts();
        final forceMarked = await dbHelper.forceMarkRepairPartsSynced();
        final stuckFixed = await dbHelper.fixStuckDeletedRepairParts();
        if (deduped > 0 ||
            orphansCleaned > 0 ||
            forceMarked > 0 ||
            stuckFixed > 0) {
          debugPrint(
            "🧹 Auto-cleanup: deduped $deduped cloud-shadow rows, removed $orphansCleaned orphans, force-marked $forceMarked synced, fixed $stuckFixed stuck-deleted",
          );
        }
      } catch (e) {
        debugPrint("⚠️ Auto-cleanup failed: $e");
      }

      // 1. Đồng bộ REPAIRS
      _subscribeToCollection(
        collection: 'repairs',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            debugPrint(
              "SYNC_TRACE: Received repair data from Firestore - docId: $docId, status: ${data['status']}, price: ${data['price']}, totalCost: ${data['totalCost']}, createdAt: ${data['createdAt']}, deliveredAt: ${data['deliveredAt']}, deleted: ${data['deleted']}",
            );
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteRepairByFirestoreId(docId);
              debugPrint(
                "SYNC_TRACE: Deleted repair $docId from local DB (deleted=true in Firestore)",
              );
            } else {
              // CONFLICT RESOLUTION: So sánh updatedAt
              final shouldAccept = await _shouldAcceptCloudData(
                collection: 'repairs',
                firestoreId: docId,
                cloudData: data,
              );

              if (shouldAccept) {
                _convertTimestampFields(data);
                _normalizeRepairPayload(data);
                data['firestoreId'] = docId;
                data['isSynced'] = 1; // Đánh dấu đã sync từ cloud
                await db.upsertRepair(Repair.fromMap(data));
                debugPrint(
                  "SYNC_TRACE: Upserted repair $docId to local DB SUCCESSFULLY",
                );
              }
            }
          } catch (e) {
            debugPrint("SYNC_TRACE: Error syncing repair $docId: $e");
          }
        },
        onBatchDone: () {
          // Chỉ emit EventBus — HomeView + các view khác đã listen EventBus
          // (bỏ onDataChanged() để tránh double-hit reload)
          debugPrint(
            '✅ [SyncService] Sync xong repairs → emit repairs_changed',
          );
          EventBus().emit(EventBus.repairsChanged);
        },
      );

      // 2. Đồng bộ SALES
      _subscribeToCollection(
        collection: 'sales',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            debugPrint(
              "SYNC_TRACE: Received sale data from Firestore - docId: $docId, totalPrice: ${data['totalPrice']}, totalCost: ${data['totalCost']}, soldAt: ${data['soldAt']}, customerName: ${data['customerName']}, deleted: ${data['deleted']}",
            );
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteSaleByFirestoreId(docId);
              debugPrint(
                "SYNC_TRACE: Deleted sale $docId from local DB (deleted=true in Firestore)",
              );
            } else {
              // CONFLICT RESOLUTION: So sánh updatedAt
              final shouldAccept = await _shouldAcceptCloudData(
                collection: 'sales',
                firestoreId: docId,
                cloudData: data,
              );

              if (shouldAccept) {
                data['firestoreId'] = docId;
                data['isSynced'] = 1; // Đánh dấu đã sync từ cloud
                await db.upsertSale(SaleOrder.fromMap(data));
                // Đảm bảo shopId được lưu để getAllSales() scoped query tìm thấy
                if (shopId.isNotEmpty) {
                  try {
                    await (await db.database).rawUpdate(
                      'UPDATE sales SET shopId = ? WHERE firestoreId = ?',
                      [shopId, docId],
                    );
                  } catch (_) {}
                }
                debugPrint(
                  "SYNC_TRACE: Upserted sale $docId to local DB SUCCESSFULLY",
                );
              }
            }
          } catch (e) {
            debugPrint("SYNC_TRACE: Error syncing sale $docId: $e");
          }
        },
        onBatchDone: () {
          // Chỉ emit EventBus — tránh double-hit reload
          debugPrint('✅ [SyncService] Sync xong sales → emit sales_changed');
          EventBus().emit('sales_changed');
        },
      );

      // 3. Đồng bộ PRODUCTS
      _subscribeToCollection(
        collection: 'products',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteProductByFirestoreId(docId);
            } else {
              // CONFLICT RESOLUTION: So sánh updatedAt
              final shouldAccept = await _shouldAcceptCloudData(
                collection: 'products',
                firestoreId: docId,
                cloudData: data,
              );

              if (shouldAccept) {
                data['firestoreId'] = docId;
                data['isSynced'] = 1; // Đánh dấu đã sync từ cloud

                // Chuyển đổi Timestamp sang milliseconds cho SQLite
                if (data['createdAt'] is Timestamp) {
                  data['createdAt'] =
                      (data['createdAt'] as Timestamp).millisecondsSinceEpoch;
                }
                if (data['updatedAt'] is Timestamp) {
                  data['updatedAt'] =
                      (data['updatedAt'] as Timestamp).millisecondsSinceEpoch;
                }

                // BẢO TOÀN các field quan trọng từ local nếu cloud trả về 0/null
                final existingProduct = await db.getProductByFirestoreId(docId);
                if (existingProduct != null) {
                  // Preserve isPending / pendingSupplier
                  if (existingProduct.isPending && data['isPending'] == null) {
                    data['isPending'] = 1;
                    data['pendingSupplier'] = existingProduct.pendingSupplier;
                  }
                  // Preserve createdAt: không cho cloud ghi đè 0 lên giá trị đúng local
                  final cloudCreatedAt = _getTimestamp(data['createdAt']);
                  if (existingProduct.createdAt > 0 && cloudCreatedAt <= 0) {
                    data['createdAt'] = existingProduct.createdAt;
                  }
                  // Preserve price / cost: không cho cloud ghi 0 lên giá trị đúng local
                  final cloudPrice = _asInt(data['price']);
                  final cloudCost = _asInt(data['cost']);
                  if (existingProduct.price > 0 && cloudPrice <= 0) {
                    data['price'] = existingProduct.price;
                  }
                  if (existingProduct.cost > 0 && cloudCost <= 0) {
                    data['cost'] = existingProduct.cost;
                  }
                }

                // Map 'detail' → 'description' nếu cloud chỉ có 'detail' (backward compat)
                if (data['description'] == null && data['detail'] != null) {
                  data['description'] = data['detail'];
                }

                await db.upsertProduct(Product.fromMap(data));
              }
            }
          } catch (e) {
            debugPrint("Lỗi sync product $docId: $e");
          }
        },
        onBatchDone: () {
          debugPrint(
            '✅ [SyncService] Sync xong products → emit products_changed',
          );
          onDataChanged();
          EventBus().emit('products_changed');
        },
      );

      // 4. Đồng bộ EXPENSES
      _subscribeToCollection(
        collection: 'expenses',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteExpenseByFirestoreId(docId);
            } else {
              // CONFLICT RESOLUTION: So sánh updatedAt
              final shouldAccept = await _shouldAcceptCloudData(
                collection: 'expenses',
                firestoreId: docId,
                cloudData: data,
              );

              if (shouldAccept) {
                data['firestoreId'] = docId;
                data['isSynced'] = 1; // Đánh dấu đã sync từ cloud
                await db.upsertExpense(Expense.fromMap(data));
              }
            }
          } catch (e) {
            debugPrint("Lỗi sync expense $docId: $e");
          }
        },
        onBatchDone: () {
          // Chỉ emit EventBus — tránh double-hit reload
          EventBus().emit('expenses_changed');
        },
      );

      // 5. Đồng bộ DEBTS
      _subscribeToCollection(
        collection: 'debts',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteDebtByFirestoreId(docId);
            } else {
              // CONFLICT RESOLUTION: So sánh updatedAt
              final shouldAccept = await _shouldAcceptCloudData(
                collection: 'debts',
                firestoreId: docId,
                cloudData: data,
              );

              if (shouldAccept) {
                data['firestoreId'] = docId;
                data['isSynced'] = 1; // Đánh dấu đã sync từ cloud
                await db.upsertDebt(Debt.fromMap(data));
              }
            }
          } catch (e) {
            debugPrint("Lỗi sync debt $docId: $e");
          }
        },
        onBatchDone: () {
          // Chỉ emit EventBus — tránh double-hit reload
          EventBus().emit('debts_changed');
        },
      );

      // 5b. Đồng bộ DEBT PAYMENTS (thanh toán công nợ)
      // FIX: Thêm real-time listener cho debt_payments - trước đây bị thiếu
      _subscribeToCollection(
        collection: 'debt_payments',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteDebtPaymentByFirestoreId(docId);
              // Phiếu bị xóa trên cloud → nợ liên quan phải giảm paidAmount.
              await _reconcileDebtFromPaymentRow(db, data);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1;
              _convertTimestampFields(data);
              await db.upsertDebtPayment(data);
              // Tự khớp lại debts.paidAmount từ sổ cái — không chờ doc debts
              // riêng của máy nguồn (gốc rễ "mỗi máy một số công nợ").
              await _reconcileDebtFromPaymentRow(db, data);
            }
          } catch (e) {
            debugPrint("Lỗi sync debt_payment $docId: $e");
          }
        },
        onBatchDone: () {
          // Chỉ emit EventBus — tránh double-hit reload
          EventBus().emit('debts_changed');
        },
      );

      // 6. Đồng bộ USERS (cập nhật cache khi có thay đổi)
      _subscribeToCollection(
        collection: 'users',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            // Nếu là user hiện tại, cập nhật cache shopId
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null && docId == currentUser.uid) {
              final newSignature = _buildUserPermissionSignature(data);
              final signatureChanged =
                  _lastUserPermissionSignature != null &&
                  _lastUserPermissionSignature != newSignature;
              UserService.updateCachedShopId(data['shopId']);
              debugPrint("Updated cached shopId: ${data['shopId']}");

              if (_lastUserPermissionSignature == null) {
                _lastUserPermissionSignature = newSignature;
              } else if (signatureChanged) {
                _lastUserPermissionSignature = newSignature;
                UserService.invalidatePermissionsCache();
                unawaited(
                  _refreshSyncAfterAccessChange('user permissions changed'),
                );
              }
            }
          } catch (e) {
            debugPrint("Lỗi sync user $docId: $e");
          }
        },
        onBatchDone: () {
          onDataChanged();
          EventBus().emit('users_changed');
        },
      );

      // 7. Đồng bộ SHOPS (subscribe trực tiếp vào document, không query by shopId)
      // Collection 'shops' sử dụng document ID = shopId, không có field 'shopId'
      final shopSub = _db.collection('shops').doc(shopId).snapshots().listen((
        snapshot,
      ) async {
        if (!snapshot.exists) return;
        final data = snapshot.data();
        if (data == null) return;

        try {
          final newShopSignature = _buildShopRestrictionSignature(data);
          final shopSignatureChanged =
              _lastShopRestrictionSignature != null &&
              _lastShopRestrictionSignature != newShopSignature;
          if (_lastShopRestrictionSignature == null) {
            _lastShopRestrictionSignature = newShopSignature;
          } else if (shopSignatureChanged) {
            _lastShopRestrictionSignature = newShopSignature;
            UserService.invalidatePermissionsCache();
            unawaited(
              _refreshSyncAfterAccessChange('shop restrictions changed'),
            );
          }

          debugPrint("📡 Shop data changed for shopId: $shopId");

          // Cập nhật SharedPreferences để các màn hình khác có thể đọc
          final prefs = await SharedPreferences.getInstance();
          final shopName = _normalizeLegacyShopName(data['name']?.toString());
          final shopAddress = data['address']?.toString() ?? '';
          final shopPhone = data['phone']?.toString() ?? '';

          await prefs.setString('shop_name', shopName);
          await prefs.setString('shop_address', shopAddress);
          await prefs.setString('shop_phone', shopPhone);

          // Sync policies to SharedPreferences so all devices in the same shop
          // share the same warranty/return policy text.
          final warrantyPolicy = data['warrantyPolicy']?.toString() ?? '';
          final returnPolicy = data['returnPolicy']?.toString() ?? '';
          await prefs.setString('warranty_policy', warrantyPolicy);
          await prefs.setString('return_policy', returnPolicy);

          debugPrint(
            "✅ Synced shop info to SharedPreferences: $shopName, $shopAddress, $shopPhone",
          );

          // Trigger UI update
          onDataChanged();
        } catch (e) {
          debugPrint("Lỗi sync shop $shopId: $e");
        }
      }, onError: (e) => debugPrint("Sync error in shops/$shopId: $e"));
      _subscriptions.add(shopSub);

      // 8. Đồng bộ STORAGE_LOCATIONS — cần sớm vì picker vị trí dùng ngay
      try {
        _subscribeToCollection(
          collection: 'storage_locations',
          shopId: shopId,
          permissions: permissions,
          role: role,
          isSuperAdmin: isSuperAdmin,
          onChanged: (data, docId) async {
            try {
              final db = DBHelper();
              if (data['deleted'] == true || data['deleted'] == 1) {
                await db.deleteStorageLocationByFirestoreId(docId);
              } else {
                data['firestoreId'] = docId;
                _convertTimestampFields(data);
                await db.upsertStorageLocationFromMap(data);
              }
            } catch (e) {
              debugPrint("Lỗi sync storage_location $docId: $e");
            }
          },
          onBatchDone: onDataChanged,
        );
      } catch (e) {
        debugPrint("Lỗi khởi tạo storage_locations sync (critical): $e");
      }

      // ═══════════════════════════════════════════════════════════════════════
      // CRITICAL subscriptions done — mark as initialized so UI can proceed
      // ═══════════════════════════════════════════════════════════════════════
      _isInitialized = true;
      _lastRealtimeInitSignature = initSignature;
      PerfMonitor.stop('initRealTimeSync');
      debugPrint(
        "✅ Critical sync ready (${_subscriptions.length} subs) — "
        "deferred collections will load in 3s...",
      );

      // Nhịp nền tự động fetch lại riêng "repairs" — bù cho việc collection
      // này dùng controlled get() polling thay vì snapshots() realtime nên
      // không thấy ngay đơn mới/đổi trạng thái từ thiết bị khác cho tới khi
      // thoát app vào lại. Gọi thẳng refresher của riêng "repairs" (không
      // dùng refreshCloudCollections() chung) để không kéo theo ~20 collection
      // khác cũng đang polling, tránh đội read cost trở lại. Mỗi tick chỉ tải
      // incremental (updatedAt > cursor cuối) nên rẻ; tự dừng khi đổi
      // shop/đăng xuất qua cancelAllSubscriptions().
      _pollingTimers.add(
        Timer.periodic(_periodicRepairsRefreshInterval, (_) {
          if (_currentShopId != shopId) return;
          final refresher = _collectionRefreshers['repairs'];
          if (refresher != null) unawaited(refresher());
        }),
      );

      // Schedule DEFERRED subscriptions after 3s to reduce initial load
      Future.delayed(const Duration(seconds: 3), () {
        if (_currentShopId != shopId) {
          debugPrint('⚠️ Shop changed before deferred sync — skipping');
          return;
        }
        _initDeferredSubscriptions(
          shopId: shopId,
          isSuperAdmin: isSuperAdmin,
          permissions: permissions,
          role: role,
          onDataChanged: onDataChanged,
        );
      });

      debugPrint("📊 Subscription status: $_subscriptionStatus");
    } finally {
      _isInitializingRealtime = false;
    }
  }

  /// Khởi tạo các subscription KHÔNG CẤP BÁCH sau 3 giây delay
  /// (attendance, suppliers, audit_logs, cash_closings, v.v.)
  static void _initDeferredSubscriptions({
    required String? shopId,
    required bool isSuperAdmin,
    required Map<String, dynamic> permissions,
    required String role,
    required VoidCallback onDataChanged,
  }) {
    debugPrint("🕐 Starting deferred sync subscriptions...");
    PerfMonitor.start('deferredSync');

    // 8. Đồng bộ ATTENDANCE
    try {
      _subscribeToCollection(
        collection: 'attendance',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteAttendanceByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1; // Đánh dấu đã sync từ cloud
              // Chuyển đổi Timestamp sang milliseconds cho SQLite
              if (data['checkInAt'] is Timestamp) {
                data['checkInAt'] =
                    (data['checkInAt'] as Timestamp).millisecondsSinceEpoch;
              }
              if (data['checkOutAt'] is Timestamp) {
                data['checkOutAt'] =
                    (data['checkOutAt'] as Timestamp).millisecondsSinceEpoch;
              }
              if (data['createdAt'] is Timestamp) {
                data['createdAt'] =
                    (data['createdAt'] as Timestamp).millisecondsSinceEpoch;
              }
              if (data['updatedAt'] is Timestamp) {
                data['updatedAt'] =
                    (data['updatedAt'] as Timestamp).millisecondsSinceEpoch;
              }
              if (data['approvedAt'] is Timestamp) {
                data['approvedAt'] =
                    (data['approvedAt'] as Timestamp).millisecondsSinceEpoch;
              }
              await db.upsertAttendance(Attendance.fromMap(data));
            }
          } catch (e) {
            debugPrint("Lỗi sync attendance $docId: $e");
          }
        },
        onBatchDone: () {
          onDataChanged();
          EventBus().emit('attendance_changed');
        },
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo attendance sync: $e");
    }

    // 8b. Đồng bộ LEAVE REQUESTS (Xin nghỉ)
    try {
      _subscribeToCollection(
        collection: 'leave_requests',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteLeaveRequestByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1;
              // Convert Timestamp fields
              for (final key in ['createdAt', 'updatedAt', 'approvedAt']) {
                if (data[key] is Timestamp) {
                  data[key] = (data[key] as Timestamp).millisecondsSinceEpoch;
                }
              }
              await db.upsertLeaveRequest(LeaveRequest.fromMap(data));
            }
          } catch (e) {
            debugPrint("Lỗi sync leave_request $docId: $e");
          }
        },
        onBatchDone: () {
          onDataChanged();
          EventBus().emit('leave_requests_changed');
        },
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo leave_requests sync: $e");
    }

    // 9. Đồng bộ QUICK INPUT CODES
    try {
      _subscribeToCollection(
        collection: 'quick_input_codes',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteQuickInputCodeByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1; // Đánh dấu đã sync từ cloud
              await db.upsertQuickInputCode(QuickInputCode.fromMap(data));
            }
          } catch (e) {
            debugPrint("Lỗi sync quick_input_code $docId: $e");
          }
        },
        onBatchDone: () {
          // Chỉ emit EventBus — tránh double-hit reload
          EventBus().emit('quick_input_codes_changed');
        },
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo quick_input_codes sync: $e");
    }

    // 10. Đồng bộ SUPPLIER PAYMENTS
    try {
      _subscribeToCollection(
        collection: 'supplier_payments',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteSupplierPaymentByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1; // Đánh dấu đã sync từ cloud
              await db.upsertSupplierPayment(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync supplier_payment $docId: $e");
          }
        },
        onBatchDone: onDataChanged,
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo supplier_payments sync: $e");
    }

    // 11. Đồng bộ REPAIR PARTNER PAYMENTS
    try {
      _subscribeToCollection(
        collection: 'repair_partner_payments',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteRepairPartnerPaymentByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1; // Đánh dấu đã sync từ cloud
              await db.upsertRepairPartnerPayment(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync repair_partner_payment $docId: $e");
          }
        },
        onBatchDone: onDataChanged,
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo repair_partner_payments sync: $e");
    }

    // 12. Đồng bộ CUSTOMERS
    try {
      bool customerBatchChanged = false;
      _subscribeToCollection(
        collection: 'customers',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteCustomerByFirestoreId(docId);
            } else {
              _convertTimestampFields(data);
              data['firestoreId'] = docId;
              data['isSynced'] = 1; // Đánh dấu đã sync từ cloud
              await db.upsertCustomer(data);
            }
            customerBatchChanged = true;
          } catch (e) {
            debugPrint("Lỗi sync customer $docId: $e");
          }
        },
        onBatchDone: () {
          if (customerBatchChanged) {
            EventBus().emit('customers_changed');
            customerBatchChanged = false;
          }
          onDataChanged();
        },
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo customers sync: $e");
    }

    // 13. Đồng bộ SUPPLIERS
    try {
      _subscribeToCollection(
        collection: 'suppliers',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteSupplierByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1; // Đánh dấu đã sync từ cloud
              await db.upsertSupplier(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync supplier $docId: $e");
          }
        },
        onBatchDone: () {
          debugPrint(
            '✅ [SyncService] Sync xong suppliers → emit suppliers_changed',
          );
          onDataChanged();
          EventBus().emit('suppliers_changed');
        },
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo suppliers sync: $e");
    }

    // 14. Đồng bộ REPAIR PARTNERS
    try {
      _subscribeToCollection(
        collection: 'repair_partners',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteRepairPartnerByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1; // Đánh dấu đã sync từ cloud
              await db.upsertRepairPartner(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync repair_partner $docId: $e");
          }
        },
        onBatchDone: () {
          onDataChanged();
          EventBus().emit('repair_partners_changed');
        },
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo repair_partners sync: $e");
    }

    // 14b. Đồng bộ PARTNER REPAIR HISTORY (lịch sử gửi sửa đối tác)
    try {
      _subscribeToCollection(
        collection: 'partner_repair_history',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deletePartnerRepairHistoryByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1;
              // Convert Timestamp to milliseconds for SQLite
              if (data['sentAt'] is Timestamp) {
                data['sentAt'] =
                    (data['sentAt'] as Timestamp).millisecondsSinceEpoch;
              }
              if (data['updatedAt'] is Timestamp) {
                data['updatedAt'] =
                    (data['updatedAt'] as Timestamp).millisecondsSinceEpoch;
              }
              await db.upsertPartnerRepairHistory(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync partner_repair_history $docId: $e");
          }
        },
        onBatchDone: onDataChanged,
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo partner_repair_history sync: $e");
    }

    // 15. Đồng bộ AUDIT LOGS
    try {
      _subscribeToCollection(
        collection: 'audit_logs',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteAuditLogByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1; // Đánh dấu đã sync từ cloud
              // Chuyển đổi Timestamp sang milliseconds cho SQLite
              if (data['createdAt'] is Timestamp) {
                data['createdAt'] =
                    (data['createdAt'] as Timestamp).millisecondsSinceEpoch;
              }
              // Map userName từ cloud
              data['userName'] =
                  data['userName'] ??
                  data['email']?.toString().split('@').first.toUpperCase() ??
                  'SYSTEM';
              // Map description từ summary
              data['description'] =
                  data['summary'] ?? data['description'] ?? '';
              // Map targetType và targetId từ entityType và entityId
              data['targetType'] =
                  data['targetType'] ?? data['entityType'] ?? '';
              data['targetId'] = data['targetId'] ?? data['entityId'] ?? '';
              await db.upsertAuditLog(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync audit_log $docId: $e");
          }
        },
        onBatchDone: onDataChanged,
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo audit_logs sync: $e");
    }

    // 16. Đồng bộ REPAIR PARTS (Kho linh kiện)
    try {
      _subscribeToCollection(
        collection: 'repair_parts',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteRepairPartByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1; // Đánh dấu đã sync từ cloud
              // Chuyển đổi Timestamp sang milliseconds cho SQLite
              if (data['createdAt'] is Timestamp) {
                data['createdAt'] =
                    (data['createdAt'] as Timestamp).millisecondsSinceEpoch;
              }
              if (data['updatedAt'] is Timestamp) {
                data['updatedAt'] =
                    (data['updatedAt'] as Timestamp).millisecondsSinceEpoch;
              }
              await db.upsertRepairPart(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync repair_part $docId: $e");
          }
        },
        onBatchDone: () {
          debugPrint(
            '✅ [SyncService] Sync xong repair_parts → emit parts_changed',
          );
          EventBus().emit('parts_changed');
        },
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo repair_parts sync: $e");
    }

    // 17. Đồng bộ SUPPLIER IMPORT HISTORY (Lịch sử nhập hàng)
    // FIX BUG-001: Thêm real-time sync cho supplier_import_history
    try {
      _subscribeToCollection(
        collection: 'supplier_import_history',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteSupplierImportHistoryByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1;
              _convertTimestampFields(data);
              await db.upsertSupplierImportHistory(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync supplier_import_history $docId: $e");
          }
        },
        onBatchDone: onDataChanged,
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo supplier_import_history sync: $e");
    }

    // 18. Đồng bộ SUPPLIER PRODUCT PRICES (Giá NCC)
    try {
      _subscribeToCollection(
        collection: 'supplier_product_prices',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteSupplierProductPriceByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1;
              _convertTimestampFields(data);
              await db.upsertSupplierProductPrice(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync supplier_product_price $docId: $e");
          }
        },
        onBatchDone: onDataChanged,
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo supplier_product_prices sync: $e");
    }

    // 18b. Đồng bộ IMPORT ORDERS (Phiếu nhập kho)
    try {
      _subscribeToCollection(
        collection: 'import_orders',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteImportOrderByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1;
              _convertTimestampFields(data);
              await db.upsertImportOrder(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync import_orders $docId: $e");
          }
        },
        onBatchDone: onDataChanged,
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo import_orders sync: $e");
    }

    // 18c. Đồng bộ IMPORT ORDER ITEMS (Chi tiết phiếu nhập)
    try {
      _subscribeToCollection(
        collection: 'import_order_items',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteImportOrderItemByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1;
              _convertTimestampFields(data);
              await db.upsertImportOrderItem(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync import_order_items $docId: $e");
          }
        },
        onBatchDone: onDataChanged,
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo import_order_items sync: $e");
    }

    // 19. FIX BUG-CC-002: Đồng bộ CASH CLOSINGS (Chốt quỹ)
    // Để đảm bảo khi máy A chốt quỹ, máy B sẽ nhận được update ngay lập tức
    try {
      _subscribeToCollection(
        collection: 'cash_closings',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteCashClosingByFirestoreId(docId);
              // Dọn luôn dòng local `firestoreId=NULL` cùng ngày (nếu có) —
              // docId dạng `closing_<shopId>_<yyyy-MM-dd>`.
              final dateKey = _dateKeyFromClosingDocId(docId) ??
                  (data['dateKey'] ?? data['date'])?.toString();
              if (dateKey != null && dateKey.isNotEmpty) {
                await db.deleteCashClosingByDateKey(dateKey);
              }
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1;
              _convertTimestampFields(data);
              await db.upsertCashClosing(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync cash_closing $docId: $e");
          }
        },
        onBatchDone: () {
          onDataChanged();
          EventBus().emit('cash_closings_changed');
        },
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo cash_closings sync: $e");
    }

    // 20. Đồng bộ ADJUSTMENT ENTRIES (Bút toán điều chỉnh)
    try {
      _subscribeToCollection(
        collection: 'adjustment_entries',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteAdjustmentEntryByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1;
              _convertTimestampFields(data);
              await db.upsertAdjustmentEntry(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync adjustment_entry $docId: $e");
          }
        },
        onBatchDone: onDataChanged,
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo adjustment_entries sync: $e");
    }

    // 21. Đồng bộ PURCHASE ORDERS (Đơn đặt hàng NCC)
    try {
      _subscribeToCollection(
        collection: 'purchase_orders',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deletePurchaseOrderByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1;
              _convertTimestampFields(data);
              await db.upsertPurchaseOrder(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync purchase_order $docId: $e");
          }
        },
        onBatchDone: onDataChanged,
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo purchase_orders sync: $e");
    }

    // 22. Đồng bộ PAYMENT INTENTS (Yêu cầu thanh toán)
    // FIX: Thêm real-time sync cho payment_intents để 2 máy cùng thấy các giao dịch chờ thanh toán
    try {
      _subscribeToCollection(
        collection: 'payment_intents',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deletePaymentIntentByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1;
              _convertTimestampFields(data);
              await db.upsertPaymentIntent(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync payment_intent $docId: $e");
          }
        },
        onBatchDone: () {
          onDataChanged();
          // Emit event để PaymentIntentService reload data
          EventBus().emit('payment_intents_changed');
        },
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo payment_intents sync: $e");
    }

    // 22b. Đồng bộ PAYMENT REQUESTS (Yêu cầu đóng tiền)
    try {
      _subscribeToCollection(
        collection: 'payment_requests',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deletePaymentRequestByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1;
              _convertTimestampFields(data);
              await db.upsertPaymentRequest(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync payment_request $docId: $e");
          }
        },
        onBatchDone: () {
          debugPrint(
            '✅ [SyncService] Sync xong payment_requests → emit payment_requests_changed',
          );
          EventBus().emit('payment_requests_changed');
        },
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo payment_requests sync: $e");
    }

    // 23. Đồng bộ WORK SCHEDULES (Lịch làm việc nhân viên)
    try {
      _subscribeToCollection(
        collection: 'work_schedules',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              // Không xóa hẳn, chỉ bỏ qua
              debugPrint("Work schedule $docId marked as deleted");
            } else {
              // Lấy userId từ docId (format: staff_<userId>_<shopId>)
              String? userId;
              if (docId.startsWith('staff_')) {
                final parts = docId.split('_');
                if (parts.length >= 2) {
                  userId = parts[1];
                }
              }
              if (userId != null && userId.isNotEmpty) {
                final scheduleData = Map<String, dynamic>.from(data);
                _convertTimestampFields(scheduleData);
                await db.upsertWorkSchedule(userId, scheduleData);
                debugPrint("✅ Synced work_schedule for user $userId");
              }
            }
          } catch (e) {
            debugPrint("Lỗi sync work_schedule $docId: $e");
          }
        },
        onBatchDone: () {
          onDataChanged();
          EventBus().emit('work_schedules_changed');
        },
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo work_schedules sync: $e");
    }

    // 24. Đồng bộ EMPLOYEE SALARY SETTINGS (Cài đặt lương nhân viên)
    try {
      _subscribeToCollection(
        collection: 'employee_salary_settings',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteEmployeeSalarySettingsByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1;
              _convertTimestampFields(data);
              await db.upsertEmployeeSalarySettings(data);
              debugPrint(
                "✅ Synced employee_salary_setting for ${data['staffId']}",
              );
            }
          } catch (e) {
            debugPrint("Lỗi sync employee_salary_setting $docId: $e");
          }
        },
        onBatchDone: () {
          onDataChanged();
          EventBus().emit('employee_salary_settings_changed');
        },
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo employee_salary_settings sync: $e");
    }

    // === MULTI-INDUSTRY EXPANSION - Phase 1 (v75) ===

    // 25. Đồng bộ PRODUCT CATEGORIES (Danh mục sản phẩm)
    try {
      // Categories được lưu trong subcollection của shops
      if (!_canSubscribeShopSubcollection(
        subcollection: 'product_categories',
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
      )) {
        _subscriptionStatus['product_categories'] = false;
        _collectionRefreshers.remove('product_categories');
        debugPrint(
          '⏭️ Skipping product_categories subscription due to permissions',
        );
      } else {
        final currentShopId = shopId;
        if (currentShopId == null || currentShopId.isEmpty) {
          _subscriptionStatus['product_categories'] = false;
          _collectionRefreshers.remove('product_categories');
          debugPrint('⚠️ Skipping product_categories polling: missing shopId');
        } else {
          _subscriptionStatus['product_categories'] = true;
          bool isPolling = false;

          Future<void> pollProductCategories({
            String reason = 'initial',
          }) async {
            if (isPolling) return;
            isPolling = true;
            try {
              _logCollectionFetch(
                collection: 'product_categories',
                reason: reason,
              );
              Query<Map<String, dynamic>> query = _db
                  .collection('shops')
                  .doc(currentShopId)
                  .collection('product_categories');

              final cursorMs = _realtimeCursorMs(
                'product_categories',
                currentShopId,
              );
              if (cursorMs > 0) {
                query = query.where(
                  'updatedAt',
                  isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(cursorMs),
                );
              }

              final snapshot = await _getQueryWithTimeout(
                query: query,
                context: 'product_categories_poll',
                limit: _collectionPollLimit,
              );
              if (snapshot.docs.isEmpty) return;

              final db = DBHelper();
              var maxCursorMs = 0;
              for (final doc in snapshot.docs) {
                try {
                  final docId = doc.id;
                  final data = doc.data();
                  final docCursorMs = _extractRealtimeCursorMs(data);
                  if (docCursorMs > maxCursorMs) {
                    maxCursorMs = docCursorMs;
                  }

                  if (data['isActive'] == false) {
                    await db.rawUpdate(
                      'UPDATE product_categories SET isActive = 0 WHERE firestoreId = ?',
                      [docId],
                    );
                  } else {
                    data['firestoreId'] = docId;
                    data['shopId'] = currentShopId;
                    data['isSynced'] = 1;
                    _convertTimestampFields(data);
                    await db.upsertProductCategory(data);
                  }
                } catch (e) {
                  debugPrint("Lỗi sync product_category ${doc.id}: $e");
                }
              }

              if (maxCursorMs > 0) {
                await _saveRealtimeCursorMs(
                  collection: 'product_categories',
                  shopId: currentShopId,
                  cursorMs: maxCursorMs,
                );
              }

              unawaited(
                FirebaseUsageStatsService.logRealtimeRead(
                  collection: 'product_categories',
                  shopId: currentShopId,
                  readCount: snapshot.docs.length,
                ),
              );
              onDataChanged();
              EventBus().emit('product_categories_changed');
            } catch (e) {
              debugPrint('Sync error in product_categories polling: $e');
            } finally {
              isPolling = false;
            }
          }

          _collectionRefreshers['product_categories'] = () =>
              pollProductCategories(reason: 'manual_refresh');
          unawaited(pollProductCategories());
        }
      }
    } catch (e) {
      debugPrint("Lỗi khởi tạo product_categories sync: $e");
    }

    // 26. Đồng bộ PRODUCT VARIANTS (Biến thể sản phẩm)
    try {
      _subscribeToCollection(
        collection: 'product_variants',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['isActive'] == false) {
              await db.rawUpdate(
                'UPDATE product_variants SET isActive = 0 WHERE firestoreId = ?',
                [docId],
              );
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1;
              _convertTimestampFields(data);
              await db.upsertProductVariant(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync product_variant $docId: $e");
          }
        },
        onBatchDone: () {
          onDataChanged();
          EventBus().emit('product_variants_changed');
        },
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo product_variants sync: $e");
    }

    // 27. Đồng bộ SALES RETURNS (Phiếu trả hàng)
    try {
      _subscribeToCollection(
        collection: 'sales_returns',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              // Phiếu trả hàng bị xóa trên cloud → xóa header + cascade item
              // (item là collection riêng, listener riêng — không tự dọn).
              await db.deleteSalesReturnByFirestoreId(docId);
              await db.deleteSalesReturnItemsByReturnFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1;
              _convertTimestampFields(data);
              await db.upsertSalesReturn(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync sales_return $docId: $e");
          }
        },
        onBatchDone: () {
          debugPrint(
            '✅ [SyncService] Sync xong sales_returns → emit sales_returns_changed',
          );
          EventBus().emit('sales_returns_changed');
        },
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo sales_returns sync: $e");
    }

    // 28. Đồng bộ SALES RETURN ITEMS (Chi tiết trả hàng)
    try {
      _subscribeToCollection(
        collection: 'sales_return_items',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteSalesReturnItemByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1;
              await db.upsertSalesReturnItem(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync sales_return_item $docId: $e");
          }
        },
        onBatchDone: () {
          onDataChanged();
        },
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo sales_return_items sync: $e");
    }

    // 28b. Đồng bộ PRICE CATALOG ITEMS (Danh mục giá từ hoá đơn NCC)
    try {
      _subscribeToCollection(
        collection: 'price_catalog_items',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            data['firestoreId'] = docId;
            data['isSynced'] = 1;
            _convertTimestampFields(data);
            // Xoá MỀM: vẫn upsert (giữ cờ deleted) thay vì xoá hẳn — bản ghi
            // còn đó để máy khác không "hồi sinh" mặt hàng đã bỏ.
            await db.upsertPriceCatalogItem(data);
          } catch (e) {
            debugPrint("Lỗi sync price_catalog_item $docId: $e");
          }
        },
        onBatchDone: () {
          onDataChanged();
          EventBus().emit('price_catalog_changed');
        },
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo price_catalog_items sync: $e");
    }

    // 29. Đồng bộ SALVAGE PHONES (Kho máy xác)
    try {
      _subscribeToCollection(
        collection: 'salvage_phones',
        shopId: shopId,
        permissions: permissions,
        role: role,
        isSuperAdmin: isSuperAdmin,
        onChanged: (data, docId) async {
          try {
            final db = DBHelper();
            if (data['deleted'] == true || data['deleted'] == 1) {
              await db.deleteSalvagePhoneByFirestoreId(docId);
            } else {
              data['firestoreId'] = docId;
              data['isSynced'] = 1;
              _convertTimestampFields(data);
              await db.upsertSalvagePhone(data);
            }
          } catch (e) {
            debugPrint("Lỗi sync salvage_phone $docId: $e");
          }
        },
        onBatchDone: onDataChanged,
      );
    } catch (e) {
      debugPrint("Lỗi khởi tạo salvage_phones sync: $e");
    }

    // storage_locations đã được đồng bộ trong critical section — không cần lại ở đây

    PerfMonitor.stop('deferredSync');
    debugPrint(
      "✅ Deferred sync done — total ${_subscriptions.length} subscriptions active "
      "for ${isSuperAdmin ? 'super admin' : 'shop: $shopId'}",
    );
    debugPrint("📊 Subscription status: $_subscriptionStatus");
  }

  /// Hàm helper để quản lý subscription an toàn
  static void _subscribeToCollection({
    required String collection,
    String? shopId,
    required Map<String, dynamic> permissions,
    required String role,
    required bool isSuperAdmin,
    required Future<void> Function(Map<String, dynamic> data, String docId)
    onChanged,
    required VoidCallback onBatchDone,
  }) {
    if (!_canSubscribeCollection(
      collection: collection,
      permissions: permissions,
      role: role,
      isSuperAdmin: isSuperAdmin,
    )) {
      debugPrint(
        '⏭️ Skipping subscribe to $collection - not allowed for role=$role',
      );
      _subscriptionStatus[collection] = false;
      _collectionRefreshers.remove(collection);
      return;
    }

    // Skip nếu shop đang bị xóa
    if (shopId != null && ShopDeletionService.isShopBeingDeleted(shopId)) {
      debugPrint(
        "⏭️ Skipping subscribe to $collection - shop $shopId is being deleted",
      );
      return;
    }

    debugPrint(
      '📉 $collection: using controlled get() fetch instead of snapshots()',
    );
    _subscriptionStatus[collection] = true;

    bool isPolling = false;

    Future<void> pollCollection({String reason = 'initial'}) async {
      if (isPolling) return;
      if (!ConnectivityService.instance.isOnline) return;
      isPolling = true;
      try {
        if (shopId != null && ShopDeletionService.isShopBeingDeleted(shopId)) {
          debugPrint(
            "⏭️ Skipping poll for $collection - shop $shopId is being deleted",
          );
          return;
        }

        _logCollectionFetch(collection: collection, reason: reason);

        Query<Map<String, dynamic>> query = _db.collection(collection);
        if (shopId != null) {
          query = query.where('shopId', isEqualTo: shopId);

          if (_canUseIncrementalRealtime(
            collection: collection,
            shopId: shopId,
          )) {
            final cursorMs = _realtimeCursorMs(collection, shopId);
            query = query.where(
              'updatedAt',
              isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(cursorMs),
            );
          }
        }

        final snapshot = await _getQueryWithTimeout(
          query: query,
          context: 'poll_$collection',
          limit: _collectionPollLimit,
        );
        if (snapshot.docs.isEmpty) {
          return;
        }

        debugPrint(
          "📥 Polled $collection: ${snapshot.docs.length} docs (limit=$_collectionPollLimit)",
        );

        var maxCursorMs = 0;
        for (final doc in snapshot.docs) {
          var data = doc.data();
          data = EncryptionService.decryptMap(data);

          final cursorMs = _extractRealtimeCursorMs(data);
          if (cursorMs > maxCursorMs) {
            maxCursorMs = cursorMs;
          }

          await onChanged(data, doc.id);
        }

        if (shopId != null && maxCursorMs > 0) {
          await _saveRealtimeCursorMs(
            collection: collection,
            shopId: shopId,
            cursorMs: maxCursorMs,
          );
        }

        unawaited(
          FirebaseUsageStatsService.logRealtimeRead(
            collection: collection,
            shopId: shopId,
            readCount: snapshot.docs.length,
          ),
        );

        onBatchDone();
      } catch (e) {
        final errorStr = e.toString();
        final isTimeout =
            e is TimeoutException || errorStr.contains('TimeoutException');
        if (isTimeout) {
          debugPrint("⏱️ Poll timeout $collection (transient, will retry)");
        } else {
          debugPrint("❌ Poll sync error in $collection: $errorStr");
        }

        final isPermissionError =
            errorStr.contains('permission-denied') ||
            errorStr.contains('PERMISSION_DENIED') ||
            errorStr.contains('Missing or insufficient permissions');

        final isMissingIndexError =
            errorStr.contains('failed-precondition') &&
            (errorStr.contains('requires an index') ||
                errorStr.contains('missing index') ||
                errorStr.contains('create it here'));

        if (isPermissionError) {
          _subscriptionStatus[collection] = false;
          _collectionRefreshers.remove(collection);
          EventBus().emit('permission_denied:$collection');
          debugPrint(
            "⚠️ Permission denied while polling $collection - waiting for next init/re-auth",
          );
          return;
        }

        if (isMissingIndexError && shopId != null) {
          _incrementalRealtimeDisabled.add(collection);
          debugPrint(
            "⚠️ Missing index for incremental poll $collection, next poll will fallback without updatedAt cursor",
          );
        }
      } finally {
        isPolling = false;
      }
    }

    _collectionRefreshers[collection] = () =>
        pollCollection(reason: 'manual_refresh');
    unawaited(pollCollection());
  }

  /// Helper để xóa record local theo firestoreId khi cloud record đã bị soft-delete
  static Future<void> _deleteLocalByFirestoreId(
    DBHelper db,
    String collection,
    String firestoreId,
  ) async {
    try {
      switch (collection) {
        case 'repairs':
          await db.deleteRepairByFirestoreId(firestoreId);
          break;
        case 'products':
          await db.deleteProductByFirestoreId(firestoreId);
          break;
        case 'sales':
          await db.deleteSaleByFirestoreId(firestoreId);
          break;
        case 'expenses':
          await db.deleteExpenseByFirestoreId(firestoreId);
          break;
        case 'debts':
          await db.deleteDebtByFirestoreId(firestoreId);
          break;
        case 'debt_payments':
          await db.deleteDebtPaymentByFirestoreId(firestoreId);
          break;
        case 'attendance':
          await db.deleteAttendanceByFirestoreId(firestoreId);
          break;
        case 'quick_input_codes':
          await db.deleteQuickInputCodeByFirestoreId(firestoreId);
          break;
        case 'supplier_payments':
          await db.deleteSupplierPaymentByFirestoreId(firestoreId);
          break;
        case 'repair_partner_payments':
          await db.deleteRepairPartnerPaymentByFirestoreId(firestoreId);
          break;
        case 'customers':
          await db.deleteCustomerByFirestoreId(firestoreId);
          break;
        case 'suppliers':
          await db.deleteSupplierByFirestoreId(firestoreId);
          break;
        case 'repair_partners':
          await db.deleteRepairPartnerByFirestoreId(firestoreId);
          break;
        case 'repair_parts':
          await db.deleteRepairPartByFirestoreId(firestoreId);
          break;
        case 'payment_intents':
          await db.deletePaymentIntentByFirestoreId(firestoreId);
          break;
        case 'payment_requests':
          await db.deletePaymentRequestByFirestoreId(firestoreId);
          break;
        case 'leave_requests':
          await db.deleteLeaveRequestByFirestoreId(firestoreId);
          break;
        case 'import_orders':
          await db.deleteImportOrderByFirestoreId(firestoreId);
          break;
        case 'import_order_items':
          await db.deleteImportOrderItemByFirestoreId(firestoreId);
          break;
        case 'cash_closings':
          await db.deleteCashClosingByFirestoreId(firestoreId);
          final dk = _dateKeyFromClosingDocId(firestoreId);
          if (dk != null) await db.deleteCashClosingByDateKey(dk);
          break;
      }
      debugPrint(
        "  -> Deleted local $collection record: $firestoreId (soft-deleted on cloud)",
      );
    } catch (e) {
      debugPrint("  -> Error deleting local $collection $firestoreId: $e");
    }
  }

  static Future<void> cancelAllSubscriptions() async {
    debugPrint(
      '🔴 Canceling all ${_subscriptions.length} subscriptions and ${_pollingTimers.length} polling timers...',
    );
    for (var sub in _subscriptions) {
      await sub.cancel();
    }
    for (final timer in _pollingTimers) {
      timer.cancel();
    }
    _subscriptions.clear();
    _pollingTimers.clear();
    _collectionRefreshers.clear();
    _collectionFetchCounts.clear();
    _subscriptionStatus.clear();
    _isInitialized = false;
    _currentShopId = null;
    _lastUserPermissionSignature = null;
    _lastShopRestrictionSignature = null;
    _lastRealtimeInitSignature = null;
    debugPrint('✅ All subscriptions cancelled');
  }

  /// Reset tất cả sync timestamps — force full re-download lần sau
  /// Dùng khi: đổi shop, force reinit, clear data
  static Future<void> resetSyncTimestamps() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where(
          (k) =>
              k.startsWith(_lastSyncPrefix) ||
              k.startsWith(_realtimeCursorPrefix),
        )
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
    _lastDownloadTime = null;
    _realtimeCursorCache.clear();
    _incrementalRealtimeDisabled.clear();
    debugPrint('🔄 Reset ${keys.length} sync timestamps/cursors');
  }

  /// Force reinitialize real-time sync (useful when sync appears broken)
  static Future<void> forceReinitializeSync() async {
    debugPrint('🔄 Force reinitializing real-time sync...');
    await cancelAllSubscriptions();
    // Reset sync timestamps để force full re-download
    await resetSyncTimestamps();

    if (_onDataChangedCallback != null) {
      await initRealTimeSync(_onDataChangedCallback!);
    } else {
      debugPrint('⚠️ No callback stored, cannot reinitialize');
    }
  }

  /// Sync payment-related data immediately after payment execution
  /// Targets: payment_intents, debt_payments, expenses, financial_activity_log
  /// Much faster than syncAllToCloud() since it only syncs payment-related tables
  static Future<void> syncPaymentRelatedData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final String? shopId = await UserService.getCurrentShopId();
      if (shopId == null) return;

      // FIX: Super admin có shopId → cho phép sync (không block nữa)

      final dbHelper = DBHelper();
      debugPrint('⚡ syncPaymentRelatedData: starting targeted sync...');

      // 1. Sync payment_intents
      try {
        final paymentIntents = await dbHelper.getPaymentIntentsForSync();
        if (paymentIntents.isNotEmpty) {
          final WriteBatch batch = _db.batch();
          for (var intentMap in paymentIntents) {
            final firestoreId = intentMap['firestoreId'];
            final isSynced =
                intentMap['isSynced'] == 1 || intentMap['isSynced'] == true;
            if (firestoreId != null &&
                firestoreId.toString().isNotEmpty &&
                isSynced)
              continue;

            final data = Map<String, dynamic>.from(intentMap);
            data['shopId'] = shopId;
            data['deleted'] = data['deleted'] == 1 || data['deleted'] == true;
            final localId = data['id'];
            data.remove('id');

            final docId =
                firestoreId ??
                "pi_${data['intentId'] ?? data['createdAt']}_${data['type'] ?? 'unknown'}";
            batch.set(
              _db.collection('payment_intents').doc(docId),
              data,
              SetOptions(merge: true),
            );
            await dbHelper.updatePaymentIntentSynced(localId, docId);
          }
          await batch.commit();
          debugPrint('  -> Synced ${paymentIntents.length} payment intents');
        }
      } catch (e) {
        debugPrint('  -> Error syncing payment_intents: $e');
      }

      // 2. Sync debt_payments
      try {
        final debtPayments = await dbHelper.getAllDebtPaymentsForSync();
        if (debtPayments.isNotEmpty) {
          final WriteBatch batch = _db.batch();
          int count = 0;
          for (var dp in debtPayments) {
            final firestoreId = dp['firestoreId'];
            final isSynced = dp['isSynced'] == 1 || dp['isSynced'] == true;
            if (firestoreId != null &&
                firestoreId.toString().isNotEmpty &&
                isSynced)
              continue;

            final data = Map<String, dynamic>.from(dp);
            data['shopId'] = shopId;
            final localId = data['id'];
            data.remove('id');

            final docId =
                firestoreId ??
                "dp_${data['debtId']}_${data['paidAt'] ?? data['createdAt']}";
            batch.set(
              _db.collection('debt_payments').doc(docId),
              data,
              SetOptions(merge: true),
            );
            await dbHelper.updateDebtPaymentSynced(localId as int, docId);
            count++;
          }
          if (count > 0) {
            await batch.commit();
            debugPrint('  -> Synced $count debt payments');
          }
        }
      } catch (e) {
        debugPrint('  -> Error syncing debt_payments: $e');
      }

      // 3. Sync debts (status may have changed after payment)
      try {
        final debts = await dbHelper.getAllDebts();
        final unsyncedDebts = debts
            .where((d) => d['isSynced'] != 1 && d['isSynced'] != true)
            .toList();
        if (unsyncedDebts.isNotEmpty) {
          final WriteBatch batch = _db.batch();
          int count = 0;
          for (var debt in unsyncedDebts) {
            final firestoreId = debt['firestoreId'];
            if (firestoreId == null || firestoreId.toString().isEmpty) continue;

            final data = Map<String, dynamic>.from(debt);
            data['shopId'] = shopId;
            data['deleted'] = data['deleted'] == 1 || data['deleted'] == true;
            data.remove('id');

            batch.set(
              _db.collection('debts').doc(firestoreId),
              data,
              SetOptions(merge: true),
            );
            count++;
          }
          if (count > 0) {
            await batch.commit();
            debugPrint('  -> Synced $count debts');
          }
        }
      } catch (e) {
        debugPrint('  -> Error syncing debts: $e');
      }

      // 4. Sync expenses (in case payment created an expense)
      try {
        final expenses = await dbHelper.getAllExpensesForSync();
        final unsyncedExpenses = expenses
            .where((e) => e.isSynced != 1)
            .toList();
        if (unsyncedExpenses.isNotEmpty) {
          final WriteBatch batch = _db.batch();
          int count = 0;
          for (var expense in unsyncedExpenses) {
            final data = expense.toMap();
            data['shopId'] = shopId;
            data['deleted'] = data['deleted'] == 1 || data['deleted'] == true;
            data.remove('id');

            final docId =
                expense.firestoreId ?? "exp_${expense.date}_${expense.amount}";
            batch.set(
              _db.collection('expenses').doc(docId),
              data,
              SetOptions(merge: true),
            );

            // Mark as synced
            final updatedExpense = Expense.fromMap({
              ...expense.toMap(),
              'firestoreId': docId,
              'isSynced': 1,
            });
            await dbHelper.updateExpense(updatedExpense);
            count++;
          }
          if (count > 0) {
            await batch.commit();
            debugPrint('  -> Synced $count expenses');
          }
        }
      } catch (e) {
        debugPrint('  -> Error syncing expenses: $e');
      }

      // 5. Sync financial_activity_log
      try {
        final activities = await dbHelper.getUnsyncedFinancialActivities();
        if (activities.isNotEmpty) {
          final WriteBatch batch = _db.batch();
          int count = 0;
          for (var act in activities) {
            final data = Map<String, dynamic>.from(act);
            data['shopId'] = shopId;
            final localId = data['id'];
            data.remove('id');

            final docId =
                data['firestoreId'] ??
                "fal_${data['createdAt']}_${data['activityType'] ?? 'unknown'}";
            batch.set(
              _db.collection('financial_activity_log').doc(docId),
              data,
              SetOptions(merge: true),
            );

            // Mark as synced
            await dbHelper.updateFinancialActivitySynced(localId as int, docId);
            count++;
          }
          if (count > 0) {
            await batch.commit();
            debugPrint('  -> Synced $count financial activities');
          }
        }
      } catch (e) {
        debugPrint('  -> Error syncing financial_activity_log: $e');
      }

      // 6. Sync supplier_payments and repair_partner_payments
      try {
        final supplierPayments = await dbHelper.getSupplierPaymentsForSync();
        final unsyncedSP = supplierPayments
            .where((sp) => sp['isSynced'] != 1 && sp['isSynced'] != true)
            .toList();
        if (unsyncedSP.isNotEmpty) {
          final WriteBatch batch = _db.batch();
          int count = 0;
          final List<Map<String, dynamic>> toMarkSynced = [];
          for (var sp in unsyncedSP) {
            final firestoreId = sp['firestoreId'];
            final data = Map<String, dynamic>.from(sp);
            data['shopId'] = shopId;
            data['deleted'] = data['deleted'] == 1 || data['deleted'] == true;
            final localId = data['id'];
            data.remove('id');
            data.remove('isSynced');

            final docId =
                firestoreId ?? "sp_${data['supplierId']}_${data['paidAt']}";
            batch.set(
              _db.collection('supplier_payments').doc(docId),
              data,
              SetOptions(merge: true),
            );
            toMarkSynced.add({'localId': localId, 'firestoreId': docId});
            count++;
          }
          if (count > 0) {
            await batch.commit();
            // Mark as synced in local DB after successful Firestore commit
            for (var item in toMarkSynced) {
              await dbHelper.updateSupplierPayment(item['localId'] as int, {
                'isSynced': 1,
                'firestoreId': item['firestoreId'],
              });
            }
            debugPrint('  -> Synced $count supplier payments');
          }
        }
      } catch (e) {
        debugPrint('  -> Error syncing supplier_payments: $e');
      }

      try {
        final partnerPayments = await dbHelper
            .getRepairPartnerPaymentsForSync();
        final unsyncedPP = partnerPayments
            .where((pp) => pp['isSynced'] != 1 && pp['isSynced'] != true)
            .toList();
        if (unsyncedPP.isNotEmpty) {
          final WriteBatch batch = _db.batch();
          int count = 0;
          final List<Map<String, dynamic>> toMarkSynced = [];
          for (var pp in unsyncedPP) {
            final firestoreId = pp['firestoreId'];
            final data = Map<String, dynamic>.from(pp);
            data['shopId'] = shopId;
            data['deleted'] = data['deleted'] == 1 || data['deleted'] == true;
            final localId = data['id'];
            data.remove('id');
            data.remove('isSynced');

            final docId =
                firestoreId ?? "rpp_${data['partnerId']}_${data['paidAt']}";
            batch.set(
              _db.collection('repair_partner_payments').doc(docId),
              data,
              SetOptions(merge: true),
            );
            toMarkSynced.add({'localId': localId, 'firestoreId': docId});
            count++;
          }
          if (count > 0) {
            await batch.commit();
            // Mark as synced in local DB after successful Firestore commit
            for (var item in toMarkSynced) {
              await dbHelper.updateRepairPartnerPayment(
                item['localId'] as int,
                {'isSynced': 1, 'firestoreId': item['firestoreId']},
              );
            }
            debugPrint('  -> Synced $count repair partner payments');
          }
        }
      } catch (e) {
        debugPrint('  -> Error syncing repair_partner_payments: $e');
      }

      debugPrint('⚡ syncPaymentRelatedData: completed');
    } catch (e) {
      debugPrint('⚡ syncPaymentRelatedData error: $e');
    }
  }

  /// Sync repair data immediately after repair status changes
  /// Targets: repairs table only - much faster than syncAllToCloud()
  /// Ensures status updates (chờ duyệt, giao máy, etc.) sync to other devices immediately
  static Future<void> syncRepairData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final String? shopId = await UserService.getCurrentShopId();
      if (shopId == null) return;

      // FIX: Super admin có shopId → cho phép sync (không block nữa)

      final dbHelper = DBHelper();
      debugPrint('⚡ syncRepairData: starting targeted repair sync...');

      // Sync unsynced repairs
      // OPT: Dùng getUnsyncedRepairs() thay vì getAllRepairs().where(!isSynced)
      // để tránh load toàn bộ records vào RAM chỉ để filter.
      final unsyncedRepairs = (await dbHelper.getUnsyncedRepairs())
          .where((r) => !r.isSynced || _hasLocalImagePath(r.imagePath))
          .toList();

      if (unsyncedRepairs.isEmpty) {
        debugPrint('⚡ syncRepairData: no unsynced repairs');
        return;
      }

      debugPrint(
        '⚡ syncRepairData: found ${unsyncedRepairs.length} unsynced repairs',
      );
      final WriteBatch batch = _db.batch();
      final List<Repair> toMarkSynced = [];

      for (var r in unsyncedRepairs) {
        try {
          Map<String, dynamic> data = r.toMap();
          _normalizeRepairPayload(data);
          data['shopId'] = shopId;
          data.remove('id');
          data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
          data.remove('isSynced');
          data.remove('firestoreId');

          // Upload local images if needed
          if (_hasLocalImagePath(r.imagePath)) {
            try {
              data['imagePath'] = await _normalizeRepairImagePathsForCloud(
                r.imagePath,
                r.createdAt,
              ).timeout(const Duration(seconds: 15));
            } catch (e) {
              debugPrint(
                '⚡ syncRepairData: image upload incomplete for ${r.id}, keep local data for retry: $e',
              );
              continue;
            }
          }

          final docId =
              r.firestoreId ?? "repair_${r.createdAt}_${r.phone}_${r.id ?? 0}";
          batch.set(
            _db.collection('repairs').doc(docId),
            data,
            SetOptions(merge: true),
          );

          r.firestoreId = docId;
          r.imagePath = data['imagePath'];
          toMarkSynced.add(r);
        } catch (e) {
          debugPrint('⚡ syncRepairData: error preparing repair ${r.id}: $e');
        }
      }

      try {
        await batch.commit();
        for (var r in toMarkSynced) {
          r.isSynced = true;
          await dbHelper.updateRepair(r);
        }
        debugPrint(
          '⚡ syncRepairData: ✅ synced ${toMarkSynced.length} repairs to cloud',
        );
      } catch (e) {
        debugPrint(
          '⚡ syncRepairData: ❌ batch commit failed: $e - will retry next sync',
        );
      }
    } catch (e) {
      debugPrint('⚡ syncRepairData error: $e');
    }
  }

  /// One-time fix: backfill shopId for KiotViet-imported records with NULL shopId,
  /// then reset isSynced=0 for all sales + products so they get pushed to Firestore.
  static Future<Map<String, int>> forceResyncKiotVietData() async {
    final shopId = await UserService.getCurrentShopId();
    if (shopId == null) return {};
    final db = DBHelper();

    final salesBackfilled = await db.backfillShopId('sales', shopId);
    final productsBackfilled = await db.backfillShopId('products', shopId);
    final salesReset = await db.markAllUnsynced('sales');
    final productsReset = await db.markAllUnsynced('products');

    debugPrint(
      'forceResyncKiotVietData: backfilled sales=$salesBackfilled, products=$productsBackfilled'
      ' | reset isSynced: sales=$salesReset, products=$productsReset',
    );

    await syncAllToCloud(force: true);

    return {
      'salesBackfilled': salesBackfilled,
      'productsBackfilled': productsBackfilled,
      'salesReset': salesReset,
      'productsReset': productsReset,
    };
  }

  /// Đẩy dữ liệu từ Local lên Cloud (Dùng khi có mạng trở lại)
  static Future<void> syncAllToCloud({bool force = false}) async {
    final now = DateTime.now();
    if (_isSyncingAllToCloud) {
      debugPrint('⏭️ syncAllToCloud: already running, skip duplicate trigger');
      return;
    }
    if (!force && _lastSyncAllToCloudAt != null) {
      final elapsed = now.difference(_lastSyncAllToCloudAt!);
      if (elapsed < _syncAllToCloudCooldown) {
        debugPrint(
          '⏭️ syncAllToCloud: cooldown active (${_syncAllToCloudCooldown.inSeconds - elapsed.inSeconds}s left)',
        );
        return;
      }
    }

    _isSyncingAllToCloud = true;
    _lastSyncAllToCloudAt = now;
    debugPrint("Bắt đầu syncAllToCloud...");
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("Không có user, bỏ qua syncAllToCloud");
        return;
      }

      final String? shopId = await UserService.getCurrentShopId();
      final bool isSuperAdmin = UserService.isCurrentUserSuperAdmin();

      // LOG QUAN TRỌNG: Hiển thị shopId được sử dụng
      debugPrint(
        "⚡ syncAllToCloud: user=${user.uid}, email=${user.email}, shopId=$shopId, isSuperAdmin=$isSuperAdmin",
      );

      // Cần có shopId để upload (super admin chỉ xem, không tạo/sửa data)
      if (shopId == null) {
        if (isSuperAdmin) {
          debugPrint(
            "⚠️ Super admin chưa chọn shop hoặc chỉ được xem, bỏ qua syncAllToCloud",
          );
        } else {
          debugPrint("Không có shopId, bỏ qua syncAllToCloud");
        }
        return;
      }

      // FIX: Super admin CÓ shopId (đã chọn shop) → cho phép upload data
      // (Trước đây block hoàn toàn → gây tích lũy records chưa đồng bộ)

      final dbHelper = DBHelper();

      // Chỉ đẩy những đơn hàng CHƯA đồng bộ hoặc CÓ thay đổi hình ảnh
      {
        // OPT: Dùng getUnsyncedRepairs() thay vì getAllRepairs().filter()
        // để tránh load toàn bộ object vào RAM.
        final repairs = await dbHelper.getUnsyncedRepairs();
        debugPrint("syncAllToCloud: có ${repairs.length} repairs cần sync");
        const repairBatchLimit = 400;
        WriteBatch repairBatch = _db.batch();
        List<Repair> repairsToMarkSynced = [];
        int repairBatchCount = 0;
        int totalRepairsSynced = 0;

        Future<void> commitRepairsBatch() async {
          if (repairsToMarkSynced.isEmpty) return;
          try {
            await repairBatch.commit();
            for (var r in repairsToMarkSynced) {
              try {
                r.isSynced = true;
                await dbHelper.updateRepair(r);
              } catch (_) {}
            }
            totalRepairsSynced += repairsToMarkSynced.length;
            debugPrint(
              "✅ Committed ${repairsToMarkSynced.length} repairs batch to cloud",
            );
          } catch (e) {
            debugPrint(
              "❌ Batch commit repairs failed: $e - repairs will retry next sync",
            );
          }
          repairBatch = _db.batch();
          repairsToMarkSynced = [];
          repairBatchCount = 0;
        }

        for (var r in repairs) {
          if (r.isSynced && !_hasLocalImagePath(r.imagePath)) continue;
          try {
            Map<String, dynamic> data = r.toMap();
            _normalizeRepairPayload(data);
            data['shopId'] = shopId;
            data.remove('id');
            data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
            data.remove('isSynced');
            data.remove('firestoreId');
            if (_hasLocalImagePath(r.imagePath)) {
              try {
                data['imagePath'] = await _normalizeRepairImagePathsForCloud(
                  r.imagePath,
                  r.createdAt,
                ).timeout(const Duration(seconds: 30));
              } catch (e) {
                debugPrint(
                  'Upload ảnh repair ${r.id} chưa hoàn tất, giữ local để retry: $e',
                );
                continue;
              }
            }
            final docId =
                r.firestoreId ??
                "repair_${r.createdAt}_${r.phone}_${r.id ?? 0}";
            repairBatch.set(
              _db.collection('repairs').doc(docId),
              data,
              SetOptions(merge: true),
            );
            r.firestoreId = docId;
            r.imagePath = data['imagePath'];
            repairsToMarkSynced.add(r);
            repairBatchCount++;
            if (repairBatchCount >= repairBatchLimit)
              await commitRepairsBatch();
          } catch (e) {
            debugPrint("Lỗi sync repair ${r.id}: $e");
          }
        }
        await commitRepairsBatch();
        debugPrint("✅ Synced $totalRepairsSynced repairs to cloud");
      }

      // Sync SALES
      final sales = await dbHelper.getAllSales();
      debugPrint("syncAllToCloud: có ${sales.length} sales cần sync");
      {
        const batchLimit = 400;
        WriteBatch saleBatch = _db.batch();
        final List<SaleOrder> salesToMarkSynced = [];
        int batchCount = 0;
        int totalSynced = 0;

        Future<void> commitSalesBatch() async {
          if (salesToMarkSynced.isEmpty) return;
          try {
            await saleBatch.commit();
            final saleIds = salesToMarkSynced
                .map((s) => s.id)
                .whereType<int>()
                .toList();
            if (saleIds.isNotEmpty) {
              final ph = List.filled(saleIds.length, '?').join(',');
              try {
                await (await dbHelper.database).rawUpdate(
                  'UPDATE sales SET isSynced = 1 WHERE id IN ($ph)',
                  saleIds,
                );
              } catch (e) {
                debugPrint(
                  "⚠️ Bulk sales isSynced update failed, fallback per-item: $e",
                );
                for (var s in salesToMarkSynced) {
                  try {
                    s.isSynced = true;
                    await dbHelper.updateSale(s);
                  } catch (_) {}
                }
              }
            }
            totalSynced += salesToMarkSynced.length;
            debugPrint(
              "✅ Committed ${salesToMarkSynced.length} sales batch to cloud",
            );
          } catch (e) {
            debugPrint(
              "❌ Batch commit sales failed: $e - sales will retry next sync",
            );
          }
          saleBatch = _db.batch();
          salesToMarkSynced.clear();
          batchCount = 0;
        }

        for (var s in sales) {
          if (s.isSynced) continue;
          try {
            Map<String, dynamic> data = s.toMap();
            data['shopId'] = shopId;
            data.remove('id');
            data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
            data.remove('isSynced');
            data.remove('firestoreId');
            final docId =
                s.firestoreId ?? "sale_${s.soldAt}_${s.phone}_${s.id ?? 0}";
            saleBatch.set(
              _db.collection('sales').doc(docId),
              data,
              SetOptions(merge: true),
            );
            s.firestoreId = docId;
            salesToMarkSynced.add(s);
            batchCount++;
            if (batchCount >= batchLimit) await commitSalesBatch();
          } catch (e) {
            debugPrint("Lỗi sync sale ${s.id}: $e");
          }
        }
        await commitSalesBatch();
        debugPrint("✅ Synced $totalSynced sales to cloud");
      }

      // Sync EXPENSES (Chi phí)
      try {
        final expenses = await dbHelper.getAllExpensesForSync();
        debugPrint(
          "syncAllToCloud: có ${expenses.length} expenses cần kiểm tra sync",
        );
        if (expenses.isNotEmpty) {
          final WriteBatch expenseBatch = _db.batch();
          final List<dynamic> expensesToMarkSynced = [];
          for (var expense in expenses) {
            // Skip nếu đã có firestoreId và đã sync
            final firestoreId = expense.firestoreId;
            if (firestoreId != null &&
                firestoreId.isNotEmpty &&
                expense.isSynced) {
              continue;
            }

            try {
              Map<String, dynamic> data = expense.toMap();
              data['shopId'] = shopId;
              data.remove('id');
              data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
              data.remove('isSynced');
              data.remove('firestoreId');

              final docId =
                  firestoreId ??
                  "exp_${expense.date}_${expense.title.hashCode}";
              expenseBatch.set(
                _db.collection('expenses').doc(docId),
                data,
                SetOptions(merge: true),
              );

              // Defer marking synced
              expense.firestoreId = docId;
              expensesToMarkSynced.add(expense);
            } catch (e) {
              debugPrint("Lỗi sync expense ${expense.id}: $e");
            }
          }
          try {
            await expenseBatch.commit();
            for (var expense in expensesToMarkSynced) {
              expense.isSynced = true;
              await dbHelper.updateExpense(expense);
            }
            debugPrint(
              "✅ Synced ${expensesToMarkSynced.length} expenses to cloud",
            );
          } catch (e) {
            debugPrint(
              "❌ Batch commit expenses failed: $e - expenses will retry next sync",
            );
          }
        }
      } catch (e) {
        debugPrint("Lỗi sync expenses collection: $e");
      }

      // Sync PRODUCTS
      {
        final products = await dbHelper.getAllProducts();
        debugPrint("syncAllToCloud: có ${products.length} products cần sync");
        const prodBatchLimit = 400;
        WriteBatch productBatch = _db.batch();
        final List<Product> productsToMarkSynced = [];
        int prodBatchCount = 0;
        int totalProductsSynced = 0;

        Future<void> commitProductsBatch() async {
          if (productsToMarkSynced.isEmpty) return;
          try {
            await productBatch.commit();
            // Bulk update isSynced=1 bằng 1 SQL thay vì N round-trips
            final ids = productsToMarkSynced
                .map((p) => p.id)
                .whereType<int>()
                .toList();
            if (ids.isNotEmpty) {
              final placeholders = List.filled(ids.length, '?').join(',');
              try {
                await (await dbHelper.database).rawUpdate(
                  'UPDATE products SET isSynced = 1 WHERE id IN ($placeholders)',
                  ids,
                );
              } catch (e) {
                debugPrint(
                  "⚠️ Bulk isSynced update failed, fallback per-item: $e",
                );
                for (var p in productsToMarkSynced) {
                  try {
                    p.isSynced = true;
                    await dbHelper.updateProduct(p);
                  } catch (_) {}
                }
              }
            }
            totalProductsSynced += productsToMarkSynced.length;
            debugPrint(
              "✅ Committed ${productsToMarkSynced.length} products batch to cloud",
            );
          } catch (e) {
            debugPrint(
              "❌ Batch commit products failed: $e - products will retry next sync",
            );
          }
          productBatch = _db.batch();
          productsToMarkSynced.clear();
          prodBatchCount = 0;
        }

        for (var p in products) {
          if (p.isSynced) continue;
          try {
            Map<String, dynamic> data = p.toMap();
            data['shopId'] = shopId;
            data.remove('id');
            data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
            data.remove('isSynced');
            data.remove('firestoreId');

            if (_hasLocalImagePath(p.images)) {
              final allPaths = _splitImagePaths(p.images);
              List<String> urls =
                  await StorageService.uploadMultipleImages(
                    allPaths.where((path) => !_isCloudImagePath(path)).toList(),
                    'products/${p.createdAt}',
                  ).timeout(
                    const Duration(seconds: 30),
                    onTimeout: () {
                      debugPrint(
                        "Upload ảnh product ${p.id} quá thời gian, bỏ qua",
                      );
                      return <String>[];
                    },
                  );
              final existingCloud = allPaths
                  .where((path) => _isCloudImagePath(path))
                  .toList();
              existingCloud.addAll(urls);
              data['images'] = existingCloud.join(',');
            }

            final docId =
                p.firestoreId ??
                "product_${p.createdAt}_${p.imei ?? 'noimei'}_${p.id ?? 0}";
            productBatch.set(
              _db.collection('products').doc(docId),
              data,
              SetOptions(merge: true),
            );
            p.firestoreId = docId;
            p.images = data['images'];
            productsToMarkSynced.add(p);
            prodBatchCount++;
            if (prodBatchCount >= prodBatchLimit) await commitProductsBatch();
          } catch (e) {
            debugPrint("Lỗi sync product ${p.id}: $e");
          }
        }
        await commitProductsBatch();
        debugPrint("✅ Synced $totalProductsSynced products to cloud");

        // Retry ảnh sản phẩm còn kẹt ở local (chọn ảnh qua màn Sửa sản
        // phẩm nhưng lần upload nền đầu tiên lỗi/không có mạng, không có
        // cơ chế tự thử lại nào khác) — ảnh nằm ở thư mục cache của app
        // nên có thể bị hệ điều hành xoá bất cứ lúc nào nếu không upload
        // kịp lên cloud, mất ảnh vĩnh viễn.
        try {
          await ProductImageService.retryPendingProductImages(shopId);
        } catch (e) {
          debugPrint("Lỗi retry ảnh sản phẩm còn kẹt ở local: $e");
        }

        // Sửa lại các phiếu nhập kho bị lệch: đã trả nợ xong (bảng debts)
        // nhưng phiếu vẫn hiện "còn nợ" do trước đây trả nợ NCC không
        // đồng bộ ngược lại import_orders (đã sửa ở PaymentIntentService,
        // nhưng chỉ áp dụng cho lần trả nợ MỚI — cần quét lại cho dữ liệu
        // cũ đã lệch sẵn).
        try {
          await PaymentIntentService.reconcileStaleImportOrderDebts();
        } catch (e) {
          debugPrint("Lỗi reconcile phiếu nhập kho lệch nợ NCC: $e");
        }

        // Sync DELETED products → push deleted:true lên Firestore
        final deletedProducts = await dbHelper.getDeletedUnsyncedProducts();
        if (deletedProducts.isNotEmpty) {
          debugPrint(
            "syncAllToCloud: có ${deletedProducts.length} deleted products cần push lên cloud",
          );
          WriteBatch deletedBatch = _db.batch();
          final List<int> deletedIds = [];
          for (final p in deletedProducts) {
            try {
              final docId = p.firestoreId!;
              deletedBatch.set(_db.collection('products').doc(docId), {
                'deleted': true,
                'updatedAt': FirestoreWriteHelper.serverUpdatedAt(),
                'shopId': shopId,
              }, SetOptions(merge: true));
              if (p.id != null) deletedIds.add(p.id!);
            } catch (e) {
              debugPrint("Lỗi queue deleted product ${p.id}: $e");
            }
          }
          try {
            await deletedBatch.commit();
            if (deletedIds.isNotEmpty) {
              final placeholders = List.filled(
                deletedIds.length,
                '?',
              ).join(',');
              await (await dbHelper.database).rawUpdate(
                'UPDATE products SET isSynced = 1 WHERE id IN ($placeholders)',
                deletedIds,
              );
            }
            debugPrint(
              "✅ Synced ${deletedIds.length} deleted products to cloud",
            );
          } catch (e) {
            debugPrint("❌ Batch commit deleted products failed: $e");
          }
        }
      }

      // Sync DELETED records cho tất cả tables có soft-delete
      for (final entry in {
        'sales': 'sales',
        'customers': 'customers',
        'suppliers': 'suppliers',
        'purchase_orders': 'purchase_orders',
        'repair_parts': 'repair_parts',
      }.entries) {
        try {
          await _syncDeletedRowsToCloud(
            tableName: entry.key,
            collection: entry.value,
            shopId: shopId,
            dbHelper: dbHelper,
          );
        } catch (e) {
          debugPrint('_syncDeletedRowsToCloud ${entry.key} error: $e');
        }
      }

      // Sync ATTENDANCE
      try {
        final attendance = await dbHelper.getAllAttendance();
        debugPrint(
          "syncAllToCloud: có ${attendance.length} attendance cần sync",
        );
        final WriteBatch attendanceBatch = _db.batch();
        final List<dynamic> attendanceToMarkSynced = [];
        for (var a in attendance) {
          if (a.firestoreId != null && a.firestoreId!.isNotEmpty) {
            continue; // Đã sync rồi
          }

          try {
            Map<String, dynamic> data = a.toMap();
            data['shopId'] = shopId;
            data.remove('id');
            data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
            data.remove('isSynced');
            data.remove('firestoreId');

            // Xử lý upload ảnh check-in/out nếu là ảnh local
            if (a.photoIn != null &&
                a.photoIn!.isNotEmpty &&
                !a.photoIn!.startsWith('http')) {
              List<String> urls =
                  await StorageService.uploadMultipleImages([
                    a.photoIn!,
                  ], 'attendance/${a.dateKey}_${a.userId}_in').timeout(
                    const Duration(seconds: 30),
                    onTimeout: () {
                      debugPrint(
                        "Upload ảnh check-in ${a.id} quá thời gian, bỏ qua",
                      );
                      return <String>[];
                    },
                  );
              if (urls.isNotEmpty) data['photoIn'] = urls.first;
            }

            if (a.photoOut != null &&
                a.photoOut!.isNotEmpty &&
                !a.photoOut!.startsWith('http')) {
              List<String> urls =
                  await StorageService.uploadMultipleImages([
                    a.photoOut!,
                  ], 'attendance/${a.dateKey}_${a.userId}_out').timeout(
                    const Duration(seconds: 30),
                    onTimeout: () {
                      debugPrint(
                        "Upload ảnh check-out ${a.id} quá thời gian, bỏ qua",
                      );
                      return <String>[];
                    },
                  );
              if (urls.isNotEmpty) data['photoOut'] = urls.first;
            }

            final docId =
                a.firestoreId ?? "attendance_${a.userId}_${a.dateKey}";
            attendanceBatch.set(
              _db.collection('attendance').doc(docId),
              data,
              SetOptions(merge: true),
            );

            a.firestoreId = docId;
            a.photoIn = data['photoIn'];
            a.photoOut = data['photoOut'];
            attendanceToMarkSynced.add(a);
          } catch (e) {
            debugPrint("Lỗi sync attendance ${a.id}: $e");
            // Tiếp tục với attendance tiếp theo
          }
        }
        try {
          await attendanceBatch.commit();
          for (var a in attendanceToMarkSynced) {
            await dbHelper.updateAttendance(a);
          }
          debugPrint(
            "✅ Synced ${attendanceToMarkSynced.length} attendance to cloud",
          );
        } catch (e) {
          debugPrint(
            "❌ Batch commit attendance failed: $e - attendance will retry next sync",
          );
        }
      } catch (e) {
        debugPrint("Lỗi sync attendance collection: $e");
      }

      // Đồng bộ Quick Input Codes
      try {
        final quickInputCodes = await dbHelper.getQuickInputCodes();
        debugPrint(
          "syncAllToCloud: có ${quickInputCodes.length} quick input codes cần sync",
        );
        if (quickInputCodes.isNotEmpty) {
          final WriteBatch quickInputBatch = _db.batch();
          final List<dynamic> qicToMarkSynced = [];
          for (var code in quickInputCodes) {
            if (code.isSynced) continue;

            try {
              Map<String, dynamic> data = code.toMap();
              data['shopId'] = shopId;
              data.remove('id');
              data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
              data.remove('isSynced');
              data.remove('firestoreId');

              final docId =
                  code.firestoreId ??
                  "qic_${code.createdAt}_${code.name.replaceAll(' ', '_')}";
              quickInputBatch.set(
                _db.collection('quick_input_codes').doc(docId),
                data,
                SetOptions(merge: true),
              );

              code.firestoreId = docId;
              code.shopId = shopId;
              qicToMarkSynced.add(code);
            } catch (e) {
              debugPrint("Lỗi sync quick input code ${code.id}: $e");
            }
          }
          try {
            await quickInputBatch.commit();
            for (var code in qicToMarkSynced) {
              code.isSynced = true;
              await dbHelper.updateQuickInputCode(code);
            }
            debugPrint(
              "✅ Synced ${qicToMarkSynced.length} quick input codes to cloud",
            );
          } catch (e) {
            debugPrint("❌ Batch commit quick input codes failed: $e");
          }
        }
      } catch (e) {
        debugPrint("Lỗi sync quick input codes collection: $e");
      }

      // Đồng bộ Suppliers
      try {
        final suppliers = await dbHelper.getSuppliers();
        debugPrint(
          "syncAllToCloud: có ${suppliers.length} suppliers cần kiểm tra sync",
        );
        if (suppliers.isNotEmpty) {
          // Query existing Firestore suppliers for this shop to avoid duplicates
          final supplierQuery = _db
              .collection('suppliers')
              .where('shopId', isEqualTo: shopId);
          final existingSnapshot = await _getQueryWithTimeout(
            query: supplierQuery,
            context: 'syncAllToCloud_suppliers_dedupe',
          );
          final Map<String, String> existingByName = {};
          for (var doc in existingSnapshot.docs) {
            final data = doc.data();
            if (data['deleted'] == true || data['deleted'] == 1) continue;
            final decrypted = EncryptionService.decryptMap(data);
            final name = (decrypted['name'] ?? '')
                .toString()
                .toLowerCase()
                .trim();
            if (name.isNotEmpty) {
              existingByName[name] = doc.id;
            }
          }

          final WriteBatch supplierBatch = _db.batch();
          final List<Map<String, dynamic>> suppliersToMarkSynced = [];
          for (var supplierMap in suppliers) {
            // Skip nếu đã có firestoreId (đã sync)
            if (supplierMap['firestoreId'] != null &&
                supplierMap['firestoreId'].toString().isNotEmpty) {
              continue;
            }

            try {
              Map<String, dynamic> data = Map<String, dynamic>.from(
                supplierMap,
              );
              data['shopId'] = shopId;
              data.remove('id');
              data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
              data.remove('isSynced');
              data.remove('firestoreId');

              // Check if supplier with same name already exists in Firestore
              final nameKey = (supplierMap['name'] ?? '')
                  .toString()
                  .toLowerCase()
                  .trim();
              final docId =
                  existingByName[nameKey] ??
                  "supplier_${DateTime.now().millisecondsSinceEpoch}_${supplierMap['id']}";
              supplierBatch.set(
                _db.collection('suppliers').doc(docId),
                data,
                SetOptions(merge: true),
              );

              suppliersToMarkSynced.add({
                'supplierMap': supplierMap,
                'docId': docId,
              });
            } catch (e) {
              debugPrint("Lỗi sync supplier ${supplierMap['id']}: $e");
            }
          }
          try {
            await supplierBatch.commit();
            for (var item in suppliersToMarkSynced) {
              final updateData = Map<String, dynamic>.from(item['supplierMap']);
              updateData['firestoreId'] = item['docId'];
              await dbHelper.upsertSupplier(updateData);
            }
            debugPrint(
              "✅ Synced ${suppliersToMarkSynced.length} suppliers to cloud",
            );
          } catch (e) {
            debugPrint("❌ Batch commit suppliers failed: $e");
          }
        }
      } catch (e) {
        debugPrint("Lỗi sync suppliers collection: $e");
      }

      // Đồng bộ Customers (push unsynced local → Firestore)
      try {
        final unsyncedCustomers = await dbHelper.getUnsyncedCustomers();
        debugPrint(
          'syncAllToCloud: có ${unsyncedCustomers.length} customers chưa sync',
        );
        if (unsyncedCustomers.isNotEmpty) {
          const customerBatchSize = 400;
          final chunks = <List<Map<String, dynamic>>>[];
          for (
            int i = 0;
            i < unsyncedCustomers.length;
            i += customerBatchSize
          ) {
            chunks.add(
              unsyncedCustomers.sublist(
                i,
                i + customerBatchSize > unsyncedCustomers.length
                    ? unsyncedCustomers.length
                    : i + customerBatchSize,
              ),
            );
          }
          int totalSynced = 0;
          for (final chunk in chunks) {
            final batch = _db.batch();
            final toMark = <Map<String, dynamic>>[];
            for (final cMap in chunk) {
              try {
                final data = Map<String, dynamic>.from(cMap);
                data['shopId'] = shopId;
                data.remove('id');
                data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
                data.remove('isSynced');
                final phone = (cMap['phone'] ?? '').toString();
                final ts =
                    cMap['createdAt'] ?? DateTime.now().millisecondsSinceEpoch;
                final existingFid =
                    (cMap['firestoreId'] as String?)?.isNotEmpty == true
                    ? cMap['firestoreId'] as String
                    : null;
                final docId =
                    existingFid ??
                    'customer_${ts}_${phone.isNotEmpty ? phone : cMap['id']}';
                data.remove('firestoreId');
                batch.set(
                  _db.collection('customers').doc(docId),
                  data,
                  SetOptions(merge: true),
                );
                toMark.add({...cMap, 'firestoreId': docId, 'isSynced': 1});
              } catch (e) {
                debugPrint('Lỗi chuẩn bị sync customer ${cMap['id']}: $e');
              }
            }
            try {
              await batch.commit();
              // Direct update by original SQLite id — tránh match sai qua phone/firestoreId
              final db = await dbHelper.database;
              for (final c in toMark) {
                final cId = c['id'];
                if (cId == null) continue;
                try {
                  await db.update(
                    'customers',
                    {'isSynced': 1, 'firestoreId': c['firestoreId']},
                    where: 'id = ?',
                    whereArgs: [cId],
                  );
                } catch (e) {
                  debugPrint('⚠️ update customer id=$cId isSynced=1 fail: $e');
                }
              }
              totalSynced += toMark.length;
            } catch (e) {
              debugPrint('❌ Batch commit customers failed: $e');
            }
          }
          debugPrint('✅ Synced $totalSynced customers to cloud');
          EventBus().emit('customers_changed');
        }
      } catch (e) {
        debugPrint('Lỗi sync customers to cloud: $e');
      }

      // Đồng bộ Repair Partners
      try {
        final partners = await dbHelper.getRepairPartners();
        debugPrint(
          "syncAllToCloud: có ${partners.length} repair partners cần kiểm tra sync",
        );
        if (partners.isNotEmpty) {
          final WriteBatch partnerBatch = _db.batch();
          final List<Map<String, dynamic>> partnersToMarkSynced = [];
          for (var partnerMap in partners) {
            // Skip nếu đã có firestoreId (đã sync)
            if (partnerMap['firestoreId'] != null &&
                partnerMap['firestoreId'].toString().isNotEmpty) {
              continue;
            }

            try {
              Map<String, dynamic> data = Map<String, dynamic>.from(partnerMap);
              data['shopId'] = shopId;
              data.remove('id');
              data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
              data.remove('isSynced');
              data.remove('firestoreId');

              final docId =
                  "rp_${partnerMap['createdAt']}_${partnerMap['name'].toString().replaceAll(' ', '_')}";
              partnerBatch.set(
                _db.collection('repair_partners').doc(docId),
                data,
                SetOptions(merge: true),
              );

              partnersToMarkSynced.add({
                'partnerMap': partnerMap,
                'docId': docId,
              });
            } catch (e) {
              debugPrint("Lỗi sync repair partner ${partnerMap['id']}: $e");
            }
          }
          try {
            await partnerBatch.commit();
            for (var item in partnersToMarkSynced) {
              final updateData = Map<String, dynamic>.from(item['partnerMap']);
              updateData['firestoreId'] = item['docId'];
              await dbHelper.upsertRepairPartner(updateData);
            }
            debugPrint(
              "✅ Synced ${partnersToMarkSynced.length} repair partners to cloud",
            );
          } catch (e) {
            debugPrint("❌ Batch commit repair partners failed: $e");
          }
        }
      } catch (e) {
        debugPrint("Lỗi sync repair partners collection: $e");
      }

      // Đồng bộ Supplier Payments
      try {
        final supplierPayments = await dbHelper.getSupplierPaymentsForSync();
        debugPrint(
          "syncAllToCloud: có ${supplierPayments.length} supplier payments cần kiểm tra sync",
        );
        if (supplierPayments.isNotEmpty) {
          final WriteBatch supplierPaymentBatch = _db.batch();
          final List<Map<String, dynamic>> supPayToMarkSynced = [];
          for (var paymentMap in supplierPayments) {
            final firestoreId = paymentMap['firestoreId'];
            final isSynced =
                paymentMap['isSynced'] == 1 || paymentMap['isSynced'] == true;
            if (firestoreId != null &&
                firestoreId.toString().isNotEmpty &&
                isSynced) {
              continue;
            }

            try {
              final data = Map<String, dynamic>.from(paymentMap);
              data['shopId'] = shopId;
              data['deleted'] = data['deleted'] == 1 || data['deleted'] == true;
              data.remove('id');
              data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
              data.remove('isSynced');
              data.remove('firestoreId');

              final docId =
                  firestoreId ??
                  "sup_pay_${data['paidAt']}_${data['supplierId'] ?? 'sup'}";
              supplierPaymentBatch.set(
                _db.collection('supplier_payments').doc(docId),
                data,
                SetOptions(merge: true),
              );

              supPayToMarkSynced.add({'id': paymentMap['id'], 'docId': docId});
            } catch (e) {
              debugPrint("Lỗi sync supplier payment ${paymentMap['id']}: $e");
            }
          }
          try {
            await supplierPaymentBatch.commit();
            for (var item in supPayToMarkSynced) {
              await dbHelper.updateSupplierPayment(item['id'], {
                'firestoreId': item['docId'],
                'isSynced': 1,
              });
            }
            debugPrint(
              "✅ Synced ${supPayToMarkSynced.length} supplier payments to cloud",
            );
          } catch (e) {
            debugPrint("❌ Batch commit supplier payments failed: $e");
          }
        }
      } catch (e) {
        debugPrint("Lỗi sync supplier payments collection: $e");
      }

      // Đồng bộ Repair Partner Payments
      try {
        final partnerPayments = await dbHelper
            .getRepairPartnerPaymentsForSync();
        debugPrint(
          "syncAllToCloud: có ${partnerPayments.length} repair partner payments cần kiểm tra sync",
        );
        if (partnerPayments.isNotEmpty) {
          final WriteBatch partnerPaymentBatch = _db.batch();
          final List<Map<String, dynamic>> partPayToMarkSynced = [];
          for (var paymentMap in partnerPayments) {
            final firestoreId = paymentMap['firestoreId'];
            final isSynced =
                paymentMap['isSynced'] == 1 || paymentMap['isSynced'] == true;
            if (firestoreId != null &&
                firestoreId.toString().isNotEmpty &&
                isSynced) {
              continue;
            }

            try {
              final data = Map<String, dynamic>.from(paymentMap);
              data['shopId'] = shopId;
              data['deleted'] = data['deleted'] == 1 || data['deleted'] == true;
              data.remove('id');
              data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
              data.remove('isSynced');
              data.remove('firestoreId');

              final docId =
                  firestoreId ??
                  "part_pay_${data['paidAt']}_${data['partnerId'] ?? 'partner'}";
              partnerPaymentBatch.set(
                _db.collection('repair_partner_payments').doc(docId),
                data,
                SetOptions(merge: true),
              );

              partPayToMarkSynced.add({'id': paymentMap['id'], 'docId': docId});
            } catch (e) {
              debugPrint(
                "Lỗi sync repair partner payment ${paymentMap['id']}: $e",
              );
            }
          }
          try {
            await partnerPaymentBatch.commit();
            for (var item in partPayToMarkSynced) {
              await dbHelper.updateRepairPartnerPayment(item['id'], {
                'firestoreId': item['docId'],
                'isSynced': 1,
              });
            }
            debugPrint(
              "✅ Synced ${partPayToMarkSynced.length} repair partner payments to cloud",
            );
          } catch (e) {
            debugPrint("❌ Batch commit repair partner payments failed: $e");
          }
        }
      } catch (e) {
        debugPrint("Lỗi sync repair partner payments collection: $e");
      }

      // Đồng bộ Debts (Công nợ)
      try {
        final debts = await dbHelper.getAllDebts();
        debugPrint(
          "syncAllToCloud: có ${debts.length} debts cần kiểm tra sync",
        );
        if (debts.isNotEmpty) {
          final WriteBatch debtBatch = _db.batch();
          final List<Map<String, dynamic>> debtsToMarkSynced = [];
          for (var debtMap in debts) {
            // Skip nếu đã có firestoreId và đã sync
            final firestoreId = debtMap['firestoreId'];
            final isSynced =
                debtMap['isSynced'] == 1 || debtMap['isSynced'] == true;
            if (firestoreId != null &&
                firestoreId.toString().isNotEmpty &&
                isSynced) {
              continue;
            }

            try {
              Map<String, dynamic> data = Map<String, dynamic>.from(debtMap);
              data['shopId'] = shopId;
              data.remove('id');
              data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
              data.remove('isSynced');
              data.remove('firestoreId');

              final docId =
                  firestoreId ??
                  "debt_${debtMap['createdAt']}_${debtMap['phone'] ?? 'ncc'}";
              debtBatch.set(
                _db.collection('debts').doc(docId),
                data,
                SetOptions(merge: true),
              );

              debtsToMarkSynced.add({'id': debtMap['id'], 'docId': docId});
            } catch (e) {
              debugPrint("Lỗi sync debt ${debtMap['id']}: $e");
            }
          }
          try {
            await debtBatch.commit();
            for (var item in debtsToMarkSynced) {
              await dbHelper.updateDebtSynced(item['id'], item['docId']);
            }
            debugPrint("✅ Synced ${debtsToMarkSynced.length} debts to cloud");
          } catch (e) {
            debugPrint("❌ Batch commit debts failed: $e");
          }
        }
      } catch (e) {
        debugPrint("Lỗi sync debts collection: $e");
      }

      // Đồng bộ Debt Payments (Lịch sử thanh toán công nợ)
      try {
        final debtPayments = await dbHelper.getAllDebtPaymentsForSync();
        debugPrint(
          "syncAllToCloud: có ${debtPayments.length} debt payments cần kiểm tra sync",
        );
        if (debtPayments.isNotEmpty) {
          final WriteBatch paymentBatch = _db.batch();
          final List<Map<String, dynamic>> debtPayToMarkSynced = [];
          for (var paymentMap in debtPayments) {
            // Skip nếu đã có firestoreId và đã sync
            final firestoreId = paymentMap['firestoreId'];
            final isSynced =
                paymentMap['isSynced'] == 1 || paymentMap['isSynced'] == true;
            if (firestoreId != null &&
                firestoreId.toString().isNotEmpty &&
                isSynced) {
              continue;
            }

            try {
              Map<String, dynamic> data = Map<String, dynamic>.from(paymentMap);
              data['shopId'] = shopId;
              data.remove('id');
              data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
              data.remove('isSynced');
              data.remove('firestoreId');

              final docId =
                  firestoreId ??
                  "pay_${data['paidAt']}_${data['debtId'] ?? 'debt'}";
              paymentBatch.set(
                _db.collection('debt_payments').doc(docId),
                data,
                SetOptions(merge: true),
              );

              debtPayToMarkSynced.add({'id': paymentMap['id'], 'docId': docId});
            } catch (e) {
              debugPrint("Lỗi sync debt payment ${paymentMap['id']}: $e");
            }
          }
          try {
            await paymentBatch.commit();
            for (var item in debtPayToMarkSynced) {
              await dbHelper.updateDebtPaymentSynced(item['id'], item['docId']);
            }
            debugPrint(
              "✅ Synced ${debtPayToMarkSynced.length} debt payments to cloud",
            );
          } catch (e) {
            debugPrint("❌ Batch commit debt payments failed: $e");
          }
        }
      } catch (e) {
        debugPrint("Lỗi sync debt payments collection: $e");
      }

      // Đồng bộ Audit Logs (Nhật ký hoạt động) — chunked 400/batch
      try {
        final auditLogs = await dbHelper.getUnsyncedAuditLogs();
        debugPrint(
          "syncAllToCloud: có ${auditLogs.length} audit logs cần sync",
        );
        if (auditLogs.isNotEmpty) {
          const auditBatchLimit = 400;
          WriteBatch auditBatch = _db.batch();
          List<Map<String, dynamic>> auditToMark = [];
          int auditCount = 0;
          int totalAuditSynced = 0;

          // audit_logs là bất biến (Firestore rule: allow update: if false).
          // Nếu doc đã tồn tại trên cloud (VD: ghi thành công lần trước nhưng
          // bước đánh dấu synced ở local bị lỗi/kẹt), ghi lại sẽ luôn bị
          // permission-denied vĩnh viễn. Tự phục hồi: nếu doc đã tồn tại thật
          // thì coi như đã sync, không retry mãi mãi.
          Future<bool> alreadyExistsOnCloud(String docId) async {
            try {
              final snap = await _db.collection('audit_logs').doc(docId).get();
              return snap.exists;
            } catch (_) {
              return false;
            }
          }

          Future<void> commitAuditBatch() async {
            if (auditToMark.isEmpty) return;
            try {
              await auditBatch.commit();
              for (var item in auditToMark) {
                try {
                  await dbHelper.updateAuditLogSynced(item['docId']);
                } catch (_) {}
              }
              totalAuditSynced += auditToMark.length;
            } catch (e) {
              debugPrint(
                "❌ Batch commit audit logs failed: $e — thử ghi từng dòng riêng",
              );
              // Batch ghi atomic nên 1 dòng lỗi làm cả batch fail — ghi lại
              // từng dòng riêng để không chặn các dòng hợp lệ khác cùng batch.
              for (var item in auditToMark) {
                final docId = item['docId'] as String;
                final data = item['data'] as Map<String, dynamic>;
                try {
                  await _db
                      .collection('audit_logs')
                      .doc(docId)
                      .set(data, SetOptions(merge: true));
                  await dbHelper.updateAuditLogSynced(docId);
                  totalAuditSynced++;
                } catch (individualError) {
                  if (await alreadyExistsOnCloud(docId)) {
                    try {
                      await dbHelper.updateAuditLogSynced(docId);
                    } catch (_) {}
                    totalAuditSynced++;
                    debugPrint(
                      "♻️ audit log $docId đã tồn tại trên cloud — đánh dấu synced, bỏ retry",
                    );
                  } else {
                    debugPrint("❌ audit log $docId vẫn lỗi: $individualError");
                  }
                }
              }
            }
            auditBatch = _db.batch();
            auditToMark = [];
            auditCount = 0;
          }

          for (var logMap in auditLogs) {
            try {
              Map<String, dynamic> data = Map<String, dynamic>.from(logMap);
              data['shopId'] = shopId;
              data.remove('id');
              data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
              data.remove('isSynced');
              data.remove('firestoreId');
              final docId =
                  (logMap['firestoreId'] as String?)?.isNotEmpty == true
                  ? logMap['firestoreId'] as String
                  : "log_${data['createdAt']}_${data['userId']}";
              auditBatch.set(
                _db.collection('audit_logs').doc(docId),
                data,
                SetOptions(merge: true),
              );
              auditToMark.add({'docId': docId, 'data': data});
              auditCount++;
              if (auditCount >= auditBatchLimit) await commitAuditBatch();
            } catch (e) {
              debugPrint("Lỗi sync audit log ${logMap['id']}: $e");
            }
          }
          await commitAuditBatch();
          debugPrint("✅ Synced $totalAuditSynced audit logs to cloud");
        }
      } catch (e) {
        debugPrint("Lỗi sync audit logs collection: $e");
      }

      // Đồng bộ Repair Parts (Kho linh kiện) — chunked 400/batch
      try {
        final repairParts = await dbHelper.getUnsyncedRepairParts();
        debugPrint(
          "syncAllToCloud: có ${repairParts.length} repair parts cần sync",
        );
        if (repairParts.isNotEmpty) {
          const partsBatchLimit = 400;
          WriteBatch partsBatch = _db.batch();
          List<Map<String, dynamic>> partsToMarkSynced = [];
          int partsCount = 0;
          int totalPartsSynced = 0;

          Future<void> commitPartsBatch() async {
            if (partsToMarkSynced.isEmpty) return;
            try {
              await partsBatch.commit();
              for (var item in partsToMarkSynced) {
                try {
                  await dbHelper.updateRepairPartSynced(
                    item['localId'],
                    item['docId'],
                  );
                } catch (_) {}
              }
              totalPartsSynced += partsToMarkSynced.length;
            } catch (e) {
              debugPrint("❌ Batch commit repair parts failed: $e");
            }
            partsBatch = _db.batch();
            partsToMarkSynced = [];
            partsCount = 0;
          }

          for (var partMap in repairParts) {
            try {
              Map<String, dynamic> data = Map<String, dynamic>.from(partMap);
              data['shopId'] = shopId;
              final localId = data['id'];
              data.remove('id');
              data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
              data.remove('isSynced');
              data.remove('firestoreId');
              final rawPartName = data['partName'];
              final partNameStr = rawPartName?.toString().trim() ?? '';
              if (partNameStr.isEmpty) {
                debugPrint(
                  "⚠️ Skip repair part id=$localId: partName is null/empty",
                );
                continue;
              }
              data['partName'] = partNameStr;
              final docId =
                  (partMap['firestoreId'] as String?)?.isNotEmpty == true
                  ? partMap['firestoreId'] as String
                  : "part_${data['createdAt']}_${partNameStr.replaceAll(' ', '_')}";
              partsBatch.set(
                _db.collection('repair_parts').doc(docId),
                data,
                SetOptions(merge: true),
              );
              partsToMarkSynced.add({'localId': localId, 'docId': docId});
              partsCount++;
              if (partsCount >= partsBatchLimit) await commitPartsBatch();
            } catch (e) {
              debugPrint("Lỗi sync repair part ${partMap['id']}: $e");
            }
          }
          await commitPartsBatch();
          debugPrint("✅ Synced $totalPartsSynced repair parts to cloud");
        }
      } catch (e) {
        debugPrint("Lỗi sync repair parts collection: $e");
      }

      // Đồng bộ Payment Intents (Yêu cầu thanh toán)
      // FIX: Thêm sync cho payment_intents để 2 máy cùng thấy các giao dịch chờ thanh toán
      try {
        final paymentIntents = await dbHelper.getPaymentIntentsForSync();
        debugPrint(
          "syncAllToCloud: có ${paymentIntents.length} payment intents cần sync",
        );
        if (paymentIntents.isNotEmpty) {
          final WriteBatch intentBatch = _db.batch();
          final List<Map<String, dynamic>> intentsToMarkSynced = [];
          for (var intentMap in paymentIntents) {
            final firestoreId = intentMap['firestoreId'];
            final isSynced =
                intentMap['isSynced'] == 1 || intentMap['isSynced'] == true;
            if (firestoreId != null &&
                firestoreId.toString().isNotEmpty &&
                isSynced) {
              continue;
            }

            try {
              final data = Map<String, dynamic>.from(intentMap);
              data['shopId'] = shopId;
              data['deleted'] = data['deleted'] == 1 || data['deleted'] == true;
              final localId = data['id'];
              data.remove('id');
              data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
              data.remove('isSynced');
              data.remove('firestoreId');

              final docId =
                  firestoreId ??
                  "pi_${data['intentId'] ?? data['createdAt']}_${data['type'] ?? 'unknown'}";
              intentBatch.set(
                _db.collection('payment_intents').doc(docId),
                data,
                SetOptions(merge: true),
              );

              intentsToMarkSynced.add({'localId': localId, 'docId': docId});
            } catch (e) {
              debugPrint("Lỗi sync payment intent ${intentMap['id']}: $e");
            }
          }
          try {
            await intentBatch.commit();
            for (var item in intentsToMarkSynced) {
              await dbHelper.updatePaymentIntentSynced(
                item['localId'],
                item['docId'],
              );
            }
            debugPrint(
              "✅ Synced ${intentsToMarkSynced.length} payment intents to cloud",
            );
          } catch (e) {
            debugPrint("❌ Batch commit payment intents failed: $e");
          }
        }
      } catch (e) {
        debugPrint("Lỗi sync payment intents collection: $e");
      }

      // Sync ADJUSTMENT ENTRIES (Bút toán điều chỉnh)
      try {
        final adjustments = await dbHelper.getUnsyncedAdjustmentEntries();
        debugPrint(
          "syncAllToCloud: có ${adjustments.length} adjustment entries cần sync",
        );
        if (adjustments.isNotEmpty) {
          final WriteBatch adjustmentBatch = _db.batch();
          final List<Map<String, dynamic>> adjustmentsToMarkSynced = [];
          for (var entry in adjustments) {
            try {
              final existingId = entry['firestoreId'] as String?;
              final localId = entry['id'] as int?;
              final data = Map<String, dynamic>.from(entry);
              data['shopId'] = shopId;
              data.remove('id');
              data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
              data.remove('isSynced');
              data.remove('firestoreId');

              final docId = (existingId != null && existingId.isNotEmpty)
                  ? existingId
                  : "adj_${entry['createdAt']}_${(entry['description'] ?? '').hashCode}";
              adjustmentBatch.set(
                _db.collection('adjustment_entries').doc(docId),
                data,
                SetOptions(merge: true),
              );
              adjustmentsToMarkSynced.add({
                ...entry,
                '_docId': docId,
                'id': localId,
              });
            } catch (e) {
              debugPrint("Lỗi sync adjustment entry ${entry['id']}: $e");
            }
          }
          try {
            await adjustmentBatch.commit();
            for (var entry in adjustmentsToMarkSynced) {
              final localId = entry['id'] as int?;
              final docId = entry['_docId'] as String;
              if (localId != null) {
                await dbHelper.markAdjustmentEntrySynced(localId, docId);
              }
            }
            debugPrint(
              "✅ Synced ${adjustmentsToMarkSynced.length} adjustment entries to cloud",
            );
          } catch (e) {
            debugPrint("❌ Batch commit adjustment entries failed: $e");
          }
        }
      } catch (e) {
        debugPrint("Lỗi sync adjustment_entries collection: $e");
      }

      // Sync IMPORT_ORDERS + IMPORT_ORDER_ITEMS (từ KiotViet import)
      try {
        await _syncRawTableToCloud(
          tableName: 'import_orders',
          collection: 'import_orders',
          shopId: shopId,
          dbHelper: dbHelper,
          firestoreIdFallback: (row) =>
              'io_${row['importDate'] ?? row['createdAt'] ?? 0}_${row['orderCode'] ?? ''}_${row['id'] ?? 0}',
        );
        await _syncRawTableToCloud(
          tableName: 'import_order_items',
          collection: 'import_order_items',
          shopId: shopId,
          dbHelper: dbHelper,
          firestoreIdFallback: (row) =>
              'ioi_${row['importOrderFirestoreId'] ?? ''}_${row['id'] ?? 0}',
        );
      } catch (e) {
        debugPrint('Lỗi sync import_orders/items: $e');
      }

      debugPrint("Đã hoàn thành đồng bộ toàn bộ dữ liệu lên Cloud.");
    } catch (e) {
      debugPrint("Lỗi syncAllToCloud: $e");
    } finally {
      _isSyncingAllToCloud = false;
    }
  }

  /// Bulk-sync một table local (raw SQL) lên Firestore collection, chunk 400/batch.
  static Future<void> _syncRawTableToCloud({
    required String tableName,
    required String collection,
    required String shopId,
    required DBHelper dbHelper,
    required String Function(Map<String, dynamic> row) firestoreIdFallback,
  }) async {
    final db = await dbHelper.database;
    // Kiểm tra columns tồn tại để tránh lỗi nếu table thiếu cột
    final tableInfo = await db.rawQuery('PRAGMA table_info($tableName)');
    final cols = tableInfo.map((r) => r['name']?.toString() ?? '').toSet();
    final deletedClause = cols.contains('deleted')
        ? ' AND (deleted IS NULL OR deleted = 0)'
        : '';
    final shopClause = cols.contains('shopId') ? ' AND shopId = ?' : '';
    final whereArgs = cols.contains('shopId') ? [shopId] : <dynamic>[];
    final rows = await db.query(
      tableName,
      where: '(isSynced = 0 OR isSynced IS NULL)$shopClause$deletedClause',
      whereArgs: whereArgs,
    );
    if (rows.isEmpty) return;
    debugPrint('syncAllToCloud: $tableName có ${rows.length} rows chưa sync');

    const batchSize = 400;
    WriteBatch batch = _db.batch();
    final List<int> syncedIds = [];
    int count = 0;

    Future<void> commitBatch() async {
      if (syncedIds.isEmpty) return;
      try {
        await batch.commit();
        final placeholders = List.filled(syncedIds.length, '?').join(',');
        await db.rawUpdate(
          'UPDATE $tableName SET isSynced = 1 WHERE id IN ($placeholders)',
          syncedIds,
        );
        debugPrint('✅ Committed ${syncedIds.length} $tableName rows to cloud');
      } catch (e) {
        debugPrint('❌ Batch commit $tableName failed: $e');
      }
      batch = _db.batch();
      syncedIds.clear();
      count = 0;
    }

    for (final rawRow in rows) {
      final row = Map<String, dynamic>.from(rawRow);
      final id = row['id'] as int?;
      final firestoreId = (row['firestoreId'] as String?)?.isNotEmpty == true
          ? row['firestoreId'] as String
          : firestoreIdFallback(row);
      row['firestoreId'] = firestoreId;
      row['shopId'] = shopId;
      row.remove('id');
      row.remove('isSynced');
      row['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
      _convertTimestampFields(row);
      batch.set(
        _db.collection(collection).doc(firestoreId),
        row,
        SetOptions(merge: true),
      );
      if (id != null) syncedIds.add(id);
      count++;
      if (count >= batchSize) await commitBatch();
    }
    await commitBatch();
  }

  /// Push deleted=1 records lên Firestore với {deleted:true} cho bất kỳ table nào.
  /// Dùng cho sales, customers, suppliers, products, etc. sau khi soft-delete.
  static Future<void> _syncDeletedRowsToCloud({
    required String tableName,
    required String collection,
    required String shopId,
    required DBHelper dbHelper,
  }) async {
    final db = await dbHelper.database;
    final tableInfo = await db.rawQuery('PRAGMA table_info($tableName)');
    final cols = tableInfo.map((r) => r['name']?.toString() ?? '').toSet();
    if (!cols.contains('deleted') ||
        !cols.contains('firestoreId') ||
        !cols.contains('isSynced'))
      return;

    final shopClause = cols.contains('shopId') ? ' AND shopId = ?' : '';
    final whereArgs = cols.contains('shopId') ? [shopId] : <dynamic>[];
    final rows = await db.rawQuery(
      'SELECT * FROM $tableName WHERE deleted = 1 AND (isSynced = 0 OR isSynced IS NULL) AND firestoreId IS NOT NULL$shopClause',
      whereArgs,
    );
    if (rows.isEmpty) return;
    debugPrint(
      '_syncDeletedRowsToCloud: $tableName có ${rows.length} deleted rows cần push',
    );

    const batchSize = 400;
    WriteBatch batch = _db.batch();
    final List<int> syncedIds = [];
    int count = 0;

    Future<void> commitBatch() async {
      if (syncedIds.isEmpty) return;
      try {
        await batch.commit();
        final ph = List.filled(syncedIds.length, '?').join(',');
        await db.rawUpdate(
          'UPDATE $tableName SET isSynced = 1 WHERE id IN ($ph)',
          syncedIds,
        );
        debugPrint(
          '✅ Pushed ${syncedIds.length} deleted $tableName rows to cloud',
        );
      } catch (e) {
        debugPrint('❌ Batch commit deleted $tableName failed: $e');
      }
      batch = _db.batch();
      syncedIds.clear();
      count = 0;
    }

    for (final rawRow in rows) {
      final firestoreId = rawRow['firestoreId'] as String;
      final id = rawRow['id'] as int?;
      batch.set(_db.collection(collection).doc(firestoreId), {
        'deleted': true,
        'updatedAt': FirestoreWriteHelper.serverUpdatedAt(),
        'shopId': shopId,
      }, SetOptions(merge: true));
      if (id != null) syncedIds.add(id);
      count++;
      if (count >= batchSize) await commitBatch();
    }
    await commitBatch();
  }

  /// Tải toàn bộ dữ liệu từ Cloud về (Dùng khi cài lại app hoặc đổi máy)
  /// [force] = true bỏ qua cooldown (dùng khi user chủ động bấm sync)
  static Future<void> downloadAllFromCloud({bool force = false}) async {
    // ═══════════════════════════════════════════════════════════════════════
    // THROTTLE: Chặn gọi liên tục (tối thiểu 60s giữa các lần)
    // ═══════════════════════════════════════════════════════════════════════
    if (_isDownloading) {
      debugPrint("⏸️ downloadAllFromCloud: Đang download, bỏ qua");
      return;
    }
    if (!force && _lastDownloadTime != null) {
      final elapsed = DateTime.now().difference(_lastDownloadTime!);
      if (elapsed < _downloadCooldown) {
        debugPrint(
          "⏸️ downloadAllFromCloud: Cooldown ${_downloadCooldown.inSeconds - elapsed.inSeconds}s còn lại, bỏ qua (dùng force:true để override)",
        );
        return;
      }
    }

    // Tránh full sync đè lên realtime startup trên mobile/iOS.
    if (!force && (_isInitializingRealtime || isRealTimeSyncActive)) {
      debugPrint(
        '⏸️ downloadAllFromCloud: Bỏ qua vì realtime sync đang active/initializing',
      );
      return;
    }

    _isDownloading = true;
    _lastDownloadTime = DateTime.now();

    debugPrint("Bắt đầu downloadAllFromCloud (force=$force)...");
    try {
      final db = DBHelper();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("downloadAllFromCloud: Không có user, bỏ qua");
        return;
      }

      final bool isSuperAdmin = UserService.isCurrentUserSuperAdmin();
      final permissions = await UserService.getCurrentUserPermissions();
      final role = await UserService.getUserRole(user.uid);
      // Use sync cache first (set by syncUserInfo), fallback to async
      String? shopId = UserService.getShopIdSync();
      shopId ??= await UserService.getCurrentShopId();

      // LOG QUAN TRỌNG: Hiển thị shopId được sử dụng
      debugPrint(
        "⚡ downloadAllFromCloud: user=${user.uid}, email=${user.email}, shopId=$shopId, isSuperAdmin=$isSuperAdmin",
      );

      // Retry lấy shopId nếu chưa có (claims có thể chưa sync)
      if (shopId == null && !isSuperAdmin) {
        debugPrint("⚠️ shopId null, thử refresh claims...");
        for (int retry = 0; retry < 2; retry++) {
          await Future.delayed(const Duration(seconds: 1));
          try {
            await user.getIdToken(true);
            shopId = await UserService.getCurrentShopId();
            if (shopId != null) {
              debugPrint("✅ Lấy được shopId sau retry ${retry + 1}: $shopId");
              break;
            }
          } catch (e) {
            debugPrint("Retry ${retry + 1}/2 lấy shopId: $e");
          }
        }
      }

      // Cần có shopId để sync (super admin phải chọn shop trước)
      if (shopId == null) {
        if (isSuperAdmin) {
          debugPrint(
            "⚠️ Super admin chưa chọn shop, bỏ qua downloadAllFromCloud",
          );
        } else {
          debugPrint(
            "⚠️ Không có shopId sau 3 retry, bỏ qua downloadAllFromCloud",
          );
        }
        return;
      }

      // Log local data counts before sync
      // OPT: Dùng count query thay vì load toàn bộ objects chỉ để lấy .length
      final repairsCountBefore = await db.getRepairsCount();
      final productsCountBefore = await db.getProductsCount();
      final salesCountBefore = await db.getSalesCount();
      debugPrint(
        "LOCAL DATA BEFORE SYNC: repairs=$repairsCountBefore, products=$productsCountBefore, sales=$salesCountBefore",
      );

      // Chỉ tải các collection có shopId - đảm bảo chỉ lấy dữ liệu của shop hiện tại
      final collections = [
        'repairs',
        'products',
        'sales',
        'expenses',
        'debts',
        'debt_payments',
        'attendance',
        'quick_input_codes',
        'supplier_payments',
        'repair_partner_payments',
        'customers',
        'suppliers',
        'repair_partners',
        'repair_parts',
        'supplier_import_history',
        'supplier_product_prices',
        'audit_logs', // FIX: Thêm để device mới download được lịch sử thao tác
        'payment_intents', // FIX: Thêm để đồng bộ các yêu cầu thanh toán giữa các máy
        'cash_closings', // FIX: Thêm để đồng bộ lịch sử chốt quỹ + số dư đầu kỳ khi switch account
        'sales_returns', // FIX: Đồng bộ phiếu trả hàng
        'sales_return_items', // FIX: Đồng bộ chi tiết trả hàng
        'financial_activity_log', // FIX: Đồng bộ nhật ký tài chính
        'payment_requests', // FIX: Đồng bộ yêu cầu đóng tiền giữa các máy
        'leave_requests', // FIX: Đồng bộ đơn xin nghỉ giữa các máy
        'import_orders', // Đồng bộ phiếu nhập kho
        'import_order_items', // Đồng bộ chi tiết phiếu nhập
        'price_catalog_items', // Danh mục giá từ hoá đơn NCC
      ];
      final allowedCollections = collections.where((col) {
        return _canSubscribeCollection(
          collection: col,
          permissions: permissions,
          role: role,
          isSuperAdmin: isSuperAdmin,
        );
      }).toList();
      debugPrint(
        'downloadAllFromCloud: role=$role, allowedCollections=$allowedCollections',
      );
      // Lưu ý: 'users' và 'shops' không có shopId field nên không tải ở đây

      // ═══════════════════════════════════════════════════════════════════════
      // INCREMENTAL SYNC: Chỉ tải docs thay đổi từ lần sync cuối
      // Giảm reads đáng kể khi data ít thay đổi
      // ═══════════════════════════════════════════════════════════════════════
      final prefs = await SharedPreferences.getInstance();

      for (var col in allowedCollections) {
        // Yield to UI thread between collections to prevent ANR/frame drops
        await Future.delayed(Duration.zero);

        try {
          // Lấy lastSyncTime cho collection này
          final lastSyncKey = '$_lastSyncPrefix${col}_$shopId';
          final lastSyncMs = prefs.getInt(lastSyncKey) ?? 0;
          final isFirstSync = lastSyncMs == 0;

          Query<Map<String, dynamic>> query = _db
              .collection(col)
              .where('shopId', isEqualTo: shopId);

          // Incremental: chỉ lấy docs có updatedAt > lastSync
          if (!isFirstSync && !force) {
            query = query.where(
              'updatedAt',
              isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(lastSyncMs),
            );
            debugPrint(
              "Downloading collection: $col (incremental, since ${DateTime.fromMillisecondsSinceEpoch(lastSyncMs)})...",
            );
          } else {
            debugPrint("Downloading collection: $col (full sync)...");
          }

          final snap = await _getQueryWithTimeout(
            query: query,
            context: 'downloadAllFromCloud_$col',
          );
          debugPrint("  -> Found ${snap.docs.length} documents in $col");

          int successCount = 0;
          int skipCount = 0;
          int errorCount = 0;

          // Process in batches of 50 to avoid blocking main thread
          final docs = snap.docs;
          for (int i = 0; i < docs.length; i++) {
            // Yield every 50 documents to prevent frame drops
            if (i > 0 && i % 50 == 0) {
              await Future.delayed(Duration.zero);
            }

            final doc = docs[i];
            try {
              var data = doc.data();
              if (data['deleted'] == true || data['deleted'] == 1) {
                // Xóa record local nếu đã bị soft-delete trên cloud
                await _deleteLocalByFirestoreId(db, col, doc.id);
                skipCount++;
                continue; // Skip soft-deleted documents
              }

              // Giải mã dữ liệu nếu được mã hóa
              data = EncryptionService.decryptMap(data);
              data['firestoreId'] = doc.id;
              data['isSynced'] = 1; // QUAN TRỌNG: Đánh dấu đã sync từ cloud

              // Chuyển đổi tất cả Timestamp fields sang milliseconds cho SQLite
              _convertTimestampFields(data);

              if (col == 'repairs') {
                _normalizeRepairPayload(data);
                await db.upsertRepair(Repair.fromMap(data));
              } else if (col == 'products') {
                // BẢO TOÀN các field quan trọng từ local nếu cloud trả về 0/null
                final existingProduct = await db.getProductByFirestoreId(
                  doc.id,
                );
                if (existingProduct != null) {
                  if (existingProduct.isPending && data['isPending'] == null) {
                    data['isPending'] = 1;
                    data['pendingSupplier'] = existingProduct.pendingSupplier;
                  }
                  // Preserve createdAt, price, cost khi cloud trả 0/null
                  if (existingProduct.createdAt > 0 &&
                      _getTimestamp(data['createdAt']) <= 0) {
                    data['createdAt'] = existingProduct.createdAt;
                  }
                  if (existingProduct.price > 0 && _asInt(data['price']) <= 0) {
                    data['price'] = existingProduct.price;
                  }
                  if (existingProduct.cost > 0 && _asInt(data['cost']) <= 0) {
                    data['cost'] = existingProduct.cost;
                  }
                }
                await db.upsertProduct(Product.fromMap(data));
              } else if (col == 'sales') {
                await db.upsertSale(SaleOrder.fromMap(data));
                // Đảm bảo shopId được lưu vào SQLite để getAllSales() tìm thấy
                if (shopId.isNotEmpty) {
                  try {
                    await (await db.database).rawUpdate(
                      'UPDATE sales SET shopId = ? WHERE firestoreId = ?',
                      [shopId, doc.id],
                    );
                  } catch (_) {}
                }
              } else if (col == 'expenses') {
                await db.upsertExpense(Expense.fromMap(data));
              } else if (col == 'debts') {
                await db.upsertDebt(Debt.fromMap(data));
              } else if (col == 'debt_payments') {
                await db.upsertDebtPayment(data);
                // Khớp lại debts.paidAmount từ sổ cái ngay khi kéo phiếu về.
                await _reconcileDebtFromPaymentRow(db, data);
              } else if (col == 'attendance') {
                await db.upsertAttendance(Attendance.fromMap(data));
              } else if (col == 'leave_requests') {
                await db.upsertLeaveRequest(LeaveRequest.fromMap(data));
              } else if (col == 'quick_input_codes') {
                await db.upsertQuickInputCode(QuickInputCode.fromMap(data));
              } else if (col == 'supplier_payments') {
                await db.upsertSupplierPayment(data);
              } else if (col == 'repair_partner_payments') {
                await db.upsertRepairPartnerPayment(data);
              } else if (col == 'customers') {
                await db.upsertCustomer(data);
              } else if (col == 'suppliers') {
                await db.upsertSupplier(data);
              } else if (col == 'repair_partners') {
                await db.upsertRepairPartner(data);
              } else if (col == 'repair_parts') {
                await db.upsertRepairPart(data);
              } else if (col == 'supplier_import_history') {
                await db.upsertSupplierImportHistory(data);
              } else if (col == 'supplier_product_prices') {
                await db.upsertSupplierProductPrice(data);
              } else if (col == 'audit_logs') {
                // Map fields cho audit_logs
                data['userName'] =
                    data['userName'] ??
                    data['email']?.toString().split('@').first.toUpperCase() ??
                    'SYSTEM';
                data['description'] =
                    data['summary'] ?? data['description'] ?? '';
                data['targetType'] =
                    data['targetType'] ?? data['entityType'] ?? '';
                data['targetId'] = data['targetId'] ?? data['entityId'] ?? '';
                await db.upsertAuditLog(data);
              } else if (col == 'payment_intents') {
                await db.upsertPaymentIntent(data);
              } else if (col == 'cash_closings') {
                await db.upsertCashClosing(data);
              } else if (col == 'sales_returns') {
                await db.upsertSalesReturn(data);
              } else if (col == 'sales_return_items') {
                await db.upsertSalesReturnItem(data);
              } else if (col == 'financial_activity_log') {
                await db.upsertFinancialActivity(data);
              } else if (col == 'payment_requests') {
                await db.upsertPaymentRequest(data);
              } else if (col == 'import_orders') {
                await db.upsertImportOrder(data);
              } else if (col == 'import_order_items') {
                await db.upsertImportOrderItem(data);
              } else if (col == 'price_catalog_items') {
                await db.upsertPriceCatalogItem(data);
              }
              successCount++;
            } catch (e) {
              errorCount++;
              debugPrint("  -> Error processing document ${doc.id}: $e");
            }
          }
          debugPrint(
            "  -> $col: success=$successCount, skipped=$skipCount, errors=$errorCount",
          );

          // Lưu thời điểm sync thành công cho incremental sync lần sau
          if (successCount > 0 || isFirstSync) {
            await prefs.setInt(
              lastSyncKey,
              DateTime.now().millisecondsSinceEpoch,
            );
          }
        } catch (e) {
          debugPrint("Lỗi tải collection $col: $e");
        }
      }

      // Log local data counts after sync
      // OPT: Dùng count query thay vì load toàn bộ objects
      final repairsCountAfter = await db.getRepairsCount();
      final productsCountAfter = await db.getProductsCount();
      final salesCountAfter = await db.getSalesCount();
      final localExpenses = await db.getAllExpensesForSync();
      final localDebts = await db.getAllDebts();
      debugPrint(
        "LOCAL DATA AFTER SYNC: repairs=$repairsCountAfter, products=$productsCountAfter, sales=$salesCountAfter, expenses=${localExpenses.length}, debts=${localDebts.length}",
      );

      debugPrint("Đã hoàn thành downloadAllFromCloud.");
    } catch (e) {
      debugPrint("Lỗi downloadAllFromCloud: $e");
    } finally {
      _isDownloading = false;
    }
  }

  /// Đồng bộ Quick Input Codes lên Cloud
  static Future<void> syncQuickInputCodesToCloud() async {
    debugPrint("Bắt đầu syncQuickInputCodesToCloud...");
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("Không có user, bỏ qua syncQuickInputCodesToCloud");
        return;
      }

      final String? shopId = await UserService.getCurrentShopId();
      final dbHelper = DBHelper();

      final quickInputCodes = await dbHelper.getUnsyncedQuickInputCodes();
      debugPrint(
        "syncQuickInputCodesToCloud: có ${quickInputCodes.length} quick input codes cần sync",
      );

      if (quickInputCodes.isEmpty) {
        debugPrint("Không có mã nhập nhanh nào cần đồng bộ");
        return;
      }

      // Firestore giới hạn 500 docs/batch — chia nhỏ để tránh lỗi
      const batchSize = 450;
      int totalSynced = 0;

      for (int start = 0; start < quickInputCodes.length; start += batchSize) {
        final chunk = quickInputCodes.sublist(
          start,
          (start + batchSize).clamp(0, quickInputCodes.length),
        );

        // Chuẩn bị dữ liệu cho từng code trước
        final toUpdate = <QuickInputCode>[];
        final batch = _db.batch();

        for (var code in chunk) {
          final docId =
              code.firestoreId ??
              "qic_${code.createdAt}_${code.name.replaceAll(' ', '_')}";
          final Map<String, dynamic> data = code.toMap();
          data['shopId'] = shopId;
          data.remove('id');
          // Firestore dùng bool, không phải int như SQLite
          data['isActive'] = code.isActive;
          data['isSynced'] = true;
          // Đảm bảo code field luôn có giá trị (rule yêu cầu has(['code', 'shopId']))
          data['code'] = code.code ?? docId;

          batch.set(
            _db.collection('quick_input_codes').doc(docId),
            data,
            SetOptions(merge: true),
          );

          code
            ..firestoreId = docId
            ..shopId = shopId
            ..isSynced = true;
          toUpdate.add(code);
        }

        // Commit batch trước — chỉ cập nhật local DB khi Firestore thành công
        await batch.commit();

        for (final code in toUpdate) {
          await dbHelper.updateQuickInputCode(code);
        }
        totalSynced += chunk.length;
        debugPrint(
          "syncQuickInputCodesToCloud: đã sync $totalSynced/${quickInputCodes.length}",
        );
      }

      debugPrint("Đã đồng bộ thành công $totalSynced mã nhập nhanh lên Cloud");
    } catch (e) {
      debugPrint("Lỗi syncQuickInputCodesToCloud: $e");
      rethrow;
    }
  }

  /// Đồng bộ customers từ Cloud xuống local DB
  static Future<void> syncCustomersFromCloud() async {
    debugPrint("Bắt đầu syncCustomersFromCloud...");
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("syncCustomersFromCloud: Không có user, bỏ qua");
        return;
      }

      final bool isSuperAdmin = UserService.isCurrentUserSuperAdmin();
      final String? shopId = isSuperAdmin
          ? null
          : await UserService.getCurrentShopId();
      debugPrint(
        "syncCustomersFromCloud: shopId = $shopId, isSuperAdmin = $isSuperAdmin",
      );

      // Nếu không có shopId và không phải super admin, bỏ qua
      if (!isSuperAdmin && (shopId == null || shopId.isEmpty)) {
        debugPrint("syncCustomersFromCloud: Không có shopId, bỏ qua");
        return;
      }

      final dbHelper = DBHelper();

      // Query customers từ Firestore
      Query<Map<String, dynamic>> query = _db.collection('customers');
      if (!isSuperAdmin && shopId != null) {
        query = query.where('shopId', isEqualTo: shopId);
      }

      // Refresh token trước khi query để đảm bảo claims được cập nhật
      try {
        await user.getIdToken(true);
      } catch (e) {
        debugPrint("syncCustomersFromCloud: Không thể refresh token: $e");
      }

      final querySnapshot = await _getQueryWithTimeout(
        query: query,
        context: 'syncCustomersFromCloud',
      );
      debugPrint(
        "syncCustomersFromCloud: Tìm thấy ${querySnapshot.docs.length} customers từ cloud",
      );

      // Upsert từng customer vào local DB
      for (var doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          _convertTimestampFields(data);
          data['firestoreId'] = doc.id;
          data['isSynced'] = 1; // Đánh dấu đã sync
          await dbHelper.upsertCustomer(data);
          debugPrint(
            "syncCustomersFromCloud: Đã upsert customer ${data['name'] ?? ''} (${doc.id})",
          );
        } catch (e) {
          debugPrint(
            "syncCustomersFromCloud: Lỗi upsert customer ${doc.id}: $e",
          );
        }
      }

      debugPrint(
        "syncCustomersFromCloud: Hoàn thành, đã sync ${querySnapshot.docs.length} customers",
      );
    } catch (e) {
      debugPrint("syncCustomersFromCloud: Lỗi: $e");
      rethrow;
    }
  }
}
