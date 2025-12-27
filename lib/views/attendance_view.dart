import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/attendance_model.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class AttendanceView extends StatefulWidget {
  const AttendanceView({super.key});
  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> with TickerProviderStateMixin {
  final db = DBHelper();
  bool _loading = true;
  Attendance? _today;
  String _role = 'employee'; 
  late TabController _tabController;

  Map<String, dynamic> _workSchedule = {};
  List<Attendance> _history = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    // Lấy vai trò thực tế để phân quyền giao diện
    final r = await UserService.getUserRole(uid);
    
    // PHÂN QUYỀN TAB: Nhân viên thường chỉ thấy 2 tab, Quản lý thấy 3 tab
    int tabCount = (r == 'owner' || r == 'manager') ? 3 : 2;
    _tabController = TabController(length: tabCount, vsync: this);

    if (!mounted) return;
    setState(() { _role = r; });
    _refreshAttendanceData();
  }

  Future<void> _refreshAttendanceData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _loading = true);
    final rec = await db.getAttendance(DateFormat('yyyy-MM-dd').format(DateTime.now()), uid);
    final schedule = await db.getWorkSchedule(uid);
    final history = await db.getAttendanceByUser(uid);

    if (!mounted) return;
    setState(() {
      _today = rec;
      _workSchedule = schedule ?? {};
      _history = history;
      _loading = false;
    });
  }

  Future<void> _actionCheck(bool isIn) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 30);
    if (picked == null) return;

    setState(() => _loading = true);
    HapticFeedback.mediumImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final cloudUrl = await StorageService.uploadAndGetUrl(picked.path, 'attendance');
      if (cloudUrl == null) {
        NotificationService.showSnackBar("Lỗi mạng! Không thể tải ảnh lên.", color: Colors.red);
        setState(() => _loading = false);
        return;
      }

      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch;
      
      bool isLate = false;
      bool isEarly = false;
      if (isIn && now.hour >= 8 && now.minute > 15) isLate = true;
      if (!isIn && now.hour < 17) isEarly = true;

      final attendance = Attendance(
        userId: user.uid,
        email: user.email!,
        name: user.email?.split('@').first.toUpperCase() ?? 'NV',
        dateKey: DateFormat('yyyy-MM-dd').format(now),
        checkInAt: isIn ? timestamp : _today?.checkInAt,
        checkOutAt: isIn ? null : timestamp,
        photoIn: isIn ? cloudUrl : _today?.photoIn,
        photoOut: isIn ? null : cloudUrl,
        status: 'completed',
        isLate: isLate ? 1 : 0,
        isEarlyLeave: isEarly ? 1 : 0,
        createdAt: _today?.createdAt ?? timestamp,
        updatedAt: timestamp,
        firestoreId: "att_${DateFormat('yyyyMMdd').format(now)}_${user.uid}",
      );

      await db.upsertAttendance(attendance);
      await _refreshAttendanceData();

      NotificationService.showSnackBar(isIn ? "CHECK-IN THÀNH CÔNG!" : "CHECK-OUT THÀNH CÔNG!", color: Colors.green);
    } catch (e) {
      NotificationService.showSnackBar("Lỗi: $e", color: Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("CHẤM CÔNG NHÂN VIÊN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2962FF),
          indicatorColor: const Color(0xFF2962FF),
          tabs: [
            const Tab(text: "HÔM NAY"),
            const Tab(text: "LỊCH SỬ"),
            if (_role == 'owner' || _role == 'manager') const Tab(text: "THỐNG KÊ"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayTab(),
          _buildHistoryTab(),
          if (_role == 'owner' || _role == 'manager') _buildStatsTab(),
        ],
      ),
    );
  }

  Widget _buildTodayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        _buildClockCard(),
        const SizedBox(height: 30),
        Row(children: [
          Expanded(child: _checkBtn("CHECK-IN", Icons.login, Colors.green, () => _actionCheck(true), enabled: _today?.checkInAt == null)),
          const SizedBox(width: 15),
          Expanded(child: _checkBtn("CHECK-OUT", Icons.logout, Colors.red, () => _actionCheck(false), enabled: _today?.checkInAt != null && _today?.checkOutAt == null)),
        ]),
        const SizedBox(height: 30),
        if (_today != null) _buildTodaySummary(),
        if (_role == 'owner' || _role == 'manager') ...[
          const SizedBox(height: 20),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.grey),
            title: const Text("Cài đặt lịch làm việc", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => NotificationService.showSnackBar("Tính năng đang mở rộng cho Chủ shop", color: Colors.blue),
          )
        ],
      ]),
    );
  }

  Widget _buildClockCard() {
    final now = DateTime.now();
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF2962FF)]), borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15)]),
      child: Column(children: [
        Text(DateFormat('HH:mm').format(now), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white)),
        Text(DateFormat('EEEE, dd MMMM', 'vi_VN').format(now).toUpperCase(), style: const TextStyle(color: Colors.white70, letterSpacing: 1.2, fontSize: 12)),
      ]),
    );
  }

  Widget _checkBtn(String label, IconData icon, Color color, VoidCallback onTap, {bool enabled = true}) {
    return ElevatedButton.icon(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey.shade300, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
    );
  }

  Widget _buildTodaySummary() {
    return Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("TRẠNG THÁI HÔM NAY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
        const Divider(height: 30),
        _rowInfo("Giờ vào", _today?.checkInAt != null ? DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(_today!.checkInAt!)) : "--:--", _today?.isLate == 1 ? Colors.red : Colors.green),
        _rowInfo("Giờ ra", _today?.checkOutAt != null ? DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(_today!.checkOutAt!)) : "--:--", _today?.isEarlyLeave == 1 ? Colors.orange : Colors.blue),
      ]),
    );
  }

  Widget _rowInfo(String l, String v, Color c) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey)), Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: c))]));

  Widget _buildHistoryTab() {
    if (_history.isEmpty) return const Center(child: Text("Chưa có dữ liệu lịch sử"));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (ctx, i) {
        final item = _history[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: item.isLate == 1 ? Colors.red.shade50 : Colors.green.shade50, child: Icon(item.isLate == 1 ? Icons.warning : Icons.check, color: item.isLate == 1 ? Colors.red : Colors.green, size: 16)),
            title: Text(item.dateKey, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text("Vào: ${item.checkInAt != null ? DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(item.checkInAt!)) : '--'} | Ra: ${item.checkOutAt != null ? DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(item.checkOutAt!)) : '--'}"),
            trailing: item.photoIn != null ? const Icon(Icons.image, color: Colors.blue, size: 18) : null,
          ),
        );
      },
    );
  }

  Widget _buildStatsTab() {
    int totalDays = _history.length;
    int lateDays = _history.where((h) => h.isLate == 1).length;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        _statCard("TỔNG NGÀY CÔNG", "$totalDays", Colors.blue),
        const SizedBox(height: 15),
        _statCard("SỐ LẦN ĐI MUỘN", "$lateDays", Colors.red),
      ]),
    );
  }

  Widget _statCard(String l, String v, Color c) => Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)), Text(v, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: c))]));
}
