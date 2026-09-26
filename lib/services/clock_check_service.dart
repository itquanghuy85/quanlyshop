import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_session.dart';
import 'cloud_write_policy.dart';

/// Detects a device clock that was moved away from real time (F-14:
/// attendance uses device-local `DateTime.now()`, so changing the phone's
/// clock could backdate a check-in). Reference time = the HTTP `Date`
/// header of a Google endpoint the app already talks to.
class ClockCheckService {
  static const Duration maxAllowedSkew = Duration(minutes: 5);
  static const Duration _timeout = Duration(seconds: 5);
  static final Uri _probe = Uri.parse('https://firestore.googleapis.com/');

  /// Parses an RFC 1123 HTTP date header.
  @visibleForTesting
  static DateTime? parseHttpDate(String? header) {
    if (header == null || header.isEmpty) return null;
    try {
      return HttpDate.parse(header);
    } catch (_) {
      return null;
    }
  }

  /// device − reference; positive = device clock ahead.
  @visibleForTesting
  static Duration skewOf(DateTime device, DateTime reference) =>
      device.toUtc().difference(reference.toUtc());

  @visibleForTesting
  static bool isSkewTooLarge(Duration skew) => skew.abs() > maxAllowedSkew;

  /// Returns the device clock skew, or null when it could not be measured
  /// (offline, no network, request failed) — callers must then allow the
  /// action (offline-first), not block it.
  static Future<Duration?> measureSkew() async {
    if (!AppSession.syncEnabled || !await CloudWritePolicy.hasNetwork()) {
      return null;
    }
    try {
      final sentAt = DateTime.now();
      final res = await http.head(_probe).timeout(_timeout);
      final receivedAt = DateTime.now();
      final reference = parseHttpDate(res.headers['date']);
      if (reference == null) return null;
      final deviceMid = sentAt.add(receivedAt.difference(sentAt) ~/ 2);
      return skewOf(deviceMid, reference);
    } catch (e) {
      debugPrint('ClockCheckService.measureSkew: $e');
      return null;
    }
  }
}
