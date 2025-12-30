import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';
import '../l10n/app_localizations.dart';
import 'register_view.dart';

class LoginView extends StatefulWidget {
  final void Function(Locale)? setLocale;
  const LoginView({super.key, this.setLocale});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _loading = false;
  bool _rememberMe = false;
  String? _error;
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _loadSavedAccount();
  }

  Future<void> _loadSavedAccount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailC.text = prefs.getString('saved_email') ?? '';
      _passC.text = prefs.getString('saved_pass') ?? '';
      _rememberMe = prefs.getBool('remember_me') ?? false;
    });
  }

  Future<void> _saveAccount() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', _emailC.text.trim());
      await prefs.setString('saved_pass', _passC.text.trim());
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.remove('saved_pass');
      await prefs.setBool('remember_me', false);
    }
  }

  Future<void> _login() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailC.text.trim(),
        password: _passC.text.trim(),
      );
      final u = cred.user;
      if (u != null && u.email != null) {
        await UserService.syncUserInfo(u.uid, u.email!);
      }
      await _saveAccount();
    } on FirebaseAuthException {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.loginError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Locale _selectedLocale = const Locale('vi');
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront_rounded, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 10),
              Text(localizations.shopManagement, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const SizedBox(height: 20),
              // Language switcher
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      localizations.selectLanguage,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 24,
                      width: 1,
                      color: Colors.blue.shade300,
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<Locale>(
                      value: _selectedLocale,
                      underline: const SizedBox(),
                      icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade700),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade700,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: const Locale('vi'),
                          child: Row(
                            children: [
                              const Text('🇻🇳 ', style: TextStyle(fontSize: 16)),
                              Text(localizations.vietnamese),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: const Locale('en'),
                          child: Row(
                            children: [
                              const Text('🇺🇸 ', style: TextStyle(fontSize: 16)),
                              Text(localizations.english),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (locale) {
                        if (locale != null) {
                          setState(() => _selectedLocale = locale);
                          widget.setLocale?.call(locale);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailC,
                decoration: InputDecoration(
                  labelText: localizations.email,
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  helperText: 'Ví dụ: ten@domain.com hoặc ten@gmail.com',
                  helperStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passC,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: localizations.password,
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  ),
                  Text(localizations.rememberMe),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(localizations.signIn.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),              const SizedBox(height: 15),
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterView()));
                  if (result == true) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Đăng ký thành công! Vui lòng đăng nhập.')),
                    );
                  }
                },


                child: const Text('Chưa có tài khoản? Đăng ký ngay', style: TextStyle(color: Colors.blueAccent)),
              ),              const SizedBox(height: 30),
              _buildCalendarCard(),
            ],
          ),
        ),
      ),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta);
    });
  }

  Widget _buildCalendarCard() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday; // Monday = 1, Sunday = 7

    final List<Widget> dayCells = [];

    for (int i = 1; i < startWeekday; i++) {
      dayCells.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final bool isToday =
          date.year == now.year && date.month == now.month && date.day == now.day;

      dayCells.add(Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isToday ? Colors.blueAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              color: isToday ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ));
    }

    while (dayCells.length % 7 != 0) {
      dayCells.add(const SizedBox());
    }

    final List<Row> weekRows = [];
    for (int i = 0; i < dayCells.length; i += 7) {
      weekRows.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: dayCells.sublist(i, i + 7).map((w) {
          return Expanded(child: w);
        }).toList(),
      ));
    }

    final monthYearText = '${_currentMonth.month.toString().padLeft(2, '0')}/${_currentMonth.year}';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF4F8DFF), Color(0xFF6BCBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lịch vạn niên',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hôm nay: ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    Text(
                      monthYearText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Center(
                    child: Text('T2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('T3', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('T4', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('T5', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('T6', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('T7', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('CN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...weekRows,
          ],
        ),
      ),
    );
  }
}
