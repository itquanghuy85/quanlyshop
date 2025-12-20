import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _db = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// KHỞI TẠO HỆ THỐNG THÔNG BÁO (Hàm bị thiếu)
  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await _localNotifications.initialize(initializationSettings);
  }

  /// Gửi thông báo lên Cloud để tất cả các máy khác nhận được
  static Future<void> sendCloudNotification({required String title, required String body}) async {
    final user = FirebaseAuth.instance.currentUser;
    String sender = user?.email?.split('@').first.toUpperCase() ?? "NV";

    await _db.collection('shop_notifications').add({
      'title': title,
      'body': body,
      'sender': sender,
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': [user?.uid], 
    });
  }

  /// Lắng nghe thông báo mới từ Cloud và hiện thông báo rung máy
  static void listenToNotifications(Function(String, String) onMessageReceived) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _db.collection('shop_notifications')
      .where('readBy', isNotEqualTo: user.uid)
      .snapshots()
      .listen((snapshot) {
        for (var doc in snapshot.docs) {
          final data = doc.data();
          String title = data['title'] ?? "THÔNG BÁO SHOP";
          String body = data['body'] ?? "";
          
          _showLocalNotification(title, body);
          onMessageReceived(title, body);
          
          doc.reference.update({
            'readBy': FieldValue.arrayUnion([user.uid])
          });
        }
      });
  }

  /// Lắng nghe tin nhắn chat mới trong phòng chat chung
  static void listenToChatMessages(Function(String, String) onMessageReceived) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _db
        .collection('chats')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        if (data['senderId'] == user.uid) continue; // Không báo lại tin mình vừa gửi

        final sender = (data['senderName'] ?? 'Nhân viên').toString();
        final msg = (data['message'] ?? '').toString();
        final title = "Chat mới từ $sender";

        _showLocalNotification(title, msg);
        onMessageReceived(title, msg);
      }
    });
  }

  static Future<void> _showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'shop_channel', 'Thông báo Cửa hàng',
      importance: Importance.max, priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(0, title, body, details);
  }
}
