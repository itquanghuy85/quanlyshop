import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quanlyshop/models/attendance_model.dart';
import 'package:quanlyshop/models/shop_deduction_settings.dart';
import 'package:quanlyshop/services/clock_check_service.dart';
import 'package:quanlyshop/services/payroll_lock_service.dart';
import 'package:quanlyshop/services/salary_calculation_service.dart';

void main() {
  group('ClockCheckService (F-14 backdating guard)', () {
    test('parses RFC 1123 Date header as UTC', () {
      final d = ClockCheckService.parseHttpDate('Sat, 26 Sep 2026 02:16:00 GMT');
      expect(d, DateTime.utc(2026, 9, 26, 2, 16));
      expect(ClockCheckService.parseHttpDate('garbage'), isNull);
      expect(ClockCheckService.parseHttpDate(null), isNull);
    });

    test('skew within 5 minutes is allowed, beyond is blocked (both directions)', () {
      final ref = DateTime.utc(2026, 9, 26, 2, 0);
      expect(ClockCheckService.isSkewTooLarge(
          ClockCheckService.skewOf(ref.add(const Duration(minutes: 4)), ref)), isFalse);
      expect(ClockCheckService.isSkewTooLarge(
          ClockCheckService.skewOf(ref.subtract(const Duration(minutes: 4)), ref)), isFalse);
      expect(ClockCheckService.isSkewTooLarge(
          ClockCheckService.skewOf(ref.subtract(const Duration(hours: 2)), ref)), isTrue);
      expect(ClockCheckService.isSkewTooLarge(
          ClockCheckService.skewOf(ref.add(const Duration(minutes: 6)), ref)), isTrue);
    });

    test('local-time device vs UTC reference compares the same instant', () {
      final ref = DateTime.utc(2026, 9, 26, 2, 0);
      expect(ClockCheckService.skewOf(ref.toLocal(), ref), Duration.zero);
    });
  });

  group('SalaryCalculationService device cache (network loss)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('deduction settings survive a round trip incl. Firestore Timestamp', () async {
      final original = ShopDeductionSettings(shopId: 's1').toMap()
        ..['updatedAt'] = Timestamp.fromMillisecondsSinceEpoch(1790000000000);
      await SalaryCalculationService.cachePut('s1', 'deductions', original);
      final back = await SalaryCalculationService.cacheGet('s1', 'deductions');
      expect(back, isA<Map>());
      final parsed = ShopDeductionSettings.fromMap(Map<String, dynamic>.from(back as Map));
      expect(parsed.shopId, 's1');
      expect((back)['updatedAt'], 1790000000000);
    });

    test('cache is isolated per shop', () async {
      await SalaryCalculationService.cachePut('s1', 'staff', [
        {'uid': 'a', 'name': 'A'},
      ]);
      expect(await SalaryCalculationService.cacheGet('s2', 'staff'), isNull);
      final s1 = await SalaryCalculationService.cacheGet('s1', 'staff') as List;
      expect(s1.single['uid'], 'a');
    });
  });

  group('PayrollLockService keys', () {
    test('month key helpers', () {
      expect(PayrollLockService.monthKeyOf(DateTime(2026, 3, 9)), '2026-03');
      expect(PayrollLockService.monthKeyFromDateKey('2026-09-26'), '2026-09');
      expect(PayrollLockService.cacheKey('shopA', '2026-09'), 'shopA|2026-09');
      expect(PayrollLockService.cacheKey(null, '2026-09'), '2026-09');
    });
  });

  test('Attendance.fromMap accepts a raw Firestore map with Timestamp fields', () {
    final a = Attendance.fromMap({
      'userId': 'u1',
      'email': 'u1@m.com',
      'name': 'H',
      'dateKey': '2026-09-26',
      'checkInAt': 1790389011183,
      'createdAt': 1790389011183,
      'updatedAt': Timestamp.fromMillisecondsSinceEpoch(1790389099000),
      'approvedAt': Timestamp.fromMillisecondsSinceEpoch(1790389100000),
      'isLate': false,
      'overtimeOn': 30.0,
    });
    expect(a.updatedAt, 1790389099000);
    expect(a.approvedAt, 1790389100000);
    expect(a.isLate, 0);
    expect(a.overtimeOn, 30);
    expect(a.checkInAt, 1790389011183);
  });
}
