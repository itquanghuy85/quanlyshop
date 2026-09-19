import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which kind of session the app is currently running in.
enum AppSessionMode {
  /// No Firebase user and no local (offline) shop → login / welcome screen.
  none,

  /// No Firebase user, data lives only in SQLite under a locally generated
  /// shopId. Nothing touches Firebase in this mode.
  offline,

  /// A Firebase user is signed in. This is the historical behaviour of the app
  /// and MUST stay byte-for-byte identical for existing Play Store users.
  online,
}

/// Single source of truth for "who is using the app and which shop".
///
/// Business modules keep calling `UserService.getShopIdSync()` etc.; those
/// functions consult [AppSession] first so the rest of the code base does not
/// need to know whether the user is signed in.
///
/// Priority inside UserService:
///   super admin (selected shop) > AppSession.offline > cached uid → shopId
///
/// See DOCS/PLAN_OFFLINE_FIRST_2026-09-19.md.
class AppSession {
  AppSession._();

  /// Feature flag (decision D5). Steps 1–2 of the plan ship with this OFF so
  /// nothing changes for anyone; step 3 turns it on.
  static const bool kOfflineModeEnabled = true;

  /// Pseudo user id written into `createdBy` / `userId` columns while offline.
  /// Replaced by the real uid when the local shop is claimed by an account.
  static const String localOwnerUid = 'local_owner';

  static const String _prefMode = 'app_session_mode';
  static const String _prefShopId = 'app_session_shop_id';
  static const String _prefShopName = 'app_session_shop_name';
  static const String _prefShopAddress = 'app_session_shop_address';
  static const String _prefShopPhone = 'app_session_shop_phone';
  static const String _prefCreatedAt = 'app_session_created_at';

  static const String defaultOfflineShopName = 'Cửa hàng của tôi';

  static String? _offlineShopId;
  static String? _offlineShopName;
  static String? _offlineShopAddress;
  static String? _offlineShopPhone;
  static bool _restored = false;

  /// Bumped whenever the session shape changes without a Firebase auth event
  /// (start offline, clear offline, claim). AuthGate rebuilds on it.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// True while a local shop is being attached to an account (step 4).
  /// While set, the app must behave as offline for data purposes and must
  /// never wipe SQLite.
  static bool claimInProgress = false;

  /// Prefs keys shared with `main.dart` `_checkAndClearLocalDataIfShopChanged`.
  static const String prefLastSyncedShopId = 'last_synced_shop_id';
  static const String prefLastSyncedUserId = 'last_synced_user_id';

  /// Test-only: pretend there is no Firebase user even if one exists.
  @visibleForTesting
  static bool debugIgnoreFirebaseUser = false;

  /// Test-only: exercise offline mode while [kOfflineModeEnabled] is still off.
  @visibleForTesting
  static bool debugForceOfflineFlag = false;

  static bool get _offlineFlagOn =>
      kOfflineModeEnabled || debugForceOfflineFlag;

  static bool get isRestored => _restored;

  /// Locally generated shop id (null when the device never started offline).
  static String? get offlineShopId => _offlineShopId;
  static String? get offlineShopName => _offlineShopName;
  static String? get offlineShopAddress => _offlineShopAddress;
  static String? get offlineShopPhone => _offlineShopPhone;

  static AppSessionMode get mode {
    if (_hasFirebaseUser && !claimInProgress) return AppSessionMode.online;
    if (_offlineFlagOn &&
        _offlineShopId != null &&
        _offlineShopId!.isNotEmpty) {
      return AppSessionMode.offline;
    }
    return AppSessionMode.none;
  }

  static bool get isOffline => mode == AppSessionMode.offline;
  static bool get isOnline => mode == AppSessionMode.online;

  /// Whether any code path may talk to Firebase (Firestore/Storage/FCM/...).
  /// Offline and `none` sessions never do.
  static bool get syncEnabled => isOnline;

  /// Offline mode is only offered on mobile (decision D2).
  static bool get offlineModeAvailable => kOfflineModeEnabled && !kIsWeb;

  /// Whether [shopId] is the shop this device created offline. Used to decide
  /// if a logout may keep SQLite (drop back to offline) or must wipe it.
  static bool ownsShop(String? shopId) =>
      shopId != null && shopId.isNotEmpty && shopId == _offlineShopId;

  /// Effective shopId for the offline session, null otherwise. UserService
  /// falls through to its normal uid-based logic when this is null.
  static String? get shopId => isOffline ? _offlineShopId : null;

  /// Effective user id: Firebase uid when online, [localOwnerUid] offline.
  static String? get userId {
    if (isOffline) return localOwnerUid;
    return _firebaseUser?.uid;
  }

  static String? get userEmail => isOffline ? null : _firebaseUser?.email;

  /// Short display name of whoever is acting right now — the email prefix
  /// online, the owner label offline. Replaces the scattered
  /// `currentUser?.email?.split('@').first.toUpperCase() ?? "NV"` so offline
  /// records don't all read "NV".
  static const String offlineActorName = 'CHỦ SHOP';
  static String get actorName {
    if (isOffline) return offlineActorName;
    final email = _firebaseUser?.email;
    if (email == null || email.isEmpty) return 'NV';
    return email.split('@').first.toUpperCase();
  }

  static User? get _firebaseUser {
    if (debugIgnoreFirebaseUser) return null;
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      // Firebase not initialised (unit tests / very early bootstrap).
      return null;
    }
  }

  static bool get _hasFirebaseUser => _firebaseUser != null;

  /// Load persisted offline session (if any). Safe to call before Firebase
  /// initialises — it only reads SharedPreferences.
  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString(_prefMode);
      if (mode == 'offline') {
        final id = prefs.getString(_prefShopId);
        if (id != null && id.isNotEmpty) {
          _offlineShopId = id;
          _offlineShopName = prefs.getString(_prefShopName);
          _offlineShopAddress = prefs.getString(_prefShopAddress);
          _offlineShopPhone = prefs.getString(_prefShopPhone);
        }
      }
    } catch (e) {
      debugPrint('AppSession.restore failed: $e');
    } finally {
      _restored = true;
    }
    // NOTE: `mode` is not printed here — Firebase is usually not initialised
    // yet at this point, so it would always read `none`.
    debugPrint(
      'AppSession.restore: offlineShopId=$_offlineShopId '
      'flag=$kOfflineModeEnabled',
    );
  }

  /// Start (or resume) an offline session. Generates a shop id on first use.
  /// Returns the effective offline shop id.
  static Future<String> startOffline({String? shopName, String? shopId}) async {
    final id = shopId ?? _offlineShopId ?? generateShopId();
    final name = shopName ?? _offlineShopName ?? defaultOfflineShopName;
    _offlineShopId = id;
    _offlineShopName = name;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefMode, 'offline');
      await prefs.setString(_prefShopId, id);
      await prefs.setString(_prefShopName, name);
      if (!prefs.containsKey(_prefCreatedAt)) {
        await prefs.setString(_prefCreatedAt, DateTime.now().toIso8601String());
      }
      // Mark this shop as the one SQLite currently holds so a later claim /
      // login into the same shop never triggers the "shop changed → wipe"
      // logic in main.dart.
      await prefs.setString(prefLastSyncedShopId, id);
      await prefs.setString(prefLastSyncedUserId, localOwnerUid);
      // Receipts / print header read these keys (written by SyncService
      // from the cloud shop doc). A device that previously held another
      // shop would otherwise print that shop's name on offline invoices.
      await prefs.setString('shop_name', name);
      await prefs.remove('shop_address');
      await prefs.remove('shop_phone');
    } catch (e) {
      debugPrint('AppSession.startOffline: persist failed: $e');
    }
    debugPrint('AppSession.startOffline: shopId=$id');
    revision.value++;
    return id;
  }

  /// Claim into an existing (empty) cloud shop: local rows were re-tagged to
  /// [newShopId]; keep `ownsShop` true for that id so a later sign-out drops
  /// back to offline instead of wiping.
  static Future<void> rebindOfflineShopId(String newShopId) async {
    _offlineShopId = newShopId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefShopId, newShopId);
      await prefs.setString(prefLastSyncedShopId, newShopId);
    } catch (_) {}
    revision.value++;
  }

  /// Rename the offline shop (shown in the header / Welcome).
  static Future<void> setOfflineShopName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _offlineShopName = trimmed;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefShopName, trimmed);
      await prefs.setString('shop_name', trimmed);
    } catch (_) {}
    revision.value++;
  }

  /// Address / phone printed on offline receipts (`shop_address` /
  /// `shop_phone` are the keys the receipt views read; online they are
  /// written by SyncService from the cloud shop doc).
  static Future<void> setOfflineShopContact({
    required String address,
    required String phone,
  }) async {
    _offlineShopAddress = address.trim();
    _offlineShopPhone = phone.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefShopAddress, _offlineShopAddress!);
      await prefs.setString(_prefShopPhone, _offlineShopPhone!);
      await prefs.setString('shop_address', _offlineShopAddress!);
      await prefs.setString('shop_phone', _offlineShopPhone!);
    } catch (_) {}
    revision.value++;
  }

  /// Forget the offline session (does NOT touch SQLite — callers decide that).
  static Future<void> clearOffline() async {
    _offlineShopId = null;
    _offlineShopName = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefMode);
      await prefs.remove(_prefShopId);
      await prefs.remove(_prefShopName);
      await prefs.remove(_prefCreatedAt);
    } catch (e) {
      debugPrint('AppSession.clearOffline: persist failed: $e');
    }
    revision.value++;
  }

  /// Same shape as other local ids in the app (`rep_<ms>_<rand>`), no extra
  /// dependency needed (decision D6).
  static String generateShopId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rand = Random.secure().nextInt(1 << 30);
    return 'shop_${ms}_${rand.toRadixString(36)}';
  }

  /// Test-only reset.
  @visibleForTesting
  static void debugReset() {
    _offlineShopId = null;
    _offlineShopName = null;
    _restored = false;
    claimInProgress = false;
    debugIgnoreFirebaseUser = false;
    debugForceOfflineFlag = false;
  }
}
