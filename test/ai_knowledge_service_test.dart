import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/data/app_knowledge_base.dart';
import 'package:quanlyshop/data/help_center_repository.dart';
import 'package:quanlyshop/services/ai_knowledge_service.dart';

void main() {
  final kb = AiKnowledgeService.instance;

  group('AppKnowledgeBase — toàn vẹn dữ liệu', () {
    test('mọi mục có title / menuPath / tags / whatItDoes', () {
      for (final e in AppKnowledgeBase.entries) {
        expect(e.title.trim(), isNotEmpty, reason: e.id);
        expect(e.menuPath.trim(), isNotEmpty, reason: e.id);
        expect(e.whatItDoes.trim(), isNotEmpty, reason: e.id);
        expect(e.tags, isNotEmpty, reason: e.id);
      }
    });

    test('id mục là duy nhất', () {
      final ids = AppKnowledgeBase.entries.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('mọi id thuật ngữ tham chiếu đều tồn tại', () {
      for (final e in AppKnowledgeBase.entries) {
        for (final t in e.terms) {
          expect(AppKnowledgeBase.termById(t), isNotNull,
              reason: '${e.id} → thuật ngữ "$t" không có');
        }
      }
    });

    test('id thuật ngữ là duy nhất', () {
      final ids = AppKnowledgeBase.terms.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('looksLikeHowTo', () {
    test('nhận diện câu hỏi cách dùng / khái niệm', () {
      for (final q in const [
        'làm sao tạo đơn sửa',
        'chốt quỹ là gì',
        'miễn nợ ở đâu',
        'cách nhập kho công nợ',
        'dồn tích khác dòng tiền chỗ nào',
        'thu nợ khách như thế nào',
      ]) {
        expect(kb.looksLikeHowTo(q), isTrue, reason: q);
      }
    });

    test('bỏ qua câu hỏi số liệu thuần', () {
      for (final q in const [
        'doanh thu hôm nay',
        'lợi nhuận tháng này',
        'còn bao nhiêu hàng trong kho',
      ]) {
        expect(kb.looksLikeHowTo(q), isFalse, reason: q);
      }
    });
  });

  group('retrieve — truy hồi đúng mục', () {
    void expectTop(String q, String id, {String? role}) {
      final r = kb.retrieve(q, role: role);
      expect(r.entries.map((e) => e.id), contains(id),
          reason: 'câu "$q" nên khớp mục "$id"');
    }

    test('các câu hỏi tiêu biểu', () {
      expectTop('miễn nợ ở đâu', 'debt-waive');
      expectTop('cách chốt quỹ cuối ngày', 'cash-closing');
      expectTop('làm sao tạo đơn bán', 'sale-create');
      expectTop('nhập hàng nợ tiền nhà cung cấp', 'stock-in-debt');
      expectTop('đơn sửa cứ báo chưa có giá vốn', 'repair-cost');
      expectTop('có mấy hình thức thanh toán', 'sale-payment-methods');
      expectTop('sao 2 máy số liệu khác nhau', 'multi-device-sync');
    });

    test('lọc theo vai trò — kỹ thuật viên không thấy mục owner-only', () {
      final r = kb.retrieve('phân quyền nhân viên', role: 'technician');
      expect(r.entries.map((e) => e.id), isNot(contains('roles-permissions')));
      final r2 = kb.retrieve('phân quyền nhân viên', role: 'owner');
      expect(r2.entries.map((e) => e.id), contains('roles-permissions'));
    });

    test('gắn kèm thuật ngữ liên quan', () {
      final r = kb.retrieve('dồn tích là gì');
      expect(r.terms.map((t) => t.id), contains('don-tich'));
    });
  });

  group('offlineAnswer', () {
    test('trả lời how-to kèm đường dẫn menu', () {
      final a = kb.offlineAnswer('làm sao tạo đơn sửa');
      expect(a, isNotNull);
      expect(a, contains('📍'));
      expect(a!.toLowerCase(), contains('sửa'));
    });

    test('null cho câu hỏi số liệu', () {
      expect(kb.offlineAnswer('doanh thu hôm nay bao nhiêu'), isNull);
    });

    test('null khi không có mục nào khớp', () {
      expect(kb.offlineAnswer('cách nấu phở bò'), isNull);
    });
  });

  group('buildCloudContext', () {
    test('có nội dung cho câu hỏi hợp lệ, tôn trọng giới hạn ký tự', () {
      final ctx = kb.buildCloudContext('cách chốt quỹ', maxChars: 2600);
      expect(ctx, isNotEmpty);
      expect(ctx.length, lessThanOrEqualTo(2601));
      expect(ctx, contains('Sổ quỹ'));
    });

    test('rỗng cho câu vô nghĩa', () {
      expect(kb.buildCloudContext('asdfghjkl qwerty'), isEmpty);
    });
  });

  group('Help Center bridge', () {
    test('topics gộp cả mục curated lẫn mục sinh từ KB', () {
      final kbBacked =
          HelpCenterRepository.topics.where((t) => t.id.startsWith('kb-'));
      expect(kbBacked.length, AppKnowledgeBase.entries.length);
    });

    test('mọi topic sinh từ KB có categoryId hợp lệ', () {
      final catIds = HelpCenterRepository.categories.map((c) => c.id).toSet();
      for (final t in HelpCenterRepository.topics.where(
        (t) => t.id.startsWith('kb-'),
      )) {
        expect(catIds, contains(t.categoryId), reason: t.id);
        expect(t.steps, isNotEmpty, reason: t.id);
      }
    });
  });
}
