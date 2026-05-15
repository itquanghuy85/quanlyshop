import 'package:flutter_test/flutter_test.dart';
import '../lib/models/shop_settings_model.dart';

void main() {
  group('ShopSettings Model', () {
    test('electronics factory creates correct settings', () {
      final settings = ShopSettings.electronics('shop123');

      expect(settings.shopId, 'shop123');
      expect(settings.businessType, 'electronics');
      expect(settings.enableRepair, true);
      expect(settings.enableExpiry, false);
      expect(settings.enableVariants, false);
      expect(settings.enableSerial, true);
      expect(settings.enableWarranty, true);
      expect(settings.enableBatch, false);
      expect(settings.defaultUnit, 'cái');
      expect(settings.isDefault, false);
    });

    test('fromBusinessType always returns electronics settings', () {
      expect(
        ShopSettings.fromBusinessType('electronics', 'shop1').enableRepair,
        true,
      );
      expect(
        ShopSettings.fromBusinessType('any_type', 'shop1').businessType,
        'electronics',
      );
    });

    test('toMap produces correct output', () {
      final settings = ShopSettings.electronics('shop123');
      final map = settings.toMap();

      expect(map['shopId'], 'shop123');
      expect(map['businessType'], 'electronics');
      // toMap returns 1/0 for bools (SQLite compatible)
      expect(map['enableRepair'], 1);
      expect(map['enableExpiry'], 0);
      expect(map['enableVariants'], 0);
    });

    test('fromMap forces businessType to electronics', () {
      final map = {
        'shopId': 'shop123',
        'businessType': 'fashion', // Try to set non-electronics
        'businessTypeName': 'Thời trang',
        'enableRepair': false,
        'enableExpiry': false,
        'enableVariants': true,
        'enableSerial': false,
        'enableWarranty': false,
        'enableBatch': false,
        'defaultUnit': 'cái',
      };

      final settings = ShopSettings.fromMap(map);

      // Verify forced to electronics
      expect(settings.businessType, 'electronics');
      expect(settings.enableRepair, true); // Electronics defaults
    });

    test('copyWith works correctly', () {
      final original = ShopSettings.electronics('shop123');
      final modified = original.copyWith(
        enableRepair: false,
        enableVariants: true,
        isDefault: true,
      );

      expect(original.enableRepair, true);
      expect(modified.enableRepair, false);
      expect(modified.enableVariants, true);
      expect(modified.isDefault, true);
      expect(modified.shopId, 'shop123'); // unchanged
    });

    test('isDefault flag preserved through copyWith', () {
      final defaultSettings = ShopSettings.electronics(
        'shop123',
      ).copyWith(isDefault: true);

      expect(defaultSettings.isDefault, true);

      final savedSettings = defaultSettings.copyWith(isDefault: false);
      expect(savedSettings.isDefault, false);
    });
  });

  group('UI Filtering Logic', () {
    test('electronics shows repair, hides expiry/variants', () {
      final settings = ShopSettings.electronics('shop1');

      // UI should show
      expect(settings.enableRepair, true); // Repair tab visible
      expect(settings.enableSerial, true); // Serial/IMEI input visible
      expect(settings.enableWarranty, true); // Warranty management visible

      // UI should hide
      expect(settings.enableExpiry, false); // Expiry tab hidden
      expect(settings.enableVariants, false); // Variants tab hidden
      expect(settings.enableBatch, false); // Batch input hidden
    });
  });

  group('Legacy Shop Detection', () {
    test('default settings have isDefault=true when shop has no settings', () {
      // Simulate what CategoryService does for legacy shops
      final defaultSettings = ShopSettings.electronics(
        'legacy_shop',
      ).copyWith(isDefault: true);

      expect(defaultSettings.isDefault, true);
      expect(defaultSettings.businessType, 'electronics');
    });

    test('saved settings have isDefault=false', () {
      final savedSettings = ShopSettings.fromMap({
        'shopId': 'configured_shop',
        'businessType': 'fashion',
        'businessTypeName': 'Thời trang',
        'enableRepair': false,
        'enableExpiry': false,
        'enableVariants': true,
        'enableSerial': false,
        'enableWarranty': false,
        'enableBatch': false,
        // isDefault not in map = defaults to false
      });

      expect(savedSettings.isDefault, false);
    });
  });
}
