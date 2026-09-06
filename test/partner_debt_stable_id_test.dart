import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/services/repair_partner_service.dart';

/// Vá sự cố 06/09/2026: sửa giá dịch vụ đối tác xong, công nợ KHÔNG đổi theo.
///
/// Đo trên shop thật: đơn #997 dịch vụ `EK 11PRM` giá **300.000đ** nhưng bản nợ
/// đối tác vẫn ghi **400.000đ**, mã nợ là
/// `debt_partner_debt_rep_..._svc_1788260327031284_40_400000` — tức mã nợ **nhét
/// giá vào đuôi**, nên đổi giá là đổi luôn danh tính bản nợ: bản giá cũ nằm lại,
/// bản giá mới không được tạo.
///
/// Quy tắc mới: mã nợ chỉ gồm (đơn, dịch vụ, đối tác) — giá đổi thì cập nhật
/// đúng bản nợ đó.

/// Khớp đối tác của dịch vụ khi mở lại trên MÁY KHÁC.
///
/// `RepairService.partnerId` là id SQLite cục bộ. Đo trên máy test 06/09/2026:
/// đối tác "SC" có id local 28 nhưng dịch vụ lưu partnerId = 1 (id máy tạo đơn)
/// ⇒ 3/3 dịch vụ không khớp, hộp "Sửa dịch vụ" hiện "Không có đối tác", lưu lại
/// là mất đối tác kèm mất công nợ.
class _P {
  const _P(this.id, this.firestoreId, this.name);
  final int? id;
  final String? firestoreId;
  final String name;
}

void _partnerMatchTests() {
  const sc = _P(28, 'partner_1786245140527', 'SC');
  const grap = _P(29, 'partner_1788499720825', 'GRAP');
  const all = [sc, grap];

  _P? find({String? fid, int? id, String? name}) =>
      RepairPartnerService.findPartnerForService<_P>(
        partners: all,
        firestoreIdOf: (p) => p.firestoreId,
        idOf: (p) => p.id,
        nameOf: (p) => p.name,
        servicePartnerFirestoreId: fid,
        servicePartnerId: id,
        servicePartnerName: name,
      );

  group('Khớp đối tác của dịch vụ', () {
    test('ca thật: id cục bộ lệch (1 vs 28) nhưng firestoreId khớp', () {
      final p = find(fid: 'partner_1786245140527', id: 1, name: 'SC');
      expect(p?.name, 'SC');
    });

    test('firestoreId thắng id cục bộ khi hai bên chỉ khác nhau', () {
      // id 29 là GRAP trên máy này, nhưng firestoreId nói rõ là SC.
      final p = find(fid: 'partner_1786245140527', id: 29, name: null);
      expect(p?.name, 'SC');
    });

    test('không có firestoreId thì dùng id cục bộ', () {
      expect(find(id: 29)?.name, 'GRAP');
    });

    test('dữ liệu cũ không có firestoreId lẫn id khớp ⇒ khớp theo tên', () {
      final p = find(fid: null, id: 49, name: 'sc');
      expect(p?.name, 'SC');
    });

    test('KHÔNG khớp thì trả null — tuyệt đối không lấy đối tác đầu danh sách', () {
      expect(find(fid: 'partner_khong_ton_tai', id: 999, name: 'AI ĐÓ'), isNull);
      expect(find(), isNull);
    });

    test('danh sách rỗng ⇒ null, không nổ', () {
      final p = RepairPartnerService.findPartnerForService<_P>(
        partners: const <_P>[],
        firestoreIdOf: (p) => p.firestoreId,
        idOf: (p) => p.id,
        nameOf: (p) => p.name,
        servicePartnerFirestoreId: 'partner_1786245140527',
        servicePartnerId: 1,
        servicePartnerName: 'SC',
      );
      expect(p, isNull);
    });
  });
}

void main() {
  _partnerMatchTests();
  const repairOrderId = 'rep_1788251281148_0918354188';
  const serviceFirestoreId = 'svc_1788260327031284';
  const partnerId = 40;

  String stable() => RepairPartnerService.buildPartnerDebtStableId(
    repairOrderId: repairOrderId,
    serviceFirestoreId: serviceFirestoreId,
    partnerId: partnerId,
  );

  String legacy(int cost) => RepairPartnerService.buildPartnerDebtFirestoreId(
    repairOrderId: repairOrderId,
    serviceFirestoreId: serviceFirestoreId,
    partnerId: partnerId,
    partnerCost: cost,
  );

  group('Mã nợ đối tác ổn định', () {
    test('đổi giá KHÔNG làm đổi mã nợ — đây là gốc của sự cố cũ', () {
      // Mã cũ: 400.000 và 300.000 ra hai mã khác nhau ⇒ đẻ bản nợ mồ côi.
      expect(legacy(400000), isNot(legacy(300000)));
      // Mã mới: không phụ thuộc giá.
      expect(stable(), stable());
    });

    test('mã ổn định không chứa số tiền', () {
      expect(stable().contains('400000'), isFalse);
      expect(stable().contains('300000'), isFalse);
    });

    test('khác dịch vụ ⇒ khác mã', () {
      final other = RepairPartnerService.buildPartnerDebtStableId(
        repairOrderId: repairOrderId,
        serviceFirestoreId: 'svc_khac',
        partnerId: partnerId,
      );
      expect(other, isNot(stable()));
    });

    test('khác đối tác ⇒ khác mã', () {
      final other = RepairPartnerService.buildPartnerDebtStableId(
        repairOrderId: repairOrderId,
        serviceFirestoreId: serviceFirestoreId,
        partnerId: 41,
      );
      expect(other, isNot(stable()));
    });

    test('khác đơn sửa ⇒ khác mã', () {
      final other = RepairPartnerService.buildPartnerDebtStableId(
        repairOrderId: 'rep_khac',
        serviceFirestoreId: serviceFirestoreId,
        partnerId: partnerId,
      );
      expect(other, isNot(stable()));
    });
  });

  group('Tiền tố dọn bản cũ', () {
    test('tiền tố bắt được MỌI mã cũ bất kể giá', () {
      final prefix = RepairPartnerService.buildPartnerDebtIdPrefix(
        repairOrderId: repairOrderId,
        serviceFirestoreId: serviceFirestoreId,
        partnerId: partnerId,
      );
      for (final cost in [400000, 300000, 0, 1, 999999999]) {
        expect(
          legacy(cost).startsWith(prefix),
          isTrue,
          reason: 'mã cũ giá $cost phải nằm trong diện dọn',
        );
      }
      // Bản mã mới cũng nằm trong diện dọn khi xoá dịch vụ.
      expect(stable().startsWith(prefix), isTrue);
    });

    test('đúng mã nợ thật đo được ngoài production', () {
      expect(
        legacy(400000),
        'debt_partner_debt_rep_1788251281148_0918354188_svc_1788260327031284_40_400000',
      );
      final prefix = RepairPartnerService.buildPartnerDebtIdPrefix(
        repairOrderId: repairOrderId,
        serviceFirestoreId: serviceFirestoreId,
        partnerId: partnerId,
      );
      expect(
        'debt_partner_debt_rep_1788251281148_0918354188_svc_1788260327031284_40_400000'
            .startsWith(prefix),
        isTrue,
      );
    });

    test('tiền tố KHÔNG bắt nhầm dịch vụ/đối tác khác', () {
      final prefix = RepairPartnerService.buildPartnerDebtIdPrefix(
        repairOrderId: repairOrderId,
        serviceFirestoreId: serviceFirestoreId,
        partnerId: partnerId,
      );
      final khacDoiTac = RepairPartnerService.buildPartnerDebtFirestoreId(
        repairOrderId: repairOrderId,
        serviceFirestoreId: serviceFirestoreId,
        partnerId: 4, // tiền tố '..._40' không được nuốt '..._4'
        partnerCost: 400000,
      );
      expect(khacDoiTac.startsWith(prefix), isFalse);
    });
  });
}
