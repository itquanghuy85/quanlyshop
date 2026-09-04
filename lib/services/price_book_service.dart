import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/product_constants.dart';
import '../data/db_helper.dart';
import '../models/price_book_models.dart';
import '../models/product_model.dart';
import '../models/repair_model.dart';
import '../services/sync_orchestrator.dart';
import '../utils/excel_export_helper.dart';
import '../utils/money_utils.dart';
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
  static const _kSeasonPct = 'pricebook_season_pct_v1';

  // ── Hệ số mùa vụ (áp cho GIÁ ĐỀ XUẤT, không áp cho giá đã ghim) ──────────
  static Future<int> seasonPct() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_kSeasonPct) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> setSeasonPct(int pct) async {
    final prefs = await SharedPreferences.getInstance();
    final v = pct.clamp(-90, 300);
    if (v == 0) {
      await prefs.remove(_kSeasonPct);
    } else {
      await prefs.setInt(_kSeasonPct, v);
    }
  }

  static int _applySeason(int price, int pct) =>
      pct == 0 ? price : (price * (100 + pct) / 100).round();

  // ── Excel: xuất / nhập bảng giá ─────────────────────────────────────────
  static const _xlHeaders = [
    'Nhóm',
    'Tên (model · lỗi / model · biến thể)',
    'Giá đề xuất',
    'Giá vốn ĐX',
    'Giá NIÊM YẾT',
    'Giá vốn NY',
    'Ghi chú',
    'Số mẫu',
    'Độ tin cậy',
    '_khoá (không sửa)',
  ];

  static List<dynamic> _xlRow(PriceBookRow r) => [
        r.brand,
        r.title,
        r.autoPrice,
        r.autoCost,
        r.isPinned ? (r.pinnedPrice ?? 0) : 0,
        r.isPinned ? (r.pinnedCost ?? 0) : 0,
        r.pinnedNote ?? '',
        r.sampleCount,
        r.confidenceLabel,
        r.key,
      ];

  static Future<void> exportToExcel(BuildContext context) async {
    final repair = await buildRepairRows();
    final sale = await buildSaleRows();
    final excel = Excel.createExcel();
    final def = excel.getDefaultSheet();
    ExcelExportHelper.writeSheet(
      excel['Sửa chữa'],
      _xlHeaders,
      repair.map(_xlRow).toList(),
    );
    ExcelExportHelper.writeSheet(
      excel['Bán hàng'],
      _xlHeaders,
      sale.map(_xlRow).toList(),
    );
    if (def != null && def != 'Sửa chữa' && def != 'Bán hàng') {
      excel.delete(def);
    }
    final ts = DateTime.now();
    final name =
        'BangGia_${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}.xlsx';
    if (context.mounted) {
      await ExcelExportHelper.saveAndShare(excel, name, context);
    }
  }

  /// Đọc file xlsx → GHIM các dòng có "Giá NIÊM YẾT" > 0 (khớp theo cột _khoá).
  static Future<({int pinned, int cleared, List<String> errors})>
      importFromExcel(Uint8List bytes) async {
    final errors = <String>[];
    int pinned = 0, cleared = 0;
    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      return (pinned: 0, cleared: 0, errors: ['File Excel không hợp lệ: $e']);
    }
    final pins = await loadPins();

    for (final sheet in excel.tables.values) {
      if (sheet.maxRows < 2) continue;
      final head = <String, int>{};
      final h0 = sheet.row(0);
      for (var c = 0; c < h0.length; c++) {
        head[(h0[c]?.value?.toString() ?? '').trim().toLowerCase()] = c;
      }
      final ciKey = head['_khoá (không sửa)'];
      final ciPrice = head['giá niêm yết'];
      final ciCost = head['giá vốn ny'];
      final ciNote = head['ghi chú'];
      if (ciKey == null || ciPrice == null) continue;

      for (var rIdx = 1; rIdx < sheet.maxRows; rIdx++) {
        final row = sheet.row(rIdx);
        String cell(int? i) => (i == null || i >= row.length)
            ? ''
            : (row[i]?.value?.toString() ?? '');
        final key = cell(ciKey).trim();
        if (!(key.startsWith('r|') || key.startsWith('s|'))) continue;
        final price = MoneyUtils.parseCurrency(cell(ciPrice));
        final cost = MoneyUtils.parseCurrency(cell(ciCost));
        final note = cell(ciNote).trim();
        try {
          if (price > 0) {
            pins[key] = PricePin(
              price: price,
              cost: cost > 0 ? cost : null,
              note: note,
              pinnedAt: DateTime.now().millisecondsSinceEpoch,
              pinnedBy: FirebaseAuth.instance.currentUser?.email
                      ?.split('@')
                      .first ??
                  '',
            );
            pinned++;
          } else if (pins.remove(key) != null) {
            cleared++;
          }
        } catch (e) {
          errors.add('Dòng ${rIdx + 1}: $e');
        }
      }
    }
    await _savePins(pins);
    return (pinned: pinned, cleared: cleared, errors: errors);
  }

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

  /// Khoá cho 1 phụ tùng/linh kiện tham khảo trong tab Sửa chữa (vd "Pin
  /// iPhone 11 Pro Max"). Khác `repairKey`/`saleKey` — không gắn với model +
  /// lỗi/model + biến thể, chỉ theo tên phụ tùng.
  static String partKey(String name) => 'p|${_n(name)}';

  /// Dòng "phụ tùng/linh kiện" cho tab Sửa chữa — để nhân viên tham khảo
  /// giá vốn khi báo giá, KHÔNG phải bảng giá bán riêng cho phụ tùng.
  /// Nguồn: (1) phụ tùng thật đang có trong Kho phụ tùng — giá vốn = giá
  /// đang lưu thật (không phải trung vị lịch sử); (2) ghim "mồ côi" — tên đã
  /// ghim giá (vd từ hoá đơn NCC) nhưng CHƯA có phụ tùng thật trong kho —
  /// vẫn hiện để tham khảo, KHÔNG tạo tồn kho ảo.
  static Future<List<PriceBookRow>> buildPartRows() async {
    final db = DBHelper();
    final pins = await loadPins();
    List<Map<String, dynamic>> parts;
    try {
      parts = await db.getAllParts();
    } catch (e) {
      debugPrint('PriceBook.buildPartRows: $e');
      parts = const [];
    }

    final rows = <PriceBookRow>[];
    final usedKeys = <String>{};
    for (final p in parts) {
      final name = ((p['partName'] as String?) ?? '').trim();
      final cost = (p['cost'] as int?) ?? 0;
      if (name.isEmpty || cost <= 0) continue;
      final key = partKey(name);
      if (!usedKeys.add(key)) continue; // trùng tên chuẩn hoá — giữ dòng đầu
      final pin = pins[key];
      rows.add(PriceBookRow(
        scope: 'part',
        key: key,
        brand: _brandOfPart(name),
        title: name,
        note: name,
        autoCost: cost,
        source: pin != null ? PriceSource.pinned : PriceSource.auto,
        pinnedPrice: pin?.price,
        pinnedCost: pin?.cost,
        pinnedNote: pin?.note,
      ));
    }

    pins.forEach((key, pin) {
      if (!key.startsWith('p|') || usedKeys.contains(key)) return;
      final name = (pin.displayName ?? '').trim().isNotEmpty
          ? pin.displayName!.trim()
          : key.substring(2);
      final brandHint = (pin.brandHint ?? '').trim();
      rows.add(PriceBookRow(
        scope: 'part',
        key: key,
        brand: brandHint.isNotEmpty ? brandHint : _brandOfPart(name),
        title: name,
        note: name,
        source: PriceSource.pinned,
        pinnedPrice: pin.price,
        pinnedCost: pin.cost,
        pinnedNote: pin.note,
      ));
    });

    rows.sort((a, b) {
      final c = a.brand.compareTo(b.brand);
      return c != 0 ? c : a.title.compareTo(b.title);
    });
    return rows;
  }

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
    String? displayName,
    String? displayExtra,
    String? brandHint,
  }) async {
    final pins = await loadPins();
    pins[key] = PricePin(
      price: price,
      cost: cost,
      note: note,
      displayName: displayName,
      displayExtra: displayExtra,
      brandHint: brandHint,
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

  /// Tên phụ tùng thường theo mẫu "[loại phụ tùng] [hãng] [model]" (vd "Pin
  /// iPhone 13", "Màn hình Oppo A74") — hãng máy KHÔNG nằm ở từ đầu tiên như
  /// tên model sửa chữa/SP, nên không dùng [_brandOf] (chỉ xét từ đầu) cho
  /// phụ tùng — sẽ gộp nhầm "Pin iPhone 13" vào nhóm "PIN" thay vì "IPHONE".
  /// Quét toàn bộ các từ trong tên, lấy từ đầu tiên khớp 1 hãng máy đã biết;
  /// không từ nào khớp thì xếp "Khác" (không dùng từ đầu làm hãng giả).
  static String _brandOfPart(String name) {
    for (final w in name.trim().split(RegExp(r'\s+'))) {
      final b = ProductConstants.mapBrand(w);
      if (b.isNotEmpty && b != 'KHÁC') return b;
    }
    return 'Khác';
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
    final season = await seasonPct();
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
    final usedKeys = <String>{};
    groups.forEach((gk, list) {
      final lab = labels[gk]!;
      final prices = list.map((e) => e.price).toList();
      final costs = list.map((e) => e.cost).toList()..removeWhere((c) => c < 0);
      final sortedP = [...prices]..sort();
      final key = repairKey(lab.model, lab.issue);
      usedKeys.add(key);
      final pin = pins[key];
      rows.add(PriceBookRow(
        scope: 'repair',
        key: key,
        brand: _brandOf(lab.model),
        title: lab.issue.isEmpty
            ? lab.model
            : '${lab.model} · ${lab.issue}',
        note: '${lab.model} ${lab.issue}',
        src1: lab.model,
        src2: lab.issue,
        autoPrice: _applySeason(_median(prices), season),
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

    // Ghim "mồ côi" — mục sửa chữa tạo tay (chưa từng có đơn thật nào) qua
    // luồng "Thêm mục sửa chữa mới" trên Bảng giá. Cho phép chủ shop dựng
    // sẵn bảng giá trước khi khách mang máy đến, không phải đợi có lịch sử.
    pins.forEach((key, pin) {
      if (!key.startsWith('r|') || usedKeys.contains(key)) return;
      final model = (pin.displayName ?? '').trim();
      if (model.isEmpty) return; // thiếu tên gốc — bỏ qua an toàn
      final issue = (pin.displayExtra ?? '').trim();
      rows.add(PriceBookRow(
        scope: 'repair',
        key: key,
        brand: _brandOf(model),
        title: issue.isEmpty ? model : '$model · $issue',
        note: '$model $issue',
        src1: model,
        src2: issue,
        source: PriceSource.pinned,
        pinnedPrice: pin.price,
        pinnedCost: pin.cost,
        pinnedNote: pin.note,
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
    final season = await seasonPct();
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
        src1: lab.brand,
        src2: lab.model,
        src3: lab.cap,
        src4: lab.cond,
        autoPrice: _applySeason(_median(prices), season),
        autoCost: _median(costs),
        minPrice: sortedP.isEmpty ? 0 : sortedP.first,
        maxPrice: sortedP.isEmpty ? 0 : sortedP.last,
        // Đếm trên CÙNG danh sách (chỉ giá > 0) với confidenceLabel, không
        // đếm cả SP giá=0 — tránh nhãn mâu thuẫn kiểu "1 mẫu · Không có dữ liệu".
        sampleCount: prices.length,
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
        final season = await seasonPct();
        return PriceResolution(
          price: _applySeason(s.medianSalePrice, season),
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
        final season = await seasonPct();
        return PriceResolution(
          price: _applySeason(s.medianSalePrice, season),
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

  // ── Xem các đơn / SP đã tạo ra dòng bảng giá ────────────────────────────
  /// Các đơn sửa (Xong/Đã giao) khớp model + lỗi của 1 dòng bảng giá sửa chữa.
  static Future<List<Repair>> repairSourcesFor(String model, String issue) async {
    try {
      final db = DBHelper();
      final all = await db.getRepairsForPricing(
        statuses: PricingEngineConfig.pricingStatuses,
      );
      final nm = _n(model);
      final ni = _n(issue);
      return all.where((r) {
        if (r.deleted || r.price <= 0) return false;
        if (_n(r.model) != nm) return false;
        return _n(_issueOf(r)) == ni;
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('PriceBook.repairSourcesFor: $e');
      return const [];
    }
  }

  /// Các SP trong kho khớp (hãng · model · dung lượng · tình trạng).
  static Future<List<Product>> saleSourcesFor(
    String brand,
    String model,
    String? capacity,
    String? condition,
  ) async {
    try {
      final db = DBHelper();
      final all = await db.getProductsForPricing();
      final bk = saleKey(brand, model, capacity, condition);
      return all.where((p) {
        final m = (p.model ?? '').trim();
        if (m.isEmpty) return false;
        final b = p.brand.trim().isEmpty ? _brandOf(m) : p.brand.trim();
        return saleKey(b, m, p.capacity, p.condition) == bk;
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('PriceBook.saleSourcesFor: $e');
      return const [];
    }
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
