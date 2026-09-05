import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../data/db_helper.dart';
import 'audit_service.dart';
import 'event_bus.dart';
import 'firestore_service.dart';
import 'firestore_write_helper.dart';
import 'sync_orchestrator.dart';
import 'user_service.dart';

/// Kết quả quét đơn bán KiotViet bị nhập trùng.
class KvDuplicateReport {
  const KvDuplicateReport({
    required this.kvRecords,
    required this.invoiceCodes,
    required this.duplicateGroups,
    required this.extraRecords,
    required this.inflatedAmount,
    required this.missingShopId,
    required this.extraByMonth,
  });

  /// Tổng bản ghi mang mã `KV:` (chưa xoá).
  final int kvRecords;

  /// Số mã hoá đơn KiotViet khác nhau = số đơn THẬT.
  final int invoiceCodes;

  /// Số mã bị lặp (>1 bản ghi).
  final int duplicateGroups;

  /// Số bản ghi thừa cần dọn = kvRecords - invoiceCodes.
  final int extraRecords;

  /// Doanh thu bị cộng lặp do các bản ghi thừa.
  final int inflatedAmount;

  /// Số đơn bán còn thiếu `shopId` ở bản LOCAL.
  final int missingShopId;

  /// Bản ghi thừa theo tháng (yyyy-MM) — để đối chiếu báo cáo.
  final Map<String, int> extraByMonth;

  bool get isClean => extraRecords == 0;
}

/// Kết quả sau khi dọn.
class KvCleanupOutcome {
  const KvCleanupOutcome({
    required this.deletedLocal,
    required this.deletedCloud,
    required this.queuedForRetry,
    required this.failed,
    required this.amountRemoved,
    required this.shopIdBackfilled,
  });

  final int deletedLocal;
  final int deletedCloud;
  final int queuedForRetry;
  final int failed;
  final int amountRemoved;
  final int shopIdBackfilled;
}

/// Dọn đơn bán KiotViet bị nhập TRÙNG.
///
/// ## Vì sao có trùng
/// Đơn nhập từ Excel KiotViet được chống trùng bằng `notes = 'KV:<mã HĐ>'`,
/// nhưng chỉ chống trùng trên **máy đang import**. Khi đẩy lên cloud,
/// `sync_service` sinh doc id `sale_<soldAt>_<phone>_<s.id>` — trong đó `s.id`
/// là **số thứ tự SQLite của riêng từng máy**. Nên cùng một hoá đơn import ở
/// hai máy sẽ ra hai doc id khác nhau ⇒ hai document trên Firestore ⇒ mọi máy
/// tải về hai bản.
///
/// Hai hàm dọn trùng sẵn có đều KHÔNG bắt được ca này:
/// - `DBHelper.cleanDuplicateData` gộp theo `firestoreId` (hai bản khác id);
/// - `DBHelper.cleanupCloudShadowDuplicates` chỉ xoá bản `firestoreId` rỗng.
///
/// Chặn tái diễn: `KiotVietExcelImportService` nay gán `firestoreId` tất định
/// (`kv_<shopId>_<mã HĐ>`) ngay lúc import, nên import lại ở máy khác ghi đè
/// đúng document cũ thay vì đẻ thêm bản mới.
///
/// ## Quy tắc dọn
/// - Giữ bản ghi có `id` NHỎ NHẤT trong nhóm (cùng quy ước với
///   `cleanDuplicateData`), xoá các bản còn lại.
/// - Cloud: xoá MỀM (`deleted: true`) theo CLAUDE.md mục III.10 để máy khác
///   cũng gỡ theo. Local: xoá hẳn dòng thừa.
/// - KHÔNG đụng tới công nợ / bút toán / kho: bản trùng là bản ghi ma do đồng
///   bộ đẻ ra, chưa từng sinh sổ sách riêng.
class KvDuplicateCleanupService {
  KvDuplicateCleanupService._();

  static final DBHelper _db = DBHelper();

  static const String _kvPrefix = 'KV:';

  /// Dưới trần 500 thao tác/`WriteBatch` của Firestore, chừa biên an toàn.
  static const int _batchSize = 400;

  /// Đọc các đơn mang mã `KV:` còn hiệu lực, gom theo mã hoá đơn.
  static Future<Map<String, List<Map<String, Object?>>>> _loadGroups() async {
    final db = await _db.database;
    final rows = await db.query(
      'sales',
      columns: ['id', 'firestoreId', 'notes', 'totalPrice', 'soldAt'],
      where: 'notes LIKE ? AND (deleted IS NULL OR deleted = 0)',
      whereArgs: ['$_kvPrefix%'],
      orderBy: 'id ASC',
    );
    final groups = <String, List<Map<String, Object?>>>{};
    for (final r in rows) {
      final code = (r['notes'] as String?) ?? '';
      if (!code.startsWith(_kvPrefix)) continue;
      groups.putIfAbsent(code, () => []).add(r);
    }
    return groups;
  }

  static String _monthKey(Object? soldAt) {
    final raw = soldAt is int
        ? soldAt
        : int.tryParse('${soldAt ?? ''}') ?? 0;
    if (raw <= 0) return 'khong-ro';
    final ms = raw > 100000000000 ? raw : raw * 1000;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  /// Quét thử — KHÔNG sửa gì. Dùng để hiện số liệu cho chủ shop duyệt.
  static Future<KvDuplicateReport> scan() async {
    final groups = await _loadGroups();
    var kvRecords = 0;
    var dupGroups = 0;
    var extra = 0;
    var inflated = 0;
    final byMonth = <String, int>{};

    for (final entry in groups.entries) {
      final rows = entry.value;
      kvRecords += rows.length;
      if (rows.length < 2) continue;
      dupGroups++;
      for (final r in rows.skip(1)) {
        extra++;
        inflated += (r['totalPrice'] as int?) ?? 0;
        final k = _monthKey(r['soldAt']);
        byMonth[k] = (byMonth[k] ?? 0) + 1;
      }
    }

    final db = await _db.database;
    final missing = Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM sales WHERE (shopId IS NULL OR shopId = '') "
            "AND (deleted IS NULL OR deleted != 1)",
          ),
        ) ??
        0;

    return KvDuplicateReport(
      kvRecords: kvRecords,
      invoiceCodes: groups.length,
      duplicateGroups: dupGroups,
      extraRecords: extra,
      inflatedAmount: inflated,
      missingShopId: missing,
      extraByMonth: Map.fromEntries(
        byMonth.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      ),
    );
  }

  /// Dọn thật. [onProgress] nhận (đã xử lý, tổng cần xử lý).
  ///
  /// [backfillShopId] = true thì gán luôn `shopId` cho các dòng local còn
  /// thiếu. Lưu ý: bản trên cloud VỐN ĐÃ có `shopId` đúng (xem
  /// `sync_service.syncAllToCloud`), thiếu chỉ xảy ra ở bản local tải về vì
  /// `SaleOrder` chưa có trường `shopId`. Backfill này vì thế là dọn cho sạch,
  /// không phải điều kiện để báo cáo chạy đúng.
  static Future<KvCleanupOutcome> apply({
    void Function(int done, int total)? onProgress,
    bool backfillShopId = true,
  }) async {
    final groups = await _loadGroups();
    final victims = <Map<String, Object?>>[];
    for (final rows in groups.values) {
      if (rows.length < 2) continue;
      victims.addAll(rows.skip(1)); // rows đã sắp xếp id ASC ⇒ giữ id nhỏ nhất
    }

    var deletedLocal = 0;
    var deletedCloud = 0;
    var queued = 0;
    var failed = 0;
    var amount = 0;
    var done = 0;

    final fs = FirebaseFirestore.instance;
    final db = await _db.database;

    // Gộp lô thay vì gọi từng bản: mỗi `WriteBatch` là MỘT lượt mạng cho tới
    // 500 thao tác. Đo thực tế 06/09/2026 trên shop thật: xoá từng bản chạy
    // ~37 bản/phút ⇒ 2.181 bản mất ~47 phút; gộp lô còn vài lượt mạng.
    for (var start = 0; start < victims.length; start += _batchSize) {
      final chunk = victims.sublist(
        start,
        (start + _batchSize).clamp(0, victims.length),
      );
      final withFid = chunk
          .where((v) => ((v['firestoreId'] as String?) ?? '').trim().isNotEmpty)
          .toList();

      var cloudOk = false;
      if (withFid.isNotEmpty) {
        try {
          final batch = fs.batch();
          for (final v in withFid) {
            batch.set(
              fs.collection('sales').doc((v['firestoreId'] as String).trim()),
              {
                'deleted': true,
                'updatedAt': FirestoreWriteHelper.serverUpdatedAt(),
              },
              // merge: doc đã bị gỡ ở nơi khác thì `update` sẽ làm hỏng cả lô;
              // `set(merge)` vẫn an toàn vì ta chỉ đánh dấu đã xoá.
              SetOptions(merge: true),
            );
          }
          await batch.commit();
          deletedCloud += withFid.length;
          cloudOk = true;
        } catch (e) {
          debugPrint('KvDuplicateCleanup: lô cloud lỗi, lùi về từng bản — $e');
        }
      } else {
        cloudOk = true;
      }

      // Lô hỏng thì hạ xuống xoá lẻ để một document lỗi không kéo cả lô theo.
      if (!cloudOk) {
        for (final v in withFid) {
          final fid = (v['firestoreId'] as String).trim();
          try {
            await FirestoreService.deleteSale(fid);
            deletedCloud++;
          } catch (_) {
            try {
              await SyncOrchestrator().enqueue(
                entityType: SyncEntityType.sale,
                entityId: (v['id'] as int?) ?? 0,
                firestoreId: fid,
                operation: SyncOperation.delete,
                data: {'firestoreId': fid},
              );
              queued++;
            } catch (e2) {
              failed++;
              debugPrint('KvDuplicateCleanup: bỏ qua $fid — $e2');
            }
          }
        }
      }

      // Local: một câu DELETE cho cả lô thay vì mỗi bản một câu.
      final ids = chunk
          .map((v) => v['id'])
          .whereType<int>()
          .toList(growable: false);
      if (ids.isNotEmpty) {
        try {
          final marks = List.filled(ids.length, '?').join(',');
          deletedLocal += await db.rawDelete(
            'DELETE FROM sales WHERE id IN ($marks)',
            ids,
          );
        } catch (e) {
          failed += ids.length;
          debugPrint('KvDuplicateCleanup: xoá local lô lỗi — $e');
        }
      }

      amount += chunk.fold<int>(
        0,
        (acc, v) => acc + ((v['totalPrice'] as int?) ?? 0),
      );
      done += chunk.length;
      onProgress?.call(done, victims.length);
    }

    if (deletedLocal > 0) {
      try {
        EventBus().emit('sales_changed');
      } catch (_) {}
    }

    var backfilled = 0;
    if (backfillShopId) {
      final shopId = await UserService.getCurrentShopId();
      if (shopId != null && shopId.isNotEmpty) {
        backfilled = await _db.backfillShopId('sales', shopId);
      }
    }

    // MỘT bản ghi kiểm toán tổng — không ghi từng dòng, tránh đẻ hàng nghìn
    // lượt ghi Firestore chỉ để log việc dọn rác.
    if (deletedLocal > 0 || deletedCloud > 0) {
      try {
        await AuditService.logAction(
          action: 'RECONCILE_KV_DEDUPE',
          entityType: 'sale',
          entityId: 'kv_dedupe_${DateTime.now().millisecondsSinceEpoch}',
          summary:
              'Dọn $deletedLocal đơn bán KiotViet trùng (cloud $deletedCloud, '
              'hàng đợi $queued, lỗi $failed)',
          payload: {
            'deletedLocal': deletedLocal,
            'deletedCloud': deletedCloud,
            'queued': queued,
            'failed': failed,
            'amountRemoved': amount,
            'shopIdBackfilled': backfilled,
          },
        );
      } catch (e) {
        debugPrint('KvDuplicateCleanup: không ghi được audit log — $e');
      }
    }

    return KvCleanupOutcome(
      deletedLocal: deletedLocal,
      deletedCloud: deletedCloud,
      queuedForRetry: queued,
      failed: failed,
      amountRemoved: amount,
      shopIdBackfilled: backfilled,
    );
  }
}
