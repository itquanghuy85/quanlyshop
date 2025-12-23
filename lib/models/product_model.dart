class Product {
  int? id;
  String? firestoreId;
  String name;
  String brand;
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
  String? capacity;
  int? kpkPrice;
  int? pkPrice;
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
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    // TẠO ID DUY NHẤT: Tránh trùng lặp khi nhập liên tục
    final String uniqueSuffix = imei != null && imei!.isNotEmpty ? imei! : DateTime.now().microsecondsSinceEpoch.toString();
    return {
      'id': id,
      'firestoreId': firestoreId ?? "prod_${createdAt}_$uniqueSuffix",
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
      cost: map['cost'] ?? 0,
      price: map['price'] ?? 0,
      condition: map['condition'] ?? "Mới",
      status: map['status'] ?? 1,
      description: map['description'] ?? "",
      images: map['images'],
      warranty: map['warranty'],
      createdAt: map['createdAt'] ?? 0,
      supplier: map['supplier'],
      type: map['type'] ?? 'PHONE',
      quantity: map['quantity'] ?? 1,
      color: map['color'],
      capacity: map['capacity'],
      kpkPrice: map['kpkPrice'],
      pkPrice: map['pkPrice'],
      isSynced: map['isSynced'] == 1 || map['isSynced'] == true,
    );
  }
}
