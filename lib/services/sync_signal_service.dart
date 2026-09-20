// SyncSignalService — tín hiệu "có thay đổi" liên máy bằng MỘT document.
//
// Vấn đề (BUG-05, audit 2026-09-20): chỉ `repairs`/`sales` có listener
// realtime; 28 bảng còn lại (products, debts, payment_intents, repair_parts…)
// chỉ được kéo về khi app resume / bấm đồng bộ ⇒ máy B mở liên tục không thấy
// tồn kho / công nợ máy A vừa đổi. Thêm listener cho từng bảng thì đắt
// (mỗi listener nối lại = đọc trọn tập kết quả).
//
// Giải pháp: người ghi cloud "bump" `shops/{shopId}/meta/sync_signal`
// (`{tables: {col: ms}, by: deviceId}`), mọi máy khác nghe DUY NHẤT doc này
// (1 read mỗi lần đổi) và gọi `SyncService.refreshCollectionNow(col)` — truy
// vấn con trỏ `updatedAt` tăng dần, chỉ trả doc thật sự đổi. Không poll,
// không listener theo bảng. Bỏ qua tín hiệu của chính máy mình.
//
// Rules: `shops/{shopId}/meta/{docId}` cho phép mọi thành viên shop ghi/đọc.
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_session.dart';
import 'cloud_write_policy.dart';
import 'sync_service.dart';
import 'user_service.dart';

class SyncSignalService {
  SyncSignalService._();

  static const String docId = 'sync_signal';
  static const Duration _debounce = Duration(milliseconds: 1500);
  static const String _deviceIdPref = 'sync_signal_device_id';

  /// Bảng đã có listener realtime riêng — không cần tín hiệu.
  static const Set<String> _liveCollections = {'repairs', 'sales'};

  /// Bảng KHÔNG đồng bộ về SQLite (không có refresher) — bỏ qua.
  static const Set<String> _ignored = {
    'chats',
    'notifications',
    'shop_notifications',
    'shops',
    'users',
    'meta',
    'unknown',
    'reset',
  };

  static String? _deviceId;
  static final Map<String, int> _pendingBump = {};
  static Timer? _bumpTimer;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  static String? _listeningShopId;
  static final Map<String, int> _seen = {};
  static bool _firstSnapshot = true;

  /// Cho test: tắt hoàn toàn (không ghi, không nghe).
  @visibleForTesting
  static bool disabled = false;

  static Future<String> deviceId() async {
    final cached = _deviceId;
    if (cached != null) return cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_deviceIdPref);
      if (id == null || id.isEmpty) {
        final rnd = Random();
        id =
            'dev_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}_${rnd.nextInt(1 << 30).toRadixString(36)}';
        await prefs.setString(_deviceIdPref, id);
      }
      _deviceId = id;
      return id;
    } catch (_) {
      _deviceId = 'dev_unknown';
      return _deviceId!;
    }
  }

  /// Chuẩn hoá tên bảng từ context ghi (vd `products.tx`, `sales.batch`).
  static String _normalize(String context) {
    final base = context.split('.').first.split('/').first.trim();
    return base;
  }

  /// Báo "bảng [collections] vừa đổi trên cloud". Gộp trong 1,5 s, ghi 1 lần.
  /// Không bao giờ ném lỗi — tín hiệu là phụ, nghiệp vụ không phụ thuộc.
  static void bump(Iterable<String> collections) {
    if (disabled || !AppSession.syncEnabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    var added = false;
    for (final c in collections) {
      final col = _normalize(c);
      if (col.isEmpty || _ignored.contains(col) || _liveCollections.contains(col)) {
        continue;
      }
      _pendingBump[col] = now;
      added = true;
    }
    if (!added) return;
    _bumpTimer?.cancel();
    _bumpTimer = Timer(_debounce, () => unawaited(_flush()));
  }

  static Future<void> _flush() async {
    if (_pendingBump.isEmpty) return;
    final tables = Map<String, int>.from(_pendingBump);
    _pendingBump.clear();
    final shopId = _listeningShopId ?? UserService.getShopIdSync();
    if (shopId == null || shopId.isEmpty) return;
    try {
      final by = await deviceId();
      await CloudWritePolicy.guard(
        () => FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('meta')
            .doc(docId)
            .set({
              'tables': tables,
              'by': by,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)),
        context: 'meta/sync_signal',
        timeout: CloudWritePolicy.background,
      );
      debugPrint('📡 SyncSignal: bump ${tables.keys.join(',')}');
    } catch (e) {
      // Mất mạng thì bỏ — lượt sync kế tiếp (khi có mạng) sẽ bump lại.
      debugPrint('📡 SyncSignal: bump bỏ qua ($e)');
      // Giữ lại để lần bump sau gộp chung (không tạo timer mới ở đây).
      for (final e in tables.entries) {
        _pendingBump.putIfAbsent(e.key, () => e.value);
      }
    }
  }

  /// Bắt đầu nghe tín hiệu của [shopId]. Gọi từ `SyncService.initRealTimeSync`.
  static Future<void> listen(String shopId) async {
    if (disabled || !AppSession.syncEnabled) return;
    if (_listeningShopId == shopId && _sub != null) return;
    await stop();
    _listeningShopId = shopId;
    _firstSnapshot = true;
    final me = await deviceId();
    _sub = FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('meta')
        .doc(docId)
        .snapshots()
        .listen(
          (snap) {
            // Lần đầu chỉ ghi nhận mốc — dữ liệu ban đầu đã do poll mở app lo.
            final data = snap.data();
            final tables = (data?['tables'] as Map?)?.cast<String, dynamic>();
            if (tables == null) return;
            if (_firstSnapshot) {
              _firstSnapshot = false;
              for (final e in tables.entries) {
                _seen[e.key] = (e.value as num?)?.toInt() ?? 0;
              }
              return;
            }
            if (data?['by'] == me) return; // tín hiệu của chính máy này
            final changed = <String>[];
            for (final e in tables.entries) {
              final ts = (e.value as num?)?.toInt() ?? 0;
              if (ts > (_seen[e.key] ?? 0)) {
                _seen[e.key] = ts;
                changed.add(e.key);
              }
            }
            if (changed.isEmpty) return;
            debugPrint('📡 SyncSignal: nhận ${changed.join(',')} từ ${data?['by']}');
            unawaited(_refresh(changed));
          },
          onError: (e) => debugPrint('📡 SyncSignal listener lỗi: $e'),
        );
    debugPrint('📡 SyncSignal: đang nghe shop $shopId');
  }

  /// Kéo các bảng vừa được báo. Nếu đang có lượt refresh gộp thì đợi 3 s rồi
  /// thử lại (tối đa 3 lần) — `refreshCollectionNow` trả về sớm khi bận và
  /// tín hiệu sẽ mất nếu không hoãn.
  static Future<void> _refresh(List<String> cols, [int attempt = 0]) async {
    if (SyncService.isRefreshingCollections && attempt < 3) {
      await Future<void>.delayed(const Duration(seconds: 3));
      return _refresh(cols, attempt + 1);
    }
    for (final col in cols) {
      await SyncService.refreshCollectionNow(col);
    }
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _listeningShopId = null;
    _seen.clear();
  }
}
