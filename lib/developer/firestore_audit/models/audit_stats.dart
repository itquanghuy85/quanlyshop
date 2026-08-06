import 'audit_event.dart';

/// Thống kê tổng hợp cho một collection.
class CollectionStat {
  final String collection;
  int totalCalls;
  int totalDocuments;
  int totalEstimatedReads;
  int totalTimeMs;
  DateTime? lastCalledAt;
  int activeListeners;
  final Map<String, int> callerServiceCounts; // service -> count
  final Map<AuditOperation, int> operationCounts;
  final List<int> recentReadCounts; // last 10 read counts for sparkline

  CollectionStat({required this.collection})
      : totalCalls = 0,
        totalDocuments = 0,
        totalEstimatedReads = 0,
        totalTimeMs = 0,
        activeListeners = 0,
        callerServiceCounts = {},
        operationCounts = {},
        recentReadCounts = [];

  double get avgDocuments =>
      totalCalls == 0 ? 0 : totalDocuments / totalCalls;

  double get avgTimeMs =>
      totalCalls == 0 ? 0 : totalTimeMs / totalCalls;

  String get topCaller {
    if (callerServiceCounts.isEmpty) return '—';
    return callerServiceCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  void absorb(AuditEvent e) {
    totalCalls++;
    totalDocuments += e.documentCount;
    totalEstimatedReads += e.estimatedReads;
    totalTimeMs += e.executionTimeMs;
    lastCalledAt = e.timestamp;
    if (e.isActiveListener) activeListeners++;
    callerServiceCounts[e.callerService] =
        (callerServiceCounts[e.callerService] ?? 0) + 1;
    operationCounts[e.operation] =
        (operationCounts[e.operation] ?? 0) + 1;
    recentReadCounts.add(e.estimatedReads);
    if (recentReadCounts.length > 20) recentReadCounts.removeAt(0);
  }
}

/// Thống kê tổng hợp cho một caller (service+method).
class CallerStat {
  final String service;
  final String method;
  int totalCalls;
  int totalEstimatedReads;
  int totalDocuments;
  final Set<String> collections;
  final Set<String> screens;

  CallerStat({required this.service, required this.method})
      : totalCalls = 0,
        totalEstimatedReads = 0,
        totalDocuments = 0,
        collections = {},
        screens = {};

  String get key => '$service.$method';

  void absorb(AuditEvent e) {
    totalCalls++;
    totalEstimatedReads += e.estimatedReads;
    totalDocuments += e.documentCount;
    collections.add(e.collection);
    if (e.callerScreen != null) screens.add(e.callerScreen!);
  }
}

/// Snapshot tổng hợp toàn bộ phiên.
class AuditSessionStats {
  final DateTime sessionStart;
  int totalEvents;
  int totalEstimatedReads;
  int totalDocuments;
  final Map<String, CollectionStat> byCollection;
  final Map<String, CallerStat> byCaller;
  final Map<String, int> byScreen;
  final Map<AuditOperation, int> byOperation;
  final Map<String, int> byService;
  int activeListenerCount;

  AuditSessionStats()
      : sessionStart = DateTime.now(),
        totalEvents = 0,
        totalEstimatedReads = 0,
        totalDocuments = 0,
        byCollection = {},
        byCaller = {},
        byScreen = {},
        byOperation = {},
        byService = {},
        activeListenerCount = 0;

  void absorb(AuditEvent e) {
    totalEvents++;
    totalEstimatedReads += e.estimatedReads;
    totalDocuments += e.documentCount;

    byCollection.putIfAbsent(e.collection, () => CollectionStat(collection: e.collection))
        .absorb(e);

    final callerKey = '${e.callerService}.${e.callerMethod}';
    byCaller.putIfAbsent(callerKey, () => CallerStat(service: e.callerService, method: e.callerMethod))
        .absorb(e);

    if (e.callerScreen != null) {
      byScreen[e.callerScreen!] = (byScreen[e.callerScreen!] ?? 0) + e.estimatedReads;
    }

    byOperation[e.operation] = (byOperation[e.operation] ?? 0) + e.estimatedReads;
    byService[e.callerService] = (byService[e.callerService] ?? 0) + e.estimatedReads;

    if (e.isActiveListener) activeListenerCount++;
  }

  void reset() {
    totalEvents = 0;
    totalEstimatedReads = 0;
    totalDocuments = 0;
    byCollection.clear();
    byCaller.clear();
    byScreen.clear();
    byOperation.clear();
    byService.clear();
    activeListenerCount = 0;
  }

  List<MapEntry<String, CollectionStat>> get topCollections {
    final list = byCollection.entries.toList();
    list.sort((a, b) => b.value.totalEstimatedReads.compareTo(a.value.totalEstimatedReads));
    return list;
  }

  List<MapEntry<String, CallerStat>> get topCallers {
    final list = byCaller.entries.toList();
    list.sort((a, b) => b.value.totalEstimatedReads.compareTo(a.value.totalEstimatedReads));
    return list;
  }

  List<MapEntry<String, int>> get topScreens {
    final list = byScreen.entries.toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  List<MapEntry<String, int>> get topServices {
    final list = byService.entries.toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  Duration get sessionDuration => DateTime.now().difference(sessionStart);

  double get readsPerMinute {
    final mins = sessionDuration.inSeconds / 60.0;
    if (mins < 0.01) return 0;
    return totalEstimatedReads / mins;
  }

  double get readsPerHour => readsPerMinute * 60;
}
