import 'package:flutter/material.dart';

import '../services/ai_usage_logger.dart';
import '../services/user_service.dart';

/// AI usage dashboard — visible to Owner/Admin only.
/// Shows today's stats from the `ai_usage_logs` Firestore collection.
class AiUsageDashboardView extends StatefulWidget {
  const AiUsageDashboardView({super.key});

  @override
  State<AiUsageDashboardView> createState() => _AiUsageDashboardViewState();
}

class _AiUsageDashboardViewState extends State<AiUsageDashboardView> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};

  static const _kPurple = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null) throw Exception('Không tìm thấy shopId');
      final data = await AiUsageLogger.getShopSummaryToday(shopId);
      if (mounted) setState(() { _stats = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thống kê AI hôm nay'),
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Làm mới',
              onPressed: _load,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            tabs: [
              Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'Tổng quan'),
              Tab(icon: Icon(Icons.thumb_down_rounded, size: 18), text: 'Phản hồi xấu'),
            ],
          ),
        ),
        backgroundColor: const Color(0xFFF8FAFC),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : TabBarView(children: [_buildContent(), _buildNegativeFeedbackTab()]),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final cloudCalls = _stats['cloudCalls'] as int? ?? 0;
    final quickCalls = _stats['quickCalls'] as int? ?? 0;
    final positiveFeeds = _stats['positiveFeeds'] as int? ?? 0;
    final negativeFeeds = _stats['negativeFeeds'] as int? ?? 0;
    final activeUsers = _stats['activeUsers'] as int? ?? 0;
    final totalInteractions = _stats['totalInteractions'] as int? ?? 0;

    final totalFeeds = positiveFeeds + negativeFeeds;
    final satisfactionPct = totalFeeds == 0
        ? null
        : (positiveFeeds / totalFeeds * 100).round();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDateChip(),
          const SizedBox(height: 16),
          _buildRow([
            _StatCard(
              icon: Icons.cloud_rounded,
              label: 'Cloud AI',
              value: cloudCalls.toString(),
              color: _kPurple,
            ),
            _StatCard(
              icon: Icons.bolt_rounded,
              label: 'Quick Answer',
              value: quickCalls.toString(),
              color: const Color(0xFF0891B2),
            ),
          ]),
          const SizedBox(height: 12),
          _buildRow([
            _StatCard(
              icon: Icons.people_rounded,
              label: 'Người dùng',
              value: activeUsers.toString(),
              color: const Color(0xFF059669),
            ),
            _StatCard(
              icon: Icons.chat_bubble_rounded,
              label: 'Tổng tương tác',
              value: totalInteractions.toString(),
              color: const Color(0xFFD97706),
            ),
          ]),
          const SizedBox(height: 12),
          _buildFeedbackCard(positiveFeeds, negativeFeeds, satisfactionPct),
        ],
      ),
    );
  }

  Widget _buildNegativeFeedbackTab() {
    final items = (_stats['negativeFeedbackItems'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.thumb_up_alt_rounded, size: 48,
                color: const Color(0xFF059669).withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text('Không có phản hồi xấu hôm nay!',
                style: TextStyle(fontSize: 15, color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final item = items[i];
        final query = item['query'] as String? ?? '';
        final answer = item['answerSnippet'] as String? ?? '';
        final ts = item['timestamp'];
        String timeStr = '';
        if (ts != null) {
          try {
            final dt = (ts as dynamic).toDate() as DateTime;
            timeStr =
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          } catch (_) {}
        }
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFECACA)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      query.isEmpty ? '(câu hỏi trống)' : query,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B)),
                    ),
                  ),
                  if (timeStr.isNotEmpty)
                    Text(timeStr,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ),
              if (answer.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    answer,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF92400E)),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.thumb_down_rounded,
                      size: 13, color: Color(0xFFDC2626)),
                  SizedBox(width: 4),
                  Text('Không hài lòng',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateChip() {
    final now = DateTime.now();
    final label =
        'Hôm nay: ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kPurple.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_rounded, size: 14, color: _kPurple),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: _kPurple, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRow(List<Widget> children) {
    return Row(
      children: children
          .expand((w) => [Expanded(child: w), const SizedBox(width: 12)])
          .toList()
        ..removeLast(),
    );
  }

  Widget _buildFeedbackCard(int positive, int negative, int? pct) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.thumb_up_alt_rounded, size: 16, color: Color(0xFF4F46E5)),
              SizedBox(width: 6),
              Text('Phản hồi người dùng',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _FeedbackPill(
                icon: Icons.thumb_up_rounded,
                count: positive,
                color: const Color(0xFF059669),
                label: 'Hài lòng',
              ),
              const SizedBox(width: 10),
              _FeedbackPill(
                icon: Icons.thumb_down_rounded,
                count: negative,
                color: const Color(0xFFDC2626),
                label: 'Không hài lòng',
              ),
              if (pct != null) ...[
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$pct%',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF059669)),
                    ),
                    const Text('mức hài lòng',
                        style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedbackPill extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final String label;

  const _FeedbackPill({
    required this.icon,
    required this.count,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(count.toString(),
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
      ],
    );
  }
}
