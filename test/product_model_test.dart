import 'package:flutter_test/flutter_test.dart';
import 'package:QuanLyShop/models/product_model.dart';

void main() {
  group('Product.fromMap', () {
    test('fromMap with negative quantity', () {
      final map = {'name': 'Phone', 'cost': 100, 'price': 200, 'condition': 'New', 'createdAt': 1234567890, 'quantity': -5};
      final product = Product.fromMap(map);
      expect(product.quantity, 0);
    });

    test('fromMap with invalid price', () {
      final map = {'name': 'Phone', 'cost': 100, 'price': 'invalid', 'condition': 'New', 'createdAt': 1234567890, 'quantity': 1};
      final product = Product.fromMap(map);
      expect(product.price, 0);
    });

    test('fromMap with invalid createdAt', () {
      final map = {'name': 'Phone', 'cost': 100, 'price': 200, 'condition': 'New', 'createdAt': 'timestamp', 'quantity': 1};
      final product = Product.fromMap(map);
      expect(product.createdAt, 0);
    });
  });
}