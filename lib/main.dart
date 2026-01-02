import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
<<<<<<< HEAD
import 'package:firebase_messaging/firebase_messaging.dart';
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'views/home_view.dart';
import 'views/login_view.dart';
import 'views/splash_view.dart'; // Import màn hình Splash mới
import 'views/currency_input_demo.dart'; // Import demo currency input
import 'services/user_service.dart';
import 'services/notification_service.dart';
<<<<<<< HEAD
import 'services/theme_service.dart';
import 'services/connectivity_service.dart';
import 'widgets/offline_indicator.dart';

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Handle background message
  await NotificationService.handleBackgroundMessage(message);
}
=======
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('vi_VN');
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
<<<<<<< HEAD

      // Set up Firebase Messaging background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
      rethrow;
    }
    try {
      await NotificationService.init();
    } catch (e) {
      debugPrint('NotificationService initialization failed: $e');
      // Continue, as notifications are not critical for launch
    }
    try {
      await ConnectivityService.instance.initialize();
    } catch (e) {
      debugPrint('ConnectivityService initialization failed: $e');
      // Continue, as connectivity monitoring is not critical for launch
    }
    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('GLOBAL ERROR: $error');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;
<<<<<<< HEAD
  final ThemeService _themeService = ThemeService();
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6

  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
<<<<<<< HEAD
    _themeService.init();
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('app_language');
    final supportedCodes = ['vi', 'en'];
    final code = supportedCodes.contains(languageCode) ? languageCode : 'vi';
    setState(() {
      _locale = Locale(code!);
    });
  }

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
    SharedPreferences.getInstance().then((p) => p.setString('app_language', locale.languageCode));
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    return AnimatedBuilder(
      animation: _themeService,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: OfflineIndicator(
            child: MaterialApp(
              title: 'Quan Ly Shop',
              debugShowCheckedModeBanner: false,
              scaffoldMessengerKey: NotificationService.messengerKey,
              theme: _themeService.getCurrentTheme(context),
              darkTheme: ThemeService.darkTheme,
              themeMode: _themeService.themeMode,
        locale: _locale,
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        localeResolutionCallback: (locale, supportedLocales) {
          for (var supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale?.languageCode) {
              return supportedLocale;
            }
          }
          return supportedLocales.first;
        },
              routes: {
                '/currency-demo': (context) => const CurrencyInputDemo(),
              },
              home: SplashView(setLocale: setLocale),
            ),
          ),
        );
      },
=======
    return MaterialApp(
      title: 'Quan Ly Shop',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: NotificationService.messengerKey,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto', 
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2962FF),
          primary: const Color(0xFF2962FF),
          secondary: const Color(0xFF00B0FF),
          surface: Colors.white,
          background: const Color(0xFFF0F4F8),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF2962FF), width: 1.5)),
          labelStyle: const TextStyle(color: Colors.blueGrey, fontSize: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2962FF),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 4,
            shadowColor: const Color(0xFF2962FF).withAlpha(102),
          ),
        ),
      ),
      locale: _locale,
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        return supportedLocales.first;
      },
      routes: {
        '/currency-demo': (context) => const CurrencyInputDemo(),
      },
      home: SplashView(setLocale: setLocale), // Luôn bắt đầu từ SplashView để khởi tạo mượt mà
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
    );
  }
}

class AuthGate extends StatefulWidget {
  final void Function(Locale)? setLocale;
  const AuthGate({super.key, this.setLocale});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
<<<<<<< HEAD
=======
  bool _isInitializing = false;
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6

  @override
  void initState() {
    super.initState();
    _initNotificationListener();
<<<<<<< HEAD
=======
    _initSyncService();
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  }

  void _initNotificationListener() {
    NotificationService.listenToNotifications((title, body) {
      if (mounted) {
        NotificationService.showSnackBar("$title: $body", color: const Color(0xFF2962FF));
      }
    });
  }

<<<<<<< HEAD
  Future<String> _getRoleAfterSync(String uid, String email) async {
    await UserService.syncUserInfo(uid, email);
    return UserService.getUserRole(uid);
=======
  Future<void> _initSyncService() async {
    if (_isInitializing) return;
    _isInitializing = true;
    try {
      // Khởi tạo sync service khi user đăng nhập
      await SyncService.initRealTimeSync(() {
        if (mounted) setState(() {});
      });
    } finally {
      _isInitializing = false;
    }
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
<<<<<<< HEAD
        if (snap.hasError || !snap.hasData) return LoginView(setLocale: widget.setLocale);

        final uid = snap.data!.uid; // Note: snap.data is guaranteed non-null here due to !snap.hasData check above

        return FutureBuilder<String>(
          future: _getRoleAfterSync(uid, snap.data!.email!).timeout(const Duration(seconds: 15)),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            if (roleSnap.hasError || !roleSnap.hasData) {
              debugPrint('AuthGate: role sync failed: ${roleSnap.error}, using default role');
              return HomeView(role: 'user', setLocale: widget.setLocale); // Use default role instead of logout
=======
        if (!snap.hasData) return LoginView(setLocale: widget.setLocale);

        return FutureBuilder<String>(
          future: UserService.getUserRole(snap.data!.uid),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            if (roleSnap.hasError || !roleSnap.hasData) {
              FirebaseAuth.instance.signOut();
              return LoginView(setLocale: widget.setLocale);
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
            }
            return HomeView(role: roleSnap.data!, setLocale: widget.setLocale);
          },
        );
      },
    );
  }
}
