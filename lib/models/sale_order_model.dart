class SaleOrder {
  int? id;
  String? firestoreId;
  String customerName;
  String phone;
  String address;
  String productNames;
  String productImeis;
  int totalPrice;
  int totalCost;
  String paymentMethod;
  String sellerName;
  int soldAt;
  String? notes;
  String? gifts;
  String warranty;
  bool isSynced;

  // --- TRƯỜNG TRẢ GÓP MỚI ---
  bool isInstallment;    // Có phải trả góp không
  int downPayment;       // Số tiền khách trả trước
  int loanAmount;        // Số tiền vay ngân hàng
  String? installmentTerm; // Kỳ hạn vay (6, 12 tháng...)
  String? bankName;      // Tên ngân hàng hỗ trợ

  SaleOrder({
    this.id,
    this.firestoreId,
    required this.customerName,
    required this.phone,
    this.address = "",
    required this.productNames,
    required this.productImeis,
    this.totalPrice = 0,
    this.totalCost = 0,
    this.paymentMethod = "TIỀN MẶT",
    required this.sellerName,
    required this.soldAt,
    this.notes,
    this.gifts,
    this.warranty = "KO BH",
    this.isInstallment = false,
    this.downPayment = 0,
    this.loanAmount = 0,
    this.installmentTerm,
    this.bankName,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firestoreId': firestoreId,
      'customerName': customerName.toUpperCase(),
      'phone': phone,
      'address': address.toUpperCase(),
      'productNames': productNames.toUpperCase(),
      'productImeis': productImeis.toUpperCase(),
      'totalPrice': totalPrice,
      'totalCost': totalCost,
      'paymentMethod': paymentMethod.toUpperCase(),
      'sellerName': sellerName.toUpperCase(),
      'soldAt': soldAt,
      'notes': notes,
      'gifts': gifts?.toUpperCase(),
      'warranty': warranty.toUpperCase(),
      'isInstallment': isInstallment ? 1 : 0,
      'downPayment': downPayment,
      'loanAmount': loanAmount,
      'installmentTerm': installmentTerm,
      'bankName': bankName?.toUpperCase(),
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory SaleOrder.fromMap(Map<String, dynamic> map) {
    return SaleOrder(
      id: map['id'],
      firestoreId: map['firestoreId'],
      customerName: map['customerName'] ?? "",
      phone: map['phone'] ?? "",
      address: map['address'] ?? "",
      productNames: map['productNames'] ?? "",
      productImeis: map['productImeis'] ?? "",
      totalPrice: map['totalPrice'] ?? 0,
      totalCost: map['totalCost'] ?? 0,
      paymentMethod: map['paymentMethod'] ?? "TIỀN MẶT",
      sellerName: map['sellerName'] ?? "",
      soldAt: map['soldAt'] ?? 0,
      notes: map['notes'],
      gifts: map['gifts'],
      warranty: map['warranty'] ?? "KO BH",
      isInstallment: map['isInstallment'] == 1,
      downPayment: map['downPayment'] ?? 0,
      loanAmount: map['loanAmount'] ?? 0,
      installmentTerm: map['installmentTerm'],
      bankName: map['bankName'],
      isSynced: map['isSynced'] == 1,
    );
  }
}
