class StorageLocation {
  int? id;
  String? firestoreId;
  String? shopId;
  String code;
  String name;
  String? warehouse;
  String? floor;
  String? shelf;
  String? bin;
  String? note;
  bool isActive;
  int createdAt;
  int? updatedAt;
  bool isSynced;
  bool deleted;

  StorageLocation({
    this.id,
    this.firestoreId,
    this.shopId,
    required this.code,
    required this.name,
    this.warehouse,
    this.floor,
    this.shelf,
    this.bin,
    this.note,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.isSynced = false,
    this.deleted = false,
  });

  String get displayName {
    final parts = <String>[];
    if (warehouse != null && warehouse!.isNotEmpty) parts.add(warehouse!);
    if (floor != null && floor!.isNotEmpty) parts.add(floor!);
    if (shelf != null && shelf!.isNotEmpty) parts.add(shelf!);
    if (bin != null && bin!.isNotEmpty) parts.add(bin!);
    return parts.isNotEmpty ? parts.join(' - ') : name;
  }

  String get shortLabel => code.isNotEmpty ? code : name;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firestoreId': firestoreId ?? 'loc_${createdAt}_$code',
      'shopId': shopId,
      'code': code,
      'name': name,
      'warehouse': warehouse,
      'floor': floor,
      'shelf': shelf,
      'bin': bin,
      'note': note,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isSynced': isSynced ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory StorageLocation.fromMap(Map<String, dynamic> map) {
    return StorageLocation(
      id: map['id'] is int ? map['id'] : null,
      firestoreId: map['firestoreId'],
      shopId: map['shopId'],
      code: map['code'] ?? '',
      name: map['name'] ?? '',
      warehouse: map['warehouse'],
      floor: map['floor'],
      shelf: map['shelf'],
      bin: map['bin'],
      note: map['note'],
      isActive: (map['isActive'] ?? 1) == 1,
      createdAt: map['createdAt'] is int ? map['createdAt'] : DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['updatedAt'] is int ? map['updatedAt'] : null,
      isSynced: map['isSynced'] == 1,
      deleted: map['deleted'] == 1,
    );
  }

  StorageLocation copyWith({
    int? id,
    String? firestoreId,
    String? shopId,
    String? code,
    String? name,
    String? warehouse,
    String? floor,
    String? shelf,
    String? bin,
    String? note,
    bool? isActive,
    int? createdAt,
    int? updatedAt,
    bool? isSynced,
    bool? deleted,
  }) {
    return StorageLocation(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      shopId: shopId ?? this.shopId,
      code: code ?? this.code,
      name: name ?? this.name,
      warehouse: warehouse ?? this.warehouse,
      floor: floor ?? this.floor,
      shelf: shelf ?? this.shelf,
      bin: bin ?? this.bin,
      note: note ?? this.note,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      deleted: deleted ?? this.deleted,
    );
  }
}
