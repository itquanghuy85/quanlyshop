class WifiPrinterService {
  WifiPrinterService._private();
  static final WifiPrinterService instance = WifiPrinterService._private();

  Future<bool> connect({required String ip, required int port}) async {
    // Minimal stub: pretend connection succeeds
    return true;
  }

  Future<void> printBytes(List<int> bytes) async {
    // Stubbed: do nothing
  }

  static Future<void> writeBytes(List<int> bytes) async {
    // Static convenience method used by UnifiedPrinterService
    return instance.printBytes(bytes);
  }

  Future<void> disconnect() async {
    // Stubbed: do nothing
  }
}
