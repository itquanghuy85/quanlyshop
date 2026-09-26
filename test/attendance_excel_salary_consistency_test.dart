import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/models/attendance_model.dart';
import 'package:quanlyshop/services/attendance_computation_service.dart';
import 'package:quanlyshop/services/attendance_summary_service.dart';

/// Item 5 (FINAL CLOSURE audit): proves the same attendance fixture yields
/// the same worked/OT numbers whether read through
/// AttendanceComputationService directly (what SalaryCalculationService now
/// uses), or through AttendanceSummaryService (what the dashboard header
/// and the Excel monthly-summary export now use — see
/// excel_export_helper.dart exportAttendance/exportAttendanceMonthlySummary,
/// which call AttendanceComputationService.compute with the exact same
/// inputs per row). This is the "UI = Salary = Excel" invariant the audit
/// was checking for; before this fix, AttendanceSummaryService/Excel used
/// raw `checkOut - checkIn` and raw `overtimeOn` while
/// SalaryCalculationService used break-subtracted worked time and
/// manual/auto/cap-aware effective OT — the same day could show different
/// hours in different places.
void main() {
  final schedule = ResolvedScheduleConfig.resolve(
    staffSchedule: {
      'startTime': '08:00',
      'endTime': '17:00',
      'breakTime': 1,
      'maxOtHours': 4,
    },
    fallbackOvertimeRatePercent: 150,
  );

  test('single day fixture: engine result matches summary-service aggregate', () {
    final record = Attendance(
      userId: 'staff-1',
      email: 's1@shop.com',
      name: 'NV1',
      dateKey: '2026-09-25',
      checkInAt: DateTime(2026, 9, 25, 8, 0).millisecondsSinceEpoch,
      checkOutAt: DateTime(2026, 9, 25, 18, 30).millisecondsSinceEpoch,
      status: 'approved',
      createdAt: DateTime(2026, 9, 25, 8, 0).millisecondsSinceEpoch,
    );

    // Direct engine call (what SalaryCalculationService/Excel row use).
    final direct = AttendanceComputationService.compute(
      shiftDate: DateTime(2026, 9, 25),
      schedule: schedule,
      standardHoursPerDay: 8,
      checkIn: DateTime.fromMillisecondsSinceEpoch(record.checkInAt!),
      checkOut: DateTime.fromMillisecondsSinceEpoch(record.checkOutAt!),
      manualOvertimeMinutes: record.overtimeOn,
    );

    // Through the summary service (what the dashboard header / Excel
    // summary sheet use).
    final summaries = AttendanceSummaryService.buildMonthlySummaries(
      staffList: const [
        {'id': 'staff-1', 'name': 'NV1', 'email': 's1@shop.com', 'role': 'employee'},
      ],
      staffAttendance: {'staff-1': [record]},
      scheduleByUserId: {'staff-1': schedule},
      standardHoursByUserId: {'staff-1': 8.0},
    );

    expect(summaries.first.totalWorkMinutes, direct.workedMinutes);
    expect(summaries.first.overtimeMinutes, direct.effectiveOvertimeMinutes);
    // Locks in the actual expected numbers from the Phase 22 acceptance
    // example (08:00 -> 18:30 = worked 9.5h, OT 1.5h).
    expect(direct.workedMinutes, (9.5 * 60).round());
    expect(direct.effectiveOvertimeMinutes, 90);
  });

  test('manual OT still wins in both paths (no double count)', () {
    final record = Attendance(
      userId: 'staff-1',
      email: 's1@shop.com',
      name: 'NV1',
      dateKey: '2026-09-25',
      checkInAt: DateTime(2026, 9, 25, 8, 0).millisecondsSinceEpoch,
      checkOutAt: DateTime(2026, 9, 25, 18, 0).millisecondsSinceEpoch, // auto OT would be 60m
      overtimeOn: 120, // manual override
      status: 'approved',
      createdAt: DateTime(2026, 9, 25, 8, 0).millisecondsSinceEpoch,
    );

    final direct = AttendanceComputationService.compute(
      shiftDate: DateTime(2026, 9, 25),
      schedule: schedule,
      standardHoursPerDay: 8,
      checkIn: DateTime.fromMillisecondsSinceEpoch(record.checkInAt!),
      checkOut: DateTime.fromMillisecondsSinceEpoch(record.checkOutAt!),
      manualOvertimeMinutes: record.overtimeOn,
    );

    final summaries = AttendanceSummaryService.buildMonthlySummaries(
      staffList: const [
        {'id': 'staff-1', 'name': 'NV1', 'email': 's1@shop.com', 'role': 'employee'},
      ],
      staffAttendance: {'staff-1': [record]},
      scheduleByUserId: {'staff-1': schedule},
      standardHoursByUserId: {'staff-1': 8.0},
    );

    expect(direct.effectiveOvertimeMinutes, 120);
    expect(summaries.first.overtimeMinutes, 120); // not 60+120=180
  });
}
