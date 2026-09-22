// Sửa/tân trang sản phẩm trong kho trước khi bán (2026-09-22).
class ProductRefurbishItem {
  static const typePartnerService = 'PARTNER_SERVICE';
  static const typePart = 'PART';
  static const typeOther = 'OTHER';

  final int? id;
  final String? firestoreId;
  final int productId;
  final String? productFirestoreId;
  final String type; // PARTNER_SERVICE | PART | OTHER
  final String description;
  final int? partnerId;
  final String? partnerName;
  final int? partId;
  final String? partName;
  final int quantity;
  final int amount;
  final String? paymentMethod; // TIỀN MẶT | CHUYỂN KHOẢN | CÔNG NỢ
  final String? debtFirestoreId;
  final String? expenseFirestoreId;
  final int createdAt;
  final String? createdBy;
  final String? shopId;
  final bool isSynced;
  final bool deleted;

  const ProductRefurbishItem({
    this.id,
    this.firestoreId,
    required this.productId,
    this.productFirestoreId,
    required this.type,
    required this.description,
    this.partnerId,
    this.partnerName,
    this.partId,
    this.partName,
    this.quantity = 1,
    required this.amount,
    this.paymentMethod,
    this.debtFirestoreId,
    this.expenseFirestoreId,
    required this.createdAt,
    this.createdBy,
    this.shopId,
    this.isSynced = false,
    this.deleted = false,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'firestoreId': firestoreId,
    'productId': productId,
    'productFirestoreId': productFirestoreId,
    'type': type,
    'description': description,
    'partnerId': partnerId,
    'partnerName': partnerName,
    'partId': partId,
    'partName': partName,
    'quantity': quantity,
    'amount': amount,
    'paymentMethod': paymentMethod,
    'debtFirestoreId': debtFirestoreId,
    'expenseFirestoreId': expenseFirestoreId,
    'createdAt': createdAt,
    'createdBy': createdBy,
    'shopId': shopId,
    'isSynced': isSynced ? 1 : 0,
    'deleted': deleted ? 1 : 0,
  };

  factory ProductRefurbishItem.fromMap(Map<String, dynamic> map) {
    return ProductRefurbishItem(
      id: map['id'] as int?,
      firestoreId: map['firestoreId'] as String?,
      productId: (map['productId'] as num?)?.toInt() ?? 0,
      productFirestoreId: map['productFirestoreId'] as String?,
      type: map['type'] as String? ?? typeOther,
      description: map['description'] as String? ?? '',
      partnerId: (map['partnerId'] as num?)?.toInt(),
      partnerName: map['partnerName'] as String?,
      partId: (map['partId'] as num?)?.toInt(),
      partName: map['partName'] as String?,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      paymentMethod: map['paymentMethod'] as String?,
      debtFirestoreId: map['debtFirestoreId'] as String?,
      expenseFirestoreId: map['expenseFirestoreId'] as String?,
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      createdBy: map['createdBy'] as String?,
      shopId: map['shopId'] as String?,
      isSynced: (map['isSynced'] as num?)?.toInt() == 1,
      deleted: (map['deleted'] as num?)?.toInt() == 1,
    );
  }
}
