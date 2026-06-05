import 'package:excel/excel.dart' hide Border;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';
import '../utils/money_utils.dart';

/// Result of a single import operation.
class ImportResult {
  final String dataType;
  final int total;
  final int success;
  final List<String> errors;

  const ImportResult({
    required this.dataType,
    required this.total,
    required this.success,
    this.errors = const [],
  });

  int get failed => total - success;
  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() =>
      '$dataType: $success/$total thành công${hasErrors ? ', ${errors.length} lỗi' : ''}';
}

/// Service that parses XLSX files exported by ExcelExportHelper and
/// imports rows into SQLite + Firestore.
///
/// Column matching is header-name-based (case-insensitive, diacritics-sensitive).
/// Unknown or empty columns are gracefully skipped.
class ExcelImportService {
  static final _db = DBHelper();
  static final _dtFmt = DateFormat('dd/MM/yyyy HH:mm');
  static final _dFmt = DateFormat('dd/MM/yyyy');

  // ────────────────────────────────────────────────────────────────────────
  //  PARSE HELPERS
  // ────────────────────────────────────────────────────────────────────────

  static int _parseMoney(String s) {
    if (s.isEmpty || s == '***') return 0;
    return MoneyUtils.parseCurrency(s);
  }

  static int _parseTs(String s) {
    if (s.isEmpty) return 0;
    try {
      return _dtFmt.parse(s).millisecondsSinceEpoch;
    } catch (_) {}
    try {
      return _dFmt.parse(s).millisecondsSinceEpoch;
    } catch (_) {}
    return 0;
  }

  static String _cellStr(Data? cell) {
    final v = cell?.value;
    if (v == null) return '';
    if (v is TextCellValue) return v.value.toString().trim();
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) {
      final d = v.value;
      if (d == d.truncateToDouble()) return d.toInt().toString();
      return d.toString();
    }
    if (v is BoolCellValue) return v.value.toString();
    return v.toString().trim();
  }

  /// Build a map of lowercased header name → column index.
  static Map<String, int> _headers(Sheet sheet) {
    final map = <String, int>{};
    if (sheet.maxRows < 1) return map;
    final row = sheet.row(0);
    for (int i = 0; i < row.length; i++) {
      final h = _cellStr(row[i]).toLowerCase();
      if (h.isNotEmpty) map[h] = i;
    }
    return map;
  }

  static String _col(List<Data?> row, Map<String, int> h, String name) {
    final idx = h[name.toLowerCase()];
    if (idx == null || idx >= row.length) return '';
    return _cellStr(row[idx]);
  }

  static int _repairStatusInt(String s) {
    final lower = s.toLowerCase();
    if (lower.contains('giao')) return 4;
    if (lower.contains('xong') || lower.contains('đã sửa')) return 3;
    if (lower.contains('đang sửa')) return 2;
    return 1;
  }

  // ────────────────────────────────────────────────────────────────────────
  //  SHEET DETECTION
  // ────────────────────────────────────────────────────────────────────────

  /// Find the first sheet whose name loosely matches the given keywords.
  static Sheet? _findSheet(Excel excel, List<String> keywords) {
    for (final name in excel.tables.keys) {
      final lower = name.toLowerCase();
      if (keywords.any((k) => lower.contains(k.toLowerCase()))) {
        return excel.tables[name];
      }
    }
    return null;
  }

  // ────────────────────────────────────────────────────────────────────────
  //  1. IMPORT REPAIRS
  // ────────────────────────────────────────────────────────────────────────

  static Future<ImportResult> importRepairs(
    Uint8List bytes, {
    required void Function(int current, int total, String msg) onProgress,
  }) async {
    const type = 'Đơn sửa chữa';
    final shopId = await UserService.getCurrentShopId() ?? '';
    if (shopId.isEmpty && !UserService.isCurrentUserSuperAdmin()) {
      return const ImportResult(
        dataType: type,
        total: 0,
        success: 0,
        errors: ['Không tìm thấy thông tin cửa hàng'],
      );
    }

    final excel = Excel.decodeBytes(bytes);
    final sheet = _findSheet(excel, ['sửa', 'don sua', 'repair']) ??
        (excel.tables.isEmpty ? null : excel.tables.values.first);

    if (sheet == null || sheet.maxRows < 2) {
      return ImportResult(
        dataType: type,
        total: 0,
        success: 0,
        errors: ['File trống hoặc không có dữ liệu sửa chữa'],
      );
    }

    final h = _headers(sheet);
    final total = sheet.maxRows - 1;
    int success = 0;
    final errors = <String>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (int i = 1; i <= total; i++) {
      onProgress(i, total, 'Đang nhập đơn $i/$total…');
      final row = sheet.row(i);

      final customerName = _col(row, h, 'khách hàng');
      final model = _col(row, h, 'model');
      if (customerName.isEmpty && model.isEmpty) continue; // blank row

      final phone = _col(row, h, 'sđt');
      final issue = _col(row, h, 'lỗi');
      final createdAtStr = _col(row, h, 'ngày nhận');
      final createdAt = createdAtStr.isEmpty ? now : (_parseTs(createdAtStr) == 0 ? now : _parseTs(createdAtStr));

      final finishedAtStr = _col(row, h, 'ngày sửa xong');
      final deliveredAtStr = _col(row, h, 'ngày giao');
      final priceStr = _col(row, h, 'giá');
      final costStr = _col(row, h, 'chi phí');
      final statusStr = _col(row, h, 'trạng thái');
      final warranty = _col(row, h, 'bảo hành');

      final fid = 'import_rep_${now}_$i';

      final repair = Repair(
        firestoreId: fid,
        shopId: shopId,
        customerName: customerName.isEmpty ? 'Khách lẻ' : customerName,
        phone: phone.isEmpty ? 'N/A' : phone,
        model: model.isEmpty ? 'Không rõ' : model,
        issue: issue.isEmpty ? 'Không rõ' : issue,
        accessories: _col(row, h, 'phụ kiện kèm'),
        color: _col(row, h, 'màu').let((v) => v.isEmpty ? null : v),
        imei: _col(row, h, 'imei').let((v) => v.isEmpty ? null : v),
        warranty: warranty.isEmpty ? 'Không bảo hành' : warranty,
        price: _parseMoney(priceStr),
        cost: _parseMoney(costStr),
        paymentMethod: _col(row, h, 'pt thanh toán').let((v) => v.isEmpty ? 'TIỀN MẶT' : v),
        createdBy: _col(row, h, 'người nhận').let((v) => v.isEmpty ? null : v),
        repairedBy: _col(row, h, 'người sửa').let((v) => v.isEmpty ? null : v),
        deliveredBy: _col(row, h, 'người giao').let((v) => v.isEmpty ? null : v),
        finishedAt: finishedAtStr.isEmpty ? null : _parseTs(finishedAtStr).let((ms) => ms == 0 ? null : ms),
        deliveredAt: deliveredAtStr.isEmpty ? null : _parseTs(deliveredAtStr).let((ms) => ms == 0 ? null : ms),
        notes: _col(row, h, 'ghi chú').let((v) => v.isEmpty ? null : v),
        status: statusStr.isEmpty ? 1 : _repairStatusInt(statusStr),
        createdAt: createdAt,
        isSynced: false,
      );

      try {
        await _db.upsertRepair(repair);
        await FirestoreService.upsertRepair(repair);
        success++;
      } catch (e) {
        debugPrint('importRepairs row $i error: $e');
        errors.add('Hàng $i: $e');
      }
    }

    return ImportResult(
      dataType: type,
      total: total,
      success: success,
      errors: errors,
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  //  2. IMPORT SALES
  // ────────────────────────────────────────────────────────────────────────

  static Future<ImportResult> importSales(
    Uint8List bytes, {
    required void Function(int, int, String) onProgress,
  }) async {
    const type = 'Đơn mua bán';
    final shopId = await UserService.getCurrentShopId() ?? '';
    if (shopId.isEmpty && !UserService.isCurrentUserSuperAdmin()) {
      return const ImportResult(
        dataType: type,
        total: 0,
        success: 0,
        errors: ['Không tìm thấy thông tin cửa hàng'],
      );
    }

    final excel = Excel.decodeBytes(bytes);
    final sheet = _findSheet(excel, ['bán', 'don ban', 'sale']) ??
        (excel.tables.isEmpty ? null : excel.tables.values.first);

    if (sheet == null || sheet.maxRows < 2) {
      return ImportResult(
        dataType: type,
        total: 0,
        success: 0,
        errors: ['File trống hoặc không có dữ liệu mua bán'],
      );
    }

    final h = _headers(sheet);
    final total = sheet.maxRows - 1;
    int success = 0;
    final errors = <String>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (int i = 1; i <= total; i++) {
      onProgress(i, total, 'Đang nhập đơn bán $i/$total…');
      final row = sheet.row(i);

      final customerName = _col(row, h, 'khách hàng');
      final productNames = _col(row, h, 'sản phẩm');
      if (customerName.isEmpty && productNames.isEmpty) continue;

      final phone = _col(row, h, 'sđt');
      final soldAtStr = _col(row, h, 'ngày bán');
      final soldAt = soldAtStr.isEmpty ? now : (_parseTs(soldAtStr) == 0 ? now : _parseTs(soldAtStr));

      final fid = 'import_sale_${now}_$i';

      final sale = SaleOrder(
        firestoreId: fid,
        customerName: customerName.isEmpty ? 'Khách lẻ' : customerName,
        phone: phone.isEmpty ? 'N/A' : phone,
        productNames: productNames.isEmpty ? 'Không rõ' : productNames,
        productImeis: _col(row, h, 'imei'),
        totalPrice: _parseMoney(_col(row, h, 'giá bán')),
        totalCost: _parseMoney(_col(row, h, 'giá vốn')),
        discount: _parseMoney(_col(row, h, 'giảm giá')),
        paymentMethod: _col(row, h, 'pt thanh toán').let((v) => v.isEmpty ? 'TIỀN MẶT' : v),
        cashAmount: _parseMoney(_col(row, h, 'tiền mặt')),
        transferAmount: _parseMoney(_col(row, h, 'chuyển khoản')),
        isInstallment: _col(row, h, 'trả góp').toLowerCase().contains('có'),
        downPayment: _parseMoney(_col(row, h, 'trả trước')),
        bankName: _col(row, h, 'ngân hàng').let((v) => v.isEmpty ? null : v),
        sellerName: _col(row, h, 'người bán').let((v) => v.isEmpty ? 'Import' : v),
        warranty: _col(row, h, 'bảo hành').let((v) => v.isEmpty ? 'KO BH' : v),
        gifts: _col(row, h, 'quà tặng').let((v) => v.isEmpty ? null : v),
        notes: _col(row, h, 'ghi chú').let((v) => v.isEmpty ? null : v),
        soldAt: soldAt,
        isSynced: false,
      );

      try {
        await _db.upsertSale(sale);
        await FirestoreService.updateSaleCloud(sale);
        success++;
      } catch (e) {
        debugPrint('importSales row $i error: $e');
        errors.add('Hàng $i: $e');
      }
    }

    return ImportResult(
      dataType: type,
      total: total,
      success: success,
      errors: errors,
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  //  3. IMPORT PRODUCTS
  // ────────────────────────────────────────────────────────────────────────

  static Future<ImportResult> importProducts(
    Uint8List bytes, {
    required void Function(int, int, String) onProgress,
  }) async {
    const type = 'Kho hàng';

    final excel = Excel.decodeBytes(bytes);
    final sheet = _findSheet(excel, ['kho', 'hàng', 'product', 'inventory']) ??
        (excel.tables.isEmpty ? null : excel.tables.values.first);

    if (sheet == null || sheet.maxRows < 2) {
      return ImportResult(
        dataType: type,
        total: 0,
        success: 0,
        errors: ['File trống hoặc không có dữ liệu kho hàng'],
      );
    }

    final h = _headers(sheet);
    final total = sheet.maxRows - 1;
    int success = 0;
    final errors = <String>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    final shopId = await UserService.getCurrentShopId();

    for (int i = 1; i <= total; i++) {
      onProgress(i, total, 'Đang nhập sản phẩm $i/$total…');
      final row = sheet.row(i);

      final name = _col(row, h, 'tên sản phẩm');
      if (name.isEmpty) continue;

      final importedAtStr = _col(row, h, 'ngày nhập');
      final createdAt = importedAtStr.isEmpty ? now : (_parseTs(importedAtStr) == 0 ? now : _parseTs(importedAtStr));

      final qtyStr = _col(row, h, 'số lượng');
      final qty = qtyStr.isEmpty ? 1 : (int.tryParse(qtyStr) ?? 1);

      final fid = 'import_prod_${now}_$i';

      final product = Product(
        firestoreId: fid,
        shopId: shopId,
        name: name,
        brand: _col(row, h, 'hãng').let((v) => v.isEmpty ? 'KHÁC' : v),
        model: _col(row, h, 'model').let((v) => v.isEmpty ? null : v),
        imei: _col(row, h, 'imei').let((v) => v.isEmpty ? null : v),
        color: _col(row, h, 'màu').let((v) => v.isEmpty ? null : v),
        capacity: _col(row, h, 'dung lượng').let((v) => v.isEmpty ? null : v),
        condition: _col(row, h, 'tình trạng').let((v) => v.isEmpty ? 'Mới' : v),
        quantity: qty,
        cost: _parseMoney(_col(row, h, 'giá vốn')),
        price: _parseMoney(_col(row, h, 'giá bán')),
        supplier: _col(row, h, 'nhà cung cấp').let((v) => v.isEmpty ? null : v),
        warranty: _col(row, h, 'bảo hành').let((v) => v.isEmpty ? null : v),
        description: _col(row, h, 'mô tả'),
        sku: _col(row, h, 'sku').let((v) => v.isEmpty ? null : v),
        locationCode: _col(row, h, 'vị trí (code)').let((v) => v.isEmpty ? null : v),
        locationName: _col(row, h, 'vị trí (tên)').let((v) => v.isEmpty ? null : v),
        createdAt: createdAt,
        isSynced: false,
      );

      try {
        await _db.upsertProduct(product);
        final docId = await FirestoreService.addProduct(product);
        if (docId != null && docId != fid) {
          product.firestoreId = docId;
          await _db.upsertProduct(product);
        }
        success++;
      } catch (e) {
        debugPrint('importProducts row $i error: $e');
        errors.add('Hàng $i: $e');
      }
    }

    return ImportResult(
      dataType: type,
      total: total,
      success: success,
      errors: errors,
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  //  4. IMPORT CUSTOMERS
  // ────────────────────────────────────────────────────────────────────────

  static Future<ImportResult> importCustomers(
    Uint8List bytes, {
    required void Function(int, int, String) onProgress,
  }) async {
    const type = 'Khách hàng';

    final excel = Excel.decodeBytes(bytes);
    final sheet = _findSheet(excel, ['khách', 'customer']) ??
        (excel.tables.isEmpty ? null : excel.tables.values.first);

    if (sheet == null || sheet.maxRows < 2) {
      return ImportResult(
        dataType: type,
        total: 0,
        success: 0,
        errors: ['File trống hoặc không có dữ liệu khách hàng'],
      );
    }

    final h = _headers(sheet);
    final total = sheet.maxRows - 1;
    int success = 0;
    final errors = <String>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (int i = 1; i <= total; i++) {
      onProgress(i, total, 'Đang nhập khách hàng $i/$total…');
      final row = sheet.row(i);

      final name = _col(row, h, 'tên khách hàng');
      if (name.isEmpty) continue;

      final phone = _col(row, h, 'sđt');
      final fid = 'import_cust_${now}_$i';

      final data = <String, dynamic>{
        'firestoreId': fid,
        'name': name,
        'phone': phone,
        'email': _col(row, h, 'email'),
        'address': _col(row, h, 'địa chỉ'),
        'notes': _col(row, h, 'ghi chú').let((v) => v.isEmpty ? null : v),
        'totalSpent': _parseMoney(_col(row, h, 'tổng chi tiêu')),
        'totalRepairs': int.tryParse(_col(row, h, 'số lần sửa')) ?? 0,
        'totalRepairCost': _parseMoney(_col(row, h, 'tổng tiền sửa')),
        'createdAt': now,
        'isSynced': 0,
        'deleted': 0,
        'coverAlignX': 0.0,
        'coverAlignY': 0.0,
      };

      try {
        final docId = await FirestoreService.addCustomer(data);
        if (docId != null) {
          data['firestoreId'] = docId;
        }
        await _db.upsertCustomer(data);
        success++;
      } catch (e) {
        debugPrint('importCustomers row $i error: $e');
        errors.add('Hàng $i: $e');
      }
    }

    return ImportResult(
      dataType: type,
      total: total,
      success: success,
      errors: errors,
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  //  5. IMPORT SUPPLIERS
  // ────────────────────────────────────────────────────────────────────────

  static Future<ImportResult> importSuppliers(
    Uint8List bytes, {
    required void Function(int, int, String) onProgress,
  }) async {
    const type = 'Nhà cung cấp';
    final shopId = await UserService.getCurrentShopId() ?? '';
    if (shopId.isEmpty && !UserService.isCurrentUserSuperAdmin()) {
      return const ImportResult(
        dataType: type,
        total: 0,
        success: 0,
        errors: ['Không tìm thấy thông tin cửa hàng'],
      );
    }

    final excel = Excel.decodeBytes(bytes);
    final sheet = _findSheet(excel, ['cung cấp', 'supplier', 'ncc']) ??
        (excel.tables.isEmpty ? null : excel.tables.values.first);

    if (sheet == null || sheet.maxRows < 2) {
      return ImportResult(
        dataType: type,
        total: 0,
        success: 0,
        errors: ['File trống hoặc không có dữ liệu nhà cung cấp'],
      );
    }

    final h = _headers(sheet);
    final total = sheet.maxRows - 1;
    int success = 0;
    final errors = <String>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (int i = 1; i <= total; i++) {
      onProgress(i, total, 'Đang nhập nhà cung cấp $i/$total…');
      final row = sheet.row(i);

      final name = _col(row, h, 'tên nhà cung cấp');
      if (name.isEmpty) continue;

      final activeStr = _col(row, h, 'trạng thái').toLowerCase();
      final active = !activeStr.contains('không');

      final fid = 'import_sup_${now}_$i';

      final data = <String, dynamic>{
        'firestoreId': fid,
        'name': name,
        'phone': _col(row, h, 'sđt'),
        'email': _col(row, h, 'email'),
        'address': _col(row, h, 'địa chỉ'),
        'note': _col(row, h, 'ghi chú').let((v) => v.isEmpty ? null : v),
        'active': active ? 1 : 0,
        'favorite': 0,
        'shopId': shopId,
        'createdAt': now,
        'updatedAt': now,
      };

      try {
        final docId = await FirestoreService.addSupplier(data);
        if (docId != null) {
          data['firestoreId'] = docId;
        }
        await _db.upsertSupplier(data);
        success++;
      } catch (e) {
        debugPrint('importSuppliers row $i error: $e');
        errors.add('Hàng $i: $e');
      }
    }

    return ImportResult(
      dataType: type,
      total: total,
      success: success,
      errors: errors,
    );
  }
}

// Dart extension helper used internally.
extension _LetExt<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
