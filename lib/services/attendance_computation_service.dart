import 'attendance_schedule_resolver.dart';

/// Canonical day classification for OT-rate selection.
enum AttendanceDayType { holiday, dayOff, weekend, weekday }

/// Canonical, fully-resolved schedule configuration for one attendance
/// record's shift date. Every field is resolved through the same
/// staff-specific -> shop_general -> system-default chain
/// (`AttendanceScheduleResolver`), field by field — a staff override that
/// only sets startTime/endTime/breakTime/maxOtHours/workDays (as the staff
/// schedule editor actually saves — see `staff_list_view.dart`) still falls
/// back to the shop's holidays/OT rates instead of losing them.
class ResolvedScheduleConfig {
  final String startTime;
  final String endTime;
  final int breakMinutes;
  final int maxOvertimeMinutes;
  final List<int> workDays; // Dart weekday values (1=Mon..7=Sun) that ARE working days
  final Set<String> holidayDateKeys; // yyyy-MM-dd
  final double weekdayOtRatePercent;
  final double weekendOtRatePercent;
  final double holidayOtRatePercent;

  const ResolvedScheduleConfig({
    required this.startTime,
    required this.endTime,
    required this.breakMinutes,
    required this.maxOvertimeMinutes,
    required this.workDays,
    required this.holidayDateKeys,
    required this.weekdayOtRatePercent,
    required this.weekendOtRatePercent,
    required this.holidayOtRatePercent,
  });

  /// Used by the shift-swap override (2026-09-26): an approved swap only
  /// changes the TIME WINDOW for one specific date — break/maxOT/workDays/
  /// holidays/rates still come from the normal staff/shop resolution, so
  /// only startTime/endTime are ever overridden here.
  ResolvedScheduleConfig copyWith({String? startTime, String? endTime}) {
    return ResolvedScheduleConfig(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      breakMinutes: breakMinutes,
      maxOvertimeMinutes: maxOvertimeMinutes,
      workDays: workDays,
      holidayDateKeys: holidayDateKeys,
      weekdayOtRatePercent: weekdayOtRatePercent,
      weekendOtRatePercent: weekendOtRatePercent,
      holidayOtRatePercent: holidayOtRatePercent,
    );
  }

  factory ResolvedScheduleConfig.resolve({
    Map<String, dynamic>? staffSchedule,
    Map<String, dynamic>? shopSchedule,
    required double fallbackOvertimeRatePercent,
  }) {
    final times = AttendanceScheduleResolver.effectiveTimes(
      staffSchedule: staffSchedule,
      shopSchedule: shopSchedule,
    );
    return ResolvedScheduleConfig(
      startTime: times['startTime']!,
      endTime: times['endTime']!,
      breakMinutes: _intField(
        staffSchedule,
        shopSchedule,
        'breakTime',
        // breakTime is stored in HOURS in work_schedules (see db_helper
        // schema + work_schedule_settings_view/staff_list_view editors,
        // both default to "1" meaning 1 giờ nghỉ).
        unitToMinutes: 60,
        fallback: 60,
      ),
      maxOvertimeMinutes: _intField(
        staffSchedule,
        shopSchedule,
        'maxOtHours',
        unitToMinutes: 60,
        fallback: 4 * 60,
      ),
      workDays: _resolveWorkDays(staffSchedule, shopSchedule),
      holidayDateKeys: _resolveHolidays(staffSchedule, shopSchedule),
      weekdayOtRatePercent: _doubleField(
        staffSchedule,
        shopSchedule,
        'weekdayOtRate',
        fallback: fallbackOvertimeRatePercent,
      ),
      weekendOtRatePercent: _doubleField(
        staffSchedule,
        shopSchedule,
        'weekendOtRate',
        fallback: fallbackOvertimeRatePercent,
      ),
      holidayOtRatePercent: _doubleField(
        staffSchedule,
        shopSchedule,
        'holidayOtRate',
        fallback: fallbackOvertimeRatePercent,
      ),
    );
  }

  static dynamic _pick(
    Map<String, dynamic>? staff,
    Map<String, dynamic>? shop,
    String key,
  ) {
    final s = staff?[key];
    if (s != null) return s;
    final g = shop?[key];
    if (g != null) return g;
    return null;
  }

  static int _intField(
    Map<String, dynamic>? staff,
    Map<String, dynamic>? shop,
    String key, {
    required int unitToMinutes,
    required int fallback,
  }) {
    final raw = _pick(staff, shop, key);
    if (raw == null) return fallback;
    final n = raw is num ? raw : num.tryParse(raw.toString());
    if (n == null) return fallback;
    return (n.toDouble() * unitToMinutes).round();
  }

  static double _doubleField(
    Map<String, dynamic>? staff,
    Map<String, dynamic>? shop,
    String key, {
    required double fallback,
  }) {
    final raw = _pick(staff, shop, key);
    if (raw == null) return fallback;
    final n = raw is num ? raw : num.tryParse(raw.toString());
    return n?.toDouble() ?? fallback;
  }

  static List<int> _resolveWorkDays(
    Map<String, dynamic>? staff,
    Map<String, dynamic>? shop,
  ) {
    // workDays is one of the few fields the staff-specific editor DOES
    // write (staff_list_view.dart), so an explicit staff value always
    // takes full precedence (no field ever partially-missing here).
    final raw = _pick(staff, shop, 'workDays');
    return AttendanceComputationService.parseWorkDays(raw);
  }

  static Set<String> _resolveHolidays(
    Map<String, dynamic>? staff,
    Map<String, dynamic>? shop,
  ) {
    // holidays is only ever written by the shop-general editor
    // (work_schedule_settings_view.dart) — the staff-specific editor never
    // saves it, so falling back to shop is always correct here, not just
    // "when missing".
    final raw = (staff?['holidays'] as String?)?.isNotEmpty == true
        ? staff!['holidays']
        : shop?['holidays'];
    if (raw is! String || raw.isEmpty) return const {};
    return raw.split(',').where((d) => d.isNotEmpty).toSet();
  }
}

/// Full computation result for one attendance record, produced by
/// [AttendanceComputationService.compute]. Every consumer (AttendanceView,
/// AttendanceManagementView, AttendanceApprovalService,
/// AttendanceSummaryService, SalaryCalculationService, Excel/report) reads
/// from this single structure instead of re-deriving these numbers.
class AttendanceComputationResult {
  final bool isLate;
  final bool isEarlyLeave;
  final bool incomplete; // checkIn present, checkOut missing
  final bool overnight; // scheduled shift crosses midnight
  final AttendanceDayType dayType;
  final int workedMinutes; // elapsed - break, clamped >= 0
  final int regularMinutes; // min(worked, standardMinutes)
  final int automaticOvertimeMinutes; // derived from schedule, capped
  final int manualOvertimeMinutes; // as recorded on the attendance row
  final int effectiveOvertimeMinutes; // manual if >0 else automatic, capped
  final double appliedOvertimeRatePercent; // e.g. 150.0 = 150%

  const AttendanceComputationResult({
    required this.isLate,
    required this.isEarlyLeave,
    required this.incomplete,
    required this.overnight,
    required this.dayType,
    required this.workedMinutes,
    required this.regularMinutes,
    required this.automaticOvertimeMinutes,
    required this.manualOvertimeMinutes,
    required this.effectiveOvertimeMinutes,
    required this.appliedOvertimeRatePercent,
  });
}

/// Single canonical attendance/OT computation engine.
///
/// Formulas below implement the business rules explicitly specified by the
/// product owner (see CLAUDE.md audit 2026-09-25 "FINALIZE" phase, section
/// 2 "CANONICAL BUSINESS RULE") — this is the one and only place that:
/// - resolves which calendar day type applies (holiday > configured
///   non-working day > weekend > normal weekday),
/// - computes worked/regular/overtime minutes (break subtracted, standard
///   hours capped as "regular", overtime only for time beyond the
///   scheduled window),
/// - picks the OT rate for that day type, falling back to
///   EmployeeSalarySettings.overtimeRate when the schedule doesn't
///   configure a rate for that day type,
/// - applies `maxOtHours` as a hard cap on BOTH manual and automatic OT,
/// - handles an overnight shift (end time <= start time of day) by
///   anchoring the scheduled end to the next calendar day.
class AttendanceComputationService {
  /// Parses a work-days configuration from either storage format:
  /// - shop_general: 7-item boolean string indexed Sun..Sat, e.g.
  ///   "0,1,1,1,1,1,0" (see `work_schedule_settings_view.dart`).
  /// - staff-specific: a `List` of raw Dart weekday integers (1=Mon..7=Sun)
  ///   as written directly by `staff_list_view.dart`'s day chips (T2=1 ...
  ///   T7=6, CN=7) — NOT a "UI index 0..6" list. A prior version of this
  ///   parser ran staff lists through the shop_general 0=CN..6=T7 lookup
  ///   table meant only for the string formats, which silently dropped
  ///   Sunday (value 7 is out of that table's 0..6 range) whenever a staff
  ///   explicitly included it. Fixed here — staff lists are used as-is.
  static List<int> parseWorkDays(dynamic wd) {
    const uiToDartWeekday = [7, 1, 2, 3, 4, 5, 6]; // for STRING formats only

    if (wd is List) {
      final result = <int>[];
      for (final v in wd) {
        final day = (v is int) ? v : int.tryParse(v.toString()) ?? -1;
        if (day >= 1 && day <= 7) result.add(day);
      }
      return result.isNotEmpty ? result : const [1, 2, 3, 4, 5, 6];
    }

    if (wd is String) {
      final stripped = wd.replaceAll('[', '').replaceAll(']', '').trim();
      if (stripped.isEmpty) return const [1, 2, 3, 4, 5, 6];
      final parts = stripped.split(',').map((s) => s.trim()).toList();

      if (parts.length == 7 && parts.every((p) => p == '0' || p == '1')) {
        final result = <int>[];
        for (int i = 0; i < 7; i++) {
          if (parts[i] == '1') result.add(uiToDartWeekday[i]);
        }
        return result.isNotEmpty ? result : const [1, 2, 3, 4, 5, 6];
      }

      final result = <int>[];
      for (final p in parts) {
        final idx = int.tryParse(p) ?? -1;
        if (idx >= 0 && idx < 7) result.add(uiToDartWeekday[idx]);
      }
      return result.isNotEmpty ? result : const [1, 2, 3, 4, 5, 6];
    }

    return const [1, 2, 3, 4, 5, 6];
  }

  static String dateKeyOf(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Priority: holiday (1) > not in configured workDays (2) > Sat/Sun (3) >
  /// normal weekday (4). A day off Mon-Fri (not in workDays) and an actual
  /// Sat/Sun both resolve to the "weekend" OT-rate tier per business rule
  /// 2.2/2.9 ("weekend rate applies to non-working days too"); `dayOff` is
  /// kept as a distinct enum value purely for reporting/labeling.
  static AttendanceDayType resolveDayType(
    DateTime shiftDate,
    ResolvedScheduleConfig schedule,
  ) {
    if (schedule.holidayDateKeys.contains(dateKeyOf(shiftDate))) {
      return AttendanceDayType.holiday;
    }
    if (!schedule.workDays.contains(shiftDate.weekday)) {
      return (shiftDate.weekday == DateTime.saturday ||
              shiftDate.weekday == DateTime.sunday)
          ? AttendanceDayType.weekend
          : AttendanceDayType.dayOff;
    }
    if (shiftDate.weekday == DateTime.saturday ||
        shiftDate.weekday == DateTime.sunday) {
      return AttendanceDayType.weekend;
    }
    return AttendanceDayType.weekday;
  }

  static double overtimeRateFor(
    AttendanceDayType dayType,
    ResolvedScheduleConfig schedule,
  ) {
    switch (dayType) {
      case AttendanceDayType.holiday:
        return schedule.holidayOtRatePercent;
      case AttendanceDayType.weekend:
      case AttendanceDayType.dayOff:
        return schedule.weekendOtRatePercent;
      case AttendanceDayType.weekday:
        return schedule.weekdayOtRatePercent;
    }
  }

  /// Resolves the scheduled start/end as concrete DateTimes anchored to
  /// [shiftDate] (the attendance record's dateKey date — i.e. the day the
  /// shift STARTS, per business rule 2.10). When the configured end time
  /// is not after the start time of day, the shift is overnight and the
  /// end is rolled to the next calendar day.
  static ({DateTime start, DateTime end, bool overnight}) effectiveWindow(
    DateTime shiftDate,
    ResolvedScheduleConfig schedule,
  ) {
    final start = AttendanceScheduleResolver.timeOnDate(
      shiftDate,
      schedule.startTime,
    );
    var end = AttendanceScheduleResolver.timeOnDate(
      shiftDate,
      schedule.endTime,
    );
    final overnight = !end.isAfter(start);
    if (overnight) {
      end = end.add(const Duration(days: 1));
    }
    return (start: start, end: end, overnight: overnight);
  }

  /// Thin wrapper used by callers that only need the late flag (e.g. right
  /// at check-in time, before a checkout/standardHoursPerDay exists).
  static bool isLateCheckIn(
    DateTime checkIn,
    DateTime shiftDate,
    ResolvedScheduleConfig schedule,
  ) {
    final window = effectiveWindow(shiftDate, schedule);
    return checkIn.isAfter(
      window.start.add(
        const Duration(minutes: AttendanceScheduleResolver.lateGraceMinutes),
      ),
    );
  }

  /// Thin wrapper used by callers that only need the early-leave flag.
  static bool isEarlyCheckOut(
    DateTime checkOut,
    DateTime shiftDate,
    ResolvedScheduleConfig schedule,
  ) {
    final window = effectiveWindow(shiftDate, schedule);
    return checkOut.isBefore(window.end);
  }

  /// Full computation for one attendance record.
  ///
  /// [shiftDate] must be the record's dateKey date (the calendar day the
  /// shift is scheduled to start), independent of what [checkIn] ends up
  /// being — this is what makes overnight-shift math correct even if
  /// [checkIn] is null (e.g. computing day type for a leave day).
  static AttendanceComputationResult compute({
    required DateTime shiftDate,
    required ResolvedScheduleConfig schedule,
    required double standardHoursPerDay,
    DateTime? checkIn,
    DateTime? checkOut,
    int manualOvertimeMinutes = 0,
  }) {
    final window = effectiveWindow(shiftDate, schedule);
    final dayType = resolveDayType(shiftDate, schedule);
    final rate = overtimeRateFor(dayType, schedule);

    final isLate = checkIn != null &&
        checkIn.isAfter(
          window.start.add(
            const Duration(minutes: AttendanceScheduleResolver.lateGraceMinutes),
          ),
        );
    final isEarly = checkOut != null && checkOut.isBefore(window.end);
    final incomplete = checkIn != null && checkOut == null;

    int workedMinutes = 0;
    int regularMinutes = 0;
    int automaticOt = 0;
    final standardMinutes = (standardHoursPerDay * 60).round();

    if (checkIn != null && checkOut != null) {
      final elapsedMinutes = checkOut.difference(checkIn).inMinutes;
      workedMinutes = (elapsedMinutes - schedule.breakMinutes).clamp(0, 1 << 30);
      regularMinutes = workedMinutes < standardMinutes
          ? workedMinutes
          : standardMinutes;
      // Automatic OT only counts time actually worked past the SCHEDULED
      // window end (rule 2.6) — arriving early does not create OT, and
      // "worked past standard hours" alone is not enough if the employee
      // simply checked out before the scheduled end (already captured as
      // early leave, not OT).
      if (checkOut.isAfter(window.end)) {
        // Only the portion of worked time that is both past the scheduled
        // end AND in excess of regular/standard hours counts as OT — this
        // is what stops a late arrival (checkIn after start) from turning
        // into "OT" just because checkout also lands after the scheduled
        // end while total worked time never actually exceeded standard.
        final byElapsed = workedMinutes - regularMinutes;
        final byScheduleEnd = checkOut.difference(window.end).inMinutes;
        automaticOt = (byElapsed < byScheduleEnd ? byElapsed : byScheduleEnd)
            .clamp(0, schedule.maxOvertimeMinutes);
      }
    }

    final cappedManual = manualOvertimeMinutes.clamp(0, schedule.maxOvertimeMinutes);
    final effectiveOt = cappedManual > 0 ? cappedManual : automaticOt;

    return AttendanceComputationResult(
      isLate: isLate,
      isEarlyLeave: isEarly,
      incomplete: incomplete,
      overnight: window.overnight,
      dayType: dayType,
      workedMinutes: workedMinutes,
      regularMinutes: regularMinutes,
      automaticOvertimeMinutes: automaticOt,
      manualOvertimeMinutes: cappedManual,
      effectiveOvertimeMinutes: effectiveOt,
      appliedOvertimeRatePercent: rate,
    );
  }
}
