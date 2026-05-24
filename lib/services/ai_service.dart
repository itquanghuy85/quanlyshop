import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/ai_repair_result.dart';
import '../models/ai_universal_result.dart';

enum AiStatus { idle, loading, success, error }

class AiException implements Exception {
  final String message;
  final bool isRateLimit;
  final bool isTimeout;

  const AiException(this.message,
      {this.isRateLimit = false, this.isTimeout = false});

  @override
  String toString() => 'AiException: $message';
}

// ── Client-side result cache ─────────────────────────────────────────────────
class _CacheEntry {
  final AiUniversalResult result;
  final DateTime timestamp;
  _CacheEntry(this.result, this.timestamp);
  bool get isValid =>
      DateTime.now().difference(timestamp) < AiService._cacheTtl;
}

/// Service wrapping Firebase Cloud Functions for AI-powered order parsing.
///
/// Architecture:
///   Flutter → [AiService] → Cloud Function → DeepSeek API
///
/// DeepSeek API key is NEVER in Flutter — it lives exclusively in
/// Google Secret Manager, read by the Cloud Function at runtime.
///
/// Client-side cache: up to 50 results, 10-minute TTL.
/// Server-side cache: Firestore `_ai_cache`, 24-hour TTL (handled by CF).
class AiService {
  AiService._();
  static final AiService instance = AiService._();

  static const _cacheTtl = Duration(minutes: 10);
  static const _maxCacheSize = 50;

  final Map<String, _CacheEntry> _cache = {};

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  // ── Cache helpers ────────────────────────────────────────────────────────

  String _cacheKey(String text, String? hintMode) =>
      '${hintMode ?? ""}:${text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}';

  void _putCache(String key, AiUniversalResult result) {
    _cache[key] = _CacheEntry(result, DateTime.now());
    if (_cache.length > _maxCacheSize) {
      final oldest = _cache.entries.reduce(
        (a, b) => a.value.timestamp.isBefore(b.value.timestamp) ? a : b,
      );
      _cache.remove(oldest.key);
    }
  }

  /// Clear the entire client-side cache (e.g. on sign-out).
  void clearCache() => _cache.clear();

  // ── Universal parse (repair / sale / stock) ──────────────────────────────

  /// Parse free-text into [AiUniversalResult] via `parseOrderAI` Cloud Function.
  ///
  /// [hintMode]: optional hint — `'repair'`, `'sale'`, or `'stock'`.
  /// Throws [AiException] on rate-limit, timeout, or network errors.
  Future<AiUniversalResult> parseUniversal(String text,
      {String? hintMode}) async {
    if (text.trim().isEmpty) return AiUniversalResult.unknown;

    try {
      final callable = _functions.httpsCallable(
        'parseOrderAI',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 28)),
      );
      final res = await callable.call<Map<String, dynamic>>({
        'text': text,
        if (hintMode != null) 'hint_mode': hintMode,
      });

      final raw = res.data;
      if (raw['success'] != true) return AiUniversalResult.unknown;
      final data = raw['data'];
      if (data is! Map<String, dynamic>) return AiUniversalResult.unknown;

      final result = AiUniversalResult.fromJson(data, fromAi: true);
      debugPrint('✅ AiService.parseUniversal: intent=${result.intent}');
      return result;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ AiService FunctionsException: ${e.code} — ${e.message}');
      throw _mapFunctionError(e);
    } catch (e) {
      if (e is AiException) rethrow;
      debugPrint('❌ AiService unexpected: $e');
      throw const AiException('Lỗi kết nối. Kiểm tra mạng và thử lại.');
    }
  }

  /// Safe wrapper — returns `(result, errorMessage)`, never throws.
  /// Checks client-side cache first; caches successful responses.
  Future<(AiUniversalResult?, String?)> tryParseUniversal(
    String text, {
    String? hintMode,
  }) async {
    final key = _cacheKey(text, hintMode);
    final cached = _cache[key];
    if (cached != null && cached.isValid) {
      debugPrint('🔁 AiService: cache hit (${hintMode ?? "auto"})');
      return (cached.result, null);
    }

    try {
      final result = await parseUniversal(text, hintMode: hintMode);
      _putCache(key, result);
      return (result, null);
    } on AiException catch (e) {
      return (null, e.message);
    } catch (_) {
      return (null, 'Lỗi không xác định.');
    }
  }

  // ── Legacy repair-only (backward-compat with AiRepairInputSheet) ─────────

  Future<AiRepairResult> parseRepairText(String text) async {
    if (text.trim().isEmpty) return AiRepairResult.unknown;
    try {
      final callable = _functions.httpsCallable(
        'createRepairOrderAI',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 28)),
      );
      final res = await callable.call<Map<String, dynamic>>({'text': text});
      final raw = res.data;
      if (raw['success'] != true) return AiRepairResult.unknown;
      final data = raw['data'];
      if (data is! Map<String, dynamic>) return AiRepairResult.unknown;
      return AiRepairResult.fromJson(data);
    } on FirebaseFunctionsException catch (e) {
      throw _mapFunctionError(e);
    } catch (e) {
      if (e is AiException) rethrow;
      throw const AiException('Lỗi kết nối.');
    }
  }

  Future<(AiRepairResult?, String?)> tryParseRepairText(String text) async {
    try {
      final result = await parseRepairText(text);
      return (result, null);
    } on AiException catch (e) {
      return (null, e.message);
    } catch (_) {
      return (null, 'Lỗi không xác định.');
    }
  }

  // ── Error mapping ────────────────────────────────────────────────────────

  AiException _mapFunctionError(FirebaseFunctionsException e) {
    return switch (e.code) {
      'resource-exhausted' => AiException(
          e.message ?? 'Quá nhiều yêu cầu. Thử lại sau 1 phút.',
          isRateLimit: true),
      'deadline-exceeded' =>
        const AiException('AI phản hồi quá chậm. Thử lại.', isTimeout: true),
      'unauthenticated' => const AiException('Yêu cầu đăng nhập lại.'),
      'invalid-argument' =>
        AiException(e.message ?? 'Nội dung không hợp lệ.'),
      _ => AiException(e.message ?? 'Lỗi AI. Thử lại sau.'),
    };
  }
}
