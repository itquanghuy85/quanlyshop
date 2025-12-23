import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';

class AttendanceView extends StatefulWidget {
  const AttendanceView({super.key});
  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  final db = DBHelper();
  bool _loading = true;
  Map<String, dynamic>? _today;
  File? _photoIn;
  File? _photoOut;
  String _role = 'user';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final r = await UserService.getUserRole(uid);
    final rec = await db.getAttendance(DateFormat('yyyy-MM-dd').format(DateTime.now()), uid);
    if (!mounted) return;
    setState(() { _role = r; _today = rec; _loading = false; });
  }

  Future<void> _actionCheck(bool isIn) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 50);
    if (picked == null) return;

    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser!;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final data = {
      'userId': user.uid,
      'email': user.email,
      'name': user.email?.split('@').first.toUpperCase(),
      'dateKey': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'checkInAt': isIn ? now : _today?['checkInAt'],
      'checkOutAt': isIn ? null : now,
      'photoIn': isIn ? picked.path : _today?['photoIn'],
      'photoOut': isIn ? null : picked.path,
      'status': 'pending',
      'createdAt': _today?['createdAt'] ?? now,
    };

    await db.upsertAttendance(data);
    await _initData();
    NotificationService.showSnackBar(isIn ? "CHÀO BUỔI SÁNG! ĐÃ CHECK-IN" : "VẤT VẢ RỒI! ĐÃ CHECK-OUT", color: Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("HỆ THỐNG CHẤM CÔNG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white, elevation: 0,
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildClockCard(),
            const SizedBox(height: 30),
            _buildActionButtons(),
            const SizedBox(height: 40),
            _buildRecentHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildClockCard() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2962FF), Color(0xFF00B0FF)]),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Text(DateFormat('EEEE, dd MMMM').format(DateTime.now()).toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          StreamBuilder(
            stream: Stream.periodic(const Duration(seconds: 1)),
            builder: (context, snapshot) {
              return Text(DateFormat('HH:mm:ss').format(DateTime.now()), style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 2));
            },
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _timeInfo("BẮT ĐẦU", _today?['checkInAt']),
              Container(width: 1, height: 30, color: Colors.white24),
              _timeInfo("KẾT THÚC", _today?['checkOutAt']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeInfo(String label, int? ms) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      Text(ms == null ? "--:--" : DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ms)), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildActionButtons() {
    bool canCheckIn = _today?['checkInAt'] == null;
    bool canCheckOut = _today?['checkInAt'] != null && _today?['checkOutAt'] == null;

    return Row(
      children: [
        _attendanceButton("CHECK-IN", Icons.login_rounded, Colors.green, canCheckIn, () => _actionCheck(true)),
        const SizedBox(width: 20),
        _attendanceButton("CHECK-OUT", Icons.logout_rounded, Colors.orange, canCheckOut, () => _actionCheck(false)),
      ],
    );
  }

  Widget _attendanceButton(String label, IconData icon, Color color, bool active, VoidCallback onTap) {
    return Expanded(
      child: Opacity(
        opacity: active ? 1 : 0.5,
        child: InkWell(
          onTap: active ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: active ? color.withOpacity(0.5) : Colors.transparent, width: 2)),
            child: Column(children: [Icon(icon, color: color, size: 32), const SizedBox(height: 8), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))]),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("LỊCH SỬ GẦN ĐÂY", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 13)),
        const SizedBox(height: 15),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: db.getAttendanceRange(DateTime.now().subtract(const Duration(days: 5)), DateTime.now()),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            return Column(
              children: snapshot.data!.map((e) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFF0F4F8), child: Icon(Icons.calendar_today, size: 18, color: Colors.blueAccent)),
                  title: Text(e['dateKey'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text("Giờ làm: ${DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(e['checkInAt']))} - ${e['checkOutAt'] != null ? DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(e['checkOutAt'])) : '...' }"),
                  trailing: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: const Text("HỢP LỆ", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold))),
                ),
              )).toList(),
            );
          },
        ),
      ],
    );
  }
}
