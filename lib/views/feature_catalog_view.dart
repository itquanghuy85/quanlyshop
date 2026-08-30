import 'package:flutter/material.dart';

import '../data/app_knowledge_base.dart';
import '../services/ai_nav_bridge.dart';
import '../utils/vietnamese_utils.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/responsive_wrapper.dart';

/// "Tất cả tính năng" — bản đồ mọi tính năng của app, dựng từ
/// [AppKnowledgeBase]. Giúp người dùng lướt xem hết những gì app làm được.
class FeatureCatalogView extends StatefulWidget {
  final String userRole;
  const FeatureCatalogView({super.key, this.userRole = ''});

  @override
  State<FeatureCatalogView> createState() => _FeatureCatalogViewState();
}

class _FeatureCatalogViewState extends State<FeatureCatalogView> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _visible(List<String> audience) {
    final r = widget.userRole.toLowerCase();
    if (audience.contains('all') || r.isEmpty) return true;
    if (r == 'owner' || r == 'admin' || r == 'super_admin') return true;
    return audience.contains(r);
  }

  bool _matches(KbEntry e, String nq) {
    if (nq.isEmpty) return true;
    final hay = VietnameseUtils.normalize([
      e.title,
      e.whatItDoes,
      e.menuPath,
      e.tags.join(' '),
      e.sampleQuestions.join(' '),
    ].join(' '));
    return hay.contains(nq);
  }

  @override
  Widget build(BuildContext context) {
    final nq = VietnameseUtils.normalize(_q.trim());
    var shown = 0;

    return Scaffold(
      appBar: CustomAppBar.build(title: 'Tất cả tính năng'),
      body: ResponsiveCenter(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Tìm tính năng, vd "chốt quỹ", "trả góp"...',
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                children: [
                  for (final area in AppKnowledgeBase.areas)
                    ..._areaSection(area.$1, area.$2, nq, (n) => shown += n),
                  if (nq.isNotEmpty)
                    Builder(builder: (_) {
                      return shown == 0
                          ? Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Text(
                                  'Không có tính năng nào khớp "$_q".',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ),
                            )
                          : const SizedBox.shrink();
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _areaSection(
    String areaId,
    String label,
    String nq,
    void Function(int) countCb,
  ) {
    final entries = AppKnowledgeBase.entriesByArea(areaId)
        .where((e) => _visible(e.audience) && _matches(e, nq))
        .toList();
    if (entries.isEmpty) return const [];
    countCb(entries.length);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
            letterSpacing: 0.4,
          ),
        ),
      ),
      for (final e in entries) _row(e),
    ];
  }

  Widget _row(KbEntry e) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Text(
          e.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          e.whatItDoes,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: () => _openDetail(e),
      ),
    );
  }

  void _openDetail(KbEntry e) {
    showAppBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final terms = [
          for (final id in e.terms)
            if (AppKnowledgeBase.termById(id) case final t?) t,
        ];
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, controller) => SingleChildScrollView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              18,
              14,
              18,
              14 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  e.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _kv(Icons.place_outlined, e.menuPath),
                const SizedBox(height: 12),
                Text(e.whatItDoes, style: const TextStyle(fontSize: 14, height: 1.4)),
                if (e.whenToUse.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Khi nào dùng: ${e.whenToUse}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (e.steps.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Các bước',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  for (var i = 0; i < e.steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${i + 1}. ',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          Expanded(
                            child: Text(e.steps[i],
                                style: const TextStyle(fontSize: 13, height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                ],
                if (e.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final note in e.notes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $note',
                          style: TextStyle(
                              fontSize: 12.5, color: Colors.orange.shade900)),
                    ),
                ],
                if (terms.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('Thuật ngữ',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  for (final t in terms)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${t.term}: ${t.definition}',
                          style: const TextStyle(fontSize: 12.5, height: 1.4)),
                    ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      final q = e.sampleQuestions.isNotEmpty
                          ? e.sampleQuestions.first
                          : e.title;
                      Navigator.of(sheetCtx).pop();
                      Navigator.of(context).popUntil((r) => r.isFirst);
                      AiNavBridge.ask(q);
                    },
                    icon: const Icon(Icons.smart_toy_outlined, size: 18),
                    label: const Text('Hỏi AI Trợ Lý về mục này'),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _kv(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }
}

/// Dùng chung: mở màn "Tất cả tính năng".
void openFeatureCatalog(BuildContext context, {String userRole = ''}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(builder: (_) => FeatureCatalogView(userRole: userRole)),
  );
}
