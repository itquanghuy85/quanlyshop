import 'package:flutter/material.dart';

import '../data/discovery_checklist.dart';
import '../services/discovery_service.dart';

/// Thẻ "Khám phá HULUCA" ở Trang chủ — checklist giúp người dùng mới đi qua
/// hết các tính năng chính. Tự ẩn khi hoàn thành hết hoặc khi người dùng bấm Ẩn.
class DiscoveryCard extends StatefulWidget {
  final String userRole;

  /// Chuyển tab dưới (id: home/sales/repairs/inventory/finance).
  final void Function(String tabId) onOpenTab;

  /// Mở hướng dẫn cho một mục KB (id không kèm tiền tố "kb-").
  final void Function(String kbEntryId) onOpenGuide;

  const DiscoveryCard({
    super.key,
    required this.userRole,
    required this.onOpenTab,
    required this.onOpenGuide,
  });

  @override
  State<DiscoveryCard> createState() => _DiscoveryCardState();
}

class _DiscoveryCardState extends State<DiscoveryCard> {
  DiscoveryStatus? _status;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final s = await DiscoveryService.load(widget.userRole);
    if (mounted) setState(() => _status = s);
  }

  Future<void> _openTask(DiscoveryTask t) async {
    await DiscoveryService.markDone(t.id);
    if (!mounted) return;
    if (t.tabId != null) {
      widget.onOpenTab(t.tabId!);
    } else {
      widget.onOpenGuide(t.kbEntryId);
    }
    _reload();
  }

  Future<void> _toggleTask(DiscoveryTask t, bool done) async {
    await DiscoveryService.markDone(t.id, done: done);
    _reload();
  }

  Future<void> _dismiss() async {
    await DiscoveryService.setDismissed(true);
    if (mounted) setState(() => _status = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    if (s == null || !s.shouldShow) return const SizedBox.shrink();

    final pct = (s.progress * 100).round();
    final remaining = s.tasks.where((t) => !s.doneIds.contains(t.id)).toList();
    final visible = _expanded ? s.tasks : remaining.take(3).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 4),
            child: Row(
              children: [
                Icon(Icons.rocket_launch_rounded,
                    size: 18, color: Colors.indigo.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Khám phá HULUCA  ·  ${s.done}/${s.total}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.indigo.shade800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _dismiss,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text('Ẩn',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: s.progress,
                minHeight: 6,
                backgroundColor: Colors.indigo.shade100,
                valueColor:
                    AlwaysStoppedAnimation(Colors.indigo.shade400),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
            child: Text('Hoàn thành $pct% — chạm từng việc để bắt đầu',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ),
          ...visible.map((t) => _taskRow(t, s.doneIds.contains(t.id))),
          if (remaining.length > 3 || _expanded)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18),
                label: Text(_expanded ? 'Thu gọn' : 'Xem tất cả'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _taskRow(DiscoveryTask t, bool done) {
    return InkWell(
      onTap: () => _openTask(t),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: done,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) => _toggleTask(t, v ?? false),
            ),
            Icon(t.icon, size: 16, color: Colors.indigo.shade400),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? Colors.grey.shade500 : Colors.black87,
                    ),
                  ),
                  if (!done)
                    Text(t.hint,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
