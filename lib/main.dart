import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'views/home_view.dart';
import 'views/login_view.dart';
import 'services/user_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
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
    debugPrint('GLOBAL ERROR: $error');
    debugPrint('STACK: $stack');
  });
}


class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quan Ly Shop',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: NotificationService.messengerKey,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFF),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      locale: _locale,
      supportedLocales: const [
        Locale('vi'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AuthGate(setLocale: setLocale),
    );
  }
}

class AuthGate extends StatefulWidget {
  final void Function(Locale)? setLocale;
  AuthGate({Key? key, this.setLocale}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  int _notificationCount = 0;
  
  @override
  void initState() {
    super.initState();
    _initNotificationListener();
    _syncUserOnStart();
  }

  void _initNotificationListener() {
    NotificationService.listenToNotifications((title, body) {
      if (mounted && _notificationCount < 3) {
        _notificationCount++;
        // Sử dụng GlobalKey để show SnackBar an toàn hơn
        NotificationService.showSnackBar(
          "$title: $body",
          color: Colors.blueAccent,
        );
        // Reset count sau 10s
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) _notificationCount = 0;
        });
      }
    });
  }

  void _syncUserOnStart() {
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
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (!snap.hasData) return LoginView(setLocale: widget.setLocale);

        return FutureBuilder<String>(
          // Dùng memoization hoặc kiểm tra uid để tránh gọi lại future vô ích
          future: UserService.getUserRole(snap.data!.uid),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            
            if (roleSnap.hasError || !roleSnap.hasData) {
              // Nếu lỗi role, ép đăng xuất để tránh treo app
              FirebaseAuth.instance.signOut();
              return const LoginView();
            }
            
            return HomeView(role: roleSnap.data!, setLocale: widget.setLocale);
          },
        );
      },
    );
  }
}
