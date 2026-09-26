import '../models/attendance_model.dart';
import '../models/attendance_monthly_summary_model.dart';
import 'attendance_computation_service.dart';

class AttendanceSummaryService {
  static bool isPendingLike(Attendance record) {
    return record.checkInAt != null &&
        record.status != 'approved' &&
        record.status != 'rejected';
  }

  /// [scheduleByUserId]/[standardHoursByUserId] (Phase 5/12 fix): the
  /// dashboard summary ("Giờ công X • OT Y") and the Excel monthly-summary
  /// export both read `totalWorkMinutes`/`overtimeMinutes` from this
  /// service's output. Before this fix they were raw
  /// `checkOut - checkIn` (no break subtracted) and the raw stored
  /// `overtimeOn` (no automatic-OT fallback, no maxOtHours cap) — silently
  /// diverging from what SalaryCalculationService actually pays. Both
  /// numbers now go through the same `AttendanceComputationService.compute`
  /// canonical engine as salary. A missing entry in the maps falls back to
  /// the engine's own defaults (08:00-17:00, no break, 8h standard) —
  /// callers should always populate them from `DBHelper.getWorkSchedule`
  /// (see `AttendanceApprovalService.resolveComputationInputs` for the
  /// resolution chain every other call site already uses).
  /// [scheduleOverrideByKey] (2026-09-26 shift-swap redesign): an approved
  /// swap only changes ONE day's schedule, so the caller resolves it
  /// per-record (async, via
  /// `AttendanceApprovalService.getApprovedShiftSwapOverride`) and passes
  /// the result here keyed by `"userId|dateKey"` — this function itself
  /// stays synchronous/pure (no DB access) for testability, matching
  /// AttendanceComputationService's own design.
  static List<AttendanceMonthlySummary> buildMonthlySummaries({
    required List<Map<String, dynamic>> staffList,
    required Map<String, List<Attendance>> staffAttendance,
    Map<String, ResolvedScheduleConfig> scheduleByUserId = const {},
    Map<String, double> standardHoursByUserId = const {},
    Map<String, ResolvedScheduleConfig> scheduleOverrideByKey = const {},
  }) {
    final defaultSchedule = ResolvedScheduleConfig.resolve(
      fallbackOvertimeRatePercent: 150,
    );

    final summaries = staffList.map((staff) {
      final userId = staff['id'] as String? ?? '';
      final records = List<Attendance>.from(
        staffAttendance[userId] ?? const [],
      );
      records.sort((a, b) => a.dateKey.compareTo(b.dateKey));
      return _buildSummary(
        userId: userId,
        name: staff['name'] as String? ?? 'NV',
        email: staff['email'] as String? ?? '',
        role: staff['role'] as String? ?? 'employee',
        records: records,
        schedule: scheduleByUserId[userId] ?? defaultSchedule,
        standardHoursPerDay: standardHoursByUserId[userId] ?? 8.0,
        scheduleOverrideByKey: scheduleOverrideByKey,
      );
    }).toList();

    summaries.sort((a, b) {
      const order = {'owner': 0, 'manager': 1, 'technician': 2, 'employee': 3};
      final roleCompare = (order[a.role] ?? 99).compareTo(order[b.role] ?? 99);
      if (roleCompare != 0) return roleCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return summaries;
  }

  static AttendanceMonthlySummary _buildSummary({
    required String userId,
    required String name,
    required String email,
    required String role,
    required List<Attendance> records,
    required ResolvedScheduleConfig schedule,
    required double standardHoursPerDay,
    Map<String, ResolvedScheduleConfig> scheduleOverrideByKey = const {},
  }) {
    var workDays = 0;
    var approvedDays = 0;
    var pendingDays = 0;
    var rejectedDays = 0;
    var lateDays = 0;
    var earlyLeaveDays = 0;
    var incompleteDays = 0;
    var totalWorkMinutes = 0;
    var overtimeMinutes = 0;

    for (final record in records) {
      final hasCheckIn = record.checkInAt != null;
      final hasCheckOut = record.checkOutAt != null;

      if (hasCheckIn) {
        workDays++;
      }

      if (record.status == 'approved' && hasCheckIn) {
        approvedDays++;
      } else if (record.status == 'rejected' && hasCheckIn) {
        rejectedDays++;
      } else if (isPendingLike(record)) {
        pendingDays++;
      }

      if (record.isLate == 1) {
        lateDays++;
      }
      if (record.isEarlyLeave == 1) {
        earlyLeaveDays++;
      }
      if (hasCheckIn && !hasCheckOut) {
        incompleteDays++;
      }

      if (hasCheckIn && hasCheckOut) {
        final effectiveSchedule =
            scheduleOverrideByKey['$userId|${record.dateKey}'] ?? schedule;
        final result = AttendanceComputationService.compute(
          shiftDate: DateTime.parse(record.dateKey),
          schedule: effectiveSchedule,
          standardHoursPerDay: standardHoursPerDay,
          checkIn: DateTime.fromMillisecondsSinceEpoch(record.checkInAt!),
          checkOut: DateTime.fromMillisecondsSinceEpoch(record.checkOutAt!),
          manualOvertimeMinutes: record.overtimeOn,
        );
        totalWorkMinutes += result.workedMinutes;
        overtimeMinutes += result.effectiveOvertimeMinutes;
      }
    }

    return AttendanceMonthlySummary(
      userId: userId,
      name: name,
      email: email,
      role: role,
      totalRecords: records.length,
      workDays: workDays,
      approvedDays: approvedDays,
      pendingDays: pendingDays,
      rejectedDays: rejectedDays,
      lateDays: lateDays,
      earlyLeaveDays: earlyLeaveDays,
      incompleteDays: incompleteDays,
      totalWorkMinutes: totalWorkMinutes,
      overtimeMinutes: overtimeMinutes,
    );
  }
}
