import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:quanlyshop/services/kiotviet_service.dart';
import 'package:quanlyshop/services/notification_service.dart';
import 'package:quanlyshop/views/kiotviet_settings_view.dart';

class _IntegrationFakeDelegate extends KiotVietSettingsViewDelegate {
  _IntegrationFakeDelegate();

  KiotVietConnectionSnapshot snapshot = const KiotVietConnectionSnapshot(
    retailerCode: '',
    hasSecureConfiguration: true,
    hasCachedToken: false,
  );

  String? lastRetailer;

  @override
  Future<KiotVietConnectionSnapshot> loadSnapshot({
    KiotVietLogHandler? onLog,
  }) async {
    return snapshot;
  }

  @override
  Future<KiotVietSyncResult> connectAndSync(
    String retailerCode, {
    void Function(String message)? onProgress,
    KiotVietLogHandler? onLog,
  }) async {
    lastRetailer = normalizeRetailerCode(retailerCode);
    onProgress?.call('Bắt đầu đồng bộ sản phẩm...');
    onProgress?.call('Đồng bộ hoàn tất.');
    snapshot = KiotVietConnectionSnapshot(
      retailerCode: lastRetailer!,
      hasSecureConfiguration: true,
      hasCachedToken: true,
      lastConnectedAt: DateTime(2026, 5, 15).millisecondsSinceEpoch,
    );
    return const KiotVietSyncResult(added: 4, updated: 1, failed: 0);
  }

  @override
  Future<void> clearConnection() async {
    snapshot = const KiotVietConnectionSnapshot(
      retailerCode: '',
      hasSecureConfiguration: true,
      hasCachedToken: false,
    );
  }

  @override
  String normalizeRetailerCode(String input) {
    return KiotVietService.normalizeRetailerCode(input);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ket noi KiotViet voi retailer duoc chuan hoa va hien success state', (
    tester,
  ) async {
    final delegate = _IntegrationFakeDelegate();

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: NotificationService.messengerKey,
        home: KiotVietSettingsView(delegate: delegate),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField),
      'https://huymobile.kiotviet.vn',
    );
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Kết nối KiotViet'),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(delegate.lastRetailer, 'huymobile');
    expect(find.byType(TextFormField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
