import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
  static final _db = FirebaseFirestore.instance;
  static DateTime _appStartTime = DateTime.now();

  static Future<void> init() async {
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(initSettings);
    _appStartTime = DateTime.now(); // Ghi nhớ lúc mở app để không báo lại tin cũ
  }

  // HÀM LẮNG NGHE THÔNG BÁO (ĐÃ SỬA LỖI LẶP LIÊN TỤC)
  static void listenToNotifications(Function(String, String) onMessageReceived) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    UserService.getCurrentShopId().then((shopId) {
      if (shopId == null) return;

      _db.collection('shop_notifications')
        .where('shopId', isEqualTo: shopId) // CHỈ LẤY THÔNG BÁO CỦA SHOP MÌNH
        .where('createdAt', isGreaterThan: Timestamp.fromDate(_appStartTime)) // CHỈ LẤY TIN MỚI PHÁT SINH
        .snapshots().listen((snapshot) {
          for (var change in snapshot.docChanges) {
            // Chỉ báo khi có tài liệu MỚI được thêm vào
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;
              
              // Nếu mình không phải là người tạo ra thông báo này thì mới báo
              if (data['senderId'] != user.uid) {
                String title = data['title'] ?? "THÔNG BÁO";
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
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Lỗi gửi thông báo: $e");
    }
  }

  static Future<void> _showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'shop_channel', 'Thông báo cửa hàng',
      importance: Importance.max, priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(DateTime.now().millisecond, title, body, details);
  }

  static void showSnackBar(String message, {Color color = Colors.blueAccent}) {
    messengerKey.currentState?.hideCurrentSnackBar();
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
