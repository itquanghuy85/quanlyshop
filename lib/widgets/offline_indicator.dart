import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

class OfflineIndicator extends StatefulWidget {
  final Widget child;

  const OfflineIndicator({super.key, required this.child});

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator> {
  bool _isOnline = true;
  bool _showIndicator = false;

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService.instance.isOnline;

    // Listen to connectivity changes
    ConnectivityService.instance.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    ConnectivityService.instance.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onConnectivityChanged() {
    final wasOnline = _isOnline;
    final isOnline = ConnectivityService.instance.isOnline;

    if (mounted) {
      setState(() {
        _isOnline = isOnline;
        // Show indicator when going offline or coming back online
        _showIndicator = !isOnline || (isOnline && !wasOnline);
      });

      // Hide indicator after 3 seconds when coming back online
      if (isOnline && !wasOnline) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _showIndicator = false);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showIndicator)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 32,
              decoration: BoxDecoration(
                color: _isOnline ? Colors.green : Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: (_isOnline ? Colors.green : Colors.red)
                        .withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isOnline ? Icons.wifi : Icons.wifi_off,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isOnline
                        ? 'Đã kết nối lại'
                        : 'Không có kết nối internet',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Offline overlay for entire screen when offline
        if (!_isOnline)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.05),
              child: const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}

class ConnectivityBadge extends StatelessWidget {
  final double size;

  const ConnectivityBadge({super.key, this.size = 8});

  @override
  Widget build(BuildContext context) {
    final isOnline = ConnectivityService.instance.isOnline;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? Colors.green : Colors.red,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOnline ? Colors.green : Colors.red).withOpacity(0.3),
            blurRadius: 2,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.red.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bạn đang ở chế độ offline. Một số tính năng có thể không khả dụng.',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              // Could add retry connectivity check here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đang kiểm tra kết nối...'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: Icon(Icons.refresh, color: Colors.red.shade700, size: 20),
            tooltip: 'Kiểm tra lại kết nối',
          ),
        ],
      ),
    );
  }
}
