import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
  static final _db = FirebaseFirestore.instance;

  static Future<void> init() async {
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(initSettings);
  }

  // Khôi phục hàm lắng nghe thông báo để main.dart không báo lỗi
  static void listenToNotifications(Function(String, String) onMessageReceived) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _db.collection('shop_notifications')
      .where('readBy', isNotEqualTo: user.uid)
      .snapshots().listen((snapshot) {
        for (var doc in snapshot.docs) {
          final data = doc.data();
          String title = data['title'] ?? "THÔNG BÁO";
          String body = data['body'] ?? "";
          _showLocalNotification(title, body);
          onMessageReceived(title, body);
          doc.reference.update({'readBy': FieldValue.arrayUnion([user.uid])});
        }
      });
  }

  static Future<void> sendCloudNotification({required String title, required String body}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final shopId = await UserService.getCurrentShopId();
      await _db.collection('shop_notifications').add({
        'shopId': shopId,
        'title': title,
        'body': body,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [user?.uid], 
      });
    } catch (e) {
      debugPrint("Lỗi gửi thông báo: $e");
    }
  }

  static Future<void> _showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'shop_channel', 'Thông báo cửa hàng',
      importance: Importance.max, priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(0, title, body, details);
  }

  static void showSnackBar(String message, {Color color = Colors.blueAccent}) {
    messengerKey.currentState?.hideCurrentSnackBar();
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
