import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quanlyshop/data/db_helper.dart';
import 'package:quanlyshop/models/shift_swap_request_model.dart';
import 'package:quanlyshop/services/app_session.dart';

/// Self-healing schema test (2026-09-26 shift-swap redesign): confirms the
/// new `shift_swap_requests` SQLite table is created lazily on first use
/// (no version bump needed, matching the `_ensureProductRefurbishSchema`
/// pattern — L-01 2026-09-20 "no such table" lesson), and that the
/// structured-time fields + the override query the canonical engine will
/// use both round-trip correctly.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    await AppSession.startOffline(shopName: 'Shift swap schema test');
  });

  test('upsert creates the table lazily and round-trips all fields', () async {
    final db = DBHelper();
    final r = ShiftSwapRequest(
      firestoreId: 'ssw_test_001',
      shopId: '',
      requesterId: 'u1',
      requesterName: 'A',
      requesterEmail: 'a@shop.com',
      requestedDate: '2026-09-30',
      currentShift: 'Ca sáng',
      desiredShift: 'Ca chiều',
      newStartTime: '13:00',
      newEndTime: '22:00',
      targetUserId: 'u2',
      targetUserName: 'B',
      targetNewStartTime: '08:00',
      targetNewEndTime: '17:00',
      note: 'Đổi ca test',
      status: 'pending',
      reviewedBy: null,
      reviewedByName: null,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      reviewedAt: null,
      rejectReason: null,
      deleted: false,
      isSynced: false,
    );

    await db.upsertShiftSwapRequest(r);

    final all = await db.getAllShiftSwapRequests();
    final found = all.where((x) => x.firestoreId == 'ssw_test_001').toList();
    expect(found, hasLength(1));
    expect(found.first.newStartTime, '13:00');
    expect(found.first.newEndTime, '22:00');
    expect(found.first.targetNewStartTime, '08:00');
    expect(found.first.targetNewEndTime, '17:00');
    expect(found.first.targetUserId, 'u2');
    expect(found.first.isSynced, isFalse);

    // Upsert again with same firestoreId (simulating approve()) must
    // replace, not duplicate.
    final approved = found.first.copyWith(
      status: 'approved',
      reviewedBy: 'mgr1',
      isSynced: false,
    );
    await db.upsertShiftSwapRequest(approved);
    final allAfter = await db.getAllShiftSwapRequests();
    expect(allAfter.where((x) => x.firestoreId == 'ssw_test_001'), hasLength(1));
    expect(
      allAfter.firstWhere((x) => x.firestoreId == 'ssw_test_001').status,
      'approved',
    );
  });

  test('getApprovedShiftSwapRequestsForUserAndDate finds both requester and target side', () async {
    final db = DBHelper();
    final requesterSide = ShiftSwapRequest(
      firestoreId: 'ssw_test_req',
      shopId: '',
      requesterId: 'u10',
      requesterName: 'Req',
      requesterEmail: 'req@shop.com',
      requestedDate: '2026-10-01',
      currentShift: 'Ca sáng',
      desiredShift: 'Ca chiều',
      newStartTime: '13:00',
      newEndTime: '22:00',
      targetUserId: 'u11',
      targetUserName: 'Target',
      targetNewStartTime: '08:00',
      targetNewEndTime: '17:00',
      note: null,
      status: 'approved',
      reviewedBy: 'mgr',
      reviewedByName: 'Mgr',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      reviewedAt: DateTime.now().millisecondsSinceEpoch,
      rejectReason: null,
      deleted: false,
    );
    await db.upsertShiftSwapRequest(requesterSide);

    final forRequester =
        await db.getApprovedShiftSwapRequestsForUserAndDate('u10', '2026-10-01');
    expect(forRequester, hasLength(1));
    expect(forRequester.first.newStartTime, '13:00');

    final forTarget =
        await db.getApprovedShiftSwapRequestsForUserAndDate('u11', '2026-10-01');
    expect(forTarget, hasLength(1));
    expect(forTarget.first.targetNewStartTime, '08:00');

    // A third, unrelated user on the same date finds nothing.
    final forOther =
        await db.getApprovedShiftSwapRequestsForUserAndDate('u99', '2026-10-01');
    expect(forOther, isEmpty);

    // Same user, different date finds nothing.
    final wrongDate =
        await db.getApprovedShiftSwapRequestsForUserAndDate('u10', '2026-10-02');
    expect(wrongDate, isEmpty);
  });

  test('pending/rejected swaps are not returned by the approved-override query', () async {
    final db = DBHelper();
    final pending = ShiftSwapRequest(
      firestoreId: 'ssw_test_pending',
      shopId: '',
      requesterId: 'u20',
      requesterName: 'P',
      requesterEmail: 'p@shop.com',
      requestedDate: '2026-10-05',
      currentShift: 'Ca sáng',
      desiredShift: 'Ca chiều',
      newStartTime: '13:00',
      newEndTime: '22:00',
      targetUserId: null,
      targetUserName: null,
      note: null,
      status: 'pending',
      reviewedBy: null,
      reviewedByName: null,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      reviewedAt: null,
      rejectReason: null,
      deleted: false,
    );
    await db.upsertShiftSwapRequest(pending);

    final result =
        await db.getApprovedShiftSwapRequestsForUserAndDate('u20', '2026-10-05');
    expect(result, isEmpty);
  });
}
