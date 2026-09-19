import 'package:flutter/material.dart';

/// "Kết nối tài khoản" — attaches the offline shop to a Firebase account.
/// Step 4 of PLAN_OFFLINE_FIRST replaces this placeholder with the real flow.
class ClaimAccountView extends StatelessWidget {
  const ClaimAccountView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kết nối tài khoản')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Tính năng kết nối tài khoản sẽ có ở bản cập nhật tới.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
