import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/models/repair_model.dart';

void main() {
  group('RepairModel', () {
    test('should create Repair with required fields', () {
      final repair = Repair(
        customerName: 'Nguyễn Văn A',
        phone: '0123456789',
        model: 'iPhone 15 Pro',
        issue: 'Màn hình bị vỡ',
        createdAt: 1640995200000, // 2022-01-01
      );

      expect(repair.customerName, 'Nguyễn Văn A');
      expect(repair.phone, '0123456789');
      expect(repair.model, 'iPhone 15 Pro');
      expect(repair.issue, 'Màn hình bị vỡ');
      expect(repair.status, 1); // default status
      expect(repair.price, 0); // default price
    });

    test('should serialize to Map correctly', () {
      final repair = Repair(
        customerName: 'Nguyễn Văn A',
        phone: '0123456789',
        model: 'iPhone 15 Pro',
        issue: 'Màn hình bị vỡ',
        createdAt: 1640995200000,
        price: 5000000,
        cost: 2000000,
        status: 2,
      );

      final map = repair.toMap();

      expect(map['customerName'], 'Nguyễn Văn A');
      expect(map['phone'], '0123456789');
      expect(map['model'], 'iPhone 15 Pro');
      expect(map['issue'], 'Màn hình bị vỡ');
      expect(map['price'], 5000000);
      expect(map['cost'], 2000000);
      expect(map['status'], 2);
      expect(map['createdAt'], 1640995200000);
    });

    test('should deserialize from Map correctly', () {
      final map = {
        'customerName': 'Nguyễn Văn A',
        'phone': '0123456789',
        'model': 'iPhone 15 Pro',
        'issue': 'Màn hình bị vỡ',
        'createdAt': 1640995200000,
        'price': 5000000,
        'cost': 2000000,
        'status': 2,
        'isSynced': 1,
        'deleted': 0,
      };

      final repair = Repair.fromMap(map);

      expect(repair.customerName, 'Nguyễn Văn A');
      expect(repair.phone, '0123456789');
      expect(repair.model, 'iPhone 15 Pro');
      expect(repair.issue, 'Màn hình bị vỡ');
      expect(repair.price, 5000000);
      expect(repair.cost, 2000000);
      expect(repair.status, 2);
      expect(repair.createdAt, 1640995200000);
      expect(repair.isSynced, true);
      expect(repair.deleted, false);
    });

    test('should handle null values in fromMap', () {
      final map = {
        'customerName': null,
        'phone': null,
        'model': null,
        'issue': null,
        'createdAt': null,
      };

      final repair = Repair.fromMap(map);

      expect(repair.customerName, '');
      expect(repair.phone, '');
      expect(repair.model, '');
      expect(repair.issue, '');
      expect(repair.createdAt, 0);
    });

    test('should calculate receiveImages correctly', () {
      final repair = Repair(
        customerName: 'Test',
        phone: '0123456789',
        model: 'iPhone',
        issue: 'Test',
        createdAt: 1640995200000,
        imagePath: 'image1.jpg,image2.jpg,',
      );

      expect(repair.receiveImages, ['image1.jpg', 'image2.jpg']);
    });

    test('should handle empty imagePath', () {
      final repair = Repair(
        customerName: 'Test',
        phone: '0123456789',
        model: 'iPhone',
        issue: 'Test',
        createdAt: 1640995200000,
        imagePath: '',
      );

      expect(repair.receiveImages, isEmpty);
    });
  });
}