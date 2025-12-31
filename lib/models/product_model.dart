class Product {
  int? id;
  String? firestoreId;
  String name;
  String brand; // Trường bắt buộc
  String? imei;
  int cost;
  int price;
  String condition;
  int status;
  String description;
  String? images;
  String? warranty;
  int createdAt;
  String? supplier;
  String type;
  int quantity;
  String? color;
  String? capacity; // Dung lượng (ví dụ: 64GB, 128GB, etc.)
  int? kpkPrice; // Giá bán kèm phụ kiện
  int? pkPrice; // Giá phụ kiện
  String? paymentMethod; // Phương thức thanh toán
  bool isSynced;

  Product({
    this.id,
    this.firestoreId,
    required this.name,
    this.brand = "KHÁC",
    this.imei,
    this.cost = 0,
    this.price = 0,
    this.condition = "Mới",
    this.status = 1,
    this.description = "",
    this.images,
    this.warranty,
    required this.createdAt,
    this.supplier,
    this.type = 'PHONE',
    this.quantity = 1,
    this.color,
    this.capacity,
    this.kpkPrice,
    this.pkPrice,
    this.paymentMethod,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firestoreId': firestoreId ?? "prod_${createdAt}_$name",
      'name': name,
      'brand': brand,
      'imei': imei,
      'cost': cost,
      'price': price,
      'condition': condition,
      'status': status,
      'description': description,
      'images': images,
      'warranty': warranty,
      'createdAt': createdAt,
      'supplier': supplier,
      'type': type,
      'quantity': quantity,
      'color': color,
      'capacity': capacity,
      'kpkPrice': kpkPrice,
      'pkPrice': pkPrice,
      'paymentMethod': paymentMethod,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      firestoreId: map['firestoreId'],
      name: map['name'] ?? "",
      brand: map['brand'] ?? "KHÁC",
      imei: map['imei'],
      cost: (map['cost'] is int ? map['cost'] : 0) < 0 ? 0 : (map['cost'] is int ? map['cost'] : 0),
      price: (map['price'] is int ? map['price'] : 0) < 0 ? 0 : (map['price'] is int ? map['price'] : 0),
      condition: map['condition'] ?? "Mới",
      status: map['status'] is int ? map['status'] : 1,
      description: map['description'] ?? "",
      images: map['images'],
      warranty: map['warranty'],
      createdAt: map['createdAt'] is int ? map['createdAt'] : 0,
      supplier: map['supplier'],
      type: map['type'] ?? 'PHONE',
      quantity: (map['quantity'] is int ? map['quantity'] : 1) < 0 ? 0 : (map['quantity'] is int ? map['quantity'] : 1),
      color: map['color'],
      capacity: map['capacity'],
      kpkPrice: map['kpkPrice'] is int ? map['kpkPrice'] : null,
      pkPrice: map['pkPrice'] is int ? map['pkPrice'] : null,
      paymentMethod: map['paymentMethod'],
      isSynced: map['isSynced'] == 1,
    );
  }

  Product copyWith({
    int? id,
    String? firestoreId,
    String? name,
    String? brand,
    String? imei,
    int? cost,
    int? price,
    String? condition,
    int? status,
    String? description,
    String? images,
    String? warranty,
    int? createdAt,
    String? supplier,
    String? type,
    int? quantity,
    String? color,
    String? capacity,
    int? kpkPrice,
    int? pkPrice,
    String? paymentMethod,
    bool? isSynced,
    int? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      imei: imei ?? this.imei,
      cost: cost ?? this.cost,
      price: price ?? this.price,
      condition: condition ?? this.condition,
      status: status ?? this.status,
      description: description ?? this.description,
      images: images ?? this.images,
      warranty: warranty ?? this.warranty,
      createdAt: createdAt ?? this.createdAt,
      supplier: supplier ?? this.supplier,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      color: color ?? this.color,
      capacity: capacity ?? this.capacity,
      kpkPrice: kpkPrice ?? this.kpkPrice,
      pkPrice: pkPrice ?? this.pkPrice,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
