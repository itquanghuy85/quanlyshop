import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/models/shop_settings_model.dart';
import 'package:quanlyshop/models/product_category_model.dart';
import 'package:quanlyshop/models/product_model.dart';

void main() {
  group('Electronics Phase 1 Tests', () {
    test('Electronics settings validation', () {
      final settings = ShopSettings.electronics('shop_elec_001');
      expect(settings.businessType, 'electronics');
      expect(settings.isElectronics, true);
    });
  });
}
