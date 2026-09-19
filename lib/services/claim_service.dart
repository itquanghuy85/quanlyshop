import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db_helper.dart';
import 'app_session.dart';
import 'event_bus.dart';
import 'offline_stock_entry_store.dart';
import 'sync_orchestrator.dart';
import 'sync_service.dart';
import 'user_service.dart';

/// Which situation the signed-in account is in when the user connects it to
/// the offline shop (PLAN_OFFLINE_FIRST step 4/5).
enum ClaimCase {
  /// Account has no shop yet → the offline shop becomes its shop (same id).
  newAccount,

  /// Account already belongs to a shop on the cloud.
  existingShop,
}

class ClaimPrecheck {
  final ClaimCase kind;
  final String? cloudShopId;
  final String? cloudShopName;

  /// Only meaningful for [ClaimCase.existingShop]: true when the cloud shop
  /// holds no products / sales / repairs, so local data may be re-tagged into
  /// it without merging anything (decision D4).
  final bool cloudShopEmpty;

  const ClaimPrecheck({
    required this.kind,
    this.cloudShopId,
    this.cloudShopName,
    this.cloudShopEmpty = false,
  });
}

typedef ClaimStep = void Function(String message);

/// Attaches the offline shop (SQLite) to a Firebase account.
///
/// This is the ONLY place allowed to talk to Firestore while
/// `AppSession.claimInProgress` is set (every other service is gated by
/// `AppSession.syncEnabled`). Nothing here ever wipes SQLite except
/// [replaceLocalWithCloud], which the user must pick explicitly.
class ClaimService {
  ClaimService._();

  static FirebaseFirestore get _fs => FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Precheck
  // ---------------------------------------------------------------------------
  static Future<ClaimPrecheck> precheck(User user) async {
    String? cloudShopId;
    String? cloudShopName;

    final userDoc = await _fs.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? const {};
    final fromUser = (userData['shopId'] ?? '').toString().trim();
    if (fromUser.isNotEmpty) cloudShopId = fromUser;

    if (cloudShopId == null) {
      // Owner of a shop without users.shopId (legacy accounts).
      final owned = await _fs
          .collection('shops')
          .where('ownerUid', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (owned.docs.isNotEmpty) cloudShopId = owned.docs.first.id;
    }

    if (cloudShopId == null || cloudShopId == AppSession.offlineShopId) {
      return const ClaimPrecheck(kind: ClaimCase.newAccount);
    }

    try {
      final shopDoc = await _fs.collection('shops').doc(cloudShopId).get();
      cloudShopName = (shopDoc.data()?['name'] ?? '').toString();
    } catch (_) {}

    var empty = true;
    for (final coll in const ['products', 'sales', 'repairs']) {
      final snap = await _fs
          .collection(coll)
          .where('shopId', isEqualTo: cloudShopId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        empty = false;
        break;
      }
    }
    return ClaimPrecheck(
      kind: ClaimCase.existingShop,
      cloudShopId: cloudShopId,
      cloudShopName: cloudShopName,
      cloudShopEmpty: empty,
    );
  }

  // ---------------------------------------------------------------------------
  // Case A — new account: the offline shopId becomes the cloud shopId.
  // ---------------------------------------------------------------------------
  static Future<void> claimToNewAccount(User user, {ClaimStep? onStep}) async {
    final shopId = AppSession.offlineShopId;
    if (shopId == null || shopId.isEmpty) {
      throw StateError('Không có cửa hàng offline để kết nối');
    }
    final shopName =
        AppSession.offlineShopName ?? AppSession.defaultOfflineShopName;
    final email = user.email ?? '';

    onStep?.call('Tạo cửa hàng trên đám mây…');
    // Same payload `UserService.syncUserInfo` writes for a brand-new shop —
    // only the id is ours instead of `uid`.
    await _fs.collection('shops').doc(shopId).set({
      'shopId': shopId,
      'ownerUid': user.uid,
      'ownerEmail': email,
      'name': shopName,
      'businessType': 'electronics',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    try {
      await _fs
          .collection('shops')
          .doc(shopId)
          .collection('settings')
          .doc('shop_settings')
          .set({
            'shopId': shopId,
            'businessType': 'electronics',
            'businessTypeName': 'Điện thoại & Điện tử',
            'enableRepair': true,
            'enableSerial': true,
            'enableWarranty': true,
            'enableExpiry': false,
            'enableVariants': false,
            'enableBatch': false,
            'defaultUnit': 'cái',
            'expiryWarningDays': 7,
            'lowStockWarning': 5,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ claim: shop_settings create failed: $e');
    }

    onStep?.call('Gắn tài khoản vào cửa hàng…');
    final emailPrefix = email.split('@').first;
    await _fs.collection('users').doc(user.uid).set({
      'email': email,
      'displayName': user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (emailPrefix.isNotEmpty
                ? emailPrefix[0].toUpperCase() + emailPrefix.substring(1)
                : ''),
      'role': 'owner',
      'shopId': shopId,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _finishAttach(user, shopId: shopId, onStep: onStep);
  }

  // ---------------------------------------------------------------------------
  // Case B1 — existing but EMPTY cloud shop: re-tag local rows into it.
  // ---------------------------------------------------------------------------
  static Future<void> attachToExistingEmptyShop(
    User user,
    String cloudShopId, {
    ClaimStep? onStep,
  }) async {
    final localShopId = AppSession.offlineShopId;
    if (localShopId == null) {
      throw StateError('Không có cửa hàng offline để kết nối');
    }
    onStep?.call('Đổi mã cửa hàng trên máy…');
    await retagShopId(from: localShopId, to: cloudShopId);
    await AppSession.rebindOfflineShopId(cloudShopId);
    await OfflineStockEntryStore.retagShopId(
      from: localShopId,
      to: cloudShopId,
    );
    await _finishAttach(user, shopId: cloudShopId, onStep: onStep);
  }

  // ---------------------------------------------------------------------------
  // Case B2 — keep the cloud, drop local (user confirmed a backup).
  // ---------------------------------------------------------------------------
  static Future<void> replaceLocalWithCloud(
    User user, {
    ClaimStep? onStep,
  }) async {
    onStep?.call('Xoá dữ liệu trên máy…');
    await OfflineStockEntryStore.clear();
    await AppSession.clearOffline();
    await DBHelper().clearAllData();
    await SyncService.resetSyncTimestamps();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppSession.prefLastSyncedShopId);
    await prefs.remove(AppSession.prefLastSyncedUserId);
    UserService.clearCache();
    AppSession.claimInProgress = false;
    AppSession.revision.value++;
    // AuthGate now runs the normal online bootstrap, which downloads the shop.
  }

  /// Abort: sign out and stay offline with everything untouched.
  static Future<void> abort() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    AppSession.claimInProgress = false;
    AppSession.revision.value++;
  }

  // ---------------------------------------------------------------------------
  // Shared tail: session flip + initial upload.
  // ---------------------------------------------------------------------------
  static Future<void> _finishAttach(
    User user, {
    required String shopId,
    ClaimStep? onStep,
  }) async {
    onStep?.call('Cập nhật quyền tài khoản…');
    // `syncUserClaims` (Cloud Function) copies users/{uid}.shopId into the
    // token a few seconds after the doc is written. Uploading before that
    // hits `permission-denied` on every write, so wait (bounded) for it.
    await _waitForShopClaim(user, shopId);

    // Never let main.dart treat this as "shop changed → wipe".
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppSession.prefLastSyncedShopId, shopId);
    await prefs.setString(AppSession.prefLastSyncedUserId, user.uid);
    await prefs.setString('lastUserId', user.uid); // HomeView._initialSetup

    onStep?.call('Gán người tạo cho dữ liệu cũ…');
    await retagLocalOwner(user.uid);

    UserService.clearCache();
    UserService.updateCachedShopId(shopId);
    await UserService.saveAuthCache(role: 'owner', forUid: user.uid);

    // Flip to the online session — from here every service may use the cloud.
    AppSession.claimInProgress = false;
    AppSession.revision.value++;
    EventBus().emit(EventBus.shopChanged);

    onStep?.call('Đưa phiếu nhập kho lên đám mây…');
    await _pushOfflineStockEntries(shopId);

    onStep?.call('Đưa dữ liệu lên đám mây (có thể mất vài phút)…');
    await SyncService.syncAllToCloud(force: true);
    try {
      await SyncOrchestrator().syncAll();
    } catch (e) {
      debugPrint('⚠️ claim: orchestrator syncAll failed: $e');
    }
    // Second pass picks up rows whose first push failed transiently.
    await SyncService.syncAllToCloud(force: true);

    onStep?.call('Hoàn tất');
    debugPrint('✅ claim: shop $shopId attached to ${user.uid}');
  }

  static Future<void> _waitForShopClaim(User user, String shopId) async {
    const attempts = 12; // ~24 s
    for (var i = 0; i < attempts; i++) {
      try {
        final result = await user.getIdTokenResult(true);
        final claimShop = (result.claims?['shopId'] ?? '').toString();
        if (claimShop == shopId) {
          debugPrint('🔑 claim: token has shopId after ${i + 1} attempt(s)');
          return;
        }
      } catch (e) {
        debugPrint('⚠️ claim: getIdTokenResult failed: $e');
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    debugPrint('⚠️ claim: token still without shopId — continuing anyway');
  }

  /// `createdBy` / `*Uid` / `userId` columns hold [AppSession.localOwnerUid]
  /// for rows written offline. Point them at the real uid (decision D3).
  /// Public for tests.
  static Future<int> retagLocalOwner(String uid) async {
    final db = await DBHelper().database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
    );
    var changed = 0;
    for (final t in tables) {
      final table = t['name'] as String;
      final cols = await db.rawQuery('PRAGMA table_info($table)');
      for (final c in cols) {
        final name = (c['name'] ?? '').toString();
        final type = (c['type'] ?? '').toString().toUpperCase();
        final isUidCol =
            name == 'createdBy' ||
            name == 'userId' ||
            name == 'confirmedBy' ||
            name.endsWith('Uid');
        if (!isUidCol || !type.contains('TEXT')) continue;
        try {
          changed += await db.update(
            table,
            {name: uid},
            where: '$name = ?',
            whereArgs: [AppSession.localOwnerUid],
          );
        } catch (e) {
          debugPrint('⚠️ retagLocalOwner $table.$name: $e');
        }
      }
    }
    debugPrint('🔁 claim: retagged $changed local_owner cells → $uid');
    return changed;
  }

  /// Public for tests (case B1 has no cheap device scenario).
  static Future<int> retagShopId({
    required String from,
    required String to,
  }) async {
    final db = await DBHelper().database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
    );
    var changed = 0;
    for (final t in tables) {
      final table = t['name'] as String;
      final cols = await db.rawQuery('PRAGMA table_info($table)');
      if (!cols.any((c) => c['name'] == 'shopId')) continue;
      final hasSynced = cols.any((c) => c['name'] == 'isSynced');
      try {
        // OR REPLACE: tables such as `customers` carry UNIQUE(shopId, phone).
        // A leftover row of the target shop with the same key would block the
        // whole UPDATE; the local row is the one the user is moving up, so it
        // wins. Rows move to a DIFFERENT cloud shop, so whatever was synced
        // before (e.g. an earlier claim) must be pushed again: isSynced = 0.
        changed += await db.rawUpdate(
          hasSynced
              ? 'UPDATE OR REPLACE $table SET shopId = ?, isSynced = 0 WHERE shopId = ?'
              : 'UPDATE OR REPLACE $table SET shopId = ? WHERE shopId = ?',
          [to, from],
        );
      } catch (e) {
        debugPrint('⚠️ retagShopId $table: $e');
      }
    }
    debugPrint('🔁 claim: retagged $changed rows shopId $from → $to');
    return changed;
  }

  /// `stock_entries` has no SQLite table; offline entries live in
  /// [OfflineStockEntryStore]. Push them so "Hàng chờ xác nhận" and the
  /// import history stay complete on every device.
  static Future<void> _pushOfflineStockEntries(String shopId) async {
    final all = await OfflineStockEntryStore.where((_) => true);
    for (final e in all) {
      final id = e.firestoreId;
      if (id == null) continue;
      try {
        final map = e.toMap();
        map['shopId'] = shopId;
        await _fs
            .collection('stock_entries')
            .doc(id)
            .set(map, SetOptions(merge: true));
        await OfflineStockEntryStore.remove(id);
      } catch (err) {
        debugPrint('⚠️ claim: push stock entry $id failed: $err');
      }
    }
  }
}
