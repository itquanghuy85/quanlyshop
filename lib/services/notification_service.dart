import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
  static final _db = FirebaseFirestore.instance;
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final DateTime _appStartTime = DateTime.now().subtract(const Duration(minutes: 1));

  // Rate limiting: max 3 notifications per 10 seconds
  static final List<DateTime> _recentNotifications = [];
  static const int _maxNotificationsPerPeriod = 3;
  static const Duration _rateLimitPeriod = Duration(seconds: 10);

  // Notification settings keys
  static const String _newOrderKey = 'notification_new_order';
  static const String _paymentKey = 'notification_payment';
  static const String _inventoryKey = 'notification_inventory';
  static const String _staffKey = 'notification_staff';
  static const String _systemKey = 'notification_system';

  // Handle background messages
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Handling background message: ${message.messageId}');
    await _showLocalNotification(
      message.notification?.title ?? 'Thông báo mới',
      message.notification?.body ?? '',
      channelId: _getChannelId(message.data['type']),
      payload: message.data.toString(),
    );
  }

  static Future<void> init() async {
    // Request permissions
    await _requestPermissions();

    // Initialize local notifications
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels
    await _createNotificationChannels();

    // Initialize FCM
    await _initFirebaseMessaging();
  }

  static Future<void> _requestPermissions() async {
    // Request notification permission
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // Request FCM permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');
  }

  static Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel newOrderChannel = AndroidNotificationChannel(
      'new_order_channel',
      'Đơn hàng mới',
      description: 'Thông báo khi có đơn hàng mới',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    const AndroidNotificationChannel paymentChannel = AndroidNotificationChannel(
      'payment_channel',
      'Thanh toán',
      description: 'Thông báo về thanh toán',
      importance: Importance.high,
      playSound: true,
    );

    const AndroidNotificationChannel inventoryChannel = AndroidNotificationChannel(
      'inventory_channel',
      'Kho hàng',
      description: 'Thông báo về tình trạng kho',
      importance: Importance.defaultImportance,
      playSound: false,
    );

    const AndroidNotificationChannel staffChannel = AndroidNotificationChannel(
      'staff_channel',
      'Nhân viên',
      description: 'Thông báo về nhân viên',
      importance: Importance.defaultImportance,
      playSound: false,
    );

    const AndroidNotificationChannel systemChannel = AndroidNotificationChannel(
      'system_channel',
      'Hệ thống',
      description: 'Thông báo hệ thống',
      importance: Importance.low,
      playSound: false,
    );

    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(newOrderChannel);
    await androidPlugin?.createNotificationChannel(paymentChannel);
    await androidPlugin?.createNotificationChannel(inventoryChannel);
    await androidPlugin?.createNotificationChannel(staffChannel);
    await androidPlugin?.createNotificationChannel(systemChannel);
  }

  static Future<void> _initFirebaseMessaging() async {
    // Set background message handler (defined in main.dart)
    // FirebaseMessaging.onBackgroundMessage is already set up in main.dart

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Subscribe to staff topic for business notifications
    await _firebaseMessaging.subscribeToTopic('staff');

    // Get FCM token
    String? token = await _firebaseMessaging.getToken();
    debugPrint('FCM Token: $token');

    // Save token to user profile
    if (token != null) {
      await _saveFCMToken(token);
    }

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveFCMToken);
  }

  static Future<void> refreshFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveFCMToken(token);
        debugPrint('FCM token refreshed: $token');
      }
    } catch (e) {
      debugPrint('Error refreshing FCM token: $e');
    }
  }

  static Future<void> _saveFCMToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _db.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message received: ${message.notification?.title}');

    // Show in-app snackbar notification
    final title = message.notification?.title ?? 'Thông báo mới';
    final body = message.notification?.body ?? '';
    showSnackBar('$title: $body', color: Colors.blueAccent);

    // Check if notifications are enabled for this type
    _shouldShowNotification(message.data['type']).then((shouldShow) {
      if (shouldShow) {
        _showLocalNotification(
          title,
          body,
          channelId: _getChannelId(message.data['type']),
          payload: message.data.toString(),
        );
      }
    });
  }

  static void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Message opened app: ${message.notification?.title}');
    // Handle navigation based on message type
    _handleNotificationNavigation(message.data);
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    if (response.payload != null) {
      // Parse payload and navigate
      final data = _parsePayload(response.payload!);
      _handleNotificationNavigation(data);
    }
  }

  static Map<String, dynamic> _parsePayload(String payload) {
    try {
      // Simple parsing - in production, use proper JSON parsing
      final Map<String, dynamic> data = {};
      final pairs = payload.replaceAll('{', '').replaceAll('}', '').split(', ');
      for (final pair in pairs) {
        final keyValue = pair.split(': ');
        if (keyValue.length == 2) {
          data[keyValue[0]] = keyValue[1];
        }
      }
      return data;
    } catch (e) {
      return {};
    }
  }

  static void _handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type'];
    final id = data['id'];

    // Navigate based on notification type
    switch (type) {
      case 'new_order':
        // Navigate to order details
        debugPrint('Navigate to order: $id');
        break;
      case 'payment':
        // Navigate to payment details
        debugPrint('Navigate to payment: $id');
        break;
      case 'inventory':
        // Navigate to inventory
        debugPrint('Navigate to inventory');
        break;
      default:
        debugPrint('Unknown notification type: $type');
    }
  }

  static String _getChannelId(String? type) {
    switch (type) {
      case 'new_order':
        return 'new_order_channel';
      case 'payment':
        return 'payment_channel';
      case 'inventory':
        return 'inventory_channel';
      case 'staff':
        return 'staff_channel';
      case 'system':
        return 'system_channel';
      default:
        return 'system_channel';
    }
  }

  // MẠCH LẮNG NGHE GIA CỐ (KHÓA CHẶT SHOP ID)
  static void listenToNotifications(Function(String, String) onMessageReceived) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Lắng nghe thay đổi ShopId liên tục để đảm bảo không mất kết nối
    UserService.getCurrentShopId().then((shopId) {
      if (shopId == null) return;

      _db.collection('shop_notifications')
        .where('shopId', isEqualTo: shopId)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(_appStartTime))
        .snapshots().listen((snapshot) {
          debugPrint('Received ${snapshot.docChanges.length} notification changes');
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;
              debugPrint('New notification: ${data['title']} from ${data['senderId']} (current user: ${user.uid})');
              // Hiển thị thông báo nếu không phải do chính mình gửi, HOẶC là thông báo hệ thống test
              if (data['senderId'] != user.uid || data['type'] == 'system') {
                String title = data['title'] ?? "THÔNG BÁO MỚI";
                String body = data['body'] ?? "";
                String type = data['type'] ?? 'system';

                // Check if notification should be shown
                _shouldShowNotification(type).then((shouldShow) {
                  debugPrint('Should show notification for type $type: $shouldShow');
                  if (shouldShow) {
                    _showLocalNotification(title, body, channelId: _getChannelId(type));
                    onMessageReceived(title, body);
                  }
                });
              } else {
                debugPrint('Skipping notification from self');
              }
            }
          }
        }, onError: (e) => debugPrint("LỖI MẠCH THÔNG BÁO: $e"));
    });
  }

  static Future<void> sendCloudNotification({
    required String title,
    required String body,
    required String type,
    String? targetUserId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null) return;

      final notificationData = {
        'shopId': shopId,
        'title': title,
        'body': body,
        'type': type,
        'senderId': user?.uid,
        'senderName': user?.email?.split('@').first.toUpperCase() ?? "NV",
        'createdAt': FieldValue.serverTimestamp(),
        'targetUserId': targetUserId, // null = broadcast to all shop users
      };

      debugPrint('Creating shop notification: $notificationData');
      await _db.collection('shop_notifications').add(notificationData);
      debugPrint('Shop notification created successfully');

      // Send FCM push notification
      await _sendFCMNotification(notificationData);
    } catch (e) {
      debugPrint("LỖI GỬI: $e");
    }
  }

  static Future<void> _sendFCMNotification(Map<String, dynamic> notificationData) async {
    try {
      debugPrint('Sending FCM notification: ${notificationData['title']}');
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1').httpsCallable('sendShopNotification');
      
      // Get current shopId
      final shopId = await UserService.getCurrentShopId();
      
      final result = await callable.call({
        'title': notificationData['title'],
        'body': notificationData['body'],
        'type': notificationData['type'],
        'targetUserId': notificationData['targetUserId'],
        'shopId': shopId,
      });

      final data = result.data as Map<String, dynamic>;
      debugPrint('FCM sent successfully: ${data['sentCount']} success, ${data['failedCount']} failed');
    } catch (e) {
      debugPrint('Error sending FCM via Cloud Function: $e');
      // Fallback: try to send local notification if FCM fails
      _showLocalNotification(
        notificationData['title'],
        notificationData['body'],
        channelId: _getChannelId(notificationData['type']),
      );
    }
  }

  static Future<void> _showLocalNotification(
    String title,
    String body, {
    String channelId = 'system_channel',
    String? payload,
  }) async {
    final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId, _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: _getChannelImportance(channelId),
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      playSound: _shouldPlaySound(channelId),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  static String _getChannelName(String channelId) {
    switch (channelId) {
      case 'new_order_channel':
        return 'Đơn hàng mới';
      case 'payment_channel':
        return 'Thanh toán';
      case 'inventory_channel':
        return 'Kho hàng';
      case 'staff_channel':
        return 'Nhân viên';
      case 'system_channel':
        return 'Hệ thống';
      default:
        return 'Thông báo';
    }
  }

  static String _getChannelDescription(String channelId) {
    switch (channelId) {
      case 'new_order_channel':
        return 'Thông báo khi có đơn hàng mới';
      case 'payment_channel':
        return 'Thông báo về thanh toán';
      case 'inventory_channel':
        return 'Thông báo về tình trạng kho';
      case 'staff_channel':
        return 'Thông báo về nhân viên';
      case 'system_channel':
        return 'Thông báo hệ thống';
      default:
        return 'Thông báo từ ứng dụng';
    }
  }

  static Importance _getChannelImportance(String channelId) {
    switch (channelId) {
      case 'new_order_channel':
      case 'payment_channel':
        return Importance.high;
      case 'inventory_channel':
      case 'staff_channel':
        return Importance.defaultImportance;
      case 'system_channel':
        return Importance.low;
      default:
        return Importance.defaultImportance;
    }
  }

  static bool _shouldPlaySound(String channelId) {
    return channelId == 'new_order_channel' || channelId == 'payment_channel';
  }

  // Notification Settings Management
  static Future<bool> _shouldShowNotification(String? type) async {
    if (type == null) return true;

    // Check rate limiting
    if (!_isWithinRateLimit()) {
      debugPrint('Notification rate limited: $type');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _getNotificationSettingKey(type);
    return prefs.getBool(key) ?? _getDefaultNotificationSetting(type);
  }

  static bool _isWithinRateLimit() {
    final now = DateTime.now();
    
    // Remove old notifications outside the rate limit period
    _recentNotifications.removeWhere((time) => now.difference(time) > _rateLimitPeriod);
    
    // Check if we're within the limit
    if (_recentNotifications.length >= _maxNotificationsPerPeriod) {
      return false;
    }
    
    // Add current notification to the list
    _recentNotifications.add(now);
    return true;
  }

  static Future<void> setNotificationEnabled(String type, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getNotificationSettingKey(type);
    await prefs.setBool(key, enabled);
  }

  static Future<bool> getNotificationEnabled(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getNotificationSettingKey(type);
    return prefs.getBool(key) ?? _getDefaultNotificationSetting(type);
  }

  static String _getNotificationSettingKey(String type) {
    switch (type) {
      case 'new_order':
        return _newOrderKey;
      case 'payment':
        return _paymentKey;
      case 'inventory':
        return _inventoryKey;
      case 'staff':
        return _staffKey;
      case 'system':
        return _systemKey;
      default:
        return _systemKey;
    }
  }

  static bool _getDefaultNotificationSetting(String type) {
    // Critical notifications are enabled by default
    return type == 'new_order' || type == 'payment' || type == 'system';
  }

  // Critical Business Events
  static Future<void> sendNewOrderNotification(String orderId, String customerName, double amount) async {
    final title = 'ĐƠN HÀNG MỚI';
    final body = 'Khách hàng $customerName - ${amount.toStringAsFixed(0)}đ';
    await sendCloudNotification(
      title: title,
      body: body,
      type: 'new_order',
    );
  }

  static Future<void> sendPaymentNotification(String orderId, double amount, String paymentMethod) async {
    final title = 'THANH TOÁN THÀNH CÔNG';
    final body = '${amount.toStringAsFixed(0)}đ qua $paymentMethod';
    await sendCloudNotification(
      title: title,
      body: body,
      type: 'payment',
    );
  }

  static Future<void> sendLowInventoryNotification(String productName, int currentStock) async {
    final title = 'CẢNH BÁO KHO';
    final body = '$productName chỉ còn $currentStock sản phẩm';
    await sendCloudNotification(
      title: title,
      body: body,
      type: 'inventory',
    );
  }

  static Future<void> sendStaffNotification(String message, {String? targetUserId}) async {
    final title = 'THÔNG BÁO NHÂN VIÊN';
    await sendCloudNotification(
      title: title,
      body: message,
      type: 'staff',
      targetUserId: targetUserId,
    );
  }

  static Future<void> sendSystemNotification(String message) async {
    final title = 'THÔNG BÁO HỆ THỐNG';
    await sendCloudNotification(
      title: title,
      body: message,
      type: 'system',
    );
  }

  static void showSnackBar(String message, {Color color = Colors.blueAccent}) {
    messengerKey.currentState?.hideCurrentSnackBar();
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
