import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/db_helper.dart';
import 'app_session.dart';
import 'current_shop_service.dart';
import 'encryption_service.dart';
import 'sync_service.dart';
import 'user_service.dart';

/// Single place that performs "sign out" for the whole app.
///
/// Historically `HomeView` had two copies of this sequence (app-bar button and
/// Settings tab). Both now call [SessionLogoutService.signOut] so the
/// offline-first rule below is applied consistently.
///
/// Rule (PLAN_OFFLINE_FIRST step 3): SQLite is wiped on sign-out EXCEPT when
/// the signed-in shop is the one this device created offline
/// (`AppSession.ownsShop`). In that case the device simply drops back to the
/// offline session with its data intact. A staff member signing out of a
/// cloud-only shop therefore never gets offline-owner access to that data.
class SessionLogoutService {
  SessionLogoutService._();

  /// Returns true when local data was kept (device is now offline).
  static Future<bool> signOut() async {
    final shopId = UserService.getShopIdSync();
    final keepLocal =
        AppSession.offlineModeAvailable && AppSession.ownsShop(shopId);
    debugPrint(
      '🚪 SessionLogoutService.signOut: shopId=$shopId keepLocal=$keepLocal',
    );

    // Always sign out — cleanup failures must not block logout.
    try {
      await SyncService.cancelAllSubscriptions();
    } catch (_) {}
    try {
      EncryptionService.reset();
    } catch (_) {}
    try {
      UserService.clearCache();
    } catch (_) {}
    try {
      CurrentShopService().clear();
    } catch (_) {}
    try {
      UserService.setAdminSelectedShop(null);
    } catch (_) {}
    if (!keepLocal) {
      try {
        await DBHelper().clearAllData();
        // Bắt buộc đi kèm: xem ghi chú ở `main.dart` / [2026-09-06d].
        await SyncService.resetSyncTimestamps();
      } catch (_) {}
    }
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('SessionLogoutService: signOut error $e');
    }
    AppSession.revision.value++;
    return keepLocal;
  }
}
