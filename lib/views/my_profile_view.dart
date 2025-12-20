import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';

class MyProfileView extends StatefulWidget {
  const MyProfileView({super.key});

  @override
  State<MyProfileView> createState() => _MyProfileViewState();
}

class _MyProfileViewState extends State<MyProfileView> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  String? _photoPath;
  String _role = 'user';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final info = await UserService.getUserInfo(user.uid);
    setState(() {
      nameCtrl.text = (info['displayName'] ?? '').toString();
      phoneCtrl.text = (info['phone'] ?? '').toString();
      addressCtrl.text = (info['address'] ?? '').toString();
      _photoPath = info['photoUrl'] as String?;
      _role = (info['role'] ?? 'user').toString();
      _loading = false;
    });
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await UserService.updateUserInfo(
        uid: user.uid,
        name: nameCtrl.text,
        phone: phoneCtrl.text,
        address: addressCtrl.text,
        role: _role,
        photoUrl: _photoPath,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ĐÃ LƯU HỒ SƠ CÁ NHÂN')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HỒ SƠ CÁ NHÂN')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: _photoPath != null && File(_photoPath!).existsSync() ? FileImage(File(_photoPath!)) : null,
                        child: _photoPath == null ? const Icon(Icons.person, size: 30) : null,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_role == 'admin' ? 'QUẢN LÝ' : 'NHÂN VIÊN', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  _input(nameCtrl, 'Họ và tên'),
                  _input(phoneCtrl, 'Số điện thoại', keyboard: TextInputType.phone),
                  _input(addressCtrl, 'Địa chỉ'),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('LƯU THAY ĐỔI', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
    );
  }

  Widget _input(TextEditingController c, String label, {TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
