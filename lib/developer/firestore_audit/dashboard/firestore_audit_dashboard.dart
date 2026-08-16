import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/audit_event.dart';
import '../models/audit_stats.dart';
import '../services/firestore_audit_service.dart';
import '../export/audit_export_service.dart';
import '../widgets/stats_card.dart';
import '../widgets/read_bar_chart.dart';
import '../widgets/top_list_section.dart';
import '../widgets/live_event_tile.dart';
import 'live_monitor_view.dart';
import 'collection_detail_view.dart';

/// Main dashboard của Firestore Audit Monitor.
class FirestoreAuditDashboard extends StatefulWidget {
  const FirestoreAuditDashboard({super.key});

  @override
  State<FirestoreAuditDashboard> createState() =>
      _FirestoreAuditDashboardState();
}

class _FirestoreAuditDashboardState extends State<FirestoreAuditDashboard>
    with TickerProviderStateMixin {
  final _service = FirestoreAuditService.instance;
  StreamSubscription<AuditSessionStats>? _statsSub;
  AuditSessionStats? _stats;
  bool _isDark = true;
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _sortKey = 'reads'; // reads / calls / time
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _stats = _service.stats;
    _statsSub = _service.statsStream.listen((s) {
      if (mounted) setState(() => _stats = s);
    });
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = _isDark ? ThemeData.dark() : ThemeData.light();
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: const Color(0xFF6C63FF),
        ),
      ),
      child: Builder(builder: (ctx) => _buildScaffold(ctx)),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final isDark = _isDark;
    final bgColor = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF2F3F7);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(context, isDark),
      body: !_service.isEnabled
          ? _buildDisabledState(context, isDark)
          : _buildTabbedContent(context, isDark),
    );
  }

  AppBar _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Firestore Audit Monitor',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          Text(
            'Developer Tool · Read-Only',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.normal,
              color: Colors.white60,
            ),
          ),
        ],
      ),
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      foregroundColor: isDark ? Colors.white : Colors.black87,
      elevation: 0,
      actions: [
        // Kill switch toggle
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _service.isEnabled ? 'ON' : 'OFF',
                style: TextStyle(
                  color: _service.isEnabled ? Colors.green : Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Switch(
                value: _service.isEnabled,
                onChanged: (v) async {
                  await _service.setEnabled(v);
                  if (mounted) setState(() {});
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeThumbColor: Colors.green,
              ),
            ],
          ),
        ),
        // Dark mode toggle
        IconButton(
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 20,
          ),
          tooltip: isDark ? 'Light mode' : 'Dark mode',
          onPressed: () => setState(() => _isDark = !_isDark),
        ),
        // Export menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.download_outlined, size: 20),
          tooltip: 'Export',
          onSelected: _handleExport,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'json', child: Text('Export JSON')),
            PopupMenuItem(value: 'csv', child: Text('Export CSV')),
            PopupMenuItem(value: 'markdown', child: Text('Export Markdown')),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'copy_json',
              child: Text('Copy JSON to clipboard'),
            ),
          ],
        ),
        // Reset
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 20),
          tooltip: 'Reset',
          onPressed: _confirmReset,
        ),
      ],
      bottom: TabBar(
        controller: _tabCtrl,
        indicatorColor: const Color(0xFF6C63FF),
        labelColor: const Color(0xFF6C63FF),
        unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Summary'),
          Tab(
            icon: Icon(Icons.storage_outlined, size: 18),
            text: 'Collections',
          ),
          Tab(icon: Icon(Icons.code_outlined, size: 18), text: 'Callers'),
          Tab(icon: Icon(Icons.sensors_outlined, size: 18), text: 'Live'),
        ],
      ),
    );
  }

  Widget _buildDisabledState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sensors_off_rounded,
            size: 64,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 16),
          Text(
            'Firestore Audit Monitor',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hiện đang TẮT (Kill Switch = OFF)',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Khi tắt: không theo dõi, không ghi log, không tốn tài nguyên.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            icon: const Icon(Icons.power_settings_new_rounded),
            label: const Text('Bật Monitor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () async {
              await _service.setEnabled(true);
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 12),
          Text(
            '⚠️ Chỉ dùng khi debug. Không deploy production khi đang ON.',
            style: TextStyle(color: Colors.orange.shade400, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildTabbedContent(BuildContext context, bool isDark) {
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _buildSummaryTab(context, isDark),
        _buildCollectionsTab(context, isDark),
        _buildCallersTab(context, isDark),
        const LiveMonitorView(),
      ],
    );
  }

  // ── Summary Tab ────────────────────────────────────────────────────────────

  Widget _buildSummaryTab(BuildContext context, bool isDark) {
    final stats = _stats ?? _service.stats;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Top stats cards
        _buildStatsGrid(stats, isDark),
        const SizedBox(height: 14),

        // Reads per operation
        if (stats.byOperation.isNotEmpty) ...[
          _SectionHeader('Reads by Operation', isDark),
          const SizedBox(height: 8),
          _Card(
            isDark: isDark,
            child: AuditBarChart.fromMap(
              stats.byOperation.map((k, v) => MapEntry(k.label, v)),
              barColor: Colors.purple,
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Top collections chart
        if (stats.byCollection.isNotEmpty) ...[
          _SectionHeader('Top Collections (Est. Reads)', isDark),
          const SizedBox(height: 8),
          _Card(
            isDark: isDark,
            child: AuditBarChart.fromMap(
              Map.fromEntries(
                stats.topCollections
                    .take(8)
                    .map((e) => MapEntry(e.key, e.value.totalEstimatedReads)),
              ),
              barColor: Colors.red,
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Active listeners
        if (_service.activeListeners.isNotEmpty) ...[
          _SectionHeader('Active Listeners (snapshots / listen)', isDark),
          const SizedBox(height: 8),
          _Card(
            isDark: isDark,
            child: Column(
              children: _service.activeListeners.entries
                  .map(
                    (e) => _ListenerRow(
                      collection: e.key,
                      count: e.value,
                      isDark: isDark,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Top services
        if (stats.byService.isNotEmpty) ...[
          TopListSection.fromMap(
            'Top Services (Est. Reads)',
            stats.byService,
            accentColor: Colors.blue,
          ),
          const SizedBox(height: 14),
        ],

        // Top screens
        if (stats.byScreen.isNotEmpty) ...[
          TopListSection.fromMap(
            'Top Screens (Est. Reads)',
            stats.byScreen,
            accentColor: Colors.teal,
          ),
          const SizedBox(height: 14),
        ],

        // Recent events
        if (_service.recentEvents.isNotEmpty) ...[
          _SectionHeader('Recent Events (last 10)', isDark),
          const SizedBox(height: 8),
          ..._service.recentEvents.reversed
              .take(10)
              .map((e) => LiveEventTile(event: e, compact: true)),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.sensors_outlined, size: 16),
              label: const Text('Ver Live Monitor →'),
              onPressed: () => _tabCtrl.animateTo(3),
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStatsGrid(AuditSessionStats stats, bool isDark) {
    final sessionMins = stats.sessionDuration.inMinutes;
    final rpmStr = stats.readsPerMinute.toStringAsFixed(1);

    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        AuditStatsCard(
          label: 'Est. Reads (Session)',
          value: _fmt(stats.totalEstimatedReads),
          subtitle: '${stats.totalDocuments} docs total',
          icon: Icons.menu_book_outlined,
          color: Colors.red,
        ),
        AuditStatsCard(
          label: 'Daily Total',
          value: _fmt(_service.dailyReadsTotal),
          subtitle: 'accumulated today',
          icon: Icons.today_outlined,
          color: Colors.deepOrange,
        ),
        AuditStatsCard(
          label: 'Reads/Minute',
          value: rpmStr,
          subtitle: '${(stats.readsPerHour).toStringAsFixed(0)}/hr est.',
          icon: Icons.speed_outlined,
          color: Colors.blue,
        ),
        AuditStatsCard(
          label: 'Events',
          value: _fmt(stats.totalEvents),
          subtitle: '${sessionMins}m session',
          icon: Icons.bolt_outlined,
          color: Colors.purple,
        ),
        AuditStatsCard(
          label: 'Collections',
          value: '${stats.byCollection.length}',
          subtitle: 'tracked',
          icon: Icons.storage_outlined,
          color: Colors.green,
        ),
        AuditStatsCard(
          label: 'Active Listeners',
          value: '${_service.activeListeners.values.fold(0, (a, b) => a + b)}',
          subtitle: '${_service.activeListeners.length} collections',
          icon: Icons.sensors_outlined,
          color: Colors.orange,
          onTap: () => _tabCtrl.animateTo(0),
        ),
      ],
    );
  }

  // ── Collections Tab ────────────────────────────────────────────────────────

  Widget _buildCollectionsTab(BuildContext context, bool isDark) {
    final stats = _stats ?? _service.stats;
    var items = stats.topCollections;

    // Apply search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((e) => e.key.toLowerCase().contains(q)).toList();
    }

    // Apply sort
    switch (_sortKey) {
      case 'calls':
        items.sort((a, b) => b.value.totalCalls.compareTo(a.value.totalCalls));
        break;
      case 'time':
        items.sort(
          (a, b) => b.value.totalTimeMs.compareTo(a.value.totalTimeMs),
        );
        break;
      default:
        items.sort(
          (a, b) => b.value.totalEstimatedReads.compareTo(
            a.value.totalEstimatedReads,
          ),
        );
    }

    return Column(
      children: [
        // Search + sort bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: _SearchField(
                  hint: 'Tìm collection...',
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 8),
              _SortButton(
                current: _sortKey,
                options: const {
                  'reads': 'Reads',
                  'calls': 'Calls',
                  'time': 'Time',
                },
                onChanged: (v) => setState(() => _sortKey = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    'Chưa có dữ liệu',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final entry = items[i];
                    final stat = entry.value;
                    return _CollectionTile(
                      collection: entry.key,
                      stat: stat,
                      rank: i + 1,
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CollectionDetailView(collection: entry.key),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Callers Tab ────────────────────────────────────────────────────────────

  Widget _buildCallersTab(BuildContext context, bool isDark) {
    final stats = _stats ?? _service.stats;
    var callers = stats.topCallers;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      callers = callers
          .where(
            (e) =>
                e.value.service.toLowerCase().contains(q) ||
                e.value.method.toLowerCase().contains(q),
          )
          .toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: _SearchField(
            hint: 'Tìm service / method...',
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        Expanded(
          child: callers.isEmpty
              ? Center(
                  child: Text(
                    'Chưa có dữ liệu',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: callers.length,
                  itemBuilder: (ctx, i) {
                    final entry = callers[i];
                    final caller = entry.value;
                    return _CallerTile(
                      caller: caller,
                      rank: i + 1,
                      isDark: isDark,
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _handleExport(String type) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      String content;
      String filename;
      switch (type) {
        case 'json':
          content = AuditExportService.exportJson();
          filename =
              'firestore_audit_${DateTime.now().millisecondsSinceEpoch}.json';
          await AuditExportService.shareAsText(content, filename);
          break;
        case 'csv':
          content = AuditExportService.exportCsv();
          filename =
              'firestore_audit_${DateTime.now().millisecondsSinceEpoch}.csv';
          await AuditExportService.shareAsText(content, filename);
          break;
        case 'markdown':
          content = AuditExportService.exportMarkdown();
          filename =
              'firestore_audit_${DateTime.now().millisecondsSinceEpoch}.md';
          await AuditExportService.shareAsText(content, filename);
          break;
        case 'copy_json':
          content = AuditExportService.exportJson();
          await Clipboard.setData(ClipboardData(text: content));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ JSON đã copy vào clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          break;
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _confirmReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Statistics'),
        content: const Text(
          'Xóa toàn bộ thống kê session hiện tại?\n(Daily total cũng bị reset)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.resetAll();
      if (mounted) setState(() {});
    }
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _Card({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionHeader(this.title, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: isDark ? Colors.white : Colors.black87,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  final String collection;
  final CollectionStat stat;
  final int rank;
  final bool isDark;
  final VoidCallback? onTap;

  const _CollectionTile({
    required this.collection,
    required this.stat,
    required this.rank,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final sub = isDark ? Colors.white54 : Colors.black45;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(color: Colors.red.withOpacity(0.5), width: 3),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: sub,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stat.totalCalls} calls · avg ${stat.avgDocuments.toStringAsFixed(0)} docs · ${stat.topCaller}',
                    style: TextStyle(color: sub, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_fmt(stat.totalEstimatedReads)}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text('reads', style: TextStyle(color: sub, fontSize: 10)),
              ],
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18, color: sub),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _CallerTile extends StatelessWidget {
  final CallerStat caller;
  final int rank;
  final bool isDark;

  const _CallerTile({
    required this.caller,
    required this.rank,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final sub = isDark ? Colors.white54 : Colors.black45;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: Colors.blue.withOpacity(0.5), width: 3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: TextStyle(
                color: sub,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caller.service,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '.${caller.method}',
                  style: TextStyle(color: sub, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  caller.collections.take(3).join(', '),
                  style: TextStyle(color: Colors.blue.shade400, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_fmt(caller.totalEstimatedReads)}',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                '${caller.totalCalls} calls',
                style: TextStyle(color: sub, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _ListenerRow extends StatelessWidget {
  final String collection;
  final int count;
  final bool isDark;

  const _ListenerRow({
    required this.collection,
    required this.count,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(collection, style: const TextStyle(fontSize: 13)),
          ),
          Text(
            '×$count',
            style: TextStyle(
              color: count > 2 ? Colors.red : Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
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
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final String current;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  const _SortButton({
    required this.current,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 16, color: Color(0xFF6C63FF)),
            const SizedBox(width: 4),
            Text(
              options[current] ?? current,
              style: const TextStyle(
                color: Color(0xFF6C63FF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (_) => options.entries
          .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
    );
  }
}
