import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'views/home_view.dart';
import 'views/login_view.dart';
import 'services/user_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  // Đảm bảo WidgetsFlutterBinding.ensureInitialized, Firebase.init và runApp
  // đều chạy trong cùng một Zone để tránh lỗi Zone mismatch.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('vi_VN');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // KHỞI TẠO HỆ THỐNG THÔNG BÁO
    await NotificationService.init();

    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('ERROR: $error');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quan Ly Shop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFF),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // --- CAO KIẾN: KÍCH HOẠT LẮNG NGHE THÔNG BÁO TOÀN CỤC ---
    NotificationService.listenToNotifications((title, body) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$title: $body"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.blueAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });

    // Thông báo khi có tin nhắn chat mới
    NotificationService.listenToChatMessages((title, body) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$title: $body"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.deepPurple,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    // Đồng bộ thông tin user hiện tại (trường hợp app mở thẳng vào Home
    // mà không đi qua màn Login sau khi cập nhật code).
    final current = FirebaseAuth.instance.currentUser;
    if (current != null && current.email != null) {
      UserService.syncUserInfo(current.uid, current.email!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snap.hasData) return const LoginView();

        return FutureBuilder<String>(
          future: UserService.getUserRole(snap.data!.uid),
          builder: (context, roleSnap) {
            if (!roleSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            return HomeView(role: roleSnap.data!);
          },
        );
      },
    );
  }
}
