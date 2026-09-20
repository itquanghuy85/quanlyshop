// SaleStockGuard — kiểm tồn kho LOCAL trước khi lưu đơn bán theo đường
// local-first (mất mạng / phiên offline / SP chưa có firestoreId) — NEW-05.
// Đường online đã có transaction cloud (OUT_OF_STOCK); đường local trước đây
// trừ thẳng ⇒ tồn âm và số âm được đồng bộ lên cloud.
import '../data/db_helper.dart';
import '../models/product_model.dart';

class SaleStockGuard {
  SaleStockGuard._();

  /// Số lượng tối đa bán được theo tồn đang có: điện thoại (IMEI) = 1 nếu
  /// còn (status 1), SP khác = quantity.
  static int maxSellable(Product p) {
    if (p.type == 'DIEN_THOAI') return p.status == 1 ? 1 : 0;
    return p.quantity < 0 ? 0 : p.quantity;
  }

  /// Đối chiếu các dòng đã chọn (`{'product': Product, 'quantity': int}`) với
  /// tồn ĐỌC LẠI từ SQLite (không tin bản trong bộ nhớ). Cùng SP chọn nhiều
  /// dòng thì cộng dồn. Trả về danh sách "TÊN (còn: N, cần: M)"; rỗng = đủ.
  static Future<List<String>> shortages(
    DBHelper db,
    List<Map<String, dynamic>> items,
  ) async {
    final need = <int, int>{};
    final byId = <int, Product>{};
    for (final item in items) {
      final p = item['product'] as Product;
      final id = p.id;
      if (id == null) continue;
      need[id] = (need[id] ?? 0) + ((item['quantity'] as int?) ?? 1);
      byId[id] = p;
    }
    final result = <String>[];
    for (final e in need.entries) {
      final fresh = await db.getProductById(e.key) ?? byId[e.key]!;
      final available = maxSellable(fresh);
      if (e.value > available) {
        result.add('${fresh.name} (còn: $available, cần: ${e.value})');
      }
    }
    return result;
  }
}
