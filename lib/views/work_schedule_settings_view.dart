import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/responsive_wrapper.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/app_localizations.dart';
import '../data/db_helper.dart';
import '../models/attendance_model.dart';
import '../services/user_service.dart';
import '../services/event_bus.dart';
import '../theme/app_text_styles.dart';
import '../widgets/custom_app_bar.dart';

class WorkScheduleSettingsView extends StatefulWidget {
  const WorkScheduleSettingsView({super.key});

  @override
  State<WorkScheduleSettingsView> createState() =>
      _WorkScheduleSettingsViewState();
}

class _WorkScheduleSettingsViewState extends State<WorkScheduleSettingsView> {
  AppLocalizations get loc => AppLocalizations.of(context)!;
  // Work Schedule Settings
  final startTimeCtrl = TextEditingController(text: '08:00');
  final endTimeCtrl = TextEditingController(text: '17:00');
  final breakTimeCtrl = TextEditingController(text: '1');
  final maxOtHoursCtrl = TextEditingController(text: '4');

  // Work Days Settings
  List<bool> workDays = [
    false,
    true,
    true,
    true,
    true,
    true,
    false,
  ]; // Sun to Sat
  final holidayCtrl = TextEditingController();
  List<String> holidays = [];

  // Overtime Settings
  final weekdayOtRateCtrl = TextEditingController(text: '150');
  final weekendOtRateCtrl = TextEditingController(text: '200');
  final holidayOtRateCtrl = TextEditingController(text: '300');

  // Staff Salary Settings
  final staffSalaryCtrl = TextEditingController();
  String? selectedStaff;
  List<Map<String, dynamic>> staffList = [];
  Map<String, double> staffSalaries = {};

  // Staff Work Schedules (loaded into state to avoid FutureBuilder issues)
  Map<String, Map<String, dynamic>> _staffWorkSchedules = {};

  // Attendance Settings
  List<Attendance> attendanceRecords = [];
  String? selectedStaffForAttendance;
  DateTime selectedDate = DateTime.now();
  bool _isSuperAdmin = false;
  String? _currentShopId;

  bool _loading = true;
  bool _refreshingStaff =
      false; // For refreshing staff list without resetting tabs

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    startTimeCtrl.dispose();
    endTimeCtrl.dispose();
    breakTimeCtrl.dispose();
    maxOtHoursCtrl.dispose();
    holidayCtrl.dispose();
    weekdayOtRateCtrl.dispose();
    weekendOtRateCtrl.dispose();
    holidayOtRateCtrl.dispose();
    staffSalaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Check permissions
      _isSuperAdmin = UserService.isCurrentUserSuperAdmin();
      _currentShopId = await UserService.getCurrentShopId();

      // Load work schedule from Firestore first (sync source), fallback to local
      Map<String, dynamic>? firestoreSchedule;
      if (_currentShopId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('work_schedules')
            .doc('shop_general_$_currentShopId')
            .get();
        if (doc.exists) {
          firestoreSchedule = doc.data();
          debugPrint(
            '📋 Loaded work schedule from Firestore: $firestoreSchedule',
          );
        }
      }

      // Use Firestore data if available, otherwise use SharedPreferences
      if (firestoreSchedule != null) {
        startTimeCtrl.text = firestoreSchedule['startTime'] ?? '08:00';
        endTimeCtrl.text = firestoreSchedule['endTime'] ?? '17:00';
        breakTimeCtrl.text = (firestoreSchedule['breakTime'] ?? 1).toString();
        maxOtHoursCtrl.text = (firestoreSchedule['maxOtHours'] ?? 4).toString();

        // Load work days from Firestore
        final workDaysStr = firestoreSchedule['workDays'] as String?;
        if (workDaysStr != null) {
          final days = workDaysStr.split(',');
          for (int i = 0; i < workDays.length && i < days.length; i++) {
            workDays[i] = days[i] == '1';
          }
        }

        // Load holidays from Firestore
        final holidaysStr = firestoreSchedule['holidays'] as String?;
        if (holidaysStr != null && holidaysStr.isNotEmpty) {
          holidays = holidaysStr.split(',').where((h) => h.isNotEmpty).toList();
        }

        // Load OT rates from Firestore
        weekdayOtRateCtrl.text = (firestoreSchedule['weekdayOtRate'] ?? 150)
            .toString();
        weekendOtRateCtrl.text = (firestoreSchedule['weekendOtRate'] ?? 200)
            .toString();
        holidayOtRateCtrl.text = (firestoreSchedule['holidayOtRate'] ?? 300)
            .toString();

        // Also update SharedPreferences for local cache
        await prefs.setString('work_start_time', startTimeCtrl.text);
        await prefs.setString('work_end_time', endTimeCtrl.text);
        await prefs.setInt(
          'work_break_time',
          int.tryParse(breakTimeCtrl.text) ?? 1,
        );
        await prefs.setInt(
          'work_max_ot_hours',
          int.tryParse(maxOtHoursCtrl.text) ?? 4,
        );
        await prefs.setString('work_days', workDaysStr ?? '0,1,1,1,1,1,0');
        await prefs.setString('work_holidays', holidaysStr ?? '');
        await prefs.setInt(
          'weekday_ot_rate',
          int.tryParse(weekdayOtRateCtrl.text) ?? 150,
        );
        await prefs.setInt(
          'weekend_ot_rate',
          int.tryParse(weekendOtRateCtrl.text) ?? 200,
        );
        await prefs.setInt(
          'holiday_ot_rate',
          int.tryParse(holidayOtRateCtrl.text) ?? 300,
        );
      } else {
        // Fallback to SharedPreferences
        startTimeCtrl.text = prefs.getString('work_start_time') ?? '08:00';
        endTimeCtrl.text = prefs.getString('work_end_time') ?? '17:00';
        breakTimeCtrl.text = (prefs.getInt('work_break_time') ?? 1).toString();
        maxOtHoursCtrl.text = (prefs.getInt('work_max_ot_hours') ?? 4)
            .toString();

        // Load work days from SharedPreferences
        final workDaysStr = prefs.getString('work_days');
        if (workDaysStr != null) {
          final days = workDaysStr.split(',');
          for (int i = 0; i < workDays.length && i < days.length; i++) {
            workDays[i] = days[i] == '1';
          }
        }

        // Load holidays from SharedPreferences
        final holidaysStr = prefs.getString('work_holidays');
        if (holidaysStr != null && holidaysStr.isNotEmpty) {
          holidays = holidaysStr.split(',').where((h) => h.isNotEmpty).toList();
        }

        // Load OT rates from SharedPreferences
        weekdayOtRateCtrl.text = (prefs.getInt('weekday_ot_rate') ?? 150)
            .toString();
        weekendOtRateCtrl.text = (prefs.getInt('weekend_ot_rate') ?? 200)
            .toString();
        holidayOtRateCtrl.text = (prefs.getInt('holiday_ot_rate') ?? 300)
            .toString();
      }

      // Load staff salaries
      final salariesStr = prefs.getString('staff_salaries');
      if (salariesStr != null) {
        final entries = salariesStr.split(';');
        for (final entry in entries) {
          if (entry.isNotEmpty) {
            final parts = entry.split(':');
            if (parts.length == 2) {
              staffSalaries[parts[0]] = double.tryParse(parts[1]) ?? 0;
            }
          }
        }
      }

      // Load staff list from shop
      await _loadStaffList();

      // Load work schedules for all staff
      await _loadStaffWorkSchedules();

      // Load attendance records for selected date
      await _loadAttendanceRecords();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadStaffList() async {
    try {
      final db = FirebaseFirestore.instance;
      final currentUser = FirebaseAuth.instance.currentUser;

      debugPrint(
        '📋 _loadStaffList: isSuperAdmin=$_isSuperAdmin, shopId=$_currentShopId',
      );

      // Nếu chưa có shopId, thử lấy từ nhiều nguồn
      if (_currentShopId == null || _currentShopId!.isEmpty) {
        // 1. Thử từ UserService cache
        _currentShopId = await UserService.getCurrentShopId();
        debugPrint('📋 Got shopId from UserService: $_currentShopId');

        // 2. Thử từ Firestore user doc
        if ((_currentShopId == null || _currentShopId!.isEmpty) &&
            currentUser != null) {
          final userDoc = await db
              .collection('users')
              .doc(currentUser.uid)
              .get();
          final shopIdFromDoc = userDoc.data()?['shopId'] as String?;
          if (shopIdFromDoc != null && shopIdFromDoc.isNotEmpty) {
            _currentShopId = shopIdFromDoc;
            debugPrint('📋 Got shopId from Firestore doc: $_currentShopId');
          }
        }

        // 3. Với non-super-admin, dùng uid làm shopId (owner mặc định)
        if ((_currentShopId == null || _currentShopId!.isEmpty) &&
            !_isSuperAdmin &&
            currentUser != null) {
          _currentShopId = currentUser.uid;
          debugPrint('📋 Using uid as shopId fallback: $_currentShopId');
        }
      }

      // Vẫn không có shopId = trả về rỗng
      if (_currentShopId == null || _currentShopId!.isEmpty) {
        debugPrint(
          '⚠️ No shopId found after all attempts, returning empty staffList',
        );
        staffList = [];
        return;
      }

      // Query users với shopId filter
      debugPrint('📋 Querying users with shopId: $_currentShopId');

      // Thực hiện queries:
      // 1. Users có shopId trùng với _currentShopId
      // 2. Users có shopId trùng uid của owner (nếu khác _currentShopId)
      // 3. User hiện tại (owner case)
      final List<Map<String, dynamic>> allStaff = [];
      final Set<String> addedIds = {};

      // Query 1: Users có shopId == _currentShopId
      try {
        final snapshot = await db
            .collection('users')
            .where('shopId', isEqualTo: _currentShopId)
            .get();
        debugPrint(
          '📋 Found ${snapshot.docs.length} staff with shopId=$_currentShopId',
        );

        for (var doc in snapshot.docs) {
          if (!addedIds.contains(doc.id)) {
            final data = doc.data();
            allStaff.add({
              'id': doc.id,
              'name':
                  data['name'] ??
                  data['displayName'] ??
                  data['email']?.toString().split('@').first ??
                  'Unknown',
              'email': data['email'] ?? '',
              'role': data['role'] ?? 'user',
            });
            addedIds.add(doc.id);
          }
        }
      } catch (e) {
        debugPrint('❌ Query users with shopId failed: $e');
      }

      // Query 2: Nếu shopId khác uid, thử query thêm với uid làm shopId (owner's employees)
      if (currentUser != null && _currentShopId != currentUser.uid) {
        try {
          final snapshot2 = await db
              .collection('users')
              .where('shopId', isEqualTo: currentUser.uid)
              .get();
          debugPrint(
            '📋 Found ${snapshot2.docs.length} staff with shopId=${currentUser.uid} (owner uid)',
          );

          for (var doc in snapshot2.docs) {
            if (!addedIds.contains(doc.id)) {
              final data = doc.data();
              allStaff.add({
                'id': doc.id,
                'name':
                    data['name'] ??
                    data['displayName'] ??
                    data['email']?.toString().split('@').first ??
                    'Unknown',
                'email': data['email'] ?? '',
                'role': data['role'] ?? 'user',
              });
              addedIds.add(doc.id);
            }
          }
        } catch (e) {
          debugPrint('❌ Query users with owner uid failed: $e');
        }
      }

      // Query 3: LUÔN thêm current user vào danh sách nếu chưa có
      // (Đảm bảo owner/chủ shop luôn xuất hiện trong danh sách)
      if (currentUser != null && !addedIds.contains(currentUser.uid)) {
        try {
          final ownerDoc = await db
              .collection('users')
              .doc(currentUser.uid)
              .get();
          if (ownerDoc.exists) {
            final data = ownerDoc.data()!;
            allStaff.add({
              'id': currentUser.uid,
              'name':
                  data['name'] ??
                  data['displayName'] ??
                  currentUser.email?.split('@').first ??
                  'Owner',
              'email': data['email'] ?? currentUser.email ?? '',
              'role': data['role'] ?? 'owner',
            });
            addedIds.add(currentUser.uid);
            debugPrint(
              '📋 Added owner/current user to staff list: ${currentUser.uid}',
            );
          } else {
            // User doc không tồn tại, tạo entry từ auth info
            allStaff.add({
              'id': currentUser.uid,
              'name':
                  currentUser.displayName ??
                  currentUser.email?.split('@').first ??
                  'Owner',
              'email': currentUser.email ?? '',
              'role': 'owner',
            });
            addedIds.add(currentUser.uid);
            debugPrint(
              '📋 Added current user from auth info: ${currentUser.uid}',
            );
          }
        } catch (e) {
          debugPrint('❌ Query owner doc failed: $e');
          // Fallback: thêm từ auth info
          allStaff.add({
            'id': currentUser.uid,
            'name':
                currentUser.displayName ??
                currentUser.email?.split('@').first ??
                'Owner',
            'email': currentUser.email ?? '',
            'role': 'owner',
          });
          addedIds.add(currentUser.uid);
        }
      }

      // Hide super admin from staff list
      allStaff.removeWhere((s) => s['email'] == 'admin@huluca.com');

      debugPrint('📋 Total staff loaded: ${allStaff.length}');

      staffList = allStaff;

      // Sort by name
      staffList.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );
    } catch (e) {
      debugPrint('❌ _loadStaffList error: $e');
      // Fallback to empty list instead of sample data
      staffList = [];
    }
  }

  /// Load work schedules cho tất cả nhân viên vào state (từ Firestore hoặc local DB)
  Future<void> _loadStaffWorkSchedules() async {
    final db = DBHelper();
    final Map<String, Map<String, dynamic>> schedules = {};

    for (final staff in staffList) {
      final userId = staff['id'] as String;
      try {
        // Thử load từ Firestore trước (để sync giữa các thiết bị)
        Map<String, dynamic>? schedule;
        if (_currentShopId != null) {
          final doc = await FirebaseFirestore.instance
              .collection('work_schedules')
              .doc('staff_${userId}_$_currentShopId')
              .get();
          if (doc.exists) {
            schedule = doc.data();
            debugPrint('📋 Loaded schedule from Firestore for $userId');
            // Cập nhật local DB
            await db.upsertWorkSchedule(userId, schedule!);
          }
        }

        // Nếu không có trên Firestore, dùng local DB
        schedule ??= await db.getWorkSchedule(userId);

        if (schedule != null) {
          schedules[userId] = schedule;
        }
      } catch (e) {
        debugPrint('❌ Error loading schedule for $userId: $e');
        // Fallback to local DB
        final localSchedule = await db.getWorkSchedule(userId);
        if (localSchedule != null) {
          schedules[userId] = localSchedule;
        }
      }
    }

    setState(() {
      _staffWorkSchedules = schedules;
    });
    debugPrint(
      '📋 Loaded ${schedules.length} work schedules for ${staffList.length} staff',
    );
  }

  /// Auto load staff list khi vào tab Nhân viên
  Future<void> _autoLoadStaff() async {
    if (_refreshingStaff) return;
    setState(() => _refreshingStaff = true);
    try {
      // Đảm bảo có shopId trước
      if (_currentShopId == null || _currentShopId!.isEmpty) {
        _currentShopId = await UserService.getCurrentShopId();
        final currentUser = FirebaseAuth.instance.currentUser;
        if ((_currentShopId == null || _currentShopId!.isEmpty) &&
            currentUser != null) {
          _currentShopId = currentUser.uid;
        }
      }
      await _loadStaffList();
      await _loadStaffWorkSchedules();
    } catch (e) {
      debugPrint('❌ _autoLoadStaff error: $e');
    } finally {
      if (mounted) setState(() => _refreshingStaff = false);
    }
  }

  Future<void> _loadAttendanceRecords() async {
    if (selectedStaffForAttendance == null) return;

    try {
      final db = DBHelper();
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final record = await db.getAttendance(
        dateStr,
        selectedStaffForAttendance!,
      );

      setState(() {
        attendanceRecords = record != null ? [record] : [];
      });
    } catch (e) {
      setState(() {
        attendanceRecords = [];
      });
    }
  }

  Future<void> _saveWorkSchedule() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = _currentShopId;

      // Prepare data for sync
      final workDaysStr = workDays.map((d) => d ? '1' : '0').join(',');
      final holidaysStr = holidays.join(',');
      final scheduleData = {
        'startTime': startTimeCtrl.text,
        'endTime': endTimeCtrl.text,
        'breakTime': int.tryParse(breakTimeCtrl.text) ?? 1,
        'maxOtHours': int.tryParse(maxOtHoursCtrl.text) ?? 4,
        'workDays': workDaysStr,
        'holidays': holidaysStr,
        'weekdayOtRate': int.tryParse(weekdayOtRateCtrl.text) ?? 150,
        'weekendOtRate': int.tryParse(weekendOtRateCtrl.text) ?? 200,
        'holidayOtRate': int.tryParse(holidayOtRateCtrl.text) ?? 300,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'shopId': shopId,
      };

      // Save to SharedPreferences (for local cache)
      await prefs.setString('work_start_time', startTimeCtrl.text);
      await prefs.setString('work_end_time', endTimeCtrl.text);
      await prefs.setInt(
        'work_break_time',
        int.tryParse(breakTimeCtrl.text) ?? 1,
      );
      await prefs.setInt(
        'work_max_ot_hours',
        int.tryParse(maxOtHoursCtrl.text) ?? 4,
      );
      await prefs.setString('work_days', workDaysStr);
      await prefs.setString('work_holidays', holidaysStr);
      await prefs.setInt(
        'weekday_ot_rate',
        int.tryParse(weekdayOtRateCtrl.text) ?? 150,
      );
      await prefs.setInt(
        'weekend_ot_rate',
        int.tryParse(weekendOtRateCtrl.text) ?? 200,
      );
      await prefs.setInt(
        'holiday_ot_rate',
        int.tryParse(holidayOtRateCtrl.text) ?? 300,
      );

      // Save to local DB
      await DBHelper().upsertWorkSchedule('shop_general', scheduleData);

      // Sync to Firestore (với shopId)
      if (shopId != null) {
        await FirebaseFirestore.instance
            .collection('work_schedules')
            .doc('shop_general_$shopId')
            .set(scheduleData, SetOptions(merge: true));
      }

      EventBus().emit('work_schedules_changed');

      messenger.showSnackBar(
        SnackBar(content: Text(loc.workScheduleSaved)),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(loc.saveErrorMsg(e.toString()))));
    }
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      controller.text =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _addHoliday() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      if (!holidays.contains(dateStr)) {
        setState(() {
          holidays.add(dateStr);
          holidays.sort();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: CustomAppBar.build(
          title: loc.workScheduleSettingsTitle,
          accentColor: AppBarAccents.staff,
          bottom: TabBar(
            tabs: [
              Tab(text: loc.generalSettingsTab),
              Tab(text: loc.staffTab),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
          ),
        ),
        body: ResponsiveCenter(child: TabBarView(
          children: [
            _buildGeneralSettingsTab(),
            _buildStaffManagementTabSimple(),
          ],
        )),
      ),
    );
  }

  /// Simplified Staff Management Tab - không dùng Builder hay try-catch
  Widget _buildStaffManagementTabSimple() {
    debugPrint(
      '🟢 _buildStaffManagementTabSimple called, staffList=${staffList.length}',
    );

    if (staffList.isEmpty) {
      // Tự động load lại nếu chưa có data và không đang loading
      if (!_refreshingStaff && !_loading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && staffList.isEmpty && !_refreshingStaff) {
            _autoLoadStaff();
          }
        });
      }

      return Container(
        color: Colors.grey.shade100,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_refreshingStaff) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  loc.loadingStaffList,
                  style: TextStyle(fontSize: AppTextStyles.headline4.fontSize),
                ),
              ] else ...[
                const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  loc.noStaffData,
                  style: TextStyle(fontSize: AppTextStyles.headline2.fontSize),
                ),
                const SizedBox(height: 8),
                Text(
                  loc.tapToRefresh,
                  style: TextStyle(fontSize: AppTextStyles.headline4.fontSize, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: Text(loc.reload),
                  onPressed: _autoLoadStaff,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: staffList.length + 2, // +2 for headers
        itemBuilder: (context, index) {
          if (index == 0) {
            return Card(
              color: Colors.blue.shade50,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.people, color: Colors.blue),
                    const SizedBox(width: 12),
                    Text(
                      loc.staffCountLabel(staffList.length),
                      style: TextStyle(
                        fontSize: AppTextStyles.headline3.fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 20, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    loc.staffWorkSchedule,
                    style: TextStyle(
                      fontSize: AppTextStyles.headline3.fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            );
          }

          final staffIndex = index - 2;
          final staff = staffList[staffIndex];
          final staffId = staff['id'] as String;
          final schedule = _staffWorkSchedules[staffId];
          final hasSchedule = schedule != null;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: hasSchedule
                    ? Colors.green.shade100
                    : Colors.grey.shade200,
                child: Icon(
                  hasSchedule ? Icons.check : Icons.schedule,
                  color: hasSchedule ? Colors.green : Colors.grey,
                  size: 20,
                ),
              ),
              title: Text(
                '${staff['name']}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: hasSchedule
                  ? Text(
                      '${schedule['startTime'] ?? '08:00'} - ${schedule['endTime'] ?? '17:00'}',
                      style: TextStyle(
                        fontSize: AppTextStyles.subtitle1.fontSize,
                        color: Colors.grey.shade700,
                      ),
                    )
                  : Text(
                      loc.scheduleNotSet,
                      style: TextStyle(
                        fontSize: AppTextStyles.subtitle1.fontSize,
                        color: Colors.orange.shade700,
                      ),
                    ),
              trailing: IconButton(
                icon: Icon(Icons.edit, color: Colors.blue.shade600),
                onPressed: () => _editStaffWorkSchedule(staff, schedule),
              ),
            ),
          );
        },
      ),
    );
  }

  // Tab 1: Gộp Giờ làm việc + Ngày nghỉ + Tăng ca
  Widget _buildGeneralSettingsTab() {
    final dayNames = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === SECTION: Giờ làm việc ===
          _buildSectionTitle(loc.workHoursLabel, Icons.access_time),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildCompactTimeCard(loc.startTimeLabel, startTimeCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _buildCompactTimeCard(loc.endTimeLabel, endTimeCtrl)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactNumberCard(
                  loc.lunchBreakLabel,
                  breakTimeCtrl,
                  'giờ',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactNumberCard(
                  loc.maxOvertimeLabel,
                  maxOtHoursCtrl,
                  'giờ',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // === SECTION: Ngày làm việc ===
          _buildSectionTitle(loc.workDaysLabel, Icons.calendar_today),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (index) {
              return FilterChip(
                label: Text(dayNames[index]),
                selected: workDays[index],
                onSelected: (selected) {
                  setState(() => workDays[index] = selected);
                  // Auto-save when work day changes
                  _saveWorkSchedule();
                },
              );
            }),
          ),

          const SizedBox(height: 16),

          // Ngày nghỉ lễ
          Row(
            children: [
              Expanded(
                child: Text(
                  loc.holidaysLabel,
                  style: TextStyle(fontSize: AppTextStyles.headline4.fontSize, fontWeight: FontWeight.w500),
                ),
              ),
              TextButton.icon(
                onPressed: _addHoliday,
                icon: const Icon(Icons.add, size: 18),
                label: Text(loc.addBtn),
              ),
            ],
          ),
          if (holidays.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: holidays.map((holiday) {
                return Chip(
                  label: Text(holiday, style: TextStyle(fontSize: AppTextStyles.subtitle1.fontSize)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => setState(() => holidays.remove(holiday)),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),

          const SizedBox(height: 24),

          // === SECTION: Tăng ca ===
          _buildSectionTitle(loc.overtimeRateLabel, Icons.timer),
          const SizedBox(height: 12),
          _buildCompactNumberCard(loc.weekdayLabel, weekdayOtRateCtrl, '%'),
          const SizedBox(height: 8),
          _buildCompactNumberCard(loc.weekendLabel, weekendOtRateCtrl, '%'),
          const SizedBox(height: 8),
          _buildCompactNumberCard(loc.holidayLabel, holidayOtRateCtrl, '%'),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveWorkSchedule,
              icon: const Icon(Icons.save),
              label: Text(loc.saveSettingsBtn, style: TextStyle(fontSize: AppTextStyles.headline3.fontSize)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: AppTextStyles.headline3.fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
        ),
      ],
    );
  }

  /// Dialog chỉnh sửa lịch làm việc cho 1 nhân viên
  Future<void> _editStaffWorkSchedule(
    Map<String, dynamic> staff,
    Map<String, dynamic>? currentSchedule,
  ) async {
    final startCtrl = TextEditingController(
      text: currentSchedule?['startTime'] ?? '08:00',
    );
    final endCtrl = TextEditingController(
      text: currentSchedule?['endTime'] ?? '17:00',
    );
    final breakCtrl = TextEditingController(
      text: (currentSchedule?['breakTime'] ?? 1).toString(),
    );
    final maxOtCtrl = TextEditingController(
      text: (currentSchedule?['maxOtHours'] ?? 4).toString(),
    );

    // Work days (default Mon-Sat)
    List<bool> workDays = List.generate(7, (i) {
      final savedDays = currentSchedule?['workDays'];
      if (savedDays is String && savedDays.isNotEmpty) {
        // Parse "1,2,3,4,5,6" format
        final dayIndices = savedDays
            .split(',')
            .map((s) => int.tryParse(s.trim()) ?? -1)
            .toList();
        return dayIndices.contains(i);
      } else if (savedDays is List) {
        return savedDays.contains(i);
      }
      // Default: Mon(1) to Sat(6)
      return i >= 1 && i <= 6;
    });
    final dayNames = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.schedule, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lịch làm việc: ${staff['name']}',
                  style: TextStyle(fontSize: AppTextStyles.headline3.fontSize),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Giờ làm việc
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startCtrl,
                        readOnly: true,
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            startCtrl.text =
                                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Bắt đầu',
                          border: OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: Icon(Icons.access_time, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: endCtrl,
                        readOnly: true,
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            endCtrl.text =
                                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Kết thúc',
                          border: OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: Icon(Icons.access_time, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Nghỉ trưa + OT
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: breakCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Nghỉ trưa',
                          border: OutlineInputBorder(),
                          isDense: true,
                          suffixText: 'giờ',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: maxOtCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'OT tối đa',
                          border: OutlineInputBorder(),
                          isDense: true,
                          suffixText: 'giờ',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Ngày làm việc
                const Text(
                  'Ngày làm việc:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: List.generate(7, (index) {
                    return FilterChip(
                      label: Text(
                        dayNames[index],
                        style: TextStyle(fontSize: AppTextStyles.subtitle1.fontSize),
                      ),
                      selected: workDays[index],
                      onSelected: (selected) {
                        setDialogState(() => workDays[index] = selected);
                      },
                      visualDensity: VisualDensity.compact,
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('HỦY'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 18),
              label: const Text('LƯU'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                // Convert workDays bool list to int list (indices of true values)
                final workDayIndices = <int>[];
                for (int i = 0; i < workDays.length; i++) {
                  if (workDays[i]) workDayIndices.add(i);
                }

                final newSchedule = {
                  'userId': staff['id'],
                  'startTime': startCtrl.text,
                  'endTime': endCtrl.text,
                  'breakTime': int.tryParse(breakCtrl.text) ?? 1,
                  'maxOtHours': int.tryParse(maxOtCtrl.text) ?? 4,
                  'workDays': workDayIndices.join(
                    ',',
                  ), // Store as "1,2,3,4,5,6"
                  'updatedAt': DateTime.now().millisecondsSinceEpoch,
                  'shopId': _currentShopId,
                };

                await DBHelper().upsertWorkSchedule(
                  staff['id'] as String,
                  newSchedule,
                );

                // Sync to Firestore
                if (_currentShopId != null) {
                  await FirebaseFirestore.instance
                      .collection('work_schedules')
                      .doc('staff_${staff['id']}_$_currentShopId')
                      .set(newSchedule, SetOptions(merge: true));
                }

                EventBus().emit('work_schedules_changed');

                // Cập nhật state ngay lập tức
                _staffWorkSchedules[staff['id'] as String] = newSchedule;

                if (!mounted) return;
                Navigator.pop(ctx);
                setState(() {}); // Refresh UI

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã lưu lịch làm việc cho ${staff['name']}'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactTimeCard(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () => _selectTime(controller),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.access_time, size: 20),
        isDense: true,
      ),
    );
  }

  Widget _buildCompactNumberCard(
    String label,
    TextEditingController controller,
    String unit,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixText: unit,
        isDense: true,
      ),
    );
  }
}

class NumberTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final number = int.tryParse(newValue.text.replaceAll(',', ''));
    if (number == null) return oldValue;

    final formatted = NumberFormat('#,###').format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
