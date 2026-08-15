import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/models/repair_model.dart';
import 'package:quanlyshop/models/repair_service_model.dart';
import 'package:quanlyshop/models/part_used_detail_model.dart';
import 'package:quanlyshop/services/pricing_engine_service.dart';

/// Tạo 1 đơn sửa "sạch" (1 dịch vụ + 1 linh kiện) đã hoàn thành, dùng cho
/// fixture. status=4 (Đã giao) — nằm trong nhóm trạng thái pricing engine dùng.
Repair _cleanRepair({
  required String model,
  required String service,
  required String part,
  required int cost,
  required int price,
  bool deleted = false,
  int status = 4,
}) {
  return Repair(
    customerName: 'KH',
    phone: '0900000000',
    model: model,
    issue: service,
    createdAt: DateTime.now().millisecondsSinceEpoch,
    status: status,
    cost: cost,
    price: price,
    deleted: deleted,
    services: [RepairService(serviceName: service, cost: 0)],
    partsUsedDetailed: [PartUsedDetail(name: part, cost: cost, qty: 1)],
    partsUsed: '$part x1',
  );
}

void main() {
  group('PricingEngineService.computeSuggestion', () {
    test('Test 1: không có lịch sử → null, không bịa giá', () {
      final result = PricingEngineService.computeSuggestion(
        repairs: const [],
        model: 'iPhone 14 Pro Max',
        issueOrService: 'Thay màn hình',
      );
      expect(result, isNull);
    });

    test('Test 2: chỉ 1 đơn → có kết quả nhưng độ tin cậy thấp (không báo Tốt/Khá)', () {
      final repairs = [
        _cleanRepair(
          model: 'iPhone 14 Pro Max',
          service: 'Thay màn hình',
          part: 'Màn GX',
          cost: 1800000,
          price: 3200000,
        ),
      ];
      final result = PricingEngineService.computeSuggestion(
        repairs: repairs,
        model: 'iPhone 14 Pro Max',
        issueOrService: 'Thay màn hình',
      );
      expect(result, isNotNull);
      expect(result!.sampleCount, 1);
      expect(result.confidence, PricingConfidence.veryLow);
      expect(
        result.confidence,
        isNot(anyOf(PricingConfidence.fair, PricingConfidence.good)),
      );
    });

    test('Test 3: 10+ đơn tương tự → median chính xác, độ tin cậy Tốt', () {
      // 11 đơn, giá thu: 2.9tr..3.3tr + 1 giá lặp 3.2tr → median = 3.2tr
      final prices = [
        2900000,
        3000000,
        3000000,
        3100000,
        3100000,
        3200000,
        3200000,
        3200000,
        3300000,
        3300000,
        3300000,
      ];
      final repairs = prices
          .map(
            (p) => _cleanRepair(
              model: 'iPhone 14 Pro Max',
              service: 'Thay màn hình',
              part: 'Màn GX',
              cost: 1800000,
              price: p,
            ),
          )
          .toList();

      final result = PricingEngineService.computeSuggestion(
        repairs: repairs,
        model: 'iphone 14 pro max', // chữ thường + không dấu vẫn phải khớp
        issueOrService: 'thay man hinh',
      );

      expect(result, isNotNull);
      expect(result!.sampleCount, 11);
      expect(result.medianSalePrice, 3200000);
      expect(result.confidence, PricingConfidence.good);
    });

    test('Test 4: 1 outlier rất lớn không được kéo lệch giá đề xuất', () {
      final prices = [
        3000000,
        3050000,
        3100000,
        3100000,
        3150000,
        3200000,
        15000000, // outlier bất thường
      ];
      final repairs = prices
          .map(
            (p) => _cleanRepair(
              model: 'iPhone 14 Pro Max',
              service: 'Thay màn hình',
              part: 'Màn GX',
              cost: 1800000,
              price: p,
            ),
          )
          .toList();

      final result = PricingEngineService.computeSuggestion(
        repairs: repairs,
        model: 'iPhone 14 Pro Max',
        issueOrService: 'Thay màn hình',
      );

      expect(result, isNotNull);
      // Giá đề xuất phải nằm trong vùng dữ liệu hợp lý, không bị outlier kéo lên
      expect(result!.medianSalePrice, lessThan(3500000));
      // Khoảng giá thường gặp (sau khi loại outlier) không được chứa outlier
      expect(result.maxPrice, lessThan(15000000));
    });

    test('Test 5: sửa giá 1 đơn cũ → thống kê phải dùng giá mới', () {
      final original = _cleanRepair(
        model: 'iPhone 13',
        service: 'Thay pin',
        part: 'Pin zin',
        cost: 400000,
        price: 550000,
      );
      final beforeEdit = PricingEngineService.computeSuggestion(
        repairs: [original],
        model: 'iPhone 13',
        issueOrService: 'Thay pin',
      );
      expect(beforeEdit!.medianSalePrice, 550000);

      // Giả lập sửa giá đơn cũ (đúng hành vi thực tế: field được ghi đè tại
      // chỗ, không tạo bản ghi lịch sử riêng).
      final edited = original.copyWith(price: 600000);
      final afterEdit = PricingEngineService.computeSuggestion(
        repairs: [edited],
        model: 'iPhone 13',
        issueOrService: 'Thay pin',
      );
      expect(afterEdit!.medianSalePrice, 600000);
    });

    test('Test 6: đơn đã soft-delete không tham gia thống kê', () {
      final active = _cleanRepair(
        model: 'iPhone 13',
        service: 'Thay pin',
        part: 'Pin zin',
        cost: 400000,
        price: 550000,
      );
      final deletedOne = _cleanRepair(
        model: 'iPhone 13',
        service: 'Thay pin',
        part: 'Pin zin',
        cost: 999999,
        price: 9999999, // giá trị bất thường — không được lọt vào thống kê
        deleted: true,
      );

      final result = PricingEngineService.computeSuggestion(
        repairs: [active, deletedOne],
        model: 'iPhone 13',
        issueOrService: 'Thay pin',
      );

      expect(result, isNotNull);
      expect(result!.sampleCount, 1);
      expect(result.medianSalePrice, 550000);
    });

    test('Test 7: 2 loại linh kiện khác nhau cùng model — Level 1 không bị trộn', () {
      final screenRepairs = List.generate(
        5,
        (_) => _cleanRepair(
          model: 'iPhone 14',
          service: 'Thay màn hình',
          part: 'Màn GX',
          cost: 1800000,
          price: 3000000,
        ),
      );
      final batteryRepairs = List.generate(
        5,
        (_) => _cleanRepair(
          model: 'iPhone 14',
          service: 'Thay màn hình', // cùng "dịch vụ" tên nhưng khác linh kiện
          part: 'Pin zin',
          cost: 300000,
          price: 500000,
        ),
      );

      final result = PricingEngineService.computeSuggestion(
        repairs: [...screenRepairs, ...batteryRepairs],
        model: 'iPhone 14',
        issueOrService: 'Thay màn hình',
        partName: 'Màn GX',
      );

      expect(result, isNotNull);
      expect(result!.matchLevel, 1);
      // Chỉ 5 đơn màn hình được tính, không lẫn 5 đơn pin
      expect(result.sampleCount, 5);
      expect(result.medianSalePrice, 3000000);
    });

    test('Fallback: Level 1 không đủ dữ liệu → rơi xuống Level 2 (model+dịch vụ)', () {
      // Chỉ có dữ liệu ở mức model+dịch vụ, không có linh kiện xác định
      // (partsUsedDetailed rỗng, partsUsed nhiều dòng → không "sạch")
      final repairs = List.generate(
        4,
        (_) => Repair(
          customerName: 'KH',
          phone: '0900000000',
          model: 'Samsung S23',
          issue: 'Thay màn hình',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          status: 4,
          cost: 2000000,
          price: 3500000,
          services: [RepairService(serviceName: 'Thay màn hình', cost: 0)],
          partsUsed: 'Màn Samsung x1, Ép kính x1', // 2 dòng — không "sạch"
        ),
      );

      final result = PricingEngineService.computeSuggestion(
        repairs: repairs,
        model: 'Samsung S23',
        issueOrService: 'Thay màn hình',
        partName: 'Màn Samsung',
      );

      expect(result, isNotNull);
      expect(result!.matchLevel, 2);
      expect(result.sampleCount, 4);
    });

    test('Fallback: không khớp dịch vụ → rơi xuống Level 3 (chỉ model)', () {
      final repairs = [
        _cleanRepair(
          model: 'Xiaomi 12',
          service: 'Thay pin',
          part: 'Pin zin',
          cost: 300000,
          price: 500000,
        ),
        _cleanRepair(
          model: 'Xiaomi 12',
          service: 'Thay pin',
          part: 'Pin zin',
          cost: 320000,
          price: 520000,
        ),
      ];

      final result = PricingEngineService.computeSuggestion(
        repairs: repairs,
        model: 'Xiaomi 12',
        issueOrService: 'Thay màn hình', // không khớp dịch vụ đã có
      );

      expect(result, isNotNull);
      expect(result!.matchLevel, 3);
      expect(result.sampleCount, 2);
    });

    test('Đơn chưa hoàn thành (status khác 3/4) vẫn được tính nếu caller truyền vào — '
        'việc lọc status thuộc tầng DB (getRepairsForPricing), không phải computeSuggestion', () {
      // computeSuggestion tin tưởng dữ liệu caller truyền vào; DB layer chịu
      // trách nhiệm lọc status. Test này xác nhận không có lọc ẩn bất ngờ.
      final repair = _cleanRepair(
        model: 'Oppo A5',
        service: 'Thay pin',
        part: 'Pin zin',
        cost: 200000,
        price: 350000,
        status: 2, // Đang sửa — DB layer sẽ không trả về status này thực tế
      );
      final result = PricingEngineService.computeSuggestion(
        repairs: [repair],
        model: 'Oppo A5',
        issueOrService: 'Thay pin',
      );
      expect(result, isNotNull);
      expect(result!.sampleCount, 1);
    });
  });

  group('Repair.fromMap tương thích ngược với DB cũ chưa có partsUsedDetailed', () {
    test('map không có key partsUsedDetailed → mặc định rỗng, không lỗi', () {
      final legacyMap = {
        'customerName': 'KH cũ',
        'phone': '0911111111',
        'model': 'iPhone X',
        'issue': 'Thay pin',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'status': 4,
        'cost': 300000,
        'price': 500000,
        // Không có 'partsUsedDetailed' — mô phỏng row cũ trước migration
      };

      final repair = Repair.fromMap(legacyMap);
      expect(repair.partsUsedDetailed, isEmpty);
    });

    test('partsUsedDetailed null tường minh cũng không lỗi', () {
      final legacyMap = {
        'customerName': 'KH cũ',
        'phone': '0911111111',
        'model': 'iPhone X',
        'issue': 'Thay pin',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'status': 4,
        'cost': 300000,
        'price': 500000,
        'partsUsedDetailed': null,
      };

      final repair = Repair.fromMap(legacyMap);
      expect(repair.partsUsedDetailed, isEmpty);
    });
  });
}
