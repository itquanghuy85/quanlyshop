import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quanlyshop/firebase_options.dart';
import 'package:quanlyshop/main.dart' as app;
import 'package:quanlyshop/views/repair_detail_view.dart';

/// On-device regression for the "Đơn sửa" module redesign:
/// OrderListView (stats strip + subtitle) → RepairDetailView
/// (header card + timeline + tab selector) → RepairInvoicePreviewView
/// (section headers). Runs against the REAL app + REAL SQLite data on device.
Future<bool> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (tester.any(finder)) return true;
  }
  return false;
}

Future<bool> waitForAny(
  WidgetTester tester,
  List<Finder> finders, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    for (final f in finders) {
      if (tester.any(f)) return true;
    }
  }
  return false;
}

/// Dismiss the per-screen FirstTimeGuide overlays ("ĐÃ HIỂU, BẮT ĐẦU!" /
/// "BỎ QUA"), one page at a time, until no modal barrier remains.
/// Every screen (Home, OrderList, Detail, Preview...) shows its own guide
/// the first time it is opened — they block all taps until closed.
Future<void> dismissGuides(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    if (tester.any(find.text('ĐÃ HIỂU, BẮT ĐẦU!').hitTestable())) {
      await tester.tap(find.text('ĐÃ HIỂU, BẮT ĐẦU!').hitTestable().first);
      await tester.pump(const Duration(milliseconds: 300));
      continue;
    }
    if (tester.any(find.text('BỎ QUA').hitTestable())) {
      await tester.tap(find.text('BỎ QUA').hitTestable().first);
      await tester.pump(const Duration(milliseconds: 300));
      continue;
    }
    await tester.pump(const Duration(milliseconds: 200));
    if (find.byType(ModalBarrier, skipOffstage: false).evaluate().isEmpty) {
      break;
    }
  }
}

/// Capture an on-device screenshot (no-op under plain `flutter test`; only
/// `flutter drive` with the extended driver writes the PNGs).
Future<void> shot(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  try {
    await binding.takeScreenshot(name);
  } catch (e) {
    debugPrint('shot "$name" skipped: $e');
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('order module redesign: list -> detail -> preview', (tester) async {
    try {
      await binding.convertFlutterSurfaceToImage();
    } catch (e) {
      debugPrint('convertFlutterSurfaceToImage skipped: $e');
    }
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    const testEmail = String.fromEnvironment('TEST_EMAIL', defaultValue: 'm@m.com');
    const testPassword = String.fromEnvironment('TEST_PASSWORD', defaultValue: '123123');
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: testEmail, password: testPassword)
          .timeout(const Duration(seconds: 30));
      debugPrint('OK integration: signed in as ${cred.user?.email}');
    } catch (e) {
      fail('Integration test login failed: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('home_last_tab_index_v1');
    await tester.pumpWidget(const app.MyApp());

    // 1) Splash -> AuthGate -> Home. FirstTimeGuideService may overlay — dismiss.
    final homeOrGuide = await waitForAny(
      tester,
      [find.text('Sửa chữa'), find.text('BỎ QUA')],
      timeout: const Duration(seconds: 90),
    );
    expect(homeOrGuide, isTrue, reason: 'Home not reached.');
    if (tester.any(find.text('BỎ QUA'))) {
      await tester.tap(find.text('BỎ QUA'));
      await tester.pump(const Duration(milliseconds: 600));
    }
    final homeOk = await waitFor(
      tester,
      find.text('Sửa chữa'),
      timeout: const Duration(seconds: 60),
    );
    expect(homeOk, isTrue, reason: 'Home not reached after login/guide.');

    // 2) Open OrderListView from the Home "Trang chủ" tab via the "DS sửa"
    //    shortcut. Start Home on the first tab by clearing the "last tab"
    //    pref so no restored tab's tour dialog can block the screen.
    // 2) Close any FirstTimeGuide overlay (may have several pages; button is
    //    "ĐÃ HIỂU, BẮT ĐẦU!"), then open OrderListView via the "DS sửa"
    //    shortcut on the Trang chủ tab.
    await dismissGuides(tester);
    expect(
      tester.any(find.text('DS sửa').hitTestable()),
      isTrue,
      reason: 'DS sửa shortcut not tappable on Home (guide overlay?)',
    );
    await tester.tap(find.text('DS sửa'));
    await tester.pump(const Duration(milliseconds: 500));
    // OrderListView has its own first-time guide — close it before tapping.
    await dismissGuides(tester);

    final subtitleOk = await waitFor(
      tester,
      find.textContaining(RegExp(r'\d+ đơn')),
      timeout: const Duration(seconds: 30),
    );
    expect(subtitleOk, isTrue, reason: 'AppBar subtitle "<N> đơn" missing.');

    // Status filter chips — all 7 always render (Row inside horizontal scroll).
    for (final label in [
      'Tất cả',
      'Tiếp nhận',
      'Đang sửa',
      'Y/c duyệt',
      'Sửa xong',
      'Giao',
      'Quá hạn',
    ]) {
      expect(find.text(label), findsWidgets,
          reason: 'filter chip "$label" missing');
    }
    expect(find.textContaining('Sắp xếp: Ưu tiên'), findsOneWidget,
        reason: 'sort selector "Sắp xếp: Ưu tiên" missing');
    expect(tester.takeException(), isNull, reason: 'OrderListView threw.');
    await shot(binding, '1_order_list');

    // 3) Open the first repair card -> RepairDetailView.
    final cardOk = await waitFor(tester, find.byType(Card),
        timeout: const Duration(seconds: 25));
    expect(cardOk, isTrue, reason: 'repair cards not loaded');
    final dbg = StringBuffer('CARDS:\n');
    final cards = find.byType(Card);
    var idx = 0;
    for (final el in cards.evaluate()) {
      final texts = find
          .descendant(of: find.byWidget(el.widget), matching: find.byType(Text))
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .where((d) => d != null && d.trim().isNotEmpty)
          .take(5)
          .join(' | ');
      dbg.writeln('Card#$idx: $texts');
      idx++;
      if (idx > 8) break;
    }
    debugPrint(dbg.toString());
    // OrderListView's own first-time guide can still pop after cards render —
    // close it, then tap the first card (retry in case of a leftover overlay).
    await dismissGuides(tester);
    var opened = false;
    for (var attempt = 0; attempt < 6 && !opened; attempt++) {
      await tester.tap(find.byType(Card).first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 800));
      opened = tester.any(find.byType(RepairDetailView));
      if (!opened) await dismissGuides(tester);
    }
    expect(opened, isTrue, reason: 'RepairDetailView not opened from list.');
    // RepairDetailView has its own first-time guide — close it before
    // interacting with the timeline / tabs / more menu.
    await dismissGuides(tester);
    await shot(binding, '2_detail_tongquan');

    // Header card + timeline.
    expect(find.textContaining('#'), findsWidgets, reason: 'order code # missing');
    expect(find.text('Ngày nhận'), findsWidgets);
    expect(find.text('Sửa máy'), findsWidgets, reason: 'timeline step missing');
    expect(find.text('Giao máy'), findsWidgets, reason: 'timeline step missing');

    // Tab selector.
    expect(find.text('Tổng quan'), findsOneWidget);
    expect(find.text('Dịch vụ'), findsOneWidget);
    expect(find.text('Lịch sử & Ghi chú'), findsOneWidget);

    // Customer contact actions.
    await tester.ensureVisible(find.text('Gọi'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Gọi'), findsWidgets);
    expect(find.text('Zalo'), findsWidgets);
    expect(find.text('Nhắn tin'), findsWidgets);

    // 4) Dịch vụ tab. (tab selector is off-screen after scrolling to 'Gọi')
    await tester.ensureVisible(find.text('Dịch vụ'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Dịch vụ'));
    await tester.pump(const Duration(milliseconds: 400));
    await dismissGuides(tester);
    expect(find.text('DỊCH VỤ SỬA CHỮA'), findsWidgets);
    await shot(binding, '3_detail_dichvu');

    // 5) Lịch sử tab.
    await tester.ensureVisible(find.text('Lịch sử & Ghi chú'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Lịch sử & Ghi chú'));
    await tester.pump(const Duration(milliseconds: 400));
    await dismissGuides(tester);
    expect(find.text('LỊCH SỬ & GHI CHÚ'), findsWidgets);
    await shot(binding, '4_detail_lichsu');

    // 6) More menu -> Xem trước phiếu -> RepairInvoicePreviewView sections.
    // Force DEFAULT layout (preview falls back to custom template otherwise).
    await prefs.setBool('repair_invoice_use_template', false);
    await dismissGuides(tester);
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pump(const Duration(milliseconds: 500));
    await dismissGuides(tester);
    await tester.tap(find.text('Xem trước phiếu'));
    await tester.pump(const Duration(milliseconds: 500));
    await dismissGuides(tester);

    final previewOk = await waitFor(
      tester,
      find.text('THÔNG TIN KHÁCH HÀNG'),
      timeout: const Duration(seconds: 20),
    );
    expect(previewOk, isTrue, reason: 'preview THÔNG TIN KHÁCH HÀNG missing');
    expect(find.text('THÔNG TIN KHÁCH HÀNG'), findsWidgets);
    expect(find.text('THÔNG TIN MÁY'), findsWidgets);
    // Scroll the preview so Giá dự kiến is visible on screen.
    for (var i = 0;
        i < 8 && !tester.any(find.text('Giá dự kiến'));
        i++) {
      await tester.dragFrom(const Offset(180, 640), const Offset(0, -350));
      await tester.pump(const Duration(milliseconds: 200));
    }
    // Block "THÔNG TIN DỊCH VỤ" + "Tổng tạm tính" must be REMOVED from the
    // PHIẾU TIẾP NHẬN (preview + shared file) — services are not listed here.
    expect(tester.any(find.text('THÔNG TIN DỊCH VỤ')), isFalse,
        reason: 'dịch vụ section must be hidden on phiếu tiếp nhận');
    expect(tester.any(find.textContaining('Tổng tạm tính')), isFalse,
        reason: 'Tổng tạm tính must not appear on phiếu tiếp nhận');
    expect(tester.any(find.textContaining('Giá dự kiến')), isTrue,
        reason: 'preview Giá dự kiến missing');
    await shot(binding, '5_preview');

    expect(tester.takeException(), isNull, reason: 'an exception was thrown.');
  });
}