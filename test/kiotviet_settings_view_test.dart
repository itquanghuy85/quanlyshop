import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/services/kiotviet_service.dart';
import 'package:quanlyshop/services/notification_service.dart';
import 'package:quanlyshop/views/kiotviet_settings_view.dart';

class _FakeKiotVietDelegate extends KiotVietSettingsViewDelegate {
  _FakeKiotVietDelegate({
    required this.snapshot,
    this.loadError,
    this.connectError,
    this.result = const KiotVietSyncResult(),
    this.progressMessages = const <String>[],
  });

  KiotVietConnectionSnapshot snapshot;
  Object? loadError;
  Object? connectError;
  KiotVietSyncResult result;
  List<String> progressMessages;
  int connectCalls = 0;
  String? lastRetailer;

  @override
  Future<KiotVietConnectionSnapshot> loadSnapshot({
    KiotVietLogHandler? onLog,
  }) async {
    if (loadError != null) {
      throw loadError!;
    }
    return snapshot;
  }

  @override
  Future<KiotVietSyncResult> connectAndSync(
    String retailerCode, {
    void Function(String message)? onProgress,
    KiotVietLogHandler? onLog,
  }) async {
    connectCalls += 1;
    lastRetailer = normalizeRetailerCode(retailerCode);
    for (final message in progressMessages) {
      onProgress?.call(message);
    }
    if (connectError != null) {
      throw connectError!;
    }
    snapshot = KiotVietConnectionSnapshot(
      retailerCode: lastRetailer!,
      hasSecureConfiguration: true,
      hasCachedToken: true,
      lastConnectedAt: DateTime(2026, 5, 15).millisecondsSinceEpoch,
    );
    return result;
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

Widget _buildTestApp(KiotVietSettingsViewDelegate delegate) {
  return MaterialApp(
    scaffoldMessengerKey: NotificationService.messengerKey,
    home: KiotVietSettingsView(delegate: delegate),
  );
}

void main() {
  testWidgets('render giao dien toi gian voi mot o nhap retailer', (
    tester,
  ) async {
    final delegate = _FakeKiotVietDelegate(
      snapshot: const KiotVietConnectionSnapshot(
        retailerCode: '',
        hasSecureConfiguration: true,
        hasCachedToken: false,
      ),
    );

    await tester.pumpWidget(_buildTestApp(delegate));
    await tester.pumpAndSettle();

    expect(find.text('Kết nối KiotViet'), findsWidgets);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Kết nối cửa hàng KiotViet'), findsOneWidget);
  });

  testWidgets('hien preview retailer da chuan hoa tu url', (tester) async {
    final delegate = _FakeKiotVietDelegate(
      snapshot: const KiotVietConnectionSnapshot(
        retailerCode: '',
        hasSecureConfiguration: true,
        hasCachedToken: false,
      ),
    );

    await tester.pumpWidget(_buildTestApp(delegate));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField),
      'https://HUYMOBILE.kiotviet.vn',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('huymobile'), findsWidgets);
  });

  testWidgets('khong trang man hinh khi init loi', (tester) async {
    final delegate = _FakeKiotVietDelegate(
      snapshot: const KiotVietConnectionSnapshot(
        retailerCode: '',
        hasSecureConfiguration: true,
        hasCachedToken: false,
      ),
      loadError: Exception('boom'),
    );

    await tester.pumpWidget(_buildTestApp(delegate));
    await tester.pumpAndSettle();

    expect(find.text('Không thể mở trang KiotViet'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ket noi thanh cong va hien ket qua dong bo', (tester) async {
    final delegate = _FakeKiotVietDelegate(
      snapshot: const KiotVietConnectionSnapshot(
        retailerCode: '',
        hasSecureConfiguration: true,
        hasCachedToken: false,
      ),
      result: const KiotVietSyncResult(added: 3, updated: 2, failed: 0),
      progressMessages: const <String>[
        'Bắt đầu đồng bộ sản phẩm...',
        'Đồng bộ hoàn tất.',
      ],
    );

    await tester.pumpWidget(_buildTestApp(delegate));
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

    expect(delegate.connectCalls, 1);
    expect(delegate.lastRetailer, 'huymobile');
    expect(tester.takeException(), isNull);
  });

  testWidgets('ket noi loi van hien error state thay vi blank screen', (
    tester,
  ) async {
    final delegate = _FakeKiotVietDelegate(
      snapshot: const KiotVietConnectionSnapshot(
        retailerCode: '',
        hasSecureConfiguration: true,
        hasCachedToken: false,
      ),
      connectError: Exception('token error'),
    );

    await tester.pumpWidget(_buildTestApp(delegate));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'huymobile');
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Kết nối KiotViet'),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Không thể xác thực với KiotViet'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mo trang 100 lan lien tiep khong blank screen', (tester) async {
    final delegate = _FakeKiotVietDelegate(
      snapshot: const KiotVietConnectionSnapshot(
        retailerCode: 'huymobile',
        hasSecureConfiguration: true,
        hasCachedToken: true,
      ),
    );

    for (var index = 0; index < 100; index++) {
      await tester.pumpWidget(_buildTestApp(delegate));
      await tester.pumpAndSettle();
      expect(find.text('Kết nối KiotViet'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}
