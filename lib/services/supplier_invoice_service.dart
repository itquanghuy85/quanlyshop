import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/supplier_invoice_models.dart';
import '../utils/excel_export_helper.dart';
import '../utils/money_utils.dart';
import '../utils/vietnamese_utils.dart';
import 'audit_service.dart';
import 'sync_orchestrator.dart';

/// Cập nhật giá vốn tham khảo cho Kho phụ tùng/linh kiện từ hoá đơn nhà cung
/// cấp — qua cầu nối Excel (chủ shop nhờ ChatGPT/Gemini đọc ảnh hoá đơn rồi
/// tạo thẳng file Excel để tải về và nhập vào app; nếu AI không tạo được
/// file thì dán bảng kết quả vào file mẫu). KHÔNG tự tạo phụ tùng mới,
/// KHÔNG đụng số lượng tồn kho — chỉ giá vốn.
class SupplierInvoiceService {
  SupplierInvoiceService._();

  static const List<String> templateHeaders = [
    'Tên phụ tùng',
    'Giá vốn',
    'Hãng',
  ];

  /// Câu lệnh (prompt) chủ shop copy dán cho ChatGPT/Gemini/Claude kèm ảnh
  /// hoá đơn NCC — yêu cầu AI tạo thẳng 1 file Excel để tải về và nhập
  /// thẳng vào app (đỡ phải copy/dán tay). Có kèm phương án dự phòng (xuất
  /// bảng văn bản) cho các bản AI không tạo được file. Cột "Hãng" là tuỳ
  /// chọn — giúp Bảng giá gom đúng nhóm hãng máy (vd "Pin iPhone 13" nếu
  /// không có cột này app tự đoán hãng từ tên, có thể sai khi tên không rõ
  /// hãng, vd "Pin Zin 13").
  static const String chatGptPrompt =
      'Đây là ảnh hoá đơn mua hàng từ nhà cung cấp phụ tùng điện thoại. Hãy '
      'đọc TẤT CẢ các dòng hàng trong hoá đơn, rồi tạo cho tôi 1 file Excel '
      '(.xlsx) để tôi tải về, gồm đúng 3 cột:\n'
      'Cột A "Tên phụ tùng": tên hàng đúng như trên hoá đơn.\n'
      'Cột B "Giá vốn": đơn giá của dòng đó (chỉ số, không ghi "đ" hay dấu '
      'chấm phẩy nghìn).\n'
      'Cột C "Hãng": hãng máy dòng đó dùng cho (vd Oppo, iPhone, Samsung, '
      'Xiaomi, Vivo…) nếu suy ra được từ tên hàng; để trống nếu không rõ.\n'
      'Dòng 1 là tiêu đề "Tên phụ tùng", "Giá vốn", "Hãng". Không thêm cột '
      'nào khác, không thêm dòng tổng cộng, không giải thích gì thêm.\n'
      'Nếu không tạo được file, hãy xuất đúng bảng đó dưới dạng văn bản, '
      'phân cách bằng dấu Tab, để tôi tự dán vào Excel.';

  /// Tạo file Excel mẫu (3 cột + 1 dòng ví dụ) để chủ shop dán dữ liệu từ
  /// AI vào, hoặc tự gõ tay.
  static Excel buildTemplateExcel() {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];
    ExcelExportHelper.writeSheet(sheet, templateHeaders, [
      ['Ví dụ: Pin iPhone 11 Pro Max', 310000, 'iPhone'],
    ]);
    return excel;
  }

  static Future<void> exportTemplate(BuildContext context) async {
    final excel = buildTemplateExcel();
    await ExcelExportHelper.saveAndShare(
      excel,
      'Mau_GiaVon_PhuTung.xlsx',
      context,
    );
  }

  /// Đọc file Excel (đúng mẫu 2 cột "Tên phụ tùng" / "Giá vốn") → danh sách
  /// dòng hàng thô. Thiếu cột bắt buộc ở sheet nào thì báo lỗi rõ cho sheet
  /// đó thay vì âm thầm bỏ qua.
  static ({List<InvoiceLineItem> items, List<String> errors})
      parseExcelLineItems(Uint8List bytes) {
    final errors = <String>[];
    final items = <InvoiceLineItem>[];
    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      // Một số công cụ tạo file (vd Python/openpyxl — nhiều AI dùng cái này
      // để tự tạo file Excel) ghi đường dẫn worksheet trong
      // "xl/_rels/workbook.xml.rels" kiểu tuyệt đối ("/xl/worksheets/…")
      // thay vì tương đối — gói `excel` không hiểu, ném lỗi null-check. Tự
      // sửa lại đường dẫn trong file zip rồi đọc lại trước khi báo lỗi hẳn.
      try {
        excel = Excel.decodeBytes(_normalizeOoxmlRelTargets(bytes));
      } catch (e) {
        return (
          items: <InvoiceLineItem>[],
          errors: [
            'File Excel không đọc được: $e\n'
                'Hãy thử mở file này bằng Google Sheets hoặc Excel rồi Lưu '
                '(Save As) lại thành .xlsx, sau đó nhập lại.'
          ],
        );
      }
    }

    for (final sheet in excel.tables.values) {
      if (sheet.maxRows < 2) continue;
      final head = <String, int>{};
      final h0 = sheet.row(0);
      for (var c = 0; c < h0.length; c++) {
        head[(h0[c]?.value?.toString() ?? '').trim().toLowerCase()] = c;
      }
      final ciName = head['tên phụ tùng'];
      final ciPrice = head['giá vốn'];
      final ciBrand = head['hãng']; // tuỳ chọn — có thể null/thiếu cột
      if (ciName == null || ciPrice == null) {
        errors.add(
          'Sheet "${sheet.sheetName}": thiếu cột "Tên phụ tùng" hoặc "Giá '
          'vốn" — đã bỏ qua sheet này.',
        );
        continue;
      }

      for (var r = 1; r < sheet.maxRows; r++) {
        final row = sheet.row(r);
        String cell(int? i) => (i == null || i >= row.length)
            ? ''
            : (row[i]?.value?.toString() ?? '');
        final name = cell(ciName).trim();
        final price = MoneyUtils.parseCurrency(cell(ciPrice));
        if (name.isEmpty && price <= 0) continue; // dòng trống, bỏ qua êm
        if (name.isEmpty || price <= 0) {
          errors.add('Sheet "${sheet.sheetName}" dòng ${r + 1}: thiếu tên '
              'hoặc giá vốn không hợp lệ — đã bỏ qua.');
          continue;
        }
        items.add(InvoiceLineItem(
          name: name,
          unitPrice: price,
          brand: cell(ciBrand).trim(),
        ));
      }
    }
    return (items: items, errors: errors);
  }

  /// Khớp từng dòng hoá đơn với phụ tùng đã có trong kho theo tên (bỏ dấu +
  /// không phân biệt hoa/thường, khớp chứa 2 chiều — vd "Pin DLC korlsnow
  /// iphone 11PRO max 4710mAh" khớp phụ tùng đã lưu tên ngắn hơn "Pin iPhone
  /// 11 Pro Max"). Dòng không khớp được thì bỏ qua — không tự tạo phụ tùng
  /// mới, người dùng tự thêm phụ tùng đó ở màn Kho phụ tùng nếu cần.
  static Future<List<PartCostUpdateProposal>> matchLineItems(
    List<InvoiceLineItem> items,
  ) async {
    final db = DBHelper();
    final parts = await db.getAllParts();
    final proposals = <PartCostUpdateProposal>[];

    for (final item in items) {
      if (item.name.trim().isEmpty || item.unitPrice <= 0) continue;
      final match = _bestMatch(item.name, parts);
      final partId = match?['id'] as int?;
      if (match == null || partId == null) continue;
      proposals.add(PartCostUpdateProposal(
        partId: partId,
        partName: (match['partName'] as String?) ?? item.name,
        oldCost: (match['cost'] as int?) ?? 0,
        newCost: item.unitPrice,
        sourceLineName: item.name,
      ));
    }
    return proposals;
  }

  /// Phụ tùng khớp tốt nhất theo tên, hoặc null nếu không đủ tin cậy.
  static Map<String, dynamic>? _bestMatch(
    String query,
    List<Map<String, dynamic>> parts,
  ) {
    final nq = VietnameseUtils.normalize(query.trim());
    if (nq.isEmpty) return null;
    Map<String, dynamic>? best;
    var bestScore = 0;
    for (final p in parts) {
      final name = (p['partName'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      final nn = VietnameseUtils.normalize(name);
      int score;
      if (nn == nq) {
        score = 1000;
      } else if (nn.contains(nq) || nq.contains(nn)) {
        // Chuỗi càng dài khớp trọn vẹn càng đáng tin — điểm theo độ dài
        // chuỗi ngắn hơn trong 2 chuỗi (chuỗi đó khớp trọn trong chuỗi kia).
        score = 50 + (nn.length < nq.length ? nn.length : nq.length);
      } else {
        score = 0;
      }
      if (score > bestScore) {
        bestScore = score;
        best = p;
      }
    }
    return bestScore >= 50 ? best : null;
  }

  /// Ghi giá vốn mới cho các đề xuất đã được người dùng xác nhận. Theo đúng
  /// pattern cập nhật phụ tùng đã dùng trong `parts_inventory_view.dart`
  /// (update trực tiếp bảng `repair_parts` + enqueue sync Firestore ngay +
  /// audit log) — không đụng tồn kho/số lượng.
  static Future<int> commitCostUpdates(
    List<PartCostUpdateProposal> approved,
  ) async {
    final db = DBHelper();
    var n = 0;
    for (final p in approved) {
      try {
        final part = await db.getPartById(p.partId);
        if (part == null) continue;

        final editData = {
          'cost': p.newCost,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'isSynced': 0,
        };
        await db.updatePart(p.partId, editData);

        final firestoreId = part['firestoreId'] as String?;
        if (firestoreId != null && firestoreId.isNotEmpty) {
          await SyncOrchestrator().enqueue(
            entityType: SyncEntityType.repairPart,
            entityId: p.partId,
            firestoreId: firestoreId,
            operation: SyncOperation.update,
            data: {...editData, 'id': p.partId, 'firestoreId': firestoreId},
          );
        }

        await AuditService.logAction(
          action: 'PART_COST_UPDATE_FROM_INVOICE',
          entityType: 'repair_part',
          entityId: p.partId.toString(),
          summary: 'Cập nhật giá vốn từ hoá đơn NCC (Excel): ${p.partName} '
              '${p.oldCost}đ → ${p.newCost}đ',
        );
        n++;
      } catch (_) {
        // Bỏ qua dòng lỗi, tiếp tục các dòng còn lại.
      }
    }
    return n;
  }

  /// Sửa đường dẫn Target của quan hệ worksheet trong
  /// "xl/_rels/workbook.xml.rels" từ dạng tuyệt đối ("/xl/worksheets/…")
  /// sang tương đối ("worksheets/…") — gói `excel` luôn tự ghép tiền tố
  /// "xl/" khi tìm file, nên Target tuyệt đối làm nó tìm sai đường dẫn.
  /// Đây là kiểu file phổ biến từ Python/openpyxl (AI đọc ảnh hoá đơn hay
  /// dùng cái này để tự tạo file .xlsx). Không sửa được thì trả về nguyên
  /// bytes gốc để lỗi decode ở trên tự báo cho người dùng.
  static Uint8List _normalizeOoxmlRelTargets(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final relsFile = archive.findFile('xl/_rels/workbook.xml.rels');
      if (relsFile == null) return bytes;
      final xmlStr = utf8.decode(relsFile.content as List<int>);
      final fixed = xmlStr
          .replaceAll('Target="/xl/', 'Target="')
          .replaceAll('Target="/', 'Target="');
      if (fixed == xmlStr) return bytes;

      final newArchive = Archive();
      for (final f in archive.files) {
        if (f.name == 'xl/_rels/workbook.xml.rels') {
          final data = utf8.encode(fixed);
          newArchive.addFile(
            ArchiveFile('xl/_rels/workbook.xml.rels', data.length, data),
          );
        } else {
          newArchive.addFile(f);
        }
      }
      final out = ZipEncoder().encode(newArchive);
      return out != null ? Uint8List.fromList(out) : bytes;
    } catch (_) {
      return bytes;
    }
  }
}
