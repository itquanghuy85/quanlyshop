import '../models/attendance_model.dart';

/// Field-level check-in/check-out mutation, kept deliberately separate from
/// any Firebase/DB/widget concern so it is unit-testable in isolation.
///
/// Root cause fix (CLAUDE.md audit 2026-09-25, ROOT A / F-01 CRITICAL,
/// F-02 CRITICAL): the previous `_actionCheck` in AttendanceView always
/// built a brand-new `Attendance(...)` object on checkout, which reset
/// every field to its constructor default — silently wiping `isLate`,
/// `overtimeOn`, `overtimeStartAt/EndAt`, `approvedBy`, `approvedAt`,
/// `status` (back to 'pending'), `note`, `requestType` and `locked` any
/// time an employee checked out after a manager had already approved,
/// scheduled OT, or annotated the record. This class instead mutates the
/// existing record in place (clone-and-patch), touching only the fields
/// the action actually concerns.
class AttendanceCheckService {
  /// Apply a check-in. If [existing] is non-null (e.g. a record for the
  /// day already exists — a forgot-checkin request, or a second check-in),
  /// it is mutated and returned so every other field survives untouched.
  static Attendance applyCheckIn({
    required Attendance? existing,
    required String userId,
    required String email,
    required String name,
    required String dateKey,
    required String firestoreId,
    required int timestamp,
    required bool isLate,
    String? photoPath,
    String? location,
  }) {
    if (existing != null) {
      existing.checkInAt = timestamp;
      if (photoPath != null) existing.photoIn = photoPath;
      existing.isLate = isLate ? 1 : 0;
      if (location != null) existing.location = location;
      existing.updatedAt = timestamp;
      existing.isSynced = false;
      existing.firestoreId ??= firestoreId;
      return existing;
    }
    return Attendance(
      userId: userId,
      email: email,
      name: name,
      dateKey: dateKey,
      checkInAt: timestamp,
      photoIn: photoPath,
      status: 'pending',
      isLate: isLate ? 1 : 0,
      location: location,
      createdAt: timestamp,
      updatedAt: timestamp,
      firestoreId: firestoreId,
      isSynced: false,
    );
  }

  /// Apply a check-out. Returns null when there is no existing record to
  /// check out of (checkout without a prior check-in is not a valid state
  /// for this action — caller should surface an error instead of
  /// fabricating a record with only a checkOutAt).
  static Attendance? applyCheckOut({
    required Attendance? existing,
    required int timestamp,
    required bool isEarly,
    String? photoPath,
    String? location,
  }) {
    if (existing == null) return null;
    existing.checkOutAt = timestamp;
    if (photoPath != null) existing.photoOut = photoPath;
    existing.isEarlyLeave = isEarly ? 1 : 0;
    if (location != null) existing.location = location;
    existing.updatedAt = timestamp;
    existing.isSynced = false;
    return existing;
  }
}
