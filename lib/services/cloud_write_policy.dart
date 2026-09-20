// CloudWritePolicy — chính sách DUY NHẤT cho mọi lệnh ghi Firestore trực tiếp
// (ngoài hàng đợi SyncOrchestrator) trong nghiệp vụ.
//
// Vì sao cần (audit 2026-09-20, BUG-01/02/04): Firestore SDK bật persistence,
// nên `set/update/add/runTransaction` khi KHÔNG có mạng trả về Future chỉ hoàn
// tất khi server ack ⇒ treo vô hạn. `FirestoreService` có 67 lệnh ghi, 0 lệnh
// có timeout; `create_sale_view` chỉ rơi về local-first khi `permission-denied`.
//
// Chính sách (docs/QA_OFFLINE_SYNC_AUDIT.md §2):
//   1. Gate mạng TRƯỚC khi bắt đầu write: không có mạng ⇒ ném
//      [CloudOfflineException] ngay, KHÔNG khởi động write (nếu khởi động, SDK
//      sẽ tự ghi lại khi có mạng ⇒ trùng với hàng đợi của app).
//   2. Mọi write có timeout: tương tác 12 s, nền 25 s (= SyncOrchestrator).
//   3. Phân loại lỗi: OFFLINE (unavailable / deadline-exceeded /
//      network-request-failed / timeout / socket) ⇒ caller commit local +
//      hàng đợi; PERMANENT (permission-denied / invalid-argument /
//      failed-precondition / not-found) ⇒ báo lỗi, không queue vô hạn.
import 'dart:async';
import 'dart:io' show SocketException;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Write không thể tới cloud vì lý do MẠNG (không phải lỗi dữ liệu/quyền).
/// Caller phải coi như "đã lưu trên máy, sẽ đồng bộ sau".
class CloudOfflineException implements Exception {
  final String context;
  final Object? cause;
  const CloudOfflineException(this.context, [this.cause]);

  @override
  String toString() =>
      'CloudOfflineException($context${cause != null ? ': $cause' : ''})';
}

class CloudWritePolicy {
  CloudWritePolicy._();

  /// Người dùng đang chờ trên màn hình: tối đa 12 s rồi trả lời "đã lưu trên
  /// máy". Ack Firestore online thường < 2 s, 3G chậm < 8 s.
  static const Duration interactive = Duration(seconds: 12);

  /// Ghi nền (syncAllToCloud, batch) — bằng `SyncOrchestrator._cloudWriteTimeout`.
  static const Duration background = Duration(seconds: 25);

  /// Cache kết quả kiểm mạng trong 2 s để một nghiệp vụ nhiều write không gọi
  /// platform channel lặp lại.
  static const Duration _networkCacheTtl = Duration(seconds: 2);
  static bool? _lastHasNetwork;
  static DateTime? _lastNetworkCheckAt;

  /// Cho test/unit: ép kết quả kiểm mạng (null = hỏi platform).
  @visibleForTesting
  static bool? networkOverride;

  /// Có kết nối mạng ở tầng thiết bị (wifi/cell/ethernet)? Không đo được
  /// internet thật — captive portal vẫn trả true và sẽ rơi vào timeout.
  static Future<bool> hasNetwork() async {
    final override = networkOverride;
    if (override != null) return override;
    final now = DateTime.now();
    final cached = _lastHasNetwork;
    final at = _lastNetworkCheckAt;
    if (cached != null && at != null && now.difference(at) < _networkCacheTtl) {
      return cached;
    }
    bool result;
    try {
      final results = await Connectivity().checkConnectivity();
      result = results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      // Không hỏi được platform ⇒ giả định có mạng, để timeout quyết định.
      result = true;
    }
    _lastHasNetwork = result;
    _lastNetworkCheckAt = now;
    return result;
  }

  /// Xoá cache kiểm mạng (gọi khi connectivity đổi).
  static void invalidateNetworkCache() {
    _lastHasNetwork = null;
    _lastNetworkCheckAt = null;
  }

  /// Chạy một lệnh ghi cloud theo chính sách. [op] PHẢI là closure để write
  /// chưa được khởi động trước khi gate mạng.
  ///
  /// Ném [CloudOfflineException] khi mất mạng/timeout; ném lại nguyên lỗi
  /// khác (permission-denied, invalid-argument…) để caller phân biệt.
  static Future<T> guard<T>(
    Future<T> Function() op, {
    required String context,
    Duration timeout = interactive,
    bool precheck = true,
  }) async {
    if (precheck && !await hasNetwork()) {
      debugPrint('📴 CloudWritePolicy: không có mạng, bỏ qua write $context');
      throw CloudOfflineException(context);
    }
    try {
      return await op().timeout(timeout);
    } on TimeoutException catch (e) {
      debugPrint(
        '⏱️ CloudWritePolicy: timeout ${timeout.inSeconds}s tại $context',
      );
      throw CloudOfflineException(context, e);
    } on FirebaseException catch (e) {
      if (isOfflineError(e)) {
        debugPrint('📴 CloudWritePolicy: lỗi mạng tại $context: ${e.code}');
        throw CloudOfflineException(context, e);
      }
      rethrow;
    } on SocketException catch (e) {
      throw CloudOfflineException(context, e);
    }
  }

  /// Lỗi do MẠNG (có thể thử lại sau, không phải lỗi dữ liệu).
  static bool isOfflineError(Object? error) {
    if (error == null) return false;
    if (error is CloudOfflineException ||
        error is TimeoutException ||
        error is SocketException) {
      return true;
    }
    if (error is FirebaseException) {
      return _offlineCodes.contains(error.code);
    }
    final s = error.toString().toLowerCase();
    return s.contains('unavailable') ||
        s.contains('deadline-exceeded') ||
        s.contains('deadline_exceeded') ||
        s.contains('network-request-failed') ||
        s.contains('network error') ||
        s.contains('cloudofflineexception') ||
        s.contains('timeoutexception') ||
        s.contains('socketexception');
  }

  /// Lỗi VĨNH VIỄN — thử lại không giúp; không được đưa vào hàng đợi vô hạn.
  static bool isPermanentError(Object? error) {
    if (error == null) return false;
    if (error is FirebaseException) {
      return _permanentCodes.contains(error.code);
    }
    final s = error.toString().toLowerCase();
    return s.contains('permission-denied') ||
        s.contains('permission_denied') ||
        s.contains('missing or insufficient permissions') ||
        s.contains('invalid-argument') ||
        s.contains('failed-precondition');
  }

  static const Set<String> _offlineCodes = {
    'unavailable',
    'deadline-exceeded',
    'network-request-failed',
    'aborted', // transaction contention/mạng chập chờn — thử lại được
  };

  static const Set<String> _permanentCodes = {
    'permission-denied',
    'invalid-argument',
    'failed-precondition',
    'not-found',
    'already-exists',
    'unauthenticated',
  };
}
