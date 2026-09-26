import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/db_helper.dart';
import '../models/shift_swap_request_model.dart';
import 'event_bus.dart';
import 'user_service.dart';
import 'firebase_usage_stats_service.dart';
import 'app_session.dart';
import 'cloud_write_policy.dart';

/// 2026-09-26 redesign: shift swap now has a REAL effect on the effective
/// schedule for the date it applies to (see
/// AttendanceApprovalService.resolveComputationInputs /
/// DBHelper.getApprovedShiftSwapRequestsForUserAndDate), so this service was
/// rewritten SQLite-first (previously pure Firestore-direct with zero local
/// table — a violation of the app's offline-first architecture, CLAUDE.md
/// §13/§14). Write paths: SQLite first, then Firestore sync gated by
/// AppSession.syncEnabled, same pattern as AttendanceApprovalService.
class ShiftSwapService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final _dbHelper = DBHelper();
  static int _myRequestsFetchCount = 0;
  static int _pendingRequestsFetchCount = 0;

  static bool _isRefreshEvent(String event) {
    return event == 'shift_swap_requests_changed' ||
        event == EventBus.dataRefresh ||
        event == EventBus.shopChanged ||
        event == 'sync_now_completed' ||
        event == 'app_resumed';
  }

  static Future<String> createRequest({
    required String requestedDate,
    required String currentShift,
    required String desiredShift,
    required String newStartTime,
    required String newEndTime,
    String? targetUserId,
    String? targetUserName,
    String? targetNewStartTime,
    String? targetNewEndTime,
    String? note,
  }) async {
    if (!AppSession.syncEnabled) return ''; // offline session: no cloud
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Vui lòng đăng nhập lại để gửi yêu cầu đổi ca.');
    }
    if (targetUserId != null &&
        targetUserId.isNotEmpty &&
        ((targetNewStartTime ?? '').isEmpty || (targetNewEndTime ?? '').isEmpty)) {
      throw Exception('Chọn đổi ca cùng đồng nghiệp thì phải nhập giờ ca mới của họ.');
    }

    final shopId = await UserService.getCurrentShopId();
    if (shopId == null || shopId.isEmpty) {
      throw Exception('Không tìm thấy shopId hiện tại.');
    }

    final requesterName = await UserService.getCurrentUserName();
    final now = DateTime.now().millisecondsSinceEpoch;
    final firestoreId = 'ssw_${user.uid}_${requestedDate}_$now';

    final request = ShiftSwapRequest(
      firestoreId: firestoreId,
      shopId: shopId,
      requesterId: user.uid,
      requesterName: requesterName.isEmpty ? 'Nhân viên' : requesterName,
      requesterEmail: user.email ?? '',
      requestedDate: requestedDate,
      currentShift: currentShift,
      desiredShift: desiredShift,
      newStartTime: newStartTime,
      newEndTime: newEndTime,
      targetUserId: targetUserId,
      targetUserName: targetUserName,
      targetNewStartTime: targetNewStartTime,
      targetNewEndTime: targetNewEndTime,
      note: note,
      status: 'pending',
      reviewedBy: null,
      reviewedByName: null,
      createdAt: now,
      updatedAt: now,
      reviewedAt: null,
      rejectReason: null,
      deleted: false,
      isSynced: false,
    );

    await _dbHelper.upsertShiftSwapRequest(request);
    await _syncToCloud(request);
    EventBus().emit('shift_swap_requests_changed');

    return firestoreId;
  }

  static Stream<List<ShiftSwapRequest>> watchMyRequests({int limit = 100}) {
    return (() async* {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        yield <ShiftSwapRequest>[];
        return;
      }

      Future<List<ShiftSwapRequest>> loadLocal() async {
        final all = await _dbHelper.getShiftSwapRequestsByRequester(user.uid);
        return all.take(limit).toList();
      }

      yield await loadLocal();

      // Pull from Firestore once (online only) to seed/refresh SQLite —
      // display itself always reads local, matching CLAUDE.md §13.
      unawaited(_pullMyRequestsFromCloud(user.uid, limit));

      await for (final event in EventBus().stream.where(_isRefreshEvent)) {
        if (event == 'sync_now_completed' || event == 'app_resumed') {
          unawaited(_pullMyRequestsFromCloud(user.uid, limit));
        }
        yield await loadLocal();
      }
    })();
  }

  static Stream<List<ShiftSwapRequest>> watchPendingRequests({
    int limit = 120,
  }) {
    return (() async* {
      Future<List<ShiftSwapRequest>> loadLocal() async {
        final all = await _dbHelper.getShiftSwapRequestsByStatus('pending');
        return all.take(limit).toList();
      }

      yield await loadLocal();

      unawaited(_pullPendingRequestsFromCloud(limit));

      await for (final event in EventBus().stream.where(_isRefreshEvent)) {
        if (event == 'sync_now_completed' || event == 'app_resumed') {
          unawaited(_pullPendingRequestsFromCloud(limit));
        }
        yield await loadLocal();
      }
    })();
  }

  static Future<void> _pullMyRequestsFromCloud(String uid, int limit) async {
    if (!AppSession.syncEnabled) return; // offline session: no cloud
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null || shopId.isEmpty) return;
      final effectiveLimit = limit.clamp(1, 20);
      _myRequestsFetchCount += 1;
      debugPrint(
        '[SYNC][FETCH] collection=shift_swap_requests_my count=$_myRequestsFetchCount limit=$effectiveLimit',
      );
      final snap = await _db
          .collection('shift_swap_requests')
          .where('shopId', isEqualTo: shopId)
          .where('requesterId', isEqualTo: uid)
          .where('deleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(effectiveLimit)
          .get();
      unawaited(
        FirebaseUsageStatsService.logFetchRead(
          collection: 'shift_swap_requests',
          shopId: shopId,
          docs: snap.docs.length,
          source: 'sync-poll',
        ),
      );
      for (final doc in snap.docs) {
        final map = doc.data();
        map['firestoreId'] = doc.id;
        map['isSynced'] = 1;
        await _dbHelper.upsertShiftSwapRequest(ShiftSwapRequest.fromMap(map));
      }
      EventBus().emit('shift_swap_requests_changed');
    } catch (e) {
      debugPrint('ShiftSwapService pull my requests error: $e');
    }
  }

  static Future<void> _pullPendingRequestsFromCloud(int limit) async {
    if (!AppSession.syncEnabled) return; // offline session: no cloud
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null || shopId.isEmpty) return;
      final effectiveLimit = limit.clamp(1, 20);
      _pendingRequestsFetchCount += 1;
      debugPrint(
        '[SYNC][FETCH] collection=shift_swap_requests_pending count=$_pendingRequestsFetchCount limit=$effectiveLimit',
      );
      final snap = await _db
          .collection('shift_swap_requests')
          .where('shopId', isEqualTo: shopId)
          .where('status', isEqualTo: 'pending')
          .where('deleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(effectiveLimit)
          .get();
      unawaited(
        FirebaseUsageStatsService.logFetchRead(
          collection: 'shift_swap_requests',
          shopId: shopId,
          docs: snap.docs.length,
          source: 'sync-poll',
        ),
      );
      for (final doc in snap.docs) {
        final map = doc.data();
        map['firestoreId'] = doc.id;
        map['isSynced'] = 1;
        await _dbHelper.upsertShiftSwapRequest(ShiftSwapRequest.fromMap(map));
      }
      EventBus().emit('shift_swap_requests_changed');
    } catch (e) {
      debugPrint('ShiftSwapService pull pending requests error: $e');
    }
  }

  static Future<void> approveRequest(ShiftSwapRequest request) async {
    await _updateStatus(request: request, status: 'approved');
  }

  static Future<void> rejectRequest(
    ShiftSwapRequest request, {
    required String reason,
  }) async {
    await _updateStatus(
      request: request,
      status: 'rejected',
      rejectReason: reason.trim().isEmpty ? 'Không nêu lý do' : reason.trim(),
    );
  }

  static Future<void> cancelRequest(ShiftSwapRequest request) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != request.requesterId) {
      throw Exception('Bạn không có quyền huỷ yêu cầu này.');
    }
    if (request.status != 'pending') {
      throw Exception('Yêu cầu đã xử lý, không thể huỷ.');
    }

    final updated = request.copyWith(
      status: 'cancelled',
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      isSynced: false,
    );
    await _dbHelper.upsertShiftSwapRequest(updated);
    await _syncToCloud(updated);
    EventBus().emit('shift_swap_requests_changed');
  }

  static Future<List<Map<String, String>>> getShopStaffOptions() async {
    if (!AppSession.syncEnabled) return []; // offline session: no cloud
    final shopId = await UserService.getCurrentShopId();
    if (shopId == null || shopId.isEmpty) return const [];

    final snap = await _db
        .collection('users')
        .where('shopId', isEqualTo: shopId)
        .get();

    final out = <Map<String, String>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final name = (data['name']?.toString().trim() ?? '');
      final email = (data['email']?.toString().trim() ?? '');
      out.add({
        'uid': doc.id,
        'name': name.isEmpty ? (email.isEmpty ? 'Nhân viên' : email) : name,
        'email': email,
      });
    }

    out.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    return out;
  }

  static Future<void> _updateStatus({
    required ShiftSwapRequest request,
    required String status,
    String? rejectReason,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Vui lòng đăng nhập lại để duyệt yêu cầu.');
    }

    final role = await UserService.getUserRole(user.uid);
    final isSuperAdmin = UserService.isCurrentUserSuperAdmin();
    final canReview = isSuperAdmin || role == 'owner' || role == 'manager';
    if (!canReview) {
      throw Exception('Bạn không có quyền duyệt yêu cầu đổi ca.');
    }

    if (request.status != 'pending') {
      throw Exception('Yêu cầu đã được xử lý trước đó.');
    }

    final reviewerName = await UserService.getCurrentUserName();
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = request.copyWith(
      status: status,
      reviewedBy: user.uid,
      reviewedByName:
          reviewerName.isEmpty ? (user.email ?? 'Quản lý') : reviewerName,
      reviewedAt: now,
      rejectReason: rejectReason,
      updatedAt: now,
      isSynced: false,
    );

    await _dbHelper.upsertShiftSwapRequest(updated);
    await _syncToCloud(updated);
    EventBus().emit('shift_swap_requests_changed');
    // An approved/rejected swap changes the effective schedule for its
    // date — attendance late/early/OT already-computed for that date (if
    // check-in happened before approval) is intentionally NOT retroactively
    // recomputed here; the next edit/recompute pass (manager time edit,
    // salary calculation) will pick up the new schedule. Documented, not a
    // gap: retroactively rewriting isLate/isEarlyLeave on unrelated
    // attendance rows from inside this service would be a surprising
    // side-effect with no single obvious record to target.
  }

  static Future<void> _syncToCloud(ShiftSwapRequest request) async {
    if (!AppSession.syncEnabled) return; // offline session: no cloud
    try {
      final data = request.toMap();
      data['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
      data['serverUpdatedAt'] = FieldValue.serverTimestamp();
      await CloudWritePolicy.guard(
        () => _db
            .collection('shift_swap_requests')
            .doc(request.firestoreId)
            .set(data, SetOptions(merge: true)),
        context: 'shift_swap_requests',
      );
    } catch (e) {
      debugPrint('ShiftSwapService sync to cloud error: $e');
    }
  }

  static void debugLog(Object message) {
    if (!AppSession.syncEnabled) return; // offline session: no cloud
    debugPrint('ShiftSwapService: $message');
  }
}
