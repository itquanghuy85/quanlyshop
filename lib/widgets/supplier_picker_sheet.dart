import 'dart:async';
import 'package:flutter/material.dart';
import '../data/db_helper.dart';

/// Opens a paginated, searchable supplier picker bottom sheet.
/// Returns the selected supplier map {id, name, phone} or null (no supplier).
Future<Map<String, dynamic>?> showSupplierPickerSheet(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true, // appear above dialogs
    backgroundColor: Colors.transparent,
    builder: (_) => const _SupplierPickerSheet(),
  );
}

class _SupplierPickerSheet extends StatefulWidget {
  const _SupplierPickerSheet();

  @override
  State<_SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends State<_SupplierPickerSheet> {
  static const _pageSize = 30;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _db = DBHelper();

  List<Map<String, dynamic>> _recentItems = [];
  List<Map<String, dynamic>> _items = [];
  String? _cursorName;
  int _total = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  String _query = '';
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadRecent();
    _loadPage();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 150) {
      _loadPage();
    }
  }

  Future<void> _loadRecent() async {
    try {
      final recent = await _db.getRecentSuppliersForPicker(limit: 5);
      if (mounted) setState(() => _recentItems = recent);
    } catch (_) {}
  }

  Future<void> _loadPage() async {
    if (_isLoading || !_hasMore) return;
    if (mounted) setState(() => _isLoading = true);
    try {
      final result = await _db.getSuppliersPage(
        search: _query.isEmpty ? null : _query,
        cursorName: _cursorName,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (_cursorName == null) _total = result.total;
        _items.addAll(result.items);
        _hasMore = result.items.length >= _pageSize;
        if (result.items.isNotEmpty) {
          _cursorName = result.items.last['name'] as String?;
        }
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String q) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _query = q.trim();
        _items = [];
        _cursorName = null;
        _hasMore = true;
        _total = 0;
        _isLoading = false;
      });
      _loadPage();
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _items = [];
      _cursorName = null;
      _hasMore = true;
      _total = 0;
      _isLoading = false;
    });
    _loadPage();
  }

  void _select(Map<String, dynamic>? s) => Navigator.pop(context, s);

  @override
  Widget build(BuildContext context) {
    final isSearching = _query.isNotEmpty;
    final showRecent = !isSearching && _recentItems.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, __) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.store_rounded, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Chọn nhà cung cấp',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _select(null),
                    child: const Text(
                      'Không chọn',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Tìm tên, SĐT, mã NCC...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: isSearching
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            // Count indicator
            if (_total > 0 || (_items.isNotEmpty && !isSearching))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isSearching
                        ? 'Tìm thấy ${_items.length} NCC'
                        : _hasMore
                        ? 'Đã tải ${_items.length} / $_total NCC — Cuộn để tải thêm'
                        : 'Đã tải ${_items.length} / $_total NCC',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
              ),
            const Divider(height: 1),
            // List
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: EdgeInsets.fromLTRB(
                  0,
                  4,
                  0,
                  4 + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: _listItemCount(showRecent),
                itemBuilder: (ctx, i) => _buildListItem(i, showRecent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _listItemCount(bool showRecent) {
    int n = 1; // "Không chọn NCC"
    if (showRecent)
      n += 1 + _recentItems.length + 1; // section header + items + divider
    n += _items.length;
    if (_isLoading) n += 1; // loading spinner
    if (!_isLoading && _hasMore && _items.isNotEmpty) n += 1; // scroll hint
    return n;
  }

  Widget _buildListItem(int index, bool showRecent) {
    // 0: Không chọn NCC
    if (index == 0) {
      return ListTile(
        leading: const Icon(
          Icons.remove_circle_outline,
          color: Colors.grey,
          size: 20,
        ),
        title: const Text(
          '— Không chọn NCC —',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        onTap: () => _select(null),
        dense: true,
      );
    }

    int offset = 1;

    if (showRecent) {
      // Section header
      if (index == offset) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(
            'GẦN ĐÂY',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        );
      }
      offset++;

      // Recent items
      if (index < offset + _recentItems.length) {
        return _supplierTile(_recentItems[index - offset], isRecent: true);
      }
      offset += _recentItems.length;

      // Divider
      if (index == offset) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: Row(
            children: [
              const Expanded(child: Divider(height: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'TẤT CẢ NCC',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Expanded(child: Divider(height: 1)),
            ],
          ),
        );
      }
      offset++;
    }

    // Main items
    final listIdx = index - offset;
    if (listIdx < _items.length) {
      return _supplierTile(_items[listIdx]);
    }

    // Loading spinner
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Scroll hint
    if (_hasMore) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: Text(
            'Tiếp tục cuộn để tải thêm...',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _supplierTile(Map<String, dynamic> s, {bool isRecent = false}) {
    final name = (s['name'] as String?) ?? '';
    final phone = (s['phone'] as String?) ?? '';
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: isRecent
            ? Colors.orange.shade100
            : Colors.blue.shade50,
        child: Text(
          name.isNotEmpty ? name[0] : '?',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isRecent ? Colors.orange.shade700 : Colors.blue.shade700,
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: phone.isNotEmpty
          ? Text(
              phone,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          : null,
      trailing: isRecent
          ? Icon(Icons.history, size: 14, color: Colors.orange.shade400)
          : null,
      onTap: () => _select(s),
      dense: true,
    );
  }
}
