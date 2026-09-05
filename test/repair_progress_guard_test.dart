import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/services/sync_orchestrator.dart';

/// Bảo vệ đơn sửa khỏi bị một máy còn giữ bản CŨ (chưa sync) ghi đè, làm đơn
/// "tụt" về Tiếp nhận và mất luôn KTV / mốc sửa xong.
/// Bối cảnh: sự cố 2026-09-05 — đơn IPHONE 11 đã "Chờ duyệt giao" quay về
/// "Tiếp nhận" + mất tên KTV.
void main() {
  Map<String, dynamic> repairPayload({
    required int status,
    int? lastCaredAt,
    String? repairedBy,
    int? finishedAt,
    bool pending = false,
  }) {
    return <String, dynamic>{
      'status': status,
      'pendingDeliveryApproval': pending ? 1 : 0,
      'lastCaredAt': lastCaredAt,
      'repairedBy': repairedBy,
      'repairedByUid': repairedBy == null ? null : 'uid_$repairedBy',
      'finishedAt': finishedAt,
      'deliveredAt': null,
      'price': 1100000,
      'cost': 600000,
      'notes': 'GHI CHÚ MỚI',
    };
  }

  group('applyRepairCloudGuards', () {
    test('bản chụp lúc tạo đơn KHÔNG được hạ cấp đơn đang chờ duyệt giao', () {
      // Máy A tạo đơn 15:11, sync lỗi → local vẫn status 1, chưa từng sửa lại.
      final local = repairPayload(status: 1);
      // Máy B đã "Sửa xong" + gửi duyệt giao lúc 15:12.
      final cloud = repairPayload(
        status: 3,
        lastCaredAt: 1000000,
        repairedBy: 'MISS TRÂM',
        finishedAt: 999000,
        pending: true,
      );

      final stripped = SyncOrchestrator.applyRepairCloudGuards(local, cloud);

      expect(stripped, isTrue);
      expect(local.containsKey('status'), isFalse);
      expect(local.containsKey('repairedBy'), isFalse);
      expect(local.containsKey('finishedAt'), isFalse);
      expect(local.containsKey('pendingDeliveryApproval'), isFalse);
      // Các thay đổi khác vẫn được đồng bộ bình thường.
      expect(local['notes'], 'GHI CHÚ MỚI');
      expect(local['cost'], 600000);
    });

    test('hạ cấp CÓ CHỦ ĐÍCH (local vừa sửa) vẫn được đẩy lên', () {
      // Quản lý chủ động chuyển đơn từ "Sửa xong" về "Đang sửa" lúc 15:20.
      final local = repairPayload(status: 2, lastCaredAt: 2000000);
      final cloud = repairPayload(status: 3, lastCaredAt: 1000000);

      final stripped = SyncOrchestrator.applyRepairCloudGuards(local, cloud);

      expect(stripped, isFalse);
      expect(local['status'], 2);
    });

    test('cloud ĐÃ GIAO (4) là trạng thái cuối — local cũ không đảo ngược', () {
      final local = repairPayload(status: 3, lastCaredAt: 9000000);
      final cloud = repairPayload(status: 4, lastCaredAt: 1000000);

      final stripped = SyncOrchestrator.applyRepairCloudGuards(local, cloud);

      expect(stripped, isTrue);
      expect(local.containsKey('status'), isFalse);
      expect(local.containsKey('deliveredAt'), isFalse);
    });

    test('cloud không mới hơn thì giữ nguyên payload', () {
      final local = repairPayload(status: 3, lastCaredAt: 2000000);
      final cloud = repairPayload(status: 3, lastCaredAt: 1000000);

      final stripped = SyncOrchestrator.applyRepairCloudGuards(local, cloud);

      expect(stripped, isFalse);
      expect(local['status'], 3);
    });
  });
}
