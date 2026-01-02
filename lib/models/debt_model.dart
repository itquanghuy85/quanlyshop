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
<<<<<<< HEAD
  String? linkedId; // Link to related record (product, sale, etc.)
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
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
<<<<<<< HEAD
    this.linkedId,
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
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
<<<<<<< HEAD
      'linkedId': linkedId,
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map) {
    final totalAmount = map['totalAmount'] is int ? map['totalAmount'] : 0;
<<<<<<< HEAD
    final totalAmountSafe = totalAmount < 0 ? 0 : totalAmount;
    final paidAmountRaw = map['paidAmount'] is int ? map['paidAmount'] : 0;
    final paidAmount = paidAmountRaw > totalAmountSafe ? totalAmountSafe : paidAmountRaw;
=======
    final paidAmountRaw = map['paidAmount'] is int ? map['paidAmount'] : 0;
    final paidAmount = paidAmountRaw > totalAmount ? totalAmount : paidAmountRaw;
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
    return Debt(
      id: map['id'],
      firestoreId: map['firestoreId'],
      personName: map['personName'] ?? '',
      phone: map['phone'] ?? '',
<<<<<<< HEAD
      totalAmount: totalAmountSafe,
=======
      totalAmount: totalAmount,
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
      paidAmount: paidAmount,
      type: map['type'] ?? 'OWE',
      status: map['status'] ?? 'ACTIVE',
      createdAt: map['createdAt'] is int ? map['createdAt'] : 0,
      note: map['note'],
<<<<<<< HEAD
      linkedId: map['linkedId'],
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
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
<<<<<<< HEAD
      'linkedId': linkedId,
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
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
<<<<<<< HEAD
      linkedId: data['linkedId'],
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
      isSynced: true,
    );
  }
}
