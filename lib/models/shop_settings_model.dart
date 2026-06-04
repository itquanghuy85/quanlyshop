/// Model cài đặt cửa hàng theo ngành kinh doanh
/// Định nghĩa businessType và các module được bật cho shop
class ShopSettings {
  final String id;
  final String firestoreId;
  final String shopId;

  // === NGÀNH KINH DOANH ===
  /// 'electronics' | 'food' | 'fashion' | 'general'
  final String businessType;
  final String businessTypeName; // Tên hiển thị (VD: "Điện thoại", "Thực phẩm")

  // === MODULES ĐƯỢC BẬT ===
  final bool enableRepair; // Module sửa chữa (electronics)
  final bool enableExpiry; // Quản lý hạn sử dụng (food)
  final bool enableVariants; // Biến thể size/màu (fashion)
  final bool enableSerial; // Quản lý IMEI/Serial (electronics)
  final bool enableWarranty; // Quản lý bảo hành (electronics)
  final bool enableBatch; // Quản lý số lô (food)

  // === CÀI ĐẶT MẶC ĐỊNH ===
  final String defaultUnit; // Đơn vị mặc định: 'cái', 'kg', 'lít'...
  final int expiryWarningDays; // Số ngày cảnh báo HSD (mặc định 7)
  final int lowStockWarning; // Cảnh báo tồn kho thấp

  // === METADATA ===
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final bool isSynced;

  // === CÀI ĐẶT GIÁ VỐN ===
  /// true = cho phép lưu sản phẩm với giá vốn = 0 (nhập vốn sau)
  /// false (mặc định) = bắt buộc nhập giá vốn > 0 khi xác nhận nhập kho
  final bool allowPendingCost;

  // === MODULE NHÀ CUNG CẤP ===
  /// true (mặc định) = bật tính năng quản lý nhà cung cấp
  final bool enableSupplier;
  /// true (mặc định) = bắt buộc chọn NCC khi nhập kho (chỉ có hiệu lực khi enableSupplier = true)
  final bool requireSupplier;

  // === DEFAULT FLAG ===
  /// True nếu settings được tạo mặc định (shop chưa thiết lập ngành kinh doanh)
  final bool isDefault;

  ShopSettings({
    this.id = '',
    this.firestoreId = '',
    required this.shopId,
    this.businessType = 'electronics',
    this.businessTypeName = 'Điện thoại & Điện tử',
    this.enableRepair = true,
    this.enableExpiry = false,
    this.enableVariants = false,
    this.enableSerial = true,
    this.enableWarranty = true,
    this.enableBatch = false,
    this.defaultUnit = 'cái',
    this.expiryWarningDays = 7,
    this.lowStockWarning = 5,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.updatedBy,
    this.isSynced = false,
    this.isDefault = false,
    this.allowPendingCost = false,
    this.enableSupplier = true,
    this.requireSupplier = true,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Factory constructor cho electronics (ngành duy nhất được hỗ trợ)
  factory ShopSettings.electronics(String shopId) {
    return ShopSettings(
      shopId: shopId,
      businessType: 'electronics',
      businessTypeName: 'Điện thoại & Điện tử',
      enableRepair: true,
      enableExpiry: false,
      enableVariants: false,
      enableSerial: true,
      enableWarranty: true,
      enableBatch: false,
      defaultUnit: 'cái',
    );
  }

  /// Factory tạo từ loại ngành kinh doanh - luôn trả về electronics
  /// (Backward compatibility: các shop cũ với businessType khác sẽ được force về electronics)
  factory ShopSettings.fromBusinessType(String type, String shopId) {
    return ShopSettings.electronics(shopId);
  }

  /// Tạo từ Map (Firestore hoặc SQLite)
  /// IMPORTANT: Force businessType về 'electronics' nếu đọc từ dữ liệu cũ
  factory ShopSettings.fromMap(Map<String, dynamic> map) {
    // Force electronics cho tất cả shop - backward compatibility
    final businessType = 'electronics';

    return ShopSettings(
      id: (map['id'] ?? '').toString(),
      firestoreId: (map['firestoreId'] ?? map['id'] ?? '').toString(),
      shopId: map['shopId'] ?? '',
      businessType: businessType,
      businessTypeName: 'Điện thoại & Điện tử',
      enableRepair: true,
      enableExpiry: false,
      enableVariants: false,
      enableSerial: true,
      enableWarranty: true,
      enableBatch: false,
      defaultUnit: 'cái',
      expiryWarningDays: 7,
      lowStockWarning: 5,
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      updatedBy: map['updatedBy'],
      isSynced: map['isSynced'] == true || map['isSynced'] == 1,
      isDefault: false,
      allowPendingCost: map['allowPendingCost'] == true || map['allowPendingCost'] == 1,
      enableSupplier: map['enableSupplier'] != false && map['enableSupplier'] != 0,
      requireSupplier: map['requireSupplier'] != false && map['requireSupplier'] != 0,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final asInt = int.tryParse(value);
      if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  /// Chuyển sang Map cho Firestore
  Map<String, dynamic> toFirestoreMap() {
    return {
      'shopId': shopId,
      'businessType': businessType,
      'businessTypeName': businessTypeName,
      'enableRepair': enableRepair,
      'enableExpiry': enableExpiry,
      'enableVariants': enableVariants,
      'enableSerial': enableSerial,
      'enableWarranty': enableWarranty,
      'enableBatch': enableBatch,
      'defaultUnit': defaultUnit,
      'expiryWarningDays': expiryWarningDays,
      'lowStockWarning': lowStockWarning,
      'allowPendingCost': allowPendingCost,
      'enableSupplier': enableSupplier,
      'requireSupplier': requireSupplier,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'updatedBy': updatedBy,
    };
  }

  /// Chuyển sang Map cho SQLite
  Map<String, dynamic> toMap() {
    return {
      'firestoreId': firestoreId.isNotEmpty ? firestoreId : 'settings_$shopId',
      'shopId': shopId,
      'businessType': businessType,
      'businessTypeName': businessTypeName,
      'enableRepair': enableRepair ? 1 : 0,
      'enableExpiry': enableExpiry ? 1 : 0,
      'enableVariants': enableVariants ? 1 : 0,
      'enableSerial': enableSerial ? 1 : 0,
      'enableWarranty': enableWarranty ? 1 : 0,
      'enableBatch': enableBatch ? 1 : 0,
      'defaultUnit': defaultUnit,
      'expiryWarningDays': expiryWarningDays,
      'lowStockWarning': lowStockWarning,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'updatedBy': updatedBy,
      'isSynced': isSynced ? 1 : 0,
      'allowPendingCost': allowPendingCost ? 1 : 0,
      'enableSupplier': enableSupplier ? 1 : 0,
      'requireSupplier': requireSupplier ? 1 : 0,
    };
  }

  /// Copy with để update
  ShopSettings copyWith({
    String? id,
    String? firestoreId,
    String? shopId,
    String? businessType,
    String? businessTypeName,
    bool? enableRepair,
    bool? enableExpiry,
    bool? enableVariants,
    bool? enableSerial,
    bool? enableWarranty,
    bool? enableBatch,
    String? defaultUnit,
    int? expiryWarningDays,
    int? lowStockWarning,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
    bool? isSynced,
    bool? isDefault,
    bool? allowPendingCost,
    bool? enableSupplier,
    bool? requireSupplier,
  }) {
    return ShopSettings(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      shopId: shopId ?? this.shopId,
      businessType: businessType ?? this.businessType,
      businessTypeName: businessTypeName ?? this.businessTypeName,
      enableRepair: enableRepair ?? this.enableRepair,
      enableExpiry: enableExpiry ?? this.enableExpiry,
      enableVariants: enableVariants ?? this.enableVariants,
      enableSerial: enableSerial ?? this.enableSerial,
      enableWarranty: enableWarranty ?? this.enableWarranty,
      enableBatch: enableBatch ?? this.enableBatch,
      defaultUnit: defaultUnit ?? this.defaultUnit,
      expiryWarningDays: expiryWarningDays ?? this.expiryWarningDays,
      lowStockWarning: lowStockWarning ?? this.lowStockWarning,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      updatedBy: updatedBy ?? this.updatedBy,
      isSynced: isSynced ?? this.isSynced,
      isDefault: isDefault ?? this.isDefault,
      allowPendingCost: allowPendingCost ?? this.allowPendingCost,
      enableSupplier: enableSupplier ?? this.enableSupplier,
      requireSupplier: requireSupplier ?? this.requireSupplier,
    );
  }

  /// Kiểm tra có phải ngành điện tử không (luôn true vì chỉ hỗ trợ electronics)
  bool get isElectronics => true;

  @override
  String toString() =>
      'ShopSettings(shopId: $shopId, businessType: $businessType)';
}

/// Enum các loại ngành kinh doanh (chỉ hỗ trợ electronics)
enum BusinessType {
  electronics('electronics', 'Điện thoại & Điện tử', '📱');

  final String code;
  final String displayName;
  final String icon;

  const BusinessType(this.code, this.displayName, this.icon);

  static BusinessType fromCode(String code) {
    // Luôn trả về electronics
    return BusinessType.electronics;
  }
}
