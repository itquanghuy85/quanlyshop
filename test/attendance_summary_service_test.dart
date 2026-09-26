import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/models/attendance_model.dart';
import 'package:quanlyshop/services/attendance_computation_service.dart';
import 'package:quanlyshop/services/attendance_summary_service.dart';

void main() {
  group('AttendanceSummaryService', () {
    test('buildMonthlySummaries aggregates attendance metrics per staff', () {
      final summaries = AttendanceSummaryService.buildMonthlySummaries(
        staffList: const [
          {
            'id': 'staff-1',
            'name': 'Nguyen Van A',
            'email': 'a@example.com',
            'role': 'technician',
          },
        ],
        staffAttendance: {
          'staff-1': [
            Attendance(
              userId: 'staff-1',
              email: 'a@example.com',
              name: 'Nguyen Van A',
              dateKey: '2025-03-01',
              checkInAt: DateTime(2025, 3, 1, 8, 0).millisecondsSinceEpoch,
              checkOutAt: DateTime(2025, 3, 1, 17, 30).millisecondsSinceEpoch,
              overtimeOn: 60,
              status: 'approved',
              isLate: 1,
              createdAt: DateTime(2025, 3, 1, 8, 0).millisecondsSinceEpoch,
            ),
            Attendance(
              userId: 'staff-1',
              email: 'a@example.com',
              name: 'Nguyen Van A',
              dateKey: '2025-03-02',
              checkInAt: DateTime(2025, 3, 2, 8, 15).millisecondsSinceEpoch,
              status: 'completed',
              isEarlyLeave: 1,
              createdAt: DateTime(2025, 3, 2, 8, 15).millisecondsSinceEpoch,
            ),
          ],
        },
      );

      expect(summaries, hasLength(1));
      final summary = summaries.first;
      expect(summary.workDays, 2);
      expect(summary.approvedDays, 1);
      expect(summary.pendingDays, 1);
      expect(summary.rejectedDays, 0);
      expect(summary.lateDays, 1);
      expect(summary.earlyLeaveDays, 1);
      expect(summary.incompleteDays, 1);
      // Canonical engine fix: worked minutes now subtract the default 60m
      // break (elapsed 570m - break 60m = 510m), matching what
      // SalaryCalculationService actually pays instead of raw elapsed time.
      expect(summary.totalWorkMinutes, 510);
      // Manual overtimeOn=60 wins over the ~30m automatic OT this shift
      // would otherwise generate past the default 17:00 schedule end.
      expect(summary.overtimeMinutes, 60);
    });

    test('worked/OT minutes use the injected schedule when provided', () {
      final noBreakSchedule = ResolvedScheduleConfig.resolve(
        staffSchedule: {'startTime': '08:00', 'endTime': '17:00', 'breakTime': 0},
        fallbackOvertimeRatePercent: 150,
      );
      final summaries = AttendanceSummaryService.buildMonthlySummaries(
        staffList: const [
          {'id': 'staff-2', 'name': 'B', 'email': 'b@example.com', 'role': 'employee'},
        ],
        staffAttendance: {
          'staff-2': [
            Attendance(
              userId: 'staff-2',
              email: 'b@example.com',
              name: 'B',
              dateKey: '2025-03-01',
              checkInAt: DateTime(2025, 3, 1, 8, 0).millisecondsSinceEpoch,
              checkOutAt: DateTime(2025, 3, 1, 17, 0).millisecondsSinceEpoch,
              status: 'approved',
              createdAt: DateTime(2025, 3, 1, 8, 0).millisecondsSinceEpoch,
            ),
          ],
        },
        scheduleByUserId: {'staff-2': noBreakSchedule},
        standardHoursByUserId: {'staff-2': 8.0},
      );

      expect(summaries.first.totalWorkMinutes, 9 * 60); // no break configured
      expect(summaries.first.overtimeMinutes, 0); // checkout exactly at end time
    });

    test(
      'isPendingLike treats legacy completed records as waiting approval',
      () {
        final record = Attendance(
          userId: 'staff-1',
          email: 'a@example.com',
          name: 'Nguyen Van A',
          dateKey: '2025-03-03',
          checkInAt: DateTime(2025, 3, 3, 8, 0).millisecondsSinceEpoch,
          status: 'completed',
          createdAt: DateTime(2025, 3, 3, 8, 0).millisecondsSinceEpoch,
        );

        expect(AttendanceSummaryService.isPendingLike(record), isTrue);
      },
    );
  });
}
