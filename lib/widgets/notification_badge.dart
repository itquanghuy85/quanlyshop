import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class NotificationBadge extends StatelessWidget {
  final Widget child;
  final Stream<int> unreadCount;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: unreadCount,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return Stack(
          children: [
            child,
            if (count > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}