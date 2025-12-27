import 'package:flutter_test/flutter_test.dart';
import 'package:QuanLyShop/models/debt_model.dart';

void main() {
  group('Debt.fromMap', () {
    test('fromMap with paidAmount > totalAmount', () {
      final map = {'personName': 'Test', 'phone': '123', 'totalAmount': 100, 'paidAmount': 150, 'type': 'OWE', 'createdAt': 1234567890};
      final debt = Debt.fromMap(map);
      expect(debt.paidAmount, 100);
    });

    test('fromMap with invalid totalAmount', () {
      final map = {'personName': 'Test', 'phone': '123', 'totalAmount': '200', 'paidAmount': 50, 'type': 'OWE', 'createdAt': 1234567890};
      final debt = Debt.fromMap(map);
      expect(debt.totalAmount, 0);
    });

    test('fromMap with null paidAmount', () {
      final map = {'personName': 'Test', 'phone': '123', 'totalAmount': 100, 'paidAmount': null, 'type': 'OWE', 'createdAt': 1234567890};
      final debt = Debt.fromMap(map);
      expect(debt.paidAmount, 0);
    });
  });
}