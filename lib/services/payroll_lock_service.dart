import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/db_helper.dart';
import 'app_session.dart';
import 'cloud_write_policy.dart';
import 'user_service.dart';

/// Shop-wide payroll month lock.
///
/// Source of truth: `shops/{shopId}/settings/payroll_locks`
/// (`months.{yyyy-MM} = {locked, lockedBy, lockedAt}`) so a lock set on one
/// device blocks edits on every device. The SQLite `payroll_locks` table is
/// only a per-device cache, keyed `shopId|yyyy-MM` because the table has no
/// shopId column and `monthKey` is UNIQUE.
class PayrollLockService {
  static const String settingsDocId = 'payroll_locks';
  static const Duration _cloudReadTimeout = Duration(seconds: 6);

  static FirebaseFirestore get _fs => FirebaseFirestore.instance;

  static String monthKeyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  static String monthKeyFromDateKey(String dateKey) =>
      dateKey.length >= 7 ? dateKey.substring(0, 7) : dateKey;

  @visibleForTesting
  static String cacheKey(String? shopId, String monthKey) =>
      (shopId == null || shopId.isEmpty) ? monthKey : '$shopId|$monthKey';

  /// Owner-only: matches the Firestore rule on `settings/*` writes.
  static Future<bool> canManageLocks() async {
    if (AppSession.isOffline) return true;
    final uid = AppSession.userId;
    if (uid == null) return false;
    final role = await UserService.getUserRole(uid);
    return role == 'owner';
  }

  /// Pulls the shop's lock map into the local cache. Returns false when the
  /// cloud could not be read (caller falls back to the cached value).
  static Future<bool> refreshFromCloud() async {
    if (!AppSession.syncEnabled) return false;
    final shopId = await UserService.getCurrentShopId();
    if (shopId == null || shopId.isEmpty) return false;
    try {
      final snap = await _fs
          .collection('shops')
          .doc(shopId)
          .collection('settings')
          .doc(settingsDocId)
          .get()
          .timeout(_cloudReadTimeout);
      final months = (snap.data()?['months'] as Map?) ?? const {};
      for (final entry in months.entries) {
        final v = entry.value;
        if (v is! Map) continue;
        await DBHelper().setPayrollMonthLock(
          cacheKey(shopId, entry.key.toString()),
          locked: v['locked'] == true,
          lockedBy: v['lockedBy']?.toString(),
          note: 'cloud',
        );
      }
      return true;
    } catch (e) {
      debugPrint('PayrollLockService.refreshFromCloud: $e');
      return false;
    }
  }

  /// Cached value only — no network. Used by UI badges.
  static Future<bool> isMonthLockedCached(String monthKey) async {
    final shopId = UserService.getShopIdSync();
    return DBHelper().isPayrollMonthLocked(cacheKey(shopId, monthKey));
  }

  /// Checks the cloud first when online so a lock set on another device is
  /// honoured immediately; falls back to the cache when offline.
  static Future<bool> isMonthLocked(String monthKey) async {
    await refreshFromCloud();
    return isMonthLockedCached(monthKey);
  }

  static Future<bool> isLockedForDateKey(String dateKey) =>
      isMonthLocked(monthKeyFromDateKey(dateKey));

  /// Online: writes the cloud first and only caches after the write
  /// succeeded, so devices never disagree. Throws on failure
  /// (CloudOfflineException / FirebaseException).
  static Future<void> setMonthLock(String monthKey, {required bool locked}) async {
    final shopId = await UserService.getCurrentShopId();
    final actor = AppSession.actorName;
    if (AppSession.syncEnabled) {
      if (shopId == null || shopId.isEmpty) {
        throw StateError('Không xác định được cửa hàng');
      }
      await CloudWritePolicy.guard(
        () => _fs
            .collection('shops')
            .doc(shopId)
            .collection('settings')
            .doc(settingsDocId)
            .set({
          'months': {
            monthKey: {
              'locked': locked,
              'lockedBy': actor,
              'lockedAt': DateTime.now().millisecondsSinceEpoch,
            },
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
        context: 'settings',
        bump: false,
      );
    }
    await DBHelper().setPayrollMonthLock(
      cacheKey(shopId, monthKey),
      locked: locked,
      lockedBy: actor,
      note: AppSession.syncEnabled ? 'cloud' : 'offline',
    );
  }
}
