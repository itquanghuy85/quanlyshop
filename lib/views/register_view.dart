import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import '../services/user_service.dart';
import '../data/db_helper.dart';

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
  final _inviteCodeC = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _isJoinShop = false; // false: tạo shop mới, true: tham gia shop

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    _nameC.dispose();
    _phoneC.dispose();
    _addressC.dispose();
    _inviteCodeC.dispose();
    super.dispose();
  }

  Future<void> _scanQRCode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Quét mã QR'),
            backgroundColor: Colors.blueAccent,
          ),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),
        ),
      ),
    );

    if (result != null && result is String) {
      try {
        // Parse JSON từ QR code
        final qrData = result;
        if (qrData.contains('invite_code')) {
          // Nếu là QR invite code cũ
          final inviteCode = qrData.split('invite_code:')[1].trim();
          setState(() {
            _inviteCodeC.text = inviteCode;
          });
        } else {
          // Thử parse JSON
          final Map<String, dynamic> data = jsonDecode(qrData);
          if (data['type'] == 'invite_code' && data['code'] != null) {
            setState(() {
              _inviteCodeC.text = data['code'];
            });
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã quét mã mời thành công!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code không hợp lệ')),
        );
      }
    }
  }

  Future<void> _register() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final email = _emailC.text.trim();
    final pass = _passC.text.trim();
    final name = _nameC.text.trim();
    final phone = _phoneC.text.trim();
    final address = _addressC.text.trim();
    final inviteCode = _inviteCodeC.text.trim().toUpperCase();
    // Simple validation
    if (email.isEmpty || pass.isEmpty || name.isEmpty || phone.isEmpty) {
      setState(() {
        _error = 'Vui lòng nhập đầy đủ thông tin bắt buộc';
        _loading = false;
      });
      return;
    }
    if (_isJoinShop && inviteCode.isEmpty) {
      setState(() {
        _error = 'Vui lòng nhập mã mời để tham gia shop';
        _loading = false;
      });
      return;
    }
    // Optional: validate email/phone format
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);
      final uid = cred.user?.uid;
      if (uid != null) {
        // Clear local DB cho user mới
        final db = DBHelper();
        await db.clearAllData();
        if (_isJoinShop) {
          // Tham gia shop
          final success = await UserService.useInviteCode(inviteCode, uid);
          if (!success) {
            setState(() {
              _error = 'Mã mời không hợp lệ hoặc đã hết hạn';
              _loading = false;
            });
            return;
          }
        } else {
          // Tạo shop mới
          await UserService.syncUserInfo(uid, email, extra: {
            'name': name,
            'phone': phone,
            'address': address,
          });
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message ?? 'Lỗi đăng ký';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Đã xảy ra lỗi không xác định';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('TẠO TÀI KHOẢN MỚI', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chọn loại tài khoản:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    title: const Text('Tạo shop mới (Chủ shop)'),
                    subtitle: const Text('Tạo cửa hàng mới và quản lý nhân viên'),
                    value: false,
                    groupValue: _isJoinShop,
                    onChanged: (value) => setState(() => _isJoinShop = value!),
                  ),
                  RadioListTile<bool>(
                    title: const Text('Tham gia shop (Nhân viên)'),
                    subtitle: const Text('Tham gia cửa hàng có sẵn với mã mời'),
                    value: true,
                    groupValue: _isJoinShop,
                    onChanged: (value) => setState(() => _isJoinShop = value!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(_emailC, 'Email đăng nhập', Icons.email_outlined, type: TextInputType.emailAddress),
            const SizedBox(height: 15),
            _buildTextField(_passC, 'Mật khẩu', Icons.lock_outline, obscure: true),
            const SizedBox(height: 15),
            _buildTextField(_nameC, 'Họ và tên', Icons.person_outline),
            const SizedBox(height: 15),
            _buildTextField(_phoneC, 'Số điện thoại', Icons.phone_android_outlined, type: TextInputType.phone),
            const SizedBox(height: 15),
            _buildTextField(_addressC, 'Địa chỉ', Icons.location_on_outlined),
            if (_isJoinShop) ...[
              const SizedBox(height: 15),
              _buildTextField(_inviteCodeC, 'Mã mời tham gia shop', Icons.vpn_key_outlined, hint: 'Nhập mã 8 ký tự hoặc quét QR', hasQRScan: true),
            ],
            const SizedBox(height: 20),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('ĐĂNG KÝ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? type, bool obscure = false, String? hint, bool hasQRScan = false}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      textCapitalization: label.contains('mã') ? TextCapitalization.characters : TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        suffixIcon: hasQRScan
            ? IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: Colors.blueAccent),
                onPressed: _scanQRCode,
                tooltip: 'Quét mã QR',
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
      ),
    );
  }
}
