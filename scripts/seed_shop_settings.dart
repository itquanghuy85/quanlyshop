/// Script tạo dữ liệu test cho shop settings
/// Chạy bằng: dart run scripts/seed_shop_settings.dart
///
/// Script này tạo shop_settings document trong Firestore cho các shop test
/// với các loại ngành kinh doanh khác nhau.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Tạo shop settings cho loại ngành điện tử (loại duy nhất được hỗ trợ)
Map<String, dynamic> electronicsSettings(String shopId) => {
  'shopId': shopId,
  'businessType': 'electronics',
  'businessTypeName': 'Điện thoại & Điện tử',
  'enableRepair': true,
  'enableExpiry': false,
  'enableVariants': false,
  'enableSerial': true,
  'enableWarranty': true,
  'enableBatch': false,
  'defaultUnit': 'cái',
  'expiryWarningDays': 7,
  'lowStockWarning': 5,
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
  'isSynced': true,
};

/// Seed shop settings vào Firestore
Future<void> seedShopSettings(String shopId, String businessType) async {
  final db = FirebaseFirestore.instance;
  final settingsRef = db
      .collection('shops')
      .doc(shopId)
      .collection('settings')
      .doc('shop_settings');

  // Luôn tạo settings cho electronics
  final settings = electronicsSettings(shopId);

  await settingsRef.set(settings, SetOptions(merge: true));
  print('✅ Created electronics settings for shop: $shopId');
}

/// Main function - chạy khi gọi script
Future<void> main() async {
  print('🚀 Shop Settings Seed Script');
  print('=============================');
  print('');
  print('App chỉ hỗ trợ: Cửa hàng Điện thoại & Điện tử');
  print('');

  print('=== ELECTRONICS (Điện thoại) ===');
  print('''
{
  "shopId": "<your_shop_id>",
  "businessType": "electronics",
  "businessTypeName": "Điện thoại & Điện tử",
  "enableRepair": true,
  "enableExpiry": false,
  "enableVariants": false,
  "enableSerial": true,
  "enableWarranty": true,
  "enableBatch": false,
  "defaultUnit": "cái",
  "expiryWarningDays": 7,
  "lowStockWarning": 5,
  "isSynced": true
}
''');

  print('=============================');
  print('📍 Firestore path: shops/{shopId}/settings/shop_settings');
}
