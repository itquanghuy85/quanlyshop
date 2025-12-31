import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationSettingsView extends StatefulWidget {
  const NotificationSettingsView({super.key});

  @override
  State<NotificationSettingsView> createState() => _NotificationSettingsViewState();
}

class _NotificationSettingsViewState extends State<NotificationSettingsView> {
  bool _newOrderEnabled = true;
  bool _paymentEnabled = true;
  bool _inventoryEnabled = false;
  bool _staffEnabled = false;
  bool _systemEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final newOrder = await NotificationService.getNotificationEnabled('new_order');
    final payment = await NotificationService.getNotificationEnabled('payment');
    final inventory = await NotificationService.getNotificationEnabled('inventory');
    final staff = await NotificationService.getNotificationEnabled('staff');
    final system = await NotificationService.getNotificationEnabled('system');

    if (mounted) {
      setState(() {
        _newOrderEnabled = newOrder;
        _paymentEnabled = payment;
        _inventoryEnabled = inventory;
        _staffEnabled = staff;
        _systemEnabled = system;
      });
    }
  }

  Future<void> _updateSetting(String type, bool value) async {
    await NotificationService.setNotificationEnabled(type, value);
    setState(() {
      switch (type) {
        case 'new_order':
          _newOrderEnabled = value;
          break;
        case 'payment':
          _paymentEnabled = value;
          break;
        case 'inventory':
          _inventoryEnabled = value;
          break;
        case 'staff':
          _staffEnabled = value;
          break;
        case 'system':
          _systemEnabled = value;
          break;
      }
    });

    NotificationService.showSnackBar(
      value ? 'Đã bật thông báo' : 'Đã tắt thông báo',
      color: value ? Colors.green : Colors.orange,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text(
          "CÀI ĐẶT THÔNG BÁO",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('THÔNG BÁO QUAN TRỌNG'),
          _buildNotificationTile(
            'Đơn hàng mới',
            'Thông báo khi có khách hàng tạo đơn hàng mới',
            _newOrderEnabled,
            (value) => _updateSetting('new_order', value),
            Icons.shopping_cart,
            Colors.blue,
          ),
          _buildNotificationTile(
            'Thanh toán',
            'Thông báo khi có thanh toán thành công',
            _paymentEnabled,
            (value) => _updateSetting('payment', value),
            Icons.payment,
            Colors.green,
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('THÔNG BÁO KHÁC'),
          _buildNotificationTile(
            'Kho hàng',
            'Cảnh báo khi sản phẩm sắp hết hàng',
            _inventoryEnabled,
            (value) => _updateSetting('inventory', value),
            Icons.inventory,
            Colors.orange,
          ),
          _buildNotificationTile(
            'Nhân viên',
            'Thông báo về hoạt động của nhân viên',
            _staffEnabled,
            (value) => _updateSetting('staff', value),
            Icons.people,
            Colors.purple,
          ),
          _buildNotificationTile(
            'Hệ thống',
            'Thông báo cập nhật và bảo trì hệ thống',
            _systemEnabled,
            (value) => _updateSetting('system', value),
            Icons.settings,
            Colors.grey,
          ),

          const SizedBox(height: 32),
          _buildRefreshTokenButton(),
          const SizedBox(height: 16),
          _buildTestNotificationButton(),
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNotificationTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: color,
        ),
      ),
    );
  }

  Widget _buildRefreshTokenButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: _refreshFCMToken,
        icon: const Icon(Icons.refresh),
        label: const Text('LÀM MỚI FCM TOKEN'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildTestNotificationButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: _sendTestNotification,
        icon: const Icon(Icons.notifications_active),
        label: const Text('GỬI THÔNG BÁO TEST'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshFCMToken() async {
    try {
      await NotificationService.refreshFCMToken();
      NotificationService.showSnackBar(
        'Đã làm mới FCM token!',
        color: Colors.green,
      );
    } catch (e) {
      NotificationService.showSnackBar(
        'Lỗi làm mới token: $e',
        color: Colors.red,
      );
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      await NotificationService.sendSystemNotification(
        'Đây là thông báo test từ hệ thống push notification. Nếu bạn thấy thông báo này, hệ thống đang hoạt động bình thường!'
      );
      NotificationService.showSnackBar(
        'Đã gửi thông báo test!',
        color: Colors.green,
      );
    } catch (e) {
      NotificationService.showSnackBar(
        'Lỗi gửi thông báo: $e',
        color: Colors.red,
      );
    }
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Lưu ý',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '• Thông báo quan trọng (đơn hàng, thanh toán) luôn được ưu tiên\n'
              '• Bạn có thể bật/tắt từng loại thông báo theo nhu cầu\n'
              '• Thông báo sẽ được gửi ngay cả khi ứng dụng đang đóng\n'
              '• Kiểm tra cài đặt hệ thống để đảm bảo quyền thông báo được bật',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1976D2),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}