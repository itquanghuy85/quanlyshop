import 'package:flutter_test/flutter_test.dart';
<<<<<<< HEAD
import 'package:quanlyshop/models/sale_order_model.dart';
=======
import 'package:QuanLyShop/models/sale_order_model.dart';
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6

void main() {
  group('SaleOrder.fromMap', () {
    test('fromMap with invalid totalPrice string', () {
      final map = {'totalPrice': 'abc', 'totalCost': 100, 'customerName': 'Test', 'phone': '123', 'productNames': 'Phone', 'productImeis': 'IMEI', 'sellerName': 'Seller', 'soldAt': 1234567890};
      final sale = SaleOrder.fromMap(map);
      expect(sale.totalPrice, 0);
    });

    test('fromMap with negative totalPrice', () {
      final map = {'totalPrice': -100, 'totalCost': 50, 'customerName': 'Test', 'phone': '123', 'productNames': 'Phone', 'productImeis': 'IMEI', 'sellerName': 'Seller', 'soldAt': 1234567890};
      final sale = SaleOrder.fromMap(map);
<<<<<<< HEAD
      expect(sale.totalPrice, 0); // Model clamps negative values to 0
=======
      expect(sale.totalPrice, -100);
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
    });

    test('fromMap with null soldAt', () {
      final map = {'totalPrice': 100, 'totalCost': 50, 'customerName': 'Test', 'phone': '123', 'productNames': 'Phone', 'productImeis': 'IMEI', 'sellerName': 'Seller', 'soldAt': null};
      final sale = SaleOrder.fromMap(map);
      expect(sale.soldAt, 0);
    });

    test('fromMap with invalid isInstallment', () {
      final map = {'totalPrice': 100, 'totalCost': 50, 'customerName': 'Test', 'phone': '123', 'productNames': 'Phone', 'productImeis': 'IMEI', 'sellerName': 'Seller', 'soldAt': 1234567890, 'isInstallment': 'true'};
      final sale = SaleOrder.fromMap(map);
      expect(sale.isInstallment, false);
    });
  });
}