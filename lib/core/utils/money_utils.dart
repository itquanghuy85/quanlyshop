import 'package:intl/intl.dart';

/// Utility class for handling Vietnamese Dong (VNĐ) currency operations.
/// This is the ONLY place allowed to handle currency formatting, parsing, and conversions.
///
/// Conventions:
/// - Internal system: VNĐ (integer)
/// - UI input: Thousand VNĐ (user enters smaller numbers, code multiplies by 1000)
/// - Display: VNĐ with separators (formatted string)
class MoneyUtils {
  static final NumberFormat _vndFormat = NumberFormat('#,###', 'vi_VN');

  /// Formats VNĐ amount to display string with separators.
  /// Example: 5000000 -> "5,000,000"
  static String formatVND(int vnd) {
    if (vnd == 0) return '0';
    return _vndFormat.format(vnd);
  }

  /// Converts user input (thousand VNĐ) to VNĐ.
  /// If input < 100,000, assumes it's thousand VNĐ and multiplies by 1000.
  /// Otherwise, treats as VNĐ directly.
  static int inputToVND(int input) {
    if (input > 0 && input < 100000) {
      return input * 1000;
    }
    return input;
  }

  /// Parses currency string to VNĐ.
  /// Removes separators and converts to int, then applies inputToVND logic.
  static int parseInputToVND(String input) {
    final clean = input.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(clean) ?? 0;
    return inputToVND(amount);
  }

  /// Converts VNĐ to thousand VNĐ for display purposes.
  /// Only use when you need to show thousand VNĐ instead of VNĐ.
  static int vndToThousand(int vnd) {
    return vnd ~/ 1000;
  }

  /// Parses currency string to VNĐ with input conversion logic.
  /// Cleans the string, parses to int, then applies inputToVND logic.
  /// This maintains backward compatibility with existing code.
  static int parseMoney(String text) {
    final clean = text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(clean) ?? 0;
    return inputToVND(amount);
  }
}