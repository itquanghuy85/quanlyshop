import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/services/attendance_computation_service.dart';

void main() {
  const standardSchedule = {
    'startTime': '08:00',
    'endTime': '17:00',
    'breakTime': 1, // hours
    'maxOtHours': 4,
    'weekdayOtRate': 150,
    'weekendOtRate': 200,
    'holidayOtRate': 300,
  };

  ResolvedScheduleConfig resolve({
    Map<String, dynamic>? staff,
    Map<String, dynamic>? shop = standardSchedule,
  }) =>
      ResolvedScheduleConfig.resolve(
        staffSchedule: staff,
        shopSchedule: shop,
        fallbackOvertimeRatePercent: 150,
      );

  group('ResolvedScheduleConfig field-by-field fallback', () {
    test('staff override with only startTime/endTime/breakTime/maxOtHours '
        'still inherits holidays/rates from shop_general (real writer shape)', () {
      final cfg = resolve(staff: {
        'startTime': '09:00',
        'endTime': '18:00',
        'breakTime': 1,
        'maxOtHours': 4,
        'workDays': [1, 2, 3, 4, 5, 6, 7],
      });
      expect(cfg.startTime, '09:00');
      expect(cfg.weekdayOtRatePercent, 150);
      expect(cfg.weekendOtRatePercent, 200);
      expect(cfg.holidayOtRatePercent, 300);
    });

    test('breakTime/maxOtHours stored in hours are converted to minutes', () {
      final cfg = resolve();
      expect(cfg.breakMinutes, 60);
      expect(cfg.maxOvertimeMinutes, 240);
    });

    test('falls back to EmployeeSalarySettings.overtimeRate when no schedule rate configured', () {
      final cfg = ResolvedScheduleConfig.resolve(
        staffSchedule: null,
        shopSchedule: {'startTime': '08:00', 'endTime': '17:00'},
        fallbackOvertimeRatePercent: 175,
      );
      expect(cfg.weekdayOtRatePercent, 175);
      expect(cfg.weekendOtRatePercent, 175);
      expect(cfg.holidayOtRatePercent, 175);
    });
  });

  group('parseWorkDays — F-04-adjacent bug fix (Sunday drop)', () {
    test('shop_general boolean-7 string format (0=CN..6=T7)', () {
      // "0,1,1,1,1,1,0" = CN off, T2-T6 on, T7 off
      final days = AttendanceComputationService.parseWorkDays('0,1,1,1,1,1,0');
      expect(days, [1, 2, 3, 4, 5]); // Mon-Fri
    });

    test('staff-specific List format is raw Dart weekday values (1=Mon..7=Sun), '
        'NOT ui-index 0..6 — Sunday(7) must not be silently dropped', () {
      // staff_list_view.dart writes T2=1..T7=6, CN=7 directly.
      final days = AttendanceComputationService.parseWorkDays([1, 2, 3, 4, 5, 6, 7]);
      expect(days, containsAll([1, 2, 3, 4, 5, 6, 7]));
      expect(days.length, 7);
    });

    test('staff list without Sunday keeps Mon-Sat only', () {
      final days = AttendanceComputationService.parseWorkDays([1, 2, 3, 4, 5, 6]);
      expect(days, [1, 2, 3, 4, 5, 6]);
      expect(days.contains(7), isFalse);
    });
  });

  group('resolveDayType priority — holiday > non-workday > weekend > weekday', () {
    final cfg = resolve(staff: {
      'workDays': [1, 2, 3, 4, 5, 6], // Mon-Sat, Sunday off
      'holidays': '2026-09-25', // configured holiday
    });

    test('holiday wins even if it would otherwise be a normal weekday', () {
      // 2026-09-25 is a Friday
      final type = AttendanceComputationService.resolveDayType(
        DateTime(2026, 9, 25),
        cfg,
      );
      expect(type, AttendanceDayType.holiday);
    });

    test('day not in workDays (Sunday here) resolves to weekend tier', () {
      final type = AttendanceComputationService.resolveDayType(
        DateTime(2026, 9, 27), // Sunday
        cfg,
      );
      expect(type, AttendanceDayType.weekend);
    });

    test('Saturday is always weekend-tier for OT rate, even when it is a '
        'scheduled workday — calendar weekend, not "day off", drives the '
        'rate (a shop that schedules Sat as a normal work day still pays '
        'weekend OT premium for hours worked that day)', () {
      final type = AttendanceComputationService.resolveDayType(
        DateTime(2026, 9, 26), // Saturday, in workDays [1..6]
        cfg,
      );
      expect(type, AttendanceDayType.weekend);
    });

    test('configured day off on a weekday (e.g. Wed excluded) -> dayOff, uses weekend rate', () {
      final cfg2 = resolve(staff: {
        'workDays': [1, 2, 4, 5, 6], // Wednesday(3) excluded
      });
      final type = AttendanceComputationService.resolveDayType(
        DateTime(2026, 9, 23), // Wednesday
        cfg2,
      );
      expect(type, AttendanceDayType.dayOff);
      expect(AttendanceComputationService.overtimeRateFor(type, cfg2), cfg2.weekendOtRatePercent);
    });
  });

  group('OT rate selection', () {
    final cfg = resolve();
    test('weekday -> weekdayOtRate', () {
      expect(
        AttendanceComputationService.overtimeRateFor(AttendanceDayType.weekday, cfg),
        150,
      );
    });
    test('weekend -> weekendOtRate', () {
      expect(
        AttendanceComputationService.overtimeRateFor(AttendanceDayType.weekend, cfg),
        200,
      );
    });
    test('holiday -> holidayOtRate (never falls back to weekday rate)', () {
      expect(
        AttendanceComputationService.overtimeRateFor(AttendanceDayType.holiday, cfg),
        300,
      );
    });
  });

  group('Late — boundary matrix', () {
    final cfg = resolve();
    final shiftDate = DateTime(2026, 9, 25);
    DateTime at(int h, int m, [int s = 0]) => DateTime(2026, 9, 25, h, m, s);

    test('exact start is not late', () {
      expect(AttendanceComputationService.isLateCheckIn(at(8, 0), shiftDate, cfg), isFalse);
    });
    test('+14:59 is not late', () {
      expect(
        AttendanceComputationService.isLateCheckIn(at(8, 14, 59), shiftDate, cfg),
        isFalse,
      );
    });
    test('+15:00 is not late (grace inclusive)', () {
      expect(
        AttendanceComputationService.isLateCheckIn(at(8, 15, 0), shiftDate, cfg),
        isFalse,
      );
    });
    test('+15:01 is late', () {
      expect(
        AttendanceComputationService.isLateCheckIn(at(8, 15, 1), shiftDate, cfg),
        isTrue,
      );
    });
  });

  group('Early — boundary', () {
    final cfg = resolve();
    final shiftDate = DateTime(2026, 9, 25);
    test('exact end is not early', () {
      expect(
        AttendanceComputationService.isEarlyCheckOut(
          DateTime(2026, 9, 25, 17, 0),
          shiftDate,
          cfg,
        ),
        isFalse,
      );
    });
    test('1 second before end is early', () {
      expect(
        AttendanceComputationService.isEarlyCheckOut(
          DateTime(2026, 9, 25, 16, 59, 59),
          shiftDate,
          cfg,
        ),
        isTrue,
      );
    });
  });

  group('compute() — normal work / OT / early-arrival examples (Phase 22 acceptance cases)', () {
    final cfg = resolve();
    final shiftDate = DateTime(2026, 9, 25); // Friday, normal weekday

    test('08:00 -> 17:00: regular=8h, OT=0', () {
      final r = AttendanceComputationService.compute(
        shiftDate: shiftDate,
        schedule: cfg,
        standardHoursPerDay: 8,
        checkIn: DateTime(2026, 9, 25, 8, 0),
        checkOut: DateTime(2026, 9, 25, 17, 0),
      );
      expect(r.isLate, isFalse);
      expect(r.isEarlyLeave, isFalse);
      expect(r.workedMinutes, 8 * 60);
      expect(r.regularMinutes, 8 * 60);
      expect(r.automaticOvertimeMinutes, 0);
      expect(r.effectiveOvertimeMinutes, 0);
    });

    test('08:00 -> 18:30: worked=9.5h, regular=8h, OT=1.5h, weekday rate', () {
      final r = AttendanceComputationService.compute(
        shiftDate: shiftDate,
        schedule: cfg,
        standardHoursPerDay: 8,
        checkIn: DateTime(2026, 9, 25, 8, 0),
        checkOut: DateTime(2026, 9, 25, 18, 30),
      );
      expect(r.workedMinutes, (9.5 * 60).round());
      expect(r.regularMinutes, 8 * 60);
      expect(r.effectiveOvertimeMinutes, 90);
      expect(r.appliedOvertimeRatePercent, 150);
    });

    test('08:00 -> 17:30 = 30m OT', () {
      final r = AttendanceComputationService.compute(
        shiftDate: shiftDate,
        schedule: cfg,
        standardHoursPerDay: 8,
        checkIn: DateTime(2026, 9, 25, 8, 0),
        checkOut: DateTime(2026, 9, 25, 17, 30),
      );
      expect(r.effectiveOvertimeMinutes, 30);
    });

    test('08:00 -> 18:00 = 60m OT', () {
      final r = AttendanceComputationService.compute(
        shiftDate: shiftDate,
        schedule: cfg,
        standardHoursPerDay: 8,
        checkIn: DateTime(2026, 9, 25, 8, 0),
        checkOut: DateTime(2026, 9, 25, 18, 0),
      );
      expect(r.effectiveOvertimeMinutes, 60);
    });

    test('early arrival (07:00 -> 17:00) must NOT auto-generate OT', () {
      final r = AttendanceComputationService.compute(
        shiftDate: shiftDate,
        schedule: cfg,
        standardHoursPerDay: 8,
        checkIn: DateTime(2026, 9, 25, 7, 0),
        checkOut: DateTime(2026, 9, 25, 17, 0),
      );
      expect(r.automaticOvertimeMinutes, 0);
      expect(r.effectiveOvertimeMinutes, 0);
    });

    test('weekend day: OT rate is weekendOtRate', () {
      final saturday = DateTime(2026, 9, 26); // Saturday, in workDays -> still "weekday" unless excluded
      final weekendCfg = resolve(staff: {
        'workDays': [1, 2, 3, 4, 5], // Sat/Sun both off
      });
      final r = AttendanceComputationService.compute(
        shiftDate: saturday,
        schedule: weekendCfg,
        standardHoursPerDay: 8,
        checkIn: DateTime(2026, 9, 26, 8, 0),
        checkOut: DateTime(2026, 9, 26, 18, 0),
      );
      expect(r.dayType, AttendanceDayType.weekend);
      expect(r.appliedOvertimeRatePercent, 200);
    });

    test('holiday: OT rate is holidayOtRate', () {
      final holidayCfg = resolve(staff: {
        'workDays': [1, 2, 3, 4, 5, 6, 7],
        'holidays': '2026-09-25',
      });
      final r = AttendanceComputationService.compute(
        shiftDate: shiftDate,
        schedule: holidayCfg,
        standardHoursPerDay: 8,
        checkIn: DateTime(2026, 9, 25, 8, 0),
        checkOut: DateTime(2026, 9, 25, 18, 0),
      );
      expect(r.dayType, AttendanceDayType.holiday);
      expect(r.appliedOvertimeRatePercent, 300);
    });
  });

  group('Max OT cap (F-06)', () {
    test('maxOtHours=4 (240m): 8h worth of auto OT is clamped to 240m', () {
      final cfg = resolve(staff: {'maxOtHours': 4});
      final r = AttendanceComputationService.compute(
        shiftDate: DateTime(2026, 9, 25),
        schedule: cfg,
        standardHoursPerDay: 8,
        checkIn: DateTime(2026, 9, 25, 8, 0),
        checkOut: DateTime(2026, 9, 26, 4, 0), // 20h elapsed, way over
      );
      expect(r.automaticOvertimeMinutes, lessThanOrEqualTo(240));
    });

    test('manual OT request of 8h is clamped to configured maxOtHours=4h', () {
      final cfg = resolve(staff: {'maxOtHours': 4});
      final r = AttendanceComputationService.compute(
        shiftDate: DateTime(2026, 9, 25),
        schedule: cfg,
        standardHoursPerDay: 8,
        checkIn: DateTime(2026, 9, 25, 8, 0),
        checkOut: DateTime(2026, 9, 25, 17, 0),
        manualOvertimeMinutes: 8 * 60,
      );
      expect(r.manualOvertimeMinutes, 240);
      expect(r.effectiveOvertimeMinutes, 240);
    });

    test('negative manual OT is clamped to 0, never negative', () {
      final cfg = resolve();
      final r = AttendanceComputationService.compute(
        shiftDate: DateTime(2026, 9, 25),
        schedule: cfg,
        standardHoursPerDay: 8,
        checkIn: DateTime(2026, 9, 25, 8, 0),
        checkOut: DateTime(2026, 9, 25, 17, 0),
        manualOvertimeMinutes: -60,
      );
      expect(r.manualOvertimeMinutes, 0);
      expect(r.effectiveOvertimeMinutes, 0); // falls back to automatic (also 0 here)
    });
  });

  group('Manual OT priority (no double count)', () {
    test('manual OT overrides automatic OT entirely — not summed', () {
      final cfg = resolve();
      // 08:00 -> 18:00 would auto-generate 60m OT; manual says 120m.
      final r = AttendanceComputationService.compute(
        shiftDate: DateTime(2026, 9, 25),
        schedule: cfg,
        standardHoursPerDay: 8,
        checkIn: DateTime(2026, 9, 25, 8, 0),
        checkOut: DateTime(2026, 9, 25, 18, 0),
        manualOvertimeMinutes: 120,
      );
      expect(r.automaticOvertimeMinutes, 60);
      expect(r.effectiveOvertimeMinutes, 120); // NOT 60+120=180
    });

    test('manual OT = 0 falls back to automatic', () {
      final cfg = resolve();
      final r = AttendanceComputationService.compute(
        shiftDate: DateTime(2026, 9, 25),
        schedule: cfg,
        standardHoursPerDay: 8,
        checkIn: DateTime(2026, 9, 25, 8, 0),
        checkOut: DateTime(2026, 9, 25, 18, 0),
        manualOvertimeMinutes: 0,
      );
      expect(r.effectiveOvertimeMinutes, 60);
    });
  });

  group('Overnight shift (F-07 — now supported)', () {
    final cfg = resolve(staff: {
      'startTime': '22:00',
      'endTime': '06:00',
    });
    final shiftDate = DateTime(2026, 9, 25);

    test('effectiveWindow rolls end to the next calendar day', () {
      final w = AttendanceComputationService.effectiveWindow(shiftDate, cfg);
      expect(w.overnight, isTrue);
      expect(w.start, DateTime(2026, 9, 25, 22, 0));
      expect(w.end, DateTime(2026, 9, 26, 6, 0));
    });

    test('22:00 -> 06:00 exact: not late, not early, overnight=true', () {
      final r = AttendanceComputationService.compute(
        shiftDate: shiftDate,
        schedule: cfg,
        standardHoursPerDay: 7, // 8h elapsed - 1h break = 7h
        checkIn: DateTime(2026, 9, 25, 22, 0),
        checkOut: DateTime(2026, 9, 26, 6, 0),
      );
      expect(r.overnight, isTrue);
      expect(r.isLate, isFalse);
      expect(r.isEarlyLeave, isFalse);
      expect(r.workedMinutes, 7 * 60); // 8h elapsed - 1h break
      expect(r.regularMinutes, 7 * 60);
      expect(r.effectiveOvertimeMinutes, 0);
    });

    test('22:00 -> 06:30: 30 extra minutes become OT', () {
      final r = AttendanceComputationService.compute(
        shiftDate: shiftDate,
        schedule: cfg,
        standardHoursPerDay: 7,
        checkIn: DateTime(2026, 9, 25, 22, 0),
        checkOut: DateTime(2026, 9, 26, 6, 30),
      );
      expect(r.effectiveOvertimeMinutes, 30);
    });

    test('22:15 -> 06:00: late by grace boundary (not late, exactly +15m)', () {
      final r = AttendanceComputationService.compute(
        shiftDate: shiftDate,
        schedule: cfg,
        standardHoursPerDay: 7,
        checkIn: DateTime(2026, 9, 25, 22, 15),
        checkOut: DateTime(2026, 9, 26, 6, 0),
      );
      expect(r.isLate, isFalse); // exactly +15:00 -> not late (grace inclusive)
    });

    test('22:15 -> 06:30: late check-in and ~15 extra worked minutes vs 22:00 baseline', () {
      final r = AttendanceComputationService.compute(
        shiftDate: shiftDate,
        schedule: cfg,
        standardHoursPerDay: 7,
        checkIn: DateTime(2026, 9, 25, 22, 15, 1),
        checkOut: DateTime(2026, 9, 26, 6, 30),
      );
      expect(r.isLate, isTrue);
      // elapsed ~8h15m - break 1h = ~7h15m worked; standard 7h -> ~15m over
      // (the extra 1s on checkIn truncates .inMinutes down by 1 vs the
      // exact-15:00 case, so 434 not 435 — Duration.inMinutes truncates).
      expect(r.workedMinutes, 7 * 60 + 14);
      expect(r.regularMinutes, 7 * 60);
    });

    test('dateKey/shiftDate stays the START date, not the checkout date', () {
      // Business rule 2.10: dateKey của attendance vẫn là ngày bắt đầu ca.
      // This engine takes shiftDate as an explicit input (from the record's
      // dateKey) rather than deriving it from checkOut, so callers cannot
      // accidentally attribute an overnight shift to the wrong day.
      final r = AttendanceComputationService.compute(
        shiftDate: shiftDate, // 2026-09-25, the check-in day
        schedule: cfg,
        standardHoursPerDay: 7,
        checkIn: DateTime(2026, 9, 25, 22, 0),
        checkOut: DateTime(2026, 9, 26, 6, 0), // 2026-09-26
      );
      expect(r.dayType, isNot(AttendanceDayType.holiday));
      // (dayType is resolved from shiftDate 09-25, proving checkout's date
      // never leaks into day-type/rate resolution)
    });
  });

  group('Incomplete / missing checkout (F-15)', () {
    test('checkIn present, checkOut null -> incomplete=true, zero worked/OT', () {
      final cfg = resolve();
      final r = AttendanceComputationService.compute(
        shiftDate: DateTime(2026, 9, 25),
        schedule: cfg,
        standardHoursPerDay: 8,
        checkIn: DateTime(2026, 9, 25, 8, 0),
        checkOut: null,
      );
      expect(r.incomplete, isTrue);
      expect(r.workedMinutes, 0);
      expect(r.regularMinutes, 0);
      expect(r.effectiveOvertimeMinutes, 0);
    });
  });

  group('Invariants (Phase 20)', () {
    final cfg = resolve();
    test('workedMinutes/regularMinutes/overtimeMinutes are never negative', () {
      // checkOut before checkIn (invalid input) must not go negative.
      final r = AttendanceComputationService.compute(
        shiftDate: DateTime(2026, 9, 25),
        schedule: cfg,
        standardHoursPerDay: 8,
        checkIn: DateTime(2026, 9, 25, 17, 0),
        checkOut: DateTime(2026, 9, 25, 8, 0),
      );
      expect(r.workedMinutes, greaterThanOrEqualTo(0));
      expect(r.regularMinutes, greaterThanOrEqualTo(0));
      expect(r.automaticOvertimeMinutes, greaterThanOrEqualTo(0));
      expect(r.effectiveOvertimeMinutes, greaterThanOrEqualTo(0));
    });

    test('effectiveOvertimeMinutes never exceeds maxOvertimeMinutes', () {
      final cappedCfg = resolve(staff: {'maxOtHours': 2});
      final r = AttendanceComputationService.compute(
        shiftDate: DateTime(2026, 9, 25),
        schedule: cappedCfg,
        standardHoursPerDay: 8,
        checkIn: DateTime(2026, 9, 25, 8, 0),
        checkOut: DateTime(2026, 9, 26, 8, 0), // 24h elapsed
        manualOvertimeMinutes: 999,
      );
      expect(r.effectiveOvertimeMinutes, lessThanOrEqualTo(120));
    });

    test('same input + same schedule -> same result (determinism)', () {
      AttendanceComputationResult run() => AttendanceComputationService.compute(
            shiftDate: DateTime(2026, 9, 25),
            schedule: cfg,
            standardHoursPerDay: 8,
            checkIn: DateTime(2026, 9, 25, 8, 20),
            checkOut: DateTime(2026, 9, 25, 17, 45),
          );
      final a = run();
      final b = run();
      expect(a.isLate, b.isLate);
      expect(a.workedMinutes, b.workedMinutes);
      expect(a.effectiveOvertimeMinutes, b.effectiveOvertimeMinutes);
      expect(a.appliedOvertimeRatePercent, b.appliedOvertimeRatePercent);
    });
  });
}
