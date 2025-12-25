import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'views/home_view.dart';
import 'views/login_view.dart';
import 'views/intro_view.dart'; // Import màn hình giới thiệu mới
import 'services/user_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    await Future.wait([
      initializeDateFormatting('vi_VN', null),
      initializeDateFormatting('en_US', null),
    ]);

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await NotificationService.init();

    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('GLOBAL ERROR: $error');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('app_language');
    if (languageCode != null) {
      setState(() {
        _locale = Locale(languageCode);
      });
    } else {
      _locale = const Locale('vi');
    }
  }

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
    SharedPreferences.getInstance().then((p) => p.setString('app_language', locale.languageCode));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quan Ly Shop',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: NotificationService.messengerKey,
      locale: _locale,
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
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF2962FF), width: 1.5)),
          labelStyle: const TextStyle(color: Colors.blueGrey, fontSize: 14),
        ),
      ),
      supportedLocales: const [
        Locale('vi', ''),
        Locale('en', ''),
      ],
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
      home: RootGate(setLocale: setLocale), // Chuyển sang RootGate để kiểm tra Intro
    );
  }
}

// CỔNG KIỂM TRA LẦN ĐẦU MỞ APP
class RootGate extends StatelessWidget {
  final void Function(Locale)? setLocale;
  const RootGate({Key? key, this.setLocale}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkFirstTime(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        // Nếu là lần đầu tiên -> Hiện Intro | Nếu không -> Sang AuthGate
        if (snapshot.data == true) {
          return IntroView(setLocale: setLocale);
        } else {
          return AuthGate(setLocale: setLocale);
        }
      },
    );
  }

  Future<bool> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_first_time') ?? true;
  }
}

class AuthGate extends StatefulWidget {
  final void Function(Locale)? setLocale;
  const AuthGate({Key? key, this.setLocale}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _initNotificationListener();
  }

  void _initNotificationListener() {
    NotificationService.listenToNotifications((title, body) {
      if (mounted) {
        NotificationService.showSnackBar("$title: $body", color: const Color(0xFF2962FF));
      }
    });
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
          future: UserService.getUserRole(snap.data!.uid),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            
            if (roleSnap.hasError || !roleSnap.hasData) {
              return HomeView(role: 'user', setLocale: widget.setLocale);
            }
            
            return HomeView(role: roleSnap.data!, setLocale: widget.setLocale);
          },
        );
      },
    );
  }
}
