/// Chi tiết 1 linh kiện đã dùng trong đơn sửa — bổ sung song song với
/// `Repair.partsUsed` (text tự do) để Pricing Engine group chính xác hơn.
/// Chỉ được ghi cho đơn linh kiện thêm qua màn chọn từ kho (biết productId
/// + giá vốn tại thời điểm dùng); đơn cũ/luồng khác không có trường này.
class PartUsedDetail {
  final String name;

  /// SQLite row id của sản phẩm trên MÁY ĐÃ THÊM phụ tùng — không mang nghĩa
  /// trên máy khác (id 517 máy này là món khác máy kia). Khi tra ngược phải
  /// ưu tiên [productFirestoreId], id này chỉ dùng khi tên cũng khớp.
  final int? productId;

  /// Cloud id của sản phẩm (products.firestoreId) — khoá dùng chung mọi máy.
  /// Đơn thêm phụ tùng trước 2026-09-12 không có trường này.
  final String? productFirestoreId;
  final int cost;
  final int qty;

  /// Tên nhà cung cấp linh kiện (lấy lúc chọn từ kho) — chỉ để hiển thị cho
  /// dễ nhận biết; đơn cũ không có trường này.
  final String? supplier;

  const PartUsedDetail({
    required this.name,
    this.productId,
    this.productFirestoreId,
    required this.cost,
    this.qty = 1,
    this.supplier,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'productId': productId,
      if (productFirestoreId != null && productFirestoreId!.trim().isNotEmpty)
        'productFirestoreId': productFirestoreId!.trim(),
      'cost': cost,
      'qty': qty,
      if (supplier != null && supplier!.trim().isNotEmpty) 'supplier': supplier,
    };
  }

  factory PartUsedDetail.fromMap(Map<String, dynamic> map) {
    return PartUsedDetail(
      name: (map['name'] ?? '').toString(),
      productId: map['productId'] is num
          ? (map['productId'] as num).toInt()
          : null,
      productFirestoreId:
          (map['productFirestoreId'] as String?)?.trim().isNotEmpty == true
          ? (map['productFirestoreId'] as String).trim()
          : null,
      cost: map['cost'] is num ? (map['cost'] as num).toInt() : 0,
      qty: map['qty'] is num ? (map['qty'] as num).toInt() : 1,
      supplier: (map['supplier'] as String?)?.trim().isNotEmpty == true
          ? (map['supplier'] as String).trim()
          : null,
    );
  }
}
