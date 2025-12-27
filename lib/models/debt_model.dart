class Debt {
  int? id;
  String? firestoreId;
  String personName;
  String phone;
  int totalAmount;
  int paidAmount;
  String type; // 'OWE' or 'OWED'
  String status; // 'ACTIVE', 'PAID', 'CANCELLED'
  int createdAt;
  String? note;
  bool isSynced;

  Debt({
    this.id,
    this.firestoreId,
    required this.personName,
    required this.phone,
    required this.totalAmount,
    this.paidAmount = 0,
    required this.type,
    this.status = 'ACTIVE',
    required this.createdAt,
    this.note,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firestoreId': firestoreId,
      'personName': personName,
      'phone': phone,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'type': type,
      'status': status,
      'createdAt': createdAt,
      'note': note,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map) {
    final totalAmount = map['totalAmount'] is int ? map['totalAmount'] : 0;
    final paidAmountRaw = map['paidAmount'] is int ? map['paidAmount'] : 0;
    final paidAmount = paidAmountRaw > totalAmount ? totalAmount : paidAmountRaw;
    return Debt(
      id: map['id'],
      firestoreId: map['firestoreId'],
      personName: map['personName'] ?? '',
      phone: map['phone'] ?? '',
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      type: map['type'] ?? 'OWE',
      status: map['status'] ?? 'ACTIVE',
      createdAt: map['createdAt'] is int ? map['createdAt'] : 0,
      note: map['note'],
      isSynced: map['isSynced'] == 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'personName': personName,
      'phone': phone,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'type': type,
      'status': status,
      'createdAt': createdAt,
      'note': note,
    };
  }

  factory Debt.fromFirestore(Map<String, dynamic> data, String id) {
    return Debt(
      firestoreId: id,
      personName: data['personName'] ?? '',
      phone: data['phone'] ?? '',
      totalAmount: data['totalAmount'] ?? 0,
      paidAmount: data['paidAmount'] ?? 0,
      type: data['type'] ?? 'OWE',
      status: data['status'] ?? 'ACTIVE',
      createdAt: data['createdAt'] ?? 0,
      note: data['note'],
      isSynced: true,
    );
  }
}
