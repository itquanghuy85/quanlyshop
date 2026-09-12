import 'package:flutter/services.dart';
import 'money_input_formatter.dart';

class MoneyUtils {
  /// Format int VNĐ -> "1.234.567"
  static String formatCurrency(int value) {
    return MoneyInputFormatter.formatValue(value);
  }

  /// Format rút gọn cho số tiền lớn theo đơn vị Việt: Tr/Tỷ.
  /// Ký hiệu kiểu Việt: dấu chấm ngăn nghìn, dấu phẩy thập phân.
  /// Ví dụ:
  /// - 24_430_000 -> 24,43 Tr
  /// - 6_350_000_000 -> 6,35 Tỷ
  /// - 1_234_000_000_000 -> 1.234 Tỷ
  static String formatCompactCurrency(int value) {
    final abs = value.abs();
    final sign = value < 0 ? '-' : '';

    if (abs >= 1000000000) {
      return '$sign${_formatCompactUnit(abs / 1000000000)} Tỷ';
    }
    if (abs >= 1000000) {
      return '$sign${_formatCompactUnit(abs / 1000000)} Tr';
    }
    return formatCurrency(value);
  }

  static String _formatCompactUnit(double value) {
    final abs = value.abs();
    final decimals = abs >= 1000
        ? 0
        : abs >= 100
        ? 1
        : abs >= 10
        ? 2
        : 3;

    final raw = value.toStringAsFixed(decimals);
    var cleaned = raw.replaceFirst(RegExp(r'([.]0+)$'), '');
    cleaned = cleaned.replaceFirstMapped(
      RegExp(r'(\.\d*[1-9])0+$'),
      (m) => m.group(1) ?? '',
    );

    final parts = cleaned.split('.');
    final intPart = parts.first;
    final fracPart = parts.length > 1 ? parts.last : '';
    final grouped = _groupThousandsByDot(intPart);
    if (fracPart.isEmpty) return grouped;
    // Dấu PHẨY thập phân kiểu Việt: "24,43 Tr". Bản cũ in "24.43 Tr" trong
    // khi cả app dùng dấu chấm làm ngăn nghìn ("24.430.000") → đọc thành
    // "24.430 triệu" (phản hồi tab Lãi 2026-09-12).
    return '$grouped,$fracPart';
  }

  static String _groupThousandsByDot(String intPart) {
    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      final revIdx = intPart.length - i;
      buf.write(intPart[i]);
      if (revIdx > 1 && revIdx % 3 == 1) {
        buf.write('.');
      }
    }
    return buf.toString();
  }

  /// Parse chuỗi tiền có dấu chấm -> int VNĐ (mặc định 0 nếu lỗi)
  static int parseCurrency(String input) {
    return MoneyInputFormatter.parseRaw(input);
  }

  /// Input formatter riêng cho money input (realtime format + giữ cursor)
  static TextInputFormatter currencyInputFormatter() {
    return MoneyInputFormatter();
  }

  /// Validator cho trường tiền/số lượng.
  static String? validateAmount(
    String value, {
    int min = 0,
    int? max,
    String? fieldName,
  }) {
    final name = fieldName ?? 'Giá trị';
    final parsed = parseCurrency(value);
    if (parsed < min) return '$name phải ≥ ${formatCurrency(min)}';
    if (max != null && parsed > max)
      return '$name không được vượt ${formatCurrency(max)}';
    return null;
  }

  // Giữ API cũ cho tương thích
  static int parseMoney(String text) => parseCurrency(text);
  static String formatVND(int amount) => formatCurrency(amount);
}
