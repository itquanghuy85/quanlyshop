import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quanlyshop/data/db_helper.dart';
import 'package:quanlyshop/models/attendance_model.dart';
import 'package:quanlyshop/services/attendance_approval_service.dart';
import 'package:quanlyshop/services/attendance_computation_service.dart';
import 'package:quanlyshop/services/app_session.dart';
import 'package:quanlyshop/services/payroll_lock_service.dart';

/// Payroll-lock guard tests (item 1 of the FINAL CLOSURE audit).
///
/// `AttendanceApprovalService`'s write paths are Firebase-dependent
/// end-to-end (FirebaseAuth.instance.currentUser, Firestore sync), and this
/// repo has no FirebaseAuth mocking infrastructure. Rather than skip the
/// test, the service was refactored (see its class doc comment) so every
/// write path's actual business logic — including the payroll-lock
/// check — lives in a `@visibleForTesting` pure function with no Firebase
/// or DB IO. These tests exercise those pure functions directly, plus the
/// real (FFI) SQLite-backed `isLockedForDateKey` predicate the async
/// wrappers call before invoking them. Together this proves: (a) the lock
/// predicate itself is correct against a real DB, and (b) every write
/// path's logic refuses to mutate the record when told it is locked.
/// What remains unverified without Firebase mocking is only the thin IO
/// wrapper (auth check, DB write, cloud sync) around this logic — see the
/// final acceptance report.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Attendance baseRecord({String dateKey = '2026-09-25'}) => Attendance(
        userId: 'u1',
        email: 'u1@shop.com',
        name: 'NV',
        dateKey: dateKey,
        checkInAt: DateTime(2026, 9, 25, 8, 0).millisecondsSinceEpoch,
        createdAt: DateTime(2026, 9, 25, 8, 0).millisecondsSinceEpoch,
      );

  final cfg = ResolvedScheduleConfig.resolve(fallbackOvertimeRatePercent: 150);

  setUpAll(() async {
    await AppSession.startOffline(shopName: 'Payroll lock test');
  });

  group('isLockedForDateKey — PayrollLockService (offline session, real SQLite FFI)', () {
    test('unlocked month is not locked', () async {
      await PayrollLockService.setMonthLock('2099-01', locked: false);
      expect(await AttendanceApprovalService.isLockedForDateKey('2099-01-15'), isFalse);
    });

    test('locked month is locked for any dateKey within it', () async {
      await PayrollLockService.setMonthLock('2099-02', locked: true);
      expect(await AttendanceApprovalService.isLockedForDateKey('2099-02-01'), isTrue);
      expect(await AttendanceApprovalService.isLockedForDateKey('2099-02-28'), isTrue);
      await PayrollLockService.setMonthLock('2099-02', locked: false);
      expect(await AttendanceApprovalService.isLockedForDateKey('2099-02-01'), isFalse);
    });

    test('adjacent month is unaffected by a lock', () async {
      await PayrollLockService.setMonthLock('2099-03', locked: true);
      expect(await AttendanceApprovalService.isLockedForDateKey('2099-04-01'), isFalse);
      await PayrollLockService.setMonthLock('2099-03', locked: false);
    });

    test('a lock cached for ANOTHER shop does not leak into this shop', () async {
      await DBHelper().setPayrollMonthLock(
        PayrollLockService.cacheKey('other_shop', '2099-05'),
        locked: true,
      );
      expect(await AttendanceApprovalService.isLockedForDateKey('2099-05-10'), isFalse);
    });

    test('offline owner can manage locks', () async {
      expect(await PayrollLockService.canManageLocks(), isTrue);
    });
  });

  group('applyApproveAttendanceLogic — locked month blocks, unlocked permits', () {
    test('locked: does not mutate, returns false', () {
      final r = baseRecord()..status = 'pending';
      final applied = AttendanceApprovalService.applyApproveAttendanceLogic(
        record: r,
        approverUid: 'mgr1',
        isLocked: true,
      );
      expect(applied, isFalse);
      expect(r.status, 'pending'); // untouched
      expect(r.approvedBy, isNull);
    });

    test('unlocked: mutates and returns true', () {
      final r = baseRecord()..status = 'pending';
      final applied = AttendanceApprovalService.applyApproveAttendanceLogic(
        record: r,
        approverUid: 'mgr1',
        isLocked: false,
      );
      expect(applied, isTrue);
      expect(r.status, 'approved');
      expect(r.approvedBy, 'mgr1');
    });
  });

  group('applyRejectAttendanceLogic — locked month blocks', () {
    test('locked: does not mutate', () {
      final r = baseRecord()..status = 'pending';
      final applied = AttendanceApprovalService.applyRejectAttendanceLogic(
        record: r,
        reason: 'sai giờ',
        approverUid: 'mgr1',
        isLocked: true,
      );
      expect(applied, isFalse);
      expect(r.status, 'pending');
    });

    test('unlocked: mutates', () {
      final r = baseRecord()..status = 'pending';
      final applied = AttendanceApprovalService.applyRejectAttendanceLogic(
        record: r,
        reason: 'sai giờ',
        approverUid: 'mgr1',
        isLocked: false,
      );
      expect(applied, isTrue);
      expect(r.status, 'rejected');
      expect(r.rejectReason, 'sai giờ');
    });
  });

  group('applyEditOvertimeLogic — locked month blocks OT edit', () {
    test('locked: overtimeOn unchanged', () {
      final r = baseRecord()..overtimeOn = 30;
      final applied = AttendanceApprovalService.applyEditOvertimeLogic(
        record: r,
        overtimeMinutes: 120,
        maxOvertimeMinutes: 240,
        isLocked: true,
      );
      expect(applied, isFalse);
      expect(r.overtimeOn, 30);
    });

    test('unlocked: overtimeOn updated and capped by maxOvertimeMinutes (F-06)', () {
      final r = baseRecord();
      final applied = AttendanceApprovalService.applyEditOvertimeLogic(
        record: r,
        overtimeMinutes: 480, // request 8h
        maxOvertimeMinutes: 240, // configured max 4h
        isLocked: false,
      );
      expect(applied, isTrue);
      expect(r.overtimeOn, 240);
      expect(r.requestType, 'overtime_edit');
    });
  });

  group('applyEditAttendanceTimesLogic — locked month blocks time correction', () {
    test('locked: times unchanged', () {
      final r = baseRecord();
      final originalCheckIn = r.checkInAt;
      final applied = AttendanceApprovalService.applyEditAttendanceTimesLogic(
        record: r,
        checkInAt: DateTime(2026, 9, 25, 9, 30).millisecondsSinceEpoch,
        schedule: cfg,
        isLocked: true,
      );
      expect(applied, isFalse);
      expect(r.checkInAt, originalCheckIn);
    });

    test('unlocked: recomputes isLate via canonical engine', () {
      final r = baseRecord()..isLate = 0;
      final applied = AttendanceApprovalService.applyEditAttendanceTimesLogic(
        record: r,
        checkInAt: DateTime(2026, 9, 25, 9, 30).millisecondsSinceEpoch, // well past grace
        schedule: cfg,
        isLocked: false,
      );
      expect(applied, isTrue);
      expect(r.isLate, 1);
    });
  });

  group('applyForgotCheckinLogic — locked month blocks', () {
    test('locked: returns null', () {
      final result = AttendanceApprovalService.applyForgotCheckinLogic(
        existing: null,
        userId: 'u1',
        email: 'u1@shop.com',
        name: 'NV',
        dateKey: '2026-09-25',
        firestoreId: 'att_20260925_u1',
        checkInAt: DateTime(2026, 9, 25, 8, 0).millisecondsSinceEpoch,
        schedule: cfg,
        isLocked: true,
      );
      expect(result, isNull);
    });

    test('unlocked: builds a new pending record with computed isLate', () {
      final result = AttendanceApprovalService.applyForgotCheckinLogic(
        existing: null,
        userId: 'u1',
        email: 'u1@shop.com',
        name: 'NV',
        dateKey: '2026-09-25',
        firestoreId: 'att_20260925_u1',
        checkInAt: DateTime(2026, 9, 25, 9, 0).millisecondsSinceEpoch, // late
        schedule: cfg,
        isLocked: false,
      );
      expect(result, isNotNull);
      expect(result!.status, 'pending');
      expect(result.requestType, 'forgot_checkin');
      expect(result.isLate, 1);
    });
  });

  group('applyForgotCheckoutLogic — locked month blocks, requires existing check-in', () {
    test('locked: returns null even with a valid existing check-in', () {
      final existing = baseRecord();
      final result = AttendanceApprovalService.applyForgotCheckoutLogic(
        existing: existing,
        dateKey: '2026-09-25',
        checkOutAt: DateTime(2026, 9, 25, 17, 0).millisecondsSinceEpoch,
        schedule: cfg,
        isLocked: true,
      );
      expect(result, isNull);
      expect(existing.checkOutAt, isNull); // untouched
    });

    test('no existing check-in: returns null (never fabricates a check-in)', () {
      final result = AttendanceApprovalService.applyForgotCheckoutLogic(
        existing: null,
        dateKey: '2026-09-25',
        checkOutAt: DateTime(2026, 9, 25, 17, 0).millisecondsSinceEpoch,
        schedule: cfg,
        isLocked: false,
      );
      expect(result, isNull);
    });

    test('unlocked with existing check-in: sets checkOutAt + requestType', () {
      final existing = baseRecord();
      final result = AttendanceApprovalService.applyForgotCheckoutLogic(
        existing: existing,
        dateKey: '2026-09-25',
        checkOutAt: DateTime(2026, 9, 25, 17, 0).millisecondsSinceEpoch,
        schedule: cfg,
        isLocked: false,
      );
      expect(result, isNotNull);
      expect(result!.checkOutAt, isNotNull);
      expect(result.requestType, 'forgot_checkout');
      expect(result.status, 'pending');
    });
  });
}
