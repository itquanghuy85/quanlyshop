import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, Timestamp;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/stock_entry_model.dart';

/// Local persistence for stock entries (phiếu nhập kho) while the app runs
/// in the offline session (PLAN_OFFLINE_FIRST step 3b).
///
/// `stock_entries` has no SQLite table — online they live only in Firestore.
/// Offline, drafts and confirmed entries are kept here as JSON so that
/// "Chờ xác nhận nhập vào kho" keeps working and the claim step (4) can
/// replay confirmed entries to the cloud.
class OfflineStockEntryStore {
  OfflineStockEntryStore._();

  static const _prefKey = 'offline_stock_entries_v1';
  static Map<String, Map<String, dynamic>>? _cache;

  static String newEntryId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rand = Random.secure().nextInt(1 << 30).toRadixString(36);
    return 'se_${ms}_$rand';
  }

  static Future<Map<String, Map<String, dynamic>>> _load() async {
    if (_cache != null) return _cache!;
    final out = <String, Map<String, dynamic>>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (v is Map) out[k.toString()] = Map<String, dynamic>.from(v);
          });
        }
      }
    } catch (e) {
      debugPrint('OfflineStockEntryStore.load failed: $e');
    }
    _cache = out;
    return out;
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(_cache ?? {}));
    } catch (e) {
      debugPrint('OfflineStockEntryStore.persist failed: $e');
    }
  }

  /// `StockEntry.toMap()` targets Firestore (Timestamp / FieldValue).
  /// Make it JSON-safe: timestamps → epoch ms.
  static Map<String, dynamic> _toJson(StockEntry e) {
    final map = e.toMap();
    final now = DateTime.now().millisecondsSinceEpoch;
    Object? fix(Object? v) {
      if (v is Timestamp) return v.millisecondsSinceEpoch;
      if (v is FieldValue) return now;
      if (v is DateTime) return v.millisecondsSinceEpoch;
      if (v is Map) return v.map((k, x) => MapEntry(k.toString(), fix(x)));
      if (v is List) return v.map(fix).toList();
      return v;
    }

    final out = <String, dynamic>{};
    map.forEach((k, v) => out[k] = fix(v));
    out['firestoreId'] = e.firestoreId;
    return out;
  }

  static StockEntry _fromJson(String id, Map<String, dynamic> json) {
    final map = Map<String, dynamic>.from(json);
    for (final key in ['createdAt', 'confirmedAt', 'updatedAt']) {
      final v = map[key];
      if (v is int) map[key] = DateTime.fromMillisecondsSinceEpoch(v);
    }
    return StockEntry.fromMap(map, docId: id);
  }

  static Future<void> put(StockEntry entry) async {
    final id = entry.firestoreId;
    if (id == null || id.isEmpty) {
      throw ArgumentError('OfflineStockEntryStore.put: entry has no id');
    }
    final all = await _load();
    all[id] = _toJson(entry);
    await _persist();
  }

  static Future<StockEntry?> get(String id) async {
    final all = await _load();
    final json = all[id];
    if (json == null) return null;
    try {
      return _fromJson(id, json);
    } catch (e) {
      debugPrint('OfflineStockEntryStore.get($id) parse failed: $e');
      return null;
    }
  }

  static Future<void> remove(String id) async {
    final all = await _load();
    all.remove(id);
    await _persist();
  }

  static Future<List<StockEntry>> where(
    bool Function(StockEntry e) test, {
    String? shopId,
  }) async {
    final all = await _load();
    final out = <StockEntry>[];
    for (final e in all.entries) {
      try {
        final entry = _fromJson(e.key, e.value);
        if (shopId != null && entry.shopId != shopId) continue;
        if (test(entry)) out.add(entry);
      } catch (_) {}
    }
    out.sort((a, b) {
      final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });
    return out;
  }

  static Future<List<StockEntry>> drafts({String? shopId}) =>
      where((e) => e.status == StockEntryStatus.draft, shopId: shopId);

  static Future<List<StockEntry>> confirmed({String? shopId}) =>
      where((e) => e.status == StockEntryStatus.confirmed, shopId: shopId);

  /// Test-only.
  @visibleForTesting
  static Future<void> clear() async {
    _cache = {};
    await _persist();
  }
}
