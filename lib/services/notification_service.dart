import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'user_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
  static final _db = FirebaseFirestore.instance;
  static DateTime _appStartTime = DateTime.now();

  static Future<void> init() async {
    // 1. Xin quyền thông báo (Bắt buộc cho Android 13+)
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // 2. Khởi tạo Plugin
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidInit);
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Xử lý khi người dùng chạm vào thông báo (nếu cần)
      },
    );

    // Tạo Channel cho Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'shop_channel', 'Thông báo cửa hàng',
      description: 'Thông báo về đơn hàng và tin nhắn mới',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _appStartTime = DateTime.now();
  }

  // HÀM LẮNG NGHE THÔNG BÁO CHUẨN KIẾN TRÚC
  static void listenToNotifications(Function(String, String) onMessageReceived) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    UserService.getCurrentShopId().then((shopId) {
      if (shopId == null) return;

      _db.collection('shop_notifications')
        .where('shopId', isEqualTo: shopId)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(_appStartTime))
        .snapshots().listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;
              
              // Chỉ báo nếu không phải mình gửi
              if (data['senderId'] != user.uid) {
                String title = data['title'] ?? "THÔNG BÁO MỚI";
                String body = data['body'] ?? "";
                
                _showLocalNotification(title, body);
                onMessageReceived(title, body);
              }
            }
          }
        });
    });
  }

  static Future<void> sendCloudNotification({required String title, required String body}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null) return;

      await _db.collection('shop_notifications').add({
        'shopId': shopId,
        'title': title,
        'body': body,
        'senderId': user?.uid,
        'senderName': user?.email?.split('@').first.toUpperCase() ?? "NV",
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("LỖI GỬI THÔNG BÁO: $e");
    }
  }

  static Future<void> _showLocalNotification(String title, String body) async {
    final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'shop_channel', 'Thông báo cửa hàng',
      channelDescription: 'Thông báo về đơn hàng và tin nhắn mới',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher', // Sử dụng icon mặc định của app
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(id, title, body, details);
  }

  static void showSnackBar(String message, {Color color = Colors.blueAccent}) {
    messengerKey.currentState?.hideCurrentSnackBar();
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
