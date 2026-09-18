// Step 1 of DOCS/PLAN_OFFLINE_FIRST_2026-09-19.md.
//
// These tests run WITHOUT Firebase initialised on purpose: any code path that
// touches the Firebase SDK throws `[core/no-app]`, so a passing test proves the
// offline branch returns before the SDK is reached.
import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/services/app_session.dart';
import 'package:quanlyshop/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppSession.debugReset();
    AppSession.debugIgnoreFirebaseUser = true;
  });

  tearDown(AppSession.debugReset);

  group('AppSession.restore', () {
    test('empty prefs → mode none, shopId null', () async {
      SharedPreferences.setMockInitialValues({});
      await AppSession.restore();
      expect(AppSession.isRestored, isTrue);
      expect(AppSession.mode, AppSessionMode.none);
      expect(AppSession.shopId, isNull);
      expect(AppSession.syncEnabled, isFalse);
    });

    test('prefs offline but feature flag OFF → still mode none', () async {
      SharedPreferences.setMockInitialValues({
        'app_session_mode': 'offline',
        'app_session_shop_id': 'shop_1_abc',
      });
      await AppSession.restore();
      expect(AppSession.offlineShopId, 'shop_1_abc');
      // kOfflineModeEnabled is const false in step 1–2.
      expect(
        AppSession.mode,
        AppSession.kOfflineModeEnabled
            ? AppSessionMode.offline
            : AppSessionMode.none,
      );
    });

    test('prefs offline + flag ON → mode offline', () async {
      SharedPreferences.setMockInitialValues({
        'app_session_mode': 'offline',
        'app_session_shop_id': 'shop_1_abc',
        'app_session_shop_name': 'Tiệm A',
      });
      AppSession.debugForceOfflineFlag = true;
      await AppSession.restore();
      expect(AppSession.mode, AppSessionMode.offline);
      expect(AppSession.shopId, 'shop_1_abc');
      expect(AppSession.offlineShopName, 'Tiệm A');
      expect(AppSession.userId, AppSession.localOwnerUid);
      expect(AppSession.userEmail, isNull);
      expect(AppSession.syncEnabled, isFalse);
    });
  });

  group('AppSession.startOffline / clearOffline', () {
    test('generates and persists a shop id once', () async {
      SharedPreferences.setMockInitialValues({});
      AppSession.debugForceOfflineFlag = true;
      final id = await AppSession.startOffline();
      expect(id, startsWith('shop_'));
      expect(AppSession.isOffline, isTrue);

      // Second call keeps the same id.
      final again = await AppSession.startOffline();
      expect(again, id);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_session_mode'), 'offline');
      expect(prefs.getString('app_session_shop_id'), id);
      expect(
        prefs.getString('app_session_shop_name'),
        AppSession.defaultOfflineShopName,
      );
      expect(prefs.getString('app_session_created_at'), isNotNull);

      await AppSession.clearOffline();
      expect(AppSession.mode, AppSessionMode.none);
      expect(prefs.getString('app_session_shop_id'), isNull);
    });

    test('generateShopId is unique', () {
      final ids = {for (var i = 0; i < 200; i++) AppSession.generateShopId()};
      expect(ids.length, 200);
    });
  });

  group('UserService in offline session (no Firebase)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AppSession.debugForceOfflineFlag = true;
      await AppSession.startOffline(shopName: 'Tiệm B');
    });

    test('shopId helpers return the local shop id', () async {
      final id = AppSession.shopId!;
      expect(UserService.getShopIdSync(), id);
      expect(await UserService.getCurrentShopId(), id);
      expect(await UserService.ensureShopId(maxRetries: 1), id);
      expect(await UserService.getShopIdFast(), id);
      expect(UserService.isShopIdReady(), isTrue);
    });

    test('device owner has full owner permissions incl. cost price', () async {
      final sync = UserService.getCurrentUserPermissionsSync()!;
      expect(sync['role'], 'owner');
      expect(sync['isManagerLike'], isTrue);
      expect(sync['allowViewCostPrice'], isTrue);
      expect(sync['allowViewRevenue'], isTrue);
      expect(sync['allowViewDebts'], isTrue);

      final async = await UserService.getCurrentUserPermissions();
      expect(async['role'], 'owner');
      expect(await UserService.canViewCostPrice(), isTrue);
      expect(await UserService.isCurrentUserAdmin(), isTrue);
      expect(await UserService.getRoleFast(), 'owner');
      expect(await UserService.getUserRole(AppSession.localOwnerUid), 'owner');
      expect(await UserService.getCurrentUserName(), 'Tiệm B');
    });
  });

  group('UserService with no session at all (mode none)', () {
    test('behaves like the historical signed-out state', () async {
      SharedPreferences.setMockInitialValues({});
      // No offline shop, no Firebase user.
      expect(AppSession.mode, AppSessionMode.none);
      expect(AppSession.shopId, isNull);
      expect(AppSession.userId, isNull);
      expect(AppSession.syncEnabled, isFalse);
      // UserService itself falls through to FirebaseAuth here (historical
      // path) — not exercisable without Firebase, covered by adb regression.
    });
  });
}
