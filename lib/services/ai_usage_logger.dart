import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'user_service.dart';

/// Loại tương tác AI
enum AiCallType {
  quickAnswer,   // pattern cứng, không tốn tiền
  cloudAI,       // gọi DeepSeek qua Cloud Function
  parseOrder,    // parse đơn hàng từ văn bản
  feedback,      // user bấm 👍/👎
}

/// Ghi log mọi lần user tương tác với AI vào Firestore collection `ai_usage_logs`.
/// Dùng để: theo dõi chi phí, phát hiện bất thường, hiển thị dashboard cho Owner.
class AiUsageLogger {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'ai_usage_logs';

  static Future<void> log({
    required AiCallType type,
    required String query,
    String? answer,
    bool? feedbackPositive,
    int estimatedTokens = 0,
    List<String> matchedKb = const [],
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final shopId = await UserService.getCurrentShopId();
      if (shopId == null) return;

      await _db.collection(_collection).add({
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'shopId': shopId,
        'type': type.name,
        'query': query.length > 300 ? query.substring(0, 300) : query,
        if (answer != null)
          'answerSnippet': answer.length > 200 ? answer.substring(0, 200) : answer,
        if (feedbackPositive != null) 'feedbackPositive': feedbackPositive,
        if (matchedKb.isNotEmpty) 'matchedKb': matchedKb,
        'estimatedTokens': estimatedTokens,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      // Logging lỗi không được làm gián đoạn flow chính
      debugPrint('AiUsageLogger: $e');
    }
  }

  /// Đếm số cloud AI calls của một user trong ngày hôm nay.
  static Future<int> countCloudCallsToday(String userId, String shopId) async {
    try {
      final start = DateTime.now().copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0,
      );
      final snap = await _db
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('shopId', isEqualTo: shopId)
          .where('type', isEqualTo: AiCallType.cloudAI.name)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Tổng hợp usage theo ngày cho dashboard Owner.
  static Future<Map<String, dynamic>> getShopSummaryToday(String shopId) async {
    try {
      final start = DateTime.now().copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0,
      );
      final snap = await _db
          .collection(_collection)
          .where('shopId', isEqualTo: shopId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .get();

      int cloudCalls = 0;
      int quickCalls = 0;
      int positiveFeeds = 0;
      int negativeFeeds = 0;
      final userSet = <String>{};
      final negativeFeedbackItems = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final d = doc.data();
        final t = d['type'] as String? ?? '';
        if (t == AiCallType.cloudAI.name) { cloudCalls++; }
        if (t == AiCallType.quickAnswer.name) { quickCalls++; }
        if (t == AiCallType.feedback.name) {
          if (d['feedbackPositive'] == true) {
            positiveFeeds++;
          } else {
            negativeFeeds++;
            negativeFeedbackItems.add(d);
          }
        }
        if (d['userId'] is String) { userSet.add(d['userId'] as String); }
      }

      return {
        'cloudCalls': cloudCalls,
        'quickCalls': quickCalls,
        'positiveFeeds': positiveFeeds,
        'negativeFeeds': negativeFeeds,
        'activeUsers': userSet.length,
        'totalInteractions': snap.docs.length,
        'negativeFeedbackItems': negativeFeedbackItems,
      };
    } catch (_) {
      return {};
    }
  }
}
