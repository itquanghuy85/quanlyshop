import 'package:flutter/material.dart';

enum SyncState { offline, connecting, synced }

class SyncStatusBar extends StatelessWidget {
  final bool isOnline;
  final bool isRealtimeConnected;
  final int? itemCount;
  final String? itemLabel;
  final String? modeDetail;

  const SyncStatusBar({
    super.key,
    required this.isOnline,
    required this.isRealtimeConnected,
    this.itemCount,
    this.itemLabel,
    this.modeDetail,
  });

  SyncState get _state {
    if (!isOnline) return SyncState.offline;
    if (!isRealtimeConnected) return SyncState.connecting;
    return SyncState.synced;
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;

    final Color statusColor;
    final IconData statusIcon;
    final String statusText;

    switch (state) {
      case SyncState.offline:
        statusColor = Colors.grey.shade600;
        statusIcon = Icons.cloud_off_outlined;
        statusText = 'Ngoại tuyến';
      case SyncState.connecting:
        statusColor = Colors.orange.shade700;
        statusIcon = Icons.sync;
        statusText = 'Đang kết nối...';
      case SyncState.synced:
        statusColor = Colors.green.shade700;
        statusIcon = Icons.cloud_done_outlined;
        statusText = 'Đồng bộ';
    }

    final countPart = itemCount != null ? ' • $itemCount ${itemLabel ?? 'mục'}' : '';
    final modePart = modeDetail != null ? ' • $modeDetail' : '';
    final leftLabel = 'Realtime Firestore$modePart$countPart';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights, size: 14, color: Color(0xFF2962FF)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              leftLabel,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          if (state == SyncState.connecting)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            )
          else
            Icon(statusIcon, size: 12, color: statusColor),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 10,
              color: statusColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
