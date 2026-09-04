/// Một dòng hàng hoá trích từ ảnh hoá đơn NCC — do AI đọc ảnh trả về, hoặc
/// người dùng tự gõ tay theo ảnh khi AI chưa khả dụng.
class InvoiceLineItem {
  final String name;
  final int unitPrice;
  final int qty;

  /// Hãng máy (Oppo/iPhone/Samsung/…), nếu file Excel có cột "Hãng" riêng —
  /// đáng tin hơn việc tự đoán hãng từ chuỗi tên gộp. Rỗng nếu AI/người dùng
  /// không điền — khi đó Bảng giá tự đoán hãng từ [name].
  final String brand;

  const InvoiceLineItem({
    required this.name,
    required this.unitPrice,
    this.qty = 1,
    this.brand = '',
  });

  InvoiceLineItem copyWith({
    String? name,
    int? unitPrice,
    int? qty,
    String? brand,
  }) {
    return InvoiceLineItem(
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      qty: qty ?? this.qty,
      brand: brand ?? this.brand,
    );
  }
}

/// Đề xuất cập nhật giá vốn cho 1 phụ tùng đã có trong kho, khớp từ 1 dòng
/// hoá đơn NCC. KHÔNG đụng số lượng tồn kho — chỉ giá vốn tham khảo.
class PartCostUpdateProposal {
  final int partId;
  final String partName;
  final int oldCost;
  final int newCost;
  final String sourceLineName;

  const PartCostUpdateProposal({
    required this.partId,
    required this.partName,
    required this.oldCost,
    required this.newCost,
    required this.sourceLineName,
  });
}
