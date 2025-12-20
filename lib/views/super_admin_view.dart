import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';

class SuperAdminView extends StatelessWidget {
  const SuperAdminView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text(
          'SUPER ADMIN CONTROL',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: UserService.getAllShopsStreamForSuperAdmin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có shop nào được tạo',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final shops = snapshot.data!.docs;
          return ListView(
            padding: const EdgeInsets.all(15),
            children: [
              _buildIntroCard(context),
              const SizedBox(height: 12),
              ...shops.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final shopId = doc.id;
                final ownerEmail = data['ownerEmail'] ?? 'Không rõ email chủ shop';
                final ownerUid = data['ownerUid'] ?? 'Không rõ UID chủ shop';
                final createdAt = data['createdAt'];
                final appLocked = data['appLocked'] == true;
                final adminFinanceLocked = data['adminFinanceLocked'] == true;

                String createdText = 'Chưa rõ ngày tạo';
                if (createdAt is Timestamp) {
                  createdText = 'Tạo: ${createdAt.toDate().toString().substring(0, 16)}';
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.store_mall_directory, color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Shop ID: $shopId',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Chủ shop: $ownerEmail', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('Owner UID: $ownerUid', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(createdText, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const Divider(height: 20),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('KHÓA TOÀN BỘ APP CỦA SHOP NÀY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          subtitle: const Text(
                            'Khi bật, mọi tài khoản thuộc shop này sẽ không truy cập được bất kỳ chức năng nào.',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          value: appLocked,
                          onChanged: (v) async {
                            await UserService.updateShopControlFlags(shopId: shopId, appLocked: v);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(v ? 'ĐÃ KHÓA toàn bộ app cho shop $shopId' : 'ĐÃ MỞ KHÓA app cho shop $shopId')),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('KHÓA CHỨC NĂNG TÀI CHÍNH CỦA QUẢN LÝ SHOP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          subtitle: const Text(
                            'Khi bật, tài khoản QUẢN LÝ của shop không xem được Doanh thu, Chi phí và Sổ công nợ.',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          value: adminFinanceLocked,
                          onChanged: (v) async {
                            await UserService.updateShopControlFlags(shopId: shopId, adminFinanceLocked: v);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(v ? 'ĐÃ KHÓA tài chính của quản lý shop $shopId' : 'ĐÃ MỞ lại tài chính cho quản lý shop $shopId')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blueAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Giới thiệu ứng dụng',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Ứng dụng quản lý sửa chữa điện thoại HULUCA giúp cửa hàng theo dõi đơn sửa chữa, khách hàng, thu chi và tồn kho một cách đơn giản, có hỗ trợ làm việc cả khi offline và đồng bộ dữ liệu với Firebase.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            SizedBox(height: 8),
            Text(
              'Ứng dụng được xây dựng và vận hành bởi HULUCA (admin@huluca.com) với mục tiêu hỗ trợ các cửa hàng sửa chữa điện thoại vừa và nhỏ quản lý công việc hiệu quả, minh bạch và chuyên nghiệp hơn.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
