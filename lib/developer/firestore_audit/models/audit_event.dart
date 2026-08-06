import 'dart:convert';

/// Phân loại operation Firestore.
enum AuditOperation {
  get,
  snapshots,
  listen,
  count,
  aggregate,
  batch,
  transaction,
  other,
}

extension AuditOperationLabel on AuditOperation {
  String get label {
    switch (this) {
      case AuditOperation.get:
        return 'get()';
      case AuditOperation.snapshots:
        return 'snapshots()';
      case AuditOperation.listen:
        return 'listen()';
      case AuditOperation.count:
        return 'count()';
      case AuditOperation.aggregate:
        return 'aggregate()';
      case AuditOperation.batch:
        return 'batch()';
      case AuditOperation.transaction:
        return 'transaction()';
      case AuditOperation.other:
        return 'other';
    }
  }

  static AuditOperation fromString(String s) {
    switch (s) {
      case 'get':
        return AuditOperation.get;
      case 'snapshots':
        return AuditOperation.snapshots;
      case 'listen':
        return AuditOperation.listen;
      case 'count':
        return AuditOperation.count;
      case 'aggregate':
        return AuditOperation.aggregate;
      case 'batch':
        return AuditOperation.batch;
      case 'transaction':
        return AuditOperation.transaction;
      default:
        return AuditOperation.other;
    }
  }
}

/// Một sự kiện Firestore Read được ghi nhận.
class AuditEvent {
  final String id;
  final DateTime timestamp;
  final String collection;
  final AuditOperation operation;
  final String callerService; // e.g. "SyncService"
  final String callerMethod; // e.g. "_subscribeToCollection"
  final String? callerScreen; // e.g. "HomeView"
  final int documentCount; // số doc trả về
  final int estimatedReads; // ước tính Firestore Read (thường == documentCount)
  final int executionTimeMs;
  final bool isActiveListener; // true nếu là snapshots()/listen() đang active
  final String? queryInfo; // mô tả query (collection + filter ngắn gọn)

  const AuditEvent({
    required this.id,
    required this.timestamp,
    required this.collection,
    required this.operation,
    required this.callerService,
    required this.callerMethod,
    this.callerScreen,
    required this.documentCount,
    required this.estimatedReads,
    required this.executionTimeMs,
    required this.isActiveListener,
    this.queryInfo,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'collection': collection,
    'operation': operation.name,
    'callerService': callerService,
    'callerMethod': callerMethod,
    'callerScreen': callerScreen,
    'documentCount': documentCount,
    'estimatedReads': estimatedReads,
    'executionTimeMs': executionTimeMs,
    'isActiveListener': isActiveListener,
    'queryInfo': queryInfo,
  };

  factory AuditEvent.fromJson(Map<String, dynamic> json) => AuditEvent(
    id: json['id'] as String? ?? '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      json['timestamp'] as int? ?? 0,
    ),
    collection: json['collection'] as String? ?? '',
    operation: AuditOperationLabel.fromString(
      json['operation'] as String? ?? '',
    ),
    callerService: json['callerService'] as String? ?? '',
    callerMethod: json['callerMethod'] as String? ?? '',
    callerScreen: json['callerScreen'] as String?,
    documentCount: json['documentCount'] as int? ?? 0,
    estimatedReads: json['estimatedReads'] as int? ?? 0,
    executionTimeMs: json['executionTimeMs'] as int? ?? 0,
    isActiveListener: json['isActiveListener'] as bool? ?? false,
    queryInfo: json['queryInfo'] as String?,
  );

  String toJsonString() => jsonEncode(toJson());

  @override
  String toString() =>
      '[${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}] '
      '$collection ${operation.label} $documentCount docs ← $callerService.$callerMethod';
}
