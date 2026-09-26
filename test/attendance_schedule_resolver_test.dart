import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/services/attendance_schedule_resolver.dart';

void main() {
  group('AttendanceScheduleResolver.effectiveTimes', () {
    test('uses staff-specific schedule when present', () {
      final times = AttendanceScheduleResolver.effectiveTimes(
        staffSchedule: {'startTime': '09:00', 'endTime': '18:00'},
        shopSchedule: {'startTime': '08:00', 'endTime': '17:00'},
      );
      expect(times['startTime'], '09:00');
      expect(times['endTime'], '18:00');
    });

    test('falls back to shop_general when staff schedule missing (F-03)', () {
      final times = AttendanceScheduleResolver.effectiveTimes(
        staffSchedule: null,
        shopSchedule: {'startTime': '08:30', 'endTime': '17:30'},
      );
      expect(times['startTime'], '08:30');
      expect(times['endTime'], '17:30');
    });

    test('falls back to shop_general when staff schedule has no startTime', () {
      final times = AttendanceScheduleResolver.effectiveTimes(
        staffSchedule: {'someOtherField': 1},
        shopSchedule: {'startTime': '08:30', 'endTime': '17:30'},
      );
      expect(times['startTime'], '08:30');
      expect(times['endTime'], '17:30');
    });

    test('falls back to hardcoded default when nothing configured', () {
      final times = AttendanceScheduleResolver.effectiveTimes(
        staffSchedule: null,
        shopSchedule: null,
      );
      expect(times['startTime'], AttendanceScheduleResolver.defaultStartTime);
      expect(times['endTime'], AttendanceScheduleResolver.defaultEndTime);
    });
  });
}
