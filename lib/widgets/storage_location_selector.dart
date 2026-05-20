import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/storage_location_model.dart';
import '../services/user_service.dart';

/// Compact selector that shows current location and lets user pick a new one.
class StorageLocationSelector extends StatefulWidget {
  final String? selectedLocationId;
  final String? selectedLocationCode;
  final String? selectedLocationName;
  final ValueChanged<StorageLocation?> onSelected;
  final String? shopId;

  const StorageLocationSelector({
    super.key,
    this.selectedLocationId,
    this.selectedLocationCode,
    this.selectedLocationName,
    required this.onSelected,
    this.shopId,
  });

  @override
  State<StorageLocationSelector> createState() =>
      _StorageLocationSelectorState();
}

class _StorageLocationSelectorState extends State<StorageLocationSelector> {
  List<StorageLocation> _locations = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final shopId =
          widget.shopId ?? await UserService.getCurrentShopId() ?? '';
      final db = DBHelper();
      final locs = await db.getStorageLocations(shopId, activeOnly: true);
      if (mounted) setState(() => _locations = locs);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasSelection =>
      widget.selectedLocationId != null &&
      widget.selectedLocationId!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _hasSelection
              ? const Color(0xFFEFF6FF)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _hasSelection
                ? const Color(0xFF93C5FD)
                : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              size: 16,
              color: _hasSelection
                  ? const Color(0xFF1D4ED8)
                  : Colors.grey.shade500,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _loading
                  ? const SizedBox(
                      height: 2,
                      child: LinearProgressIndicator(),
                    )
                  : Text(
                      _hasSelection
                          ? (widget.selectedLocationCode != null &&
                                  widget.selectedLocationCode!.isNotEmpty
                              ? '${widget.selectedLocationCode} · ${widget.selectedLocationName ?? ''}'
                              : widget.selectedLocationName ?? '')
                          : 'Chọn vị trí lưu kho',
                      style: TextStyle(
                        fontSize: 13,
                        color: _hasSelection
                            ? const Color(0xFF1D4ED8)
                            : Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            if (_hasSelection)
              GestureDetector(
                onTap: () => widget.onSelected(null),
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.close, size: 15, color: Color(0xFF64748B)),
                ),
              )
            else
              Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    await _load();
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _LocationPickerSheet(
        locations: _locations,
        selectedId: widget.selectedLocationId,
        onSelected: (loc) {
          widget.onSelected(loc);
          Navigator.pop(ctx);
        },
        onRefresh: _load,
      ),
    );
  }
}

class _LocationPickerSheet extends StatefulWidget {
  final List<StorageLocation> locations;
  final String? selectedId;
  final ValueChanged<StorageLocation?> onSelected;
  final VoidCallback onRefresh;

  const _LocationPickerSheet({
    required this.locations,
    this.selectedId,
    required this.onSelected,
    required this.onRefresh,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.locations
        .where((l) =>
            _search.isEmpty ||
            l.code.toLowerCase().contains(_search.toLowerCase()) ||
            l.name.toLowerCase().contains(_search.toLowerCase()) ||
            (l.warehouse?.toLowerCase().contains(_search.toLowerCase()) ?? false))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Chọn vị trí lưu kho',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    widget.onSelected(null);
                  },
                  icon: const Icon(Icons.clear, size: 14),
                  label: const Text('Xóa', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm mã/tên vị trí...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      widget.locations.isEmpty
                          ? 'Chưa có vị trí nào.\nVào Kho → Vị trí lưu kho để thêm.'
                          : 'Không tìm thấy vị trí',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: controller,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final loc = filtered[i];
                      final isSelected = loc.firestoreId ==
                              widget.selectedId ||
                          loc.id?.toString() == widget.selectedId;
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.location_on_rounded,
                              size: 18,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                        title: Text(
                          '${loc.code} · ${loc.name}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? const Color(0xFF1D4ED8)
                                : null,
                          ),
                        ),
                        subtitle: loc.displayName != loc.name
                            ? Text(
                                loc.displayName,
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF1D4ED8),
                                size: 20,
                              )
                            : null,
                        onTap: () => widget.onSelected(loc),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
