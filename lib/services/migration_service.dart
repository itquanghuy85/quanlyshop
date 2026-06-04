import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class MigrationCancelledException implements Exception {
  const MigrationCancelledException();
}

class MigrationResult {
  final int totalCopied;
  final List<String> errors;
  final Duration elapsed;

  const MigrationResult({
    required this.totalCopied,
    required this.errors,
    required this.elapsed,
  });

  bool get hasErrors => errors.isNotEmpty;
}

class MigrationService {
  static const _batchSize = 400;
  static const _pageSize = 500;
  static final _db = FirebaseFirestore.instance;

  static Future<int> countRepairs(String shopId) async {
    try {
      final agg = await _db
          .collection('repairs')
          .where('shopId', isEqualTo: shopId)
          .where('deleted', isEqualTo: false)
          .count()
          .get();
      return agg.count ?? 0;
    } catch (e) {
      debugPrint('MigrationService.countRepairs error: $e');
      return 0;
    }
  }

  static Future<MigrationResult> migrateRepairs({
    required String sourceShopId,
    required String targetShopId,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final stopwatch = Stopwatch()..start();
    final errors = <String>[];
    int totalCopied = 0;

    try {
      final total = await countRepairs(sourceShopId);
      onProgress?.call(0, total);

      DocumentSnapshot? lastDoc;
      bool hasMore = true;
      final buffer = <QueryDocumentSnapshot>[];

      // Collect all docs via pagination
      while (hasMore) {
        if (isCancelled?.call() == true) throw const MigrationCancelledException();

        var query = _db
            .collection('repairs')
            .where('shopId', isEqualTo: sourceShopId)
            .where('deleted', isEqualTo: false)
            .orderBy(FieldPath.documentId)
            .limit(_pageSize);

        if (lastDoc != null) query = query.startAfterDocument(lastDoc);

        final snap = await query.get();
        if (snap.docs.isEmpty) break;

        buffer.addAll(snap.docs);
        lastDoc = snap.docs.last;
        hasMore = snap.docs.length == _pageSize;
      }

      // Batch write in chunks
      for (int i = 0; i < buffer.length; i += _batchSize) {
        if (isCancelled?.call() == true) throw const MigrationCancelledException();

        final chunk = buffer.sublist(
          i,
          (i + _batchSize) > buffer.length ? buffer.length : i + _batchSize,
        );

        final batch = _db.batch();
        for (final doc in chunk) {
          final newRef = _db.collection('repairs').doc();
          final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
          data['shopId'] = targetShopId;
          data['firestoreId'] = newRef.id;
          data['updatedAt'] = FieldValue.serverTimestamp();
          data['isSynced'] = true;
          batch.set(newRef, data);
        }

        try {
          await batch.commit();
          totalCopied += chunk.length;
          onProgress?.call(totalCopied, buffer.isEmpty ? total : buffer.length);
        } catch (e) {
          errors.add('Batch lỗi (${i ~/ _batchSize + 1}): $e');
          debugPrint('MigrationService batch error: $e');
        }
      }
    } on MigrationCancelledException {
      rethrow;
    } catch (e) {
      errors.add('Lỗi nghiêm trọng: $e');
      debugPrint('MigrationService.migrateRepairs error: $e');
    }

    stopwatch.stop();
    return MigrationResult(
      totalCopied: totalCopied,
      errors: errors,
      elapsed: stopwatch.elapsed,
    );
  }
}
