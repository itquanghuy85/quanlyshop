import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/product_constants.dart';
import '../data/db_helper.dart';
import '../models/price_book_models.dart';
import '../models/product_model.dart';
import '../models/repair_model.dart';
import '../services/sync_orchestrator.dart';
import '../utils/vietnamese_utils.dart';
import 'pricing_engine_config.dart';
import 'pricing_engine_service.dart';
import 'product_pricing_service.dart';

/// "Bảng giá" — tổng hợp giá đề xuất (trung vị lịch sử) cho sửa chữa & bán
/// hàng, cho phép chủ shop GHIM giá niêm yết, và tra giá cho form tạo đơn.
///
/// Toàn bộ tính toán chạy local trên SQLite (tái dùng `PricingEngineService`
/// và `ProductPricingService`). Giá ghim lưu trong SharedPreferences (theo
/// máy — chưa đồng bộ đám mây).
class PriceBookService {
  PriceBookService._();

  static const _kPins = 'pricebook_pins_v1';

  // ── Khoá ổn định ─────────────────────────────────────────────────────────
  static String _n(String? s) =>
      VietnameseUtils.normalize((s ?? '').trim().replaceAll(RegExp(r'\s+'), ' '));

  static String repairKey(String model, String? issue) =>
      'r|${_n(model)}|${_n(issue)}';

  static String saleKey(
    String brand,
    String? model,
    String? capacity,
    String? condition,
  ) =>
      's|${_n(brand)}|${_n(model)}|${_n(capacity)}|${_n(condition)}';

  // ── Ghim ─────────────────────────────────────────────────────────────────
  static Future<Map<String, PricePin>> loadPins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPins);
      if (raw == null || raw.isEmpty) return {};
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (k, v) => MapEntry(k, PricePin.fromJson(v as Map<String, dynamic>)),
      );
    } catch (e) {
      debugPrint('PriceBook.loadPins: $e');
      return {};
    }
  }

  static Future<void> _savePins(Map<String, PricePin> pins) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPins,
      jsonEncode(pins.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  static Future<void> pin(
    String key, {
    required int price,
    int? cost,
    String note = '',
  }) async {
    final pins = await loadPins();
    pins[key] = PricePin(
      price: price,
      cost: cost,
      note: note,
      pinnedAt: DateTime.now().millisecondsSinceEpoch,
      pinnedBy: FirebaseAuth.instance.currentUser?.displayName ??
          FirebaseAuth.instance.currentUser?.email?.split('@').first ??
          '',
    );
    await _savePins(pins);
  }

  static Future<void> unpin(String key) async {
    final pins = await loadPins();
    if (pins.remove(key) != null) await _savePins(pins);
  }

  // ── Số học ───────────────────────────────────────────────────────────────
  static int _median(List<int> xs) {
    if (xs.isEmpty) return 0;
    final s = [...xs]..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : ((s[m - 1] + s[m]) / 2).round();
  }

  static String _confLabel(int n) {
    if (n <= 0) return 'Không có dữ liệu';
    if (n <= 2) return 'Dữ liệu quá ít';
    if (n <= 4) return 'Thấp';
    if (n <= 9) return 'Khá';
    return 'Tốt';
  }

  static String _brandOf(String model) {
    final first = model.trim().split(RegExp(r'\s+')).first;
    final b = ProductConstants.mapBrand(first);
    return b.isEmpty || b == 'KHÁC'
        ? (first.isEmpty ? 'Khác' : first.toUpperCase())
        : b;
  }

  static String _issueOf(Repair r) {
    if (r.services.length == 1) return r.services.first.serviceName.trim();
    if (r.services.isEmpty) return r.issue.trim();
    return r.services.map((s) => s.serviceName.trim()).join(' + ');
  }

  // ── Dựng bảng giá ────────────────────────────────────────────────────────
  static Future<List<PriceBookRow>> buildRepairRows() async {
    final db = DBHelper();
    final pins = await loadPins();
    List<Repair> repairs;
    try {
      repairs = await db.getRepairsForPricing(
        statuses: PricingEngineConfig.pricingStatuses,
      );
    } catch (e) {
      debugPrint('PriceBook.buildRepairRows: $e');
      return const [];
    }

    final groups = <String, List<Repair>>{};
    final labels = <String, ({String model, String issue})>{};
    for (final r in repairs) {
      if (r.deleted) continue;
      final model = r.model.trim();
      if (model.isEmpty || r.price <= 0) continue;
      final issue = _issueOf(r);
      final gk = '${_n(model)}##${_n(issue)}';
      groups.putIfAbsent(gk, () => []).add(r);
      labels.putIfAbsent(gk, () => (model: model, issue: issue));
    }

    final rows = <PriceBookRow>[];
    groups.forEach((gk, list) {
      final lab = labels[gk]!;
      final prices = list.map((e) => e.price).toList();
      final costs = list.map((e) => e.cost).toList()..removeWhere((c) => c < 0);
      final sortedP = [...prices]..sort();
      final key = repairKey(lab.model, lab.issue);
      final pin = pins[key];
      rows.add(PriceBookRow(
        scope: 'repair',
        key: key,
        brand: _brandOf(lab.model),
        title: lab.issue.isEmpty
            ? lab.model
            : '${lab.model} · ${lab.issue}',
        note: '${lab.model} ${lab.issue}',
        autoPrice: _median(prices),
        autoCost: _median(costs),
        minPrice: sortedP.first,
        maxPrice: sortedP.last,
        sampleCount: list.length,
        confidenceLabel: _confLabel(list.length),
        source: pin != null ? PriceSource.pinned : PriceSource.auto,
        pinnedPrice: pin?.price,
        pinnedCost: pin?.cost,
        pinnedNote: pin?.note,
      ));
    });

    rows.sort((a, b) {
      final c = a.brand.compareTo(b.brand);
      return c != 0 ? c : a.title.compareTo(b.title);
    });
    return rows;
  }

  static Future<List<PriceBookRow>> buildSaleRows() async {
    final db = DBHelper();
    final pins = await loadPins();
    List<Product> products;
    try {
      products = await db.getProductsForPricing();
    } catch (e) {
      debugPrint('PriceBook.buildSaleRows: $e');
      return const [];
    }

    final groups = <String, List<Product>>{};
    final labels = <String, ({String brand, String model, String cap, String cond})>{};
    for (final p in products) {
      final model = (p.model ?? '').trim();
      if (model.isEmpty) continue;
      final brand = p.brand.trim().isEmpty ? _brandOf(model) : p.brand.trim();
      final cap = (p.capacity ?? '').trim();
      final cond = (p.condition).trim();
      final gk = '${_n(brand)}##${_n(model)}##${_n(cap)}##${_n(cond)}';
      groups.putIfAbsent(gk, () => []).add(p);
      labels.putIfAbsent(
        gk,
        () => (brand: brand, model: model, cap: cap, cond: cond),
      );
    }

    final rows = <PriceBookRow>[];
    groups.forEach((gk, list) {
      final lab = labels[gk]!;
      final prices = list.map((e) => e.price).where((v) => v > 0).toList();
      final costs = list.map((e) => e.cost).where((v) => v > 0).toList();
      final sortedP = [...prices]..sort();
      final key = saleKey(lab.brand, lab.model, lab.cap, lab.cond);
      final pin = pins[key];
      final titleExtra = [
        if (lab.cap.isNotEmpty) lab.cap,
        if (lab.cond.isNotEmpty) '(${lab.cond})',
      ].join(' ');
      rows.add(PriceBookRow(
        scope: 'sale',
        key: key,
        brand: lab.brand,
        title: titleExtra.isEmpty
            ? lab.model
            : '${lab.model} $titleExtra',
        note: '${lab.brand} ${lab.model} ${lab.cap} ${lab.cond}',
        autoPrice: _median(prices),
        autoCost: _median(costs),
        minPrice: sortedP.isEmpty ? 0 : sortedP.first,
        maxPrice: sortedP.isEmpty ? 0 : sortedP.last,
        sampleCount: list.length,
        confidenceLabel: _confLabel(prices.length),
        source: pin != null ? PriceSource.pinned : PriceSource.auto,
        pinnedPrice: pin?.price,
        pinnedCost: pin?.cost,
        pinnedNote: pin?.note,
      ));
    });

    rows.sort((a, b) {
      final c = a.brand.compareTo(b.brand);
      return c != 0 ? c : a.title.compareTo(b.title);
    });
    return rows;
  }

  // ── Tra giá cho form tạo đơn ─────────────────────────────────────────────
  /// Ưu tiên: GHIM → trung vị lịch sử → không có.
  static Future<PriceResolution> resolveRepair({
    required String model,
    String? issue,
  }) async {
    if (model.trim().isEmpty) return const PriceResolution();
    final pins = await loadPins();
    final pin = pins[repairKey(model, issue)];
    if (pin != null && pin.price > 0) {
      return PriceResolution(
        price: pin.price,
        cost: pin.cost,
        source: PriceSource.pinned,
        confidenceLabel: 'Niêm yết',
      );
    }
    try {
      final s = await PricingEngineService.getSuggestion(
        model: model,
        issueOrService: issue,
      );
      if (s != null && s.medianSalePrice > 0) {
        return PriceResolution(
          price: s.medianSalePrice,
          cost: s.medianCost,
          source: PriceSource.auto,
          sampleCount: s.sampleCount,
          confidenceLabel: s.confidence.label,
        );
      }
    } catch (e) {
      debugPrint('PriceBook.resolveRepair: $e');
    }
    return const PriceResolution();
  }

  static Future<PriceResolution> resolveSale({
    required String brand,
    required String model,
    String? capacity,
    String? condition,
  }) async {
    if (model.trim().isEmpty) return const PriceResolution();
    final pins = await loadPins();
    final pin = pins[saleKey(brand, model, capacity, condition)];
    if (pin != null && pin.price > 0) {
      return PriceResolution(
        price: pin.price,
        cost: pin.cost,
        source: PriceSource.pinned,
        confidenceLabel: 'Niêm yết',
      );
    }
    try {
      final s = await ProductPricingService.getSuggestion(model: model);
      if (s != null && s.medianSalePrice > 0) {
        return PriceResolution(
          price: s.medianSalePrice,
          cost: s.medianCost,
          source: PriceSource.auto,
          sampleCount: s.sampleCount,
          confidenceLabel: _confLabel(s.sampleCount),
        );
      }
    } catch (e) {
      debugPrint('PriceBook.resolveSale: $e');
    }
    return const PriceResolution();
  }

  // ── Áp giá hàng loạt cho SP chưa có giá ─────────────────────────────────
  /// Dry-run: trả về danh sách đề xuất, CHƯA ghi. Gọi [commitSalePrices] để ghi.
  static Future<List<SalePriceProposal>> proposeSalePrices() async {
    final db = DBHelper();
    List<Product> products;
    try {
      products = await db.getProductsForPricing();
    } catch (_) {
      return const [];
    }
    final rows = await buildSaleRows();
    final byKey = {for (final r in rows) r.key: r};

    final out = <SalePriceProposal>[];
    for (final p in products) {
      if (p.id == null) continue;
      if (p.price > 0) continue; // chỉ SP chưa có giá bán
      if (p.quantity <= 0) continue;
      if (p.isPending) continue;
      if (p.status == 0) continue;
      final model = (p.model ?? '').trim();
      if (model.isEmpty) continue;
      final brand = p.brand.trim().isEmpty ? _brandOf(model) : p.brand.trim();
      final row = byKey[saleKey(brand, model, p.capacity, p.condition)];
      final suggested = row?.effectivePrice ?? 0;
      if (suggested <= 0) continue;
      out.add(SalePriceProposal(
        productId: p.id!,
        label: p.name.trim().isEmpty ? model : p.name.trim(),
        oldPrice: p.price,
        newPrice: suggested,
      ));
    }
    return out;
  }

  /// Ghi giá cho các đề xuất đã chọn.
  static Future<int> commitSalePrices(List<SalePriceProposal> list) async {
    final db = DBHelper();
    final all = await db.getProductsForPricing();
    final byId = {for (final p in all) if (p.id != null) p.id!: p};

    var n = 0;
    for (final prop in list) {
      final p = byId[prop.productId];
      if (p == null) continue;
      try {
        p.price = prop.newPrice;
        p.isSynced = false;
        p.updatedAt = DateTime.now().millisecondsSinceEpoch;
        await db.upsertProduct(p);
        n++;
        await SyncOrchestrator().enqueue(
          entityType: SyncEntityType.product,
          entityId: prop.productId,
          firestoreId: p.firestoreId,
          operation: SyncOperation.update,
          data: p.toMap(),
        );
      } catch (e) {
        debugPrint('PriceBook.commitSalePrices ${prop.productId}: $e');
      }
    }
    if (n > 0) {
      try {
        await SyncOrchestrator().syncAll();
      } catch (_) {}
    }
    return n;
  }
}
