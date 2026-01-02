import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('SubscriptionService', () {
    test('should return enterprise tier by default', () async {
      final tier = await SubscriptionService.getCurrentTier();
      expect(tier, 'enterprise');
    });

    test('should set and get tier correctly', () async {
      await SubscriptionService.setTier('basic');
      final tier = await SubscriptionService.getCurrentTier();
      expect(tier, 'basic');
    });

    test('should check features correctly', () async {
      // Free tier
      await SubscriptionService.setTier('free');
      expect(await SubscriptionService.hasFeature('basic_repairs'), true);
      expect(await SubscriptionService.hasFeature('advanced_reports'), false);

      // Basic tier
      await SubscriptionService.setTier('basic');
      expect(await SubscriptionService.hasFeature('unlimited_repairs'), true);
      expect(await SubscriptionService.hasFeature('advanced_reports'), false);

      // Pro tier
      await SubscriptionService.setTier('pro');
      expect(await SubscriptionService.hasFeature('advanced_reports'), true);
      expect(await SubscriptionService.hasFeature('white_label'), false);

      // Enterprise tier
      await SubscriptionService.setTier('enterprise');
      expect(await SubscriptionService.hasFeature('white_label'), true);
    });

    test('should return correct limits', () async {
      await SubscriptionService.setTier('free');
      final limits = await SubscriptionService.getCurrentLimits();
      expect(limits['maxUsers'], 2);
      expect(limits['storageGB'], 1);

      await SubscriptionService.setTier('basic');
      final basicLimits = await SubscriptionService.getCurrentLimits();
      expect(basicLimits['maxUsers'], 10);
      expect(basicLimits['storageGB'], 5);

      await SubscriptionService.setTier('enterprise');
      final enterpriseLimits = await SubscriptionService.getCurrentLimits();
      expect(enterpriseLimits['maxUsers'], -1); // unlimited
      expect(enterpriseLimits['storageGB'], 100);
    });

    test('should return correct pricing', () {
      expect(SubscriptionService.getTierPrice('free'), 0);
      expect(SubscriptionService.getTierPrice('basic'), 199000);
      expect(SubscriptionService.getTierPrice('pro'), 599000);
      expect(SubscriptionService.getTierPrice('enterprise'), 1999000);
    });

    test('should return upgrade message', () async {
      await SubscriptionService.setTier('free');
      final message = await SubscriptionService.getUpgradeMessage('advanced_reports');
      expect(message.contains('nâng cấp'), true);
    });
  });
}