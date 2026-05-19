import 'package:flutter/material.dart';

/// Compact badge showing a storage location code/name.
/// Shows a "Chưa cập nhật vị trí" placeholder when no location is set.
class LocationBadge extends StatelessWidget {
  final String? locationCode;
  final String? locationName;
  final bool showPlaceholder;

  const LocationBadge({
    super.key,
    this.locationCode,
    this.locationName,
    this.showPlaceholder = true,
  });

  bool get _hasLocation =>
      (locationCode ?? '').isNotEmpty || (locationName ?? '').isNotEmpty;

  String get _label {
    final code = (locationCode ?? '').trim();
    final name = (locationName ?? '').trim();
    if (code.isNotEmpty && name.isNotEmpty) return '$code · $name';
    if (code.isNotEmpty) return code;
    return name;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasLocation) {
      if (!showPlaceholder) return const SizedBox.shrink();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off_outlined, size: 14, color: Colors.grey.shade400),
          const SizedBox(width: 4),
          Text(
            'Chưa cập nhật vị trí',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF1D4ED8)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              _label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D4ED8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
