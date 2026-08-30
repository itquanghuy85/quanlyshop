import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/data/app_knowledge_base.dart';
import 'package:quanlyshop/data/discovery_checklist.dart';
import 'package:quanlyshop/services/discovery_service.dart';

void main() {
  group('AppKnowledgeBase — nhóm tính năng', () {
    test('id nhóm là duy nhất', () {
      final ids = AppKnowledgeBase.areas.map((a) => a.$1).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('mọi mục thuộc đúng 1 nhóm đã khai báo; tổng phần = toàn bộ', () {
      final areaIds = AppKnowledgeBase.areas.map((a) => a.$1).toSet();
      var covered = 0;
      for (final a in AppKnowledgeBase.areas) {
        covered += AppKnowledgeBase.entriesByArea(a.$1).length;
      }
      expect(covered, AppKnowledgeBase.entries.length);
      for (final e in AppKnowledgeBase.entries) {
        expect(areaIds, contains(AppKnowledgeBase.areaOf(e.id)), reason: e.id);
      }
    });

    test('sampleQuestionSpread trả về tối đa n câu, không rỗng, không trùng', () {
      final s = AppKnowledgeBase.sampleQuestionSpread(3, seed: 42);
      expect(s.length, lessThanOrEqualTo(3));
      expect(s.length, greaterThan(0));
      expect(s.toSet().length, s.length);
      expect(s.every((q) => q.trim().isNotEmpty), isTrue);
    });

    test('sampleQuestionSpread ổn định theo seed', () {
      expect(
        AppKnowledgeBase.sampleQuestionSpread(3, seed: 7),
        AppKnowledgeBase.sampleQuestionSpread(3, seed: 7),
      );
    });

    test('tipOfTheDay trả về mẹo + id mục hợp lệ', () {
      final tod = AppKnowledgeBase.tipOfTheDay(DateTime(2026, 3, 15));
      expect(tod, isNotNull);
      expect(tod!.tip.trim(), isNotEmpty);
      expect(AppKnowledgeBase.entryById(tod.entryId), isNotNull);
    });
  });

  group('Discovery checklist', () {
    test('id nhiệm vụ là duy nhất', () {
      final ids = kDiscoveryTasks.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('mọi nhiệm vụ trỏ tới mục KB có thật', () {
      for (final t in kDiscoveryTasks) {
        expect(AppKnowledgeBase.entryById(t.kbEntryId), isNotNull,
            reason: '${t.id} → ${t.kbEntryId}');
      }
    });

    test('lọc theo vai trò: kỹ thuật viên không thấy nhiệm vụ owner-only', () {
      final tech = DiscoveryService.tasksFor('technician').map((t) => t.id);
      expect(tech, isNot(contains('permissions')));
      expect(tech, isNot(contains('daily-report')));
      expect(tech, contains('create-repair'));

      final owner = DiscoveryService.tasksFor('owner').map((t) => t.id).toList();
      expect(owner.length, kDiscoveryTasks.length);
    });

    test('vai trò rỗng → thấy tất cả', () {
      expect(DiscoveryService.tasksFor('').length, kDiscoveryTasks.length);
      expect(DiscoveryService.tasksFor(null).length, kDiscoveryTasks.length);
    });
  });
}
