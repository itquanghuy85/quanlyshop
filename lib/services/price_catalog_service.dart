import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../constants/product_constants.dart';
import '../data/db_helper.dart';
import '../models/price_book_models.dart';
import '../models/price_catalog_models.dart';
import '../utils/vietnamese_utils.dart';
import 'sync_orchestrator.dart';
import 'user_service.dart';

/// Danh mục giá của shop ("Bảng giá từ hoá đơn NCC").
///
/// Khác giá GHIM của [PriceBookService] (SharedPreferences, theo từng máy):
/// danh mục này nằm trong SQLite `price_catalog_items` và đồng bộ Firestore
/// theo `shopId`, nên mọi thiết bị trong cùng shop tra cứu được cùng dữ liệu.
///
/// Quy tắc giá (bắt buộc, đừng nới lỏng):
///   • **Giá vốn** = giá nhập thực tế theo đơn vị, lấy từ hoá đơn NCC.
///   • **Giá thu khách** do người dùng nhập, ĐƯỢC PHÉP TRỐNG. Không bao giờ
///     suy ra từ giá vốn — nhân viên phải thấy "chưa thiết lập" thay vì báo
///     nhầm giá vốn cho khách.
class PriceCatalogService {
  PriceCatalogService._();

  static final DBHelper _db = DBHelper();

  // ── Khoá ổn định ─────────────────────────────────────────────────────────
  static String _n(String? s) => VietnameseUtils.normalize(
        (s ?? '').trim().replaceAll(RegExp(r'\s+'), ' '),
      );

  /// Khoá `_khóa_import` cho 1 mặt hàng.
  ///
  /// Ưu tiên **SKU** (mã hàng của NCC — định danh chắc chắn nhất). Không có
  /// SKU mới ghép hãng + tên + model + loại linh kiện: cố tình KHÔNG dùng
  /// riêng tên hàng, vì 2 mặt hàng khác model/khác chất lượng thường trùng
  /// tên (vd "Màn hình iPhone 13" bản OLED và bản LCD) — gộp là sai giá.
  static String buildImportKey({
    required String name,
    String sku = '',
    String brand = '',
    String model = '',
    String partType = '',
  }) {
    final s = _n(sku);
    if (s.isNotEmpty) return 'pc|sku|$s';
    return 'pc|${_n(brand)}|${_n(name)}|${_n(model)}|${_n(partType)}';
  }

  /// Doc ID Firestore TẤT ĐỊNH theo (shopId, khoá) — 2 máy cùng shop nhập
  /// cùng file sẽ ghi vào ĐÚNG một document thay vì tạo 2 bản ghi trùng.
  static String firestoreIdFor(String shopId, String importKey) {
    final digest = sha1.convert(utf8.encode('$shopId|$importKey')).toString();
    return 'pcat_$digest';
  }

  /// Vân tay 1 dòng hoá đơn — nhập LẠI cùng file thì dòng đó bị coi là trùng
  /// và không cộng thêm lần nữa vào bình quân gia quyền.
  static String lineFingerprint({
    required String importKey,
    required String invoiceNo,
    required String invoiceDate,
    required int unitCost,
    required int qty,
  }) {
    final raw =
        '$importKey|${_n(invoiceNo)}|${invoiceDate.trim()}|$unitCost|$qty';
    return sha1.convert(utf8.encode(raw)).toString().substring(0, 16);
  }

  // ── Tổng hợp giá vốn từ lịch sử nhập ────────────────────────────────────
  /// Tính lại giá vốn gần nhất / thấp nhất / cao nhất / bình quân gia quyền
  /// từ toàn bộ [history]. Luôn tính lại từ đầu (không cộng dồn tại chỗ) để
  /// kết quả không lệch khi sửa/bỏ bớt lịch sử.
  static ({
    int last,
    int avg,
    int min,
    int max,
    String invoiceNo,
    String invoiceDate,
    String supplier,
  }) aggregate(List<CostHistoryEntry> history) {
    final valid = history.where((e) => e.unitCost > 0).toList();
    if (valid.isEmpty) {
      return (
        last: 0,
        avg: 0,
        min: 0,
        max: 0,
        invoiceNo: '',
        invoiceDate: '',
        supplier: '',
      );
    }

    var min = valid.first.unitCost;
    var max = valid.first.unitCost;
    var sumValue = 0;
    var sumQty = 0;
    for (final e in valid) {
      if (e.unitCost < min) min = e.unitCost;
      if (e.unitCost > max) max = e.unitCost;
      final q = e.qty > 0 ? e.qty : 1;
      sumValue += e.unitCost * q;
      sumQty += q;
    }

    // "Gần nhất" = ngày hoá đơn lớn nhất (YYYY-MM-DD so sánh chuỗi được).
    // Dòng không có ngày thì xếp sau cùng theo thứ tự đã ghi — mục đích là
    // luôn có 1 giá "gần nhất" xác định, kể cả file thiếu cột ngày.
    var latest = valid.first;
    for (final e in valid) {
      final a = e.invoiceDate.trim();
      final b = latest.invoiceDate.trim();
      if (a.isEmpty && b.isEmpty) {
        latest = e; // không có ngày → dòng ghi sau thắng
      } else if (a.isNotEmpty && (b.isEmpty || a.compareTo(b) >= 0)) {
        latest = e;
      }
    }

    return (
      last: latest.unitCost,
      avg: sumQty > 0 ? (sumValue / sumQty).round() : 0,
      min: min,
      max: max,
      invoiceNo: latest.invoiceNo,
      invoiceDate: latest.invoiceDate,
      supplier: latest.supplier,
    );
  }

  /// Số dòng lịch sử giữ tối đa cho 1 mặt hàng — đủ để tính bình quân và
  /// chống trùng, đồng thời chặn document Firestore phình vô hạn.
  static const int maxHistoryEntries = 200;

  /// Gộp thêm các dòng hoá đơn mới vào 1 mặt hàng và tính lại giá vốn.
  /// Trả về mặt hàng đã cập nhật + số dòng bị bỏ vì trùng.
  static ({PriceCatalogItem item, int duplicates}) mergeHistory(
    PriceCatalogItem item,
    List<CostHistoryEntry> incoming,
  ) {
    final seen = {for (final e in item.costHistory) e.fingerprint};
    final merged = [...item.costHistory];
    var duplicates = 0;
    for (final e in incoming) {
      if (!seen.add(e.fingerprint)) {
        duplicates++;
        continue;
      }
      merged.add(e);
    }
    if (merged.length > maxHistoryEntries) {
      merged.removeRange(0, merged.length - maxHistoryEntries);
    }

    final agg = aggregate(merged);
    return (
      item: item.copyWith(
        costHistory: merged,
        lastCost: agg.last,
        avgCost: agg.avg,
        minCost: agg.min,
        maxCost: agg.max,
        lastInvoiceNo: agg.invoiceNo,
        lastInvoiceDate: agg.invoiceDate,
        supplier: agg.supplier.isNotEmpty ? agg.supplier : item.supplier,
      ),
      duplicates: duplicates,
    );
  }

  // ── Quyền ────────────────────────────────────────────────────────────────
  /// Người dùng hiện tại có được xem giá vốn không.
  ///
  /// Kiểm ở ĐÂY (tầng service) chứ không chỉ ở UI: mọi đường ra dữ liệu —
  /// bảng giá, Excel xuất, tra giá khi báo giá — đều đi qua service này.
  static Future<bool> canViewCost() async {
    try {
      return await UserService.canViewCostPrice();
    } catch (e) {
      debugPrint('PriceCatalog.canViewCost: $e');
      return false; // lỗi ⇒ giả định KHÔNG có quyền (an toàn hơn)
    }
  }

  /// Chỉ chủ shop/quản lý (người được xem giá vốn) mới được nhập danh mục —
  /// thao tác này ghi giá vốn hàng loạt.
  static Future<bool> canImport() => canViewCost();

  // ── Đọc ──────────────────────────────────────────────────────────────────
  static Future<List<PriceCatalogItem>> all() async {
    try {
      return await _db.getPriceCatalogItems();
    } catch (e) {
      debugPrint('PriceCatalog.all: $e');
      return const [];
    }
  }

  static Future<PriceCatalogItem?> byKey(String importKey) async {
    try {
      return await _db.getPriceCatalogItemByKey(importKey);
    } catch (e) {
      debugPrint('PriceCatalog.byKey: $e');
      return null;
    }
  }

  /// Bản đồ khoá → mặt hàng (dùng khi đối chiếu cả file Excel một lượt).
  static Future<Map<String, PriceCatalogItem>> keyedMap() async {
    final items = await all();
    return {for (final i in items) i.importKey: i};
  }

  // ── Ghi ──────────────────────────────────────────────────────────────────
  /// Lưu 1 mặt hàng + đẩy hàng đợi đồng bộ. Trả về id cục bộ, null nếu lỗi.
  static Future<int?> save(PriceCatalogItem item) async {
    try {
      final shopId = item.shopId ?? await UserService.getCurrentShopId();
      if (shopId == null || shopId.isEmpty) {
        debugPrint('PriceCatalog.save: thiếu shopId');
        return null;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final fid = item.firestoreId?.isNotEmpty == true
          ? item.firestoreId!
          : firestoreIdFor(shopId, item.importKey);

      final toSave = item.copyWith(
        shopId: shopId,
        firestoreId: fid,
        createdAt: item.createdAt > 0 ? item.createdAt : now,
        updatedAt: now,
        isSynced: false,
      );
      final id = await _db.savePriceCatalogItem(toSave);

      await SyncOrchestrator().enqueue(
        entityType: SyncEntityType.priceCatalogItem,
        entityId: id,
        firestoreId: fid,
        operation: SyncOperation.update,
        data: {...toSave.toMap(), 'id': id, 'firestoreId': fid},
      );
      return id;
    } catch (e) {
      debugPrint('PriceCatalog.save ${item.importKey}: $e');
      return null;
    }
  }

  /// Đặt/sửa Giá thu khách cho 1 mặt hàng (0 = xoá giá, về "chưa thiết lập").
  static Future<bool> setCustomerPrice(
    String importKey,
    int price, {
    String? note,
  }) async {
    final item = await byKey(importKey);
    if (item == null) return false;
    final saved = await save(
      item.copyWith(
        customerPrice: price < 0 ? 0 : price,
        note: note ?? item.note,
      ),
    );
    return saved != null;
  }

  /// Xoá mềm 1 mặt hàng khỏi danh mục (vẫn giữ bản ghi để đồng bộ).
  static Future<bool> softDelete(PriceCatalogItem item) async {
    if (item.id == null) return false;
    try {
      await _db.softDeletePriceCatalogItem(item.id!);
      final now = DateTime.now().millisecondsSinceEpoch;
      await SyncOrchestrator().enqueue(
        entityType: SyncEntityType.priceCatalogItem,
        entityId: item.id!,
        firestoreId: item.firestoreId,
        operation: SyncOperation.update,
        data: {
          ...item.copyWith(deleted: true, updatedAt: now).toMap(),
          'id': item.id,
        },
      );
      return true;
    } catch (e) {
      debugPrint('PriceCatalog.softDelete: $e');
      return false;
    }
  }

  // ── Dòng cho Bảng giá ────────────────────────────────────────────────────
  /// Dựng dòng bảng giá từ danh mục (hiện ở tab "Sửa chữa", cạnh phụ tùng).
  ///
  /// [includeCost] = false (nhân viên không có quyền xem giá vốn) ⇒ toàn bộ
  /// trường giá vốn bị **xoá khỏi dữ liệu trả về**, không chỉ ẩn trên UI.
  static Future<List<PriceBookRow>> buildRows({bool? includeCost}) async {
    final showCost = includeCost ?? await canViewCost();
    final items = await all();
    final rows = <PriceBookRow>[];

    for (final item in items) {
      if (item.itemName.trim().isEmpty) continue;
      final safe = showCost
          ? item
          : item.copyWith(
              lastCost: 0,
              avgCost: 0,
              minCost: 0,
              maxCost: 0,
              costHistory: const [],
              supplier: '',
              lastInvoiceNo: '',
              lastInvoiceDate: '',
            );
      final hasPrice = item.customerPrice > 0;
      rows.add(PriceBookRow(
        scope: 'catalog',
        key: item.importKey,
        brand: brandOf(item),
        title: item.itemName,
        note: [
          item.itemName,
          item.model,
          item.sku,
          item.partType,
          item.brand,
        ].where((e) => e.trim().isNotEmpty).join(' '),
        autoCost: safe.lastCost,
        source: hasPrice ? PriceSource.pinned : PriceSource.auto,
        pinnedPrice: hasPrice ? item.customerPrice : null,
        pinnedCost: safe.lastCost > 0 ? safe.lastCost : null,
        pinnedNote: item.note,
        catalog: safe,
      ));
    }

    rows.sort((a, b) {
      final c = a.brand.compareTo(b.brand);
      return c != 0 ? c : a.title.compareTo(b.title);
    });
    return rows;
  }

  /// Nhóm hãng hiển thị: ưu tiên cột "Hãng" của file Excel (đáng tin), không
  /// có thì quét mọi từ trong tên để tìm hãng máy đã biết, cuối cùng "Khác".
  static String brandOf(PriceCatalogItem item) {
    final explicit = item.brand.trim();
    if (explicit.isNotEmpty) {
      final mapped = ProductConstants.mapBrand(explicit);
      return mapped.isNotEmpty && mapped != 'KHÁC'
          ? mapped
          : explicit.toUpperCase();
    }
    for (final w in '${item.itemName} ${item.model}'.trim().split(
      RegExp(r'\s+'),
    )) {
      final b = ProductConstants.mapBrand(w);
      if (b.isNotEmpty && b != 'KHÁC') return b;
    }
    return 'Khác';
  }

  // ── Tra cứu khi báo giá ──────────────────────────────────────────────────
  /// Tra Giá thu khách theo model / tên linh kiện người dùng đang gõ.
  ///
  /// CHỈ trả giá thu khách — không bao giờ lấy giá vốn thay thế. Không tìm
  /// thấy, hoặc tìm thấy nhưng mặt hàng chưa đặt giá ⇒ trả về mặt hàng khớp
  /// (nếu có) kèm `price == null` để màn báo giá hiển thị "chưa thiết lập".
  static Future<CatalogLookup> lookup(String query) async {
    final q = _n(query);
    if (q.isEmpty) return const CatalogLookup();

    final items = await all();
    PriceCatalogItem? best;
    var bestScore = 0;

    for (final item in items) {
      final haystacks = <String>[
        _n(item.sku),
        _n(item.itemName),
        _n('${item.itemName} ${item.model}'),
        _n(item.model),
      ];
      var score = 0;
      // Khớp SKU tuyệt đối là chắc chắn nhất.
      if (haystacks[0].isNotEmpty && haystacks[0] == q) {
        score = 1000;
      } else if (haystacks[1] == q || haystacks[2] == q) {
        score = 900;
      } else {
        for (final h in haystacks) {
          if (h.isEmpty) continue;
          if (h.contains(q) || q.contains(h)) {
            final len = h.length < q.length ? h.length : q.length;
            final s = 50 + len;
            if (s > score) score = s;
          }
        }
      }
      // Ưu tiên mặt hàng ĐÃ có giá thu khách khi điểm ngang nhau — mục đích
      // của tra cứu là báo giá cho khách.
      if (item.customerPrice > 0) score += 5;
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }

    if (best == null || bestScore < 50) return const CatalogLookup();
    final showCost = await canViewCost();
    return CatalogLookup(
      item: showCost
          ? best
          : best.copyWith(
              lastCost: 0,
              avgCost: 0,
              minCost: 0,
              maxCost: 0,
              costHistory: const [],
            ),
      price: best.customerPrice > 0 ? best.customerPrice : null,
      referenceCost: showCost && best.lastCost > 0 ? best.lastCost : null,
    );
  }
}

/// Kết quả tra danh mục giá cho luồng báo giá.
class CatalogLookup {
  /// Mặt hàng khớp (null = không tìm thấy trong danh mục).
  final PriceCatalogItem? item;

  /// Giá thu khách — null nghĩa là CHƯA thiết lập, tuyệt đối không thay bằng
  /// giá vốn.
  final int? price;

  /// Giá vốn gần nhất để chủ shop tham khảo. Null với người không có quyền
  /// xem giá vốn. Chỉ để xem — KHÔNG ghi đè giá vốn thực tế của đơn hàng.
  final int? referenceCost;

  const CatalogLookup({this.item, this.price, this.referenceCost});

  bool get found => item != null;
  bool get hasPrice => price != null && price! > 0;

  /// Thông báo chuẩn khi mặt hàng có trong danh mục nhưng chưa có giá thu.
  static const String noPriceMessage = 'Chưa thiết lập giá thu khách';
}
