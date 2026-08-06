import 'package:flutter/material.dart';

import '../models/audit_event.dart';
import '../models/audit_stats.dart';
import '../services/firestore_audit_service.dart';
import '../widgets/read_bar_chart.dart';
import '../widgets/live_event_tile.dart';

/// Màn hình chi tiết cho một Collection.
class CollectionDetailView extends StatelessWidget {
  final String collection;

  const CollectionDetailView({super.key, required this.collection});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreAuditService.instance;
    final stat = service.stats.byCollection[collection];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF2F3F7);
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final subColor = isDark ? Colors.white60 : Colors.black54;

    // Recent events for this collection
    final events = service.recentEvents
        .where((e) => e.collection == collection)
        .toList()
        .reversed
        .take(50)
        .toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(collection,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const Text('Collection Detail',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
      ),
      body: stat == null
          ? Center(
              child: Text('Chưa có dữ liệu', style: TextStyle(color: subColor)))
          : _buildBody(context, stat, events, cardBg, subColor, isDark),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CollectionStat stat,
    List<dynamic> events,
    Color cardBg,
    Color subColor,
    bool isDark,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary grid
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _InfoCard('Est. Reads', '${stat.totalEstimatedReads}', Colors.red, Icons.menu_book_outlined, cardBg, isDark),
            _InfoCard('Total Calls', '${stat.totalCalls}', Colors.blue, Icons.call_outlined, cardBg, isDark),
            _InfoCard('Avg Docs', stat.avgDocuments.toStringAsFixed(1), Colors.green, Icons.article_outlined, cardBg, isDark),
            _InfoCard('Avg Time', '${stat.avgTimeMs.toStringAsFixed(0)}ms', Colors.orange, Icons.timer_outlined, cardBg, isDark),
          ],
        ),
        const SizedBox(height: 16),
        // Info rows
        _DetailCard(
          child: Column(
            children: [
              _InfoRow('Active Listeners', '${stat.activeListeners}', subColor),
              _InfoRow('Top Caller', stat.topCaller, subColor),
              _InfoRow(
                'Last Called',
                stat.lastCalledAt != null
                    ? _formatDateTime(stat.lastCalledAt!)
                    : '—',
                subColor,
              ),
            ],
          ),
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        // Operations breakdown
        if (stat.operationCounts.isNotEmpty) ...[
          _SectionTitle('Operations', isDark),
          const SizedBox(height: 8),
          AuditBarChart.fromMap(
            stat.operationCounts.map((k, v) => MapEntry(k.label, v)),
            barColor: Colors.purple,
          ),
          const SizedBox(height: 16),
        ],
        // Callers breakdown
        if (stat.callerServiceCounts.isNotEmpty) ...[
          _SectionTitle('Callers', isDark),
          const SizedBox(height: 8),
          AuditBarChart.fromMap(stat.callerServiceCounts, barColor: Colors.blue),
          const SizedBox(height: 16),
        ],
        // Sparkline
        if (stat.recentReadCounts.isNotEmpty) ...[
          _SectionTitle('Read Trend (recent)', isDark),
          const SizedBox(height: 8),
          _DetailCard(
            child: AuditSparkline(
              values: stat.recentReadCounts,
              color: Colors.red,
              height: 50,
            ),
            isDark: isDark,
          ),
          const SizedBox(height: 16),
        ],
        // Recent events
        if (events.isNotEmpty) ...[
          _SectionTitle('Recent Events (${events.length})', isDark),
          const SizedBox(height: 8),
          ...events.map((e) => LiveEventTile(event: e as dynamic, compact: true)),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final Color bg;
  final bool isDark;

  const _InfoCard(this.label, this.value, this.color, this.icon, this.bg, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.black45)),
          ]),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color subColor;

  const _InfoRow(this.label, this.value, this.subColor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: TextStyle(color: subColor, fontSize: 12))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _DetailCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionTitle(this.text, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: isDark ? Colors.white : Colors.black87));
  }
}
