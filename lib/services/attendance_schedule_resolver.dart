/// Single source of truth for resolving a staff member's effective raw
/// schedule TIME STRINGS (startTime/endTime) via the staff-specific ->
/// shop_general -> default chain.
///
/// Root cause fix (CLAUDE.md audit 2026-09-25, ROOT B / F-03): before this,
/// `AttendanceView` read only the per-uid `work_schedules` row and silently
/// fell back to hardcoded 08:00-17:00 when it was missing, while
/// `SalaryCalculationService` already fell back to the `shop_general` row.
///
/// All other schedule-derived computation (late/early clock, day type,
/// worked/regular/overtime minutes, overnight handling, OT rate) now lives
/// in `AttendanceComputationService`, which builds on top of this class —
/// keep this file limited to the raw string-resolution chain so there is
/// exactly one place that does the actual clock math.
class AttendanceScheduleResolver {
  /// Minutes of grace after the scheduled start time before a check-in is
  /// flagged late. This is the CLOCK grace (when the flag flips), distinct
  /// from any payroll "allowed late occurrences before deduction" grace
  /// (see ShopDeductionSettings.lateGraceTimes) — the two must not be mixed.
  static const int lateGraceMinutes = 15;

  static const String defaultStartTime = '08:00';
  static const String defaultEndTime = '17:00';

  /// Resolution chain: staff-specific schedule -> shop_general schedule ->
  /// hardcoded default. [staffSchedule] and [shopSchedule] are the raw rows
  /// as returned by `DBHelper.getWorkSchedule` (nullable maps).
  static Map<String, String> effectiveTimes({
    Map<String, dynamic>? staffSchedule,
    Map<String, dynamic>? shopSchedule,
  }) {
    final start = _stringField(staffSchedule, 'startTime') ??
        _stringField(shopSchedule, 'startTime') ??
        defaultStartTime;
    final end = _stringField(staffSchedule, 'endTime') ??
        _stringField(shopSchedule, 'endTime') ??
        defaultEndTime;
    return {'startTime': start, 'endTime': end};
  }

  static String? _stringField(Map<String, dynamic>? map, String key) {
    final v = map?[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static DateTime timeOnDate(DateTime date, String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}
