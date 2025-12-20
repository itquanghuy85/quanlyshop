import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../services/user_service.dart';
import '../services/audit_service.dart';

class AttendanceView extends StatefulWidget {
  const AttendanceView({super.key});

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  final db = DBHelper();
  bool _loading = true;
  Map<String, dynamic>? _today;
  bool _overtime = false;
    String _role = 'user';
    bool _monthLocked = false;
  final noteCtrl = TextEditingController();
  File? _photoIn;
  File? _photoOut;

  String get _dateKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadRole();
    _load();
    _refreshLockState();
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final rec = await db.getAttendance(_dateKey, uid);
    setState(() {
      _today = rec;
      _overtime = (rec?['overtimeOn'] ?? 0) == 1;
      noteCtrl.text = rec?['note'] ?? '';
      _loading = false;
    });
  }

  Future<void> _loadRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final r = await UserService.getUserRole(uid);
    if (mounted) setState(() => _role = r);
  }

  Future<void> _refreshLockState() async {
    final locked = await db.isPayrollMonthLocked(DateFormat('yyyy-MM').format(DateTime.now()));
    if (mounted) setState(() => _monthLocked = locked);
  }

  Future<void> _pickPhoto(bool isIn) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked != null) {
      setState(() {
        if (isIn) _photoIn = File(picked.path); else _photoOut = File(picked.path);
      });
    }
  }

  Future<void> _checkIn() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if ((_today?['locked'] ?? 0) == 1 || (_today?['status'] == 'approved')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Công đã khóa/duyệt, không thể sửa')));
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = {
      'userId': user.uid,
      'email': user.email,
      'name': user.email?.split('@').first.toUpperCase(),
      'dateKey': _dateKey,
      'checkInAt': now,
      'checkOutAt': _today?['checkOutAt'],
      'overtimeOn': _overtime ? 1 : 0,
      'photoIn': _photoIn?.path ?? _today?['photoIn'],
      'photoOut': _today?['photoOut'],
      'note': noteCtrl.text,
      'status': 'pending',
      'createdAt': now,
    };
    await db.upsertAttendance(data);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ĐÃ CHECK-IN')));
    _load();
  }

  Future<void> _checkOut() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if ((_today?['locked'] ?? 0) == 1 || (_today?['status'] == 'approved')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Công đã khóa/duyệt, không thể sửa')));
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = {
      'userId': user.uid,
      'email': user.email,
      'name': user.email?.split('@').first.toUpperCase(),
      'dateKey': _dateKey,
      'checkInAt': _today?['checkInAt'],
      'checkOutAt': now,
      'overtimeOn': _overtime ? 1 : 0,
      'photoIn': _today?['photoIn'],
      'photoOut': _photoOut?.path ?? _today?['photoOut'],
      'note': noteCtrl.text,
      'status': 'pending',
      'createdAt': _today?['createdAt'] ?? now,
    };
    await db.upsertAttendance(data);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ĐÃ CHECK-OUT')));
    _load();
  }

  String _fmt(int? ms) => ms == null ? '--:--' : DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ms));

  bool get _isManager => _role == 'admin';
  bool get _isLocked => (_today?['locked'] ?? 0) == 1;
  String get _status => (_today?['status'] as String?) ?? 'pending';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CHẤM CÔNG')), 
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    title: const Text('Hôm nay'),
                    subtitle: Text(_dateKey),
                    trailing: Switch(
                      value: _overtime,
                      onChanged: _isLocked || _status == 'approved' ? null : (v) => setState(() => _overtime = v),
                      activeColor: Colors.orange,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(label: Text('Trạng thái: ${_status.toUpperCase()}'), backgroundColor: _status == 'approved' ? Colors.green.shade100 : (_status == 'rejected' ? Colors.red.shade100 : Colors.orange.shade100)),
                      if (_isLocked) const Chip(label: Text('ĐÃ KHÓA'), backgroundColor: Colors.grey),
                      if (_today?['approvedBy'] != null) Chip(label: Text('Duyệt: ${_today?['approvedBy']}'), backgroundColor: Colors.blue.shade50),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.login, color: Colors.green),
                    title: Text('Check-in: ${_fmt(_today?['checkInAt'] as int?)}'),
                    subtitle: Text(_today?['photoIn'] ?? 'Chưa chụp ảnh'),
                    trailing: ElevatedButton(onPressed: _isLocked || _status == 'approved' ? null : _checkIn, child: const Text('CHECK-IN')),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: Text('Check-out: ${_fmt(_today?['checkOutAt'] as int?)}'),
                    subtitle: Text(_today?['photoOut'] ?? 'Chưa chụp ảnh'),
                    trailing: ElevatedButton(onPressed: _isLocked || _status == 'approved' ? null : _checkOut, child: const Text('CHECK-OUT')),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLocked || _status == 'approved' ? null : () => _pickPhoto(true),
                        icon: const Icon(Icons.camera_alt),
                        label: Text(_photoIn == null ? 'Chụp ảnh check-in' : 'Đã chọn ảnh in'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLocked || _status == 'approved' ? null : () => _pickPhoto(false),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(_photoOut == null ? 'Chụp ảnh check-out' : 'Đã chọn ảnh out'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  enabled: !_isLocked && _status != 'approved',
                  decoration: const InputDecoration(labelText: 'Ghi chú', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text('7 ngày gần nhất', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: db.getAttendanceRange(DateTime.now().subtract(const Duration(days: 7)), DateTime.now()),
                  builder: (ctx, snap) {
                    if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
                    final list = snap.data!;
                    if (list.isEmpty) {
                      return const Padding(padding: EdgeInsets.all(12), child: Text('Chưa có dữ liệu'));
                    }
                    return Column(
                      children: list.map((e) => ListTile(
                        leading: const Icon(Icons.calendar_today, size: 18),
                        title: Text(e['dateKey'] ?? ''),
                        subtitle: Text('In: ${_fmt(e['checkInAt'] as int?)} • Out: ${_fmt(e['checkOutAt'] as int?)} • OT: ${((e['overtimeOn'] ?? 0) == 1) ? 'Có' : 'Không'}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text((e['status'] ?? 'pending').toString().toUpperCase(), style: const TextStyle(fontSize: 12)),
                            if ((e['locked'] ?? 0) == 1) const Text('KHÓA', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      )).toList(),
                    );
                  },
                ),
                if (_isManager) ...[
                  const Divider(height: 30),
                  _managerTools(),
                ],
              ],
            ),
    );
  }

  Widget _managerTools() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: db.getPendingAttendance(daysBack: 21),
      builder: (ctx, snap) {
        final pending = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('QUẢN LÝ DUYỆT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                TextButton.icon(
                  onPressed: _toggleLock,
                  icon: Icon(_monthLocked ? Icons.lock_open : Icons.lock, color: _monthLocked ? Colors.orange : Colors.blueGrey),
                  label: Text(_monthLocked ? 'MỞ KHÓA THÁNG' : 'KHÓA SỔ THÁNG'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (pending.isEmpty)
              const Text('Không có công chờ duyệt', style: TextStyle(color: Colors.grey))
            else
              ...pending.map((e) {
                return Card(
                  child: ListTile(
                    title: Text('${e['name'] ?? ''} • ${e['dateKey'] ?? ''}'),
                    subtitle: Text('In: ${_fmt(e['checkInAt'] as int?)} • Out: ${_fmt(e['checkOutAt'] as int?)} • OT: ${((e['overtimeOn'] ?? 0) == 1) ? 'Có' : 'Không'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(onPressed: () => _approve(e), icon: const Icon(Icons.check_circle, color: Colors.green)),
                        IconButton(onPressed: () => _reject(e), icon: const Icon(Icons.cancel, color: Colors.red)),
                      ],
                    ),
                  ),
                );
              }).toList(),
          ],
        );
      },
    );
  }

  Future<void> _approve(Map<String, dynamic> e) async {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'manager';
    await db.approveAttendance(e['id'] as int, approver: email);
    AuditService.logAction(action: 'ATTENDANCE_APPROVE', entityType: 'attendance', entityId: '${e['userId']}_${e['dateKey']}', summary: 'Approve ${e['name']} ${e['dateKey']}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã duyệt')));
    _load();
    setState(() {});
  }

  Future<void> _reject(Map<String, dynamic> e) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lý do từ chối'),
        content: TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Ghi lý do')), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('HỦY')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('TỪ CHỐI')),
        ],
      ),
    );
    if (ok == true) {
      final email = FirebaseAuth.instance.currentUser?.email ?? 'manager';
      await db.rejectAttendance(e['id'] as int, approver: email, reason: reasonCtrl.text);
      AuditService.logAction(action: 'ATTENDANCE_REJECT', entityType: 'attendance', entityId: '${e['userId']}_${e['dateKey']}', summary: 'Reject ${e['name']} ${e['dateKey']}', payload: {'reason': reasonCtrl.text});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã từ chối')));
      _load();
      setState(() {});
    }
  }

  Future<void> _toggleLock() async {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'manager';
    final newLock = !_monthLocked;
    await db.setPayrollMonthLock(DateFormat('yyyy-MM').format(DateTime.now()), locked: newLock, lockedBy: email, note: 'manual');
    await AuditService.logAction(
      action: newLock ? 'PAYROLL_LOCK' : 'PAYROLL_UNLOCK',
      entityType: 'payroll_month',
      entityId: DateFormat('yyyy-MM').format(DateTime.now()),
      summary: newLock ? 'Khóa sổ chấm công' : 'Mở khóa sổ chấm công',
    );
    await _refreshLockState();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newLock ? 'Đã khóa sổ tháng' : 'Đã mở khóa tháng')));
  }
}
