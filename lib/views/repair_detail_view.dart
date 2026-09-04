import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/money_utils.dart';
import '../widgets/currency_text_field.dart';
import '../widgets/keyboard_aware_padding.dart';
import '../utils/repair_status_validator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../models/repair_model.dart';
import '../models/repair_service_model.dart';
import '../models/part_used_detail_model.dart';
import '../models/product_model.dart';
import '../services/pricing_engine_service.dart';
import 'similar_repair_history_view.dart';
import '../models/repair_partner_model.dart';
import '../models/payment_intent_model.dart';
import '../models/shop_settings_model.dart';
import '../constants/financial_constants.dart';
import '../services/unified_printer_service.dart';
import '../services/repair_partner_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/payment_intent_service.dart';
import '../services/category_service.dart';
import '../models/printer_types.dart';
import '../widgets/printer_selection_dialog.dart';
import '../widgets/responsive_wrapper.dart';
import '../widgets/supplier_picker_sheet.dart';
import '../services/notification_service.dart';
import '../services/sync_orchestrator.dart';
import '../services/sync_service.dart';
import '../services/firestore_service.dart';
import '../services/firestore_write_helper.dart';
import '../services/user_service.dart';
import '../services/audit_service.dart';
import '../services/financial_activity_service.dart';
import '../services/storage_service.dart';
import '../services/background_upload_service.dart';
import '../services/encryption_service.dart';
import 'package:image_picker/image_picker.dart';
import '../data/db_helper.dart';
import '../services/event_bus.dart';
import '../theme/app_button_styles.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_cached_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'inventory_view.dart';
import 'inventory_detail_view.dart';
import 'repair_partner_view.dart';
import '../widgets/bank_transfer_assist.dart';
import '../widgets/clickable_customer_header.dart';
import 'repair_invoice_template_view.dart';
import 'repair_invoice_preview_view.dart';
import '../widgets/storage_location_selector.dart';
import '../models/storage_location_model.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/app_popup.dart';
import '../theme/popup_theme.dart';

class RepairDetailView extends StatefulWidget {
  final Repair repair;
  const RepairDetailView({super.key, required this.repair});

  @override
  State<RepairDetailView> createState() => _RepairDetailViewState();
}

class _RepairDetailViewState extends State<RepairDetailView> {
  final db = DBHelper();
  late Repair r;
  // NCC của phụ tùng tra theo productId — bù cho đơn cũ chưa lưu supplier.
  final Map<int, String> _partSupplierByPid = {};
  bool _isUpdating = false;
  bool _isPrinting = false;
  String _shopName = "";
  String _shopAddr = "";
  String _shopPhone = "";
  bool _hasPermission = false;
  bool _canViewRevenue = false;
  bool _canViewCostPrice = false;
  bool _canEditRepairOrder = false; // Manager: sửa/xóa linh kiện, tài chính
  bool _canEditRepairBasicInfo =
      false; // Staff: sửa thông tin cơ bản (tên KH, model, lỗi...)
  bool _isManagerLike = false;
  bool _canEditRepairNotes = false;
  bool _canAddRepairImage = false;
  bool _canEditRepairFinancial = false;
  bool _canEditRepairCharge = false;
  List<RepairPartner> _partners = [];
  String? _lastModifiedBy;
  int? _lastModifiedAt;

  // Tra sản phẩm theo tên cho phụ tùng KHÔNG có partsUsedDetailed (đơn cũ /
  // luồng thêm phụ tùng không lưu productId) — chỉ để hiển thị NCC; việc mở
  // đúng linh kiện khi chạm vẫn tự tra lại qua _openPartInInventory.
  final Map<String, Product?> _legacyPartLookup = {};

  // Chỉ cho sửa giá/vốn khi giao trong ngày; qua ngày → khóa
  bool get _isDeliverySameDay {
    final deliveredAt = r.deliveredAt;
    if (deliveredAt == null || deliveredAt == 0)
      return true; // chưa giao → đang giao ngay bây giờ
    final d = DateTime.fromMillisecondsSinceEpoch(deliveredAt);
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  // Shop settings for dynamic terminology (reserved for future multi-industry use)
  // ignore: unused_field
  ShopSettings? _shopSettings;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _repairDocSubscription;
  bool _hasReceivedServerDocSnapshot = false;

  AppLocalizations get loc => AppLocalizations.of(context)!;

  bool get _canViewAnyFinancial => _canViewRevenue || _canViewCostPrice;

  // Bảng giá thông minh — chỉ tính 1 lần khi vào màn hình, không tính lại
  // mỗi lần rebuild. Chỉ đọc local SQLite, không thay đổi giá/logic tài chính.
  PricingSuggestion? _historicalPricing;

  @override
  void initState() {
    super.initState();
    r = widget.repair;
    _loadShopSettings();
    _checkPermission();
    _loadShopInfo();
    _loadPartners();
    unawaited(
      _loadFreshRepairFromDb().then((_) {
        _loadPartSuppliers();
        _loadLegacyPartsLookup();
      }),
    );
    unawaited(_startRepairRealtimeListener(forceRestart: true));
    unawaited(_loadLastModifierInfo());
    unawaited(_loadHistoricalPricing());
  }

  /// Tra NCC cho các phụ tùng có productId nhưng chưa lưu supplier (đơn cũ).
  Future<void> _loadPartSuppliers() async {
    try {
      final pids = <int>{
        for (final p in r.partsUsedDetailed)
          if (p.productId != null &&
              (p.supplier ?? '').trim().isEmpty &&
              !_partSupplierByPid.containsKey(p.productId))
            p.productId!,
      };
      if (pids.isEmpty) return;
      final map = <int, String>{};
      for (final pid in pids) {
        final prod = await db.getProductById(pid);
        final sup = (prod?.supplier ?? '').trim();
        if (sup.isNotEmpty) map[pid] = sup;
      }
      if (map.isNotEmpty && mounted) {
        setState(() => _partSupplierByPid.addAll(map));
      }
    } catch (e) {
      debugPrint('_loadPartSuppliers: $e');
    }
  }

  /// Tách "PIN IPHONE 11 x1, MÀN HÌNH IP12 x2" → [(tên, sl), ...].
  List<(String, int)> _parsePartsUsedText(String text) {
    return text
        .split(', ')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .map((p) {
          final m = RegExp(r'^(.+)\s+x(\d+)$').firstMatch(p);
          if (m == null) return (p, 1);
          return (m.group(1)!.trim(), int.tryParse(m.group(2)!) ?? 1);
        })
        .toList();
  }

  /// Tra sản phẩm theo tên cho phụ tùng KHÔNG có partsUsedDetailed (đơn cũ) —
  /// chỉ để hiển thị đúng NCC ngay trên màn; việc mở đúng linh kiện khi chạm
  /// tự tra lại (không phụ thuộc cache này) nên vẫn đúng dù cache chưa xong.
  Future<void> _loadLegacyPartsLookup() async {
    if (r.partsUsedDetailed.isNotEmpty || r.partsUsed.trim().isEmpty) return;
    try {
      final names = _parsePartsUsedText(r.partsUsed)
          .map((e) => e.$1)
          .where((n) => n.isNotEmpty && !_legacyPartLookup.containsKey(n))
          .toSet();
      if (names.isEmpty) return;
      final map = <String, Product?>{};
      for (final name in names) {
        map[name] = await db.getProductByNameFlexible(name);
      }
      if (mounted) setState(() => _legacyPartLookup.addAll(map));
    } catch (e) {
      debugPrint('_loadLegacyPartsLookup: $e');
    }
  }

  Future<void> _loadHistoricalPricing() async {
    try {
      final issueOrService = r.issue.trim().isNotEmpty
          ? r.issue
          : (r.services.length == 1 ? r.services.first.serviceName : null);
      final suggestion = await PricingEngineService.getSuggestion(
        model: r.model,
        issueOrService: issueOrService,
      );
      if (mounted) setState(() => _historicalPricing = suggestion);
    } catch (e) {
      debugPrint('⚠️ [RepairDetailView] Lịch sử giá lỗi: $e');
    }
  }

  /// Load bản mới nhất từ local DB để tránh hiển thị stale data từ list
  Future<void> _loadFreshRepairFromDb() async {
    try {
      Repair? fresh;
      if (r.id != null) fresh = await db.getRepairById(r.id!);
      fresh ??= r.firestoreId != null
          ? await db.getRepairByFirestoreId(r.firestoreId!)
          : null;
      if (fresh != null && mounted) setState(() => r = fresh!);
    } catch (e) {
      debugPrint('_loadFreshRepairFromDb error: $e');
    }
  }

  Future<void> _startRepairRealtimeListener({bool forceRestart = false}) async {
    final targetId = (r.firestoreId ?? '').trim();
    if (targetId.isEmpty) return;

    if (!forceRestart && _repairDocSubscription != null) {
      return;
    }

    await _repairDocSubscription?.cancel();
    _repairDocSubscription = null;
    _hasReceivedServerDocSnapshot = false;

    _repairDocSubscription = FirestoreService.watchRepairDoc(targetId).listen(
      (snapshot) {
        unawaited(_applyRepairDocSnapshot(snapshot));
      },
      onError: (error) {
        debugPrint('❌ [RepairDetailView] Realtime doc listener lỗi: $error');
      },
    );
  }

  Future<void> _applyRepairDocSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) async {
    if (!snapshot.exists) return;

    if (snapshot.metadata.isFromCache && _hasReceivedServerDocSnapshot) {
      return;
    }

    if (!snapshot.metadata.isFromCache) {
      _hasReceivedServerDocSnapshot = true;
    }

    try {
      final rawData = Map<String, dynamic>.from(snapshot.data() ?? {});
      final data = EncryptionService.decryptMap(rawData);
      if (data['deleted'] == true) return;

      SyncService.convertTimestampFieldsPublic(data);
      data['firestoreId'] = snapshot.id;
      data['isSynced'] = 1;

      final isPartialSnapshot = _isPartialRepairSnapshot(data);
      final latest = Repair.fromMap(data);
      var safeLatest = await _mergeSnapshotWithLocalIfPartial(data, latest);
      safeLatest = await _protectLocalUnsyncedRepairFromStaleCloud(
        data,
        safeLatest,
      );

      // Khi đang xử lý thao tác cập nhật và snapshot cloud chỉ là patch trạng thái,
      // bỏ qua để tránh ghi đè đơn local thành giá 0/thiếu dữ liệu.
      if (_isUpdating && isPartialSnapshot) {
        debugPrint(
          'ℹ️ [RepairDetailView] Skip partial realtime snapshot while updating: ${snapshot.id}',
        );
        return;
      }

      final recoveredLocalData =
          isPartialSnapshot &&
          (safeLatest.price > 0 ||
              safeLatest.cost > 0 ||
              safeLatest.services.isNotEmpty ||
              safeLatest.customerName.trim().isNotEmpty ||
              safeLatest.model.trim().isNotEmpty);

      if (recoveredLocalData) {
        // Snapshot cloud bị thiếu dữ liệu, giữ bản local đầy đủ và ép sync ngược.
        safeLatest.isSynced = false;
      }

      await db.upsertRepair(safeLatest);

      if (recoveredLocalData && safeLatest.id != null) {
        try {
          await SyncOrchestrator().enqueue(
            entityType: SyncEntityType.repair,
            entityId: safeLatest.id!,
            firestoreId: safeLatest.firestoreId,
            operation: SyncOperation.update,
            data: safeLatest.toMap(),
          );
          // ignore: unawaited_futures
          unawaited(SyncOrchestrator().syncAll());
        } catch (e) {
          debugPrint(
            '⚠️ [RepairDetailView] enqueue heal partial repair snapshot lỗi: $e',
          );
        }
      }

      if (!mounted || _isUpdating) return;
      setState(() => r = safeLatest);
      unawaited(_loadLastModifierInfo());
    } catch (e) {
      debugPrint('⚠️ [RepairDetailView] _applyRepairDocSnapshot lỗi: $e');
    }
  }

  bool _isPartialRepairSnapshot(Map<String, dynamic> data) {
    final hasIdentity =
        (data['customerName']?.toString().trim().isNotEmpty ?? false) ||
        (data['model']?.toString().trim().isNotEmpty ?? false) ||
        (data['phone']?.toString().trim().isNotEmpty ?? false);
    final hasFinancial =
        data.containsKey('price') ||
        data.containsKey('cost') ||
        data.containsKey('totalCost') ||
        data.containsKey('services') ||
        data.containsKey('requestedDeliveryPrice');
    final hasCreatedAt = _parseTimestamp(data['createdAt']) > 0;

    return !hasIdentity && !hasFinancial && !hasCreatedAt;
  }

  Future<Repair> _mergeSnapshotWithLocalIfPartial(
    Map<String, dynamic> cloudData,
    Repair cloudRepair,
  ) async {
    if (!_isPartialRepairSnapshot(cloudData)) {
      return cloudRepair;
    }

    final firestoreId = (cloudRepair.firestoreId ?? '').trim();
    if (firestoreId.isEmpty) {
      return cloudRepair;
    }

    final localRepair = await db.getRepairByFirestoreId(firestoreId);
    if (localRepair == null) {
      return cloudRepair;
    }

    return localRepair.copyWith(
      status: cloudRepair.status,
      pendingDeliveryApproval: cloudRepair.pendingDeliveryApproval,
      requestedDeliveryPrice: cloudRepair.requestedDeliveryPrice != null
          ? cloudRepair.requestedDeliveryPrice
          : localRepair.requestedDeliveryPrice,
      lastCaredAt: cloudRepair.lastCaredAt ?? localRepair.lastCaredAt,
      finishedAt: cloudRepair.finishedAt ?? localRepair.finishedAt,
      deliveredAt: cloudRepair.deliveredAt ?? localRepair.deliveredAt,
      repairedBy: (cloudRepair.repairedBy ?? '').trim().isNotEmpty
          ? cloudRepair.repairedBy
          : localRepair.repairedBy,
      repairedByUid: (cloudRepair.repairedByUid ?? '').trim().isNotEmpty
          ? cloudRepair.repairedByUid
          : localRepair.repairedByUid,
      deliveredBy: (cloudRepair.deliveredBy ?? '').trim().isNotEmpty
          ? cloudRepair.deliveredBy
          : localRepair.deliveredBy,
      deliveredByUid: (cloudRepair.deliveredByUid ?? '').trim().isNotEmpty
          ? cloudRepair.deliveredByUid
          : localRepair.deliveredByUid,
      paymentMethod: cloudRepair.paymentMethod.trim().isNotEmpty
          ? cloudRepair.paymentMethod
          : localRepair.paymentMethod,
    );
  }

  int _extractCloudRepairTimeMs(Map<String, dynamic> cloudData) {
    final updatedAt = _parseTimestamp(cloudData['updatedAt']);
    if (updatedAt > 0) return updatedAt;

    final lastCaredAt = _parseTimestamp(cloudData['lastCaredAt']);
    if (lastCaredAt > 0) return lastCaredAt;

    final deliveredAt = _parseTimestamp(cloudData['deliveredAt']);
    if (deliveredAt > 0) return deliveredAt;

    final finishedAt = _parseTimestamp(cloudData['finishedAt']);
    if (finishedAt > 0) return finishedAt;

    return _parseTimestamp(cloudData['createdAt']);
  }

  Future<Repair> _protectLocalUnsyncedRepairFromStaleCloud(
    Map<String, dynamic> cloudData,
    Repair cloudRepair,
  ) async {
    final firestoreId = (cloudRepair.firestoreId ?? '').trim();
    if (firestoreId.isEmpty) {
      return cloudRepair;
    }

    final localRepair = await db.getRepairByFirestoreId(firestoreId);
    if (localRepair == null || localRepair.isSynced) {
      return cloudRepair;
    }

    // Status 4 (đã giao) là trạng thái cuối — cloud approval luôn thắng.
    // Tránh trường hợp: staff submit chờ duyệt (local unsynced),
    // manager duyệt trên máy khác → cloud status=4 bị block bởi protection.
    if (cloudRepair.status == 4 && localRepair.status < 4) {
      debugPrint(
        '🔓 [RepairDetailView] Cloud approved delivery (status 4) overrides local pending for $firestoreId',
      );
      return cloudRepair;
    }

    final localTime = localRepair.lastCaredAt ?? localRepair.createdAt;
    final cloudTime = _extractCloudRepairTimeMs(cloudData);

    // Cloud chỉ được phép ghi đè khi thật sự mới hơn local unsynced.
    const toleranceMs = 5000;
    final cloudClearlyNewer =
        cloudTime > 0 && cloudTime > localTime + toleranceMs;
    if (cloudClearlyNewer) {
      return cloudRepair;
    }

    debugPrint(
      '🛡️ [RepairDetailView] Keep local unsynced repair $firestoreId (local: $localTime, cloud: $cloudTime)',
    );

    // Cloud cũ hơn local — giữ nguyên status và pendingDeliveryApproval của local.
    // Chỉ merge các field không xung đột (lastCaredAt, repairedBy, v.v.)
    // KHÔNG copy status/pendingDeliveryApproval từ cloud vì đó là dữ liệu stale
    // sẽ ghi đè thay đổi local rồi sync ngược lên cloud gây mất trạng thái.
    return localRepair.copyWith(
      requestedDeliveryPrice:
          cloudRepair.requestedDeliveryPrice ??
          localRepair.requestedDeliveryPrice,
      lastCaredAt:
          (cloudRepair.lastCaredAt ?? 0) > (localRepair.lastCaredAt ?? 0)
          ? cloudRepair.lastCaredAt
          : localRepair.lastCaredAt,
      finishedAt: cloudRepair.finishedAt ?? localRepair.finishedAt,
      deliveredAt: cloudRepair.deliveredAt ?? localRepair.deliveredAt,
      repairedBy: (cloudRepair.repairedBy ?? '').trim().isNotEmpty
          ? cloudRepair.repairedBy
          : localRepair.repairedBy,
      repairedByUid: (cloudRepair.repairedByUid ?? '').trim().isNotEmpty
          ? cloudRepair.repairedByUid
          : localRepair.repairedByUid,
      deliveredBy: (cloudRepair.deliveredBy ?? '').trim().isNotEmpty
          ? cloudRepair.deliveredBy
          : localRepair.deliveredBy,
      deliveredByUid: (cloudRepair.deliveredByUid ?? '').trim().isNotEmpty
          ? cloudRepair.deliveredByUid
          : localRepair.deliveredByUid,
      paymentMethod: cloudRepair.paymentMethod.trim().isNotEmpty
          ? cloudRepair.paymentMethod
          : localRepair.paymentMethod,
    );
  }

  String _normalizeActionText(String rawAction) {
    return rawAction.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isWalkInRepair(Repair repair) {
    if (repair.isWalkIn) return true;

    bool looksWalkIn(String? raw) {
      final value = _normalizeActionText(raw ?? '');
      if (value.isEmpty) return false;
      return value.contains('KHÁCH VÃNG LAI') ||
          value.contains('KHACH VANG LAI') ||
          value.contains('KHÁCH LẺ') ||
          value.contains('KHACH LE') ||
          value.contains('WALK IN') ||
          value == 'VÃNG LAI' ||
          value == 'VANG LAI';
    }

    return looksWalkIn(repair.customerName) || looksWalkIn(repair.walkInName);
  }

  Future<String> _resolveCurrentStaffName({String fallback = 'NV'}) async {
    try {
      final name = (await UserService.getCurrentUserName()).trim();
      if (name.isNotEmpty) return name;
    } catch (_) {}

    final email = (FirebaseAuth.instance.currentUser?.email ?? '').trim();
    if (email.isNotEmpty && email.contains('@')) {
      final prefix = email.split('@').first.trim();
      if (prefix.isNotEmpty) {
        return prefix[0].toUpperCase() + prefix.substring(1);
      }
    }

    return fallback;
  }

  bool _isDeliveryRequestAction(String rawAction) {
    final action = _normalizeActionText(rawAction);
    if (action.isEmpty) return false;

    final localizedAction = _normalizeActionText(
      loc.actionRequestDeliveryApproval,
    );
    return action == localizedAction ||
        action == 'YÊU CẦU DUYỆT GIAO' ||
        action == 'REQUEST DELIVERY APPROVAL';
  }

  Future<int?> _findDeliveryRequestedAt() async {
    final targetId = (r.firestoreId ?? '').trim();
    if (targetId.isEmpty) return null;

    try {
      final dbConn = await db.database;
      final rows = await dbConn.query(
        'audit_logs',
        columns: ['action', 'createdAt'],
        where: 'targetType = ? AND targetId = ?',
        whereArgs: ['REPAIR', targetId],
        orderBy: 'createdAt DESC',
        limit: 40,
      );

      for (final row in rows) {
        final action = row['action']?.toString() ?? '';
        if (!_isDeliveryRequestAction(action)) continue;

        final createdAt = _parseTimestamp(row['createdAt']);
        if (createdAt > 0) return createdAt;
      }
    } catch (e) {
      debugPrint('⚠️ [RepairDetailView] _findDeliveryRequestedAt lỗi: $e');
    }

    return null;
  }

  Future<void> _loadLastModifierInfo() async {
    final targetId = (r.firestoreId ?? '').trim();
    if (targetId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _lastModifiedBy = null;
        _lastModifiedAt = null;
      });
      return;
    }

    try {
      final dbConn = await db.database;
      final rows = await dbConn.query(
        'audit_logs',
        columns: ['userName', 'action', 'createdAt'],
        where: 'targetType = ? AND targetId = ?',
        whereArgs: ['REPAIR', targetId],
        orderBy: 'createdAt DESC',
        limit: 30,
      );

      Map<String, dynamic>? modifierRow;
      for (final row in rows) {
        final action = row['action']?.toString() ?? '';
        if (_isRepairEditAction(action)) {
          modifierRow = row;
          break;
        }
      }

      String? modifiedBy;
      int? modifiedAt;

      if (modifierRow != null) {
        final userName = modifierRow['userName']?.toString();
        final label = _staffLabel(userName);
        if (label != '---') {
          modifiedBy = label;
        }

        final parsedAt = _parseTimestamp(modifierRow['createdAt']);
        if (parsedAt > 0) {
          modifiedAt = parsedAt;
        }
      }

      if (!mounted) return;
      setState(() {
        _lastModifiedBy = modifiedBy;
        _lastModifiedAt = modifiedAt;
      });
    } catch (e) {
      debugPrint('⚠️ [RepairDetailView] _loadLastModifierInfo lỗi: $e');
    }
  }

  bool _isRepairEditAction(String rawAction) {
    final action = _normalizeActionText(rawAction);
    if (action.isEmpty) return false;

    final localizedEditAction = _normalizeActionText(loc.editRepairAction);
    return action == localizedEditAction ||
        action == 'SỬA ĐƠN SỬA' ||
        action == 'CHỈNH SỬA THÔNG TIN ĐƠN SỬA' ||
        action == 'EDIT REPAIR';
  }

  int _parseTimestamp(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  String _statusFlowFor(int status, {required bool pendingApproval}) {
    if (status <= 1) return 'received';
    if (status == 2) return 'repairing';
    if (status == 3) {
      return pendingApproval ? 'pending_approval' : 'approved';
    }
    return 'delivered';
  }

  Future<Repair?> _loadPersistedRepairSnapshot() async {
    if (r.id != null) {
      return db.getRepairById(r.id!);
    }
    final firestoreId = (r.firestoreId ?? '').trim();
    if (firestoreId.isEmpty) return null;
    return db.getRepairByFirestoreId(firestoreId);
  }

  int _displayedChargePrice(Repair repair) {
    final requested = repair.requestedDeliveryPrice;
    if (repair.pendingDeliveryApproval && requested != null) {
      return requested;
    }
    return repair.price;
  }

  bool _hideDeliveredSensitiveFinancial(Repair repair) {
    return repair.status == 4 && !(_canViewRevenue && _canViewCostPrice);
  }

  String _displayedPriceLabel(Repair repair) {
    final requested = repair.requestedDeliveryPrice;
    if (repair.pendingDeliveryApproval && requested != null) {
      return 'Giá yêu cầu';
    }
    return loc.priceLabel;
  }

  bool _hasFinancialImpact(Repair? previous, Repair current) {
    if (previous == null) {
      return current.price != 0 ||
          current.cost != 0 ||
          (current.requestedDeliveryPrice ?? 0) != 0 ||
          current.paymentMethod.trim().isNotEmpty ||
          current.status == 4;
    }

    return previous.price != current.price ||
        previous.cost != current.cost ||
        previous.requestedDeliveryPrice != current.requestedDeliveryPrice ||
        previous.paymentMethod != current.paymentMethod ||
        previous.costRecordedInFund != current.costRecordedInFund ||
        previous.costPaymentMethod != current.costPaymentMethod ||
        previous.costRecordedAmount != current.costRecordedAmount ||
        previous.status != current.status ||
        previous.pendingDeliveryApproval != current.pendingDeliveryApproval;
  }

  void _emitRepairChanged({
    bool financialImpact = false,
    bool includeDebts = false,
    bool includeServiceChanges = false,
  }) {
    final eventBus = EventBus();
    eventBus.emit(EventBus.repairsChanged);
    if (financialImpact) {
      eventBus.emit(EventBus.financialChanged);
    }
    if (includeDebts) {
      eventBus.emit('debts_changed');
    }
    if (includeServiceChanges) {
      eventBus.emit('repair_services_changed');
    }
  }

  Future<void> _pushRepairStatusToCloud({
    required int status,
    required bool pendingApproval,
    int? finishedAt,
    int? deliveredAt,
    String? repairedBy,
    String? repairedByUid,
    String? deliveredBy,
    String? deliveredByUid,
    String? paymentMethod,
    int? requestedDeliveryPrice,
    bool includeRequestedDeliveryPrice = false,
  }) async {
    final targetId = (r.firestoreId ?? '').trim();
    if (targetId.isEmpty) return;

    final payload = <String, dynamic>{
      'status': status,
      'statusFlow': _statusFlowFor(status, pendingApproval: pendingApproval),
      'pendingDeliveryApproval': pendingApproval,
      // Gồm luôn giá thu/vốn hiện tại trong patch — trước đây patch này chỉ
      // có trạng thái, để trống 1 khoảng hở giữa lúc trạng thái lên cloud
      // và lúc giá lên cloud (ghi riêng, có thể trễ/lỗi mạng), khiến cloud
      // tạm thời/vĩnh viễn có trạng thái mới nhưng giá cũ.
      'price': r.price,
      'cost': r.cost,
      'updatedAt': FirestoreWriteHelper.serverUpdatedAt(),
    };

    // Include storage location in patch so listener never sees a stale doc without location
    if ((r.storageLocationId ?? '').isNotEmpty) {
      payload['storageLocationId'] = r.storageLocationId;
    }
    if ((r.storageLocationCode ?? '').isNotEmpty) {
      payload['storageLocationCode'] = r.storageLocationCode;
    }
    if ((r.storageLocationName ?? '').isNotEmpty) {
      payload['storageLocationName'] = r.storageLocationName;
    }

    final lastCaredAt = r.lastCaredAt;
    if (lastCaredAt != null && lastCaredAt > 0) {
      payload['lastCaredAt'] = lastCaredAt;
    }
    if (finishedAt != null && finishedAt > 0) {
      payload['finishedAt'] = finishedAt;
    }
    if (deliveredAt != null && deliveredAt > 0) {
      payload['deliveredAt'] = deliveredAt;
    }
    if ((repairedBy ?? '').trim().isNotEmpty) {
      payload['repairedBy'] = repairedBy!.trim();
    }
    if ((repairedByUid ?? '').trim().isNotEmpty) {
      payload['repairedByUid'] = repairedByUid!.trim();
    }
    if ((deliveredBy ?? '').trim().isNotEmpty) {
      payload['deliveredBy'] = deliveredBy!.trim();
    }
    if ((deliveredByUid ?? '').trim().isNotEmpty) {
      payload['deliveredByUid'] = deliveredByUid!.trim();
    }
    if ((paymentMethod ?? '').trim().isNotEmpty) {
      payload['paymentMethod'] = paymentMethod!.trim();
    }
    if (includeRequestedDeliveryPrice) {
      payload['requestedDeliveryPrice'] = requestedDeliveryPrice;
    }

    final docSnapshot = await FirestoreService.getRepairDoc(targetId);
    if (!docSnapshot.exists) {
      // Nếu doc chưa tồn tại trên cloud mà chỉ set patch status,
      // Firestore sẽ tạo doc thiếu trường và làm local bị ghi đè về 0 khi listener chạy.
      // Bootstrap full payload trước để tránh mất price/cost/customer/model.
      final bootstrap = Map<String, dynamic>.from(r.toMap());
      bootstrap['firestoreId'] = targetId;
      bootstrap['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
      final shopId = (await UserService.getCurrentShopId())?.trim();
      if (shopId != null && shopId.isNotEmpty) {
        bootstrap['shopId'] = shopId;
      }
      bootstrap.addAll(payload);

      final encryptedBootstrap = EncryptionService.encryptMap(bootstrap);
      await FirestoreService.upsertRepairPatchByFirestoreId(
        targetId,
        encryptedBootstrap,
      );
      return;
    }

    await FirestoreService.upsertRepairPatchByFirestoreId(targetId, payload);
  }

  @override
  void dispose() {
    _repairDocSubscription?.cancel();
    super.dispose();
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

  Future<void> _loadPartners() async {
    try {
      final partnerService = RepairPartnerService();
      final partners = await partnerService.getRepairPartners();
      if (!mounted) return;
      setState(() {
        _partners = partners;
        // Resolve partnerName cho các dịch vụ đã có partnerId
        for (final s in r.services) {
          if (s.partnerId != null && s.partnerName == null) {
            final match = partners.where((p) => p.id == s.partnerId);
            if (match.isNotEmpty) {
              s.partnerName = match.first.name;
            }
          }
        }
      });
    } catch (e) {
      debugPrint('⚠️ [RepairDetailView] _loadPartners lỗi: $e');
    }
  }

  Future<void> _checkPermission() async {
    final perms = await UserService.getCurrentUserPermissions(
      forceRefresh: true,
    );
    // Lấy isManagerLike từ permissions map (cùng nguồn Firestore — tránh stale claims)
    final isManagerLike = perms['isManagerLike'] == true;
    final canViewCostPrice = perms['allowViewCostPrice'] == true;
    final canViewRevenue =
        perms['allowViewRevenue'] == true || canViewCostPrice;
    if (!mounted) return;
    setState(() {
      _hasPermission = perms['allowViewRepairs'] ?? false;
      _canViewRevenue = canViewRevenue;
      _canViewCostPrice = canViewCostPrice;
      _isManagerLike = isManagerLike;
      _canEditRepairOrder =
          isManagerLike; // Manager only: xóa linh kiện, tài chính
      _canEditRepairBasicInfo =
          isManagerLike ||
          perms['allowViewRepairs'] == true; // Staff: thông tin cơ bản
      _canEditRepairNotes =
          perms['allowViewRepairs'] ==
          true; // KTV/nhân viên được ghi chú và thêm dịch vụ
      _canAddRepairImage = perms['allowViewRepairs'] == true;
      _canEditRepairFinancial = isManagerLike && canViewRevenue;
      _canEditRepairCharge = perms['allowViewRepairs'] == true;
    });
  }

  bool _ensureCanEditRepairOrder() {
    if (_canEditRepairOrder) return true;
    NotificationService.showSnackBar(
      'Bạn không có quyền sửa thông tin đơn sửa chữa.',
      color: Colors.orange,
    );
    return false;
  }

  bool _ensureCanEditRepairCharge() {
    if (_canEditRepairCharge || _canEditRepairFinancial) return true;
    NotificationService.showSnackBar(
      'Bạn không có quyền sửa giá thu khách.',
      color: Colors.orange,
    );
    return false;
  }

  Future<void> _loadShopInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final rawShopName = (prefs.getString('shop_name') ?? '').trim();
    final normalizedShopName =
        rawShopName.toLowerCase() == 'shop new' ||
            rawShopName.toLowerCase() == 'shop_new' ||
            rawShopName.toLowerCase() == 'shopnew'
        ? 'Quản Lý Shop'
        : (rawShopName.isNotEmpty ? rawShopName : loc.defaultShopName);
    if (!mounted) return;
    setState(() {
      _shopName = normalizedShopName;
      _shopAddr = prefs.getString('shop_address') ?? loc.defaultShopDesc;
      _shopPhone = prefs.getString('shop_phone') ?? loc.defaultShopPhone;
    });
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

  Widget _buildSmartImage(String path) {
    final normalized = path.trim();
    if (_isGsStoragePath(normalized) || _isStorageRelativePath(normalized)) {
      return FutureBuilder<String?>(
        future: _resolveDisplayImagePath(normalized),
        builder: (context, snapshot) {
          final url = snapshot.data;
          if (url == null || url.isEmpty) {
            return const Icon(Icons.broken_image, color: AppColors.error);
          }
          return AppCachedImage(
            imageUrl: url,
            fit: BoxFit.cover,
            memCacheWidth: 400,
          );
        },
      );
    }
    if (normalized.startsWith('http') ||
        normalized.startsWith('blob:') ||
        normalized.startsWith('data:')) {
      return AppCachedImage(
        imageUrl: normalized,
        fit: BoxFit.cover,
        memCacheWidth: 400,
      );
    }
    if (kIsWeb) {
      return const Icon(Icons.broken_image, color: AppColors.error);
    }
    File file = File(normalized);
    if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
    return const Icon(Icons.cloud_download, color: AppColors.primary);
  }

  bool _isWebImageSource(String path) {
    return StorageService.isDisplayableCloudPath(path);
  }

  List<String> _displayableImages(List<String> images) {
    final normalized = images
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .where((path) {
          if (StorageService.isResolvableDisplayPath(path)) return true;
          return !kIsWeb;
        })
        .toList();
    if (!kIsWeb) return normalized;
    final web = normalized.where(_isWebImageSource).toList();
    return web;
  }

  /// Show location picker dialog before marking repair as done (status 3).
  Future<void> _promptLocationAndMarkDone() async {
    StorageLocation? pickedLoc;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text(
            'Chọn vị trí cất máy',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tuỳ chọn: chọn vị trí lưu kho để dễ tìm máy sau khi sửa xong.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                StorageLocationSelector(
                  selectedLocationId: pickedLoc?.firestoreId,
                  selectedLocationCode: pickedLoc?.code,
                  selectedLocationName: pickedLoc?.name,
                  onSelected: (loc) => setS(() => pickedLoc = loc),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Bỏ qua', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('XONG'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    // Save location to repair before updating status
    if (pickedLoc != null) {
      final updated = r.copyWith(
        storageLocationId: pickedLoc!.firestoreId ?? pickedLoc!.id?.toString(),
        storageLocationCode: pickedLoc!.code,
        storageLocationName: pickedLoc!.name,
        isSynced: false,
      );
      await db.upsertRepair(updated);
      setState(() => r = updated);
    }
    await _updateStatus(3);
  }

  Future<void> _updateStatus(int newStatus) async {
    if (_isUpdating) return; // Guard chống double-tap
    debugPrint(
      'Starting status update from ${r.status} to $newStatus for repair ${r.firestoreId}',
    );

    // Validate status transition using state machine
    final transitionError = RepairStatusValidator.getTransitionError(
      r.status,
      newStatus,
    );
    if (transitionError != null) {
      NotificationService.showSnackBar(transitionError, color: AppColors.error);
      return;
    }

    // FIX C-03: Set lock TRƯỚC await đầu tiên cho status 1/2/3.
    // Status 4 delegate sang _approveDelivery/_submitForDeliveryApproval có guard riêng.
    if (newStatus != 4) _isUpdating = true;

    final currentStaffName = await _resolveCurrentStaffName(fallback: 'NV');

    // Chỉ admin/owner mới được giao máy (status 4)
    // Nếu đơn đang chờ duyệt (pendingDeliveryApproval = true), phải duyệt trước
    if (newStatus == 4) {
      // Dùng _isManagerLike từ Firestore (tránh stale Claims với chủ shop/quản lý mới)
      final isManagerOrOwner = _isManagerLike;
      debugPrint(
        'Giao máy check: isManagerLike=$isManagerOrOwner, pending=${r.pendingDeliveryApproval}',
      );

      // Nhân viên bấm "Giao máy" -> chuyển sang "Chờ duyệt giao"
      // (status 3 + pendingDeliveryApproval = true). Quản lý/chủ shop sẽ duyệt.
      if (!isManagerOrOwner) {
        if (r.pendingDeliveryApproval) {
          NotificationService.showSnackBar(
            loc.orderPendingApproval,
            color: Colors.deepOrange,
          );
          return;
        }
        await _submitForDeliveryApproval();
        return;
      }

      // Admin/owner duyệt đơn chờ giao
      await _approveDelivery();
      return;
    }

    // NOTE: Code below is DEAD CODE - kept for reference only
    // Admin/owner always goes through _approveDelivery() above
    /*
    if (newStatus == 4) {
      // GIAO MÁY (DEAD CODE)
      String payMethod = loc.cash;
      String selectedWarranty = r.warranty.isEmpty ? loc.month1 : r.warranty;
      final List<String> warrantyOptions = [
        loc.noWarranty,
        loc.month1,
        loc.month3,
        loc.month6,
        loc.month12,
      ];

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final dialogLoc = AppLocalizations.of(ctx)!;
          return StatefulBuilder(
            builder: (ctx, setS) => AlertDialog(
              title: Text(dialogLoc.confirmDeliveryAndPayment),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dialogLoc.selectWarrantyPeriod,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: warrantyOptions
                        .map(
                          (opt) => ChoiceChip(
                            label: Text(opt, style: AppTextStyles.caption),
                            selected: selectedWarranty == opt,
                            onSelected: (v) =>
                                setS(() => selectedWarranty = opt),
                            selectedColor: AppColors.primary.withOpacity(0.2),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    dialogLoc.selectPaymentMethod,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [dialogLoc.cash, dialogLoc.transfer, dialogLoc.debt]
                        .map(
                          (m) => ChoiceChip(
                            label: Text(m, style: AppTextStyles.caption),
                            selected: payMethod == m,
                            onSelected: (v) => setS(() => payMethod = m),
                            selectedColor:
                                AppColors.secondary.withOpacity(0.2),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(dialogLoc.cancel),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: AppButtonStyles.elevatedButtonStyle,
                  child: Text(dialogLoc.completeDelivery,
                      style: AppTextStyles.button),
                ),
              ],
            ),
          );
        },
      );

      if (confirm != true) return;
      r.warranty = selectedWarranty;
      r.paymentMethod = payMethod;
      r.deliveredAt = DateTime.now().millisecondsSinceEpoch;

      final user = FirebaseAuth.instance.currentUser;
      final userName = user?.email?.split('@').first.toUpperCase() ?? "NV";

      // GHI NHẬT KÝ GIAO MÁY
      await db.logAction(
        userId: user?.uid ?? "0",
        userName: userName,
        action: loc.actionDeliverDevice,
        type: "REPAIR",
        targetId: r.firestoreId,
        desc: loc.deliveredDevice(r.model, r.customerName, selectedWarranty),
      );

      if (payMethod == "CÔNG NỢ") {
        // FIX: Tạo firestoreId TRƯỚC khi insert để tránh duplicate khi sync
        final debtFId =
            "debt_${DateTime.now().millisecondsSinceEpoch}_${r.phone.hashCode}";
        final debtId = await PaymentIntentService.createDebtRecord(
          debtType: "CUSTOMER_OWES",
          amount: r.price,
          personName: r.customerName,
          personPhone: r.phone,
          note: loc.debtNoteForRepair(r.model),
          linkedId: r.firestoreId,
          debtFirestoreId: debtFId,
        );

        // Tạo PaymentIntent cho việc thu nợ sau này (CHỜ THU)
        final intent = PaymentIntent(
          id: 'pi_repair_debt_${DateTime.now().millisecondsSinceEpoch}_${r.id}',
          type: PaymentIntentType.customerDebtCollection,
          amount: r.price,
          description: 'Thu tiền sửa máy: ${r.model} - ${r.customerName}',
          referenceId: debtFId,
          referenceType: 'repair_debt',
          personName: r.customerName,
          personPhone: r.phone,
          createdBy: user?.uid ?? 'unknown',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          metadata: {
            'repairId': r.id,
            'repairFirestoreId': r.firestoreId,
            'debtId': debtId,
            'debtFirestoreId': debtFId,
            'debtType': 'CUSTOMER_OWES',
          },
        );
        await PaymentIntentService.createIntent(intent);
        debugPrint('💳 Created PaymentIntent for repair debt collection: ${intent.id}');
      } else if (r.price > 0) {
        // Thanh toán tiền mặt/chuyển khoản - Tạo PaymentIntent (CHỜ THU)
        final intent = PaymentIntent(
          id: 'pi_repair_${DateTime.now().millisecondsSinceEpoch}_${r.id}',
          type: PaymentIntentType.repairService,
          amount: r.price,
          description: 'Thu tiền sửa máy: ${r.model} - ${r.customerName}',
          referenceId: r.firestoreId,
          referenceType: 'repair',
          personName: r.customerName,
          personPhone: r.phone,
          createdBy: user?.uid ?? 'unknown',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          metadata: {
            'repairId': r.id,
            'repairFirestoreId': r.firestoreId,
            'paymentMethod': payMethod,
            'model': r.model,
          },
        );
        await PaymentIntentService.createIntent(intent);
        debugPrint('💳 Created PaymentIntent for repair payment: ${intent.id}');
      }

      // GHIM ĐƠN SỬA VÀO CHAT NỘI BỘ KHI GIAO MÁY
      final key = r.firestoreId ?? "repair_${r.createdAt}";
      final summary = loc.repairOrderSummary(
          r.customerName, r.phone, r.model, '${MoneyUtils.formatCurrency(r.price)} đ');
      final msg = loc.chatDeviceDelivered(summary);
      await FirestoreService.sendChat(
        message: msg,
        senderId: user?.uid ?? 'guest',
        senderName: userName,
        linkedType: 'repair',
        linkedKey: key,
        linkedSummary: summary,
      );
    }
    */
    // END OF DEAD CODE BLOCK

    if (newStatus == 3) {
      r.finishedAt = DateTime.now().millisecondsSinceEpoch;
      // Ghi nhận người sửa xong = user hiện tại
      final user = FirebaseAuth.instance.currentUser;
      r.repairedBy = currentStaffName;
      r.repairedByUid = user?.uid;
      // Không tự động set pendingDeliveryApproval = true
      // Để user chủ động bấm nút "GIAO MÁY" sau khi sửa xong
    }

    // Update lastCaredAt for conflict resolution during sync
    r.lastCaredAt = DateTime.now().millisecondsSinceEpoch;
    r.isSynced = false; // Mark as needing sync

    setState(() {
      r.status = newStatus;
      _isUpdating = true;
    });
    try {
      debugPrint(
        'Updating repair status to $newStatus for repair ${r.firestoreId}',
      );
      await db.upsertRepair(r);

      try {
        await _pushRepairStatusToCloud(
          status: r.status,
          pendingApproval: r.pendingDeliveryApproval,
          finishedAt: r.finishedAt,
          deliveredAt: r.deliveredAt,
          repairedBy: r.repairedBy,
          repairedByUid: r.repairedByUid,
          deliveredBy: r.deliveredBy,
          deliveredByUid: r.deliveredByUid,
          paymentMethod: r.paymentMethod,
        );
      } catch (e) {
        debugPrint('⚠️ [RepairDetailView] Push status realtime lỗi: $e');
      }

      // Queue sync repair to cloud via SyncOrchestrator
      if (r.id != null) {
        await SyncOrchestrator().enqueue(
          entityType: SyncEntityType.repair,
          entityId: r.id!,
          firestoreId: r.firestoreId,
          operation: SyncOperation.update,
          data: r.toMap(),
        );

        // Run sync in background — don't block status update flow
        SyncOrchestrator().syncAll().then((_) {
          if (mounted) setState(() => r.isSynced = true);
        }).ignore();
      }

      debugPrint('Repair status updated successfully');
      NotificationService.showSnackBar(
        loc.statusUpdated(_getStatusText(newStatus)),
        color: AppColors.success,
      );
      _emitRepairChanged();

      // GỬI PUSH NOTIFICATION khi thay đổi trạng thái (trừ status 4 đã xử lý riêng)
      if (newStatus != 4) {
        try {
          final user = FirebaseAuth.instance.currentUser;
          final userName = currentStaffName;
          final key = r.firestoreId ?? "repair_${r.createdAt}";
          final summary = loc.repairOrderShare(
            r.customerName,
            r.phone,
            r.model,
            '',
          );

          String emoji = "";
          String statusMsg = "";
          switch (newStatus) {
            case 1:
              emoji = "📥";
              statusMsg = loc.statusReceivedMsg;
              break;
            case 2:
              emoji = "🔧";
              statusMsg = loc.statusStartRepairMsg;
              break;
            case 3:
              emoji = "✔️";
              statusMsg = loc.statusRepairDoneUpper;
              break;
          }

          final msg = "$emoji $statusMsg: $summary";

          // Gửi push notification cho mọi người
          await NotificationService.sendCloudNotification(
            title: '$emoji $statusMsg',
            body:
                '👤 ${r.customerName} • 📱 ${r.model}\n💰 ${MoneyUtils.formatCurrency(r.price)}đ',
            type: 'new_order',
            data: {'targetType': 'repair', 'targetId': key, 'repairId': key},
          );

          // Ghim vào chat nội bộ
          await FirestoreService.sendChat(
            message: msg,
            senderId: user?.uid ?? 'guest',
            senderName: userName,
            linkedType: 'repair',
            linkedKey: key,
            linkedSummary: summary,
          );
        } catch (e) {
          debugPrint('Failed to send status notification/chat: $e');
        }
      }
    } catch (e) {
      debugPrint('Error updating repair status: $e');
    }
    if (mounted) setState(() => _isUpdating = false);
  }

  String _getStatusText(int s, {bool pendingApproval = false}) {
    if (s == 3 && pendingApproval) {
      return loc.statusPendingApproval;
    }
    switch (s) {
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

  Color _getStatusColor(int s, {bool pendingApproval = false}) {
    if (s == 3 && pendingApproval) {
      return AppColors.repairPendingApproval;
    }
    switch (s) {
      case 1:
        return AppColors.repairReceived;
      case 2:
        return AppColors.repairRepairing;
      case 3:
        return AppColors.repairDone;
      case 4:
        return AppColors.primary;
      default:
        return Colors.grey;
    }
  }

  /// Nhân viên submit đơn chờ duyệt giao (pendingDeliveryApproval = true)
  Future<void> _submitForDeliveryApproval() async {
    if (_isUpdating) return; // Guard chống double-tap
    // Kiểm tra thông tin khách hàng trước khi giao máy
    // Khách vãng lai (isWalkIn) được phép giao mà không cần thông tin đầy đủ
    if (!_isWalkInRepair(r) &&
        (r.phone.trim().isEmpty || r.customerName.trim().isEmpty)) {
      // Có tên nhưng thiếu SĐT: cho phép bỏ qua giao máy luôn (đơn cũ nhập
      // thiếu, không chặn cứng nữa). Thiếu cả tên thì vẫn bắt buộc cập nhật
      // vì lúc đó gần như không xác định được đơn của khách nào.
      final hasNameOnly =
          r.customerName.trim().isNotEmpty && r.phone.trim().isEmpty;
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ Thiếu thông tin khách hàng'),
          content: Text(
            hasNameOnly
                ? 'Đơn này có tên khách nhưng chưa có số điện thoại. Bạn có thể cập nhật ngay, hoặc bỏ qua để giao máy luôn (sẽ khó liên hệ lại khách sau này).'
                : 'Vui lòng cập nhật thông tin khách hàng (Tên, SĐT) trước khi giao máy.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Hủy'),
            ),
            if (hasNameOnly)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'skip'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange.shade800,
                ),
                child: const Text('Bỏ qua, giao máy luôn'),
              ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'update'),
              child: const Text('Cập nhật ngay'),
            ),
          ],
        ),
      );
      if (action == 'update') {
        await _editBasicInfo();
        return;
      }
      if (action != 'skip') {
        return; // Hủy hoặc đóng dialog
      }
      // action == 'skip' → tiếp tục quy trình giao máy bên dưới
    }

    String payMethod = loc.cash;
    String selectedWarranty = r.warranty.isEmpty ? '1 tháng' : r.warranty;
    final List<String> warrantyOptions = [
      loc.noWarranty,
      '1 tháng',
      '3 tháng',
      '6 tháng',
      '12 tháng',
    ];
    final formKey = GlobalKey<FormState>();
    final priceCtrl = TextEditingController(
      text: CurrencyTextField.formatDisplay(_displayedChargePrice(r)),
    );

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final dialogLoc = AppLocalizations.of(ctx)!;
        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: Text(dialogLoc.sendApprovalRequest),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dialogLoc.orderWillBeSentForApproval,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CurrencyTextField(
                    controller: priceCtrl,
                    label: dialogLoc.chargeCustomerVnd,
                    validator: (v) => MoneyUtils.validateAmount(
                      v ?? '',
                      min: 0,
                      fieldName: dialogLoc.chargeCustomerLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    dialogLoc.selectWarrantyPeriod,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: warrantyOptions
                        .map(
                          (opt) => ChoiceChip(
                            label: Text(opt, style: AppTextStyles.caption),
                            selected: selectedWarranty == opt,
                            onSelected: (v) =>
                                setS(() => selectedWarranty = opt),
                            selectedColor: AppColors.primary.withOpacity(0.2),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    dialogLoc.selectPaymentMethod,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        [dialogLoc.cash, dialogLoc.transfer, dialogLoc.debt]
                            .map(
                              (m) => ChoiceChip(
                                label: Text(m, style: AppTextStyles.caption),
                                selected: payMethod == m,
                                onSelected: (v) => setS(() => payMethod = m),
                                selectedColor: AppColors.secondary.withOpacity(
                                  0.2,
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  if (payMethod == dialogLoc.transfer)
                    bankTransferAssistCard(
                      amountController: priceCtrl,
                      direction: BankPayDirection.inbound,
                      counterpartyName: r.customerName,
                      refText: 'Sua chua ${r.customerName}',
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(dialogLoc.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) {
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                ),
                child: Text(
                  dialogLoc.sendApprovalRequest,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirm != true) return;
    final parsedPrice = MoneyUtils.parseCurrency(priceCtrl.text);

    final user = FirebaseAuth.instance.currentUser;
    final userName = await _resolveCurrentStaffName(fallback: 'NV');
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    r.requestedDeliveryPrice = parsedPrice;
    r.warranty = selectedWarranty;
    r.paymentMethod = payMethod;
    r.lastCaredAt = nowMs;
    r.isSynced = false;

    setState(() {
      // Nếu đơn chưa ở status 3 (Sửa xong), chuyển lên status 3 trước
      if (r.status < 3) {
        r.status = 3;
        r.finishedAt = nowMs;
        // Ghi nhận người sửa xong
        r.repairedBy = userName;
        r.repairedByUid = user?.uid;
      }
      // Người gửi yêu cầu giao được xem là người giao thực tế.
      r.deliveredBy = userName;
      r.deliveredByUid = user?.uid;
      // Dùng thời điểm gửi yêu cầu duyệt làm mốc thời gian giao hiển thị.
      r.deliveredAt = nowMs;
      r.pendingDeliveryApproval = true; // Đánh dấu chờ duyệt
      _isUpdating = true;
    });

    try {
      await db.upsertRepair(r);

      try {
        await _pushRepairStatusToCloud(
          status: r.status,
          pendingApproval: r.pendingDeliveryApproval,
          finishedAt: r.finishedAt,
          deliveredAt: r.deliveredAt,
          repairedBy: r.repairedBy,
          repairedByUid: r.repairedByUid,
          deliveredBy: r.deliveredBy,
          deliveredByUid: r.deliveredByUid,
          paymentMethod: r.paymentMethod,
          requestedDeliveryPrice: r.requestedDeliveryPrice,
          includeRequestedDeliveryPrice: true,
        );
      } catch (e) {
        debugPrint(
          '⚠️ [RepairDetailView] Push pending approval realtime lỗi: $e',
        );
      }

      if (r.id != null) {
        await SyncOrchestrator().enqueue(
          entityType: SyncEntityType.repair,
          entityId: r.id!,
          firestoreId: r.firestoreId,
          operation: SyncOperation.update,
          data: r.toMap(),
        );

        // Await sync để tránh trạng thái pending kéo dài (nút sync vàng).
        try {
          await SyncOrchestrator().syncAll();
          if (mounted) setState(() => r.isSynced = true);
        } catch (_) {}
        // FIX: Also trigger targeted repair sync for reliability
        // ignore: unawaited_futures
        SyncService.syncRepairData();
      }

      final key = r.firestoreId ?? "repair_${r.createdAt}";

      // Gửi notification cho quản lý
      await NotificationService.sendCloudNotification(
        title: '📋 YÊU CẦU DUYỆT GIAO MÁY',
        body:
            '👤 ${r.customerName} • 📱 ${r.model}\n💰 ${MoneyUtils.formatCurrency(parsedPrice)}đ (giá yêu cầu)\n👷 $userName',
        type: 'approval_needed',
        data: {'targetType': 'repair', 'targetId': key, 'repairId': key},
      );

      // Log và chat
      await db.logAction(
        userId: user?.uid ?? "0",
        userName: userName,
        action: loc.actionRequestDeliveryApproval,
        type: "REPAIR",
        targetId: r.firestoreId,
        desc: loc.requestDeliveryApprovalDesc(r.model, r.customerName),
      );

      await FirestoreService.sendChat(
        message: loc.chatRequestDeliveryApproval(
          r.model,
          r.customerName,
          MoneyUtils.formatCurrency(parsedPrice),
        ),
        senderId: user?.uid ?? 'guest',
        senderName: userName,
        linkedType: 'repair',
        linkedKey: key,
        linkedSummary: loc.pendingDeliveryApproval(r.customerName),
      );

      NotificationService.showSnackBar(
        loc.sentDeliveryApprovalRequest,
        color: Colors.deepOrange,
      );
      _emitRepairChanged(financialImpact: false);
      // Trở về danh sách đơn sửa sau khi gửi yêu cầu giao
      if (mounted) Navigator.pop(context, true);
      return;
    } catch (e) {
      debugPrint('Error submitting for approval: $e');
    }
    if (mounted) setState(() => _isUpdating = false);
  }

  /// Quản lý duyệt đơn giao máy (pendingDeliveryApproval -> status 4)
  Future<void> _approveDelivery() async {
    if (_isUpdating) return; // Guard chống double-tap
    // Kiểm tra thông tin khách hàng trước khi giao máy
    // Khách vãng lai (isWalkIn) được phép giao mà không cần thông tin đầy đủ
    if (!_isWalkInRepair(r) &&
        (r.phone.trim().isEmpty || r.customerName.trim().isEmpty)) {
      // Có tên nhưng thiếu SĐT: cho phép bỏ qua duyệt giao luôn (đơn cũ
      // nhập thiếu, không chặn cứng nữa). Thiếu cả tên thì vẫn bắt buộc
      // cập nhật vì lúc đó gần như không xác định được đơn của khách nào.
      final hasNameOnly =
          r.customerName.trim().isNotEmpty && r.phone.trim().isEmpty;
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ Thiếu thông tin khách hàng'),
          content: Text(
            hasNameOnly
                ? 'Đơn này có tên khách nhưng chưa có số điện thoại. Bạn có thể cập nhật ngay, hoặc bỏ qua để duyệt giao luôn (sẽ khó liên hệ lại khách sau này).'
                : 'Vui lòng cập nhật thông tin khách hàng (Tên, SĐT) trước khi duyệt giao máy.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Hủy'),
            ),
            if (hasNameOnly)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'skip'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange.shade800,
                ),
                child: const Text('Bỏ qua, duyệt giao luôn'),
              ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'update'),
              child: const Text('Cập nhật ngay'),
            ),
          ],
        ),
      );
      if (action == 'update') {
        await _editBasicInfo();
        return;
      }
      if (action != 'skip') {
        return; // Hủy hoặc đóng dialog
      }
      // action == 'skip' → tiếp tục quy trình duyệt giao bên dưới
    }

    String selectedWarranty = r.warranty.isEmpty ? 'KO BH' : r.warranty;
    final List<String> warrantyOptions = [
      'KO BH',
      '1 THÁNG',
      '3 THÁNG',
      '6 THÁNG',
      '12 THÁNG',
    ];
    final requestedPriceForApproval = _displayedChargePrice(r);
    final formKey = GlobalKey<FormState>();
    final priceCtrl = TextEditingController(
      text: CurrencyTextField.formatDisplay(requestedPriceForApproval),
    );
    final costCtrl = TextEditingController(
      text: CurrencyTextField.formatDisplay(r.cost),
    );

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final dialogLoc = AppLocalizations.of(ctx)!;
        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: Text(dialogLoc.approveDelivery),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dialogLoc.customerInfo(r.customerName),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(dialogLoc.deviceInfo(r.model)),
                        Text(
                          dialogLoc.priceInfo(
                            MoneyUtils.formatCurrency(
                              requestedPriceForApproval,
                            ),
                          ),
                        ),
                        if (r.requestedDeliveryPrice != null)
                          Text(
                            'Giá hiện tại trong sổ: ${MoneyUtils.formatCurrency(r.price)}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                            ),
                          ),
                        Text(dialogLoc.paymentInfo(r.paymentMethod)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isDeliverySameDay) ...[
                    CurrencyTextField(
                      controller: priceCtrl,
                      label: dialogLoc.chargeCustomerVnd,
                      validator: (v) => MoneyUtils.validateAmount(
                        v ?? '',
                        min: 0,
                        fieldName: dialogLoc.chargeCustomerLabel,
                      ),
                    ),
                    const SizedBox(height: 10),
                    CurrencyTextField(
                      controller: costCtrl,
                      label: dialogLoc.partsCostVnd,
                      validator: (v) => MoneyUtils.validateAmount(
                        v ?? '',
                        min: 0,
                        fieldName: dialogLoc.partsCost,
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Giá bán/vốn chỉ sửa được trong ngày giao',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Thu: ${MoneyUtils.formatCurrency(r.price)} đ  •  Vốn: ${MoneyUtils.formatCurrency(r.cost)} đ',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    dialogLoc.selectWarrantyNote,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: warrantyOptions
                        .map(
                          (opt) => ChoiceChip(
                            label: Text(opt, style: AppTextStyles.caption),
                            selected: selectedWarranty == opt,
                            onSelected: (_) =>
                                setS(() => selectedWarranty = opt),
                            selectedColor: AppColors.primary.withOpacity(0.2),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    dialogLoc.confirmApproveDelivery,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(dialogLoc.cancel),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx, false);
                  // Từ chối - quay lại status 3
                  await _rejectDeliveryApproval();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(dialogLoc.reject),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) {
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text(
                  dialogLoc.approve,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirm != true) return;

    // Cho phép quản lý/chủ shop chỉnh lại bảo hành trước khi duyệt
    r.price = MoneyUtils.parseCurrency(priceCtrl.text);
    r.cost = MoneyUtils.parseCurrency(costCtrl.text);
    r.requestedDeliveryPrice = null;
    r.warranty = selectedWarranty;
    final debtImpact = r.paymentMethod == "CÔNG NỢ";

    final user = FirebaseAuth.instance.currentUser;
    final userName = await _resolveCurrentStaffName(fallback: 'QL');
    final approverName = userName;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final requestedDeliveryAt = await _findDeliveryRequestedAt();

    r.deliveredAt = requestedDeliveryAt ?? nowMs;
    r.lastCaredAt = nowMs;
    r.isSynced = false;

    // Giữ người giao do nhân viên đã gửi yêu cầu; chỉ fallback về người duyệt nếu chưa có.
    if ((r.deliveredBy ?? '').trim().isEmpty) {
      r.deliveredBy = userName;
      r.deliveredByUid = user?.uid;
    }
    final deliveredByName = (r.deliveredBy ?? '').trim().isNotEmpty
        ? (r.deliveredBy ?? '').trim()
        : approverName;

    setState(() {
      r.status = 4; // Đã giao
      r.pendingDeliveryApproval = false; // Reset pending flag
      r.storageLocationId = null; // Xóa vị trí khi giao máy về cho KH
      r.storageLocationCode = null;
      r.storageLocationName = null;
      _isUpdating = true;
    });

    try {
      // Tạo công nợ nếu thanh toán công nợ
      if (r.paymentMethod == "CÔNG NỢ") {
        final debtFId =
            "debt_${DateTime.now().millisecondsSinceEpoch}_${r.phone.hashCode}";
        final debtId = await PaymentIntentService.createDebtRecord(
          debtType: "CUSTOMER_OWES",
          amount: r.price,
          personName: r.customerName,
          personPhone: r.phone,
          note: loc.debtNoteRepair(r.model),
          linkedId: r.firestoreId,
          debtFirestoreId: debtFId,
        );

        // Tạo PaymentIntent để debt xuất hiện trong danh sách "Chờ thu"
        final intent = PaymentIntent(
          id: 'pi_repair_debt_${DateTime.now().millisecondsSinceEpoch}_${r.id}',
          type: PaymentIntentType.customerDebtCollection,
          amount: r.price,
          description: 'Thu tiền sửa máy: ${r.model} - ${r.customerName}',
          referenceId: debtFId,
          referenceType: 'repair_debt',
          personName: r.customerName,
          personPhone: r.phone,
          createdBy: user?.uid ?? 'unknown',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          metadata: {
            'repairId': r.id,
            'repairFirestoreId': r.firestoreId,
            'debtId': debtId,
            'debtFirestoreId': debtFId,
            'debtType': 'CUSTOMER_OWES',
          },
        );
        await PaymentIntentService.createIntent(intent);
        debugPrint('✅ Repair approval debt + PaymentIntent recorded: $debtFId');
      } else if (r.price > 0) {
        // Ghi nhận thu tiền sửa chữa trực tiếp
        final payResult = await PaymentIntentService.executePaymentDirect(
          type: PaymentIntentType.repairService,
          amount: r.price,
          paymentMethod: PaymentMethod.fromCode(r.paymentMethod),
          description: 'Thu tiền sửa máy: ${r.model} - ${r.customerName}',
          executedBy: user?.uid ?? 'unknown',
          referenceId: r.firestoreId,
          referenceType: 'repair',
          personName: r.customerName,
          personPhone: r.phone,
          idempotencyKey: r.firestoreId,
          metadata: {
            'repairId': r.id,
            'repairFirestoreId': r.firestoreId,
            'paymentMethod': r.paymentMethod,
            'model': r.model,
          },
        );
        debugPrint(
          '💳 Repair payment ${payResult.success ? "OK" : "FAILED"}: ${r.price}đ',
        );
      }

      await db.upsertRepair(r);

      bool cloudSynced = false;
      try {
        await _pushRepairStatusToCloud(
          status: r.status,
          pendingApproval: r.pendingDeliveryApproval,
          finishedAt: r.finishedAt,
          deliveredAt: r.deliveredAt,
          repairedBy: r.repairedBy,
          repairedByUid: r.repairedByUid,
          deliveredBy: r.deliveredBy,
          deliveredByUid: r.deliveredByUid,
          paymentMethod: r.paymentMethod,
          requestedDeliveryPrice: null,
          includeRequestedDeliveryPrice: true,
        );
        cloudSynced = true;
      } catch (e) {
        debugPrint(
          '⚠️ [RepairDetailView] Push approved delivery realtime lỗi: $e',
        );
      }

      if (r.id != null) {
        await SyncOrchestrator().enqueue(
          entityType: SyncEntityType.repair,
          entityId: r.id!,
          firestoreId: r.firestoreId,
          operation: SyncOperation.update,
          data: r.toMap(),
        );

        // Await sync để tránh trạng thái pending kéo dài (nút sync vàng).
        // Không cần chạy lại nếu bước push trực tiếp ở trên đã thành công.
        if (cloudSynced) {
          // Ghi trực tiếp đã thành công — tự đánh dấu isSynced=1 trong DB
          // ngay, vì cờ này chỉ do SyncOrchestrator set khi xử lý hàng đợi;
          // nếu không tự set ở đây, đọc lại DB ngay sau sẽ luôn thấy false
          // dù cloud đã nhận đúng, gây báo nhầm "chưa đồng bộ" mọi lúc.
          r.isSynced = true;
          await db.upsertRepair(r);
        } else {
          try {
            await SyncOrchestrator().syncAll();
          } catch (_) {}
        }
        // FIX: Also trigger targeted repair sync for reliability
        // ignore: unawaited_futures
        SyncService.syncRepairData();
      }

      // Đọc lại trạng thái đồng bộ THẬT SỰ từ DB — trước đây set isSynced=true
      // trong bộ nhớ ngay sau khi syncAll() chạy xong dù không xác nhận đúng
      // đơn này đã lên cloud, khiến bộ bảo vệ chống ghi đè coi local là "đã
      // sync" và có thể bị đồng bộ nền sau đó ghi đè ngược về dữ liệu cũ.
      final freshLocal = r.id != null ? await db.getRepairById(r.id!) : null;
      final actuallySynced = freshLocal?.isSynced ?? cloudSynced;
      if (actuallySynced && mounted) {
        setState(() => r.isSynced = true);
      }

      // Log
      await db.logAction(
        userId: user?.uid ?? "0",
        userName: userName,
        action: "DUYỆT GIAO MÁY",
        type: "REPAIR",
        targetId: r.firestoreId,
        desc: loc.approvedDelivery(r.model, r.customerName, r.warranty),
      );

      // Financial activity log (only for debt repairs - non-debt handled by PaymentIntentService)
      if (r.price > 0 && r.paymentMethod == 'CÔNG NỢ') {
        await FinancialActivityService.logRepair(
          firestoreId: r.firestoreId ?? 'repair_${r.createdAt}',
          amount: r.price,
          paymentMethod: r.paymentMethod,
          customerName: r.customerName,
          phone: r.phone,
          deviceModel: r.model,
          createdBy: user?.email,
        );
      }

      // Chat notification
      final key = r.firestoreId ?? "repair_${r.createdAt}";
      final summary = loc.repairOrderShare(
        r.customerName,
        r.phone,
        r.model,
        "${MoneyUtils.formatCurrency(r.price)}đ",
      );
      await FirestoreService.sendChat(
        message: loc.chatApprovedDelivery(summary),
        senderId: user?.uid ?? 'guest',
        senderName: userName,
        linkedType: 'repair',
        linkedKey: key,
        linkedSummary: summary,
      );

      // Push notification khi giao máy (status 4)
      try {
        final deliveredClock = DateFormat(
          'HH\'H\'mm',
        ).format(DateTime.fromMillisecondsSinceEpoch(r.deliveredAt!));
        await NotificationService.sendCloudNotification(
          title: '✅ ĐÃ DUYỆT GIAO MÁY • $deliveredClock',
          body:
              '👷 Giao: $deliveredByName • ⏰ $deliveredClock\n✅ Duyệt: $approverName\n👤 ${r.customerName} • 📱 ${r.model}\n💰 ${MoneyUtils.formatCurrency(r.price)}đ',
          type: 'new_order',
          data: {'targetType': 'repair', 'targetId': key, 'repairId': key},
        );
      } catch (e) {
        debugPrint('Failed to send delivery notification: $e');
      }

      NotificationService.showSnackBar(
        actuallySynced
            ? loc.approvedAndCompletedDelivery
            : '⚠️ Đã duyệt trên máy — mạng chập chờn nên CHƯA đồng bộ lên cloud, app sẽ tự thử lại. Vui lòng kiểm tra lại đơn này sau.',
        color: actuallySynced ? Colors.green : Colors.orange,
      );
      _emitRepairChanged(financialImpact: true, includeDebts: debtImpact);
      // Trở về danh sách đơn sửa sau khi duyệt giao
      if (mounted) Navigator.pop(context, true);
      return;
    } catch (e) {
      debugPrint('Error approving delivery: $e');
    }
    if (mounted) setState(() => _isUpdating = false);
  }

  /// Từ chối duyệt giao - reset pendingDeliveryApproval
  Future<void> _rejectDeliveryApproval() async {
    r.lastCaredAt = DateTime.now().millisecondsSinceEpoch;
    r.requestedDeliveryPrice = null;
    r.isSynced = false;

    setState(() {
      r.pendingDeliveryApproval =
          false; // Reset pending flag (giữ nguyên status 3)
      _isUpdating = true;
    });

    try {
      await db.upsertRepair(r);

      try {
        await _pushRepairStatusToCloud(
          status: r.status,
          pendingApproval: r.pendingDeliveryApproval,
          finishedAt: r.finishedAt,
          deliveredAt: r.deliveredAt,
          repairedBy: r.repairedBy,
          repairedByUid: r.repairedByUid,
          deliveredBy: r.deliveredBy,
          deliveredByUid: r.deliveredByUid,
          paymentMethod: r.paymentMethod,
          requestedDeliveryPrice: null,
          includeRequestedDeliveryPrice: true,
        );
      } catch (e) {
        debugPrint('⚠️ [RepairDetailView] Push reject realtime lỗi: $e');
      }

      if (r.id != null) {
        await SyncOrchestrator().enqueue(
          entityType: SyncEntityType.repair,
          entityId: r.id!,
          firestoreId: r.firestoreId,
          operation: SyncOperation.update,
          data: r.toMap(),
        );

        // Await sync để tránh trạng thái pending kéo dài (nút sync vàng).
        try {
          await SyncOrchestrator().syncAll();
          if (mounted) setState(() => r.isSynced = true);
        } catch (_) {}
        // FIX: Also trigger targeted repair sync for reliability
        // ignore: unawaited_futures
        SyncService.syncRepairData();
      }

      final user = FirebaseAuth.instance.currentUser;
      final userName = await _resolveCurrentStaffName(fallback: 'QL');

      await db.logAction(
        userId: user?.uid ?? "0",
        userName: userName,
        action: "TỪ CHỐI GIAO",
        type: "REPAIR",
        targetId: r.firestoreId,
        desc: loc.rejectDeliveryDesc(r.model),
      );

      NotificationService.showSnackBar(
        loc.rejectedBackToRepairDone,
        color: Colors.red,
      );
      _emitRepairChanged();
    } catch (e) {
      debugPrint('Error rejecting delivery: $e');
    }
    if (mounted) setState(() => _isUpdating = false);
  }

  Future<void> _saveData() async {
    // Cho phép: manager/owner/admin (_canEditRepairOrder) HOẶC nhân viên/KTV có quyền sửa đơn (_canEditRepairCharge hoặc _canEditRepairNotes)
    if (!_canEditRepairOrder && !_canEditRepairCharge && !_canEditRepairNotes) {
      _ensureCanEditRepairOrder();
      return;
    }
    setState(() => _isUpdating = true);
    HapticFeedback.mediumImpact();
    try {
      final previousSnapshot = await _loadPersistedRepairSnapshot();
      final financialImpact = _hasFinancialImpact(previousSnapshot, r);
      var debtChanged = false;

      // Update lastCaredAt for conflict resolution during sync
      r.lastCaredAt = DateTime.now().millisecondsSinceEpoch;
      r.isSynced = false; // Mark as needing sync

      await db.upsertRepair(r);

      // Ghi nhật ký sửa đơn
      final user = FirebaseAuth.instance.currentUser;
      final userName = await _resolveCurrentStaffName(fallback: 'NV');
      await db.logAction(
        userId: user?.uid ?? '0',
        userName: userName,
        action: loc.editRepairAction,
        type: 'REPAIR',
        targetId: r.firestoreId,
        desc:
            'Cập nhật đơn sửa ${r.model} - ${r.customerName} - Giá: ${r.price}đ',
      );

      // Đẩy lên cloud và CHỜ xác nhận thật sự — trước đây bắn đi không đợi
      // (unawaited) + nuốt lỗi im lặng, khiến app báo "Đã lưu" ngay cả khi
      // cloud chưa nhận được (mất mạng/chập chờn), rồi bị đồng bộ nền sau
      // đó ghi đè ngược local về dữ liệu cũ trên cloud mà không ai biết.
      bool cloudSynced = false;
      try {
        await FirestoreService.upsertRepair(
          r,
        ).timeout(const Duration(seconds: 8));
        cloudSynced = true;
      } catch (e) {
        debugPrint(
          '⚠️ [RepairDetailView] Direct cloud write lỗi, dựa vào hàng đợi sync: $e',
        );
      }
      // Luôn queue qua orchestrator để có cơ chế retry nếu lần ghi trực tiếp
      // ở trên thất bại; nếu đã thành công thì lần queue này chỉ ghi lại dữ
      // liệu giống hệt (vô hại, idempotent).
      if (r.id != null) {
        await SyncOrchestrator().enqueue(
          entityType: SyncEntityType.repair,
          entityId: r.id!,
          firestoreId: r.firestoreId,
          operation: SyncOperation.update,
          data: r.toMap(),
        );
        if (cloudSynced) {
          // Ghi trực tiếp đã thành công — tự đánh dấu isSynced=1 trong DB
          // ngay (cờ này chỉ do SyncOrchestrator set khi xử lý hàng đợi,
          // nếu không tự set ở đây thì đọc lại DB ngay sau sẽ luôn thấy
          // false dù cloud đã nhận đúng, gây báo nhầm "chưa đồng bộ").
          r.isSynced = true;
          await db.upsertRepair(r);
        } else {
          await SyncOrchestrator().syncAll();
        }
      }
      // Đọc lại trạng thái đồng bộ THẬT SỰ từ DB (không dựa vào biến isSynced
      // cũ trong bộ nhớ) để biết chắc có nên báo "Đã lưu" hay "đang đồng bộ".
      final freshLocal = r.id != null ? await db.getRepairById(r.id!) : null;
      final actuallySynced = freshLocal?.isSynced ?? cloudSynced;
      if (actuallySynced) {
        r.isSynced = true;
        if (mounted) setState(() {});
      }

      // Update debt if payment method is debt and repair is delivered
      if (r.paymentMethod == 'CÔNG NỢ' && r.status == 4) {
        final linkedDebt = (await db.getDebtsByLinkedId(
          r.firestoreId ?? '',
        )).firstOrNull;
        final debtAmount = r.price - r.cost; // Profit amount
        if (linkedDebt != null) {
          // Update existing debt
          linkedDebt['amount'] = debtAmount;
          linkedDebt['remainingAmount'] =
              debtAmount - (linkedDebt['paidAmount'] ?? 0);
          linkedDebt['status'] = linkedDebt['remainingAmount'] > 0
              ? 'ACTIVE'
              : 'PAID';
          await db.updateDebt(linkedDebt);
          debtChanged = true;

          // Queue sync debt to cloud via SyncOrchestrator
          final debtId = linkedDebt['id'] as int?;
          if (debtId != null) {
            await SyncOrchestrator().enqueue(
              entityType: SyncEntityType.debt,
              entityId: debtId,
              firestoreId: linkedDebt['firestoreId'] as String?,
              operation: SyncOperation.update,
              data: linkedDebt,
            );
          }
        }
        // Removed create new debt logic to avoid duplicates
      }

      NotificationService.showSnackBar(
        actuallySynced
            ? loc.savedOrderChanges
            : '⚠️ Đã lưu trên máy — mạng chập chờn nên CHƯA đồng bộ lên cloud, app sẽ tự thử lại',
        color: actuallySynced ? AppColors.success : Colors.orange,
      );
      _emitRepairChanged(
        financialImpact: financialImpact || debtChanged,
        includeDebts: debtChanged,
      );
    } catch (e) {
      NotificationService.showSnackBar(
        loc.errorSaving(e.toString()),
        color: AppColors.error,
      );
    }
    if (mounted) setState(() => _isUpdating = false);
  }

  /// Lối tắt vào Kho Phụ Tùng (PartsInventoryView)
  Future<void> _navigateToPartsInventory() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final role = currentUser != null
        ? await UserService.getUserRole(currentUser.uid)
        : 'user';
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryView(
          role: role,
          initialFilterType: 'LINH_KIEN',
          triggerPartsAdd: true,
        ),
      ),
    );
  }

  /// Chuẩn hoá tên để so khớp (bỏ dấu tiếng Việt + gộp khoảng trắng).
  static String _normNameForMatch(String s) {
    var t = s.trim().toLowerCase();
    const from = 'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ';
    const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    final b = StringBuffer();
    for (final ch in t.split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    t = b.toString();
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Mở màn Kho lọc sẵn tab Linh kiện (không tự bật hộp thoại thêm phụ tùng).
  Future<void> _openPartsWarehouse() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final role = currentUser != null
        ? await UserService.getUserRole(currentUser.uid)
        : 'user';
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryView(role: role, initialFilterType: 'LINH_KIEN'),
      ),
    );
  }

  /// Chạm 1 dòng phụ tùng → mở đúng phụ tùng đó trong Kho (hoặc Kho Linh kiện
  /// nếu không tra được sản phẩm cụ thể).
  Future<void> _openPartInInventory(PartUsedDetail p) async {
    Product? prod;
    try {
      if (p.productId != null) {
        prod = await db.getProductById(p.productId!);
      }
      if (prod == null && p.name.trim().isNotEmpty) {
        prod = await db.getProductByNameFlexible(p.name.trim());
      }
    } catch (e) {
      debugPrint('_openPartInInventory: $e');
    }
    if (!mounted) return;
    if (prod != null) {
      final found = prod;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => InventoryDetailView(product: found)),
      );
      return;
    }
    await _openPartsWarehouse();
  }

  /// Chạm 1 dòng dịch vụ → xem các đơn sửa khác cũng dùng dịch vụ cùng tên
  /// (để đối chiếu giá / lịch sử dịch vụ đó). Chỉ đọc, bấm 1 đơn để mở.
  Future<void> _openServiceHistory(RepairService s) async {
    final name = s.serviceName.trim();
    if (name.isEmpty) return;
    final target = _normNameForMatch(name);
    List<Repair> all = const [];
    try {
      all = await db.getRepairsForPricing(
        statuses: const [1, 2, 3, 4],
        limit: 5000,
      );
    } catch (e) {
      debugPrint('_openServiceHistory: $e');
    }
    final matched =
        all
            .where(
              (rp) => rp.services.any(
                (x) => _normNameForMatch(x.serviceName) == target,
              ),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!mounted) return;
    if (matched.isEmpty) {
      NotificationService.showSnackBar(
        'Chưa có đơn sửa nào khác dùng dịch vụ "$name".',
        color: Colors.blueGrey,
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SimilarRepairHistoryView(
          repairs: matched,
          showCost: _canViewAnyFinancial,
        ),
      ),
    );
  }

  /// Lối tắt vào Đối Tác Sửa Chữa
  Future<void> _navigateToRepairPartners() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RepairPartnerView()),
    );
    if (!mounted) return;
    await _loadPartners();
  }

  /// Dialog chọn phụ tùng từ kho và tự động trừ kho
  /// LƯU Ý: Mỗi lần chọn và xác nhận sẽ THÊM vào đơn và TRỪ KHO ngay lập tức
  /// [skipWarning] = true khi gọi từ flow đổi PT (đã xác nhận ở bước trước)
  Future<void> _selectPartsFromInventory({bool skipWarning = false}) async {
    if (!_canEditRepairNotes && !_canEditRepairOrder) {
      _ensureCanEditRepairOrder();
      return;
    }
    // Hiển thị cảnh báo nếu đã có phụ tùng
    if (!skipWarning && r.partsUsed.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Flexible(child: Text(loc.luuYTitle)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.orderAlreadyHasParts,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(r.partsUsed, style: const TextStyle(color: Colors.blue)),
              const SizedBox(height: 16),
              Text(
                loc.partsWillBeAddedAndDeducted,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.cancelButton),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: Text(
                loc.continueAddMore,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    // Lấy linh kiện từ CẢ 2 nguồn: repair_parts (kho cũ) + products type='LINH KIỆN' (kho mới)
    final parts = await db.getAllPartsUnified();
    if (parts.isEmpty) {
      // Thử load products để xem có nhưng chưa đánh đúng loại
      final allProducts = await db.getAllProducts();
      final linhKienProducts = allProducts
          .where((p) => p.type == 'LINH_KIEN')
          .toList();
      // phuKienProducts reserved for future use

      String msg = loc.partsInventoryEmpty;
      if (allProducts.isEmpty) {
        msg += loc.noProductsInInventory;
      } else {
        msg += loc.totalProductsLinhKien(
          allProducts.length,
          linhKienProducts.length,
        );
        if (linhKienProducts.isEmpty) {
          msg += loc.goToInventoryAddParts;
        }
      }

      NotificationService.showSnackBar(msg, color: Colors.orange);
      return;
    }

    // Hiển thị dialog chọn linh kiện
    final result = await showDialog<Map<String, int>?>(
      context: context,
      builder: (ctx) => _PartsSelectionDialog(
        parts: parts,
        onOpenPartsInventory: _navigateToPartsInventory,
      ),
    );

    if (result != null && result.isNotEmpty) {
      int totalCost = 0;
      List<String> usedParts = [];
      List<Map<String, dynamic>> selectedPartsInfo = [];

      for (var entry in result.entries) {
        final uniqueKey = entry.key;
        final qty = entry.value;

        // Parse uniqueKey = "source_id" (source có thể chứa underscore như "repair_parts")
        // Lấy phần cuối cùng sau dấu _ làm id
        final lastUnderscoreIndex = uniqueKey.lastIndexOf('_');
        final source = uniqueKey.substring(0, lastUnderscoreIndex);
        final partId = int.parse(uniqueKey.substring(lastUnderscoreIndex + 1));

        final part = parts.firstWhere(
          (p) => p['id'] == partId && p['source'] == source,
        );
        final partName = part['partName'] ?? '';
        final partCost = part['cost'] as int? ?? 0;
        final supplierName = part['supplier'] ?? part['supplierName'] ?? '';

        totalCost += partCost * qty;
        usedParts.add("$partName x$qty");
        selectedPartsInfo.add({
          'id': partId,
          'source': source,
          'name': partName,
          'cost': partCost,
          'qty': qty,
          'supplier': supplierName,
        });
      }

      // Chi tiết linh kiện cho Pricing Engine (Bảng giá thông minh) — song
      // song với usedParts (text), chỉ dùng cho thống kê, không hiển thị UI.
      final newDetailedParts = selectedPartsInfo
          .map(
            (p) => PartUsedDetail(
              name: (p['name'] ?? '').toString(),
              productId: p['source'] == 'products' ? p['id'] as int? : null,
              cost: p['cost'] as int? ?? 0,
              qty: p['qty'] as int? ?? 1,
              supplier: (p['supplier'] ?? '').toString().trim().isEmpty
                  ? null
                  : (p['supplier']).toString().trim(),
            ),
          )
          .toList();

      // === KIỂM TRA NGUỒN LINH KIỆN ===
      // Linh kiện từ 'products' hoặc 'repair_parts' đều đã được thanh toán khi nhập kho
      // → KHÔNG cần hỏi thanh toán lại (chi phí đã ghi nhận khi nhập kho: công nợ/tiền mặt/CK)
      final allFromStock = selectedPartsInfo.every(
        (p) => p['source'] == 'products' || p['source'] == 'repair_parts',
      );

      // Tất cả linh kiện đều từ kho → không cần dialog thanh toán
      if (allFromStock) {
        // Cập nhật repair object trong bộ nhớ trước
        final currentParts = r.partsUsed.isEmpty
            ? <String>[]
            : r.partsUsed.split(', ');
        final newPartsList = [...currentParts, ...usedParts];
        r.partsUsed = newPartsList.join(', ');
        r.cost = r.cost + totalCost;
        final prevPartsUsedDetailed = List<PartUsedDetail>.from(
          r.partsUsedDetailed,
        );
        r.partsUsedDetailed = [...r.partsUsedDetailed, ...newDetailedParts];
        r.isSynced = false;
        r.lastCaredAt = DateTime.now().millisecondsSinceEpoch;

        // === ATOMIC: trừ kho + cập nhật đơn sửa trong một SQLite transaction ===
        final atomicResult = await db.deductPartsAndUpdateRepairAtomic(
          parts: selectedPartsInfo,
          repair: r,
        );

        if (!atomicResult.success) {
          // Rollback repair object về trạng thái cũ
          r.partsUsed = currentParts.join(', ');
          r.cost = r.cost - totalCost;
          r.partsUsedDetailed = prevPartsUsedDetailed;
          r.isSynced = true;
          NotificationService.showSnackBar(
            '❌ ${atomicResult.message ?? "Không thể trừ kho"}',
            color: Colors.red,
          );
          return;
        }

        // Sync Firestore cho từng part (best-effort, sau khi transaction SQLite đã commit)
        for (final p in atomicResult.partsToSync) {
          final fid = p['firestoreId'] as String?;
          if (fid == null || fid.isEmpty) continue;
          final collection = p['collection'] as String;
          final newQty = p['newQty'] as int;
          try {
            await FirebaseFirestore.instance
                .collection(collection)
                .doc(fid)
                .update({
                  'quantity': newQty,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
          } catch (e) {
            debugPrint('⚠️ Sync $collection/$fid failed: $e');
          }
        }

        if (r.firestoreId != null && r.id != null) {
          await SyncOrchestrator().enqueue(
            entityType: SyncEntityType.repair,
            entityId: r.id!,
            firestoreId: r.firestoreId,
            operation: SyncOperation.update,
            data: r.toMap(),
          );
          try {
            await SyncOrchestrator().syncAll();
            if (mounted) setState(() => r.isSynced = true);
          } catch (_) {}
          // ignore: unawaited_futures
          SyncService.syncRepairData();
        }

        NotificationService.showSnackBar(
          loc.addedPartsFromInventoryMsg(usedParts.join(', ')),
          color: Colors.green,
        );

        setState(() {});
        _emitRepairChanged(financialImpact: true);
        return;
      }

      // === HỎI PHƯƠNG THỨC THANH TOÁN CHO PHỤ TÙNG (chỉ với repair_parts) ===
      final paymentResult = await showDialog<Map<String, dynamic>?>(
        context: context,
        builder: (ctx) => _PartsPaymentDialog(
          totalCost: totalCost,
          partsDescription: usedParts.join(', '),
        ),
      );

      if (paymentResult == null) {
        // User hủy, không làm gì
        return;
      }

      final paymentMethod = paymentResult['method'] as String;
      final supplierName =
          paymentResult['supplier'] as String? ?? 'Nhà cung cấp phụ tùng';

      // Cập nhật repair trong bộ nhớ trước khi thực hiện atomic
      final prevPartsUsed = r.partsUsed;
      final prevCost = r.cost;
      final prevPartsUsedDetailed = List<PartUsedDetail>.from(
        r.partsUsedDetailed,
      );
      if (r.partsUsed.isNotEmpty) {
        r.partsUsed = '${r.partsUsed}, ${usedParts.join(', ')}';
      } else {
        r.partsUsed = usedParts.join(', ');
      }
      r.cost += totalCost;
      r.partsUsedDetailed = [...r.partsUsedDetailed, ...newDetailedParts];
      r.isSynced = false;
      r.lastCaredAt = DateTime.now().millisecondsSinceEpoch;

      // === ATOMIC: trừ kho + cập nhật đơn sửa trong một SQLite transaction ===
      final atomicResult = await db.deductPartsAndUpdateRepairAtomic(
        parts: selectedPartsInfo,
        repair: r,
      );

      if (!atomicResult.success) {
        // Rollback repair object về trạng thái cũ
        r.partsUsed = prevPartsUsed;
        r.cost = prevCost;
        r.partsUsedDetailed = prevPartsUsedDetailed;
        r.isSynced = true;
        NotificationService.showSnackBar(
          '❌ ${atomicResult.message ?? "Không thể trừ kho"}',
          color: Colors.red,
        );
        return;
      }

      // Sync Firestore cho từng part (best-effort)
      for (final p in atomicResult.partsToSync) {
        final fid = p['firestoreId'] as String?;
        if (fid == null || fid.isEmpty) continue;
        final collection = p['collection'] as String;
        final newQty = p['newQty'] as int;
        try {
          await FirebaseFirestore.instance
              .collection(collection)
              .doc(fid)
              .update({
                'quantity': newQty,
                'updatedAt': FieldValue.serverTimestamp(),
              });
        } catch (e) {
          debugPrint('⚠️ Sync $collection/$fid failed: $e');
        }
      }

      // === XỬ LÝ THANH TOÁN ===
      final now = DateTime.now().millisecondsSinceEpoch;

      if (paymentMethod == 'CÔNG NỢ') {
        // Tạo debt record - Shop nợ nhà cung cấp
        try {
          final debtFId = 'debt_parts_${now}_${r.id}';
          final partNamesDetailed = selectedPartsInfo
              .map(
                (p) =>
                    '${p['name']} x${p['qty']} (${MoneyUtils.formatCurrency(p['cost'] as int? ?? 0)}đ/cái)',
              )
              .join(', ');
          final debtId = await PaymentIntentService.createDebtRecord(
            debtType: 'SHOP_OWES',
            amount: totalCost,
            personName: supplierName,
            note:
                'Nợ phụ tùng: $partNamesDetailed = ${MoneyUtils.formatCurrency(totalCost)}đ - Đơn sửa ${r.model} (${r.customerName})',
            linkedId: r.firestoreId ?? '',
            debtFirestoreId: debtFId,
          );

          // Công nợ đã ghi nhận ở bảng debts - không cần PaymentIntent
          debugPrint('✅ Parts debt recorded: $debtFId (id=$debtId)');
          EventBus().emit(EventBus.financialChanged);
        } catch (e) {
          debugPrint('❌ Error creating parts debt: $e');
        }
      } else {
        // TIỀN MẶT hoặc CHUYỂN KHOẢN - ghi nhận vào tài chính và chi phí
        try {
          // Log to financial_activities table (for financial log view)
          await FinancialActivityService.logCustomActivity(
            activityType: 'PARTS_COST',
            amount: totalCost,
            direction: 'OUT',
            paymentMethod: paymentMethod,
            title: 'Chi phí linh kiện: ${usedParts.join(', ')}',
            description:
                'Đơn #${r.firestoreId ?? r.id} — ${r.model} — KH: ${r.customerName}',
            customerName: r.customerName,
            phone: r.phone,
            productInfo: r.model,
            referenceType: 'REPAIR',
            referenceId: r.firestoreId ?? r.id?.toString() ?? '',
          );
          // Also record as expense (for cash fund / expense reports)
          final payResult = await PaymentIntentService.executePaymentDirect(
            type: PaymentIntentType.otherExpense,
            amount: totalCost,
            paymentMethod: PaymentMethod.fromCode(paymentMethod),
            description:
                'Chi phí linh kiện: $supplierName - ${usedParts.join(', ')}',
            executedBy: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
            referenceId: r.firestoreId,
            referenceType: 'parts_payment',
            personName: supplierName,
            idempotencyKey:
                'parts_${r.firestoreId}_${totalCost}_$paymentMethod',
            metadata: {
              'repairId': r.id,
              'repairFirestoreId': r.firestoreId,
              'parts': usedParts.join(', '),
              'paymentMethod': paymentMethod,
              'category': 'LINH KIỆN SỬA CHỮA',
              'scope': 'SHOP',
            },
          );
          debugPrint(
            '💳 Parts cost logged: ${totalCost}đ — expense ${payResult.success ? "OK" : "FAILED"}',
          );
        } catch (e) {
          debugPrint('❌ Error recording parts cost: $e');
        }
      }

      // Đồng bộ đơn sửa lên cloud
      if (r.firestoreId != null && r.id != null) {
        await SyncOrchestrator().enqueue(
          entityType: SyncEntityType.repair,
          entityId: r.id!,
          firestoreId: r.firestoreId,
          operation: SyncOperation.update,
          data: r.toMap(),
        );
        try {
          await SyncOrchestrator().syncAll();
          if (mounted) setState(() => r.isSynced = true);
        } catch (_) {}
        // ignore: unawaited_futures
        SyncService.syncRepairData();
      }

      setState(() {});

      NotificationService.showSnackBar(
        loc.addedPartsWithPayment(paymentMethod, usedParts.join(', ')),
        color: Colors.green,
      );
      _emitRepairChanged(financialImpact: true);
    }
  }

  /// Xóa phụ tùng khỏi đơn sửa chữa và trả lại kho
  Future<void> _removePartFromRepair() async {
    if (!_ensureCanEditRepairOrder()) return;
    if (r.partsUsed.isEmpty) {
      NotificationService.showSnackBar(
        'Đơn sửa chữa chưa có phụ tùng nào.',
        color: Colors.orange,
      );
      return;
    }

    // Parse partsUsed string: "PIN IPHONE 11 x1, MÀN HÌNH IP12 x2"
    final parts = r.partsUsed
        .split(', ')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    if (parts.isEmpty) return;

    // Show bottom sheet to select which part to remove
    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // Đọc từ `context` ngoài (không phải `ctx`) để tránh crash
      // _dependents.isEmpty khi pop.
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: PopupTheme.bgDark,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(PopupTheme.radiusSheet),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PopupDragHandle(),
              const Row(
                children: [
                  Icon(Icons.delete_sweep, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'XÓA PHỤ TÙNG',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Chọn phụ tùng cần xóa và trả lại kho:',
                style: TextStyle(fontSize: 14, color: PopupTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              ...parts.asMap().entries.map((entry) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.build,
                      size: 18,
                      color: Colors.blue,
                    ),
                    title: Text(
                      entry.value,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => Navigator.pop(ctx, entry.key),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ĐÓNG'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedIndex == null) return;

    final removedPart = parts[selectedIndex];

    // Parse part name and quantity from "PART_NAME xQTY"
    String partName = removedPart;
    int partQty = 1;
    final xMatch = RegExp(r'^(.+)\s+x(\d+)$').firstMatch(removedPart);
    if (xMatch != null) {
      partName = xMatch.group(1)!.trim();
      partQty = int.tryParse(xMatch.group(2)!) ?? 1;
    }

    // Confirm
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          r.status == 4
              ? 'Xóa "$removedPart" khỏi đơn sửa và trả lại $partQty vào kho?\n\n'
                    '⚠️ Đơn này ĐÃ GIAO cho khách. Giá vốn/lợi nhuận của đơn sẽ được điều chỉnh lại.'
              : 'Xóa "$removedPart" khỏi đơn sửa và trả lại $partQty vào kho?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'XÁC NHẬN XÓA',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Chặn realtime listener ghi đè local trong lúc đang xóa/đồng bộ — thiếu
    // guard này khiến 1 snapshot cloud cũ (chưa kịp nhận thay đổi) đè lại
    // partsUsed vừa xóa, làm màn hình như "không xóa được".
    if (mounted) setState(() => _isUpdating = true);
    try {
      // 1. Estimate cost + current inventory quantity of the removed part
      //    (looked up BEFORE restoring, so we can log old→new for audit).
      int removedCost = 0;
      int? oldQty;
      final allParts = await db.getAllPartsUnified();
      for (final p in allParts) {
        final pName = (p['partName'] ?? '').toString().toUpperCase();
        if (pName == partName.toUpperCase()) {
          removedCost = (p['cost'] as int? ?? 0) * partQty;
          oldQty = p['quantity'] as int? ?? 0;
          break;
        }
      }

      // 2. Restore part quantity to inventory
      final restored = await db.restorePartQuantityByNameUnified(
        partName,
        partQty,
      );
      if (restored) {
        debugPrint('✅ Restored $partName x$partQty to inventory');
      } else {
        debugPrint(
          '⚠️ Could not find part "$partName" in inventory to restore',
        );
      }
      final newQty = (restored && oldQty != null) ? oldQty + partQty : oldQty;

      // 3. Update partsUsed string
      parts.removeAt(selectedIndex);
      r.partsUsed = parts.join(', ');

      // 3b. Best-effort: gỡ 1 entry khớp tên khỏi partsUsedDetailed (nếu có).
      //     Đơn cũ/không thêm qua kho sẽ không có entry nào — bỏ qua, không lỗi.
      if (r.partsUsedDetailed.isNotEmpty) {
        final updatedDetailed = List<PartUsedDetail>.from(r.partsUsedDetailed);
        final matchIndex = updatedDetailed.indexWhere(
          (p) => p.name.toUpperCase() == partName.toUpperCase(),
        );
        if (matchIndex != -1) {
          updatedDetailed.removeAt(matchIndex);
          r.partsUsedDetailed = updatedDetailed;
        }
      }

      // 4. Reduce cost
      final oldCost = r.cost;
      final wasDelivered = r.status == 4;
      r.cost = (r.cost - removedCost).clamp(0, r.cost);
      final newCost = r.cost;
      r.isSynced = false;
      r.lastCaredAt = DateTime.now().millisecondsSinceEpoch;
      await db.updateRepair(r);

      // 5. Sync
      if (r.firestoreId != null && r.id != null) {
        await SyncOrchestrator().enqueue(
          entityType: SyncEntityType.repair,
          entityId: r.id!,
          firestoreId: r.firestoreId,
          operation: SyncOperation.update,
          data: r.toMap(),
        );
        try {
          await SyncOrchestrator().syncAll();
          if (mounted) setState(() => r.isSynced = true);
        } catch (_) {}
      }

      // 6. Log audit — ghi rõ giá trị cũ → mới của kho và giá vốn đơn
      await AuditService.logAction(
        action: 'PART_REMOVED',
        entityType: 'repair',
        entityId: r.id?.toString() ?? '',
        summary:
            'Xóa phụ tùng: $removedPart (kho: ${oldQty ?? "?"} → ${newQty ?? "?"}, '
            'giá vốn đơn: $oldCost → $newCost)'
            '${wasDelivered ? " [ĐƠN ĐÃ GIAO]" : ""}',
        payload: {
          'partName': partName,
          'quantity': partQty,
          'removedCost': removedCost,
          'restored': restored,
          'oldInventoryQty': oldQty,
          'newInventoryQty': newQty,
          'oldCost': oldCost,
          'newCost': newCost,
          'wasDelivered': wasDelivered,
        },
      );

      NotificationService.showSnackBar(
        'Đã xóa $removedPart${restored ? " và trả lại kho" : ""}',
        color: Colors.green,
      );
      _emitRepairChanged(financialImpact: true);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  /// Đổi phụ tùng: xóa linh kiện cũ (trả kho) → chọn linh kiện mới thay thế
  Future<void> _swapPartInRepair() async {
    if (!_ensureCanEditRepairOrder()) return;
    if (r.partsUsed.isEmpty) {
      NotificationService.showSnackBar(
        'Đơn sửa chữa chưa có phụ tùng nào để đổi.',
        color: Colors.orange,
      );
      return;
    }

    // Parse partsUsed
    final parts = r.partsUsed
        .split(', ')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    if (parts.isEmpty) return;

    // Bước 1: Chọn phụ tùng cần đổi
    final selectedIndex = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.swap_horiz, color: Colors.deepPurple),
            SizedBox(width: 8),
            Expanded(
              child: Text('ĐỔI PHỤ TÙNG', style: TextStyle(fontSize: 17)),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn phụ tùng cần đổi:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              ...parts.asMap().entries.map((entry) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.build,
                      size: 18,
                      color: Colors.blue,
                    ),
                    title: Text(
                      entry.value,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.swap_horiz,
                        color: Colors.deepPurple,
                      ),
                      onPressed: () => Navigator.pop(ctx, entry.key),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('ĐÓNG'),
          ),
        ],
      ),
    );

    if (selectedIndex == null) return;

    final removedPart = parts[selectedIndex];

    // Parse tên và số lượng: "PART_NAME xQTY"
    String partName = removedPart;
    int partQty = 1;
    final xMatch = RegExp(r'^(.+)\s+x(\d+)$').firstMatch(removedPart);
    if (xMatch != null) {
      partName = xMatch.group(1)!.trim();
      partQty = int.tryParse(xMatch.group(2)!) ?? 1;
    }

    // Chặn realtime listener ghi đè local trong lúc đang đổi/đồng bộ — thiếu
    // guard này khiến 1 snapshot cloud cũ đè lại partsUsed vừa đổi.
    if (mounted) setState(() => _isUpdating = true);
    try {
      // Bước 2: Xóa phụ tùng cũ + trả kho
      final restored = await db.restorePartQuantityByNameUnified(
        partName,
        partQty,
      );
      debugPrint(
        restored
            ? '✅ Đổi PT - Đã trả kho: $partName x$partQty'
            : '⚠️ Đổi PT - Không tìm thấy "$partName" trong kho để trả',
      );

      // Tính giá vốn phụ tùng bị xóa
      int removedCost = 0;
      final allParts = await db.getAllPartsUnified();
      for (final p in allParts) {
        final pName = (p['partName'] ?? '').toString().toUpperCase();
        if (pName == partName.toUpperCase()) {
          removedCost = (p['cost'] as int? ?? 0) * partQty;
          break;
        }
      }

      // Cập nhật repair: xóa phụ tùng cũ khỏi danh sách
      parts.removeAt(selectedIndex);
      r.partsUsed = parts.join(', ');
      r.cost = (r.cost - removedCost).clamp(0, r.cost);
      // Best-effort: gỡ entry khớp tên khỏi partsUsedDetailed (nếu có).
      if (r.partsUsedDetailed.isNotEmpty) {
        final updatedDetailed = List<PartUsedDetail>.from(r.partsUsedDetailed);
        final matchIndex = updatedDetailed.indexWhere(
          (p) => p.name.toUpperCase() == partName.toUpperCase(),
        );
        if (matchIndex != -1) {
          updatedDetailed.removeAt(matchIndex);
          r.partsUsedDetailed = updatedDetailed;
        }
      }
      r.isSynced = false;
      await db.updateRepair(r);

      if (r.firestoreId != null && r.id != null) {
        await SyncOrchestrator().enqueue(
          entityType: SyncEntityType.repair,
          entityId: r.id!,
          firestoreId: r.firestoreId,
          operation: SyncOperation.update,
          data: r.toMap(),
        );
        try {
          await SyncOrchestrator().syncAll();
          if (mounted) setState(() => r.isSynced = true);
        } catch (_) {}
      }

      // Log xóa
      await AuditService.logAction(
        action: 'PART_SWAP_REMOVE',
        entityType: 'repair',
        entityId: r.id?.toString() ?? '',
        summary:
            'Đổi PT - xóa: $removedPart (trả kho: ${restored ? "OK" : "Không tìm thấy"})',
        payload: {
          'partName': partName,
          'quantity': partQty,
          'removedCost': removedCost,
          'restored': restored,
        },
      );

      _emitRepairChanged(financialImpact: true);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }

    // Bước 3: Tự động mở dialog chọn phụ tùng mới (bỏ qua cảnh báo)
    if (!mounted) return;
    NotificationService.showSnackBar(
      'Đã xóa "$removedPart" — chọn phụ tùng thay thế.',
      color: Colors.blue,
    );
    await _selectPartsFromInventory(skipWarning: true);
  }

  Future<void> _editFinancials() async {
    if (!_ensureCanEditRepairCharge()) {
      return;
    }

    final canEditCost = _canEditRepairFinancial && _canViewCostPrice;

    if (!_canViewAnyFinancial && !_canEditRepairCharge) {
      NotificationService.showSnackBar(
        'Bạn không có quyền xem/chỉnh sửa tài chính',
        color: Colors.orange,
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final priceC = TextEditingController(
      text: CurrencyTextField.formatDisplay(r.price),
    );
    final costC = TextEditingController(
      text: CurrencyTextField.formatDisplay(r.cost),
    );
    // "Không tốn giá vốn": đơn không dùng linh kiện — 0đ là ĐÚNG, khác với
    // "chưa nhập giá vốn". Nhận biết ban đầu: cost = 0 và đã từng ghi nhận.
    bool noCost = r.cost == 0 &&
        r.costRecordedAt != null &&
        (r.costRecordedAt ?? 0) > 0;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogLoc = AppLocalizations.of(ctx)!;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(dialogLoc.repairOrderFinance),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CurrencyTextField(
                    controller: priceC,
                    label: dialogLoc.chargeCustomerVnd,
                    validator: (v) => MoneyUtils.validateAmount(
                      v ?? '',
                      min: 0,
                      fieldName: dialogLoc.chargeCustomerLabel,
                    ),
                  ),
                  if (canEditCost) ...[
                    const SizedBox(height: 12),
                    if (!noCost)
                      CurrencyTextField(
                        controller: costC,
                        label: dialogLoc.partsCostVnd,
                        validator: (v) => MoneyUtils.validateAmount(
                          v ?? '',
                          min: 0,
                          fieldName: dialogLoc.partsCost,
                        ),
                      ),
                    CheckboxListTile(
                      value: noCost,
                      onChanged: (v) => setDialogState(() {
                        noCost = v ?? false;
                        if (noCost) costC.text = '0';
                      }),
                      title: const Text('Đơn này KHÔNG tốn giá vốn (0đ)'),
                      subtitle: const Text(
                        'Không dùng linh kiện — đánh dấu để không bị nhắc "chưa có giá vốn"',
                        style: TextStyle(fontSize: 11),
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(dialogLoc.cancelButton),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  Navigator.pop(ctx, true);
                },
                child: Text(dialogLoc.saveButton),
              ),
            ],
          ),
        );
      },
    );
    if (result == true) {
      final parsedPrice = MoneyUtils.parseCurrency(priceC.text);
      final parsedCost =
          canEditCost ? (noCost ? 0 : MoneyUtils.parseCurrency(costC.text)) : r.cost;
      final oldPrice = r.price;
      final oldCost = r.cost;
      final wasFundRecorded = r.costRecordedInFund;
      final oldRecordedAmount = r.costRecordedAmount ?? 0;
      final oldRecordedBase = oldRecordedAmount > 0
          ? oldRecordedAmount
          : oldCost;

      // Update pricing
      setState(() {
        r.price = parsedPrice;
        r.cost = parsedCost;
      });

      if (canEditCost && noCost) {
        // Đánh dấu ĐÃ GHI NHẬN giá vốn = 0 (đơn không tốn linh kiện) — không
        // popup ghi quỹ, và hoàn nhập nếu trước đó đã lỡ ghi quỹ.
        if (wasFundRecorded && oldRecordedBase > 0) {
          await _applyCostFundDelta(
            deltaAmount: -oldRecordedBase,
            newRecordedAmount: 0,
          );
        }
        setState(() {
          r.costRecordedAt = DateTime.now().millisecondsSinceEpoch;
          r.costRecordedInFund = false;
          r.costRecordedAmount = 0;
        });
      } else if (canEditCost) {
        if (!wasFundRecorded && parsedCost > 0) {
          // Chỉ popup ghi quỹ lần đầu để chọn phương thức chi.
          await _showCostFundRecordingPopup(parsedCost);
        } else if (wasFundRecorded) {
          // Đã ghi quỹ trước đó: chỉ ghi thêm phần chênh lệch để tránh nhân đôi chi phí.
          final delta = parsedCost - oldRecordedBase;
          if (delta != 0) {
            await _applyCostFundDelta(
              deltaAmount: delta,
              newRecordedAmount: parsedCost,
            );
          }
        }
      }

      await _saveData();

      // Tạo bút toán điều chỉnh nếu giá thu hoặc giá vốn thay đổi
      final priceChanged = parsedPrice != oldPrice;
      final costChanged = canEditCost && parsedCost != oldCost;
      if (priceChanged || costChanged) {
        final repairRef = r.firestoreId ?? r.id?.toString() ?? 'unknown';
        if (priceChanged) {
          final delta = parsedPrice - oldPrice;
          await FinancialActivityService.logCustomActivity(
            activityType: 'REPAIR_PRICE_ADJUST',
            amount: delta.abs(),
            direction: delta >= 0 ? 'IN' : 'OUT',
            paymentMethod: r.paymentMethod,
            title:
                'Điều chỉnh giá sửa: ${r.customerName} (${MoneyUtils.formatVND(oldPrice)} → ${MoneyUtils.formatVND(parsedPrice)})',
            description:
                'Đơn #$repairRef — Máy: ${r.model} — Chênh lệch: ${MoneyUtils.formatVND(delta.abs())}',
            customerName: r.customerName,
            phone: r.phone,
            productInfo: r.model,
            referenceType: 'REPAIR',
            referenceId: repairRef,
          );
        }
        if (costChanged) {
          final costDelta = parsedCost - oldCost;
          await FinancialActivityService.logCustomActivity(
            activityType: 'REPAIR_COST_ADJUST',
            amount: costDelta.abs(),
            direction: costDelta >= 0 ? 'OUT' : 'IN',
            paymentMethod: r.costPaymentMethod ?? r.paymentMethod,
            title:
                'Điều chỉnh giá vốn sửa: ${r.customerName} (${MoneyUtils.formatVND(oldCost)} → ${MoneyUtils.formatVND(parsedCost)})',
            description:
                'Đơn #$repairRef — Máy: ${r.model} — Lãi gộp mới: ${MoneyUtils.formatVND(parsedPrice - parsedCost)}',
            customerName: r.customerName,
            phone: r.phone,
            productInfo: r.model,
            referenceType: 'REPAIR',
            referenceId: repairRef,
          );
        }
      }
    }
  }

  Future<void> _applyCostFundDelta({
    required int deltaAmount,
    required int newRecordedAmount,
  }) async {
    final paymentMethod = (r.costPaymentMethod ?? '').trim();
    if (paymentMethod.isEmpty) {
      // Dữ liệu cũ thiếu payment method: fallback về popup chọn cách ghi quỹ.
      if (newRecordedAmount > 0) {
        await _showCostFundRecordingPopup(newRecordedAmount);
      }
      return;
    }

    final absAmount = deltaAmount.abs();
    final isOut = deltaAmount > 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (absAmount == 0) return;

    await FinancialActivityService.logCustomActivity(
      activityType: 'PARTS_COST_ADJUST',
      amount: absAmount,
      direction: isOut ? 'OUT' : 'IN',
      paymentMethod: paymentMethod,
      title: isOut
          ? 'Điều chỉnh tăng giá vốn: ${r.customerName} (${r.model})'
          : 'Điều chỉnh giảm giá vốn: ${r.customerName} (${r.model})',
      description:
          'Đơn #${r.firestoreId ?? r.id} — Chênh lệch: ${MoneyUtils.formatVND(absAmount)}',
      customerName: r.customerName,
      phone: r.phone,
      productInfo: r.model,
      referenceType: 'REPAIR',
      referenceId: r.firestoreId ?? r.id?.toString() ?? '',
    );

    setState(() {
      if (newRecordedAmount > 0) {
        r.costRecordedInFund = true;
        r.costRecordedAt = now;
        r.costRecordedAmount = newRecordedAmount;
      } else {
        r.costRecordedInFund = false;
        r.costPaymentMethod = null;
        r.costRecordedAt = null;
        r.costRecordedAmount = 0;
      }
    });

    NotificationService.showSnackBar(
      isOut
          ? 'Đã ghi bổ sung ${MoneyUtils.formatVND(absAmount)} vào sổ quỹ ($paymentMethod)'
          : 'Đã hoàn nhập ${MoneyUtils.formatVND(absAmount)} vào sổ quỹ ($paymentMethod)',
      color: Colors.green,
    );
  }

  /// Show popup asking whether to record parts cost in cash fund
  Future<void> _showCostFundRecordingPopup(int costAmount) async {
    // Auto-fill: find NCC from linked debt (1 row only)
    String? autoSupplierName;
    try {
      final fid = r.firestoreId ?? '';
      if (fid.isNotEmpty) {
        final rows = await (await db.database).query(
          'debts',
          columns: ['personName'],
          where:
              "linkedId = ? AND type = 'SHOP_OWES' AND (deleted IS NULL OR deleted = 0)",
          whereArgs: [fid],
          limit: 1,
        );
        if (rows.isNotEmpty)
          autoSupplierName = rows.first['personName'] as String?;
      }
    } catch (_) {}

    List<Map<String, dynamic>> suppliers = [];
    try {
      final page = await db.getSuppliersPage(limit: 50);
      suppliers = page.items;
    } catch (_) {
      try {
        suppliers = await db.getSuppliers();
      } catch (_) {}
    }

    if (!mounted) return;

    // Validate selName against loaded suppliers list
    String? selName = autoSupplierName;
    String? selPhone;
    if (selName != null) {
      final found = suppliers.where((s) => s['name'] == selName).firstOrNull;
      if (found == null) {
        selName = null;
      } else {
        selPhone = found['phone'] as String?;
      }
    }

    // Dismiss keyboard and wait for animation before showing dialog
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    Future<void> openPicker(StateSetter setS) async {
      if (!mounted) return;
      final picked = await showSupplierPickerSheet(context);
      if (picked != null) {
        setS(() {
          selName = (picked['name'] as String?) ?? '';
          if (selName!.isEmpty) selName = null;
          selPhone = picked['phone'] as String?;
        });
      }
    }

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final hasSupplier = selName != null && selName!.isNotEmpty;

          return AlertDialog(
            title: const Text('GHI VÀO SỔ QUỸ?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chi phí: ${MoneyUtils.formatVND(costAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ghi vào sổ quỹ để cập nhật biến động quỹ?',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => openPicker(setS),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: hasSupplier
                            ? Colors.blue.shade300
                            : Colors.grey.shade400,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      color: hasSupplier
                          ? Colors.blue.withValues(alpha: 0.05)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.store,
                          size: 16,
                          color: hasSupplier
                              ? Colors.blue.shade600
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          selName ?? 'Chọn nhà cung cấp...',
                          style: TextStyle(
                            fontSize: 13,
                            color: selName == null
                                ? Colors.grey
                                : Colors.blue.shade700,
                            fontWeight: hasSupplier
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasSupplier)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Chọn "Nợ NCC" để ghi công nợ cho $selName',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () async {
                  if (!hasSupplier) {
                    await openPicker(setS);
                    return;
                  }
                  Navigator.pop(ctx, {
                    'method': 'CÔNG NỢ',
                    'name': selName,
                    'phone': selPhone ?? '',
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: hasSupplier ? Colors.orange : Colors.grey,
                ),
                child: Text(
                  hasSupplier ? 'Nợ NCC' : 'Nợ NCC (chọn NCC↑)',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, {
                  'method': 'CHUYỂN KHOẢN',
                  'name': selName,
                  'phone': selPhone ?? '',
                }),
                child: const Text('Chuyển khoản'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, {
                  'method': 'TIỀN MẶT',
                  'name': selName,
                  'phone': selPhone ?? '',
                }),
                child: const Text('Tiền mặt'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) {
      setState(() {
        r.costRecordedInFund = false;
        r.costPaymentMethod = null;
        r.costRecordedAt = null;
        r.costRecordedAmount = 0;
      });
      return;
    }

    final method = result['method'] as String;
    final supplierName = result['name'] as String?;
    final supplierPhone = result['phone'] as String? ?? '';

    if (method == 'CÔNG NỢ') {
      setState(() {
        r.costRecordedInFund = false;
        r.costPaymentMethod = 'CÔNG NỢ';
        r.costRecordedAt = DateTime.now().millisecondsSinceEpoch;
        r.costRecordedAmount = costAmount;
      });
      // Tạo bản ghi công nợ NCC
      // FIX: trước đây tự tay insertDebt với status='UNPAID' (sai — chuẩn
      // chung cả app là 'ACTIVE', 'UNPAID' làm khoản nợ này biến mất khỏi
      // các thống kê lọc theo 'ACTIVE') và KHÔNG xếp hàng đồng bộ Firestore
      // (nợ chỉ tồn tại cục bộ, không lên cloud/thiết bị khác).
      try {
        await PaymentIntentService.createDebtRecord(
          debtType: 'SHOP_OWES',
          amount: costAmount,
          personName: supplierName ?? 'NCC không rõ',
          personPhone: supplierPhone,
          note:
              'Vốn linh kiện: ${r.customerName} (${r.model})'
              '${(r.partsUsed ?? '').isNotEmpty ? " — ${r.partsUsed}" : ""}',
          linkedId: r.firestoreId ?? r.id?.toString() ?? '',
          debtFirestoreId:
              'debt_repair_${r.firestoreId ?? r.id}_${DateTime.now().millisecondsSinceEpoch}',
        );
      } catch (e) {
        debugPrint('Tạo công nợ NCC thất bại: $e');
      }
      NotificationService.showSnackBar(
        'Đã ghi công nợ ${MoneyUtils.formatVND(costAmount)} cho ${supplierName ?? "NCC"}',
        color: Colors.orange,
      );
    } else {
      // TIỀN MẶT / CHUYỂN KHOẢN
      setState(() {
        r.costRecordedInFund = true;
        r.costPaymentMethod = method;
        r.costRecordedAt = DateTime.now().millisecondsSinceEpoch;
        r.costRecordedAmount = costAmount;
      });
      await FinancialActivityService.logCustomActivity(
        activityType: 'PARTS_COST',
        amount: costAmount,
        direction: 'OUT',
        paymentMethod: method,
        title: 'Giá vốn linh kiện: ${r.customerName} (${r.model})',
        description:
            'Đơn #${r.firestoreId ?? r.id} — LK: ${r.partsUsed}'
            '${supplierName != null ? " — NCC: $supplierName" : ""}',
        customerName: r.customerName,
        phone: r.phone,
        productInfo: r.model,
        referenceType: 'REPAIR',
        referenceId: r.firestoreId ?? r.id?.toString() ?? '',
      );
      NotificationService.showSnackBar(
        'Đã ghi ${MoneyUtils.formatVND(costAmount)} vào sổ quỹ ($method)'
        '${supplierName != null ? " — NCC: $supplierName" : ""}',
        color: Colors.green,
      );
    }
  }

  /// Cho phép KTV ghi chú cho đơn sửa (vd: kt thay ic hay sàng main ...)
  /// Đổi / gán lại kỹ thuật viên (repairedBy) — dùng được cả khi đơn đã giao,
  /// để sửa nhầm người hoặc bổ sung KTV. Ảnh hưởng hoa hồng lương của KTV.
  Future<void> _editTechnician() async {
    if (!_ensureCanEditRepairOrder()) return;
    final shopId = await UserService.getCurrentShopId();
    if (!mounted) return;
    if (shopId == null || shopId.isEmpty) {
      NotificationService.showSnackBar(
        'Không xác định được cửa hàng.',
        color: Colors.orange,
      );
      return;
    }
    List<Map<String, dynamic>> staff = const [];
    try {
      staff = await FirestoreService.getShopStaffList(shopId);
    } catch (_) {}
    if (!mounted) return;

    final currentUid = (r.repairedByUid ?? '').trim();
    String nameOf(Map<String, dynamic> s) =>
        (s['name'] ?? s['displayName'] ?? s['email'] ?? 'Nhân viên').toString();

    final picked = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chọn kỹ thuật viên'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KTV hiện tại: '
                '${(r.repairedBy ?? '').trim().isEmpty ? "— chưa gán —" : r.repairedBy}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Đổi KTV sẽ tính lại hoa hồng cho người mới.',
                style: TextStyle(fontSize: 11, color: Colors.orange),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.person_off_outlined),
                      title: const Text('— Bỏ gán KTV —'),
                      onTap: () => Navigator.pop(
                        ctx,
                        <String, String>{'uid': '', 'name': ''},
                      ),
                    ),
                    for (final s in staff)
                      ListTile(
                        dense: true,
                        selected: currentUid.isNotEmpty &&
                            (s['uid'] ?? '').toString() == currentUid,
                        leading: const Icon(Icons.engineering_rounded),
                        title: Text(nameOf(s)),
                        subtitle: (s['role'] ?? '').toString().isEmpty
                            ? null
                            : Text((s['role']).toString()),
                        onTap: () => Navigator.pop(ctx, <String, String>{
                          'uid': (s['uid'] ?? '').toString(),
                          'name': nameOf(s),
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;

    final oldName = (r.repairedBy ?? '').trim();
    setState(() {
      final n = (picked['name'] ?? '').trim();
      final u = (picked['uid'] ?? '').trim();
      r.repairedBy = n.isEmpty ? null : n;
      r.repairedByUid = u.isEmpty ? null : u;
    });
    await _saveData();
    if (!mounted) return;
    try {
      await AuditService.logAction(
        action: 'REPAIR_TECHNICIAN_CHANGED',
        entityType: 'repair',
        entityId: r.firestoreId ?? r.id?.toString() ?? 'unknown',
        summary: 'Đổi KTV đơn ${r.model}: '
            '"${oldName.isEmpty ? "—" : oldName}" → '
            '"${(r.repairedBy ?? '').isEmpty ? "—" : r.repairedBy}"',
      );
    } catch (_) {}
    NotificationService.showSnackBar(
      (r.repairedBy ?? '').isEmpty
          ? 'Đã bỏ gán KTV.'
          : 'Đã đổi KTV: ${r.repairedBy}',
      color: Colors.green,
    );
  }

  Future<void> _editTechnicianNotes() async {
    if (!_canEditRepairNotes && !_canEditRepairOrder) {
      _ensureCanEditRepairOrder();
      return;
    }
    final notesC = TextEditingController(text: r.notes ?? '');
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetLoc = AppLocalizations.of(ctx)!;
        // KeyboardAwarePadding tracks the keyboard via the platform FlutterView
        // (no InheritedWidget dependency) — keeps the TextField above the
        // keyboard without the _dependents.isEmpty crash that reading
        // MediaQuery.viewInsetsOf(ctx) here used to cause on Navigator.pop.
        return KeyboardAwarePadding(
          minBottom: 16,
          child: Container(
            decoration: const BoxDecoration(
              color: PopupTheme.bgDark,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(PopupTheme.radiusSheet),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PopupDragHandle(),
                Text(
                  sheetLoc.techNotesTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: PopupTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sheetLoc.repairProcessNotes,
                  style: const TextStyle(
                    fontSize: 13,
                    color: PopupTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesC,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: sheetLoc.techNotesHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        PopupTheme.radiusField,
                      ),
                    ),
                    filled: true,
                    fillColor: PopupTheme.surfaceDark,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          // See _editBasicInfo above: FocusManager (not
                          // FocusScope.of(ctx)) avoids registering a fresh
                          // widget-tree dependency right before this route
                          // pops — the actual root cause of an intermittent
                          // _dependents.isEmpty crash.
                          FocusManager.instance.primaryFocus?.unfocus();
                          await Future.delayed(Duration.zero);
                          if (ctx.mounted) {
                            Navigator.pop(ctx, false);
                          }
                        },
                        child: Text(sheetLoc.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          await Future.delayed(Duration.zero);
                          if (ctx.mounted) {
                            Navigator.pop(ctx, true);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(sheetLoc.save),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    final notesText = notesC.text.trim();
    notesC.dispose();
    if (result == true) {
      setState(() {
        r.notes = notesText.isEmpty ? null : notesText;
      });
      await _saveData();
      NotificationService.showSnackBar(
        loc.savedTechnicianNotes,
        color: Colors.green,
      );
    }
  }

  Future<void> _editBasicInfo() async {
    if (!_canEditRepairBasicInfo) {
      NotificationService.showSnackBar(
        'Bạn không có quyền sửa thông tin đơn sửa chữa.',
        color: Colors.orange,
      );
      return;
    }
    final formKey = GlobalKey<FormState>();
    final nameC = TextEditingController(text: r.customerName);
    final phoneC = TextEditingController(text: r.phone);
    final modelC = TextEditingController(text: r.model);
    final issueC = TextEditingController(text: r.issue);
    final accC = TextEditingController(text: r.accessories);
    final warrantyC = TextEditingController(text: r.warranty);
    final addressC = TextEditingController(text: r.address);
    final notesC = TextEditingController(text: r.notes ?? '');
    final loanerDeviceC = TextEditingController(text: r.loanerDevice ?? '');
    final searchC = TextEditingController();
    String? pickupScheduleLocal = r.pickupSchedule;
    List<Map<String, dynamic>> customerSearchResults = [];
    Timer? customerSearchTimer;
    final shopId = await UserService.getCurrentShopId();

    if (!mounted) return;
    final sheetLoc = AppLocalizations.of(context)!;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          void doCustomerSearch(String q) {
            customerSearchTimer?.cancel();
            if (q.trim().isEmpty) {
              setS(() => customerSearchResults = []);
              return;
            }
            customerSearchTimer = Timer(
              const Duration(milliseconds: 300),
              () async {
                final results = await db.searchCustomers(q.trim(), shopId);
                if (!ctx.mounted) return;
                try {
                  setS(() => customerSearchResults = results.take(6).toList());
                } catch (_) {}
              },
            );
          }

          // KeyboardAwarePadding reads the keyboard height from the platform
          // FlutterView (no InheritedWidget dependency), so it tracks the
          // keyboard live without the _dependents.isEmpty crash that reading
          // MediaQuery.viewInsetsOf(ctx) here used to cause on Navigator.pop.
          // minBottom keeps the Save/Cancel row out of the OEM gesture strip
          // when the keyboard is closed.
          return KeyboardAwarePadding(
            minBottom: 16,
            child: Container(
              decoration: const BoxDecoration(
                color: PopupTheme.bgDark,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(PopupTheme.radiusSheet),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PopupDragHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_note,
                          size: 20,
                          color: PopupTheme.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          sheetLoc.editOrderInfoTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: PopupTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Search existing customer
                            TextField(
                              controller: searchC,
                              decoration: InputDecoration(
                                hintText: 'Tìm khách hàng cũ (SĐT hoặc tên)...',
                                prefixIcon: const Icon(Icons.search, size: 18),
                                border: const OutlineInputBorder(),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.grey.shade100,
                              ),
                              onChanged: doCustomerSearch,
                            ),
                            if (customerSearchResults.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 160,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.blue.shade50,
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: customerSearchResults.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: Colors.blue.shade100,
                                  ),
                                  itemBuilder: (_, i) {
                                    final c = customerSearchResults[i];
                                    final cName = (c['name'] as String?) ?? '';
                                    final cPhone =
                                        (c['phone'] as String?) ?? '';
                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
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
                                      title: Text(
                                        cName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        cPhone,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 12,
                                      ),
                                      onTap: () {
                                        nameC.text = cName;
                                        phoneC.text = cPhone;
                                        searchC.clear();
                                        setS(() => customerSearchResults = []);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                            const Divider(height: 20),
                            TextFormField(
                              controller: nameC,
                              decoration: InputDecoration(
                                labelText: sheetLoc.customerNameLabel,
                              ),
                              textCapitalization: TextCapitalization.characters,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: phoneC,
                              decoration: InputDecoration(
                                labelText: r.isWalkIn
                                    ? '${sheetLoc.phoneLabel} (không bắt buộc)'
                                    : sheetLoc.phoneLabel,
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (v) {
                                final text = v?.trim() ?? '';
                                if (r.isWalkIn && text.isEmpty) return null;
                                if (text.isEmpty)
                                  return sheetLoc.phoneRequired2;
                                return UserService.validatePhone(
                                  text,
                                  sheetLoc,
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: modelC,
                              decoration: InputDecoration(
                                labelText: sheetLoc.deviceModelLabel,
                              ),
                              textCapitalization: TextCapitalization.characters,
                              validator: (v) => (v?.trim().isEmpty ?? true)
                                  ? sheetLoc.enterModelRequired
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: issueC,
                              decoration: InputDecoration(
                                labelText: sheetLoc.deviceIssueLabel,
                              ),
                              textCapitalization: TextCapitalization.characters,
                              validator: (v) => (v?.trim().isEmpty ?? true)
                                  ? sheetLoc.enterIssueRequired
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: accC,
                              decoration: InputDecoration(
                                labelText: sheetLoc.accessoriesIncludedLabel,
                              ),
                              textCapitalization: TextCapitalization.characters,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: warrantyC,
                              decoration: InputDecoration(
                                labelText: sheetLoc.warrantyLabel2,
                              ),
                              textCapitalization: TextCapitalization.characters,
                            ),
                            const SizedBox(height: 10),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Hẹn giao máy',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: PopupTheme.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: Repair.pickupScheduleLabels.entries.map(
                                (entry) {
                                  final selected =
                                      pickupScheduleLocal == entry.key;
                                  return ChoiceChip(
                                    label: Text(entry.value),
                                    selected: selected,
                                    selectedColor: Colors.teal,
                                    labelStyle: TextStyle(
                                      color: selected ? Colors.white : null,
                                    ),
                                    onSelected: (v) {
                                      setS(
                                        () => pickupScheduleLocal = v
                                            ? entry.key
                                            : null,
                                      );
                                    },
                                  );
                                },
                              ).toList(),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: addressC,
                              decoration: InputDecoration(
                                labelText: sheetLoc.addressLabel2,
                              ),
                              textCapitalization: TextCapitalization.characters,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: notesC,
                              decoration: InputDecoration(
                                labelText: sheetLoc.note,
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: loanerDeviceC,
                              decoration: const InputDecoration(
                                labelText: 'Máy cho khách mượn (nếu có)',
                                hintText: 'VD: IPHONE 7 ĐEN, IMEI ...',
                              ),
                              textCapitalization: TextCapitalization.characters,
                            ),
                            const SizedBox(height: 20),
                            // Buttons live inside the scrollable area (not a
                            // fixed footer) so they stay reachable by
                            // scrolling no matter how tall the form grows —
                            // a fixed footer previously got pushed past the
                            // safe-area edge into the system gesture zone on
                            // some devices once this form gained more fields.
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      // FocusScope.of(ctx) (not FocusManager)
                                      // registers ctx's element as a fresh
                                      // dependent of this modal route's own
                                      // FocusScope right as the route starts
                                      // popping — an intermittent
                                      // _dependents.isEmpty race (only when
                                      // the dependency doesn't get cleared by
                                      // a rebuild before the pop lands).
                                      // FocusManager.instance.primaryFocus
                                      // unfocuses without touching the
                                      // widget-tree dependency system at all.
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      customerSearchTimer?.cancel();
                                      await Future.delayed(Duration.zero);
                                      if (ctx.mounted) {
                                        Navigator.pop(ctx, false);
                                      }
                                    },
                                    child: Text(sheetLoc.cancelButton),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      if (!(formKey.currentState?.validate() ??
                                          false)) {
                                        return;
                                      }
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      customerSearchTimer?.cancel();
                                      await Future.delayed(Duration.zero);
                                      if (ctx.mounted) {
                                        Navigator.pop(ctx, true);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: PopupTheme.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Text(sheetLoc.saveButton),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    customerSearchTimer?.cancel();
    final vals = (
      name: nameC.text.trim(),
      phone: phoneC.text.trim(),
      model: modelC.text.trim(),
      issue: issueC.text.trim(),
      acc: accC.text.trim(),
      warranty: warrantyC.text.trim(),
      address: addressC.text.trim(),
      notes: notesC.text.trim(),
      loanerDevice: loanerDeviceC.text.trim(),
      pickupSchedule: pickupScheduleLocal,
    );
    Future.delayed(Duration.zero, () {
      nameC.dispose();
      phoneC.dispose();
      modelC.dispose();
      issueC.dispose();
      accC.dispose();
      warrantyC.dispose();
      addressC.dispose();
      notesC.dispose();
      loanerDeviceC.dispose();
      searchC.dispose();
    });
    if (confirmed == true) {
      setState(() {
        r.customerName = vals.name.toUpperCase();
        r.phone = vals.phone;
        r.model = vals.model.toUpperCase();
        r.issue = vals.issue.toUpperCase();
        r.accessories = vals.acc.toUpperCase();
        r.warranty = vals.warranty.toUpperCase();
        r.address = vals.address.toUpperCase();
        r.notes = vals.notes.isNotEmpty ? vals.notes : null;
        r.loanerDevice = vals.loanerDevice.isNotEmpty
            ? vals.loanerDevice.toUpperCase()
            : null;
        r.pickupSchedule = vals.pickupSchedule;
      });
      await _saveData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Scaffold(
        appBar: CustomAppBar.build(title: loc.repairDetailTitle),
        body: Center(
          child: Text(
            loc.noAccessPermission,
            style: AppTextStyles.body1.copyWith(
              color: AppColors.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
    }

    final displayPrice = _displayedChargePrice(r);
    final displayProfit = displayPrice - r.cost;
    final hideDeliveredSensitiveFinancial = _hideDeliveredSensitiveFinancial(r);
    final canShowCost =
        _isManagerLike &&
        _canViewCostPrice &&
        _canViewRevenue &&
        !hideDeliveredSensitiveFinancial;
    final canShowProfit =
        _isManagerLike &&
        _canViewRevenue &&
        _canViewCostPrice &&
        !hideDeliveredSensitiveFinancial;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar.build(
        title: loc.repairOrderDetail,
        subtitle: r.model,
        actions: [
          IconButton(
            onPressed: _shareToZalo,
            icon: const Icon(Icons.share_rounded, color: Colors.white),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RepairInvoicePreviewView(
                    repair: r,
                    shopInfo: {
                      'shopName': _shopName,
                      'shopAddr': _shopAddr,
                      'shopPhone': _shopPhone,
                    },
                  ),
                ),
              );
            },
            icon: const Icon(Icons.preview, color: Colors.white),
          ),
          IconButton(
            onPressed: _printReceipt,
            icon: const Icon(Icons.print_rounded, color: Colors.white),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RepairInvoiceTemplateView(),
                ),
              );
            },
            icon: const Icon(Icons.design_services, color: Colors.white),
          ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 900,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              // === COMPACT: Status + Actions gộp ===
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Status row
                      _buildCompactStatusRow(),
                      const SizedBox(height: 10),
                      // Action buttons
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),

              // === Device issue/fault banner ===
              if (r.issue.isNotEmpty)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: const Color(0xFFFFF8F8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFFFCDD2)),
                  ),
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.build_rounded,
                          size: 16,
                          color: Color(0xFFD32F2F),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'LỖI THIẾT BỊ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD32F2F),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                r.issue,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF7F1D1D),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // === Storage location (editable) ===
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: Color(0xFF1E40AF),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Vị trí cất máy',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      StorageLocationSelector(
                        selectedLocationId: r.storageLocationId,
                        selectedLocationCode: r.storageLocationCode,
                        selectedLocationName: r.storageLocationName,
                        onSelected: (loc) async {
                          final oldCode = r.storageLocationCode ?? '';
                          final newCode = loc?.code ?? '';
                          final updated = r.copyWith(
                            storageLocationId: loc?.firestoreId,
                            storageLocationCode: newCode.isEmpty
                                ? null
                                : newCode,
                            storageLocationName: loc?.name,
                          );
                          await db.updateRepair(updated);
                          if (updated.id != null) {
                            await SyncOrchestrator().enqueue(
                              entityType: SyncEntityType.repair,
                              entityId: updated.id!,
                              firestoreId: updated.firestoreId,
                              operation: SyncOperation.update,
                              data: updated.toMap(),
                            );
                            unawaited(SyncOrchestrator().syncAll());
                          }
                          final user = FirebaseAuth.instance.currentUser;
                          final userName =
                              user?.email?.split('@').first.toUpperCase() ??
                              'NV';
                          await AuditService.logAction(
                            action: 'CẬP NHẬT VỊ TRÍ',
                            entityType: 'REPAIR',
                            entityId: r.firestoreId ?? r.id.toString(),
                            summary:
                                'Đổi vị trí: "${oldCode.isEmpty ? 'Trống' : oldCode}" → "${newCode.isEmpty ? 'Trống' : newCode}"',
                            payload: {
                              'oldCode': oldCode,
                              'newCode': newCode,
                              'by': userName,
                            },
                          );
                          if (mounted) {
                            setState(() => r = updated);
                            NotificationService.showSnackBar(
                              newCode.isEmpty
                                  ? 'Đã xóa vị trí lưu kho'
                                  : 'Đã cập nhật vị trí: $newCode',
                              color: newCode.isEmpty
                                  ? Colors.orange
                                  : Colors.green,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // === COMPACT: Tài chính + Dịch vụ gộp ===
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header tài chính
                      if (_canViewAnyFinancial || _canEditRepairCharge) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              size: 18,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              loc.financeTitleUpper,
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const Spacer(),
                            if (_canEditRepairFinancial || _canEditRepairCharge)
                              TextButton.icon(
                                onPressed: _editFinancials,
                                icon: const Icon(Icons.edit, size: 14),
                                label: Text(loc.editButton),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (canShowProfit)
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (displayProfit >= 0
                                                ? AppColors.success
                                                : AppColors.error)
                                            .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        loc.profitLabel,
                                        style: AppTextStyles.overline.copyWith(
                                          color: displayProfit >= 0
                                              ? AppColors.success
                                              : AppColors.error,
                                        ),
                                      ),
                                      Text(
                                        "${MoneyUtils.formatCurrency(displayProfit)} đ",
                                        style: AppTextStyles.body2.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: displayProfit >= 0
                                              ? AppColors.success
                                              : AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (canShowProfit && _canViewRevenue)
                              const SizedBox(width: 8),
                            if (_canViewRevenue || _canEditRepairCharge)
                              _miniFinCompact(
                                _displayedPriceLabel(r),
                                displayPrice,
                                AppColors.primary,
                              ),
                            if (_canViewRevenue && canShowCost)
                              const SizedBox(width: 8),
                            if (canShowCost)
                              _miniFinCompact(
                                loc.costLabel,
                                r.cost,
                                AppColors.warning,
                              ),
                          ],
                        ),
                        if ((_canViewRevenue || _canEditRepairCharge) &&
                            _historicalPricing != null) ...[
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SimilarRepairHistoryView(
                                  repairs: _historicalPricing!.matchedRepairs,
                                  showCost: canShowCost,
                                ),
                              ),
                            ),
                            child: Text(
                              '💡 Lịch sử tương tự (chạm để xem): '
                              '${MoneyUtils.formatCurrency(_historicalPricing!.minPrice)}đ - '
                              '${MoneyUtils.formatCurrency(_historicalPricing!.maxPrice)}đ '
                              '(${_historicalPricing!.sampleCount} đơn, '
                              'độ tin cậy: ${_historicalPricing!.confidence.label})',
                              style: AppTextStyles.overline.copyWith(
                                color: Colors.grey.shade600,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ],
                        if (r.pendingDeliveryApproval &&
                            r.requestedDeliveryPrice != null) ...[
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Đang chờ duyệt giá yêu cầu: ${MoneyUtils.formatCurrency(displayPrice)} đ',
                              style: AppTextStyles.overline.copyWith(
                                color: Colors.deepOrange.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        // Indicator: cost recorded in fund
                        if (canShowCost &&
                            r.costRecordedInFund &&
                            r.cost > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 12,
                                color: Colors.green.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Đã ghi sổ quỹ (${r.costPaymentMethod ?? ""})',
                                style: AppTextStyles.overline.copyWith(
                                  color: Colors.green.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        // Phân loại trạng thái giá vốn khi cost = 0:
                        // - chưa ghi nhận (costRecordedAt trống) => nhắc nhập
                        // - đã xác nhận không tốn chi phí => hiển thị rõ
                        if (canShowCost && r.cost == 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                (r.costRecordedAt ?? 0) > 0
                                    ? Icons.check_circle_outline
                                    : Icons.error_outline,
                                size: 12,
                                color: (r.costRecordedAt ?? 0) > 0
                                    ? Colors.blueGrey.shade500
                                    : Colors.orange.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (r.costRecordedAt ?? 0) > 0
                                    ? 'Không tốn giá vốn (0đ)'
                                    : 'Chưa ghi nhận giá vốn',
                                style: AppTextStyles.overline.copyWith(
                                  color: (r.costRecordedAt ?? 0) > 0
                                      ? Colors.blueGrey.shade600
                                      : Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                      // Phụ tùng — có chi tiết thì liệt kê kèm NCC cho dễ nhận biết
                      if (r.partsUsed.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        if (r.partsUsedDetailed.isNotEmpty)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.build, size: 14,
                                  color: Colors.blue),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final p in r.partsUsedDetailed)
                                      Builder(builder: (_) {
                                        final sup = (p.supplier ?? '')
                                                .trim()
                                                .isNotEmpty
                                            ? p.supplier!.trim()
                                            : (p.productId != null
                                                ? (_partSupplierByPid[
                                                        p.productId] ??
                                                    '')
                                                : '');
                                        return InkWell(
                                          onTap: () =>
                                              _openPartInInventory(p),
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                top: 2, bottom: 2),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '${p.name} x${p.qty}'
                                                    '${sup.isNotEmpty ? '  ·  NCC: $sup' : ''}',
                                                    style: AppTextStyles
                                                        .caption
                                                        .copyWith(
                                                      color: Colors.blue,
                                                      decoration:
                                                          TextDecoration
                                                              .underline,
                                                      decorationColor:
                                                          Colors.blue
                                                              .withValues(
                                                                  alpha: 0.35),
                                                    ),
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.chevron_right,
                                                  size: 14,
                                                  color: Colors.blue,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.build, size: 14,
                                  color: Colors.blue),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final entry
                                        in _parsePartsUsedText(r.partsUsed))
                                      Builder(builder: (_) {
                                        final name = entry.$1;
                                        final qty = entry.$2;
                                        final prod = _legacyPartLookup[name];
                                        final sup = (prod?.supplier ?? '')
                                            .trim();
                                        return InkWell(
                                          onTap: () => _openPartInInventory(
                                            PartUsedDetail(
                                              name: name,
                                              cost: 0,
                                              qty: qty,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                top: 2, bottom: 2),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '$name x$qty'
                                                    '${sup.isNotEmpty ? '  ·  NCC: $sup' : ''}',
                                                    style: AppTextStyles
                                                        .caption
                                                        .copyWith(
                                                      color: Colors.blue,
                                                      decoration:
                                                          TextDecoration
                                                              .underline,
                                                      decorationColor:
                                                          Colors.blue
                                                              .withValues(
                                                                  alpha: 0.35),
                                                    ),
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.chevron_right,
                                                  size: 14,
                                                  color: Colors.blue,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                      // Quick actions — cho phép cả đơn ĐÃ GIAO (status 4) bổ sung
                      // / thay đổi (thêm linh kiện, sửa KTV, ghi chú). Mọi thay
                      // đổi đều ghi nhật ký; các thao tác sửa vẫn theo phân quyền.
                      if (_canEditRepairOrder || _canEditRepairNotes) ...[
                        const SizedBox(height: 6),
                        if (r.status == 4)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Đơn đã giao — vẫn có thể bổ sung / chỉnh sửa, '
                              'thay đổi được ghi nhật ký.',
                              style: AppTextStyles.overline.copyWith(
                                color: Colors.blueGrey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            _quickAction(
                              loc.partsLabel,
                              Icons.inventory_2,
                              Colors.blue,
                              _selectPartsFromInventory,
                            ),
                            _quickAction(
                              loc.partsInventoryShort,
                              Icons.warehouse,
                              Colors.teal,
                              _navigateToPartsInventory,
                            ),
                            if (r.partsUsed.isNotEmpty && _canEditRepairOrder)
                              _quickAction(
                                'Đổi PT',
                                Icons.swap_horiz,
                                Colors.deepPurple,
                                _swapPartInRepair,
                              ),
                            if (r.partsUsed.isNotEmpty && _canEditRepairOrder)
                              _quickAction(
                                'Xóa PT',
                                Icons.delete_sweep,
                                Colors.red,
                                _removePartFromRepair,
                              ),
                            if (_canEditRepairOrder)
                              _quickAction(
                                'Sửa KTV',
                                Icons.engineering_rounded,
                                Colors.indigo,
                                _editTechnician,
                              ),
                            _quickAction(
                              loc.techShort,
                              Icons.note_add,
                              Colors.orange,
                              _editTechnicianNotes,
                            ),
                          ],
                        ),
                      ],

                      // Divider và Dịch vụ
                      const Divider(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.handyman,
                            size: 18,
                            color: Colors.teal.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            loc.servicesCount(r.services.length),
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                          ),
                          const Spacer(),
                          if (r.status != 4 && _canEditRepairNotes)
                            TextButton.icon(
                              onPressed: _showAddServiceDialog,
                              icon: const Icon(Icons.add, size: 14),
                              label: Text(loc.add),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                      if (r.services.isEmpty)
                        Text(
                          loc.noServicesYet,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.onSurface.withOpacity(0.5),
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        ...r.services.asMap().entries.map(
                          (e) => _buildCompactServiceItem(e.key, e.value),
                        ),
                      if (r.services.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                loc.totalServices,
                                style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_canViewAnyFinancial)
                                Text(
                                  "${MoneyUtils.formatCurrency(r.services.fold(0, (sum, s) => sum + s.cost))} đ",
                                  style: AppTextStyles.body2.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.warning,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // === COMPACT: Khách hàng + Hình ảnh ===
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row: customer deep-link + actions
                      Row(
                        children: [
                          Expanded(
                            child: ClickableCustomerHeader(
                              customerName: r.customerName,
                              phoneNumber: r.phone,
                              sourceEvent:
                                  'customer_profile_opened_from_repair',
                              tooltip: 'Mở hồ sơ khách hàng từ phiếu sửa',
                            ),
                          ),
                          if (_canEditRepairBasicInfo)
                            IconButton(
                              onPressed: _editBasicInfo,
                              icon: const Icon(Icons.edit, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Chỉnh sửa thông tin',
                            ),
                          TextButton.icon(
                            onPressed: _callCustomer,
                            icon: const Icon(Icons.call, size: 14),
                            label: Text(r.phone, style: AppTextStyles.caption),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Info rows - hiển thị trực tiếp, không ẩn trong dropdown
                      _compactInfoRow(
                        'Nhận',
                        _formatStageActorWithTime(
                          actorRaw: r.createdBy,
                          timestamp: r.createdAt,
                        ),
                      ),
                      _compactInfoRow(
                        'Sửa',
                        _formatStageActorWithTime(
                          actorRaw: r.repairedBy,
                          timestamp: _repairStageTimestamp(r),
                        ),
                      ),
                      _compactInfoRow(
                        'Giao',
                        _formatStageActorWithTime(
                          actorRaw: r.deliveredBy,
                          timestamp: _deliveryStageTimestamp(r),
                        ),
                      ),
                      if (_hasModifierInfo)
                        _compactInfoRow('Sửa đổi', _formatModifierInfo()),
                      if (r.accessories.isNotEmpty)
                        _compactInfoRow("PK", r.accessories),
                      if (r.warranty.isNotEmpty)
                        _compactInfoRow(loc.warranty, r.warranty),
                      if (r.pickupScheduleLabel != null)
                        _compactInfoRow('Hẹn giao', r.pickupScheduleLabel!),
                      if (r.notes != null && r.notes!.isNotEmpty)
                        _compactInfoRow(loc.note, r.notes!),
                      if (r.loanerDevice != null &&
                          r.loanerDevice!.isNotEmpty)
                        _buildLoanerDeviceRow(),

                      // Hình ảnh
                      if (_displayableImages(r.receiveImages).isNotEmpty ||
                          (r.status < 4 && _canAddRepairImage)) ...[
                        const Divider(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.photo_library,
                              size: 16,
                              color: Colors.pink.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              loc.imagesCount(
                                _displayableImages(r.receiveImages).length,
                              ),
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.pink.shade700,
                              ),
                            ),
                            const Spacer(),
                            if (r.status < 4 && _canAddRepairImage)
                              GestureDetector(
                                onTap: _addReceiveImage,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.pink.withAlpha(20),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.pink.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo,
                                        size: 13,
                                        color: Colors.pink.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Thêm ảnh',
                                        style: AppTextStyles.overline.copyWith(
                                          color: Colors.pink.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_displayableImages(r.receiveImages).isNotEmpty)
                          SizedBox(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _displayableImages(
                                r.receiveImages,
                              ).length,
                              itemBuilder: (ctx, i) => GestureDetector(
                                onTap: () => _showFullImage(
                                  _displayableImages(r.receiveImages),
                                  i,
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  width: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildSmartImage(
                                      _displayableImages(r.receiveImages)[i],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  void _callCustomer() async {
    if (r.phone.isNotEmpty) {
      final uri = Uri.parse('tel:${r.phone}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  Future<void> _addReceiveImage() async {
    if (!_canAddRepairImage) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 60);
    if (picked == null) return;
    if (mounted) setState(() => _isUpdating = true);
    try {
      // Local-first: append local path first, upload cloud in background.
      final localPath = picked.path;
      final existing = r.imagePath ?? '';
      final updated = existing.isEmpty ? localPath : '$existing,$localPath';
      r.imagePath = updated;
      r.isSynced = false;
      await db.upsertRepair(r);
      if (r.id != null) {
        await SyncOrchestrator().enqueue(
          entityType: SyncEntityType.repair,
          entityId: r.id!,
          firestoreId: r.firestoreId,
          operation: SyncOperation.update,
          data: r.toMap(),
        );
        if (r.firestoreId != null && r.firestoreId!.isNotEmpty) {
          BackgroundUploadService.uploadRepairImages(
            localRepairId: r.id!,
            firestoreId: r.firestoreId!,
            images: [picked],
          );
        }
      }
      if (mounted) setState(() {});
      NotificationService.showSnackBar(
        'Đã thêm ảnh, đang tải nền lên hệ thống',
        color: AppColors.success,
      );
    } catch (e) {
      NotificationService.showSnackBar(
        'Lỗi thêm ảnh: $e',
        color: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // === COMPACT HELPER WIDGETS ===

  Widget _buildCompactStatusRow() {
    Color color;
    IconData icon;
    switch (r.status) {
      case 1:
        color = Colors.blue;
        icon = Icons.assignment_turned_in;
        break;
      case 2:
        color = Colors.orange;
        icon = Icons.build;
        break;
      case 3:
        color = AppColors.success;
        icon = Icons.check_circle;
        break;
      case 4:
        color = AppColors.primary;
        icon = Icons.verified;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }
    final isLocalOnly = (r.firestoreId ?? '').trim().isEmpty;
    final isPendingSync = !r.isSynced || isLocalOnly;

    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.model.toUpperCase(),
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getStatusText(
                  r.status,
                  pendingApproval: r.pendingDeliveryApproval,
                ),
                style: AppTextStyles.caption.copyWith(
                  color: _getStatusColor(
                    r.status,
                    pendingApproval: r.pendingDeliveryApproval,
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (r.pendingDeliveryApproval && r.requestedDeliveryPrice != null)
                Text(
                  'Giá yêu cầu: ${MoneyUtils.formatCurrency(r.requestedDeliveryPrice ?? 0)} đ',
                  style: AppTextStyles.overline.copyWith(
                    color: Colors.deepOrange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        // Sync state badge
        if (isPendingSync)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 11,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 3),
                Text(
                  isLocalOnly ? 'Chỉ local' : 'Chờ sync',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_done_rounded,
                  size: 11,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 3),
                Text(
                  'Đã sync',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _miniFinCompact(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.overline.copyWith(color: color, fontSize: 11),
          ),
          Text(
            MoneyUtils.formatCurrency(value),
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(color: color, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactServiceItem(int index, RepairService s) {
    return Padding(
      padding: EdgeInsets.only(top: index > 0 ? 6 : 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _openServiceHistory(s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.build_circle, size: 16, color: Colors.blue),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.serviceName,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.grey.shade400,
                      ),
                    ),
                    if (s.partnerName != null)
                      Text(
                        loc.partnerLabel(s.partnerName!),
                        style: AppTextStyles.overline
                            .copyWith(color: Colors.blue),
                      ),
                  ],
                ),
              ),
              if (_canViewAnyFinancial)
                Text(
                  "${MoneyUtils.formatCurrency(s.cost)} đ",
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
              if (r.status != 4 && _canEditRepairNotes)
                IconButton(
                  icon: const Icon(Icons.edit, size: 14, color: Colors.grey),
                  onPressed: () => _showAddServiceDialog(s, index),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 24, minHeight: 24),
                )
              else
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 55,
            child: Text(
              "$label:",
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppTextStyles.caption)),
        ],
      ),
    );
  }

  Widget _buildLoanerDeviceRow() {
    final returned = r.loanerDeviceReturned;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 55,
            child: Text(
              "Máy mượn:",
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(r.loanerDevice!, style: AppTextStyles.caption),
          ),
          GestureDetector(
            onTap: _toggleLoanerReturned,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: returned
                    ? Colors.green.withAlpha(25)
                    : Colors.orange.withAlpha(25),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: returned ? Colors.green.shade300 : Colors.orange.shade300,
                ),
              ),
              child: Text(
                returned ? 'Đã trả' : 'Chưa trả',
                style: AppTextStyles.overline.copyWith(
                  color: returned ? Colors.green.shade700 : Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLoanerReturned() async {
    if (!_canEditRepairBasicInfo) {
      NotificationService.showSnackBar(
        'Bạn không có quyền sửa thông tin đơn sửa chữa.',
        color: Colors.orange,
      );
      return;
    }
    setState(() {
      r.loanerDeviceReturned = !r.loanerDeviceReturned;
    });
    await _saveData();
    NotificationService.showSnackBar(
      r.loanerDeviceReturned
          ? 'Đã đánh dấu khách trả lại máy mượn'
          : 'Đã bỏ đánh dấu trả máy mượn',
      color: Colors.green,
    );
  }

  int? _repairStageTimestamp(Repair rep) {
    if ((rep.finishedAt ?? 0) > 0) return rep.finishedAt;
    if ((rep.startedAt ?? 0) > 0) return rep.startedAt;
    return null;
  }

  int? _deliveryStageTimestamp(Repair rep) {
    if ((rep.deliveredAt ?? 0) > 0) return rep.deliveredAt;
    if ((rep.deliveredBy ?? '').trim().isEmpty) return null;

    if ((rep.lastCaredAt ?? 0) > 0) return rep.lastCaredAt;
    if ((rep.finishedAt ?? 0) > 0) return rep.finishedAt;
    return null;
  }

  String _formatStageActorWithTime({
    required String? actorRaw,
    required int? timestamp,
  }) {
    final actor = _staffLabel(actorRaw);
    final timeAndDay = _formatTimeAndDay(timestamp);

    if (actor == '---' && timeAndDay == '---') return '---';
    if (actor == '---') return timeAndDay;
    if (timeAndDay == '---') return actor;
    return '$actor  $timeAndDay';
  }

  String _formatTimeAndDay(int? timestamp) {
    if (timestamp == null || timestamp <= 0) return '---';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final time = DateFormat('HH:mm').format(dt);
    final day = DateFormat('dd/MM/yyyy').format(dt);
    return '$time - $day';
  }

  bool get _hasModifierInfo =>
      _lastModifiedBy != null && (_lastModifiedAt ?? 0) > 0;

  String _formatModifierInfo() {
    if (!_hasModifierInfo) return '---';
    return '${_lastModifiedBy!}  ${_formatTimeAndDay(_lastModifiedAt)}';
  }

  Widget _buildActionButtons() {
    debugPrint(
      '_buildActionButtons: status=${r.status}, pendingDeliveryApproval=${r.pendingDeliveryApproval}',
    );

    if (r.status == 4) return const SizedBox();

    if (r.status == 3 && r.pendingDeliveryApproval) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.deepOrange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.deepOrange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_empty, color: Colors.deepOrange.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc.waitingManagerApproval,
                style: TextStyle(
                  color: Colors.deepOrange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (r.status == 3 && !r.pendingDeliveryApproval) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc.repairDoneReadyForDelivery,
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Status < 3: nút ĐÃ XONG đã được dời xuống thanh hành động dưới cùng
    // để gom cùng LƯU/IN/ZALO trên một hàng.
    return const SizedBox.shrink();
  }

  Future<void> _showAddServiceDialog([
    RepairService? editService,
    int? editIndex,
  ]) async {
    if (!_canEditRepairNotes && !_ensureCanEditRepairOrder()) return;
    await _loadPartners();
    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    final serviceCtrl = TextEditingController(
      text: editService?.serviceName ?? '',
    );
    final costCtrl = TextEditingController(
      text: editService != null
          ? MoneyUtils.formatCurrency(editService.cost)
          : '',
    );
    final availablePartners = List<RepairPartner>.from(_partners);

    RepairPartner? selectedPartner;
    if (editService != null &&
        editService.partnerId != null &&
        availablePartners.isNotEmpty) {
      for (final partner in availablePartners) {
        if (partner.id == editService.partnerId) {
          selectedPartner = partner;
          break;
        }
      }
    }

    // Phương thức thanh toán cho đối tác
    String? selectedPaymentMethod = editService?.paymentMethod;
    final paymentMethods = ['TIỀN MẶT', 'CHUYỂN KHOẢN', 'CÔNG NỢ'];
    if (selectedPaymentMethod != null &&
        !paymentMethods.contains(selectedPaymentMethod)) {
      selectedPaymentMethod = null;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final dialogLoc = AppLocalizations.of(ctx)!;
        return StatefulBuilder(
          builder: (ctx, setS) {
            final maxSheetHeight = MediaQuery.sizeOf(ctx).height * 0.85;
            // KeyboardAwarePadding reads the keyboard from the platform
            // FlutterView (no InheritedWidget dependency) so it tracks live
            // without the _dependents.isEmpty crash. includeNavBar: false —
            // the inner SafeArea(top: false) already handles the nav bar.
            return KeyboardAwarePadding(
              includeNavBar: false,
              child: SafeArea(
                top: false,
                child: Container(
                  constraints: BoxConstraints(maxHeight: maxSheetHeight),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dialogBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: SizedBox(
                    height: maxSheetHeight,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              editService != null
                                  ? dialogLoc.editService
                                  : dialogLoc.addServiceTitle,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _navigateToRepairPartners();
                              },
                              icon: const Icon(
                                Icons.group,
                                color: Colors.teal,
                                size: 20,
                              ),
                              tooltip: dialogLoc.viewRepairPartners,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Form(
                              key: formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextFormField(
                                    controller: serviceCtrl,
                                    decoration: InputDecoration(
                                      labelText: dialogLoc.serviceNameRequired,
                                    ),
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    validator: (v) => (v ?? '').trim().isEmpty
                                        ? dialogLoc.pleaseEnterServiceName
                                        : null,
                                  ),
                                  const SizedBox(height: 10),
                                  CurrencyTextField(
                                    controller: costCtrl,
                                    label: dialogLoc.costVnd,
                                    validator: (v) => MoneyUtils.validateAmount(
                                      v ?? '',
                                      min: 1,
                                      fieldName: dialogLoc.costField,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (availablePartners.isNotEmpty)
                                    DropdownButtonFormField<RepairPartner?>(
                                      decoration: InputDecoration(
                                        labelText: dialogLoc.partnerOptional2,
                                      ),
                                      initialValue: selectedPartner,
                                      items: [
                                        DropdownMenuItem<RepairPartner?>(
                                          value: null,
                                          child: Text(
                                            dialogLoc.noPartnerOption,
                                          ),
                                        ),
                                        ...availablePartners.map(
                                          (p) =>
                                              DropdownMenuItem<RepairPartner?>(
                                                value: p,
                                                child: Text(p.name),
                                              ),
                                        ),
                                      ],
                                      onChanged: (p) => setS(() {
                                        selectedPartner = p;
                                        if (p == null) {
                                          selectedPaymentMethod = null;
                                        }
                                      }),
                                    ),
                                  if (availablePartners.isEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.orange.shade200,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Chưa có đối tác sửa chữa để chọn.',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                  color: Colors.orange.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextButton.icon(
                                            onPressed: () async {
                                              Navigator.pop(ctx);
                                              await _navigateToRepairPartners();
                                            },
                                            icon: const Icon(
                                              Icons.group,
                                              size: 16,
                                            ),
                                            label: Text(
                                              dialogLoc.viewRepairPartners,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (selectedPartner != null) ...[
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      decoration: InputDecoration(
                                        labelText: dialogLoc
                                            .partnerPaymentMethodRequired,
                                        prefixIcon: const Icon(
                                          Icons.payment,
                                          size: 20,
                                        ),
                                      ),
                                      initialValue: selectedPaymentMethod,
                                      items: paymentMethods
                                          .map(
                                            (m) => DropdownMenuItem<String>(
                                              value: m,
                                              child: Text(m),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) =>
                                          setS(() => selectedPaymentMethod = v),
                                      validator: (v) =>
                                          selectedPartner != null &&
                                              (v == null || v.isEmpty)
                                          ? dialogLoc.pleaseSelectPaymentMethod
                                          : null,
                                    ),
                                    if (selectedPaymentMethod == 'CHUYỂN KHOẢN')
                                      bankTransferAssistCard(
                                        amountController: costCtrl,
                                        direction: BankPayDirection.outbound,
                                        counterpartyName: selectedPartner?.name,
                                        refText: 'Tra doi tac '
                                            '${selectedPartner?.name ?? ''}',
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (editService != null)
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await _deleteService(editIndex!);
                                },
                                child: Text(
                                  dialogLoc.delete,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(dialogLoc.cancel),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              // minimumSize mặc định của theme là
                              // Size(double.infinity, buttonHeight) — dùng
                              // cho nút full-width. Trong Row có Spacer(),
                              // width vô hạn đó bị "tighten" thành constraint
                              // vô hạn cứng và crash layout. Ghi đè bằng
                              // smallElevatedButtonStyle (minWidth: 0) để an
                              // toàn khi đặt cạnh các nút khác trong Row.
                              style: AppButtonStyles.smallElevatedButtonStyle,
                              onPressed: () async {
                                if (!(formKey.currentState?.validate() ??
                                    false)) {
                                  return;
                                }
                                final cost = MoneyUtils.parseCurrency(
                                  costCtrl.text,
                                );
                                final service = RepairService(
                                  firestoreId:
                                      editService?.firestoreId ??
                                      RepairPartnerService.generateServiceFirestoreId(),
                                  serviceName: serviceCtrl.text
                                      .trim()
                                      .toUpperCase(),
                                  cost: cost,
                                  partnerId: selectedPartner?.id,
                                  partnerFirestoreId: selectedPartner?.firestoreId,
                                  partnerName: selectedPartner?.name,
                                  paymentMethod: selectedPaymentMethod,
                                );
                                Navigator.pop(ctx);
                                await _saveService(service, editIndex);
                              },
                              child: Text(
                                editService != null
                                    ? dialogLoc.update
                                    : dialogLoc.add,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _repairOrderTrackingId() {
    final firestoreId = r.firestoreId?.trim();
    if (firestoreId != null && firestoreId.isNotEmpty) {
      return firestoreId;
    }
    return 'local_${r.id ?? 0}';
  }

  bool _didPartnerHistoryChange(
    RepairService? oldService,
    RepairService newService,
  ) {
    if (oldService == null) {
      return newService.partnerId != null;
    }
    return oldService.partnerId != newService.partnerId ||
        (oldService.serviceName.trim().toUpperCase() !=
            newService.serviceName.trim().toUpperCase()) ||
        oldService.cost != newService.cost;
  }

  bool _didPartnerFinancialStateChange(
    RepairService? oldService,
    RepairService newService,
  ) {
    if (oldService == null) {
      return newService.partnerId != null;
    }
    return oldService.partnerId != newService.partnerId ||
        oldService.cost != newService.cost ||
        (oldService.paymentMethod ?? '') != (newService.paymentMethod ?? '');
  }

  Future<void> _cleanupPartnerHistoryForService(RepairService service) async {
    if (service.partnerId == null) {
      return;
    }

    final normalizedServiceName = service.serviceName.trim().toUpperCase();
    final histories = await db.getPartnerRepairHistory(
      repairOrderId: _repairOrderTrackingId(),
    );
    final dbInstance = await db.database;

    for (final history in histories) {
      final samePartner = history['partnerId'] == service.partnerId;
      final sameIssue =
          (history['issue'] ?? '').toString().trim().toUpperCase() ==
          normalizedServiceName;
      final sameRepairContent =
          (history['repairContent'] ?? '').toString().trim().toUpperCase() ==
          normalizedServiceName;
      final sameCost =
          (history['partnerCost'] as num?)?.toInt() == service.cost;
      if (!samePartner || !sameIssue || !sameRepairContent || !sameCost) {
        continue;
      }

      final firestoreId = history['firestoreId']?.toString();
      if (firestoreId != null && firestoreId.isNotEmpty) {
        await db.deletePartnerRepairHistoryByFirestoreId(firestoreId);
        await FirestoreService.deletePartnerRepairHistoryByFirestoreId(
          firestoreId,
        );
        continue;
      }

      final localId = history['id'] as int?;
      if (localId != null) {
        await dbInstance.delete(
          'partner_repair_history',
          where: 'id = ?',
          whereArgs: [localId],
        );
      }
    }
  }

  Future<void> _deleteDebtSnapshot(Map<String, dynamic> debtRow) async {
    final debtFId = debtRow['firestoreId']?.toString();
    final localId = debtRow['id'] as int?;
    if (debtFId == null || debtFId.isEmpty || localId == null) {
      return;
    }

    await db.deleteDebtByFirestoreId(debtFId);
    await SyncOrchestrator().enqueue(
      entityType: SyncEntityType.debt,
      entityId: localId,
      firestoreId: debtFId,
      operation: SyncOperation.delete,
      data: {...debtRow, 'deleted': true},
    );
  }

  Future<void> _cleanupPartnerDebtForService(RepairService service) async {
    if (service.partnerId == null || (service.paymentMethod ?? '').isEmpty) {
      return;
    }

    final repairOrderId = _repairOrderTrackingId();
    final serviceFirestoreId = service.firestoreId?.trim();
    if (serviceFirestoreId != null && serviceFirestoreId.isNotEmpty) {
      final stableDebtId = RepairPartnerService.buildPartnerDebtFirestoreId(
        repairOrderId: repairOrderId,
        serviceFirestoreId: serviceFirestoreId,
        partnerId: service.partnerId!,
        partnerCost: service.cost,
      );
      final stableDebt = await db.getDebtByFirestoreId(stableDebtId);
      if (stableDebt != null) {
        await _deleteDebtSnapshot(stableDebt);
      }
    }

    final dbInstance = await db.database;
    final legacyRows = await dbInstance.query(
      'debts',
      where:
          'linkedId = ? AND relatedPartId = ? AND totalAmount = ? AND (deleted IS NULL OR deleted = 0)',
      whereArgs: [repairOrderId, service.partnerId.toString(), service.cost],
    );
    final serviceName = service.serviceName.trim().toUpperCase();
    final seenIds = <int>{};
    for (final row in legacyRows) {
      final localId = row['id'] as int?;
      if (localId == null || seenIds.contains(localId)) {
        continue;
      }
      final note = (row['note'] ?? '').toString().toUpperCase();
      if (!note.contains(serviceName)) {
        continue;
      }
      seenIds.add(localId);
      await _deleteDebtSnapshot(Map<String, dynamic>.from(row));
    }
  }

  Future<void> _deletePartnerPaymentSnapshot(
    Map<String, dynamic> paymentRow,
  ) async {
    final paymentFId = paymentRow['firestoreId']?.toString();
    final localId = paymentRow['id'] as int?;
    if (paymentFId == null || paymentFId.isEmpty || localId == null) {
      return;
    }

    await db.deleteRepairPartnerPaymentByFirestoreId(paymentFId);
    await SyncOrchestrator().enqueue(
      entityType: SyncEntityType.partnerPayment,
      entityId: localId,
      firestoreId: paymentFId,
      operation: SyncOperation.delete,
      data: {...paymentRow, 'deleted': true},
    );
  }

  Future<void> _cleanupPartnerDirectPaymentForService(
    RepairService service,
    int? legacyIndex,
  ) async {
    if (service.partnerId == null ||
        service.paymentMethod == null ||
        service.paymentMethod == 'CÔNG NỢ') {
      return;
    }

    final repairOrderId = _repairOrderTrackingId();
    final serviceFirestoreId = service.firestoreId?.trim();
    final keyCandidates = <String>{};

    if (serviceFirestoreId != null && serviceFirestoreId.isNotEmpty) {
      keyCandidates.add(
        RepairPartnerService.buildPartnerPaymentIdempotencyKey(
          repairOrderId: repairOrderId,
          serviceFirestoreId: serviceFirestoreId,
          partnerId: service.partnerId!,
          partnerCost: service.cost,
          paymentMethod: service.paymentMethod!,
        ),
      );
    }

    if (legacyIndex != null && r.firestoreId != null) {
      keyCandidates.add(
        'detail_${r.firestoreId}_${service.partnerId}_${legacyIndex}_${service.serviceName}_${service.cost}_${service.paymentMethod}',
      );
      keyCandidates.add(
        'create_${r.firestoreId}_${service.partnerId}_${legacyIndex}_${service.serviceName}_${service.cost}_${service.paymentMethod}',
      );
    }

    for (final key in keyCandidates) {
      final paymentFirestoreId =
          PaymentIntentService.buildDirectPaymentRecordFirestoreId(
            type: PaymentIntentType.repairPartnerDebt,
            idempotencyKey: key,
          );
      final intentId = PaymentIntentService.buildDirectPaymentIntentId(
        type: PaymentIntentType.repairPartnerDebt,
        idempotencyKey: key,
      );
      if (paymentFirestoreId == null || intentId == null) {
        continue;
      }

      final paymentRow = await db.getRepairPartnerPaymentByFirestoreId(
        paymentFirestoreId,
      );
      if (paymentRow != null) {
        await _deletePartnerPaymentSnapshot(paymentRow);
      }
      await db.deletePaymentIntent(intentId);
    }
  }

  Future<void> _cleanupPartnerServiceRecords(
    RepairService service,
    int? legacyIndex,
  ) async {
    await _cleanupPartnerHistoryForService(service);
    await _cleanupPartnerDebtForService(service);
    await _cleanupPartnerDirectPaymentForService(service, legacyIndex);
  }

  Future<void> _createPartnerFinancialRecordsForService(
    RepairService service,
  ) async {
    if (service.partnerId == null) {
      return;
    }

    final repairOrderId = _repairOrderTrackingId();
    final partnerService = RepairPartnerService();
    await partnerService.createPartnerHistoryForRepair(
      repairOrderId: repairOrderId,
      partnerId: service.partnerId!,
      partnerCost: service.cost,
      customerName: r.customerName,
      deviceModel: r.model,
      issue: service.serviceName,
      repairContent: service.serviceName,
    );

    if (service.paymentMethod == null || service.paymentMethod!.isEmpty) {
      return;
    }

    final serviceFirestoreId = service.firestoreId?.trim();
    if (serviceFirestoreId == null || serviceFirestoreId.isEmpty) {
      return;
    }

    final trackingNote = RepairPartnerService.buildPartnerTrackingNote(
      repairOrderId: repairOrderId,
      serviceFirestoreId: serviceFirestoreId,
      serviceName: service.serviceName,
      deviceModel: r.model,
      customerName: r.customerName,
      isDebt: service.paymentMethod == 'CÔNG NỢ',
    );

    if (service.paymentMethod != 'CÔNG NỢ') {
      final payResult = await PaymentIntentService.executePaymentDirect(
        type: PaymentIntentType.repairPartnerDebt,
        amount: service.cost,
        paymentMethod: PaymentMethod.fromCode(service.paymentMethod),
        description:
            'Trả đối tác: ${service.partnerName ?? "N/A"} - ${service.serviceName}',
        executedBy: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        referenceId: repairOrderId,
        referenceType: 'repair_partner_service',
        personName: service.partnerName,
        notes: trackingNote,
        metadata: {
          'repairId': r.id,
          'repairFirestoreId': repairOrderId,
          'partnerId': service.partnerId,
          'partnerFirestoreId': service.partnerFirestoreId,
          'partnerName': service.partnerName,
          'serviceName': service.serviceName,
          'paymentMethod': service.paymentMethod,
          'serviceFirestoreId': serviceFirestoreId,
        },
        idempotencyKey: RepairPartnerService.buildPartnerPaymentIdempotencyKey(
          repairOrderId: repairOrderId,
          serviceFirestoreId: serviceFirestoreId,
          partnerId: service.partnerId!,
          partnerCost: service.cost,
          paymentMethod: service.paymentMethod!,
        ),
      );
      debugPrint(
        '💳 Partner payment ${payResult.success ? "OK" : "FAILED"}: ${service.cost}đ',
      );
      return;
    }

    try {
      final debtFId = RepairPartnerService.buildPartnerDebtFirestoreId(
        repairOrderId: repairOrderId,
        serviceFirestoreId: serviceFirestoreId,
        partnerId: service.partnerId!,
        partnerCost: service.cost,
      );
      // Guard chống nhân đôi: nếu debt đã tồn tại với cùng firestoreId thì bỏ qua
      final existingDebt = await db.getDebtByFirestoreId(debtFId);
      if (existingDebt != null) {
        debugPrint('ℹ️ Partner debt đã tồn tại, bỏ qua tạo trùng: $debtFId');
        return;
      }
      await PaymentIntentService.createDebtRecord(
        debtType: 'SHOP_OWES',
        amount: service.cost,
        personName: service.partnerName ?? 'Đối tác sửa chữa',
        note: trackingNote,
        linkedId: repairOrderId,
        // Stable partner identity first; fall back to volatile local id.
        relatedPartId:
            service.partnerFirestoreId ?? service.partnerId?.toString() ?? '',
        debtFirestoreId: debtFId,
      );
      EventBus().emit(EventBus.financialChanged);
    } catch (e) {
      debugPrint('❌ Error creating partner debt: $e');
    }
  }

  Future<void> _saveService(RepairService service, int? editIndex) async {
    if (!_ensureCanEditRepairOrder()) return;
    setState(() => _isUpdating = true);
    try {
      final newServices = List<RepairService>.from(r.services);
      final oldService = editIndex != null ? newServices[editIndex] : null;
      final trackedService = service.copyWith(
        firestoreId:
            service.firestoreId ??
            oldService?.firestoreId ??
            RepairPartnerService.generateServiceFirestoreId(),
      );

      final shouldRefreshHistory =
          editIndex == null ||
          _didPartnerHistoryChange(oldService, trackedService);
      final shouldRefreshFinancials =
          editIndex == null ||
          _didPartnerFinancialStateChange(oldService, trackedService);

      if (editIndex != null && oldService != null) {
        if (shouldRefreshHistory || shouldRefreshFinancials) {
          await _cleanupPartnerServiceRecords(oldService, editIndex);
        }
      }

      if (editIndex != null) {
        newServices[editIndex] = trackedService;
      } else {
        newServices.add(trackedService);
      }
      final updatedCost =
          (r.cost - (oldService?.cost ?? 0) + trackedService.cost).clamp(
            0,
            999999999,
          );
      r.services = newServices;
      r.cost = updatedCost;
      r.lastCaredAt = DateTime.now().millisecondsSinceEpoch;
      r.isSynced = false;
      await db.upsertRepair(r);

      if (trackedService.partnerId != null &&
          (shouldRefreshHistory || shouldRefreshFinancials)) {
        await _createPartnerFinancialRecordsForService(trackedService);
      }

      NotificationService.showSnackBar(
        editIndex != null ? loc.serviceUpdated : loc.serviceAdded,
        color: AppColors.success,
      );
      _emitRepairChanged(
        financialImpact: true,
        includeDebts: true,
        includeServiceChanges: true,
      );
      // FIX: Enqueue repair sync after saving service
      if (r.id != null) {
        await SyncOrchestrator().enqueue(
          entityType: SyncEntityType.repair,
          entityId: r.id!,
          firestoreId: r.firestoreId,
          operation: SyncOperation.update,
          data: r.toMap(),
        );
        // ignore: unawaited_futures
        SyncOrchestrator().syncAll();
        // ignore: unawaited_futures
        SyncService.syncRepairData();
      }
    } catch (e) {
      NotificationService.showSnackBar(
        '${loc.error}: $e',
        color: AppColors.error,
      );
    }
    if (mounted) setState(() => _isUpdating = false);
  }

  Future<void> _deleteService(int index) async {
    if (!_ensureCanEditRepairOrder()) return;
    setState(() => _isUpdating = true);
    try {
      final newServices = List<RepairService>.from(r.services);
      final removedService = newServices[index];
      await _cleanupPartnerServiceRecords(removedService, index);
      newServices.removeAt(index);
      r.services = newServices;
      r.cost = (r.cost - removedService.cost).clamp(0, 999999999);
      r.lastCaredAt = DateTime.now().millisecondsSinceEpoch;
      r.isSynced = false;
      await db.upsertRepair(r);
      // FIX: Enqueue repair sync after deleting service
      if (r.id != null) {
        await SyncOrchestrator().enqueue(
          entityType: SyncEntityType.repair,
          entityId: r.id!,
          firestoreId: r.firestoreId,
          operation: SyncOperation.update,
          data: r.toMap(),
        );
        // ignore: unawaited_futures
        SyncOrchestrator().syncAll();
        // ignore: unawaited_futures
        SyncService.syncRepairData();
      }
      NotificationService.showSnackBar(
        loc.serviceDeleted,
        color: AppColors.warning,
      );
      _emitRepairChanged(
        financialImpact: true,
        includeDebts: true,
        includeServiceChanges: true,
      );
    } catch (e) {
      NotificationService.showSnackBar(
        '${loc.error}: $e',
        color: AppColors.error,
      );
    }
    if (mounted) setState(() => _isUpdating = false);
  }

  Future<void> _showFullImage(List<String> images, int initialIndex) async {
    final resolvedResults = await Future.wait<String?>(
      images.map(_resolveDisplayImagePath),
    );
    final resolvedImages = resolvedResults
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (resolvedImages.isEmpty) return;
    final safeInitialIndex = initialIndex
        .clamp(0, resolvedImages.length - 1)
        .toInt();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PhotoViewGallery.builder(
              itemCount: resolvedImages.length,
              builder: (context, index) {
                final path = resolvedImages[index].trim();
                return PhotoViewGalleryPageOptions(
                  imageProvider:
                      (path.startsWith('http') ||
                          path.startsWith('blob:') ||
                          path.startsWith('data:'))
                      ? CachedNetworkImageProvider(path) as ImageProvider
                      : kIsWeb
                      ? CachedNetworkImageProvider(path) as ImageProvider
                      : FileImage(File(path)),
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                );
              },
              pageController: PageController(initialPage: safeInitialIndex),
              scrollPhysics: const BouncingScrollPhysics(),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _staffLabel(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return '---';
    if (value.contains('@')) {
      return value.split('@').first.toUpperCase();
    }
    return value.toUpperCase();
  }

  Widget _buildBottomActions() {
    const compactLabelStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 10,
      height: 1,
    );

    // Dùng _isManagerLike đã tính từ Firestore trong _checkPermission()
    // Tránh dùng getRoleFast() (Claims-based) — có thể stale với chủ shop/quản lý mới
    final isManager = _isManagerLike;

    Widget? statusButton;
    if (r.status < 3) {
      statusButton = ElevatedButton.icon(
        onPressed: _isUpdating ? null : _promptLocationAndMarkDone,
        icon: _isUpdating
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle, color: Colors.white, size: 14),
        label: const Text(
          'XONG',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            height: 1,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else if (r.status == 3 && r.pendingDeliveryApproval) {
      if (isManager) {
        statusButton = ElevatedButton.icon(
          onPressed: _isUpdating ? null : _approveDelivery,
          icon: _isUpdating
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.verified, color: Colors.white, size: 14),
          label: const Text(
            'DUYỆT',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              height: 1,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        // Nhân viên đã gửi yêu cầu duyệt thì ẩn nút đổi trạng thái.
        statusButton = null;
      }
    } else if (r.status == 3) {
      if (isManager) {
        statusButton = ElevatedButton.icon(
          onPressed: _isUpdating ? null : () => _updateStatus(4),
          icon: _isUpdating
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.local_shipping, color: Colors.white, size: 14),
          label: const Text(
            'GIAO',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              height: 1,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        statusButton = ElevatedButton.icon(
          onPressed: _isUpdating ? null : _submitForDeliveryApproval,
          icon: _isUpdating
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send, color: Colors.white, size: 14),
          label: const Text(
            'Y/C DUYỆT',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              height: 1,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (statusButton != null) ...[
              Expanded(child: statusButton),
              const SizedBox(width: 4),
            ],
            if (_canEditRepairOrder) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUpdating ? null : _saveData,
                  icon: _isUpdating
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded, size: 14),
                  label: const Text('LƯU', style: compactLabelStyle),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _printReceipt,
                icon: _isPrinting
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.print, color: Colors.white, size: 14),
                label: const Text(
                  'IN',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    height: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2962FF),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _shareToZalo,
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                label: const Text(
                  'ZALO',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    height: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Chia sẻ ảnh phiếu sửa (kèm QR chuyển khoản nếu còn nợ + đã cấu hình NH)
  // thay vì chỉ gửi text thuần như trước — mở màn xem trước rồi tự kích
  // hoạt chia sẻ ngay, người dùng vẫn có thể bấm lại nút Chia sẻ ảnh ở đó.
  Future<void> _shareToZalo() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RepairInvoicePreviewView(
          repair: r,
          shopInfo: {
            'shopName': _shopName,
            'shopAddr': _shopAddr,
            'shopPhone': _shopPhone,
          },
          autoShare: true,
        ),
      ),
    );
  }

  Future<void> _printReceipt() async {
    // Show printer selection dialog giống như in hóa đơn bán hàng
    final printerConfig = await showPrinterSelectionDialog(context);
    if (printerConfig == null) return; // User cancelled

    // Extract printer configuration
    final printerType = printerConfig['type'] as PrinterType?;
    final bluetoothPrinter =
        printerConfig['bluetoothPrinter'] as BluetoothPrinterConfig?;
    final wifiIp = printerConfig['wifiIp'] as String?;

    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    HapticFeedback.mediumImpact();
    NotificationService.showSnackBar(loc.preparingPrint, color: Colors.blue);

    try {
      final success = await UnifiedPrinterService.printRepairReceiptFromRepair(
        r,
        {'shopName': _shopName, 'shopAddr': _shopAddr, 'shopPhone': _shopPhone},
        printerType: printerType,
        bluetoothPrinter: bluetoothPrinter,
        wifiIp: wifiIp,
      );

      if (success) {
        NotificationService.showSnackBar(loc.printSuccess, color: Colors.green);
      } else {
        NotificationService.showSnackBar(loc.printFailed, color: Colors.red);
      }
    } catch (e) {
      NotificationService.showSnackBar(
        loc.printError(e.toString()),
        color: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }
}

/// Dialog widget riêng biệt để chọn linh kiện - tách ra để quản lý state đúng cách
class _PartsSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> parts;
  final Future<void> Function() onOpenPartsInventory;

  const _PartsSelectionDialog({
    required this.parts,
    required this.onOpenPartsInventory,
  });

  @override
  State<_PartsSelectionDialog> createState() => _PartsSelectionDialogState();
}

class _PartsSelectionDialogState extends State<_PartsSelectionDialog> {
  AppLocalizations get loc => AppLocalizations.of(context)!;
  final TextEditingController _searchCtrl = TextEditingController();
  final Map<String, int> selectedQuantities = {};

  int get totalSelected => selectedQuantities.values.fold(0, (a, b) => a + b);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _searchCtrl.text.trim().toLowerCase();
    final filteredParts = widget.parts.where((p) {
      if (keyword.isEmpty) return true;
      final name = (p['partName'] ?? '').toString().toLowerCase();
      final supplier = (p['supplier'] ?? p['supplierName'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(keyword) || supplier.contains(keyword);
    }).toList();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.inventory_2, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(loc.selectPartsTitle, style: AppTextStyles.headline3),
          ),
          // Shortcut to add new part from PartsInventoryView
          Material(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                await widget.onOpenPartsInventory();
                // Refresh parts list after returning from PartsInventoryView
                if (mounted) {
                  final db = DBHelper();
                  final updatedParts = await db.getAllPartsUnified();
                  if (mounted) {
                    setState(() {
                      widget.parts
                        ..clear()
                        ..addAll(updatedParts);
                    });
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle,
                      color: Colors.orange.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'NHẬP LK MỚI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 460,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: loc.searchPartOrSupplier,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filteredParts.isEmpty
                  ? Center(
                      child: Text(
                        loc.noPartsFound,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredParts.length,
                      itemBuilder: (context, index) {
                        final part = filteredParts[index];
                        final partId = part['id'] as int;
                        final source = part['source'] as String;
                        final uniqueKey = "${source}_$partId";
                        final partName = part['partName'] ?? '';
                        final partQty = part['quantity'] as int? ?? 0;
                        final partCost = part['cost'] as int? ?? 0;
                        final partPrice = part['price'] as int? ?? 0;
                        final supplier =
                            (part['supplier'] ?? part['supplierName'] ?? '')
                                .toString();
                        final isFromProducts = source == 'products';
                        final currentQty = selectedQuantities[uniqueKey] ?? 0;

                        return Card(
                          color: currentQty > 0
                              ? Colors.green.shade50
                              : (isFromProducts ? Colors.blue.shade50 : null),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Dòng 1: Icon + Tên + Tag nguồn
                                Row(
                                  children: [
                                    Icon(
                                      isFromProducts
                                          ? Icons.inventory
                                          : Icons.build,
                                      color: isFromProducts
                                          ? Colors.blue
                                          : Colors.blue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        partName,
                                        style: AppTextStyles.subtitle1.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isFromProducts
                                            ? Colors.blue.withOpacity(0.2)
                                            : Colors.blue.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isFromProducts
                                            ? loc.mainWarehouse
                                            : loc.oldWarehouse,
                                        style: AppTextStyles.caption.copyWith(
                                          color: isFromProducts
                                              ? Colors.blue
                                              : Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Dòng 2: Supplier + tồn + giá
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (supplier.isNotEmpty)
                                      Chip(
                                        label: Text(
                                          supplier,
                                          style: AppTextStyles.caption,
                                        ),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    Text(
                                      loc.stockQty(partQty),
                                      style: AppTextStyles.body2.copyWith(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    Text(
                                      loc.costPrice(
                                        MoneyUtils.formatCurrency(partCost),
                                      ),
                                      style: AppTextStyles.caption,
                                    ),
                                    Text(
                                      loc.sellPrice(
                                        MoneyUtils.formatCurrency(partPrice),
                                      ),
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Dòng 3: Nút +/- (compact hơn)
                                if (partQty > 0)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Nút trừ (nhỏ gọn hơn)
                                      Material(
                                        color: currentQty > 0
                                            ? Colors.red
                                            : Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(5),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                          onTap: currentQty > 0
                                              ? () {
                                                  setState(() {
                                                    if (currentQty <= 1) {
                                                      selectedQuantities.remove(
                                                        uniqueKey,
                                                      );
                                                    } else {
                                                      selectedQuantities[uniqueKey] =
                                                          currentQty - 1;
                                                    }
                                                  });
                                                }
                                              : null,
                                          child: Container(
                                            width: 26,
                                            height: 22,
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.remove,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Số lượng
                                      Container(
                                        width: 38,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$currentQty',
                                          style: AppTextStyles.caption.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: currentQty > 0
                                                ? Colors.green.shade700
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                      // Nút cộng (nhỏ gọn hơn)
                                      Material(
                                        color: currentQty < partQty
                                            ? Colors.green
                                            : Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(5),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                          onTap: currentQty < partQty
                                              ? () {
                                                  setState(() {
                                                    selectedQuantities[uniqueKey] =
                                                        currentQty + 1;
                                                  });
                                                }
                                              : null,
                                          child: Container(
                                            width: 26,
                                            height: 22,
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.add,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      loc.outOfStock,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(loc.cancel),
        ),
        ElevatedButton(
          onPressed: totalSelected > 0
              ? () => Navigator.pop(
                  context,
                  Map<String, int>.from(selectedQuantities),
                )
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          child: Text(
            totalSelected > 0 ? loc.confirmQty(totalSelected) : loc.confirmBtn,
            style: TextStyle(
              color: totalSelected > 0 ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}

/// Dialog chọn phương thức thanh toán cho phụ tùng
class _PartsPaymentDialog extends StatefulWidget {
  final int totalCost;
  final String partsDescription;

  const _PartsPaymentDialog({
    required this.totalCost,
    required this.partsDescription,
  });

  @override
  State<_PartsPaymentDialog> createState() => _PartsPaymentDialogState();
}

class _PartsPaymentDialogState extends State<_PartsPaymentDialog> {
  String _selectedMethod = 'TIỀN MẶT';
  final _supplierController = TextEditingController();

  AppLocalizations get loc => AppLocalizations.of(context)!;

  @override
  void dispose() {
    _supplierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.payment, color: Colors.green),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              loc.partsPaymentTitle,
              style: const TextStyle(fontSize: 17),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tổng tiền
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    loc.totalPartsAmount,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${MoneyUtils.formatCurrency(widget.totalCost)} đ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Mô tả phụ tùng
            Text(
              loc.partsDesc(widget.partsDescription),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Nhập tên nhà cung cấp
            TextField(
              controller: _supplierController,
              decoration: InputDecoration(
                labelText: loc.supplierOptional,
                hintText: loc.supplierHint,
                prefixIcon: const Icon(Icons.store, size: 20),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),

            // Chọn phương thức thanh toán
            Text(
              loc.paymentMethodLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),

            // Radio buttons
            _buildPaymentOption('TIỀN MẶT', Icons.money, Colors.green),
            _buildPaymentOption(
              'CHUYỂN KHOẢN',
              Icons.account_balance,
              Colors.blue,
            ),
            _buildPaymentOption('CÔNG NỢ', Icons.access_time, Colors.orange),

            if (_selectedMethod == 'CHUYỂN KHOẢN')
              bankTransferAssistCard(
                amount: widget.totalCost,
                direction: BankPayDirection.outbound,
                counterpartyName: _supplierController.text.trim().isEmpty
                    ? null
                    : _supplierController.text.trim(),
                refText: 'Tien linh kien',
              ),

            // Cảnh báo nếu chọn công nợ
            if (_selectedMethod == 'CÔNG NỢ')
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc.debtWarning,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(loc.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'method': _selectedMethod,
              'supplier': _supplierController.text.trim().isEmpty
                  ? loc.defaultPartsSupplier
                  : _supplierController.text.trim().toUpperCase(),
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedMethod == 'CÔNG NỢ'
                ? Colors.orange
                : Colors.green,
          ),
          child: Text(
            _selectedMethod == 'CÔNG NỢ' ? loc.recordDebt : loc.confirm,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOption(String method, IconData icon, Color color) {
    final isSelected = _selectedMethod == method;
    return InkWell(
      onTap: () => setState(() => _selectedMethod = method),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
            const SizedBox(width: 10),
            Text(
              method,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.black87,
              ),
            ),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
