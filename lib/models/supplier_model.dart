class Supplier {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? note;
  final bool active;
  final int createdAt;
  final int updatedAt;
  final String shopId;

  Supplier({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.note,
    this.active = true,
    int? createdAt,
    int? updatedAt,
    required this.shopId,
  }) :
    createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
    updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'note': note,
      'active': active ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'shopId': shopId,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      note: map['note'],
      active: map['active'] == 1,
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
      shopId: map['shopId'],
    );
  }

  Supplier copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? note,
    bool? active,
    int? createdAt,
    int? updatedAt,
    String? shopId,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      note: note ?? this.note,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      shopId: shopId ?? this.shopId,
    );
  }
}