import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../data/db_helper.dart';
import '../services/first_time_guide_service.dart';
import '../models/sale_order_model.dart';
import '../services/event_bus.dart';
import '../services/category_service.dart';
import '../services/business_type_helper.dart';
import '../models/shop_settings_model.dart';
import 'sale_detail_view.dart';
import 'create_sale_view.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/skeleton_list.dart';
import '../utils/vietnamese_utils.dart';
import '../utils/money_utils.dart';
import '../widgets/responsive_wrapper.dart';
import '../services/sales_return_service.dart';
import '../services/user_service.dart';
import '../services/customer_service.dart';
import '../services/notification_service.dart';
import '../services/encryption_service.dart';
import '../services/firestore_write_helper.dart';
import '../models/customer_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_sales_return_view.dart';
import '../l10n/app_localizations.dart';

class SaleListView extends StatefulWidget {
  final bool todayOnly;
  const SaleListView({super.key, this.todayOnly = false});

  @override
  State<SaleListView> createState() => _SaleListViewState();
}

class _SaleListViewState extends State<SaleListView> {
  final db = DBHelper();
  final ScrollController _scrollController = ScrollController();
  List<SaleOrder> _sales = [];
  List<SaleOrder> _allLoadedSales = []; // Cache for filtering
  bool _loading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  static const int _pageSize = 30;
  String _search = "";

  // Filter states
  String _timeFilter = 'today'; // all, today, week, month, custom
  String _paymentStatusFilter =
      'all'; // all, paid, debt, bank_pending, bank_received
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Return tracking: saleId -> return summary
  Map<int, _SaleReturnInfo> _returnInfoMap = {};

  // Permission
  bool _canViewCostPrice = false;

  // Search controller & sort
  final TextEditingController _searchController = TextEditingController();
  String _sortOrder = 'date_desc'; // date_desc, price_desc, debt_desc

  // EventBus subscriptions & debounce
  StreamSubscription<String>? _saleChangedSub;
  StreamSubscription<String>? _saleReturnSub;
  Timer? _saleRefreshDebounce;
  Timer? _searchDebounce;

  // Multi-Industry: Shop Settings
  ShopSettings? _shopSettings;
  BusinessTerminology get _terms =>
      BusinessTypeHelper.instance.getTerminology(_shopSettings);

  /// Check if we need full data (for filtering)
  bool get _needsFullData =>
      _search.isNotEmpty ||
      _timeFilter != 'all' ||
      _paymentStatusFilter != 'all';

  @override
  void initState() {
    super.initState();
    if (widget.todayOnly) {
      _timeFilter = 'today';
    }
    _refresh();
    _loadPermissions();

    // Setup scroll listener for lazy loading
    _scrollController.addListener(_onScroll);

    // Listen to sales changes (e.g., when settlement is received)
    _saleChangedSub = EventBus().on('sales_changed', (event) {
      debugPrint('🛒 [SaleListView] Nhận event "$event" → refresh local DB');
      _debouncedRefresh();
    });
    _saleReturnSub = EventBus().on('sales_returns_changed', (event) {
      debugPrint('🛒 [SaleListView] Nhận event "$event" → refresh local DB');
      _debouncedRefresh();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstTimeGuide());
  }

  Future<void> _showFirstTimeGuide() async {
    final l10n = AppLocalizations.of(context)!;
    await FirstTimeGuideService.showGuideIfNeeded(
      context: context,
      screenKey: FirstTimeGuideService.keySaleList,
      title: l10n.saleListGuideTitle,
      icon: Icons.receipt_long_rounded,
      color: Colors.teal,
      steps: [
        GuideStep(
          title: l10n.saleListGuide1Title,
          description: l10n.saleListGuide1Desc,
          icon: Icons.receipt_long_rounded,
          iconColor: Colors.teal,
        ),
        GuideStep(
          title: l10n.saleListGuide2Title,
          description: l10n.saleListGuide2Desc,
          icon: Icons.search_rounded,
          iconColor: Colors.blue,
        ),
        GuideStep(
          title: l10n.saleListGuide3Title,
          description: l10n.saleListGuide3Desc,
          icon: Icons.print_rounded,
          iconColor: Colors.orange,
        ),
        GuideStep(
          title: l10n.saleListGuide4Title,
          description: l10n.saleListGuide4Desc,
          icon: Icons.payment_rounded,
          iconColor: Colors.green,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _saleChangedSub?.cancel();
    _saleReturnSub?.cancel();
    _saleRefreshDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    try {
      final perms = await UserService.getCurrentUserPermissions();
      if (!mounted) return;
      setState(() {
        _canViewCostPrice = perms['allowViewCostPrice'] ?? false;
      });
    } catch (_) {}
  }

  void _debouncedRefresh() {
    _saleRefreshDebounce?.cancel();
    _saleRefreshDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _refresh();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMoreIfNeeded();
    }
  }

  Future<void> _loadMoreIfNeeded() async {
    if (_isLoadingMore || !_hasMore || _needsFullData) return;

    setState(() => _isLoadingMore = true);

    try {
      final newData = await db.getSalesPaged(_pageSize, _currentOffset);
      if (mounted) {
        setState(() {
          _allLoadedSales.addAll(newData);
          _sales = _allLoadedSales;
          _currentOffset += _pageSize;
          _isLoadingMore = false;
          _hasMore = newData.length >= _pageSize;
        });
      }
    } catch (e) {
      debugPrint('SaleListView: Error loading more: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _currentOffset = 0;
      _allLoadedSales = [];
      _hasMore = true;
    });

    // Load shop settings for terminology
    final settings = await CategoryService().getShopSettings();
    if (mounted) _shopSettings = settings;

    // Load return info per sale
    try {
      final returns = await SalesReturnService.getReturns();
      final map = <int, _SaleReturnInfo>{};
      for (final r in returns) {
        if (r.salesOrderId == null) continue;
        final sid = r.salesOrderId!;
        final info = map.putIfAbsent(sid, () => _SaleReturnInfo());
        info.totalReturnedAmount += r.totalReturnAmount;
        info.returnCount += 1;
      }
      _returnInfoMap = map;
    } catch (_) {}

    if (_needsFullData || widget.todayOnly) {
      // Optimize: use date-range query when time filter is set
      final List<SaleOrder> data;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      switch (_timeFilter) {
        case 'today':
          data = await db.getSalesByDateRange(
            today.millisecondsSinceEpoch,
            today.add(const Duration(days: 1)).millisecondsSinceEpoch - 1,
          );
          break;
        case 'week':
          data = await db.getSalesByDateRange(
            today.subtract(const Duration(days: 7)).millisecondsSinceEpoch,
            now.millisecondsSinceEpoch,
          );
          break;
        case 'month':
          data = await db.getSalesByDateRange(
            DateTime(now.year, now.month, 1).millisecondsSinceEpoch,
            now.millisecondsSinceEpoch,
          );
          break;
        case 'custom':
          if (_customStartDate != null && _customEndDate != null) {
            data = await db.getSalesByDateRange(
              _customStartDate!.millisecondsSinceEpoch,
              _customEndDate!
                      .add(const Duration(days: 1))
                      .millisecondsSinceEpoch -
                  1,
            );
          } else {
            data = await db.getAllSales();
          }
          break;
        default:
          data = await db.getAllSales();
      }
      if (!mounted) return;
      setState(() {
        _allLoadedSales = data;
        _sales = data;
        _loading = false;
        _hasMore = false;
      });
    } else {
      // Lazy load first page
      final firstPage = await db.getSalesPaged(_pageSize, 0);
      if (!mounted) return;
      setState(() {
        _allLoadedSales = firstPage;
        _sales = firstPage;
        _currentOffset = _pageSize;
        _loading = false;
        _hasMore = firstPage.length >= _pageSize;
      });
    }

    // Check fully-returned status (after sales loaded)
    _checkReturnStatus();
  }

  Future<void> _checkReturnStatus() async {
    if (_returnInfoMap.isEmpty) return;
    bool changed = false;
    for (final entry in _returnInfoMap.entries) {
      try {
        final sale = _allLoadedSales
            .where((s) => s.id == entry.key)
            .firstOrNull;
        if (sale != null && sale.id != null && sale.id! > 0) {
          final was = entry.value.allReturned;
          entry.value.allReturned = await _checkAllReturned(sale);
          if (was != entry.value.allReturned) changed = true;
        }
      } catch (_) {}
    }
    if (changed && mounted) setState(() {});
  }

  List<SaleOrder> _applyFilters() {
    var list = _sales.where((s) {
      // Search filter
      if (_search.isNotEmpty) {
        if (!VietnameseUtils.containsVietnamese(s.customerName, _search) &&
            !VietnameseUtils.containsVietnamese(s.productNames, _search) &&
            !s.allImeisForSearch.toUpperCase().contains(_search.toUpperCase())) {
          return false;
        }
      }

      // Time filter
      final saleDate = DateTime.fromMillisecondsSinceEpoch(s.soldAt);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      switch (_timeFilter) {
        case 'today':
          final saleDay = DateTime(saleDate.year, saleDate.month, saleDate.day);
          if (saleDay != today) return false;
          break;
        case 'week':
          final weekAgo = today.subtract(const Duration(days: 7));
          if (saleDate.isBefore(weekAgo)) return false;
          break;
        case 'month':
          final monthStart = DateTime(now.year, now.month, 1);
          if (saleDate.isBefore(monthStart)) return false;
          break;
        case 'custom':
          if (_customStartDate != null &&
              saleDate.isBefore(_customStartDate!)) {
            return false;
          }
          if (_customEndDate != null &&
              saleDate.isAfter(_customEndDate!.add(const Duration(days: 1)))) {
            return false;
          }
          break;
      }

      // Payment status filter - tách rõ trạng thái trả góp nhận tiền NH
      final remain = s.remainingDebt;
      final isInstallment =
          s.isInstallment || s.paymentMethod.toUpperCase().contains('TRẢ GÓP');
      final hasBankSettlement =
          (s.settlementReceivedAt ?? 0) > 0 || s.settlementAmount > 0;
      switch (_paymentStatusFilter) {
        case 'paid':
          if (isInstallment) {
            if (remain > 0 || !hasBankSettlement) return false;
          } else {
            if (remain > 0) return false;
          }
          break;
        case 'debt':
          if (remain <= 0) return false;
          break;
        case 'bank_pending':
          if (!isInstallment || hasBankSettlement) return false;
          break;
        case 'bank_received':
          if (!isInstallment || !hasBankSettlement) return false;
          break;
      }

      return true;
    }).toList();

    switch (_sortOrder) {
      case 'price_desc':
        list.sort((a, b) => b.finalPrice.compareTo(a.finalPrice));
      case 'debt_desc':
        list.sort((a, b) => b.remainingDebt.compareTo(a.remainingDebt));
      default:
        list.sort((a, b) => b.soldAt.compareTo(a.soldAt));
    }
    return list;
  }

  int get _activeFilterCount {
    int count = 0;
    if (_timeFilter != 'all' && !widget.todayOnly) count++;
    if (_paymentStatusFilter != 'all') count++;
    return count;
  }

  void _showFilterSheet() {
    final l10n = AppLocalizations.of(context)!;
    showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.saleListFilterTitle,
                    style: AppTextStyles.headline6.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _timeFilter = widget.todayOnly ? 'today' : 'all';
                            _paymentStatusFilter = 'all';
                            _customStartDate = null;
                            _customEndDate = null;
                          });
                          setState(() {});
                          _refresh();
                        },
                        child: Text(l10n.reset),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(l10n.done),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Time filter
              if (!widget.todayOnly) ...[
                Text(
                  l10n.saleListTimeSection,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip(l10n.all, 'all', _timeFilter, (v) {
                      setSheetState(() => _timeFilter = v);
                      setState(() {});
                      _refresh();
                    }),
                    _filterChip(l10n.today, 'today', _timeFilter, (v) {
                      setSheetState(() => _timeFilter = v);
                      setState(() {});
                      _refresh();
                    }),
                    _filterChip(l10n.saleListLast7Days, 'week', _timeFilter, (v) {
                      setSheetState(() => _timeFilter = v);
                      setState(() {});
                      _refresh();
                    }),
                    _filterChip(l10n.thisMonth, 'month', _timeFilter, (v) {
                      setSheetState(() => _timeFilter = v);
                      setState(() {});
                      _refresh();
                    }),
                    _filterChip(l10n.saleListCustomDate, 'custom', _timeFilter, (v) async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange:
                            _customStartDate != null && _customEndDate != null
                            ? DateTimeRange(
                                start: _customStartDate!,
                                end: _customEndDate!,
                              )
                            : null,
                        locale: const Locale('vi', 'VN'),
                      );
                      if (range != null) {
                        setSheetState(() {
                          _timeFilter = 'custom';
                          _customStartDate = range.start;
                          _customEndDate = range.end;
                        });
                        setState(() {});
                        _refresh();
                      }
                    }),
                  ],
                ),
                if (_timeFilter == 'custom' &&
                    _customStartDate != null &&
                    _customEndDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${DateFormat('dd/MM/yyyy').format(_customStartDate!)} - ${DateFormat('dd/MM/yyyy').format(_customEndDate!)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],

              // Payment status filter
              Text(
                l10n.saleListPaymentStatusSection,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterChip(l10n.all, 'all', _paymentStatusFilter, (v) {
                    setSheetState(() => _paymentStatusFilter = v);
                    setState(() {});
                  }),
                  _filterChip(l10n.saleListFilterPaid, 'paid', _paymentStatusFilter, (v) {
                    setSheetState(() => _paymentStatusFilter = v);
                    setState(() {});
                  }),
                  _filterChip(l10n.saleListFilterDebt, 'debt', _paymentStatusFilter, (v) {
                    setSheetState(() => _paymentStatusFilter = v);
                    setState(() {});
                  }),
                  _filterChip(l10n.saleListFilterBankPending, 'bank_pending', _paymentStatusFilter, (v) {
                    setSheetState(() => _paymentStatusFilter = v);
                    setState(() {});
                  }),
                  _filterChip(l10n.saleListFilterBankReceived, 'bank_received', _paymentStatusFilter, (v) {
                    setSheetState(() => _paymentStatusFilter = v);
                    setState(() {});
                  }),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(
    String label,
    String value,
    String currentValue,
    Function(String) onSelect,
  ) {
    final isSelected = currentValue == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.onSurface.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isSelected ? Colors.white : AppColors.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String _formatSaleDate(int soldAt) {
    final dt = DateTime.fromMillisecondsSinceEpoch(soldAt);
    if (_timeFilter == 'today') return DateFormat('HH:mm').format(dt);
    return DateFormat('dd/MM HH:mm').format(dt);
  }

  String _dayGroupLabel(DateTime dt) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
    if (diff == 0) return l10n.today;
    if (diff == 1) return l10n.saleListDayYesterday;
    final days = [l10n.sunday, l10n.monday, l10n.tuesday, l10n.wednesday, l10n.thursday, l10n.friday, l10n.saturday];
    return '${days[dt.weekday % 7]}, ${DateFormat('dd/MM').format(dt)}';
  }

  /// Flat list: String = group header, SaleOrder = item
  List<dynamic> _buildGroupedItems(List<SaleOrder> sales) {
    final l10n = AppLocalizations.of(context)!;
    if (sales.isEmpty) return [];
    if (_sortOrder != 'date_desc') return sales; // grouping only makes sense for date sort
    final dayCounts = <String, int>{};
    for (final s in sales) {
      final key = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(s.soldAt));
      dayCounts[key] = (dayCounts[key] ?? 0) + 1;
    }
    final result = <dynamic>[];
    String? currentKey;
    for (final s in sales) {
      final dt = DateTime.fromMillisecondsSinceEpoch(s.soldAt);
      final key = DateFormat('yyyy-MM-dd').format(dt);
      if (key != currentKey) {
        currentKey = key;
        result.add(l10n.saleListGroupOrdersCount(_dayGroupLabel(dt), dayCounts[key]!));
      }
      result.add(s);
    }
    return result;
  }

  Widget _buildActiveFilterChips() {
    final l10n = AppLocalizations.of(context)!;
    final chips = <Widget>[];
    if (_timeFilter != 'all' && !widget.todayOnly) {
      final label = {
        'today': l10n.today,
        'week': l10n.saleListLast7Days,
        'month': l10n.thisMonth,
        'custom': _customStartDate != null
            ? '${DateFormat('dd/MM').format(_customStartDate!)}–${DateFormat('dd/MM').format(_customEndDate!)}'
            : l10n.saleListCustomDate,
      }[_timeFilter] ?? _timeFilter;
      chips.add(_inlineChip(label, () {
        setState(() { _timeFilter = 'all'; _customStartDate = null; _customEndDate = null; });
        _refresh();
      }));
    }
    if (_paymentStatusFilter != 'all') {
      final labels = {
        'paid': l10n.saleListFilterPaid,
        'debt': l10n.saleListFilterDebt,
        'bank_pending': l10n.saleListFilterBankPending,
        'bank_received': l10n.saleListFilterBankReceived,
      };
      chips.add(_inlineChip(labels[_paymentStatusFilter] ?? _paymentStatusFilter, () {
        setState(() => _paymentStatusFilter = 'all');
      }));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Wrap(spacing: 6, children: chips),
    );
  }

  Widget _inlineChip(String label, VoidCallback onRemove) {
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(width: 3),
            Icon(Icons.close, size: 11, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _applyFilters();

    // Calculate summary stats
    final int totalSales = list.length;
    final int totalRevenue = list.fold(0, (sum, s) => sum + s.totalPrice);
    final int totalDebt = list.fold(0, (sum, s) => sum + s.remainingDebt);
    final int totalProfit = _canViewCostPrice
        ? list.fold(0, (sum, s) => sum + (s.finalPrice - s.totalCost))
        : 0;
    // Pre-build grouped items + index map for date grouping
    final groupedItems = _buildGroupedItems(list);
    final indexMap = <int?, int>{};
    int _seq = 0;
    for (final item in groupedItems) {
      if (item is SaleOrder) { _seq++; indexMap[item.id] = _seq; }
    }

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar.build(
        title: widget.todayOnly ? l10n.todaySales : l10n.saleListTitle,
        subtitle:
            '$totalSales ${l10n.ordersCount} • ${MoneyUtils.formatCompactCurrency(totalRevenue)}',
        accentColor: AppBarAccents.sales,
        centerTitle: false,
        actions: [
          // Create sale order
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateSaleView()),
            ).then((_) => _refresh()),
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: Colors.white,
            ),
            tooltip: l10n.createSale,
          ),
          // Sort
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: Colors.white),
            tooltip: l10n.saleListSortTooltip,
            initialValue: _sortOrder,
            onSelected: (v) => setState(() => _sortOrder = v),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'date_desc', child: Text(l10n.saleListSortNewest)),
              PopupMenuItem(value: 'price_desc', child: Text(l10n.saleListSortHighestValue)),
              PopupMenuItem(value: 'debt_desc', child: Text(l10n.saleListSortMostDebt)),
            ],
          ),
          // Filter
          Stack(
            children: [
              IconButton(
                onPressed: _showFilterSheet,
                icon: const Icon(
                  Icons.filter_list_rounded,
                  color: Colors.white,
                ),
                tooltip: l10n.filter,
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_activeFilterCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppTextStyles.caption.fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 200), () {
                  if (mounted) setState(() => _search = v);
                });
              },
              style: TextStyle(fontSize: AppTextStyles.headline5.fontSize),
              decoration: InputDecoration(
                hintText: l10n.saleListSearchHint(
                  _terms.productLabel.toLowerCase(),
                  _terms.specialField1Label,
                ),
                hintStyle: TextStyle(
                  fontSize: AppTextStyles.headline5.fontSize,
                  color: Colors.grey.shade500,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppBarAccents.sales,
                  size: 20,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const SkeletonListView(
              variant: SkeletonVariant.repairCard,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            )
          : ResponsiveCenter(
              child: Column(
                children: [
                  // Summary stats bar – compact 1 row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$totalSales ${l10n.ordersCount}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          ' • ',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          l10n.saleListRevenueShort(MoneyUtils.formatCompactCurrency(totalRevenue)),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                        if (totalDebt > 0) ...[
                          Text(' • ', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                          Text(
                            l10n.saleListDebtShort(MoneyUtils.formatCompactCurrency(totalDebt)),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error),
                          ),
                        ],
                        if (_canViewCostPrice && totalProfit != 0) ...[
                          Text(' • ', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                          Text(
                            l10n.saleListProfitShort(MoneyUtils.formatCompactCurrency(totalProfit)),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: totalProfit >= 0 ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          '${list.length} ${l10n.ordersCount}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),

                  _buildActiveFilterChips(),

                  // List
                  Expanded(
                    child: list.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.shopping_bag_outlined,
                            title: l10n.saleListNoOrders,
                            subtitle: _activeFilterCount > 0 ? l10n.saleListClearFilterHint : null,
                            actionLabel: _activeFilterCount > 0 ? l10n.saleListClearFilter : null,
                            onAction: _activeFilterCount > 0
                                ? () {
                                    _timeFilter = widget.todayOnly ? 'today' : 'all';
                                    _paymentStatusFilter = 'all';
                                    _refresh();
                                  }
                                : null,
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            itemCount: groupedItems.length +
                                (_isLoadingMore ? 1 : 0) +
                                (!_hasMore && list.isNotEmpty ? 1 : 0),
                            itemBuilder: (ctx, i) {
                              // Footer items (loading / end text)
                              if (i >= groupedItems.length) {
                                if (_isLoadingMore) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: Text(
                                      l10n.saleListDisplayedOrders(list.length),
                                      style: TextStyle(color: Colors.grey[600], fontSize: AppTextStyles.subtitle1.fontSize),
                                    ),
                                  ),
                                );
                              }

                              final item = groupedItems[i];

                              // Date group header
                              if (item is String) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                                  child: Text(
                                    item,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                                  ),
                                );
                              }

                              final s = item as SaleOrder;
                              final date = _formatSaleDate(s.soldAt);
                              final remain = s.remainingDebt;
                              final index = indexMap[s.id] ?? 0;
                              final isPaid = s.isPaid;
                              final isInstallment =
                                  s.isInstallment ||
                                  s.paymentMethod
                                      .toUpperCase()
                                      .contains('TRẢ GÓP');
                              final hasBankSettlement =
                                  (s.settlementReceivedAt ?? 0) > 0 ||
                                  s.settlementAmount > 0;
                              final returnInfo = s.id != null
                                  ? _returnInfoMap[s.id]
                                  : null;
                              final isFullyReturned =
                                  returnInfo?.allReturned == true;
                                final accentColor = isFullyReturned
                                  ? Colors.grey.shade500
                                  : (isInstallment && !hasBankSettlement)
                                  ? Colors.orange.shade600
                                  : (isPaid
                                    ? Colors.green.shade600
                                    : Colors.orange.shade600);
                                final borderColor = accentColor.withValues(
                                alpha: 0.22,
                                );

                              final paidAmount = (s.finalPrice - remain).clamp(0, s.finalPrice);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: borderColor, width: 1),
                                ),
                                elevation: 0,
                                color: Colors.white,
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SaleDetailView(sale: s),
                                      ),
                                    ).then((_) => _refresh());
                                  },
                                  onLongPress: () {
                                    HapticFeedback.mediumImpact();
                                    _openReturn(s);
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Accent bar
                                        Container(
                                          width: 5,
                                          decoration: BoxDecoration(
                                            color: accentColor,
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(10),
                                              bottomLeft: Radius.circular(10),
                                            ),
                                          ),
                                        ),
                                        // Content
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // ROW 1: Index · Product · Status badge
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                      constraints: const BoxConstraints(minWidth: 20),
                                                      height: 17,
                                                      margin: const EdgeInsets.only(right: 6),
                                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primary.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          '$index',
                                                          style: const TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppColors.primary,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        s.productNamesDisplay,
                                                        style: const TextStyle(
                                                          fontSize: 13.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: Color(0xFF0F172A),
                                                          letterSpacing: -0.2,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: accentColor,
                                                        borderRadius: BorderRadius.circular(5),
                                                      ),
                                                      child: Text(
                                                        isFullyReturned
                                                            ? l10n.saleListStatusReturned
                                                            : (isInstallment && !hasBankSettlement)
                                                            ? l10n.saleListStatusBankPending
                                                            : (isPaid ? l10n.saleListStatusCollected : l10n.saleListStatusHasDebt),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                // ROW 2: Customer · Seller · Date
                                                Row(
                                                  children: [
                                                    if (s.customerName.isNotEmpty) ...[
                                                      const Icon(Icons.person_outline, size: 11, color: Color(0xFF475569)),
                                                      const SizedBox(width: 3),
                                                      Expanded(
                                                        child: Text(
                                                          s.sellerName.isNotEmpty
                                                              ? '${s.customerName}  ·  ${s.sellerName}'
                                                              : s.customerName,
                                                          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ] else ...[
                                                      GestureDetector(
                                                        onTap: () => _addCustomerToSale(s),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Colors.orange.shade50,
                                                            borderRadius: BorderRadius.circular(8),
                                                            border: Border.all(color: Colors.orange.shade200),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(Icons.person_add_outlined, size: 10, color: Colors.orange.shade700),
                                                              const SizedBox(width: 3),
                                                              Text('Thêm khách', style: TextStyle(fontSize: 10, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const Spacer(),
                                                    ],
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      date,
                                                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                // ROW 3: Đã thu / Nợ
                                                if (s.finalPrice > 0)
                                                  _saleInfoRow(
                                                    left: _saleChip(
                                                      l10n.saleListChipPaid,
                                                      MoneyUtils.formatCompactCurrency(paidAmount),
                                                      const Color(0xFF0369A1),
                                                      const Color(0xFFE0F2FE),
                                                    ),
                                                    right: remain > 0
                                                        ? _saleChip(
                                                            l10n.saleListChipDebt,
                                                            MoneyUtils.formatCompactCurrency(remain),
                                                            const Color(0xFFB45309),
                                                            const Color(0xFFFEF3C7),
                                                          )
                                                        : null,
                                                  ),
                                                const SizedBox(height: 3),
                                                // ROW 4: Bán / Vốn
                                                _saleInfoRow(
                                                  left: s.finalPrice > 0
                                                      ? _saleChip(
                                                          l10n.saleListChipSale,
                                                          MoneyUtils.formatCompactCurrency(s.finalPrice),
                                                          const Color(0xFF374151),
                                                          const Color(0xFFF1F5F9),
                                                        )
                                                      : null,
                                                  right: (_canViewCostPrice && s.totalCost > 0)
                                                      ? _saleChip(
                                                          l10n.saleListChipCost,
                                                          MoneyUtils.formatCompactCurrency(s.totalCost),
                                                          const Color(0xFF6B7280),
                                                          const Color(0xFFF8FAFC),
                                                        )
                                                      : null,
                                                ),
                                                // ROW 5: Lãi / Lỗ
                                                if (_canViewCostPrice && s.totalCost > 0 && s.finalPrice > 0)
                                                  Builder(builder: (ctx) {
                                                    final profit = s.finalPrice - s.totalCost;
                                                    final isGain = profit >= 0;
                                                    return Padding(
                                                      padding: const EdgeInsets.only(top: 3),
                                                      child: _saleChip(
                                                        isGain ? l10n.saleListChipProfit : l10n.saleListChipLoss,
                                                        (isGain ? '+' : '') + MoneyUtils.formatCompactCurrency(profit.abs()),
                                                        isGain ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                                                        isGain ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                                      ),
                                                    );
                                                  }),
                                                // ROW 6: Return info (amber)
                                                if (returnInfo != null)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 3),
                                                    child: _saleChip(
                                                      isFullyReturned ? l10n.saleListReturnFull : l10n.saleListReturnPartial,
                                                      isFullyReturned
                                                          ? MoneyUtils.formatCompactCurrency(returnInfo.totalReturnedAmount)
                                                          : l10n.saleListReturnTimesCount(
                                                              MoneyUtils.formatCompactCurrency(returnInfo.totalReturnedAmount),
                                                              returnInfo.returnCount,
                                                            ),
                                                      isFullyReturned ? Colors.grey.shade600 : Colors.orange.shade800,
                                                      isFullyReturned ? Colors.grey.shade100 : Colors.orange.shade50,
                                                    ),
                                                  ),
                                                // ROW 7: Trả góp
                                                if (isInstallment)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 3),
                                                    child: _saleChip(
                                                      l10n.saleListInstallmentLabel,
                                                      hasBankSettlement
                                                          ? l10n.saleListBankReceivedAmount(MoneyUtils.formatCompactCurrency(s.settlementAmount))
                                                          : l10n.saleListBankNotReceived,
                                                      hasBankSettlement ? const Color(0xFF0369A1) : const Color(0xFF92400E),
                                                      hasBankSettlement ? const Color(0xFFE0F2FE) : const Color(0xFFFEF3C7),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Chip màu thể hiện 1 chỉ số tài chính trong card đơn bán
  Widget _saleChip(String label, String value, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontSize: 10,
                color: textColor.withValues(alpha: 0.75),
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 10,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hàng 2 chip cạnh nhau với Spacer cuối
  Widget _saleInfoRow({Widget? left, Widget? right}) {
    if (left == null && right == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (left != null) left,
        if (left != null && right != null) const SizedBox(width: 6),
        if (right != null) right,
      ],
    );
  }

  // ── Add customer to sale (retroactive) ──

  Future<void> _addCustomerToSale(SaleOrder s) async {
    final phoneCtrl = TextEditingController(text: s.phone);
    final nameCtrl = TextEditingController(text: s.customerName);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.person_add, size: 20),
          SizedBox(width: 8),
          Text('Thêm thông tin khách hàng', style: TextStyle(fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Tên khách hàng',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusScope.of(ctx).unfocus();
              Navigator.pop(ctx, false);
            },
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              FocusScope.of(ctx).unfocus();
              Navigator.pop(ctx, true);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final newPhone = phoneCtrl.text.trim();
    final newName = nameCtrl.text.trim().toUpperCase();
    if (newPhone.isEmpty && newName.isEmpty) return;

    try {
      // Update local DB — mutate fields directly (SaleOrder has no copyWith)
      s.customerName = newName;
      s.phone = newPhone;
      s.isWalkIn = newPhone.isEmpty && newName.isEmpty;
      s.walkInName = s.isWalkIn ? newName : null;
      s.isSynced = false;
      await db.upsertSale(s);

      // Sync Firestore
      if (s.firestoreId != null && s.firestoreId!.isNotEmpty) {
        final encData = EncryptionService.encryptMap({
          'customerName': newName,
          'phone': newPhone,
          'isWalkIn': newPhone.isEmpty && newName.isEmpty,
          'updatedAt': FirestoreWriteHelper.serverUpdatedAt(),
        });
        await FirebaseFirestore.instance
            .collection('sales')
            .doc(s.firestoreId)
            .update(encData);
      }

      // Save customer + recalculate stats
      if (newPhone.isNotEmpty) {
        final customerService = CustomerService();
        final shopId = await UserService.getCurrentShopId();
        final allSales = await db.getCustomerSalesHistory(newPhone, shopId);
        final validSales = allSales.where((x) => (x['deleted'] ?? 0) != 1).toList();
        final totalSpent = validSales.fold<int>(
          0, (acc, x) => acc + ((x['totalPrice'] as num?)?.toInt() ?? 0));
        final lastVisit = validSales.isNotEmpty
            ? validSales.map((x) => (x['soldAt'] as num?)?.toInt() ?? 0).reduce((a, b) => a > b ? a : b)
            : DateTime.now().millisecondsSinceEpoch;

        final existing = shopId != null ? await db.getCustomerByPhone(newPhone, shopId) : <Map<String, dynamic>>[];
        if (existing.isEmpty) {
          await customerService.addCustomer(Customer(
            name: newName.isNotEmpty ? newName : newPhone,
            phone: newPhone,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            totalSpent: totalSpent,
            lastVisitAt: lastVisit,
          ));
        } else {
          final existingId = (existing.first['id'] as num?)?.toInt();
          if (existingId != null) {
            await db.updateCustomer(existingId, {
              if (newName.isNotEmpty) 'name': newName,
              'totalSpent': totalSpent,
              'lastVisitAt': lastVisit,
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
            });
          }
        }
      }

      setState(() {});
      if (mounted) {
        NotificationService.showSnackBar('Đã cập nhật thông tin khách hàng', color: Colors.green);
      }
    } catch (e) {
      if (mounted) NotificationService.showSnackBar('Lỗi: $e', color: Colors.red);
    }
  }

  // ── Return helpers ──

  Future<bool> _checkAllReturned(SaleOrder sale) async {
    if (sale.id == null || sale.id! <= 0) return false;
    final returnedMap = await db.getReturnedQuantitiesForSale(sale.id!);
    if (returnedMap.isEmpty) return false;
    final names = sale.productNames.split(RegExp(r',\s*'));
    final imeis = sale.productImeis.split(RegExp(r',\s*'));
    for (int i = 0; i < names.length; i++) {
      final name = names[i].trim();
      if (name.isEmpty) continue;
      final imei = i < imeis.length ? imeis[i].trim() : '';
      int origQty = 1;
      String cleanName = name;
      final qtyMatch = RegExp(r'^(.+?)\s+[xX](\d+)').firstMatch(name);
      if (qtyMatch != null) {
        cleanName = qtyMatch.group(1)!.trim();
        origQty = int.tryParse(qtyMatch.group(2)!) ?? 1;
      }
      if (imei.toUpperCase().startsWith('PKX')) {
        origQty = int.tryParse(imei.toUpperCase().replaceAll('PKX', '')) ?? 1;
      }
      final isPhone =
          imei.isNotEmpty &&
          !imei.toUpperCase().startsWith('PKX') &&
          imei != 'NO_IMEI';
      final key = isPhone ? imei.toUpperCase() : cleanName.toUpperCase();
      final returned = returnedMap[key] ?? 0;
      if (returned < origQty) return false;
    }
    return true;
  }

  void _openReturn(SaleOrder s) async {
    final l10n = AppLocalizations.of(context)!;
    final info = _returnInfoMap[s.id];
    if (info != null && info.allReturned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.saleListOrderFullyReturned),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateSalesReturnView(sale: s)),
    );
    if (result == true && mounted) {
      _refresh();
    }
  }
}

class _SaleReturnInfo {
  int totalReturnedAmount = 0;
  int returnCount = 0;
  bool allReturned = false;
}
