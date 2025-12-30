class MoneyUtils {
  static int parseMoney(String text) {
    final clean = text.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(clean) ?? 0;
  }
}