class QuickInputCode {
  int? id;
  String? firestoreId;
  String? shopId; // Shop ID để đồng bộ giữa các thiết bị
  String name; // Tên template
  String type; // 'PHONE' hoặc 'linh-phụ kiện'
  String? brand; // Thương hiệu (cho phone)
  String? model; // Model (cho phone)
  String? capacity; // Dung lượng (cho phone)
  String? color; // Màu sắc (cho phone)
  String? condition; // Tình trạng (cho phone)
  int? cost; // Giá nhập
  int? price; // Giá bán
  String? description; // Mô tả/ghi chú
  String? supplier; // Nhà cung cấp
  String? paymentMethod; // Phương thức thanh toán
  bool isActive; // Có đang active không
  int createdAt;
  bool isSynced;

  QuickInputCode({
    this.id,
    this.firestoreId,
    this.shopId,
    required this.name,
    required this.type,
    this.brand,
    this.model,
    this.capacity,
    this.color,
    this.condition,
    this.cost,
    this.price,
    this.description,
    this.supplier,
    this.paymentMethod,
    this.isActive = true,
    required this.createdAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firestoreId': firestoreId,
      'shopId': shopId,
      'name': name,
      'type': type,
      'brand': brand,
      'model': model,
      'capacity': capacity,
      'color': color,
      'condition': condition,
      'cost': cost,
      'price': price,
      'description': description,
      'supplier': supplier,
      'paymentMethod': paymentMethod,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory QuickInputCode.fromMap(Map<String, dynamic> map) {
    return QuickInputCode(
      id: map['id'],
      firestoreId: map['firestoreId'],
      shopId: map['shopId'],
      name: map['name'] ?? '',
      type: map['type'] ?? 'PHONE',
      brand: map['brand'],
      model: map['model'],
      capacity: map['capacity'],
      color: map['color'],
      condition: map['condition'],
      cost: map['cost'],
      price: map['price'],
      description: map['description'],
      supplier: map['supplier'],
      paymentMethod: map['paymentMethod'],
      isActive: map['isActive'] == 1,
      createdAt: map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      isSynced: map['isSynced'] == 1,
    );
  }

  QuickInputCode copyWith({
    int? id,
    String? firestoreId,
    String? name,
    String? type,
    String? brand,
    String? model,
    String? capacity,
    String? color,
    String? condition,
    int? cost,
    int? price,
    String? description,
    String? supplier,
    String? paymentMethod,
    bool? isActive,
    int? createdAt,
    bool? isSynced,
  }) {
    return QuickInputCode(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      name: name ?? this.name,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      capacity: capacity ?? this.capacity,
      color: color ?? this.color,
      condition: condition ?? this.condition,
      cost: cost ?? this.cost,
      price: price ?? this.price,
      description: description ?? this.description,
      supplier: supplier ?? this.supplier,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}