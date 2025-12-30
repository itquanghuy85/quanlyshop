class Repair {
  int? id;
  String? firestoreId;
  String customerName;
  String phone;
  String model;
  String issue;
  String accessories;
  String address;
  String? imagePath; 
  String? deliveredImage; 
  String warranty;
  String partsUsed;
  int status; // 1: Nhận, 2: Sửa, 3: Xong, 4: Giao
  int price;
  int cost;
  String paymentMethod;
  int createdAt;
  int? startedAt;
  int? finishedAt;
  int? deliveredAt;
  String? createdBy;
  String? repairedBy;
  String? deliveredBy;
  int? lastCaredAt;
  bool isSynced;
  bool deleted;

  // Thông tin máy cho tem nhiệt
  String? color;
  String? imei;
  String? condition;

  Repair({
    this.id,
    this.firestoreId,
    required this.customerName,
    required this.phone,
    required this.model,
    required this.issue,
    this.accessories = "Không có",
    this.address = "",
    this.imagePath,
    this.deliveredImage,
    this.warranty = "Không bảo hành",
    this.partsUsed = "",
    this.status = 1,
    this.price = 0,
    this.cost = 0,
    this.paymentMethod = "TIỀN MẶT",
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.deliveredAt,
    this.createdBy,
    this.repairedBy,
    this.deliveredBy,
    this.lastCaredAt,
    this.isSynced = false,
    this.deleted = false,
    this.color,
    this.imei,
    this.condition,
  });

  List<String> get receiveImages => imagePath?.split(',').where((e) => e.isNotEmpty).toList() ?? [];
  List<String> get deliverImages => deliveredImage?.split(',').where((e) => e.isNotEmpty).toList() ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firestoreId': firestoreId,
      'customerName': customerName,
      'phone': phone,
      'model': model,
      'issue': issue,
      'accessories': accessories,
      'address': address,
      'imagePath': imagePath,
      'deliveredImage': deliveredImage,
      'warranty': warranty,
      'partsUsed': partsUsed,
      'status': status,
      'price': price,
      'cost': cost,
      'paymentMethod': paymentMethod,
      'createdAt': createdAt,
      'startedAt': startedAt,
      'finishedAt': finishedAt,
      'deliveredAt': deliveredAt,
      'createdBy': createdBy,
      'repairedBy': repairedBy,
      'deliveredBy': deliveredBy,
      'lastCaredAt': lastCaredAt,
      'isSynced': isSynced ? 1 : 0,
      'deleted': deleted ? 1 : 0,
      'color': color,
      'imei': imei,
      'condition': condition,
    };
  }

  factory Repair.fromMap(Map<String, dynamic> map) {
    return Repair(
      id: map['id'],
      firestoreId: map['firestoreId'],
      customerName: map['customerName'] ?? "",
      phone: map['phone'] ?? "",
      model: map['model'] ?? "",
      issue: map['issue'] ?? "",
      accessories: map['accessories'] ?? "Không có",
      address: map['address'] ?? "",
      imagePath: map['imagePath'],
      deliveredImage: map['deliveredImage'],
      warranty: map['warranty'] ?? "Không bảo hành",
      partsUsed: map['partsUsed'] ?? "",
      status: map['status'] ?? 1,
      price: map['price'] ?? 0,
      cost: map['cost'] ?? 0,
      paymentMethod: map['paymentMethod'] ?? "TIỀN MẶT",
      createdAt: map['createdAt'] ?? 0,
      startedAt: map['startedAt'],
      finishedAt: map['finishedAt'],
      deliveredAt: map['deliveredAt'],
      createdBy: map['createdBy'],
      repairedBy: map['repairedBy'],
      deliveredBy: map['deliveredBy'],
      lastCaredAt: map['lastCaredAt'],
      isSynced: map['isSynced'] == 1 || map['isSynced'] == true,
      deleted: map['deleted'] == 1 || map['deleted'] == true,
      color: map['color'],
      imei: map['imei'],
      condition: map['condition'],
    );
  }
}
