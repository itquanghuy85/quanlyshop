import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/models/attendance_model.dart';
import 'package:quanlyshop/services/attendance_check_service.dart';

Attendance _approvedLateRecordWithOt() {
  return Attendance(
    userId: 'u1',
    email: 'u1@shop.com',
    name: 'Nhan Vien A',
    dateKey: '2026-09-25',
    checkInAt: DateTime(2026, 9, 25, 8, 40).millisecondsSinceEpoch, // late
    isLate: 1,
    overtimeOn: 60,
    overtimeStartAt: DateTime(2026, 9, 25, 17, 0).millisecondsSinceEpoch,
    overtimeEndAt: DateTime(2026, 9, 25, 18, 0).millisecondsSinceEpoch,
    status: 'approved',
    approvedBy: 'manager1',
    approvedAt: DateTime(2026, 9, 25, 9, 0).millisecondsSinceEpoch,
    note: 'Tang ca theo yeu cau khach',
    requestType: 'overtime_edit',
    locked: 0,
    createdAt: DateTime(2026, 9, 25, 8, 40).millisecondsSinceEpoch,
  );
}

void main() {
  group('AttendanceCheckService.applyCheckOut — F-01/F-02 regression', () {
    test('checkout survives: isLate stays 1 after a late check-in', () {
      final existing = _approvedLateRecordWithOt();
      final result = AttendanceCheckService.applyCheckOut(
        existing: existing,
        timestamp: DateTime(2026, 9, 25, 18, 5).millisecondsSinceEpoch,
        isEarly: false,
      );
      expect(result, isNotNull);
      expect(result!.isLate, 1, reason: 'checkout must not clear isLate (F-01)');
    });

    test('checkout on time keeps isLate = 0', () {
      final existing = Attendance(
        userId: 'u1',
        email: 'u1@shop.com',
        name: 'NV',
        dateKey: '2026-09-25',
        checkInAt: DateTime(2026, 9, 25, 8, 0).millisecondsSinceEpoch,
        isLate: 0,
        createdAt: DateTime(2026, 9, 25, 8, 0).millisecondsSinceEpoch,
      );
      final result = AttendanceCheckService.applyCheckOut(
        existing: existing,
        timestamp: DateTime(2026, 9, 25, 17, 5).millisecondsSinceEpoch,
        isEarly: false,
      );
      expect(result!.isLate, 0);
    });

    test('checkout preserves overtimeOn/Start/End set by manager', () {
      final existing = _approvedLateRecordWithOt();
      final result = AttendanceCheckService.applyCheckOut(
        existing: existing,
        timestamp: DateTime(2026, 9, 25, 18, 5).millisecondsSinceEpoch,
        isEarly: false,
      );
      expect(result!.overtimeOn, 60);
      expect(result.overtimeStartAt, isNotNull);
      expect(result.overtimeEndAt, isNotNull);
    });

    test('checkout preserves approval (status/approvedBy/approvedAt)', () {
      final existing = _approvedLateRecordWithOt();
      final result = AttendanceCheckService.applyCheckOut(
        existing: existing,
        timestamp: DateTime(2026, 9, 25, 18, 5).millisecondsSinceEpoch,
        isEarly: false,
      );
      expect(result!.status, 'approved');
      expect(result.approvedBy, 'manager1');
      expect(result.approvedAt, isNotNull);
    });

    test('checkout preserves note and requestType', () {
      final existing = _approvedLateRecordWithOt();
      final result = AttendanceCheckService.applyCheckOut(
        existing: existing,
        timestamp: DateTime(2026, 9, 25, 18, 5).millisecondsSinceEpoch,
        isEarly: false,
      );
      expect(result!.note, 'Tang ca theo yeu cau khach');
      expect(result.requestType, 'overtime_edit');
    });

    test('checkout preserves locked flag', () {
      final existing = _approvedLateRecordWithOt()..locked = 1;
      final result = AttendanceCheckService.applyCheckOut(
        existing: existing,
        timestamp: DateTime(2026, 9, 25, 18, 5).millisecondsSinceEpoch,
        isEarly: false,
      );
      expect(result!.locked, 1);
    });

    test('checkout sets checkOutAt, photoOut, isEarlyLeave, isSynced=false', () {
      final existing = _approvedLateRecordWithOt();
      final ts = DateTime(2026, 9, 25, 16, 0).millisecondsSinceEpoch;
      final result = AttendanceCheckService.applyCheckOut(
        existing: existing,
        timestamp: ts,
        isEarly: true,
        photoPath: '/tmp/out.jpg',
      );
      expect(result!.checkOutAt, ts);
      expect(result.photoOut, '/tmp/out.jpg');
      expect(result.isEarlyLeave, 1);
      expect(result.isSynced, isFalse);
    });

    test('checkout without a prior check-in returns null (no fabricated record)', () {
      final result = AttendanceCheckService.applyCheckOut(
        existing: null,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isEarly: false,
      );
      expect(result, isNull);
    });
  });

  group('AttendanceCheckService.applyCheckIn', () {
    test('fresh check-in with no existing record creates a pending record', () {
      final ts = DateTime(2026, 9, 25, 8, 20).millisecondsSinceEpoch;
      final result = AttendanceCheckService.applyCheckIn(
        existing: null,
        userId: 'u1',
        email: 'u1@shop.com',
        name: 'NV',
        dateKey: '2026-09-25',
        firestoreId: 'att_20260925_u1',
        timestamp: ts,
        isLate: true,
      );
      expect(result.checkInAt, ts);
      expect(result.isLate, 1);
      expect(result.status, 'pending');
      expect(result.checkOutAt, isNull);
    });

    test('re-check-in on an existing record does not wipe a prior checkout', () {
      final existing = Attendance(
        userId: 'u1',
        email: 'u1@shop.com',
        name: 'NV',
        dateKey: '2026-09-25',
        checkInAt: DateTime(2026, 9, 25, 8, 0).millisecondsSinceEpoch,
        checkOutAt: DateTime(2026, 9, 25, 12, 0).millisecondsSinceEpoch,
        status: 'approved',
        approvedBy: 'manager1',
        createdAt: DateTime(2026, 9, 25, 8, 0).millisecondsSinceEpoch,
      );
      final ts = DateTime(2026, 9, 25, 13, 0).millisecondsSinceEpoch;
      final result = AttendanceCheckService.applyCheckIn(
        existing: existing,
        userId: 'u1',
        email: 'u1@shop.com',
        name: 'NV',
        dateKey: '2026-09-25',
        firestoreId: 'att_20260925_u1',
        timestamp: ts,
        isLate: false,
      );
      expect(result.checkInAt, ts);
      // Field-level update: unrelated approval fields survive.
      expect(result.status, 'approved');
      expect(result.approvedBy, 'manager1');
    });
  });
}
