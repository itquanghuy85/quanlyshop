class Product {
  int? id;
  String? firestoreId;
  String name;
  String brand; // Trường bắt buộc
<<<<<<< HEAD
  String? model; // Model máy (ví dụ: iPhone 15 Pro, Galaxy S24, etc.)
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  String? imei;
  int cost;
  int price;
  String condition;
  int status;
  String description;
  String? images;
  String? warranty;
  int createdAt;
<<<<<<< HEAD
  int? updatedAt;
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  String? supplier;
  String type;
  int quantity;
  String? color;
  String? capacity; // Dung lượng (ví dụ: 64GB, 128GB, etc.)
<<<<<<< HEAD
  String? paymentMethod; // Phương thức thanh toán
=======
  int? kpkPrice; // Giá bán kèm phụ kiện
  int? pkPrice; // Giá phụ kiện
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  bool isSynced;

  Product({
    this.id,
    this.firestoreId,
    required this.name,
    this.brand = "KHÁC",
<<<<<<< HEAD
    this.model,
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
    this.imei,
    this.cost = 0,
    this.price = 0,
    this.condition = "Mới",
    this.status = 1,
    this.description = "",
    this.images,
    this.warranty,
    required this.createdAt,
<<<<<<< HEAD
    this.updatedAt,
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
    this.supplier,
    this.type = 'PHONE',
    this.quantity = 1,
    this.color,
    this.capacity,
<<<<<<< HEAD
    this.paymentMethod,
=======
    this.kpkPrice,
    this.pkPrice,
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firestoreId': firestoreId ?? "prod_${createdAt}_$name",
      'name': name,
      'brand': brand,
<<<<<<< HEAD
      'model': model,
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
      'imei': imei,
      'cost': cost,
      'price': price,
      'condition': condition,
      'status': status,
      'description': description,
      'images': images,
      'warranty': warranty,
      'createdAt': createdAt,
<<<<<<< HEAD
      'updatedAt': updatedAt,
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
      'supplier': supplier,
      'type': type,
      'quantity': quantity,
      'color': color,
      'capacity': capacity,
<<<<<<< HEAD
      'paymentMethod': paymentMethod,
=======
      'kpkPrice': kpkPrice,
      'pkPrice': pkPrice,
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      firestoreId: map['firestoreId'],
      name: map['name'] ?? "",
      brand: map['brand'] ?? "KHÁC",
<<<<<<< HEAD
      model: map['model'],
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
      imei: map['imei'],
      cost: (map['cost'] is int ? map['cost'] : 0) < 0 ? 0 : (map['cost'] is int ? map['cost'] : 0),
      price: (map['price'] is int ? map['price'] : 0) < 0 ? 0 : (map['price'] is int ? map['price'] : 0),
      condition: map['condition'] ?? "Mới",
      status: map['status'] is int ? map['status'] : 1,
      description: map['description'] ?? "",
      images: map['images'],
      warranty: map['warranty'],
      createdAt: map['createdAt'] is int ? map['createdAt'] : 0,
<<<<<<< HEAD
      updatedAt: map['updatedAt'] is int ? map['updatedAt'] : null,
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
      supplier: map['supplier'],
      type: map['type'] ?? 'PHONE',
      quantity: (map['quantity'] is int ? map['quantity'] : 1) < 0 ? 0 : (map['quantity'] is int ? map['quantity'] : 1),
      color: map['color'],
      capacity: map['capacity'],
<<<<<<< HEAD
      paymentMethod: map['paymentMethod'],
      isSynced: map['isSynced'] == 1,
    );
  }

  Product copyWith({
    int? id,
    String? firestoreId,
    String? name,
    String? brand,
    String? model,
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
    String? paymentMethod,
    bool? isSynced,
    int? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      imei: imei ?? this.imei,
      cost: cost ?? this.cost,
      price: price ?? this.price,
      condition: condition ?? this.condition,
      status: status ?? this.status,
      description: description ?? this.description,
      images: images ?? this.images,
      warranty: warranty ?? this.warranty,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supplier: supplier ?? this.supplier,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      color: color ?? this.color,
      capacity: capacity ?? this.capacity,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isSynced: isSynced ?? this.isSynced,
    );
  }
=======
      kpkPrice: map['kpkPrice'] is int ? map['kpkPrice'] : null,
      pkPrice: map['pkPrice'] is int ? map['pkPrice'] : null,
      isSynced: map['isSynced'] == 1,
    );
  }
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
}
