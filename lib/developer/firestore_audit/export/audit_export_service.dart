import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../models/audit_event.dart';
import '../services/firestore_audit_service.dart';

/// Xuất dữ liệu audit ra JSON / CSV / Markdown.
class AuditExportService {
  AuditExportService._();

  /// Xuất JSON đầy đủ.
  static String exportJson() {
    final service = FirestoreAuditService.instance;
    final stats = service.stats;
    final events = service.recentEvents;

    final data = {
      'exportedAt': DateTime.now().toIso8601String(),
      'sessionStart': stats.sessionStart.toIso8601String(),
      'sessionDurationSeconds': stats.sessionDuration.inSeconds,
      'summary': {
        'totalEvents': stats.totalEvents,
        'totalEstimatedReads': stats.totalEstimatedReads,
        'totalDocuments': stats.totalDocuments,
        'dailyReadsTotal': service.dailyReadsTotal,
        'readsPerMinute': stats.readsPerMinute.toStringAsFixed(2),
        'activeListeners': stats.activeListenerCount,
      },
      'topCollections': stats.topCollections
          .take(10)
          .map(
            (e) => {
              'collection': e.key,
              'estimatedReads': e.value.totalEstimatedReads,
              'totalCalls': e.value.totalCalls,
              'avgDocuments': e.value.avgDocuments.toStringAsFixed(1),
              'avgTimeMs': e.value.avgTimeMs.toStringAsFixed(0),
              'topCaller': e.value.topCaller,
              'activeListeners': e.value.activeListeners,
            },
          )
          .toList(),
      'topCallers': stats.topCallers
          .take(10)
          .map(
            (e) => {
              'service': e.value.service,
              'method': e.value.method,
              'estimatedReads': e.value.totalEstimatedReads,
              'totalCalls': e.value.totalCalls,
              'collections': e.value.collections.toList(),
            },
          )
          .toList(),
      'topScreens': stats.topScreens
          .take(10)
          .map((e) => {'screen': e.key, 'estimatedReads': e.value})
          .toList(),
      'byOperation': stats.byOperation.map((k, v) => MapEntry(k.label, v)),
      'recentEvents': events.take(100).map((e) => e.toJson()).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  /// Xuất CSV các sự kiện gần đây.
  static String exportCsv() {
    final events = FirestoreAuditService.instance.recentEvents;
    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,collection,operation,callerService,callerMethod,callerScreen,documentCount,estimatedReads,executionTimeMs,isActiveListener,queryInfo',
    );

    for (final e in events) {
      buffer.writeln(
        [
          e.timestamp.toIso8601String(),
          _csvEscape(e.collection),
          e.operation.label,
          _csvEscape(e.callerService),
          _csvEscape(e.callerMethod),
          _csvEscape(e.callerScreen ?? ''),
          e.documentCount,
          e.estimatedReads,
          e.executionTimeMs,
          e.isActiveListener ? '1' : '0',
          _csvEscape(e.queryInfo ?? ''),
        ].join(','),
      );
    }
    return buffer.toString();
  }

  /// Xuất báo cáo Markdown.
  static String exportMarkdown() {
    final service = FirestoreAuditService.instance;
    final stats = service.stats;
    final buffer = StringBuffer();

    buffer.writeln('# Firestore Audit Report');
    buffer.writeln();
    buffer.writeln(
      '**Exported:** ${DateTime.now().toString().substring(0, 19)}  ',
    );
    buffer.writeln(
      '**Session Start:** ${stats.sessionStart.toString().substring(0, 19)}  ',
    );
    buffer.writeln('**Duration:** ${_formatDuration(stats.sessionDuration)}  ');
    buffer.writeln();
    buffer.writeln('## Summary');
    buffer.writeln();
    buffer.writeln('| Metric | Value |');
    buffer.writeln('|--------|-------|');
    buffer.writeln('| Total Estimated Reads | ${stats.totalEstimatedReads} |');
    buffer.writeln('| Daily Reads Total | ${service.dailyReadsTotal} |');
    buffer.writeln('| Total Events | ${stats.totalEvents} |');
    buffer.writeln('| Total Documents | ${stats.totalDocuments} |');
    buffer.writeln(
      '| Reads/Minute | ${stats.readsPerMinute.toStringAsFixed(1)} |',
    );
    buffer.writeln(
      '| Reads/Hour (est.) | ${stats.readsPerHour.toStringAsFixed(0)} |',
    );
    buffer.writeln(
      '| Active Listeners (session) | ${stats.activeListenerCount} |',
    );
    buffer.writeln();
    buffer.writeln('## Top Collections');
    buffer.writeln();
    buffer.writeln(
      '| Collection | Est. Reads | Calls | Avg Docs | Top Caller |',
    );
    buffer.writeln('|-----------|-----------|-------|---------|-----------|');
    for (final e in stats.topCollections.take(10)) {
      buffer.writeln(
        '| ${e.key} | ${e.value.totalEstimatedReads} | ${e.value.totalCalls} | ${e.value.avgDocuments.toStringAsFixed(1)} | ${e.value.topCaller} |',
      );
    }
    buffer.writeln();
    buffer.writeln('## Top Callers');
    buffer.writeln();
    buffer.writeln('| Service | Method | Est. Reads | Calls |');
    buffer.writeln('|---------|--------|-----------|-------|');
    for (final e in stats.topCallers.take(10)) {
      buffer.writeln(
        '| ${e.value.service} | ${e.value.method} | ${e.value.totalEstimatedReads} | ${e.value.totalCalls} |',
      );
    }
    buffer.writeln();
    buffer.writeln('## Top Screens');
    buffer.writeln();
    buffer.writeln('| Screen | Est. Reads |');
    buffer.writeln('|--------|-----------|');
    for (final e in stats.topScreens.take(10)) {
      buffer.writeln('| ${e.key} | ${e.value} |');
    }
    buffer.writeln();
    buffer.writeln('## Recent Events (last 20)');
    buffer.writeln();
    buffer.writeln('| Time | Collection | Op | Service.Method | Docs |');
    buffer.writeln('|------|-----------|-----|---------------|------|');
    for (final e in service.recentEvents.reversed.take(20)) {
      final t = e.timestamp;
      final ts =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
      buffer.writeln(
        '| $ts | ${e.collection} | ${e.operation.label} | ${e.callerService}.${e.callerMethod} | ${e.documentCount} |',
      );
    }

    return buffer.toString();
  }

  /// Share qua share_plus.
  static Future<void> shareAsText(String content, String filename) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: content, subject: filename),
      );
    } catch (e) {
      debugPrint('[AuditExport] share error: $e');
    }
  }

  static String _csvEscape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }
}
