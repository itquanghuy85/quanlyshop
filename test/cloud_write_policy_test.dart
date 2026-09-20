// CloudWritePolicy — chính sách ghi cloud chung (audit 2026-09-20, BUG-01/02/04).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/services/cloud_write_policy.dart';

void main() {
  tearDown(() => CloudWritePolicy.networkOverride = null);

  test('không có mạng ⇒ ném CloudOfflineException NGAY, không khởi động write',
      () async {
    CloudWritePolicy.networkOverride = false;
    var started = false;
    final sw = Stopwatch()..start();
    await expectLater(
      CloudWritePolicy.guard(() async {
        started = true;
        return 1;
      }, context: 'test'),
      throwsA(isA<CloudOfflineException>()),
    );
    expect(started, isFalse, reason: 'write không được khởi động khi mất mạng');
    expect(sw.elapsedMilliseconds, lessThan(500));
  });

  test('có mạng ⇒ chạy write và trả kết quả', () async {
    CloudWritePolicy.networkOverride = true;
    final v = await CloudWritePolicy.guard(() async => 42, context: 'test');
    expect(v, 42);
  });

  test('timeout ⇒ CloudOfflineException (không treo)', () async {
    CloudWritePolicy.networkOverride = true;
    final sw = Stopwatch()..start();
    await expectLater(
      CloudWritePolicy.guard(
        () => Completer<int>().future, // không bao giờ hoàn tất
        context: 'hang',
        timeout: const Duration(milliseconds: 200),
      ),
      throwsA(isA<CloudOfflineException>()),
    );
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });

  test('phân loại: unavailable = offline, permission-denied = permanent',
      () async {
    CloudWritePolicy.networkOverride = true;
    await expectLater(
      CloudWritePolicy.guard(
        () async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
        context: 'x',
      ),
      throwsA(isA<CloudOfflineException>()),
    );
    await expectLater(
      CloudWritePolicy.guard(
        () async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
        context: 'x',
      ),
      throwsA(
        isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied'),
      ),
    );
    expect(
      CloudWritePolicy.isOfflineError(
        '[cloud_firestore/unavailable] The service is currently unavailable',
      ),
      isTrue,
    );
    expect(CloudWritePolicy.isOfflineError('CloudOfflineException(x)'), isTrue);
    expect(
      CloudWritePolicy.isPermanentError('Missing or insufficient permissions'),
      isTrue,
    );
    expect(CloudWritePolicy.isOfflineError('permission-denied'), isFalse);
  });
}
