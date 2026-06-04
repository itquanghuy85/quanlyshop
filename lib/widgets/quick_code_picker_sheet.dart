import 'dart:async';
import 'package:flutter/material.dart';
import '../data/db_helper.dart';
import '../models/quick_input_code_model.dart';
import '../services/user_service.dart';
import '../theme/app_text_styles.dart';
import '../views/quick_input_codes_view.dart';

/// Opens a searchable, paginated bottom sheet for selecting a [QuickInputCode].
/// Returns the selected code or null if cancelled.
Future<QuickInputCode?> showQuickCodePickerSheet(BuildContext context) {
  return showModalBottomSheet<QuickInputCode>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _QuickCodePickerSheet(),
  );
}

class _QuickCodePickerSheet extends StatefulWidget {
  const _QuickCodePickerSheet();

  @override
  State<_QuickCodePickerSheet> createState() => _QuickCodePickerSheetState();
}

class _QuickCodePickerSheetState extends State<_QuickCodePickerSheet> {
  static const _pageSize = 20;

  final _db = DBHelper();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<QuickInputCode> _codes = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  int _total = 0;
  String? _shopId;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(() => setState(() {})); // rebuild suffix icon
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _shopId = await UserService.getCurrentShopId();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _codes = [];
      _offset = 0;
      _hasMore = true;
    });
    final search = _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim();
    final total = await _db.countQuickInputCodes(
      shopId: _shopId,
      search: search,
      activeOnly: true,
    );
    final page = await _db.getQuickInputCodesPaged(
      _pageSize, 0,
      shopId: _shopId,
      search: search,
      activeOnly: true,
    );
    if (!mounted) return;
    setState(() {
      _total = total;
      _codes = page;
      _offset = page.length;
      _hasMore = page.length >= _pageSize;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    if (!mounted) return;
    setState(() => _loadingMore = true);
    final search = _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim();
    final page = await _db.getQuickInputCodesPaged(
      _pageSize, _offset,
      shopId: _shopId,
      search: search,
      activeOnly: true,
    );
    if (!mounted) return;
    setState(() {
      _codes.addAll(page);
      _offset += page.length;
      _hasMore = page.length >= _pageSize;
      _loadingMore = false;
    });
  }

  void _onScroll() {
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 150 && !_loadingMore && _hasMore) {
      _loadMore();
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, _) => Container(
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
              padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
              child: Row(
                children: [
                  const Icon(Icons.flash_on_rounded, color: Colors.blue, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chọn mã nhập nhanh${_total > 0 ? ' ($_total)' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: AppTextStyles.headline3.fontSize,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      final nav = Navigator.of(context, rootNavigator: true);
                      nav.pop();
                      nav.push(MaterialPageRoute(
                        builder: (_) => const QuickInputCodesView(),
                      ));
                    },
                    icon: const Icon(Icons.tune_rounded, size: 15),
                    label: const Text('Quản lý'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 22),
                    splashRadius: 20,
                    tooltip: 'Đóng',
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên, mã, model, màu...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: _clearSearch,
                          splashRadius: 16,
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
              ),
            ),

            const Divider(height: 1),

            // List
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_codes.isEmpty) {
      return _buildEmpty();
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollCtrl,
        itemCount: _codes.length + (_loadingMore || _hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _codes.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _buildItem(_codes[i]);
        },
      ),
    );
  }

  Widget _buildEmpty() {
    final q = _searchCtrl.text.trim();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            q.isEmpty
                ? 'Chưa có mã nhập nhanh nào đang hoạt động'
                : 'Không tìm thấy mã nào cho "$q"',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (q.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text('Xóa bộ lọc'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(QuickInputCode code) {
    final isPhone = code.type == 'DIEN_THOAI';
    final subtitle = isPhone
        ? '${code.brand ?? ''} ${code.model ?? ''}'.trim()
        : code.description ?? '';

    return InkWell(
      onTap: () => Navigator.pop(context, code),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isPhone
                    ? Colors.blue.withAlpha(25)
                    : Colors.orange.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPhone ? Icons.phone_android_rounded : Icons.inventory_2_outlined,
                color: isPhone ? Colors.blue : Colors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    code.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Cost badge (nếu có)
            if (code.cost != null && code.cost! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _fmtCost(code.cost!),
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),

            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 18),
          ],
        ),
      ),
    );
  }

  static String _fmtCost(int cost) {
    if (cost >= 1000000) {
      final m = cost / 1000000;
      return '${m % 1 == 0 ? m.toInt() : m.toStringAsFixed(1)}tr';
    }
    if (cost >= 1000) {
      final k = cost / 1000;
      return '${k % 1 == 0 ? k.toInt() : k.toStringAsFixed(0)}k';
    }
    return cost.toString() + 'đ';
  }
}
