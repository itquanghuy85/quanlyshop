import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_session.dart';

/// Owner re-authentication used before destructive actions (delete product,
/// delete repair order, unlock sale edit, ...).
///
/// Online: re-authenticates the Firebase user with e-mail + password (the
/// historical behaviour, unchanged).
/// Offline (PLAN_OFFLINE_FIRST step 3): there is no account. The device owner
/// may set an optional local PIN ("Mật khẩu bảo vệ") in Đồng bộ & Tài khoản;
/// when it is set the same dialogs verify the PIN, when it is not set the
/// dialogs are skipped entirely ([shouldSkipPrompt]).
class OwnerReauthService {
  OwnerReauthService._();

  static const _prefPinHash = 'offline_owner_pin_hash';
  static String? _cachedHash;
  static bool _loaded = false;

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedHash = prefs.getString(_prefPinHash);
    } catch (_) {}
    _loaded = true;
  }

  static String _hash(String pin) =>
      sha256.convert(utf8.encode('huluca-offline-pin:$pin')).toString();

  /// Whether an offline PIN is configured on this device.
  static Future<bool> hasOfflinePin() async {
    await _ensureLoaded();
    return _cachedHash != null && _cachedHash!.isNotEmpty;
  }

  /// Set (non-empty) or clear (empty) the offline PIN.
  static Future<void> setOfflinePin(String? pin) async {
    final prefs = await SharedPreferences.getInstance();
    if (pin == null || pin.trim().isEmpty) {
      await prefs.remove(_prefPinHash);
      _cachedHash = null;
    } else {
      _cachedHash = _hash(pin.trim());
      await prefs.setString(_prefPinHash, _cachedHash!);
    }
    _loaded = true;
  }

  /// True when the caller may skip its password prompt altogether:
  /// offline session without a PIN.
  static Future<bool> shouldSkipPrompt() async {
    if (!AppSession.isOffline) return false;
    return !(await hasOfflinePin());
  }

  /// Synchronous variant for call sites that cannot await before building a
  /// dialog; relies on the cache filled by any earlier call.
  static bool get shouldSkipPromptSync =>
      AppSession.isOffline && (_cachedHash == null || _cachedHash!.isEmpty);

  /// Verify [password] for the current session. Never throws.
  static Future<bool> verify(String password) async {
    if (AppSession.isOffline) {
      await _ensureLoaded();
      final hash = _cachedHash;
      if (hash == null || hash.isEmpty) return true; // no PIN configured
      return _hash(password.trim()) == hash;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return false;
    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
      return true;
    } catch (e) {
      debugPrint('OwnerReauthService.verify failed: $e');
      return false;
    }
  }

  /// Warm the cache at startup so [shouldSkipPromptSync] is accurate.
  static Future<void> warmUp() => _ensureLoaded();
}
