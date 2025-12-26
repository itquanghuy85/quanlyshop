import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/db_helper.dart';
import '../models/attendance_model.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/currency_text_field.dart';

class AttendanceView extends StatefulWidget {
  const AttendanceView({super.key});
  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> with TickerProviderStateMixin {
  final db = DBHelper();
  bool _loading = true;
  Attendance? _today;
  File? _photoIn;
  File? _photoOut;
  String _role = 'user';
  Position? _currentPosition;
  late TabController _tabController;

  // Advanced features
  Map<String, dynamic> _workSchedule = {};
  List<Map<String, dynamic>> _violations = [];
  Map<String, dynamic> _performanceStats = {};
  bool _locationRequired = true;
  double _allowedRadius = 100; // meters

  // Workplace location settings
  double? _workplaceLat;
  double? _workplaceLng;
  String? _workplaceAddress;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _initData();
    _loadSettings();
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final r = await UserService.getUserRole(uid);
    final rec = await db.getAttendance(DateFormat('yyyy-MM-dd').format(DateTime.now()), uid);
    final schedule = await db.getWorkSchedule(uid);
    final violations = await db.getAttendanceViolations(uid, DateTime.now().subtract(const Duration(days: 30)), DateTime.now());
    final stats = await db.getPerformanceStats(uid, DateFormat('yyyy-MM').format(DateTime.now()));

    if (!mounted) return;
    setState(() {
      _role = r;
      _today = rec;
      _workSchedule = schedule ?? {};
      _violations = violations;
      _performanceStats = stats ?? {};
      _loading = false;
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _locationRequired = prefs.getBool('attendance_location_required') ?? true;
      _allowedRadius = prefs.getDouble('attendance_radius') ?? 100;
      _workplaceLat = prefs.getDouble('workplace_lat');
      _workplaceLng = prefs.getDouble('workplace_lng');
      _workplaceAddress = prefs.getString('workplace_address');
    });
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  Future<void> _setWorkplaceLocation() async {
    final position = await _getCurrentPosition();
    if (position == null) {
      NotificationService.showSnackBar("Không thể lấy vị trí hiện tại", color: Colors.red);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('workplace_lat', position.latitude);
    await prefs.setDouble('workplace_lng', position.longitude);
    await prefs.setString('workplace_address', 'Vị trí hiện tại');

    setState(() {
      _workplaceLat = position.latitude;
      _workplaceLng = position.longitude;
      _workplaceAddress = 'Vị trí hiện tại';
    });

    NotificationService.showSnackBar("Đã cài đặt nơi làm việc thành công!", color: Colors.green);
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      return null;
    }
  }

  Future<bool> _validateLocation() async {
    if (!_locationRequired) return true;

    final position = await _getCurrentPosition();
    if (position == null) return false;

    setState(() => _currentPosition = position);

    // Check if within allowed radius of workplace
    if (_workplaceLat == null || _workplaceLng == null) {
      // If no workplace set, allow check-in (for first setup)
      return true;
    }

    final distance = Geolocator.distanceBetween(
      position.latitude, position.longitude,
      _workplaceLat!, _workplaceLng!,
    );

    return distance <= _allowedRadius;
  }

  Future<void> _actionCheck(bool isIn) async {
    // Validate location first
    if (_locationRequired) {
      final locationValid = await _validateLocation();
      if (!locationValid) {
        NotificationService.showSnackBar("Vị trí không hợp lệ! Vui lòng chấm công tại nơi làm việc", color: Colors.red);
        return;
      }
    }

    // Take photo
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 50);
    if (picked == null) return;

    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser;
    
    // Check if user is authenticated
    if (user == null) {
      NotificationService.showSnackBar("Bạn chưa đăng nhập! Vui lòng đăng nhập lại", color: Colors.red);
      setState(() => _loading = false);
      return;
    }
    
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      // Ensure user is authenticated and token is fresh
      await user.getIdToken(true); // Force refresh token
      
      // Upload photo immediately to Firebase Storage
      final photoUrls = await StorageService.uploadMultipleImages(
        [picked.path],
        'attendance/${DateFormat('yyyy-MM-dd').format(DateTime.now())}_${user.uid}_${isIn ? 'in' : 'out'}'
      );

      if (photoUrls.isEmpty) {
        NotificationService.showSnackBar("Không thể upload ảnh! Vui lòng kiểm tra kết nối mạng và thử lại", color: Colors.red);
        setState(() => _loading = false);
        return;
      }

      final photoUrl = photoUrls.first;

      // Check work schedule
      final currentTime = DateTime.now();
      final schedule = _workSchedule;
      bool isLate = false;
      bool isEarlyLeave = false;

      if (schedule.isNotEmpty) {
        final startTime = DateTime.parse('${DateFormat('yyyy-MM-dd').format(currentTime)} ${schedule['startTime'] ?? '08:00'}');
        final endTime = DateTime.parse('${DateFormat('yyyy-MM-dd').format(currentTime)} ${schedule['endTime'] ?? '17:00'}');

        if (isIn && currentTime.isAfter(startTime.add(const Duration(minutes: 15)))) {
          isLate = true;
        }
        if (!isIn && currentTime.isBefore(endTime.subtract(const Duration(minutes: 30)))) {
          isEarlyLeave = true;
        }
      }

      final attendance = Attendance(
        userId: user.uid,
        email: user.email!,
        name: user.email?.split('@').first.toUpperCase() ?? 'Unknown',
        dateKey: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        checkInAt: isIn ? now : _today?.checkInAt,
        checkOutAt: isIn ? null : now,
        photoIn: isIn ? photoUrl : _today?.photoIn,
        photoOut: isIn ? null : photoUrl,
        status: 'pending',
        location: _currentPosition != null ? 
          '${_currentPosition!.latitude},${_currentPosition!.longitude}' : null,
        isLate: isLate ? 1 : 0,
        isEarlyLeave: isEarlyLeave ? 1 : 0,
        workSchedule: schedule.toString(),
        createdAt: _today?.createdAt ?? now,
        updatedAt: now,
        firestoreId: "attendance_${user.uid}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}",
      );

      await db.upsertAttendance(attendance);

      // Log violations
      // TODO: Implement attendance violation logging
      // if (isLate || isEarlyLeave) {
      //   await db.logAttendanceViolation({
      //     'userId': user.uid,
      //     'date': DateFormat('yyyy-MM-dd').format(currentTime),
      //     'type': isLate ? 'late_checkin' : 'early_checkout',
      //     'timestamp': now,
      //     'scheduleTime': isLate ? schedule['startTime'] : schedule['endTime'],
      //     'actualTime': DateFormat('HH:mm').format(currentTime),
      //   });
      // }

      await _initData();

      String message = isIn ? "CHÀO BUỔI SÁNG! ĐÃ CHECK-IN" : "VẤT VẢ RỒI! ĐÃ CHECK-OUT";
      if (isLate) message += " (Đi muộn)";
      if (isEarlyLeave) message += " (Về sớm)";

      NotificationService.showSnackBar(message, color: (isLate || isEarlyLeave) ? Colors.orange : Colors.green);
    } catch (e) {
      debugPrint("Lỗi check-in/out: $e");
      String errorMessage = "Lỗi khi chấm công! ";
      
      // Check for specific Firebase errors
      String errorStr = e.toString().toLowerCase();
      if (errorStr.contains('permission') || errorStr.contains('unauthorized') || errorStr.contains('denied')) {
        errorMessage += "Không có quyền upload ảnh. Vui lòng đăng nhập lại.";
      } else if (errorStr.contains('network') || errorStr.contains('timeout') || errorStr.contains('unavailable')) {
        errorMessage += "Vui lòng kiểm tra kết nối mạng.";
      } else if (errorStr.contains('storage') || errorStr.contains('quota')) {
        errorMessage += "Lỗi lưu trữ. Vui lòng thử lại sau.";
      } else {
        errorMessage += "Vui lòng thử lại.";
      }
      
      NotificationService.showSnackBar(errorMessage, color: Colors.red);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("HỆ THỐNG CHẤM CÔNG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: "Tổng quan"),
            Tab(icon: Icon(Icons.history), text: "Lịch sử"),
            Tab(icon: Icon(Icons.schedule), text: "Lịch làm"),
            Tab(icon: Icon(Icons.analytics), text: "Báo cáo"),
            Tab(icon: Icon(Icons.settings), text: "Cài đặt"),
          ],
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildHistoryTab(),
                _buildScheduleTab(),
                _buildReportsTab(),
                _buildSettingsTab(),
              ],
            ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildClockCard(),
          const SizedBox(height: 30),
          _buildActionButtons(),
          const SizedBox(height: 30),
          if (_today != null) _buildTodayAttendanceCard(),
          const SizedBox(height: 30),
          _buildTodayStats(),
          const SizedBox(height: 30),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      // Filter history by date
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: const Text("Chọn ngày"),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Attendance>>(
            future: db.getAttendanceByDateRange(
              DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 30))),
              DateFormat('yyyy-MM-dd').format(DateTime.now())
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final record = snapshot.data![index];
                  // TODO: Implement _buildHistoryCard for Attendance
                  return Card(
                    child: ListTile(
                      title: Text(record.name),
                      subtitle: Text('Date: ${record.dateKey}'),
                      trailing: Text(record.status),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("LỊCH LÀM VIỆC", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildScheduleCard(),
          const SizedBox(height: 30),
          const Text("CA LÀM VIỆC HÔM NAY", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          _buildTodaySchedule(),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("BÁO CÁO HIỆU SUẤT", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildPerformanceCard(),
          const SizedBox(height: 30),
          const Text("VI PHẠM GẦN ĐÂY", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          _buildViolationsList(),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "CÀI ĐẶT CHẤM CÔNG",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          const SizedBox(height: 24),

          // Workplace Location Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Nơi làm việc",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_workplaceLat != null && _workplaceLng != null) ...[
                    Text("Tọa độ: ${_workplaceLat!.toStringAsFixed(6)}, ${_workplaceLng!.toStringAsFixed(6)}"),
                    Text("Địa chỉ: ${_workplaceAddress ?? 'Chưa có'}"),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _setWorkplaceLocation,
                          icon: const Icon(Icons.location_on),
                          label: const Text("Đặt vị trí hiện tại"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Location Validation Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Kiểm tra vị trí",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text("Yêu cầu kiểm tra vị trí"),
                    subtitle: const Text("Nhân viên phải ở gần nơi làm việc để chấm công"),
                    value: _locationRequired,
                    onChanged: (value) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('attendance_location_required', value);
                      setState(() => _locationRequired = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text("Bán kính cho phép: ${_allowedRadius.toInt()}m"),
                  Slider(
                    value: _allowedRadius,
                    min: 10,
                    max: 1000,
                    divisions: 99,
                    label: "${_allowedRadius.toInt()}m",
                    onChanged: (value) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setDouble('attendance_radius', value);
                      setState(() => _allowedRadius = value);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayStats() {
    final today = DateTime.now();
    final thisMonth = DateTime(today.year, today.month, 1);
    final nextMonth = DateTime(today.year, today.month + 1, 1);

    return FutureBuilder<List<Attendance>>(
      future: db.getAttendanceByDateRange(
        DateFormat('yyyy-MM-dd').format(thisMonth),
        DateFormat('yyyy-MM-dd').format(nextMonth)
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final thisMonthData = snapshot.data!;
        final workedDays = thisMonthData.where((d) => d.checkInAt != null && d.checkOutAt != null).length;
        final lateDays = thisMonthData.where((d) => d.isLate == 1).length;
        final totalHours = thisMonthData.fold<double>(0, (sum, d) {
          final inMs = d.checkInAt;
          final outMs = d.checkOutAt;
          if (inMs != null && outMs != null) {
            return sum + (outMs - inMs) / (1000 * 60 * 60);
          }
          return sum;
        });

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              const Text("THỐNG KÊ THÁNG NÀY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem("Ngày công", "$workedDays", Colors.green),
                  _statItem("Đi muộn", "$lateDays", Colors.orange),
                  _statItem("Tổng giờ", "${totalHours.toStringAsFixed(1)}h", Colors.blue),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("TÁC VỤ NHANH", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 13)),
        const SizedBox(height: 15),
        Row(
          children: [
            _quickActionButton("Xin nghỉ", Icons.sick, Colors.red.shade100, () => _requestLeave()),
            const SizedBox(width: 12),
            _quickActionButton("OT", Icons.access_time, Colors.orange.shade100, () => _requestOvertime()),
            const SizedBox(width: 12),
            _quickActionButton("Báo cáo", Icons.report, Colors.blue.shade100, () => _tabController.animateTo(3)),
          ],
        ),
      ],
    );
  }

  Widget _quickActionButton(String label, IconData icon, Color bgColor, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Icon(icon, color: Colors.black54, size: 20),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> record) {
    final inMs = record['checkInAt'] as int?;
    final outMs = record['checkOutAt'] as int?;
    final hours = (inMs != null && outMs != null && outMs > inMs)
        ? (outMs - inMs) / (1000 * 60 * 60)
        : 0.0;

    final isLate = record['isLate'] == true;
    final isEarlyLeave = record['isEarlyLeave'] == true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isLate || isEarlyLeave ? Colors.orange.shade100 : Colors.green.shade100,
          child: Icon(
            isLate || isEarlyLeave ? Icons.warning : Icons.check_circle,
            color: isLate || isEarlyLeave ? Colors.orange : Colors.green,
            size: 20,
          ),
        ),
        title: Text(record['dateKey'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("In: ${inMs == null ? '--' : DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(inMs))} • Out: ${outMs == null ? '--' : DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(outMs))}"),
            Text("${hours.toStringAsFixed(2)} giờ", style: const TextStyle(color: Colors.blue)),
            if (isLate || isEarlyLeave)
              Text(
                isLate ? "Đi muộn" : "Về sớm",
                style: const TextStyle(color: Colors.orange, fontSize: 12),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.photo, size: 20),
          onPressed: () => _showPhotos(record),
        ),
      ),
    );
  }

  Widget _buildScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: Colors.blue),
              const SizedBox(width: 12),
              const Text("Lịch làm việc hàng ngày", style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _editSchedule(),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _scheduleTime("Bắt đầu", _workSchedule['startTime'] ?? '08:00'),
              Container(width: 1, height: 30, color: Colors.grey.shade300),
              _scheduleTime("Kết thúc", _workSchedule['endTime'] ?? '17:00'),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _scheduleInfo("Giờ nghỉ", "${_workSchedule['breakTime'] ?? '1'}h"),
              _scheduleInfo("Giờ OT tối đa", "${_workSchedule['maxOtHours'] ?? '4'}h"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scheduleTime(String label, String time) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(time, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
      ],
    );
  }

  Widget _scheduleInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildTodaySchedule() {
    final now = DateTime.now();
    final dayOfWeek = now.weekday; // 1 = Monday, 7 = Sunday
    final isWorkDay = _workSchedule['workDays']?.contains(dayOfWeek) ?? true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isWorkDay ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isWorkDay ? Colors.green.shade200 : Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isWorkDay ? Icons.work : Icons.weekend,
                color: isWorkDay ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 12),
              Text(
                isWorkDay ? "Ngày làm việc" : "Ngày nghỉ",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isWorkDay ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
          if (isWorkDay) ...[
            const SizedBox(height: 15),
            Text(
              "Ca làm: ${_workSchedule['startTime'] ?? '08:00'} - ${_workSchedule['endTime'] ?? '17:00'}",
              style: const TextStyle(color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPerformanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Hiệu suất 30 ngày qua", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _performanceMetric("Điểm danh", "${_performanceStats['attendanceRate'] ?? 0}%", Colors.green),
              _performanceMetric("Đúng giờ", "${_performanceStats['punctualityRate'] ?? 0}%", Colors.blue),
              _performanceMetric("Giờ làm", "${_performanceStats['avgHours'] ?? 0}h", Colors.orange),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: (_performanceStats['attendanceRate'] ?? 0) / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          const SizedBox(height: 8),
          const Text("Tỷ lệ điểm danh", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _performanceMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildViolationsList() {
    if (_violations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text("Không có vi phạm nào", style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(
      children: _violations.map((violation) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: const Icon(Icons.warning, color: Colors.orange),
          title: Text(violation['type'] == 'late_checkin' ? 'Đi muộn' : 'Về sớm'),
          subtitle: Text("${violation['date']} - ${violation['actualTime']}"),
          trailing: Text(violation['scheduleTime'] ?? '', style: const TextStyle(color: Colors.grey)),
        ),
      )).toList(),
    );
  }

  void _requestLeave() async {
    final reasonCtrl = TextEditingController();
    final startDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (startDate == null) return;

    final endDate = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: startDate,
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (endDate == null) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xin nghỉ phép'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Từ: ${DateFormat('dd/MM/yyyy').format(startDate)}'),
            Text('Đến: ${DateFormat('dd/MM/yyyy').format(endDate)}'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Lý do'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('HỦY')),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser!;
              // TODO: Implement leave request
              // await db.submitLeaveRequest({
              //   'userId': user.uid,
              //   'startDate': DateFormat('yyyy-MM-dd').format(startDate),
              //   'endDate': DateFormat('yyyy-MM-dd').format(endDate),
              //   'reason': reasonCtrl.text,
              //   'status': 'pending',
              //   'submittedAt': DateTime.now().millisecondsSinceEpoch,
              // });
              Navigator.pop(ctx);
              NotificationService.showSnackBar("Tính năng xin nghỉ đang phát triển", color: Colors.orange);
            },
            child: const Text('GỬI'),
          ),
        ],
      ),
    );
  }

  void _requestOvertime() async {
    final reasonCtrl = TextEditingController();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (date == null) return;

    final hours = await showDialog<double>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Số giờ OT'),
        children: [2, 3, 4, 5, 6, 7, 8].map((h) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, h.toDouble()),
          child: Text('$h giờ'),
        )).toList(),
      ),
    );
    if (hours == null) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng ký OT'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ngày: ${DateFormat('dd/MM/yyyy').format(date)}'),
            Text('Số giờ: $hours'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Lý do'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('HỦY')),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser!;
              // TODO: Implement overtime request
              // await db.submitOvertimeRequest({
              //   'userId': user.uid,
              //   'date': DateFormat('yyyy-MM-dd').format(date),
              //   'hours': hours,
              //   'reason': reasonCtrl.text,
              //   'status': 'pending',
              //   'submittedAt': DateTime.now().millisecondsSinceEpoch,
              // });
              Navigator.pop(ctx);
              NotificationService.showSnackBar("Tính năng OT đang phát triển", color: Colors.orange);
            },
            child: const Text('GỬI'),
          ),
        ],
      ),
    );
  }

  void _editSchedule() async {
    final startTimeCtrl = TextEditingController(text: _workSchedule['startTime'] ?? '08:00');
    final endTimeCtrl = TextEditingController(text: _workSchedule['endTime'] ?? '17:00');
    final breakTimeCtrl = TextEditingController(text: (_workSchedule['breakTime'] ?? 1).toString());
    final maxOtCtrl = TextEditingController(text: (_workSchedule['maxOtHours'] ?? 4).toString());

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chỉnh sửa lịch làm việc'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: startTimeCtrl,
              decoration: const InputDecoration(labelText: 'Giờ bắt đầu (HH:mm)'),
            ),
            TextField(
              controller: endTimeCtrl,
              decoration: const InputDecoration(labelText: 'Giờ kết thúc (HH:mm)'),
            ),
            TextField(
              controller: breakTimeCtrl,
              decoration: const InputDecoration(labelText: 'Giờ nghỉ (giờ)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: maxOtCtrl,
              decoration: const InputDecoration(labelText: 'OT tối đa (giờ/ngày)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('HỦY')),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser!;
              final newSchedule = {
                'userId': user.uid,
                'startTime': startTimeCtrl.text,
                'endTime': endTimeCtrl.text,
                'breakTime': int.tryParse(breakTimeCtrl.text) ?? 1,
                'maxOtHours': int.tryParse(maxOtCtrl.text) ?? 4,
                'workDays': [1, 2, 3, 4, 5, 6], // Monday to Saturday
                'updatedAt': DateTime.now().millisecondsSinceEpoch,
              };

              await db.upsertWorkSchedule(user.uid, newSchedule);
              await _initData();
              Navigator.pop(ctx);
              NotificationService.showSnackBar("Đã cập nhật lịch làm việc", color: Colors.green);
            },
            child: const Text('LƯU'),
          ),
        ],
      ),
    );
  }

  void _showPhotos(Map<String, dynamic> record) {
    final photos = <String>[];
    if (record['photoIn'] != null) photos.add(record['photoIn']);
    if (record['photoOut'] != null) photos.add(record['photoOut']);

    if (photos.isEmpty) {
      NotificationService.showSnackBar("Không có ảnh nào", color: Colors.grey);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(record['dateKey']),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            SizedBox(
              height: 300,
              child: PageView.builder(
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  return Image.file(
                    File(photos[index]),
                    fit: BoxFit.contain,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClockCard() {
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm:ss').format(now);
    final dateStr = DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(now);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blue, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10)],
      ),
      child: Column(
        children: [
          const Icon(Icons.access_time, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          Text(
            timeStr,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateStr,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _today != null ? "Đã chấm công hôm nay" : "Chưa chấm công",
            style: TextStyle(
              fontSize: 14,
              color: _today != null ? Colors.greenAccent : Colors.orangeAccent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _loading ? null : () => _actionCheck(true),
            icon: const Icon(Icons.login),
            label: const Text("CHECK-IN"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _loading ? null : () => _actionCheck(false),
            icon: const Icon(Icons.logout),
            label: const Text("CHECK-OUT"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayAttendanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("CHẤM CÔNG HÔM NAY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Icon(Icons.login, color: Colors.green),
                    const SizedBox(height: 8),
                    Text(
                      _today!.checkInAt != null
                          ? DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(_today!.checkInAt!))
                          : '--:--',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Text("Check-in", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade300),
              Expanded(
                child: Column(
                  children: [
                    const Icon(Icons.logout, color: Colors.red),
                    const SizedBox(height: 8),
                    Text(
                      _today!.checkOutAt != null
                          ? DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(_today!.checkOutAt!))
                          : '--:--',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Text("Check-out", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (_today!.photoIn != null || _today!.photoOut != null) ...[
            const SizedBox(height: 20),
            const Text("Ảnh chấm công", style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Row(
              children: [
                if (_today!.photoIn != null)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showPhoto(_today!.photoIn!),
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(_today!.photoIn!),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.photo, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                if (_today!.photoIn != null && _today!.photoOut != null) const SizedBox(width: 10),
                if (_today!.photoOut != null)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showPhoto(_today!.photoOut!),
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(_today!.photoOut!),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.photo, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showPhoto(String photoUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text("Ảnh chấm công"),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            SizedBox(
              height: 300,
              child: Image.network(
                photoUrl,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
