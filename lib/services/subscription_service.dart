import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  static const String _subscriptionKey = 'user_subscription_tier';

  static const Map<String, List<String>> tierFeatures = {
    'free': [
      'basic_repairs',
      'basic_inventory',
      'basic_reports',
      'limited_users', // max 2 users
    ],
    'basic': [
      'unlimited_repairs',
      'sales_tracking',
      'basic_reports',
      'unlimited_users',
      'customer_management',
    ],
    'pro': [
      'advanced_reports',
      'multi_shop',
      'api_access',
      'priority_support',
      'advanced_inventory',
      'financial_reports',
      'export_data',
      'advanced_analytics',
    ],
    'enterprise': [
      'white_label',
      'custom_integrations',
      'dedicated_support',
      'unlimited_storage',
      'advanced_analytics',
      'custom_workflows',
    ]
  };

  static const Map<String, Map<String, dynamic>> tierLimits = {
    'free': {
      'maxRepairsPerMonth': 50,
      'maxProducts': 100,
      'maxUsers': 2,
      'storageGB': 1,
    },
    'basic': {
      'maxRepairsPerMonth': 500,
      'maxProducts': 1000,
      'maxUsers': 10,
      'storageGB': 5,
    },
    'pro': {
      'maxRepairsPerMonth': 5000,
      'maxProducts': 10000,
      'maxUsers': 50,
      'storageGB': 25,
    },
    'enterprise': {
      'maxRepairsPerMonth': -1, // unlimited
      'maxProducts': -1,
      'maxUsers': -1,
      'storageGB': 100,
    }
  };

  static Future<String> getCurrentTier() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_subscriptionKey) ?? 'enterprise'; // Changed default to enterprise for full access
  }

  static Future<void> setTier(String tier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subscriptionKey, tier);
  }

  static Future<bool> hasFeature(String feature) async {
    final tier = await getCurrentTier();
    return tierFeatures[tier]?.contains(feature) ?? false;
  }

  static Future<Map<String, dynamic>> getCurrentLimits() async {
    final tier = await getCurrentTier();
    return tierLimits[tier] ?? tierLimits['free']!;
  }

  static Future<bool> canPerformAction(String action, {int? count}) async {
    final limits = await getCurrentLimits();

    switch (action) {
      case 'addRepair':
        final maxRepairs = limits['maxRepairsPerMonth'] as int;
        if (maxRepairs == -1) return true; // unlimited
        // TODO: Implement monthly repair count check
        return true; // Temporary: allow for now

      case 'addProduct':
        final maxProducts = limits['maxProducts'] as int;
        if (maxProducts == -1) return true;
        // TODO: Implement product count check
        return true;

      case 'addUser':
        final maxUsers = limits['maxUsers'] as int;
        if (maxUsers == -1) return true;
        // TODO: Implement user count check
        return true;

      default:
        return true;
    }
  }

  static Future<String> getUpgradeMessage(String feature) async {
    final tier = await getCurrentTier();

    switch (tier) {
      case 'free':
        return 'Tính năng này yêu cầu nâng cấp lên gói Basic hoặc cao hơn.';
      case 'basic':
        return 'Tính năng này yêu cầu nâng cấp lên gói Pro.';
      case 'pro':
        return 'Tính năng này yêu cầu nâng cấp lên gói Enterprise.';
      default:
        return 'Tính năng không khả dụng.';
    }
  }

  // Pricing (VND per month)
  static const Map<String, int> tierPricing = {
    'free': 0,
    'basic': 199000,
    'pro': 599000,
    'enterprise': 1999000,
  };

  static int getTierPrice(String tier) {
    return tierPricing[tier] ?? 0;
  }

  // Feature descriptions for UI
  static const Map<String, String> featureDescriptions = {
    'basic_repairs': 'Quản lý đơn sửa chữa cơ bản',
    'basic_inventory': 'Quản lý kho cơ bản',
    'basic_reports': 'Báo cáo cơ bản',
    'limited_users': 'Tối đa 2 người dùng',
    'unlimited_repairs': 'Số đơn sửa chữa không giới hạn',
    'sales_tracking': 'Theo dõi bán hàng',
    'unlimited_users': 'Số người dùng không giới hạn',
    'customer_management': 'Quản lý khách hàng',
    'advanced_reports': 'Báo cáo nâng cao',
    'multi_shop': 'Hỗ trợ nhiều cửa hàng',
    'api_access': 'Truy cập API',
    'priority_support': 'Hỗ trợ ưu tiên',
    'advanced_inventory': 'Quản lý kho nâng cao',
    'financial_reports': 'Báo cáo tài chính',
    'export_data': 'Xuất dữ liệu',
    'white_label': 'Thương hiệu riêng',
    'custom_integrations': 'Tích hợp tùy chỉnh',
    'dedicated_support': 'Hỗ trợ chuyên dụng',
    'unlimited_storage': 'Lưu trữ không giới hạn',
    'advanced_analytics': 'Phân tích nâng cao',
    'custom_workflows': 'Workflow tùy chỉnh',
  };
}