/// Chi tiết 1 linh kiện đã dùng trong đơn sửa — bổ sung song song với
/// `Repair.partsUsed` (text tự do) để Pricing Engine group chính xác hơn.
/// Chỉ được ghi cho đơn linh kiện thêm qua màn chọn từ kho (biết productId
/// + giá vốn tại thời điểm dùng); đơn cũ/luồng khác không có trường này.
class PartUsedDetail {
  final String name;
  final int? productId;
  final int cost;
  final int qty;

  /// Tên nhà cung cấp linh kiện (lấy lúc chọn từ kho) — chỉ để hiển thị cho
  /// dễ nhận biết; đơn cũ không có trường này.
  final String? supplier;

  const PartUsedDetail({
    required this.name,
    this.productId,
    required this.cost,
    this.qty = 1,
    this.supplier,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'productId': productId,
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
      cost: map['cost'] is num ? (map['cost'] as num).toInt() : 0,
      qty: map['qty'] is num ? (map['qty'] as num).toInt() : 1,
      supplier: (map['supplier'] as String?)?.trim().isNotEmpty == true
          ? (map['supplier'] as String).trim()
          : null,
    );
  }
}
