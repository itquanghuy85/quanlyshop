import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_write_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Security service for super admin account.
/// Provides:
/// - PIN protection (secondary verification after login)
/// - Session timeout (auto-lock after inactivity)
/// - Login audit logging to Firestore
class SuperAdminSecurityService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // Session management
  static DateTime? _lastActivityTime;
  static bool _isSessionVerified = false;
  static const Duration _sessionTimeout = Duration(minutes: 30);

  static const String _pinHashKey = 'super_admin_pin_hash';
  static const String _pinSetKey = 'super_admin_pin_set';
  static const String _pinFailKey = 'super_admin_pin_fail_count';
  static const String _pinLockKey = 'super_admin_pin_locked_until';

  // ─── CHỐNG DÒ PIN ────────────────────────────
  /// Cho sai bao nhiêu lần trước khi bắt đầu khoá.
  static const int _maxAttemptsBeforeLock = 5;

  /// Khoá luỹ tiến: lần khoá thứ n chờ bao lâu.
  static Duration _lockoutFor(int failCount) {
    final over = failCount - _maxAttemptsBeforeLock;
    if (over < 0) return Duration.zero;
    const steps = [30, 60, 300, 900, 1800]; // 30s → 1p → 5p → 15p → 30p
    return Duration(seconds: steps[over.clamp(0, steps.length - 1)]);
  }

  /// Còn bao lâu mới được thử lại (Duration.zero = đang không bị khoá).
  static Future<Duration> pinLockoutRemaining() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final until = prefs.getInt(_pinLockKey) ?? 0;
      if (until == 0) return Duration.zero;
      final left = until - DateTime.now().millisecondsSinceEpoch;
      return left > 0 ? Duration(milliseconds: left) : Duration.zero;
    } catch (_) {
      return Duration.zero;
    }
  }

  /// Đã thiết lập PIN chưa.
  ///
  /// ⚠️ KHÔNG được chỉ đọc SharedPreferences: hash còn được đồng bộ lên
  /// `admin_security/{uid}` (xem [setupPin]) và [verifyPin] vẫn đọc được từ đó.
  /// Nếu chỉ hỏi prefs thì trên máy MỚI / sau khi xoá dữ liệu app, hàm này trả
  /// `false` ⇒ Console **không hỏi PIN lần nào**, vào thẳng chỉ với email+mật
  /// khẩu, mà màn Cài đặt còn báo "Chưa thiết lập PIN" rồi ghi đè hash cũ nếu
  /// người dùng đặt lại. Vì vậy prefs trống thì phải hỏi cloud.
  static Future<bool> isPinSetup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_pinSetKey) ?? false) return true;
      if ((prefs.getString(_pinHashKey) ?? '').isNotEmpty) return true;

      // Prefs trống → hỏi cloud (máy mới / vừa xoá dữ liệu app).
      final user = _auth.currentUser;
      if (user == null) return false;
      final doc = await _db.collection('admin_security').doc(user.uid).get();
      final hash = (doc.data()?['pinHash'] as String?) ?? '';
      if (hash.isEmpty) return false;

      // Cache lại để lần sau khỏi tốn vòng mạng.
      await prefs.setString(_pinHashKey, hash);
      await prefs.setBool(_pinSetKey, true);
      return true;
    } catch (e) {
      // Lỗi mạng ⇒ KHÔNG kết luận "chưa có PIN" nếu prefs còn dấu vết.
      debugPrint('isPinSetup: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        return (prefs.getString(_pinHashKey) ?? '').isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  /// Set up or change PIN (4-6 digits)
  static Future<bool> setupPin(String pin) async {
    if (pin.length < 4 || pin.length > 6 || !RegExp(r'^\d+$').hasMatch(pin)) {
      return false;
    }
    try {
      final hash = _hashPinPbkdf2(pin);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pinHashKey, hash);
      await prefs.setBool(_pinSetKey, true);
      await _resetFailures(prefs);

      // Also store in Firestore for cross-device sync
      final user = _auth.currentUser;
      if (user != null) {
        await _db.collection('admin_security').doc(user.uid).set({
          'pinHash': hash,
          'updatedAt': FirestoreWriteHelper.serverUpdatedAt(),
        }, SetOptions(merge: true));
      }
      debugPrint('✅ Super admin PIN set up successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error setting up PIN: $e');
      return false;
    }
  }

  /// Verify PIN
  ///
  /// Bị KHOÁ TẠM sau [_maxAttemptsBeforeLock] lần sai (khoá luỹ tiến
  /// 30s→1p→5p→15p→30p) — PIN chỉ 4–6 chữ số nên không chặn thì dò cạn được.
  /// Trong lúc bị khoá, hàm trả `false` ngay mà KHÔNG so hash.
  static Future<bool> verifyPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final remaining = await pinLockoutRemaining();
      if (remaining > Duration.zero) {
        await _logAdminAction('pin_verify_locked_out', success: false);
        return false;
      }

      String? storedHash = prefs.getString(_pinHashKey);
      if (storedHash == null || storedHash.isEmpty) {
        // Máy mới / vừa xoá dữ liệu app → lấy hash từ cloud.
        final user = _auth.currentUser;
        if (user != null) {
          final doc = await _db.collection('admin_security').doc(user.uid).get();
          final firestoreHash = doc.data()?['pinHash'] as String?;
          if (firestoreHash != null && firestoreHash.isNotEmpty) {
            storedHash = firestoreHash;
            await prefs.setString(_pinHashKey, firestoreHash);
            await prefs.setBool(_pinSetKey, true);
          }
        }
      }

      if (storedHash == null || storedHash.isEmpty) {
        await _logAdminAction('pin_verify_failed', success: false);
        return false;
      }

      final verified = _matchesStoredHash(pin, storedHash);
      if (verified) {
        // Nâng cấp âm thầm hash cũ (sha256 1 vòng, salt dùng chung) sang PBKDF2
        // ngay lần nhập đúng đầu tiên — người dùng không phải đặt lại PIN.
        if (!storedHash.startsWith('$_pbkdf2Prefix\$')) {
          try {
            final upgraded = _hashPinPbkdf2(pin);
            await prefs.setString(_pinHashKey, upgraded);
            final user = _auth.currentUser;
            if (user != null) {
              await _db.collection('admin_security').doc(user.uid).set({
                'pinHash': upgraded,
                'updatedAt': FirestoreWriteHelper.serverUpdatedAt(),
              }, SetOptions(merge: true));
            }
            debugPrint('🔐 Đã nâng cấp hash PIN cũ sang PBKDF2');
          } catch (e) {
            debugPrint('⚠️ Nâng cấp hash PIN thất bại (bỏ qua): $e');
          }
        }
        await _resetFailures(prefs);
        _markSessionVerified();
        await _logAdminAction('pin_verified', success: true);
      } else {
        await _registerFailure(prefs);
        await _logAdminAction('pin_verify_failed', success: false);
      }
      return verified;
    } catch (e) {
      debugPrint('❌ Error verifying PIN: $e');
      return false;
    }
  }

  /// Remove PIN
  static Future<bool> removePin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pinHashKey);
      await prefs.setBool(_pinSetKey, false);
      await _resetFailures(prefs);

      final user = _auth.currentUser;
      if (user != null) {
        await _db.collection('admin_security').doc(user.uid).set({
          'pinHash': FieldValue.delete(),
          'pinRemoved': true,
          'updatedAt': FirestoreWriteHelper.serverUpdatedAt(),
        }, SetOptions(merge: true));
      }
      await _logAdminAction('pin_removed');
      return true;
    } catch (e) {
      debugPrint('❌ Error removing PIN: $e');
      return false;
    }
  }

  // ─── SESSION ─────────────────────────────────

  /// Mark session as verified (after PIN entry)
  static void _markSessionVerified() {
    _isSessionVerified = true;
    _lastActivityTime = DateTime.now();
  }

  /// Update activity timestamp (call on user interaction)
  static void touchActivity() {
    if (_isSessionVerified) {
      _lastActivityTime = DateTime.now();
    }
  }

  /// Check if current session is still valid
  static bool isSessionValid() {
    if (!_isSessionVerified) return false;
    if (_lastActivityTime == null) return false;
    return DateTime.now().difference(_lastActivityTime!) < _sessionTimeout;
  }

  /// Lock the session (require PIN again)
  static void lockSession() {
    _isSessionVerified = false;
    _lastActivityTime = null;
  }

  /// Clear all session state (on logout)
  static void clearSession() {
    _isSessionVerified = false;
    _lastActivityTime = null;
  }

  // ─── AUDIT LOG ───────────────────────────────

  /// Log super admin action to Firestore
  static Future<void> _logAdminAction(String action, {bool success = true}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _db.collection('admin_audit_log').add({
        'uid': user.uid,
        'email': user.email,
        'action': action,
        'success': success,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : 'mobile',
      });
    } catch (e) {
      debugPrint('Audit log error (non-fatal): $e');
    }
  }

  /// Log shop selection
  static Future<void> logShopAccess(String shopId, String? shopName) async {
    await _logAdminAction('shop_access: $shopId ($shopName)');
  }

  /// Log super admin login
  static Future<void> logLogin() async {
    await _logAdminAction('super_admin_login');
  }

  /// Public audit helper for Super Admin actions.
  static Future<void> logAction({
    required String action,
    String? shopId,
    String? targetUserId,
    Map<String, dynamic>? metadata,
    bool success = true,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _db.collection('admin_audit_log').add({
        'uid': user.uid,
        'email': user.email,
        'action': action,
        'shopId': shopId,
        'targetUserId': targetUserId,
        'metadata': metadata ?? <String, dynamic>{},
        'success': success,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : 'mobile',
      });
    } catch (e) {
      debugPrint('Audit log error (non-fatal): $e');
    }
  }

  /// Get recent audit logs
  static Future<List<Map<String, dynamic>>> getRecentAuditLogs({int limit = 50}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];
      final snap = await _db.collection('admin_audit_log')
          .where('uid', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('getRecentAuditLogs error: $e');
      return [];
    }
  }

  // ─── HELPERS ─────────────────────────────────

  // ─── BĂM PIN ─────────────────────────────────
  //
  // Bản cũ: sha256('super_admin_salt_huluca_' + pin) — MỘT vòng, salt là hằng
  // số biên dịch DÙNG CHUNG cho mọi super admin. PIN chỉ 4–6 chữ số nên tổng
  // không gian khoá ~1,11 triệu; vì salt cố định, một bảng tra dựng sẵn phá
  // được PIN của BẤT KỲ super admin nào trong chớp mắt.
  //
  // Bản mới: PBKDF2-HMAC-SHA256, salt ngẫu nhiên RIÊNG từng người, lưu kèm
  // hash theo dạng `pbkdf2_sha256$<iterations>$<salt_b64>$<dk_b64>`.
  // Hash cũ vẫn xác thực được và được nâng cấp âm thầm ngay lần nhập đúng
  // đầu tiên (xem [verifyPin]).

  static const String _pbkdf2Prefix = 'pbkdf2_sha256';
  static const int _pbkdf2Iterations = 100000;
  static const int _saltBytes = 16;
  static const int _dkLenBytes = 32;

  static String _hashPinPbkdf2(String pin) {
    final rnd = Random.secure();
    final salt = List<int>.generate(_saltBytes, (_) => rnd.nextInt(256));
    final dk = _pbkdf2(
      password: utf8.encode(pin),
      salt: salt,
      iterations: _pbkdf2Iterations,
    );
    return '$_pbkdf2Prefix\$$_pbkdf2Iterations\$'
        '${base64Encode(salt)}\$${base64Encode(dk)}';
  }

  /// So PIN với hash đã lưu — nhận cả dạng mới lẫn dạng cũ.
  static bool _matchesStoredHash(String pin, String storedHash) {
    if (storedHash.startsWith('$_pbkdf2Prefix\$')) {
      final parts = storedHash.split(r'$');
      if (parts.length != 4) return false;
      final iterations = int.tryParse(parts[1]) ?? 0;
      if (iterations <= 0) return false;
      try {
        final salt = base64Decode(parts[2]);
        final expected = base64Decode(parts[3]);
        final dk = _pbkdf2(
          password: utf8.encode(pin),
          salt: salt,
          iterations: iterations,
          dkLen: expected.length,
        );
        return _constantTimeEquals(dk, expected);
      } catch (_) {
        return false;
      }
    }
    // Hash cũ (sha256 1 vòng, salt hằng số) — giữ để không khoá cửa người đang dùng.
    final legacy = sha256.convert(
      utf8.encode('super_admin_salt_huluca_$pin'),
    ).toString();
    return _constantTimeEquals(utf8.encode(legacy), utf8.encode(storedHash));
  }

  /// So sánh không rò rỉ thời gian (tránh timing attack).
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// PBKDF2-HMAC-SHA256 (RFC 8018). Gói `crypto` không có sẵn nên tự dựng
  /// trên `Hmac`.
  static List<int> _pbkdf2({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    int dkLen = _dkLenBytes,
  }) {
    final hmac = Hmac(sha256, password);
    final out = <int>[];
    var blockIndex = 1;
    while (out.length < dkLen) {
      final block = <int>[
        ...salt,
        (blockIndex >> 24) & 0xff,
        (blockIndex >> 16) & 0xff,
        (blockIndex >> 8) & 0xff,
        blockIndex & 0xff,
      ];
      var u = hmac.convert(block).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.addAll(t);
      blockIndex++;
    }
    return out.sublist(0, dkLen);
  }

  // ─── ĐẾM LẦN SAI ─────────────────────────────

  static Future<void> _resetFailures(SharedPreferences prefs) async {
    await prefs.remove(_pinFailKey);
    await prefs.remove(_pinLockKey);
  }

  static Future<void> _registerFailure(SharedPreferences prefs) async {
    final count = (prefs.getInt(_pinFailKey) ?? 0) + 1;
    await prefs.setInt(_pinFailKey, count);
    final lock = _lockoutFor(count);
    if (lock > Duration.zero) {
      await prefs.setInt(
        _pinLockKey,
        DateTime.now().add(lock).millisecondsSinceEpoch,
      );
      await _logAdminAction(
        'pin_locked_out_${lock.inSeconds}s',
        success: false,
      );
    }
  }
}

