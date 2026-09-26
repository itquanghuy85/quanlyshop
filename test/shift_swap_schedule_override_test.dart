import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quanlyshop/data/db_helper.dart';
import 'package:quanlyshop/models/shift_swap_request_model.dart';
import 'package:quanlyshop/services/app_session.dart';
import 'package:quanlyshop/services/attendance_approval_service.dart';

/// End-to-end test of the 2026-09-26 "shift swap has a real schedule
/// effect" redesign: an APPROVED swap must override
/// AttendanceApprovalService.resolveComputationInputs's startTime/endTime
/// for exactly the (user, date) it applies to — for both sides of a 2-way
/// swap — and must NOT affect any other date or any other user. This is
/// the single function every caller (AttendanceView, SalaryCalculationService,
/// AttendanceSummaryService, excel_export_helper) relies on.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    await AppSession.startOffline(shopName: 'Shift swap override test');
  });

  Future<void> seedApprovedSwap({
    required String firestoreId,
    required String requesterId,
    required String targetUserId,
    required String dateKey,
    required String requesterNewStart,
    required String requesterNewEnd,
    required String targetNewStart,
    required String targetNewEnd,
  }) async {
    final r = ShiftSwapRequest(
      firestoreId: firestoreId,
      shopId: '',
      requesterId: requesterId,
      requesterName: 'A',
      requesterEmail: 'a@shop.com',
      requestedDate: dateKey,
      currentShift: 'Ca sáng (08:00-12:00)',
      desiredShift: 'Ca chiều (13:00-17:00)',
      newStartTime: requesterNewStart,
      newEndTime: requesterNewEnd,
      targetUserId: targetUserId,
      targetUserName: 'B',
      targetNewStartTime: targetNewStart,
      targetNewEndTime: targetNewEnd,
      note: null,
      status: 'approved',
      reviewedBy: 'mgr',
      reviewedByName: 'Manager',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      reviewedAt: DateTime.now().millisecondsSinceEpoch,
      rejectReason: null,
      deleted: false,
    );
    await DBHelper().upsertShiftSwapRequest(r);
  }

  group('getApprovedShiftSwapOverride', () {
    test('requester side gets their newStartTime/newEndTime', () async {
      await seedApprovedSwap(
        firestoreId: 'ssw_a1',
        requesterId: 'ov_a',
        targetUserId: 'ov_b',
        dateKey: '2026-11-01',
        requesterNewStart: '13:00',
        requesterNewEnd: '22:00',
        targetNewStart: '08:00',
        targetNewEnd: '17:00',
      );

      final result = await AttendanceApprovalService.getApprovedShiftSwapOverride(
        'ov_a',
        '2026-11-01',
      );
      expect(result, ('13:00', '22:00'));
    });

    test('target side gets targetNewStartTime/targetNewEndTime (the other half of the swap)', () async {
      await seedApprovedSwap(
        firestoreId: 'ssw_a2',
        requesterId: 'ov_c',
        targetUserId: 'ov_d',
        dateKey: '2026-11-02',
        requesterNewStart: '13:00',
        requesterNewEnd: '22:00',
        targetNewStart: '08:00',
        targetNewEnd: '17:00',
      );

      final result = await AttendanceApprovalService.getApprovedShiftSwapOverride(
        'ov_d',
        '2026-11-02',
      );
      expect(result, ('08:00', '17:00'));
    });

    test('a different date for the same user has no override', () async {
      await seedApprovedSwap(
        firestoreId: 'ssw_a3',
        requesterId: 'ov_e',
        targetUserId: 'ov_f',
        dateKey: '2026-11-03',
        requesterNewStart: '13:00',
        requesterNewEnd: '22:00',
        targetNewStart: '08:00',
        targetNewEnd: '17:00',
      );

      final result = await AttendanceApprovalService.getApprovedShiftSwapOverride(
        'ov_e',
        '2026-11-04',
      );
      expect(result, isNull);
    });

    test('a bystander user on the same date has no override', () async {
      await seedApprovedSwap(
        firestoreId: 'ssw_a4',
        requesterId: 'ov_g',
        targetUserId: 'ov_h',
        dateKey: '2026-11-05',
        requesterNewStart: '13:00',
        requesterNewEnd: '22:00',
        targetNewStart: '08:00',
        targetNewEnd: '17:00',
      );

      final result = await AttendanceApprovalService.getApprovedShiftSwapOverride(
        'ov_bystander',
        '2026-11-05',
      );
      expect(result, isNull);
    });
  });

  group('resolveComputationInputs applies the override end-to-end', () {
    test('startTime/endTime reflect the approved swap when dateKey is passed', () async {
      await seedApprovedSwap(
        firestoreId: 'ssw_b1',
        requesterId: 'ov_i',
        targetUserId: 'ov_j',
        dateKey: '2026-11-10',
        requesterNewStart: '14:00',
        requesterNewEnd: '23:00',
        targetNewStart: '06:00',
        targetNewEnd: '15:00',
      );

      final inputs = await AttendanceApprovalService.resolveComputationInputs(
        'ov_i',
        dateKey: '2026-11-10',
      );
      expect(inputs.schedule.startTime, '14:00');
      expect(inputs.schedule.endTime, '23:00');
    });

    test('without dateKey, no override is applied even if one exists for today', () async {
      await seedApprovedSwap(
        firestoreId: 'ssw_b2',
        requesterId: 'ov_k',
        targetUserId: 'ov_l',
        dateKey: '2026-11-11',
        requesterNewStart: '14:00',
        requesterNewEnd: '23:00',
        targetNewStart: '06:00',
        targetNewEnd: '15:00',
      );

      final inputs = await AttendanceApprovalService.resolveComputationInputs('ov_k');
      // No dateKey passed -> falls back to normal staff/shop/default chain,
      // never touches the swap table.
      expect(inputs.schedule.startTime, isNot('14:00'));
    });

    test('a normal (unaffected) date for the same user is untouched', () async {
      await seedApprovedSwap(
        firestoreId: 'ssw_b3',
        requesterId: 'ov_m',
        targetUserId: 'ov_n',
        dateKey: '2026-11-15',
        requesterNewStart: '14:00',
        requesterNewEnd: '23:00',
        targetNewStart: '06:00',
        targetNewEnd: '15:00',
      );

      final inputs = await AttendanceApprovalService.resolveComputationInputs(
        'ov_m',
        dateKey: '2026-11-16', // different day
      );
      expect(inputs.schedule.startTime, isNot('14:00'));
    });
  });
}
