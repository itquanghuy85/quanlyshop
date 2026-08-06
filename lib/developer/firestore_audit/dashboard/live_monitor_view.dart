import 'dart:async';
import 'package:flutter/material.dart';

import '../models/audit_event.dart';
import '../services/firestore_audit_service.dart';
import '../widgets/live_event_tile.dart';

/// Live monitor — hiển thị sự kiện Firestore Read theo thời gian thực.
class LiveMonitorView extends StatefulWidget {
  const LiveMonitorView({super.key});

  @override
  State<LiveMonitorView> createState() => _LiveMonitorViewState();
}

class _LiveMonitorViewState extends State<LiveMonitorView> {
  final List<AuditEvent> _events = [];
  StreamSubscription<AuditEvent>? _sub;
  bool _paused = false;
  bool _compact = false;
  String _filterCollection = '';
  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  static const int _maxDisplay = 200;

  @override
  void initState() {
    super.initState();
    _events.addAll(
      FirestoreAuditService.instance.recentEvents.reversed.take(50),
    );
    _sub = FirestoreAuditService.instance.liveStream.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onEvent(AuditEvent event) {
    if (_paused) return;
    if (!mounted) return;
    setState(() {
      _events.insert(0, event);
      if (_events.length > _maxDisplay) _events.removeLast();
    });
  }

  List<AuditEvent> get _filtered {
    if (_filterCollection.isEmpty) return _events;
    final q = _filterCollection.toLowerCase();
    return _events
        .where(
          (e) =>
              e.collection.toLowerCase().contains(q) ||
              e.callerService.toLowerCase().contains(q) ||
              e.callerMethod.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF2F3F7);
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'Live Monitor',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _compact ? Icons.view_agenda_outlined : Icons.view_list_outlined,
              size: 20,
            ),
            tooltip: _compact ? 'Chi tiết' : 'Gọn',
            onPressed: () => setState(() => _compact = !_compact),
          ),
          IconButton(
            icon: Icon(
              _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 22,
              color: _paused ? Colors.green : Colors.orange,
            ),
            tooltip: _paused ? 'Tiếp tục' : 'Tạm dừng',
            onPressed: () => setState(() => _paused = !_paused),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, size: 20),
            tooltip: 'Xóa màn hình',
            onPressed: () => setState(() => _events.clear()),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _SearchBar(
              controller: _searchCtrl,
              hint: 'Lọc collection / service / method...',
              onChanged: (v) => setState(() => _filterCollection = v),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            color: isDark ? const Color(0xFF16162A) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                _StatusDot(
                  active: !_paused,
                  label: _paused ? 'PAUSED' : 'LIVE',
                ),
                const SizedBox(width: 12),
                Text(
                  '${filtered.length} events',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (_paused)
                  Text(
                    'Scroll để xem lịch sử',
                    style: TextStyle(
                      color: Colors.orange.shade400,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sensors_off_rounded,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          FirestoreAuditService.instance.isEnabled
                              ? 'Đang chờ sự kiện Firestore...'
                              : 'Audit Monitor đang TẮT',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) =>
                        LiveEventTile(event: filtered[i], compact: _compact),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool active;
  final String label;
  const _StatusDot({required this.active, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.green : Colors.orange;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.5, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          builder: (_, v, __) => Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color.withOpacity(active ? v : 1.0),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: 13,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF0F0F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
      ),
    );
  }
}
