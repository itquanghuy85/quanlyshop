import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/services/salary_calculation_service.dart';

/// Item 2 (leave/day-off, FINAL CLOSURE audit).
///
/// `SalaryCalculationService.getWorkingDaysInMonth` is the denominator for
/// "ngày nghỉ không phép" (unapproved absence): `absentDays = workingDays -
/// workDays - paidLeaveDays`. Before this fix it only excluded days not in
/// the configured `workDays` set — a company-wide holiday that fell on a
/// normal configured workday (e.g. a Monday) was still counted as a
/// required work day, so an employee who correctly stayed home for the
/// holiday (with no individual leave request — holidays are shop-wide, not
/// per-employee) would be wrongly charged an unapproved absence.
///
/// The rest of the leave audit (approved/pending/rejected leave handling in
/// `calculateMonthlySalary`) was verified by reading the code, not by a new
/// test here, because it requires Firestore/UserService — already correct:
/// - only `status == 'approved'` leave requests are summed into
///   `paidLeaveDays`/`unpaidLeaveDays` (pending/rejected are skipped).
/// - `absentDays` already subtracts `paidLeaveDays`, so approved leave
///   never counts as absence.
/// - a leave day never produces an attendance record (no checkIn), so it
///   can never be flagged late/early, and no automatic OT is ever computed
///   for a day with no checkIn/checkOut.
void main() {
  group('getWorkingDaysInMonth — holiday exclusion (F-11 adjacent fix)', () {
    test('September 2026: Mon-Sat workdays, no holidays -> baseline count', () {
      // September 2026: 30 days. Sundays: 6,13,20,27 (4 Sundays).
      final days = SalaryCalculationService.getWorkingDaysInMonth(
        2026,
        9,
        [1, 2, 3, 4, 5, 6],
      );
      expect(days, 30 - 4); // 26
    });

    test('a holiday on a normal Monday workday is excluded from the count', () {
      // 2026-09-07 is a Monday (part of [1..6]).
      final withoutHoliday = SalaryCalculationService.getWorkingDaysInMonth(
        2026,
        9,
        [1, 2, 3, 4, 5, 6],
      );
      final withHoliday = SalaryCalculationService.getWorkingDaysInMonth(
        2026,
        9,
        [1, 2, 3, 4, 5, 6],
        {'2026-09-07'},
      );
      expect(withHoliday, withoutHoliday - 1);
    });

    test('a holiday on a day already excluded by workDays (e.g. Sunday) '
        'does not double-subtract', () {
      // 2026-09-06 is a Sunday, already excluded by workDays [1..6].
      final withoutHoliday = SalaryCalculationService.getWorkingDaysInMonth(
        2026,
        9,
        [1, 2, 3, 4, 5, 6],
      );
      final withHolidayOnSunday = SalaryCalculationService.getWorkingDaysInMonth(
        2026,
        9,
        [1, 2, 3, 4, 5, 6],
        {'2026-09-06'},
      );
      expect(withHolidayOnSunday, withoutHoliday); // unchanged, no double count
    });

    test('multiple holidays in the same month all get excluded', () {
      final days = SalaryCalculationService.getWorkingDaysInMonth(
        2026,
        9,
        [1, 2, 3, 4, 5, 6],
        {'2026-09-01', '2026-09-02', '2026-09-07'}, // Tue, Wed, Mon
      );
      expect(days, 26 - 3);
    });
  });
}
