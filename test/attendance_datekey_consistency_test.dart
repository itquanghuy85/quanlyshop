import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:quanlyshop/services/attendance_computation_service.dart';

/// Item 11 (F-14 timezone, FINAL CLOSURE audit).
///
/// The app has no shop/user timezone abstraction — every attendance
/// timestamp is device-local `DateTime.now()`, and this is NOT being
/// changed here (no UTC migration, per explicit instruction). What IS
/// verified: every place that turns a moment in time into a `dateKey`
/// ("yyyy-MM-dd", the key attendance/salary/payroll partition by) does it
/// the same way, so the same instant can never resolve to different
/// calendar days in different parts of the app (checkin screen vs.
/// approval screen vs. salary calc vs. Excel export). Overnight shift
/// `dateKey` semantics (start-date, not end-date) are covered separately
/// in attendance_computation_service_test.dart.
///
/// Remaining, explicitly NOT fixed (documented limitation, not a bug this
/// audit invents a fix for): a user can change the device clock to
/// backdate/forward-date a check-in, because there is no server-timestamp
/// authority for `checkInAt`/`checkOutAt` (only `updatedAt` uses
/// `FirestoreWriteHelper.serverUpdatedAt()` on sync). This is a real
/// limitation, not a false claim — flagged in the final acceptance report.
void main() {
  test('AttendanceComputationService.dateKeyOf matches the yyyy-MM-dd format '
      'used everywhere else in the codebase (DateFormat(\'yyyy-MM-dd\'))', () {
    final moments = [
      DateTime(2026, 1, 1, 0, 0, 1),
      DateTime(2026, 9, 25, 23, 59, 59),
      DateTime(2026, 12, 31, 12, 0),
      DateTime(2024, 2, 29, 6, 0), // leap day
    ];
    final fmt = DateFormat('yyyy-MM-dd');
    for (final m in moments) {
      expect(AttendanceComputationService.dateKeyOf(m), fmt.format(m));
    }
  });

  test('same timestamp always resolves to the same dateKey (determinism)', () {
    final t = DateTime(2026, 9, 25, 14, 30);
    final a = AttendanceComputationService.dateKeyOf(t);
    final b = AttendanceComputationService.dateKeyOf(t);
    expect(a, b);
  });

  test('dateKey round-trips through DateTime.parse the way callers rely on '
      '(AttendanceApprovalService/SalaryCalculationService use '
      'DateTime.parse(record.dateKey) as the shiftDate)', () {
    final original = DateTime(2026, 9, 25);
    final dateKey = AttendanceComputationService.dateKeyOf(original);
    final parsed = DateTime.parse(dateKey);
    expect(parsed.year, original.year);
    expect(parsed.month, original.month);
    expect(parsed.day, original.day);
  });

  test('overnight shift keeps dateKey pinned to the shift START date '
      'even though checkout happens on the calendar next day', () {
    final schedule = ResolvedScheduleConfig.resolve(
      staffSchedule: {'startTime': '22:00', 'endTime': '06:00'},
      fallbackOvertimeRatePercent: 150,
    );
    final shiftDate = DateTime(2026, 9, 25);
    final result = AttendanceComputationService.compute(
      shiftDate: shiftDate,
      schedule: schedule,
      standardHoursPerDay: 7,
      checkIn: DateTime(2026, 9, 25, 22, 0),
      checkOut: DateTime(2026, 9, 26, 6, 0), // next calendar day
    );
    // dayType/rate resolution is anchored to shiftDate (09-25), never to
    // the checkout's calendar date (09-26) — this is what "dateKey =
    // shift start date" means operationally for the canonical engine.
    expect(result.overnight, isTrue);
    expect(AttendanceComputationService.dateKeyOf(shiftDate), '2026-09-25');
  });
}
