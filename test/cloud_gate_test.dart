// Step 2 of DOCS/PLAN_OFFLINE_FIRST_2026-09-19.md — cloud gate.
//
// Firebase is deliberately NOT initialised here. Touching any Firebase SDK
// entry point throws `[core/no-app]`, so every call below passing proves the
// `AppSession.syncEnabled` guard runs before the SDK is reached.
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quanlyshop/models/repair_model.dart';
import 'package:quanlyshop/services/app_session.dart';
import 'package:quanlyshop/services/background_upload_service.dart';
import 'package:quanlyshop/services/chat_service.dart';
import 'package:quanlyshop/services/claims_service.dart';
import 'package:quanlyshop/services/community_service.dart';
import 'package:quanlyshop/services/current_shop_service.dart';
import 'package:quanlyshop/services/firestore_service.dart';
import 'package:quanlyshop/services/notification_service.dart';
import 'package:quanlyshop/services/storage_service.dart';
import 'package:quanlyshop/services/sync_health_check.dart';
import 'package:quanlyshop/services/sync_orchestrator.dart';
import 'package:quanlyshop/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppSession.debugReset();
    AppSession.debugIgnoreFirebaseUser = true;
    AppSession.debugForceOfflineFlag = true;
    await AppSession.startOffline(shopName: 'Offline test');
    expect(AppSession.syncEnabled, isFalse);
  });

  tearDown(AppSession.debugReset);

  group(
    'FirestoreService returns neutral values without touching Firebase',
    () {
      test('write paths', () async {
        final r = Repair(
          customerName: 'A',
          phone: '0900000000',
          model: 'X',
          issue: 'Y',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          firestoreId: 'rep_test_1',
        );
        expect(await FirestoreService.addRepair(r), isNull);
        await FirestoreService.upsertRepair(r);
        await FirestoreService.deleteRepair('rep_test_1');
        await FirestoreService.upsertRepairPatchByFirestoreId('rep_test_1', {});
      });

      test('read paths', () async {
        expect(await FirestoreService.getShopStaffList('shop_x'), isEmpty);
        expect(
          await FirestoreService.getCashClosingFromCloud('2026-09-19'),
          isNull,
        );
        expect(await FirestoreService.getStaffByShopId('shop_x'), isNull);
      });

      test('streams are empty', () async {
        expect(await FirestoreService.getUnreadCount().toList(), isEmpty);
        expect(
          await FirestoreService.watchRepairDoc('rep_test_1').toList(),
          isEmpty,
        );
      });

      test('DocumentSnapshot getters throw CloudDisabledException, not '
          '[core/no-app]', () async {
        expect(
          () => FirestoreService.getRepairDoc('rep_test_1'),
          throwsA(isA<CloudDisabledException>()),
        );
      });
    },
  );

  group('SyncService / SyncOrchestrator / SyncHealthCheck', () {
    test('entry points are no-ops', () async {
      await SyncService.initRealTimeSync(() {});
      await SyncService.refreshCloudCollections(reason: 'test');
      await SyncService.refreshCollectionNow('repairs');
      await SyncService.syncAllToCloud(force: true);
      await SyncService.downloadAllFromCloud(force: true);
      await SyncService.syncRepairData();
      await SyncService.syncPaymentRelatedData();
      await SyncService.syncQuickInputCodesToCloud();
      await SyncService.syncCustomersFromCloud();
      expect(SyncService.isRealTimeSyncActive, isFalse);
    });

    test('orchestrator init/syncAll skip', () async {
      await SyncOrchestrator().init();
      final res = await SyncOrchestrator().syncAll();
      expect(res.skipped, isTrue);
      expect(res.total, 0);
    });

    test('health check reports healthy without reading cloud', () async {
      final report = await SyncHealthCheck.runFullCheck(force: true);
      expect(report.isFullyHealthy, isTrue);
      expect(report.totalCloudRecords, 0);
      expect(await SyncHealthCheck.autoFix(), 0);
    });
  });

  group('Other cloud services', () {
    test('notifications', () async {
      await NotificationService.ensureFCMTokenValid();
      expect(await NotificationService.hasFCMTokenOnServer(), isFalse);
      NotificationService.listenToNotifications((_, __) {});
      await NotificationService.sendCloudNotification(
        title: 't',
        body: 'b',
        type: 'x',
      );
    });

    test('chat / community / claims / shop / storage / uploads', () async {
      expect(await ChatService.getUnreadCount(), 0);
      await CommunityService.toggleLike(postId: 'p1', isLiked: false);
      ClaimsService().startClaimsSync();
      await ClaimsService().forceRefresh();
      await CurrentShopService().init();
      expect(
        await StorageService.uploadAndGetUrl('/tmp/nope.jpg', 'x'),
        isNull,
      );
      BackgroundUploadService.uploadRepairImages(
        localRepairId: 1,
        firestoreId: 'rep_test_1',
        images: [XFile('/tmp/nope.jpg')],
      );
    });
  });
}
