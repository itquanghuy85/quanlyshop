import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/audit_event.dart';
import '../models/audit_stats.dart';

/// Core singleton của Firestore Audit Monitor.
///
/// Kill Switch: setEnabled(false) dừng TOÀN BỘ hoạt động.
/// Không tạo thêm Firestore Query, không đọc/ghi Firestore.
/// Lưu trữ hoàn toàn trong bộ nhớ (+ SharedPreferences cho daily total).
class FirestoreAuditService {
  FirestoreAuditService._();
  static final FirestoreAuditService instance = FirestoreAuditService._();

  static const String _prefKeyEnabled = 'dev_audit_firestore_enabled';
  static const int _maxRecentEvents = 500;

  // ── State ──────────────────────────────────────────────────────────────────
  bool _enabled = false;
  bool _initialized = false;

  final AuditSessionStats _stats = AuditSessionStats();
  final List<AuditEvent> _recentEvents = [];

  // Active listeners: collection -> count
  final Map<String, int> _activeListeners = {};

  // Live stream
  final StreamController<AuditEvent> _liveController =
      StreamController<AuditEvent>.broadcast();

  // Stats change notifier
  final StreamController<AuditSessionStats> _statsController =
      StreamController<AuditSessionStats>.broadcast();

  // Daily reads (persisted)
  int _dailyReadsTotal = 0;
  String _dailyKey = '';

  // ── Public API ─────────────────────────────────────────────────────────────

  bool get isEnabled => _enabled;

  Stream<AuditEvent> get liveStream => _liveController.stream;
  Stream<AuditSessionStats> get statsStream => _statsController.stream;

  AuditSessionStats get stats => _stats;
  List<AuditEvent> get recentEvents => List.unmodifiable(_recentEvents);
  Map<String, int> get activeListeners => Map.unmodifiable(_activeListeners);
  int get dailyReadsTotal => _dailyReadsTotal;

  /// Khởi tạo service — chỉ đọc SharedPreferences, không đọc Firestore.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefKeyEnabled) ?? false;
      await _loadDailyStats(prefs);
    } catch (e) {
      debugPrint('[AuditService] init error: $e');
    }
  }

  /// Bật/tắt kill switch.
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyEnabled, value);
    } catch (_) {}
    if (!value) {
      _activeListeners.clear();
    }
    _notifyStats();
  }

  /// Ghi nhận một sự kiện Firestore Read.
  /// Gọi từ FirebaseUsageStatsService hook hoặc từ các điểm tích hợp tùy chọn.
  void logRead({
    required String collection,
    required AuditOperation operation,
    required String callerService,
    required String callerMethod,
    String? callerScreen,
    required int documentCount,
    int? estimatedReads,
    int executionTimeMs = 0,
    bool isActiveListener = false,
    String? queryInfo,
  }) {
    if (!_enabled) return;
    if (collection.trim().isEmpty) return;

    final reads = estimatedReads ?? math.max(documentCount, 0);

    final event = AuditEvent(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}',
      timestamp: DateTime.now(),
      collection: collection.trim(),
      operation: operation,
      callerService: callerService,
      callerMethod: callerMethod,
      callerScreen: callerScreen,
      documentCount: documentCount,
      estimatedReads: reads,
      executionTimeMs: executionTimeMs,
      isActiveListener: isActiveListener,
      queryInfo: queryInfo,
    );

    _recentEvents.add(event);
    if (_recentEvents.length > _maxRecentEvents) {
      _recentEvents.removeAt(0);
    }

    _stats.absorb(event);
    _updateDailyTotal(reads);

    if (isActiveListener) {
      _activeListeners[collection] = (_activeListeners[collection] ?? 0) + 1;
    }

    if (!_liveController.isClosed) {
      _liveController.add(event);
    }
    _notifyStats();
  }

  /// Ghi nhận listener bị đóng (cancel).
  void logListenerClosed(String collection) {
    if (!_enabled) return;
    if (_activeListeners.containsKey(collection)) {
      final current = _activeListeners[collection]!;
      if (current <= 1) {
        _activeListeners.remove(collection);
      } else {
        _activeListeners[collection] = current - 1;
      }
      _notifyStats();
    }
  }

  /// Reset toàn bộ thống kê session (không xóa daily).
  void resetSessionStats() {
    _stats.reset();
    _recentEvents.clear();
    _activeListeners.clear();
    _notifyStats();
  }

  /// Reset toàn bộ bao gồm daily.
  Future<void> resetAll() async {
    resetSessionStats();
    _dailyReadsTotal = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('dev_audit_daily_${_todayKey()}', 0);
    } catch (_) {}
    _notifyStats();
  }

  /// Dọn dẹp khi module bị tắt.
  void dispose() {
    if (!_liveController.isClosed) _liveController.close();
    if (!_statsController.isClosed) _statsController.close();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _notifyStats() {
    if (!_statsController.isClosed) {
      _statsController.add(_stats);
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadDailyStats(SharedPreferences prefs) async {
    _dailyKey = _todayKey();
    _dailyReadsTotal = prefs.getInt('dev_audit_daily_$_dailyKey') ?? 0;
  }

  void _updateDailyTotal(int reads) {
    if (reads <= 0) return;
    _dailyReadsTotal += reads;
    final today = _todayKey();
    // Save asynchronously, don't block
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.setInt('dev_audit_daily_$today', _dailyReadsTotal);
        })
        .catchError((_) {});
  }

  String _randomSuffix() {
    final rand = math.Random();
    return rand.nextInt(99999).toString().padLeft(5, '0');
  }
}
