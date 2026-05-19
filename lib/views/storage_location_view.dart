import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/db_helper.dart';
import '../models/product_model.dart';
import '../models/repair_model.dart';
import '../models/storage_location_model.dart';
import '../services/user_service.dart';
import '../theme/popup_theme.dart';
import '../utils/money_utils.dart';
import '../widgets/app_cached_image.dart';
import 'inventory_detail_view.dart';
import 'repair_detail_view.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Full CRUD screen for managing storage locations — Light Premium Business design.
class StorageLocationView extends StatefulWidget {
  const StorageLocationView({super.key});

  @override
  State<StorageLocationView> createState() => _StorageLocationViewState();
}

class _StorageLocationViewState extends State<StorageLocationView> {
  final DBHelper _db = DBHelper();
  List<StorageLocation> _locations = [];
  List<StorageLocation> _filtered = [];
  Map<String, Map<String, dynamic>> _statsMap = {};
  String _search = '';
  bool _loading = true;
  String? _shopId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _shopId = await UserService.getCurrentShopId();
    await _load();
  }

  Future<void> _load() async {
    if (_shopId == null) return;
    setState(() => _loading = true);
    try {
      // Load all locations (usually small dataset) + aggregate stats in parallel
      final results = await Future.wait([
        _db.getStorageLocations(_shopId!),
        _db.getAllLocationStats(_shopId!),
      ]);
      if (mounted) {
        final locations = results[0] as List<StorageLocation>;
        final statsMap = results[1] as Map<String, Map<String, dynamic>>;
        // Show locations derived from products even if no formal record exists
        final formalCodes =
            locations.map((l) => l.code.trim().toUpperCase()).toSet();
        for (final key in statsMap.keys) {
          if (!formalCodes.contains(key.trim().toUpperCase())) {
            locations.add(StorageLocation(
              code: key,
              name: key,
              shopId: _shopId,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ));
          }
        }
        setState(() {
          _locations = locations;
          _statsMap = statsMap;
          _applyFilter();
        });
      }
    } catch (e) {
      debugPrint('StorageLocationView._load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu vị trí: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    if (_search.isEmpty) {
      _filtered = List.from(_locations);
    } else {
      final q = _search.toLowerCase();
      _filtered = _locations
          .where((l) =>
              l.code.toLowerCase().contains(q) ||
              l.name.toLowerCase().contains(q) ||
              (l.warehouse?.toLowerCase().contains(q) ?? false) ||
              (l.floor?.toLowerCase().contains(q) ?? false) ||
              (l.shelf?.toLowerCase().contains(q) ?? false))
          .toList();
    }
  }

  Future<void> _openForm({StorageLocation? existing}) async {
    final result = await showDialog<StorageLocation>(
      context: context,
      builder: (_) => _LocationFormDialog(
        existing: existing,
        shopId: _shopId ?? '',
      ),
    );
    if (result != null) {
      final id = await _db.upsertStorageLocation(result);
      if (result.id == null) {
        await _db.upsertStorageLocation(result.copyWith(id: id));
      }
      await _load();
    }
  }

  Future<void> _toggleActive(StorageLocation loc) async {
    await _db.upsertStorageLocation(loc.copyWith(
      isActive: !loc.isActive,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await _load();
  }

  Future<void> _confirmDelete(StorageLocation loc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: PopupTheme.bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PopupTheme.radiusDialog),
        ),
        title: const Text('Xóa vị trí',
            style: TextStyle(
                color: PopupTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        content: Text(
          'Xóa vị trí "${loc.code} · ${loc.name}"?\nCác sản phẩm sẽ không bị xóa.',
          style: const TextStyle(color: PopupTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy',
                style: TextStyle(color: PopupTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: PopupTheme.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(PopupTheme.radiusButton)),
            ),
            child: const Text('Xóa', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
    if (ok == true && loc.id != null) {
      await _db.deleteStorageLocation(loc.id!);
      await _load();
    }
  }

  Map<String, dynamic> _statsFor(StorageLocation loc) {
    final code = loc.code.trim().toUpperCase();
    for (final entry in _statsMap.entries) {
      if (entry.key.trim().toUpperCase() == code) return entry.value;
    }
    return {};
  }

  int _totalLocations() => _locations.length;
  int _totalProducts() => _statsMap.values
      .fold(0, (sum, s) => sum + ((s['cnt'] as int?) ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: _buildAppBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
        elevation: 3,
        tooltip: 'Thêm vị trí',
        child: const Icon(Icons.add_location_alt_rounded, size: 24),
      ),
      body: Column(
        children: [
          _buildStatsCard(),
          _buildSearchBar(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Vị trí lưu kho',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          Text('Kho · Tầng · Kệ',
              style: TextStyle(fontSize: 12, color: Color(0xCCFFFFFF))),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 22, color: Colors.white),
          onPressed: _load,
          tooltip: 'Làm mới',
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    final totalLoc = _totalLocations();
    final totalProd = _totalProducts();
    final totalValue = _statsMap.values
        .fold(0, (sum, s) => sum + ((s['totalValue'] as int?) ?? 0));
    final totalCost = _statsMap.values
        .fold(0, (sum, s) => sum + ((s['totalCost'] as int?) ?? 0));

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E40AF).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _statPill(
            Icons.location_on_rounded,
            '$totalLoc',
            'Vị trí',
          ),
          _vDivider(),
          _statPill(
            Icons.inventory_2_rounded,
            '$totalProd',
            'Sản phẩm',
          ),
          _vDivider(),
          _statPill(
            Icons.monetization_on_rounded,
            MoneyUtils.formatCompactCurrency(totalValue),
            'Giá trị tồn',
          ),
          _vDivider(),
          _statPill(
            Icons.price_change_rounded,
            MoneyUtils.formatCompactCurrency(totalCost),
            'Tổng vốn',
          ),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(
                  color: Color(0xBBFFFFFF), fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 40,
        color: Colors.white.withValues(alpha: 0.25),
      );

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Tìm mã, tên, kho, tầng, kệ...',
          hintStyle: const TextStyle(
              color: PopupTheme.textMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.search,
              size: 18, color: PopupTheme.textSecondary),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(PopupTheme.radiusField),
            borderSide:
                const BorderSide(color: PopupTheme.borderDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(PopupTheme.radiusField),
            borderSide:
                const BorderSide(color: PopupTheme.borderDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(PopupTheme.radiusField),
            borderSide:
                const BorderSide(color: PopupTheme.blue, width: 1.5),
          ),
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: (v) => setState(() {
          _search = v;
          _applyFilter();
        }),
      ),
    );
  }

  Widget _buildList() {
    if (_loading && _filtered.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_rounded,
                  size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                _locations.isEmpty
                    ? 'Chưa có vị trí nào.\nNhấn nút + (góc phải bên dưới) để thêm.'
                    : 'Không tìm thấy kết quả',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 88),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildCard(_filtered[i]),
    );
  }

  Widget _buildCard(StorageLocation loc) {
    final active = loc.isActive;
    final stats = _statsFor(loc);
    final cnt = (stats['cnt'] as int?) ?? 0;
    final totalQty = (stats['totalQty'] as int?) ?? 0;
    final totalValue = (stats['totalValue'] as int?) ?? 0;
    final updatedAt = loc.updatedAt != null
        ? DateFormat('dd/MM/yy').format(
            DateTime.fromMillisecondsSinceEpoch(loc.updatedAt!))
        : null;

    final isEmpty = cnt == 0;
    final accentColor =
        active ? const Color(0xFF1D4ED8) : Colors.grey.shade400;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openLocationProducts(loc),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: PopupTheme.shadowCard,
            border: Border.all(
              color: active
                  ? const Color(0xFFE2E8F0)
                  : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFFEFF6FF)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 22,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Name & breadcrumb
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  loc.code,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.3),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  loc.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: active
                                        ? PopupTheme.textPrimary
                                        : Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (loc.displayName != loc.name) ...[
                            const SizedBox(height: 2),
                            Text(
                              loc.displayName,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: PopupTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Status badge + menu
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _statusBadge(active, isEmpty),
                        const SizedBox(height: 4),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert,
                              size: 18, color: Colors.grey.shade400),
                          padding: EdgeInsets.zero,
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'products',
                              child: _MenuRow(
                                  Icons.inventory_2_outlined, 'Xem sản phẩm',
                                  color: Color(0xFF1D4ED8)),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: _MenuRow(Icons.edit_rounded, 'Chỉnh sửa'),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: _MenuRow(
                                active
                                    ? Icons.toggle_off_rounded
                                    : Icons.toggle_on_rounded,
                                active ? 'Vô hiệu hóa' : 'Kích hoạt',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: _MenuRow(Icons.delete_rounded, 'Xóa',
                                  color: PopupTheme.red),
                            ),
                          ],
                          onSelected: (action) {
                            if (action == 'products') {
                              _openLocationProducts(loc);
                            } else if (action == 'edit') {
                              _openForm(existing: loc);
                            } else if (action == 'toggle') {
                              _toggleActive(loc);
                            } else if (action == 'delete') {
                              _confirmDelete(loc);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Stats row
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    _miniStat(Icons.inventory_2_rounded, '$cnt sp', 'Loại'),
                    _miniDivider(),
                    _miniStat(Icons.add_box_rounded, '$totalQty', 'Tồn kho'),
                    _miniDivider(),
                    _miniStat(
                      Icons.attach_money_rounded,
                      MoneyUtils.formatCompactCurrency(totalValue),
                      'Giá trị',
                    ),
                    if (updatedAt != null) ...[
                      _miniDivider(),
                      _miniStat(
                          Icons.update_rounded, updatedAt, 'Cập nhật'),
                    ],
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded,
                        size: 16, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(bool active, bool isEmpty) {
    if (!active) {
      return _badge('Tắt', Colors.grey.shade400, Colors.grey.shade50);
    }
    if (isEmpty) {
      return _badge('Trống', PopupTheme.textMuted, const Color(0xFFF1F5F9));
    }
    return _badge('Có hàng', PopupTheme.green,
        PopupTheme.green.withValues(alpha: 0.1));
  }

  Widget _badge(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor)),
    );
  }

  Widget _miniStat(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: PopupTheme.textSecondary),
        const SizedBox(width: 3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PopupTheme.textPrimary)),
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: PopupTheme.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _miniDivider() => Container(
        width: 1,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: const Color(0xFFE2E8F0),
      );

  void _openLocationProducts(StorageLocation loc) {
    final stats = _statsFor(loc);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _LocationProductsSheet(
        location: loc,
        stats: stats,
        shopId: _shopId ?? '',
        db: _db,
      ),
    );
  }
}

// ─── Menu row helper ──────────────────────────────────────────────────────────
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MenuRow(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? PopupTheme.textSecondary),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: color ?? PopupTheme.textPrimary)),
      ],
    );
  }
}

// ─── Location products bottom sheet ──────────────────────────────────────────
class _LocationProductsSheet extends StatefulWidget {
  final StorageLocation location;
  final Map<String, dynamic> stats;
  final String shopId;
  final DBHelper db;

  const _LocationProductsSheet({
    required this.location,
    required this.stats,
    required this.shopId,
    required this.db,
  });

  @override
  State<_LocationProductsSheet> createState() =>
      _LocationProductsSheetState();
}

class _LocationProductsSheetState extends State<_LocationProductsSheet> {
  static const int _pageSize = 20;
  final List<Product> _products = [];
  List<Map<String, dynamic>> _repairs = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 0;
  String _search = '';
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPage();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 120 &&
          !_loading &&
          _hasMore) {
        _loadPage();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (_loading && !reset) return;
    if (reset) {
      setState(() {
        _products.clear();
        _repairs.clear();
        _page = 0;
        _hasMore = true;
      });
    }
    setState(() => _loading = true);
    final results = await Future.wait([
      widget.db.getProductsByLocation(
        widget.shopId,
        locationCode: widget.location.code,
        page: _page,
        pageSize: _pageSize,
        search: _search,
      ),
      if (_page == 0)
        widget.db.getRepairsByLocation(
          widget.shopId,
          locationCode: widget.location.code,
        )
      else
        Future.value(<Map<String, dynamic>>[]),
    ]);
    if (mounted) {
      final rows = results[0] as List<Product>;
      final repairRows = results[1] as List<Map<String, dynamic>>;
      setState(() {
        _products.addAll(rows);
        if (_page == 0) _repairs = repairRows;
        _page++;
        _hasMore = rows.length == _pageSize;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cnt = (widget.stats['cnt'] as int?) ?? 0;
    final totalQty = (widget.stats['totalQty'] as int?) ?? 0;
    final totalValue = (widget.stats['totalValue'] as int?) ?? 0;
    final totalCost = (widget.stats['totalCost'] as int?) ?? 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: PopupTheme.bgDark,
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(PopupTheme.radiusSheet)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: PopupTheme.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.location.code} · ${widget.location.name}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                        if (widget.location.displayName !=
                            widget.location.name)
                          Text(
                            widget.location.displayName,
                            style: const TextStyle(
                                color: Color(0xCCFFFFFF), fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _sheetStat(Icons.inventory_2_rounded,
                      '$cnt loại', 'Sản phẩm'),
                  _sheetStat(Icons.add_box_rounded,
                      '$totalQty', 'Tồn kho'),
                  _sheetStat(Icons.attach_money_rounded,
                      MoneyUtils.formatCompactCurrency(totalValue),
                      'Giá trị'),
                  _sheetStat(Icons.price_change_rounded,
                      MoneyUtils.formatCompactCurrency(totalCost),
                      'Tổng vốn'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Tìm tên, IMEI, mã hàng...',
                  hintStyle: const TextStyle(
                      color: PopupTheme.textMuted, fontSize: 12),
                  prefixIcon: const Icon(Icons.search,
                      size: 16, color: PopupTheme.textSecondary),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  filled: true,
                  fillColor: PopupTheme.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(PopupTheme.radiusField),
                    borderSide: const BorderSide(color: PopupTheme.borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(PopupTheme.radiusField),
                    borderSide: const BorderSide(color: PopupTheme.borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(PopupTheme.radiusField),
                    borderSide: const BorderSide(
                        color: PopupTheme.blue, width: 1.5),
                  ),
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (v) {
                  _search = v;
                  _loadPage(reset: true);
                },
              ),
            ),
            const SizedBox(height: 8),
            // Product list
            Expanded(
              child: _products.isEmpty && _repairs.isEmpty && !_loading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 48,
                              color: Colors.grey.shade300),
                          const SizedBox(height: 10),
                          Text(
                            _search.isEmpty
                                ? 'Không có sản phẩm nào ở vị trí này'
                                : 'Không tìm thấy kết quả',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _repairs.length +
                          _products.length +
                          (_loading ? 1 : 0),
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        // Repairs first
                        if (i < _repairs.length) {
                          return _repairTile(_repairs[i]);
                        }
                        final pi = i - _repairs.length;
                        if (pi >= _products.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                          );
                        }
                        return _productTile(_products[pi]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetStat(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: PopupTheme.surfaceDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: PopupTheme.borderDark),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: PopupTheme.blue),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: PopupTheme.textPrimary)),
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: PopupTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _repairTile(Map<String, dynamic> r) {
    final status = (r['status'] as int?) ?? 0;
    final statusLabels = {0: 'Chờ sửa', 1: 'Đang sửa', 2: 'Đang sửa', 3: 'Xong - chờ giao'};
    final statusColors = {0: Colors.orange, 1: Colors.blue, 2: Colors.blue, 3: Colors.green};
    final label = statusLabels[status] ?? 'Đang xử lý';
    final color = statusColors[status] ?? Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E7FF)),
        boxShadow: PopupTheme.shadowCard,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.build_rounded, size: 22, color: Color(0xFF3B82F6)),
        ),
        title: Text(
          r['model'] ?? 'Máy sửa',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PopupTheme.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          r['customerName'] ?? '',
          style: const TextStyle(fontSize: 11, color: PopupTheme.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: PopupTheme.textMuted),
          ],
        ),
        onTap: () {
          final repair = Repair.fromMap(Map<String, dynamic>.from(r));
          final navigator = Navigator.of(context);
          navigator.pop();
          navigator.push(MaterialPageRoute(
            builder: (_) => RepairDetailView(repair: repair),
          ));
        },
      ),
    );
  }

  Widget _productTile(Product p) {
    final isSold = p.status == 0;
    final imagePath = (p.images ?? '')
        .split(',')
        .map((e) => e.trim())
        .firstWhere((e) => e.isNotEmpty, orElse: () => '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PopupTheme.borderDark),
        boxShadow: PopupTheme.shadowCard,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: _thumb(imagePath),
        title: Text(
          p.name,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PopupTheme.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((p.imei ?? '').isNotEmpty)
              Text(p.imei!,
                  style: const TextStyle(
                      fontSize: 11, color: PopupTheme.textSecondary)),
            Row(
              children: [
                Text(
                  MoneyUtils.formatCurrency(p.price),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PopupTheme.green),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSold
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isSold ? 'Đã bán' : 'Tồn kho',
                    style: TextStyle(
                        fontSize: 10,
                        color: isSold
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'x${p.quantity}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: PopupTheme.textPrimary),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 16, color: PopupTheme.textMuted),
          ],
        ),
        onTap: () {
          final navigator = Navigator.of(context);
          navigator.pop();
          navigator.push(MaterialPageRoute(
            builder: (_) => InventoryDetailView(product: p),
          ));
        },
      ),
    );
  }

  Widget _thumb(String imagePath) {
    const size = 44.0;
    if (imagePath.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.phone_android_rounded,
            size: 22, color: Color(0xFF94A3B8)),
      );
    }
    if (imagePath.startsWith('http') || imagePath.startsWith('gs://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AppCachedImage(
            imageUrl: imagePath,
            width: size,
            height: size,
            fit: BoxFit.cover),
      );
    }
    if (!kIsWeb) {
      final f = File(imagePath);
      if (f.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child:
              Image.file(f, width: size, height: size, fit: BoxFit.cover),
        );
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.broken_image_outlined,
          size: 22, color: Color(0xFF94A3B8)),
    );
  }
}

// ─── Location form dialog ─────────────────────────────────────────────────────
class _LocationFormDialog extends StatefulWidget {
  final StorageLocation? existing;
  final String shopId;

  const _LocationFormDialog({this.existing, required this.shopId});

  @override
  State<_LocationFormDialog> createState() => _LocationFormDialogState();
}

class _LocationFormDialogState extends State<_LocationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeC;
  late final TextEditingController _nameC;
  late final TextEditingController _warehouseC;
  late final TextEditingController _floorC;
  late final TextEditingController _shelfC;
  late final TextEditingController _binC;
  late final TextEditingController _noteC;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _codeC = TextEditingController(text: e?.code ?? '');
    _nameC = TextEditingController(text: e?.name ?? '');
    _warehouseC = TextEditingController(text: e?.warehouse ?? '');
    _floorC = TextEditingController(text: e?.floor ?? '');
    _shelfC = TextEditingController(text: e?.shelf ?? '');
    _binC = TextEditingController(text: e?.bin ?? '');
    _noteC = TextEditingController(text: e?.note ?? '');
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final c in [
      _codeC,
      _nameC,
      _warehouseC,
      _floorC,
      _shelfC,
      _binC,
      _noteC
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    Navigator.pop(
      context,
      StorageLocation(
        id: widget.existing?.id,
        firestoreId: widget.existing?.firestoreId ??
            'loc_${now}_${_codeC.text.trim()}',
        shopId: widget.shopId,
        code: _codeC.text.trim().toUpperCase(),
        name: _nameC.text.trim(),
        warehouse:
            _warehouseC.text.trim().isEmpty ? null : _warehouseC.text.trim(),
        floor: _floorC.text.trim().isEmpty ? null : _floorC.text.trim(),
        shelf: _shelfC.text.trim().isEmpty ? null : _shelfC.text.trim(),
        bin: _binC.text.trim().isEmpty ? null : _binC.text.trim(),
        note: _noteC.text.trim().isEmpty ? null : _noteC.text.trim(),
        isActive: _isActive,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    TextCapitalization cap = TextCapitalization.words,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        textCapitalization: cap,
        decoration: PopupTheme.darkField(
          label: label,
          hint: hint,
        ).copyWith(
          errorStyle: const TextStyle(fontSize: 11),
        ),
        style: const TextStyle(
            fontSize: 13, color: PopupTheme.textPrimary),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      backgroundColor: PopupTheme.bgDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PopupTheme.radiusDialog),
      ),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
        decoration: BoxDecoration(
          gradient: isEdit ? PopupTheme.headerEdit : PopupTheme.headerGreen,
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(PopupTheme.radiusDialog)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isEdit
                    ? Icons.edit_location_rounded
                    : Icons.add_location_alt_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEdit ? 'Chỉnh sửa vị trí' : 'Thêm vị trí lưu kho',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 15),
              ),
            ),
          ],
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      content: SizedBox(
        width: 340,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_codeC, 'Mã vị trí',
                    required: true,
                    cap: TextCapitalization.characters,
                    hint: 'VD: A1-01'),
                _field(_nameC, 'Tên vị trí',
                    required: true, hint: 'VD: Kệ A tầng 1'),
                Row(
                  children: [
                    Expanded(
                        child: _field(_warehouseC, 'Kho',
                            hint: 'Kho A')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _field(_floorC, 'Tầng',
                            hint: 'Tầng 1')),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                        child: _field(_shelfC, 'Kệ',
                            hint: 'Kệ 1')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _field(_binC, 'Ô', hint: 'Ô 01')),
                  ],
                ),
                _field(_noteC, 'Ghi chú'),
                Row(
                  children: [
                    const Text('Kích hoạt',
                        style: TextStyle(
                            fontSize: 13,
                            color: PopupTheme.textSecondary)),
                    const Spacer(),
                    Switch.adaptive(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      activeThumbColor: PopupTheme.blue,
                      activeTrackColor: PopupTheme.blue.withValues(alpha: 0.4),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        SizedBox(
          width: 90,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: PopupTheme.secondaryButton(),
            child: const Text('Hủy'),
          ),
        ),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _submit,
            icon: Icon(
              isEdit ? Icons.save_rounded : Icons.add_rounded,
              size: 16,
            ),
            label: Text(isEdit ? 'Lưu thay đổi' : 'Thêm vị trí'),
            style: PopupTheme.primaryButton(
                color: isEdit ? PopupTheme.blue : PopupTheme.green),
          ),
        ),
      ],
    );
  }
}
