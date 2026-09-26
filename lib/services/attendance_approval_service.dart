import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_write_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/db_helper.dart';
import '../models/attendance_model.dart';
import '../models/leave_request_model.dart';
import '../services/user_service.dart';
import '../services/encryption_service.dart';
import 'event_bus.dart';
import 'app_session.dart';
import 'cloud_write_policy.dart';
import 'attendance_computation_service.dart';
import 'payroll_lock_service.dart';
import 'notification_service.dart';
import 'package:flutter/material.dart' show Colors;

/// Service for managing attendance approval, leave requests, overtime editing.
/// Only owner/manager roles can approve/reject.
///
/// Architecture note (Phase 1, payroll-lock testability): every write
/// operation here is split into a public `applyXxxLogic` pure function
/// (no Firebase/DB IO — takes already-resolved inputs, mutates the record,
/// returns whether the mutation was applied) and a thin `xxx` wrapper that
/// does the Firebase Auth check, resolves inputs from SQLite, calls the
/// pure function, then persists + syncs. The pure functions are
/// `@visibleForTesting` and unit-testable without any Firebase dependency
/// — see test/attendance_approval_logic_test.dart.
class AttendanceApprovalService {
  static final _db = FirebaseFirestore.instance;
  static final _dbHelper = DBHelper();

  // ========================
  // PAYROLL LOCK
  // ========================

  /// True when [dateKey] (yyyy-MM-dd) falls in a payroll-locked month.
  /// Shop-wide lock (cloud-backed, see PayrollLockService); locked from
  /// "Bảng lương nhân viên".
  @visibleForTesting
  static Future<bool> isLockedForDateKey(String dateKey) =>
      PayrollLockService.isLockedForDateKey(dateKey);

  static void _notifyLocked(String dateKey) {
    final m = PayrollLockService.monthKeyFromDateKey(dateKey);
    final label = m.length == 7 ? '${m.substring(5)}/${m.substring(0, 4)}' : m;
    debugPrint('Attendance write blocked: payroll month $m is locked');
    NotificationService.showSnackBar(
      'Tháng $label đã khoá lương — không thể sửa chấm công. Chủ shop mở khoá ở Bảng lương.',
      color: Colors.red,
    );
  }

  // ========================
  // ATTENDANCE APPROVAL
  // ========================

  /// Pure logic: applies an approval to [record] unless [isLocked]. Returns
  /// true iff the mutation was applied. No Firebase/DB IO.
  @visibleForTesting
  static bool applyApproveAttendanceLogic({
    required Attendance record,
    required String approverUid,
    required bool isLocked,
  }) {
    if (isLocked) return false;
    record.status = 'approved';
    record.approvedBy = approverUid;
    record.approvedAt = DateTime.now().millisecondsSinceEpoch;
    record.updatedAt = DateTime.now().millisecondsSinceEpoch;
    record.isSynced = false;
    return true;
  }

  /// Approve an attendance record (confirm it counts toward salary)
  static Future<bool> approveAttendance(Attendance record) async {
    if (!AppSession.syncEnabled) return false; // offline session: no cloud
    try {
      final uid = _getCurrentUid();
      if (uid == null) return false;
      final locked = await isLockedForDateKey(record.dateKey);
      final applied = applyApproveAttendanceLogic(
        record: record,
        approverUid: uid,
        isLocked: locked,
      );
      if (!applied) {
        if (locked) _notifyLocked(record.dateKey);
        return false;
      }

      await _dbHelper.upsertAttendance(record);
      await _syncAttendanceToCloud(record);
      EventBus().emit('attendance_changed');
      return true;
    } catch (e) {
      debugPrint('Error approving attendance: $e');
      return false;
    }
  }

  /// Pure logic: applies a rejection to [record] unless [isLocked].
  @visibleForTesting
  static bool applyRejectAttendanceLogic({
    required Attendance record,
    required String reason,
    required String approverUid,
    required bool isLocked,
  }) {
    if (isLocked) return false;
    record.status = 'rejected';
    record.approvedBy = approverUid;
    record.approvedAt = DateTime.now().millisecondsSinceEpoch;
    record.rejectReason = reason;
    record.updatedAt = DateTime.now().millisecondsSinceEpoch;
    record.isSynced = false;
    return true;
  }

  /// Reject an attendance record
  static Future<bool> rejectAttendance(Attendance record, String reason) async {
    if (!AppSession.syncEnabled) return false; // offline session: no cloud
    try {
      final uid = _getCurrentUid();
      if (uid == null) return false;
      final locked = await isLockedForDateKey(record.dateKey);
      final applied = applyRejectAttendanceLogic(
        record: record,
        reason: reason,
        approverUid: uid,
        isLocked: locked,
      );
      if (!applied) {
        if (locked) _notifyLocked(record.dateKey);
        return false;
      }

      await _dbHelper.upsertAttendance(record);
      await _syncAttendanceToCloud(record);
      EventBus().emit('attendance_changed');
      return true;
    } catch (e) {
      debugPrint('Error rejecting attendance: $e');
      return false;
    }
  }

  /// Bulk approve all pending attendance for a date
  static Future<int> bulkApproveByDate(String dateKey, List<Attendance> records) async {
    if (!AppSession.syncEnabled) return 0; // offline session: no cloud
    int count = 0;
    for (final record in records) {
      if (record.status == 'pending' && record.checkInAt != null) {
        final ok = await approveAttendance(record);
        if (ok) count++;
      }
    }
    return count;
  }

  // ========================
  // FORGOT CHECK-IN/OUT
  // ========================

  /// Pure logic for the "forgot check-in" flow: computes isLate/isEarlyLeave
  /// via the canonical engine and returns the record to persist (mutated
  /// [existing], or a freshly-built one when there is none), or null when
  /// blocked by [isLocked]. No Firebase/DB IO.
  @visibleForTesting
  static Attendance? applyForgotCheckinLogic({
    required Attendance? existing,
    required String userId,
    required String email,
    required String name,
    required String dateKey,
    required String firestoreId,
    required int checkInAt,
    int? checkOutAt,
    String? note,
    required ResolvedScheduleConfig schedule,
    required bool isLocked,
  }) {
    if (isLocked) return null;

    final shiftDate = DateTime.parse(dateKey);
    final isLate = AttendanceComputationService.isLateCheckIn(
      DateTime.fromMillisecondsSinceEpoch(checkInAt),
      shiftDate,
      schedule,
    ) ? 1 : 0;
    final isEarly = checkOutAt != null
        ? (AttendanceComputationService.isEarlyCheckOut(
            DateTime.fromMillisecondsSinceEpoch(checkOutAt),
            shiftDate,
            schedule,
          ) ? 1 : 0)
        : 0;

    if (existing != null) {
      existing.checkInAt = checkInAt;
      existing.isLate = isLate;
      if (checkOutAt != null) {
        existing.checkOutAt = checkOutAt;
        existing.isEarlyLeave = isEarly;
      }
      existing.requestType = 'forgot_checkin';
      existing.status = 'pending';
      existing.note = note ?? 'Quên chấm công';
      existing.updatedAt = DateTime.now().millisecondsSinceEpoch;
      existing.isSynced = false;
      return existing;
    }

    final record = Attendance(
      userId: userId,
      email: email,
      name: name,
      dateKey: dateKey,
      checkInAt: checkInAt,
      checkOutAt: checkOutAt,
      status: 'pending',
      requestType: 'forgot_checkin',
      note: note ?? 'Quên chấm công',
      isLate: isLate,
      isEarlyLeave: isEarly,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      isSynced: false,
    );
    record.firestoreId = firestoreId;
    return record;
  }

  /// Create a "forgot check-in" request (employee submits, manager approves)
  static Future<bool> createForgotCheckinRequest({
    required String userId,
    required String email,
    required String name,
    required String dateKey,
    required int checkInAt,
    int? checkOutAt,
    String? note,
  }) async {
    if (!AppSession.syncEnabled) return false; // offline session: no cloud
    try {
      final locked = await isLockedForDateKey(dateKey);
      if (locked) {
        _notifyLocked(dateKey);
        return false;
      }
      final shopId = await UserService.getCurrentShopId();
      final inputs = await resolveComputationInputs(userId, dateKey: dateKey);
      final existing = await _dbHelper.getAttendance(dateKey, userId);
      final firestoreId = "att_${dateKey}_$userId";

      final result = applyForgotCheckinLogic(
        existing: existing,
        userId: userId,
        email: email,
        name: name,
        dateKey: dateKey,
        firestoreId: firestoreId,
        checkInAt: checkInAt,
        checkOutAt: checkOutAt,
        note: note,
        schedule: inputs.schedule,
        isLocked: locked,
      );
      if (result == null) return false;

      if (existing != null) {
        await _dbHelper.upsertAttendance(result);
      } else {
        final map = result.toMap();
        map['shopId'] = shopId;
        await _dbHelper.upsertAttendance(Attendance.fromMap(map));
      }
      await _syncAttendanceToCloud(result);
      EventBus().emit('attendance_changed');
      return true;
    } catch (e) {
      debugPrint('Error creating forgot checkin request: $e');
      return false;
    }
  }

  /// Pure logic for the "forgot checkout" flow (Phase 7). Requires an
  /// existing checked-in record — never fabricates a check-in. Returns null
  /// when blocked by [isLocked] or when there is no valid existing check-in
  /// to correct.
  @visibleForTesting
  static Attendance? applyForgotCheckoutLogic({
    required Attendance? existing,
    required String dateKey,
    required int checkOutAt,
    String? note,
    required ResolvedScheduleConfig schedule,
    required bool isLocked,
  }) {
    if (isLocked) return null;
    if (existing == null || existing.checkInAt == null) return null;

    final isEarly = AttendanceComputationService.isEarlyCheckOut(
      DateTime.fromMillisecondsSinceEpoch(checkOutAt),
      DateTime.parse(dateKey),
      schedule,
    );

    existing.checkOutAt = checkOutAt;
    existing.isEarlyLeave = isEarly ? 1 : 0;
    existing.requestType = 'forgot_checkout';
    existing.status = 'pending';
    existing.note = note ?? 'Quên chấm công ra';
    existing.updatedAt = DateTime.now().millisecondsSinceEpoch;
    existing.isSynced = false;
    return existing;
  }

  /// Create a "forgot checkout" request (Phase 7): symmetric to
  /// createForgotCheckinRequest, for the (previously unhandled) case of a
  /// record that has checkInAt but no checkOutAt. The record goes back to
  /// 'pending' so it flows through the same manager approve/reject path as
  /// every other attendance record, and only counts toward salary once
  /// approved (see SalaryCalculationService — unchanged policy, just now
  /// reachable for a corrected missing-checkout record instead of staying
  /// incomplete forever).
  static Future<bool> createForgotCheckoutRequest({
    required String userId,
    required String dateKey,
    required int checkOutAt,
    String? note,
  }) async {
    if (!AppSession.syncEnabled) return false; // offline session: no cloud
    try {
      final locked = await isLockedForDateKey(dateKey);
      if (locked) {
        _notifyLocked(dateKey);
        return false;
      }
      final existing = await _dbHelper.getAttendance(dateKey, userId);
      final inputs = await resolveComputationInputs(userId, dateKey: dateKey);

      final result = applyForgotCheckoutLogic(
        existing: existing,
        dateKey: dateKey,
        checkOutAt: checkOutAt,
        note: note,
        schedule: inputs.schedule,
        isLocked: locked,
      );
      if (result == null) {
        if (existing == null || existing.checkInAt == null) {
          debugPrint(
            'Cannot create forgot-checkout request: no check-in found for $userId/$dateKey',
          );
        }
        return false;
      }

      await _dbHelper.upsertAttendance(result);
      await _syncAttendanceToCloud(result);
      EventBus().emit('attendance_changed');
      return true;
    } catch (e) {
      debugPrint('Error creating forgot checkout request: $e');
      return false;
    }
  }

  // ========================
  // OVERTIME EDITING
  // ========================

  /// Pure logic: applies a manual OT edit to [record], capped at
  /// [maxOvertimeMinutes] (F-06), unless [isLocked] (Phase 8). No
  /// Firebase/DB IO.
  @visibleForTesting
  static bool applyEditOvertimeLogic({
    required Attendance record,
    required int overtimeMinutes,
    int? overtimeStartAt,
    int? overtimeEndAt,
    String? note,
    required int maxOvertimeMinutes,
    required bool isLocked,
  }) {
    if (isLocked) return false;

    record.overtimeOn = overtimeMinutes.clamp(0, maxOvertimeMinutes);
    record.overtimeStartAt = overtimeStartAt;
    record.overtimeEndAt = overtimeEndAt;
    if (note != null) record.note = note;
    // F-13 fix: AttendanceManagementView reads requestType=='overtime_edit'
    // to show the "Sửa tăng ca" badge in the approval queue, but this was
    // the only writer of OT edits and never set it — the badge was dead
    // code. Don't clobber a forgot_checkin/forgot_checkout label, which
    // the UI already prioritizes over the OT badge (see _buildApprovalCard
    // isForget check).
    if (record.requestType != 'forgot_checkin' &&
        record.requestType != 'forgot_checkout') {
      record.requestType = 'overtime_edit';
    }
    record.updatedAt = DateTime.now().millisecondsSinceEpoch;
    record.isSynced = false;
    return true;
  }

  /// Edit overtime for an attendance record (set specific overtime window)
  static Future<bool> editOvertime({
    required Attendance record,
    required int overtimeMinutes,
    int? overtimeStartAt,
    int? overtimeEndAt,
    String? note,
  }) async {
    if (!AppSession.syncEnabled) return false; // offline session: no cloud
    try {
      final uid = _getCurrentUid();
      if (uid == null) return false;
      final locked = await isLockedForDateKey(record.dateKey);
      final inputs = await resolveComputationInputs(record.userId, dateKey: record.dateKey);

      final applied = applyEditOvertimeLogic(
        record: record,
        overtimeMinutes: overtimeMinutes,
        overtimeStartAt: overtimeStartAt,
        overtimeEndAt: overtimeEndAt,
        note: note,
        maxOvertimeMinutes: inputs.schedule.maxOvertimeMinutes,
        isLocked: locked,
      );
      if (!applied) {
        if (locked) _notifyLocked(record.dateKey);
        return false;
      }

      await _dbHelper.upsertAttendance(record);
      await _syncAttendanceToCloud(record);
      EventBus().emit('attendance_changed');
      return true;
    } catch (e) {
      debugPrint('Error editing overtime: $e');
      return false;
    }
  }

  /// Pure logic: applies a check-in/check-out time correction to [record],
  /// recomputing isLate/isEarlyLeave via the canonical engine, unless
  /// [isLocked]. Manual OT fields are never touched here (Phase 5 — a time
  /// correction must not silently erase a manager-confirmed OT window). No
  /// Firebase/DB IO.
  @visibleForTesting
  static bool applyEditAttendanceTimesLogic({
    required Attendance record,
    int? checkInAt,
    int? checkOutAt,
    String? note,
    required ResolvedScheduleConfig schedule,
    required bool isLocked,
  }) {
    if (isLocked) return false;

    if (checkInAt != null) record.checkInAt = checkInAt;
    if (checkOutAt != null) record.checkOutAt = checkOutAt;
    if (note != null) record.note = note;

    if (checkInAt != null || checkOutAt != null) {
      final shiftDate = DateTime.parse(record.dateKey);
      if (checkInAt != null) {
        record.isLate = AttendanceComputationService.isLateCheckIn(
          DateTime.fromMillisecondsSinceEpoch(checkInAt),
          shiftDate,
          schedule,
        ) ? 1 : 0;
      }
      final effectiveCheckOut = checkOutAt ?? record.checkOutAt;
      if (effectiveCheckOut != null) {
        record.isEarlyLeave = AttendanceComputationService.isEarlyCheckOut(
          DateTime.fromMillisecondsSinceEpoch(effectiveCheckOut),
          shiftDate,
          schedule,
        ) ? 1 : 0;
      }
    }

    record.updatedAt = DateTime.now().millisecondsSinceEpoch;
    record.isSynced = false;
    return true;
  }

  /// Edit check-in/check-out times for an attendance record
  static Future<bool> editAttendanceTimes({
    required Attendance record,
    int? checkInAt,
    int? checkOutAt,
    String? note,
  }) async {
    if (!AppSession.syncEnabled) return false; // offline session: no cloud
    try {
      final uid = _getCurrentUid();
      if (uid == null) return false;
      final locked = await isLockedForDateKey(record.dateKey);
      final inputs = await resolveComputationInputs(record.userId, dateKey: record.dateKey);

      final applied = applyEditAttendanceTimesLogic(
        record: record,
        checkInAt: checkInAt,
        checkOutAt: checkOutAt,
        note: note,
        schedule: inputs.schedule,
        isLocked: locked,
      );
      if (!applied) {
        if (locked) _notifyLocked(record.dateKey);
        return false;
      }

      await _dbHelper.upsertAttendance(record);
      await _syncAttendanceToCloud(record);
      EventBus().emit('attendance_changed');
      return true;
    } catch (e) {
      debugPrint('Error editing attendance times: $e');
      return false;
    }
  }

  /// Resolves the canonical computation inputs (schedule config +
  /// standardHoursPerDay) for one staff member — same staff -> shop_general
  /// -> default chain, shared by every write path in this service so they
  /// can never compute isLate/isEarlyLeave/OT differently from each other
  /// or from AttendanceView/SalaryCalculationService.
  ///
  /// [dateKey] (2026-09-26 shift-swap redesign), when given, applies the
  /// highest-priority override: an APPROVED shift swap affecting this user
  /// on this specific date replaces just startTime/endTime (break/maxOT/
  /// rates/workDays/holidays still come from the normal chain — a swap
  /// only changes the time window, not OT policy). Callers that compute
  /// for a specific attendance record should always pass its dateKey;
  /// callers with no specific date (none currently) may omit it.
  static Future<
      ({ResolvedScheduleConfig schedule, double standardHoursPerDay})>
      resolveComputationInputs(String userId, {String? dateKey}) async {
    final staffSchedule = await _dbHelper.getWorkSchedule(userId);
    final shopSchedule = await _dbHelper.getWorkSchedule('shop_general');
    final salarySettings =
        await _dbHelper.getEmployeeSalarySettingByStaffId(userId);
    final overtimeRatePercent =
        (salarySettings?['overtimeRate'] as num?)?.toDouble() ?? 150.0;
    final standardHoursPerDay =
        (salarySettings?['standardHoursPerDay'] as num?)?.toDouble() ?? 8.0;
    var schedule = ResolvedScheduleConfig.resolve(
      staffSchedule: staffSchedule,
      shopSchedule: shopSchedule,
      fallbackOvertimeRatePercent: overtimeRatePercent,
    );

    if (dateKey != null) {
      final override = await getApprovedShiftSwapOverride(userId, dateKey);
      if (override != null) {
        schedule = schedule.copyWith(
          startTime: override.$1,
          endTime: override.$2,
        );
      }
    }

    return (schedule: schedule, standardHoursPerDay: standardHoursPerDay);
  }

  /// Looks up an APPROVED shift swap affecting [userId] on [dateKey] and
  /// returns its (startTime, endTime) override, or null. Public
  /// (`@visibleForTesting`-worthy but kept plain public since other
  /// services — SalaryCalculationService, AttendanceSummaryService,
  /// excel_export_helper, AttendanceView — need the exact same lookup for
  /// dates outside this service's own write paths) so there is exactly one
  /// place that decides "does this record's schedule differ from normal
  /// today". Multiple approved swaps on the same date (edge case, should
  /// not normally happen) take the first match — not disambiguated further
  /// since the UI does not currently allow creating overlapping approved
  /// swaps for the same user/date.
  static Future<(String, String)?> getApprovedShiftSwapOverride(
    String userId,
    String dateKey,
  ) async {
    final rows = await _dbHelper.getApprovedShiftSwapRequestsForUserAndDate(
      userId,
      dateKey,
    );
    for (final r in rows) {
      if (r.requesterId == userId && r.hasStructuredSchedule) {
        return (r.newStartTime!, r.newEndTime!);
      }
      if (r.targetUserId == userId && r.hasStructuredTargetSchedule) {
        return (r.targetNewStartTime!, r.targetNewEndTime!);
      }
    }
    return null;
  }

  // ========================
  // LEAVE REQUESTS
  // ========================

  /// Create a leave request
  static Future<bool> createLeaveRequest(LeaveRequest request) async {
    if (!AppSession.syncEnabled) return false; // offline session: no cloud
    try {
      final shopId = await UserService.getCurrentShopId();
      request.shopId = shopId;
      request.firestoreId ??= "lr_${request.userId}_${request.startDate}_${request.createdAt}";
      await _dbHelper.upsertLeaveRequest(request);
      await _syncLeaveRequestToCloud(request);
      EventBus().emit('leave_requests_changed');
      return true;
    } catch (e) {
      debugPrint('Error creating leave request: $e');
      return false;
    }
  }

  /// Approve a leave request
  static Future<bool> approveLeaveRequest(LeaveRequest request) async {
    if (!AppSession.syncEnabled) return false; // offline session: no cloud
    try {
      final uid = _getCurrentUid();
      if (uid == null) return false;

      request.status = 'approved';
      request.approvedBy = uid;
      request.approvedAt = DateTime.now().millisecondsSinceEpoch;
      request.updatedAt = DateTime.now().millisecondsSinceEpoch;
      request.isSynced = false;

      await _dbHelper.upsertLeaveRequest(request);
      await _syncLeaveRequestToCloud(request);
      EventBus().emit('leave_requests_changed');
      return true;
    } catch (e) {
      debugPrint('Error approving leave request: $e');
      return false;
    }
  }

  /// Reject a leave request
  static Future<bool> rejectLeaveRequest(LeaveRequest request, String reason) async {
    if (!AppSession.syncEnabled) return false; // offline session: no cloud
    try {
      final uid = _getCurrentUid();
      if (uid == null) return false;

      request.status = 'rejected';
      request.approvedBy = uid;
      request.approvedAt = DateTime.now().millisecondsSinceEpoch;
      request.rejectReason = reason;
      request.updatedAt = DateTime.now().millisecondsSinceEpoch;
      request.isSynced = false;

      await _dbHelper.upsertLeaveRequest(request);
      await _syncLeaveRequestToCloud(request);
      EventBus().emit('leave_requests_changed');
      return true;
    } catch (e) {
      debugPrint('Error rejecting leave request: $e');
      return false;
    }
  }

  /// Get pending leave requests for current shop
  static Future<List<LeaveRequest>> getPendingLeaveRequests() async {
    if (!AppSession.syncEnabled) return []; // offline session: no cloud
    return _dbHelper.getLeaveRequestsByStatus('pending');
  }

  /// Get leave requests by date range
  static Future<List<LeaveRequest>> getLeaveRequestsByDateRange(String start, String end) async {
    if (!AppSession.syncEnabled) return []; // offline session: no cloud
    return _dbHelper.getLeaveRequestsByDateRange(start, end);
  }

  /// Get all leave requests for a user
  static Future<List<LeaveRequest>> getLeaveRequestsByUser(String userId) async {
    if (!AppSession.syncEnabled) return []; // offline session: no cloud
    return _dbHelper.getLeaveRequestsByUser(userId);
  }

  // ========================
  // HELPERS
  // ========================

  static String? _getCurrentUid() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  static Future<void> _syncAttendanceToCloud(Attendance record) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final docId = record.firestoreId ?? "att_${record.dateKey}_${record.userId}";
      Map<String, dynamic> data = record.toMap();
      data['shopId'] = shopId;
      data['firestoreId'] = docId;
      data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
      final encryptedData = EncryptionService.encryptMap(data);
      await CloudWritePolicy.guard(() => _db.collection('attendance').doc(docId).set(
        encryptedData,
        SetOptions(merge: true),
      ), context: 'attendance');
    } catch (e) {
      debugPrint('Error syncing attendance to cloud: $e');
    }
  }

  static Future<void> _syncLeaveRequestToCloud(LeaveRequest request) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final docId = request.firestoreId ?? "lr_${request.userId}_${request.startDate}_${request.createdAt}";
      Map<String, dynamic> data = request.toMap();
      data['shopId'] = shopId;
      data['firestoreId'] = docId;
      data['updatedAt'] = FirestoreWriteHelper.serverUpdatedAt();
      final encryptedData = EncryptionService.encryptMap(data);
      await CloudWritePolicy.guard(() => _db.collection('leave_requests').doc(docId).set(
        encryptedData,
        SetOptions(merge: true),
      ), context: 'leave_requests');
    } catch (e) {
      debugPrint('Error syncing leave request to cloud: $e');
    }
  }
}
