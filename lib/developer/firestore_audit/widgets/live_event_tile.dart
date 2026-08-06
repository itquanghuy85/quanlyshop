import 'package:flutter/material.dart';
import '../models/audit_event.dart';

/// Tile hiển thị một sự kiện audit trong live monitor.
class LiveEventTile extends StatelessWidget {
  final AuditEvent event;
  final bool compact;

  const LiveEventTile({super.key, required this.event, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opColor = _operationColor(event.operation);
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final subColor = isDark ? Colors.white60 : Colors.black54;

    final t = event.timestamp;
    final ts =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: opColor, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: compact
          ? _buildCompact(ts, opColor, subColor)
          : _buildFull(ts, opColor, subColor),
    );
  }

  Widget _buildCompact(String ts, Color opColor, Color subColor) {
    return Row(
      children: [
        Text(
          ts,
          style: TextStyle(
            color: subColor,
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            event.collection,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: opColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            event.operation.label,
            style: TextStyle(
              color: opColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${event.estimatedReads}R',
          style: TextStyle(
            color: event.estimatedReads > 50 ? Colors.red : Colors.green,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFull(String ts, Color opColor, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              ts,
              style: TextStyle(
                color: subColor,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                event.collection,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: opColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                event.operation.label,
                style: TextStyle(
                  color: opColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.account_tree_outlined, size: 11, color: subColor),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                '${event.callerService}.${event.callerMethod}',
                style: TextStyle(color: subColor, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (event.callerScreen != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.screen_rotation_outlined, size: 11, color: subColor),
              const SizedBox(width: 3),
              Text(
                event.callerScreen!,
                style: TextStyle(color: subColor, fontSize: 11),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _chip('${event.documentCount} docs', Colors.blueGrey),
            const SizedBox(width: 6),
            _chip(
              '~${event.estimatedReads} reads',
              event.estimatedReads > 100 ? Colors.red : Colors.green,
            ),
            if (event.executionTimeMs > 0) ...[
              const SizedBox(width: 6),
              _chip('${event.executionTimeMs}ms', Colors.orange),
            ],
            if (event.isActiveListener) ...[
              const SizedBox(width: 6),
              _chip('● live', Colors.purple),
            ],
          ],
        ),
      ],
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );

  Color _operationColor(AuditOperation op) {
    switch (op) {
      case AuditOperation.get:
        return Colors.blue;
      case AuditOperation.snapshots:
        return Colors.purple;
      case AuditOperation.listen:
        return Colors.deepPurple;
      case AuditOperation.count:
        return Colors.teal;
      case AuditOperation.aggregate:
        return Colors.cyan;
      case AuditOperation.batch:
        return Colors.orange;
      case AuditOperation.transaction:
        return Colors.red;
      case AuditOperation.other:
        return Colors.grey;
    }
  }
}
