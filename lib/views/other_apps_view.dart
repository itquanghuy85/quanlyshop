import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/custom_app_bar.dart';

/// Danh sách "Ứng dụng khác của chúng tôi" — quảng bá chéo các app khác
/// cùng nhà phát triển. Dữ liệu quản lý từ Super Admin Console (collection
/// `other_apps`), hiển thị cho toàn bộ người dùng mọi shop.
class OtherAppsView extends StatefulWidget {
  const OtherAppsView({super.key});

  @override
  State<OtherAppsView> createState() => _OtherAppsViewState();
}

class _OtherAppsViewState extends State<OtherAppsView> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('other_apps')
        .where('active', isEqualTo: true)
        .orderBy('order')
        .snapshots();
  }

  Future<void> _openStoreLink(Map<String, dynamic> app) async {
    final androidUrl = (app['androidUrl'] ?? '').toString().trim();
    final iosUrl = (app['iosUrl'] ?? '').toString().trim();
    final url = Platform.isIOS
        ? (iosUrl.isNotEmpty ? iosUrl : androidUrl)
        : (androidUrl.isNotEmpty ? androidUrl : iosUrl);
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ứng dụng này chưa có link tải')),
      );
      return;
    }
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không mở được link: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: CustomAppBar.build(
        title: 'ỨNG DỤNG KHÁC',
        subtitle: 'Các ứng dụng khác của chúng tôi',
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Không tải được danh sách'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final apps = snap.data!.docs;
          if (apps.isEmpty) {
            return Center(
              child: Text(
                'Chưa có ứng dụng nào để giới thiệu',
                style: AppTextStyles.body1.copyWith(color: Colors.grey),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: apps.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final data = apps[i].data();
              final name = (data['name'] ?? '').toString();
              final description = (data['description'] ?? '').toString();
              final iconUrl = (data['iconUrl'] ?? '').toString().trim();
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: iconUrl.isEmpty
                            ? Container(
                                width: 56,
                                height: 56,
                                color: AppColors.primary.withValues(alpha: 0.1),
                                child: Icon(
                                  Icons.apps_rounded,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                              )
                            : Image.network(
                                iconUrl,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 56,
                                  height: 56,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Icon(
                                    Icons.apps_rounded,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AppTextStyles.body1.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                description,
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 34,
                              child: ElevatedButton.icon(
                                onPressed: () => _openStoreLink(data),
                                icon: const Icon(
                                  Icons.download_rounded,
                                  size: 16,
                                ),
                                label: const Text('Tải xuống'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
