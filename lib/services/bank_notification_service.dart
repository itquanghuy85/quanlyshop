// BankNotificationService — đọc thông báo giao dịch từ app ngân hàng (Android)
// và lưu vào bảng `bank_notifications` để gợi ý đối soát ở màn "Đối soát tiền về".
//
// AN TOÀN & RIÊNG TƯ:
// - Android-only. iOS/web/desktop: `isSupported == false`, mọi hàm là no-op.
// - Mặc định TẮT (`bank_notif_enabled`). Chỉ chạy khi người dùng bật TRONG app
//   VÀ cấp quyền "Truy cập thông báo" của hệ thống.
// - CHỈ đọc thông báo từ nguồn trong danh sách ngân hàng (`resolveBankSource`).
//   Thông báo app khác bị bỏ qua hoàn toàn, không đọc, không lưu.
// - KHÔNG tự ghi tiền. Chỉ tạo bản ghi "gợi ý"; người dùng vẫn phải xác nhận
//   ở màn Đối soát để ghi nhận (qua đúng luồng `executePaymentDirect` cũ).
// - Lưu CỤC BỘ theo máy, không đồng bộ cloud.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bank_directory.dart';
import '../data/db_helper.dart';
import 'bank_notification_parser.dart';
import 'event_bus.dart';
import 'user_service.dart';

class BankNotificationService {
  BankNotificationService._();
  static final BankNotificationService instance = BankNotificationService._();

  static const _prefKey = 'bank_notif_enabled';

  final DBHelper _db = DBHelper();

  /// Số GD ngân hàng chưa đối soát — cho badge ở Home + màn Đối soát.
  final ValueNotifier<int> unreviewedCount = ValueNotifier<int>(0);

  StreamSubscription<ServiceNotificationEvent>? _sub;
  bool _running = false;

  bool get isSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------ enable flag
  Future<bool> isEnabled() async {
    if (!isSupported) return false;
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_prefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setEnabled(bool value) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_prefKey, value);
    } catch (_) {}
    if (value) {
      await start();
    } else {
      await stop();
    }
  }

  // ------------------------------------------------------------------ permission
  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    try {
      return await NotificationListenerService.isPermissionGranted();
    } catch (e) {
      debugPrint('BankNotificationService.hasPermission: $e');
      return false;
    }
  }

  /// Mở màn Cài đặt "Truy cập thông báo" của hệ thống. Một số máy/phiên bản
  /// plugin trả về null (không đợi người dùng) → bỏ qua lỗi cast, luôn kiểm
  /// tra lại quyền THỰC TẾ sau đó.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      await NotificationListenerService.requestPermission();
    } catch (e) {
      debugPrint('BankNotificationService.requestPermission: $e');
    }
    return hasPermission();
  }

  // ------------------------------------------------------------------ lifecycle
  /// Bật lắng nghe. Gọi sau khi đăng nhập nếu đã bật + có quyền.
  Future<void> start() async {
    if (!isSupported || _running) {
      debugPrint('🔔 BankNotif.start skip: supported=$isSupported running=$_running');
      return;
    }
    final en = await isEnabled();
    final perm = await hasPermission();
    if (!en || !perm) {
      debugPrint('🔔 BankNotif.start skip: enabled=$en permission=$perm');
      return;
    }

    _running = true;
    try {
      _sub = NotificationListenerService.notificationsStream.listen(
        _onEvent,
        onError: (Object e) => debugPrint('🔔 bank notif stream error: $e'),
      );
      debugPrint('🔔 BankNotif.start: đã lắng nghe thông báo ngân hàng');
      // Bắt bù: quét thông báo đang hiển thị (GD xảy ra lúc app tắt nhưng
      // thông báo còn trên thanh trạng thái).
      unawaited(_scanActive());
    } catch (e) {
      debugPrint('BankNotificationService.start: $e');
      _running = false;
    }
    await refreshCount();
    unawaited(_db.pruneOldBankNotifications());
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _running = false;
  }

  /// Gọi khi app resume — bắt các thông báo còn trên thanh trạng thái.
  Future<void> onAppResumed() async {
    if (!_running) return;
    await _scanActive();
    await refreshCount();
  }

  Future<void> refreshCount() async {
    try {
      unreviewedCount.value = await _db.getNewBankNotificationCount();
    } catch (_) {}
  }

  // ------------------------------------------------------------------ processing
  Future<void> _onEvent(ServiceNotificationEvent event) async {
    try {
      if (event.hasRemoved == true) return;
      await _ingest(
        packageName: event.packageName,
        title: event.title,
        content: event.content,
      );
    } catch (e) {
      debugPrint('bank notif _onEvent: $e');
    }
  }

  Future<void> _scanActive() async {
    try {
      final list = await NotificationListenerService.getActiveNotifications();
      for (final e in list) {
        await _ingest(
          packageName: e.packageName,
          title: e.title,
          content: e.content,
        );
      }
    } catch (e) {
      debugPrint('bank notif _scanActive: $e');
    }
  }

  Future<void> _ingest({
    String? packageName,
    String? title,
    String? content,
  }) async {
    var bankName = resolveBankSource(
      packageName: packageName,
      notificationTitle: title,
    );
    // Hook QA (CHỈ debug): `adb shell cmd notification post` gửi từ gói
    // com.android.shell — coi tiêu đề như tên NH để test đường dẫn đầy đủ.
    if (bankName == null &&
        kDebugMode &&
        packageName == 'com.android.shell') {
      bankName = resolveBankSource(
        packageName: 'com.google.android.apps.messaging',
        notificationTitle: title,
      );
    }
    if (bankName == null) {
      return; // im lặng: mọi thông báo không phải NH đều rơi vào đây
    }

    final parsed = BankNotificationParser.parse(title: title, content: content);
    if (parsed == null) {
      // Chỉ log ở bản debug — nội dung thông báo NH là dữ liệu nhạy cảm,
      // không được ghi ra logcat của bản phát hành.
      if (kDebugMode) {
        debugPrint('🔔 BankNotif: $bankName — parse=null. '
            'title="$title" content="$content"');
      }
      return;
    }

    final now = DateTime.now();
    final raw = [title ?? '', content ?? '']
        .where((s) => s.trim().isNotEmpty)
        .join('\n')
        .trim();
    final rawNorm = raw.replaceAll(RegExp(r'\s+'), ' ');
    final dayBucket = now.millisecondsSinceEpoch ~/ 86400000;
    final dedupHash =
        '${packageName ?? ''}|${parsed.amount}|${parsed.direction}|$dayBucket|${rawNorm.hashCode}';

    final shopId = UserService.getShopIdSync() ?? '';
    final isNew = await _db.insertBankNotificationOnce({
      'dedupHash': dedupHash,
      'shopId': shopId,
      'at': now.millisecondsSinceEpoch,
      'bankPackage': packageName,
      'bankName': bankName,
      'direction': parsed.direction,
      'amount': parsed.amount,
      'balanceAfter': parsed.balanceAfter,
      'memo': parsed.memo,
      'rawText': raw.length > 500 ? raw.substring(0, 500) : raw,
      'status': 'new',
      'createdAt': now.millisecondsSinceEpoch,
    });

    if (isNew) {
      await refreshCount();
      EventBus().emit('bank_notifications_changed');
      if (kDebugMode) {
        debugPrint(
          '🔔 Bank notif: $bankName ${parsed.direction} ${parsed.amount}đ',
        );
      }
    }
  }
}
