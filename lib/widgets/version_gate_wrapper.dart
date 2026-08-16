import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/notification_service.dart';
import '../utils/app_info.dart';

/// Chặn toàn bộ app nếu build hiện tại thấp hơn "số build tối thiểu bắt
/// buộc" do Super Admin cấu hình (Firestore `app_config/version_gate`).
///
/// NGUYÊN TẮC AN TOÀN BẮT BUỘC: fail-open tuyệt đối — bất kỳ lỗi/timeout
/// nào khi đọc cấu hình (mất mạng, chưa có doc, permission...) đều KHÔNG
/// chặn app. Chỉ chặn khi đọc được cấu hình rõ ràng VÀ xác nhận chắc chắn
/// build hiện tại thấp hơn mức tối thiểu. Tính năng này có thể khoá TOÀN BỘ
/// người dùng thật nếu sai sót, nên tuyệt đối không được chặn nhầm.
class VersionGateWrapper extends StatefulWidget {
  final Widget child;
  const VersionGateWrapper({super.key, required this.child});

  @override
  State<VersionGateWrapper> createState() => _VersionGateWrapperState();
}

class _VersionGateWrapperState extends State<VersionGateWrapper> {
  bool _blocked = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    unawaited(_checkVersion());
  }

  Future<void> _checkVersion() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version_gate')
          .get()
          .timeout(const Duration(seconds: 6));
      if (!doc.exists) return; // Chưa cấu hình → không chặn
      final data = doc.data();
      if (data == null) return;

      final minBuild = Platform.isIOS
          ? ((data['minIosBuild'] as num?)?.toInt() ?? 0)
          : ((data['minAndroidBuild'] as num?)?.toInt() ?? 0);
      if (minBuild <= 0) return; // 0/chưa set = tắt gate cho nền tảng này

      final currentBuildStr = await AppInfo.getBuildNumber();
      final currentBuild = int.tryParse(currentBuildStr) ?? 0;
      if (currentBuild <= 0)
        return; // Không đọc được build hiện tại → không chặn

      if (currentBuild < minBuild) {
        if (!mounted) return;
        setState(() {
          _blocked = true;
          _message = (data['message'] as String?)?.trim();
        });
      }
    } catch (e) {
      debugPrint(
        'VersionGateWrapper: check lỗi (fail-open, KHÔNG chặn app): $e',
      );
    }
  }

  Future<void> _openStore() async {
    final url = Platform.isIOS
        ? NotificationService.iosStoreUrl
        : NotificationService.androidStoreUrl;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('VersionGateWrapper: không mở được store: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_blocked) return widget.child;

    return PopScope(
      canPop: false,
      child: Material(
        color: const Color(0xFF1A237E),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.system_update_rounded,
                  color: Colors.white,
                  size: 72,
                ),
                const SizedBox(height: 24),
                const Text(
                  'CẦN CẬP NHẬT ỨNG DỤNG',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  (_message != null && _message!.isNotEmpty)
                      ? _message!
                      : 'Phiên bản bạn đang dùng đã quá cũ. Vui lòng cập nhật '
                            'lên bản mới nhất để tiếp tục sử dụng.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openStore,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text(
                      'CẬP NHẬT NGAY',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1A237E),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
