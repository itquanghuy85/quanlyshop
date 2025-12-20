import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _addressC = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    _nameC.dispose();
    _phoneC.dispose();
    _addressC.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _emailC.text.trim();
      final pass = _passC.text.trim();
      final name = _nameC.text.trim();
      final phone = _phoneC.text.trim();
      final address = _addressC.text.trim();

      if (email.isEmpty || pass.isEmpty || name.isEmpty) {
        setState(() => _error = 'Vui lòng nhập đủ Email, Mật khẩu, Họ tên');
        return;
      }

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);
      final uid = cred.user!.uid;

      await UserService.updateUserInfo(
        uid: uid,
        name: name,
        phone: phone,
        address: address,
        role: 'user',
        photoUrl: null,
      );

      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg = 'Không thể tạo tài khoản';
      if (e.code == 'email-already-in-use') msg = 'Email đã được sử dụng';
      if (e.code == 'weak-password') msg = 'Mật khẩu quá yếu (>= 6 ký tự)';
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = 'Lỗi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TẠO TÀI KHOẢN MỚI')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _emailC,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email đăng nhập', prefixIcon: Icon(Icons.email_outlined)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passC,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu', prefixIcon: Icon(Icons.lock_outline)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameC,
              decoration: const InputDecoration(labelText: 'Họ và tên', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneC,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại', prefixIcon: Icon(Icons.phone_android_outlined)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressC,
              decoration: const InputDecoration(labelText: 'Địa chỉ', prefixIcon: Icon(Icons.location_on_outlined)),
            ),
            const SizedBox(height: 15),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('ĐĂNG KÝ', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
