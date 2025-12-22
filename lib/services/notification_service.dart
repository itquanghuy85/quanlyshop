import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'user_service.dart';

class NotificationService {
  static final _db = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Global key để hiển thị thông báo mà không cần context
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// KHỞI TẠO HỆ THỐNG THÔNG BÁO
  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await _localNotifications.initialize(initializationSettings);
  }

  /// Hiển thị SnackBar từ bất kỳ đâu trong app
  static void showSnackBar(String message, {Color color = Colors.blueAccent}) {
    messengerKey.currentState?.hideCurrentSnackBar();
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Gửi thông báo lên Cloud để tất cả các máy khác nhận được
  static Future<void> sendCloudNotification({required String title, required String body}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      String sender = user?.email?.split('@').first.toUpperCase() ?? "NV";
      final bool isSuperAdmin = UserService.isCurrentUserSuperAdmin();
      final String? shopId = isSuperAdmin ? null : await UserService.getCurrentShopId();

      await _db.collection('shop_notifications').add({
        'shopId': shopId,
        'title': title,
        'body': body,
        'sender': sender,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [user?.uid], 
      });
    } catch (e) {
      debugPrint("Lỗi gửi thông báo Cloud: $e");
    }
  }

  /// Lắng nghe thông báo mới từ Cloud và hiện thông báo rung máy
  static Future<void> listenToNotifications(Function(String, String) onMessageReceived) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Đợi một chút để lấy shopId nếu cần
    final bool isSuperAdmin = UserService.isCurrentUserSuperAdmin();
    final String? shopId = isSuperAdmin ? null : await UserService.getCurrentShopId();

    _db.collection('shop_notifications')
      .where('readBy', isNotEqualTo: user.uid)
      .snapshots().listen((snapshot) {
        for (var doc in snapshot.docs) {
          final data = doc.data();
          
          // Kiểm tra shopId (vì Firestore không hỗ trợ multiple where với isNotEqualTo tốt)
          if (shopId != null && data['shopId'] != shopId) continue;

          String title = data['title'] ?? "THÔNG BÁO SHOP";
          String body = data['body'] ?? "";
          
          _showLocalNotification(title, body);
          onMessageReceived(title, body);
          
          doc.reference.update({
            'readBy': FieldValue.arrayUnion([user.uid])
          });
        }
      }, onError: (e) => debugPrint("Lỗi lắng nghe thông báo: $e"));
  }

  /// Lắng nghe tin nhắn chat mới trong phòng chat chung
  static Future<void> listenToChatMessages(Function(String, String) onMessageReceived) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final bool isSuperAdmin = UserService.isCurrentUserSuperAdmin();
    final String? shopId = isSuperAdmin ? null : await UserService.getCurrentShopId();

    Query<Map<String, dynamic>> q = _db.collection('chats');
    if (shopId != null) {
      q = q.where('shopId', isEqualTo: shopId);
    }

    q.orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        if (data['senderId'] == user.uid) continue; 

        final sender = (data['senderName'] ?? 'Nhân viên').toString();
        final msg = (data['message'] ?? '').toString();
        final title = "Chat mới từ $sender";

        _showLocalNotification(title, msg);
        onMessageReceived(title, msg);
      }
    }, onError: (e) => debugPrint("Lỗi lắng nghe chat: $e"));
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
