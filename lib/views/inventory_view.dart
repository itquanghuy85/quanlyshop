import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/money_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/db_helper.dart';
import '../constants/product_constants.dart';
import '../utils/vietnamese_utils.dart';
import '../models/product_model.dart';
import '../models/inventory_check_model.dart';
import 'create_sale_view.dart';
import '../services/sync_orchestrator.dart';
import '../services/sync_service.dart';
import '../services/unified_printer_service.dart';
import '../services/notification_service.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/skeleton_list.dart';
import '../services/user_service.dart';
import '../services/event_bus.dart';
import '../services/supplier_service.dart';
import '../services/firestore_service.dart';
import '../services/first_time_guide_service.dart';
import '../services/variant_service.dart';
import '../widgets/printer_selection_dialog.dart';
import '../widgets/variant_selector.dart';
import '../models/printer_types.dart';
import 'smart_stock_in_view.dart';
import 'parts_inventory_view.dart';
import 'pty_print_designer_view.dart';
import '../widgets/currency_text_field.dart';
import '../widgets/validated_text_field.dart';
import '../models/stock_entry_model.dart';
import '../services/stock_entry_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/custom_app_bar.dart';
import '../services/category_service.dart';
import '../services/business_type_helper.dart';
import '../models/shop_settings_model.dart';
import '../utils/excel_export_helper.dart';
import '../widgets/export_date_filter_dialog.dart';
import '../widgets/responsive_wrapper.dart';
import '../widgets/app_cached_image.dart';
import '../widgets/image_picker_widget.dart';
import '../widgets/storage_location_selector.dart';
import '../services/product_image_service.dart';
import '../models/storage_location_model.dart';
import 'storage_location_view.dart';
import '../theme/popup_theme.dart';
import '../widgets/app_popup.dart';
import '../widgets/ai_order_input_sheet.dart';
import '../models/supplier_model.dart';
import 'supplier_detail_view.dart';
import '../l10n/app_localizations.dart';

class InventoryView extends StatefulWidget {
  final String role;
  final String initialFilterType;
  final bool triggerPartsAdd;
  const InventoryView({
    super.key,
    required this.role,
    this.initialFilterType = 'TẤT CẢ',
    this.triggerPartsAdd = false,
  });
  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView>
    with TickerProviderStateMixin {
  final db = DBHelper();
  final supplierService = SupplierService();
  List<Product> _products = [];
  List<Product> _allLoadedProducts = []; // Cache for filtering
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  static const int _pageSize =
      20; // Load 20 products at a time to reduce frequent paging on long lists
  int _unsyncedCount = 0;
  bool _canViewCostPrice = false; // Phân quyền xem giá vốn

  // Total inventory summary from DB (not from paginated data)
  int _totalQtyFromDB = 0;
  int _totalCapitalFromDB = 0;
  bool _hasInventoryAccess = false;
  String _searchQuery = "";
  bool _showOutOfStock = false; // Hiển thị cả hàng hết
  String _filterType =
      'TẤT CẢ'; // Filter theo loại: TẤT CẢ, DIEN_THOAI, PHỤ KIỆN, LINH_KIEN
  String? _filterLocationCode; // Filter theo vị trí lưu kho
  bool _showNoCostOnly = false; // Lọc sản phẩm chưa có giá vốn (cost == 0)
  int _repairPartsCount = 0; // Count for repair parts tab chip

  // ScrollController for lazy loading
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _inventoryEventSub;
  Timer? _inventoryRefreshDebounce;

  final Set<String> _inventoryRefreshEvents = {
    'sales_changed',
    'sales_returns_changed',
    'products_changed',
    'stock_entries_changed',
    'sync_now_completed',
    'app_resumed',
    EventBus.dataRefresh,
    EventBus.shopChanged,
  };

  /// Check if we need full data (for filtering)
  bool get _needsFullData =>
      _searchQuery.isNotEmpty ||
      _filterType != 'TẤT CẢ' ||
      _showOutOfStock ||
      _showNoCostOnly ||
      _filterLocationCode != null;

  final Set<int> _selectedIds = {};
  bool _isSelectionMode = false;

  // Tab controller
  late TabController _tabController;

  // Inventory check variables
  String _selectedType = 'DIEN_THOAI';
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 1000,
    formats: [BarcodeFormat.all],
  );
  InventoryCheck? _currentCheck;

  // Phase 2: Multi-Industry - Shop Settings
  ShopSettings? _shopSettings;
  bool get _enableExpiry => _shopSettings?.enableExpiry ?? false;
  bool get _enableBatch => _shopSettings?.enableBatch ?? false;
  bool get _enableSerial => _shopSettings?.enableSerial ?? true;
  bool get _enableVariants => _shopSettings?.enableVariants ?? false;
  bool get _enableRepair => _shopSettings?.enableRepair ?? true;
  String get _businessType => _shopSettings?.businessType ?? 'electronics';
  bool get _isFashion => _businessType == 'fashion';
  bool get _isElectronics => _businessType == 'electronics';
  bool get _allowPendingCost => _shopSettings?.allowPendingCost ?? false;

  // Variant Service for fashion products
  final VariantService _variantService = VariantService();

  int _safeToInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  /// Terminology động theo ngành
  BusinessTerminology get _terms =>
      BusinessTypeHelper.instance.getTerminology(_shopSettings);

  // Notifier to trigger add-part dialog from AppBar button
  final ValueNotifier<int> _partsAddTrigger = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _filterType = widget.initialFilterType;
    _tabController = TabController(length: 1, vsync: this);
    _bindInventoryRefreshEvents();
    _init(); // _init sẽ gọi _initCheckData sau khi load shop settings
    // Setup scroll listener for lazy loading
    _scrollController.addListener(_onScroll);
    // Hiển thị hướng dẫn cho người dùng mới
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFirstTimeGuide();
      // Auto-open add dialog if requested (e.g. from repair detail "NHẬP LK MỚI")
      if (widget.triggerPartsAdd && _filterType == 'LINH_KIEN') {
        _partsAddTrigger.value++;
      }
    });
  }

  /// Hiển thị hướng dẫn lần đầu
  Future<void> _showFirstTimeGuide() async {
    await FirstTimeGuideService.showGuideIfNeeded(
      context: context,
      screenKey: FirstTimeGuideService.keyProductList,
      title: 'Danh Sách ${_terms.productLabel}',
      icon: Icons.inventory_2,
      color: Colors.blue,
      steps: [
        GuideStep(
          title: '📦 Tồn kho hiện tại',
          description:
              'Danh sách tất cả ${_terms.productLabel.toLowerCase()} trong kho. Lọc theo loại hoặc tìm kiếm nhanh.',
          icon: Icons.list,
          iconColor: Colors.blue,
        ),
        GuideStep(
          title: '🔍 Tìm kiếm',
          description:
              'Nhấn icon kính lúp để tìm theo tên, ${_terms.specialField1Label}, SKU. Hỗ trợ tìm kiếm toàn cục.',
          icon: Icons.search,
          iconColor: Colors.blue,
        ),
        GuideStep(
          title: '🛒 Bán hàng nhanh',
          description:
              'Nhấn vào ${_terms.productLabel.toLowerCase()} để xem chi tiết, hoặc vuốt để bán nhanh/in tem.',
          icon: Icons.shopping_cart,
          iconColor: Colors.green,
        ),
        GuideStep(
          title: '✏️ Chỉnh sửa giá',
          description:
              'Admin có thể chỉnh sửa giá bán, giá nhập trực tiếp từ chi tiết ${_terms.productLabel.toLowerCase()}.',
          icon: Icons.edit,
          iconColor: Colors.orange,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _partsAddTrigger.dispose();
    _inventoryRefreshDebounce?.cancel();
    _inventoryEventSub?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tabController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _bindInventoryRefreshEvents() {
    _inventoryEventSub?.cancel();
    _inventoryEventSub = EventBus().stream
        .where((event) => _inventoryRefreshEvents.contains(event))
        .listen((event) {
          if (!mounted) return;
          debugPrint(
            '📦 [InventoryView] Nhận event "$event" → refresh local DB',
          );

          // sales_returns_changed cần cloud refresh vì product quantity thay đổi từ cloud
          // stock_entries_changed không cần: stock_entry_service đã ghi local DB trực tiếp
          if (event == 'sales_returns_changed') {
            unawaited(
              SyncService.refreshCloudCollections(
                reason: 'inventory_view_$event',
                force: true,
              ),
            );
          }

          _inventoryRefreshDebounce?.cancel();
          _inventoryRefreshDebounce = Timer(
            Duration(
              milliseconds: event == 'sales_returns_changed' ? 600 : 220,
            ),
            () async {
              if (!mounted) return;
              await _refreshLocalData();
            },
          );
        });
  }

  void _onScroll() {
    if (!mounted) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMoreIfNeeded();
    }
  }

  Future<void> _loadMoreIfNeeded() async {
    if (_isLoadingMore || !_hasMore || _needsFullData) return;
    if (!mounted) return;
    setState(() => _isLoadingMore = true);

    try {
      final newData = await db.getProductsPaged(_pageSize, _currentOffset);
      if (mounted) {
        setState(() {
          _allLoadedProducts.addAll(newData);
          _products = _allLoadedProducts;
          _currentOffset += _pageSize;
          _isLoadingMore = false;
          _hasMore = newData.length >= _pageSize;
        });
      }
    } catch (e) {
      debugPrint('InventoryView: Error loading more: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _applySearchQuery(String query) {
    final wasFullData = _needsFullData;
    setState(() => _searchQuery = query.trim());
    final isFullData = _needsFullData;
    if (wasFullData != isFullData) {
      _refreshLocalData();
    }
  }

  Future<void> _openSearchDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _searchQuery);
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: PopupTheme.bgDark,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(PopupTheme.radiusSheet),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PopupDragHandle(),
              Text(
                l10n.inventorySearchProduct(_terms.productLabel.toLowerCase()),
                style: AppTextStyles.headline4.copyWith(
                  fontWeight: FontWeight.bold,
                  color: PopupTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.inventorySearchHint(
                      _terms.productLabel.toLowerCase(),
                      _terms.category2.toLowerCase(),
                      _terms.specialField1Label),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                  ),
                ),
                onSubmitted: (text) => Navigator.pop(ctx, text),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, ''),
                    child: Text(l10n.delete),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.cancel),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, controller.text),
                    child: Text(l10n.search),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (value == null) return;
    _applySearchQuery(value);
  }

  static ButtonStyle _compactFilledBtn(Color color) =>
      ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PopupTheme.radiusButton),
        ),
        textStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.2),
      );

  static ButtonStyle _compactOutlineBtn(Color color) =>
      OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color, width: 1.5),
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PopupTheme.radiusButton),
        ),
        textStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.2),
      );

  Widget _input(
    TextEditingController c,
    String l,
    IconData i, {
    FocusNode? next,
    TextInputType type = TextInputType.text,
    String? suffix,
    bool caps = false,
    bool readOnly = false,
  }) {
    if (type == TextInputType.number &&
        (l.contains('GIÁ') || l.contains('TIỀN') || suffix == 'k')) {
      // Use CurrencyTextField for price fields
      bool multiply = !(l.contains('GIÁ NHẬP') || l.contains('GIÁ BÁN'));
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: CurrencyTextField(
          controller: c,
          label: l,
          icon: i,
          autoMultiply1000: multiply,
          onSubmitted: () {
            if (next != null) FocusScope.of(context).requestFocus(next);
          },
        ),
      );
    } else {
      // Use ValidatedTextField for text fields
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ValidatedTextField(
          controller: c,
          label: l,
          icon: i,
          keyboardType: type,
          uppercase: caps,
          onSubmitted: () {
            if (next != null) FocusScope.of(context).requestFocus(next);
          },
        ),
      );
    }
  }
  Future<void> _openSupplierByName(String name) async {
    if (name.isEmpty || name == 'N/A') return;
    final map = await DBHelper().getSupplierByName(name);
    if (!mounted) return;
    final supplier = map != null
        ? Supplier.fromMap(map)
        : Supplier(name: name, shopId: '');
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => SupplierDetailView(supplier: supplier)),
    );
  }

  void _showProductDetail(Product p) async {
    HapticFeedback.lightImpact();
    final l10n = AppLocalizations.of(context)!;

    // Đọc từ local DB — nguồn dữ liệu duy nhất, SyncService giữ local DB luôn mới
    Product displayProduct = p;
    if (p.firestoreId != null) {
      try {
        final localProduct = await db.getProductByFirestoreId(p.firestoreId!);
        if (localProduct != null) {
          displayProduct = localProduct;
          debugPrint(
            '✅ [InventoryView] Đọc product từ local DB: ${localProduct.name}',
          );
        }
      } catch (e) {
        debugPrint('⚠️ [InventoryView] Lỗi đọc local DB: $e');
      }
    }

    final repairs = await db.getRepairsByImei(displayProduct.imei ?? '');
    final displayName = ProductConstants.cleanProductName(displayProduct.name);
    final normalizedCapacity = ProductConstants.mapCapacity(
      displayProduct.capacity,
    ).trim();
    final showCapacityDetail =
        normalizedCapacity.isNotEmpty &&
        !displayName.contains(normalizedCapacity);
    if (!mounted) return;
    final imagePath = (displayProduct.images ?? '')
        .split(',')
        .map((e) => e.trim())
        .firstWhere((e) => e.isNotEmpty, orElse: () => '');
    final hasLocation = (displayProduct.locationCode ?? '').isNotEmpty;
    final profit = displayProduct.price - displayProduct.cost;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: PopupTheme.bgDark,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(PopupTheme.radiusSheet),
            ),
          ),
          child: Column(
            children: [
              // ── Drag handle ──────────────────────────────────────
              const PopupDragHandle(),
              // ── Header: image + name + close ─────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PopupProductImage(imageUrl: imagePath, size: 72),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: PopupTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (displayProduct.capacity != null &&
                              displayProduct.capacity!.isNotEmpty ||
                              displayProduct.color != null &&
                              displayProduct.color!.isNotEmpty ||
                              displayProduct.condition.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              [
                                if (displayProduct.capacity?.isNotEmpty == true)
                                  displayProduct.capacity!,
                                if (displayProduct.color?.isNotEmpty == true)
                                  displayProduct.color!,
                                if (displayProduct.condition.isNotEmpty)
                                  displayProduct.condition,
                              ].join(' · '),
                              style: const TextStyle(
                                color: PopupTheme.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: PopupTheme.surfaceDark,
                          shape: BoxShape.circle,
                          border: Border.all(color: PopupTheme.borderDark),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: PopupTheme.textSecondary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ── Tags row ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    if (displayProduct.isPending)
                      PopupBadge(
                        label: l10n.inventoryTempStockLabel,
                        color: PopupTheme.yellow,
                        icon: Icons.hourglass_bottom_rounded,
                      )
                    else
                      PopupBadge(
                        label: displayProduct.quantity > 0 ? l10n.inventoryInStockLabel : l10n.outOfStock,
                        color: displayProduct.quantity > 0
                            ? PopupTheme.green
                            : PopupTheme.red,
                        icon: displayProduct.quantity > 0
                            ? Icons.check_circle_outline
                            : Icons.remove_circle_outline,
                      ),
                    if (_enableSerial &&
                        (displayProduct.imei ?? '').isNotEmpty) ...[
                      const SizedBox(width: 8),
                      PopupBadge(
                        label: '# ${displayProduct.imei!}',
                        color: PopupTheme.purple,
                        icon: Icons.fingerprint,
                      ),
                    ],
                    if (displayProduct.updatedAt != null) ...[
                      const SizedBox(width: 8),
                      PopupBadge(
                        label: DateFormat('dd/MM/yyyy').format(
                          DateTime.fromMillisecondsSinceEpoch(
                              displayProduct.updatedAt!),
                        ),
                        color: PopupTheme.blue,
                        icon: Icons.calendar_today_outlined,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // ── Scrollable content ────────────────────────────────
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    // Pending warning banner
                    if (displayProduct.isPending) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: PopupTheme.yellow.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(PopupTheme.radiusCard),
                          border: Border.all(
                            color: PopupTheme.yellow.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.hourglass_empty,
                                color: PopupTheme.yellow, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.inventoryTempStockBanner,
                                    style: const TextStyle(
                                      color: PopupTheme.yellow,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (displayProduct.pendingSupplier != null)
                                    Text(
                                      l10n.inventoryExpectedSupplier(displayProduct.pendingSupplier!),
                                      style: const TextStyle(
                                        color: PopupTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // ── Stats cards ───────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: PopupStatCard(
                            icon: Icons.inventory_2_outlined,
                            color: PopupTheme.blue,
                            value: '${displayProduct.quantity}',
                            label: l10n.inventoryStockQty,
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (_canViewCostPrice) ...[
                          Expanded(
                            child: PopupStatCard(
                              icon: Icons.attach_money_rounded,
                              color: PopupTheme.yellow,
                              value: displayProduct.isPending
                                  ? '?'
                                  : MoneyUtils.formatCompactCurrency(
                                      displayProduct.cost),
                              label: l10n.inventoryPurchasePrice,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: PopupStatCard(
                            icon: Icons.sell_outlined,
                            color: PopupTheme.green,
                            value: displayProduct.isPending
                                ? '?'
                                : MoneyUtils.formatCompactCurrency(displayProduct.price),
                            label: l10n.inventorySalePriceItem,
                          ),
                        ),
                        if (_canViewCostPrice && !displayProduct.isPending) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: PopupStatCard(
                              icon: Icons.trending_up_rounded,
                              color: profit >= 0
                                  ? PopupTheme.teal
                                  : PopupTheme.red,
                              value: MoneyUtils.formatCompactCurrency(profit.abs()),
                              label: profit >= 0 ? l10n.profit : l10n.inventoryLoss,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    // ── Info rows ─────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: PopupTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(PopupTheme.radiusCard),
                        border: Border.all(color: PopupTheme.borderDark),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Column(
                        children: [
                          if (_enableSerial)
                            PopupInfoRow(
                              icon: Icons.fingerprint,
                              iconColor: PopupTheme.purple,
                              label: _terms.specialField1Label,
                              value: (displayProduct.imei ?? '').isEmpty
                                  ? 'N/A'
                                  : displayProduct.imei!,
                            ),
                          if (_isElectronics && showCapacityDetail) ...[
                            const Divider(
                                height: 1, color: PopupTheme.borderDark),
                            PopupInfoRow(
                              icon: Icons.storage_rounded,
                              iconColor: PopupTheme.blue,
                              label: l10n.inventoryCapacityLabel,
                              value: displayProduct.capacity ?? '',
                            ),
                          ] else if (_isFashion &&
                              (displayProduct.capacity?.isNotEmpty ?? false)) ...[
                            const Divider(
                                height: 1, color: PopupTheme.borderDark),
                            PopupInfoRow(
                              icon: Icons.straighten,
                              iconColor: PopupTheme.blue,
                              label: l10n.inventorySizeLabel,
                              value: displayProduct.capacity!,
                            ),
                          ],
                          const Divider(height: 1, color: PopupTheme.borderDark),
                          PopupInfoRow(
                            icon: Icons.business_outlined,
                            iconColor: PopupTheme.teal,
                            label: l10n.inventorySupplierLabel,
                            value: displayProduct.isPending
                                ? (displayProduct.pendingSupplier ??
                                    l10n.inventoryPendingConfirm)
                                : (displayProduct.supplier ?? 'N/A'),
                            valueColor: (!displayProduct.isPending &&
                                    (displayProduct.supplier ?? '').isNotEmpty &&
                                    displayProduct.supplier != 'N/A')
                                ? PopupTheme.teal
                                : null,
                            trailingIcon: Icons.chevron_right_rounded,
                            onTap: (!displayProduct.isPending &&
                                    (displayProduct.supplier ?? '').isNotEmpty)
                                ? () => _openSupplierByName(
                                      displayProduct.supplier ?? '',
                                    )
                                : null,
                          ),
                          if (_canViewCostPrice) ...[
                            const Divider(
                                height: 1, color: PopupTheme.borderDark),
                            PopupInfoRow(
                              icon: Icons.arrow_downward_rounded,
                              iconColor: PopupTheme.yellow,
                              label: l10n.inventoryPurchasePrice,
                              value: displayProduct.isPending
                                  ? l10n.inventoryWaitingConfirm
                                  : '${MoneyUtils.formatCurrency(displayProduct.cost)} đ',
                              valueColor: PopupTheme.yellow,
                              bold: true,
                            ),
                          ],
                          const Divider(height: 1, color: PopupTheme.borderDark),
                          PopupInfoRow(
                            icon: Icons.arrow_upward_rounded,
                            iconColor: PopupTheme.green,
                            label: l10n.inventorySalePriceItem,
                            value: displayProduct.isPending
                                ? l10n.inventoryWaitingConfirm
                                : '${MoneyUtils.formatCurrency(displayProduct.price)} đ',
                            valueColor: PopupTheme.green,
                            bold: true,
                          ),
                          const Divider(height: 1, color: PopupTheme.borderDark),
                          PopupInfoRow(
                            icon: Icons.payment_outlined,
                            iconColor: PopupTheme.blue,
                            label: l10n.payment,
                            value: displayProduct.isPending
                                ? l10n.inventoryWaitingConfirm
                                : (displayProduct.paymentMethod ?? 'N/A'),
                          ),
                          if (displayProduct.labelNote != null &&
                              displayProduct.labelNote!.isNotEmpty) ...[
                            const Divider(
                                height: 1, color: PopupTheme.borderDark),
                            PopupInfoRow(
                              icon: Icons.notes_rounded,
                              iconColor: PopupTheme.textSecondary,
                              label: l10n.note,
                              value: displayProduct.labelNote!,
                            ),
                          ],
                          if (hasLocation) ...[
                            const Divider(
                                height: 1, color: PopupTheme.borderDark),
                            PopupInfoRow(
                              icon: Icons.location_on_rounded,
                              iconColor: PopupTheme.teal,
                              label: l10n.inventoryWarehouseLocation,
                              value: [
                                displayProduct.locationCode,
                                displayProduct.locationName,
                              ]
                                  .where(
                                      (v) => v != null && v.isNotEmpty)
                                  .join(' · '),
                              valueColor: PopupTheme.teal,
                            ),
                          ],
                          const Divider(height: 1, color: PopupTheme.borderDark),
                          PopupInfoRow(
                            icon: Icons.update_rounded,
                            iconColor: PopupTheme.textMuted,
                            label: l10n.inventoryLastUpdated,
                            value: displayProduct.updatedAt != null
                                ? DateFormat('dd/MM/yyyy HH:mm').format(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      displayProduct.updatedAt!,
                                    ),
                                  )
                                : 'N/A',
                            valueColor: PopupTheme.textSecondary,
                          ),
                        ],
                      ),
                    ),
                    // ── Repair history ────────────────────────────
                    if (repairs.isNotEmpty && _enableRepair) ...[
                      PopupSectionDivider(title: l10n.inventoryRepairHistorySection),
                      ...repairs.map(
                        (r) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: PopupTheme.surfaceDark,
                            borderRadius:
                                BorderRadius.circular(PopupTheme.radiusCard),
                            border: Border.all(color: PopupTheme.borderDark),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_outline,
                                      size: 14,
                                      color: PopupTheme.textSecondary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      r.customerName,
                                      style: const TextStyle(
                                        color: PopupTheme.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(r.status)
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _getStatusText(ctx, r.status),
                                      style: TextStyle(
                                        color: _getStatusColor(r.status),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                r.issue,
                                style: const TextStyle(
                                  color: PopupTheme.textSecondary,
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                DateFormat('dd/MM/yyyy').format(
                                    DateTime.fromMillisecondsSinceEpoch(
                                        r.createdAt)),
                                style: const TextStyle(
                                  color: PopupTheme.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    // ── Special: Xác nhận giá (kho tạm) ─────────
                    if (p.isPending) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showConfirmCostDialog(p);
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: Text(l10n.inventoryConfirmPriceBtn),
                          style: PopupTheme.primaryButton(color: PopupTheme.yellow),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    // ── Action buttons: one row, Wrap fallback ────
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.start,
                      children: [
                        // IN TEM
                        OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final printerConfig =
                                await showPrinterSelectionDialog(context);
                            if (printerConfig == null) return;
                            final printerType =
                                printerConfig['type'] as PrinterType?;
                            final bluetoothPrinter =
                                printerConfig['bluetoothPrinter'];
                            final wifiIp =
                                printerConfig['wifiIp'] as String?;
                            if (!mounted) return;
                            NotificationService.showSnackBar(
                                l10n.inventoryPrintingLabelMsg, color: Colors.teal);
                            final ok = await UnifiedPrinterService
                                .printProductQRLabel(
                              p.toMap(),
                              printerType: printerType,
                              bluetoothPrinter: bluetoothPrinter,
                              customMac: bluetoothPrinter is Map
                                  ? bluetoothPrinter['macAddress']
                                  : null,
                              wifiIp: wifiIp,
                            );
                            if (mounted) {
                              NotificationService.showSnackBar(
                                ok ? l10n.inventoryPrintLabelSuccess : l10n.inventoryPrintLabelError,
                                color: ok ? Colors.green : Colors.red,
                              );
                            }
                          },
                          icon: const Icon(Icons.qr_code_2, size: 15),
                          label: Text(l10n.inventoryPrintLabelAction),
                          style: _compactOutlineBtn(PopupTheme.blue),
                        ),
                        // SỬA
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _editProduct(p);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: Text(l10n.inventoryEditAction),
                          style: _compactFilledBtn(PopupTheme.orange),
                        ),
                        // BÁN
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _createSaleOrder(p);
                          },
                          icon: const Icon(Icons.shopping_cart_outlined,
                              size: 15),
                          label: Text(l10n.inventorySellAction),
                          style: _compactFilledBtn(PopupTheme.blue),
                        ),
                        // NHẬP THÊM (PHU_KIEN / LINH_KIEN)
                        if (p.type == 'PHU_KIEN' || p.type == 'LINH_KIEN')
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showQuickStockInDialog(p);
                            },
                            icon: const Icon(Icons.add_shopping_cart, size: 15),
                            label: Text(l10n.inventoryStockMoreAction(p.quantity)),
                            style: _compactOutlineBtn(PopupTheme.teal),
                          ),
                        // XÓA
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showDeleteConfirmation(p);
                          },
                          icon: const Icon(Icons.delete_outline, size: 15),
                          label: Text(l10n.delete),
                          style: _compactFilledBtn(PopupTheme.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Quick stock-in dialog for PHU_KIEN / LINH_KIEN
  void _showQuickStockInDialog(Product p) {
    final l10n = AppLocalizations.of(context)!;
    int calcWeightedCost({
      required int currentQty,
      required int currentCost,
      required int importQty,
      required int importCost,
    }) {
      final totalQty = currentQty + importQty;
      if (totalQty <= 0) return importCost;
      return ((currentQty * currentCost) + (importQty * importCost)) ~/
          totalQty;
    }

    final qtyCtrl = TextEditingController(text: '1');
    final costCtrl = TextEditingController(
      text: p.cost > 0 ? p.cost.toString() : '',
    );
    String paymentMethod = 'TIỀN MẶT';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: PopupTheme.bgDark,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(PopupTheme.radiusSheet),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PopupDragHandle(),
                  Row(
                    children: [
                      Icon(
                        Icons.add_shopping_cart,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.inventoryRestockTitle,
                        style: AppTextStyles.headline3.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Product info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          p.type == 'LINH_KIEN' ? '🔧' : '🎧',
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: AppTextStyles.headline4.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                l10n.inventoryCurrentStockNote(p.quantity),
                                style: AppTextStyles.subtitle1.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                l10n.inventoryCurrentCostNote(MoneyUtils.formatCurrency(p.cost)),
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Quantity
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setSheetState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.inventoryRestockQtyLabel,
                      prefixIcon: const Icon(Icons.add_circle_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          PopupTheme.radiusField,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Cost price
                  CurrencyTextField(
                    controller: costCtrl,
                    label: l10n.inventoryRestockPriceLabel,
                    icon: Icons.attach_money,
                    onValueChanged: (_) => setSheetState(() {}),
                  ),
                  Builder(
                    builder: (_) {
                      final importQty =
                          int.tryParse(qtyCtrl.text.trim()) ?? 0;
                      final importCost = CurrencyTextField.parseValue(
                        costCtrl.text,
                      );
                      if (importQty <= 0 || importCost <= 0) {
                        return const SizedBox.shrink();
                      }
                      final weightedCost = calcWeightedCost(
                        currentQty: p.quantity,
                        currentCost: p.cost,
                        importQty: importQty,
                        importCost: importCost,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          l10n.inventoryWeightedCostNote(MoneyUtils.formatCurrency(weightedCost)),
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Payment method
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: InputDecoration(
                      labelText: l10n.inventoryPaymentMethodLabel,
                      prefixIcon: const Icon(Icons.payment),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          PopupTheme.radiusField,
                        ),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'TIỀN MẶT',
                        child: Text(l10n.inventoryCashOption),
                      ),
                      DropdownMenuItem(
                        value: 'CHUYỂN KHOẢN',
                        child: Text(l10n.inventoryBankTransferOption),
                      ),
                      DropdownMenuItem(
                        value: 'CÔNG NỢ',
                        child: Text(l10n.inventoryDebtOption),
                      ),
                    ],
                    onChanged: (v) => setSheetState(() => paymentMethod = v!),
                  ),
                  const SizedBox(height: 20),
                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(l10n.cancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: Text(
                            l10n.inventoryStockInAction,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: () async {
                            final qty = int.tryParse(qtyCtrl.text) ?? 0;
                            if (qty <= 0) {
                              NotificationService.showSnackBar(
                                l10n.inventoryValidQtyError,
                                color: Colors.red,
                              );
                              return;
                            }
                            final cost = CurrencyTextField.parseValue(
                              costCtrl.text,
                            );
                            if (cost <= 0 && !_allowPendingCost) {
                              NotificationService.showSnackBar(
                                l10n.inventoryValidPriceError,
                                color: Colors.red,
                              );
                              return;
                            }
                            Navigator.pop(ctx);
                            await _processQuickStockIn(
                              p,
                              qty,
                              cost,
                              paymentMethod,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _processQuickStockIn(
    Product p,
    int qty,
    int cost,
    String paymentMethod,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      NotificationService.showSnackBar(l10n.inventoryStockingIn, color: Colors.blue);
      final shopId = await UserService.getCurrentShopId() ?? '';
      final service = StockEntryService();

      // Resolve supplierId trước khi tạo stock entry để không bị fail validate canConfirm.
      String? supplierId;
      final supplierName = (p.supplier ?? '').trim();
      if (supplierName.isNotEmpty) {
        final suppliers = await DBHelper().getSuppliers();
        final supplier = suppliers.firstWhere(
          (s) {
            final name = (s['name'] ?? '').toString().trim();
            return name.toUpperCase() == supplierName.toUpperCase();
          },
          orElse: () {
            return suppliers.firstWhere((s) {
              final name = (s['name'] ?? '').toString().trim();
              return name.toUpperCase().contains(supplierName.toUpperCase());
            }, orElse: () => <String, dynamic>{});
          },
        );

        final supplierFirestoreId = (supplier['firestoreId'] ?? '')
            .toString()
            .trim();
        if (supplierFirestoreId.isNotEmpty) {
          supplierId = supplierFirestoreId;
        } else {
          final localId = supplier['id'];
          if (localId != null) supplierId = localId.toString();
        }
      }

      if (supplierId == null || supplierId.trim().isEmpty) {
        NotificationService.showSnackBar(
          l10n.inventoryNoSupplierFoundError,
          color: Colors.red,
        );
        return;
      }

      // Create a stock entry for audit trail and financial tracking
      final entry = StockEntry(
        shopId: shopId,
        status: StockEntryStatus.draft,
        entryType: StockEntryType.quick,
        paymentMethod: paymentMethod,
        supplierId: supplierId,
        supplierName: p.supplier,
        items: [
          StockEntryItem(
            name: p.name,
            quantity: qty,
            cost: cost.toDouble(),
            price: p.price.toDouble(),
            productType: p.type,
            brand: p.brand,
            model: p.model,
            capacity: p.capacity,
            color: p.color,
            sku: p.sku,
            unit: p.unit,
            size: p.size,
          ),
        ],
      );

      final created = await service.createEntry(entry);
      if (created == null || created.firestoreId == null) {
        NotificationService.showSnackBar(
          l10n.inventoryCreateEntryError,
          color: Colors.red,
        );
        return;
      }

      // Auto-confirm entry to update stock + financial records
      final confirmed = await service.confirmEntry(created.firestoreId!);
      if (confirmed) {
        NotificationService.showSnackBar(
          l10n.inventoryStockInSuccess(qty, p.name),
          color: Colors.green,
        );
        // Force sync to reflect new quantities
        await SyncOrchestrator().syncAll();
        _refresh();
      } else {
        NotificationService.showSnackBar(
          l10n.inventoryConfirmEntryError,
          color: Colors.red,
        );
      }
    } catch (e) {
      debugPrint('Quick stock-in error: $e');
      NotificationService.showSnackBar('Lỗi: $e', color: Colors.red);
    }
  }

  Future<void> _showAiStockQuickEntry() async {
    final result = await AiOrderInputSheet.show(context, mode: AiSheetMode.stock);
    if (!mounted || result == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SmartStockInView(
          prefilledName: result.stockProductName.isNotEmpty
              ? result.stockProductName
              : null,
          prefilledQuantity: result.quantity > 1 ? result.quantity : null,
          prefilledCostPrice: result.unitPrice > 0 ? result.unitPrice : null,
        ),
      ),
    ).then((_) => _refresh());
  }

  /// Quick inline dialog để nhập giá vốn cho sản phẩm cost = 0
  Future<void> _showInlineCostEdit(Product p) async {
    final costCtrl = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: PopupTheme.bgDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(PopupTheme.radiusSheet)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PopupDragHandle(),
              Row(
                children: [
                  const Icon(Icons.attach_money_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nhập giá vốn: ${p.name}',
                      style: const TextStyle(
                        color: PopupTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CurrencyTextField(
                controller: costCtrl,
                label: 'Giá vốn (đ)',
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Bỏ qua'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, color: Colors.white, size: 16),
                      label: const Text('Lưu giá vốn', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final newCost = CurrencyTextField.parseValue(costCtrl.text);
    if (newCost <= 0) {
      NotificationService.showSnackBar('Giá vốn phải lớn hơn 0', color: Colors.red);
      return;
    }
    try {
      final updated = p.copyWith(cost: newCost, updatedAt: DateTime.now().millisecondsSinceEpoch);
      await db.upsertProduct(updated);
      await SyncOrchestrator().enqueue(
        entityType: SyncEntityType.product,
        entityId: updated.id!,
        firestoreId: updated.firestoreId,
        operation: SyncOperation.update,
      );
      NotificationService.showSnackBar('Đã lưu giá vốn ${MoneyUtils.formatCurrency(newCost)} đ', color: Colors.green);
      _refresh();
    } catch (e) {
      NotificationService.showSnackBar('Lỗi lưu giá vốn: $e', color: Colors.red);
    }
  }

  void _createSaleOrder(Product p) {
    HapticFeedback.mediumImpact();
    // Cảnh báo mềm: sản phẩm chưa có giá vốn (không block)
    if (_allowPendingCost && _canViewCostPrice && p.cost == 0 && !p.isPending) {
      NotificationService.showSnackBar(
        '⚠ Sản phẩm chưa có giá vốn — lợi nhuận chưa chính xác',
        color: Colors.orange.shade700,
      );
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateSaleView(preSelectedProduct: p)),
    ).then((_) => _refresh());
  }
  void _showProductActionDialog(Product p) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Product name header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                p.name,
                style: AppTextStyles.headline3.copyWith(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
              title: Text(l10n.inventoryEditOption),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              onTap: () {
                Navigator.pop(ctx);
                _editProduct(p);
              },
            ),
            ListTile(
              leading: Icon(Icons.visibility_off_rounded, color: Colors.red.shade700),
              title: Text(l10n.inventoryHideOption),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirmation(p);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Product p) {
    final l10n = AppLocalizations.of(context)!;
    final passwordCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.inventoryHideProductTitle(_terms.productLabel.toUpperCase()),
                  style: AppTextStyles.headline3,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thông tin sản phẩm
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_enableSerial && p.imei != null && p.imei!.isNotEmpty)
                        Text(
                          '${_terms.specialField1Label}: ${p.imei}',
                          style: AppTextStyles.subtitle1.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      if (_canViewCostPrice)
                        Text(
                          l10n.inventoryCostPriceNote(MoneyUtils.formatCurrency(p.cost)),
                          style: AppTextStyles.subtitle1,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Cảnh báo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.inventorySoftDeleteWarning,
                        style: AppTextStyles.subtitle1.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.inventorySoftDeleteDesc,
                        style: AppTextStyles.body1,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Lý do xóa
                TextField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.inventoryDeleteReasonLabel,
                    hintText: l10n.inventoryDeleteReasonHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Mật khẩu xác nhận
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.inventoryAccountPassword,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                    prefixIcon: const Icon(Icons.lock, size: 20),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (passwordCtrl.text.isEmpty) {
                  NotificationService.showSnackBar(
                    l10n.inventoryEnterPasswordError,
                    color: AppColors.error,
                  );
                  return;
                }

                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user?.email != null) {
                    // Re-authenticate với mật khẩu tài khoản
                    AuthCredential credential = EmailAuthProvider.credential(
                      email: user!.email!,
                      password: passwordCtrl.text,
                    );
                    await user.reauthenticateWithCredential(credential);

                    Navigator.pop(ctx);
                    await _deleteProductWithOptions(
                      p,
                      reason: reasonCtrl.text.trim(),
                    );
                  }
                } catch (e) {
                  NotificationService.showSnackBar(
                    l10n.inventoryWrongPasswordError,
                    color: AppColors.error,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.inventoryHideFromWarehouse),
            ),
          ],
        ),
      ),
    );
  }

  /// Xóa sản phẩm với các options liên quan
  Future<void> _deleteProductWithOptions(Product p, {String? reason}) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userName = user?.email?.split('@').first.toUpperCase() ?? 'NV';
      final productId = p.firestoreId ?? '';
      final imei = p.imei ?? '';

      // 1. GHI AUDIT LOG trước khi xóa
      await db.logAction(
        userId: user?.uid ?? '0',
        userName: userName,
        action: 'ẨN ${_terms.productLabel.toUpperCase()} (KHO)',
        type: 'PRODUCT',
        targetId: productId,
        desc:
            'Ẩn SP khỏi kho: ${p.name} | ${_terms.specialField1Label}: $imei | Giá vốn: ${p.cost} | Lý do: ${reason ?? "Không ghi"}',
      );

      // 2. XÓA MỀM sản phẩm (chỉ ẩn khỏi danh sách kho)
      if (p.id != null) {
        await db.softDeleteProduct(p.id!);

        // Sync update (soft delete) lên cloud
        await SyncOrchestrator().enqueue(
          entityType: SyncEntityType.product,
          entityId: p.id!,
          firestoreId: p.firestoreId,
          operation: SyncOperation.update,
        );
      }

      await _refresh();
      NotificationService.showSnackBar(
        l10n.inventoryHideSuccess(_terms.productLabel.toLowerCase(), p.name),
        color: Colors.green,
      );
    } catch (e) {
      NotificationService.showSnackBar(
        l10n.inventoryHideError(_terms.productLabel.toLowerCase(), e.toString()),
        color: Colors.red,
      );
    }
  }
  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    final isFiltered = _searchQuery.isNotEmpty ||
        _filterType != 'TẤT CẢ' ||
        _filterLocationCode != null;
    return EmptyStateWidget(
      icon: isFiltered
          ? Icons.search_off_rounded
          : Icons.inventory_2_outlined,
      title: isFiltered ? l10n.inventoryEmptyFiltered : l10n.inventoryEmptyAll,
      subtitle: isFiltered
          ? l10n.inventoryEmptyFilteredSub
          : _showOutOfStock
              ? null
              : l10n.inventoryEmptyOutOfStockSub,
    );
  }

  Future<void> _init() async {
    final perms = await UserService.getCurrentUserPermissions();
    // Load shop settings for multi-industry features
    final settings = await CategoryService().getShopSettings();
    if (!mounted) return;
    setState(() {
      _hasInventoryAccess = perms['allowViewInventory'] ?? false;
      _canViewCostPrice = perms['allowViewCostPrice'] ?? false;
      _shopSettings = settings;
      // Set default type based on business type
      _selectedType = _getDefaultInventoryType();
    });
    // CRITICAL: Init check data AFTER shop settings are loaded so _selectedType is correct
    _initCheckData();
    _refresh();
  }

  /// Get default inventory type based on business type
  String _getDefaultInventoryType() {
    switch (_businessType) {
      case 'food':
        return 'THUC_PHAM';
      case 'fashion':
        return 'THOI_TRANG';
      case 'general':
        return 'SAN_PHAM';
      case 'electronics':
      default:
        return 'DIEN_THOAI';
    }
  }

  Future<void> _initCheckData() async {
    await _loadOrCreateCurrentCheck();
  }

  /// Sync tất cả products từ Firestore vào local DB để đảm bảo dữ liệu mới nhất
  Future<void> _forceSyncProductsFromFirestore() async {
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null) return;

      debugPrint('🔄 Force syncing products from Firestore...');

      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('shopId', isEqualTo: shopId)
          .where('deleted', isEqualTo: false)
          .get();

      int updated = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['firestoreId'] = doc.id;
        data['isSynced'] = 1;

        final product = Product.fromMap(data);
        await db.upsertProduct(product);
        updated++;
      }

      debugPrint('✅ Force synced $updated products from Firestore');
    } catch (e) {
      debugPrint('⚠️ Error force syncing products: $e');
    }
  }

  Future<void> _refresh({bool forceSync = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _selectedIds.clear();
      _isSelectionMode = false;
      _currentOffset = 0;
      _allLoadedProducts = [];
      _hasMore = true;
    });

    // Load từ local DB trước để UI hiển thị nhanh
    // Chỉ force sync khi user kéo refresh hoặc yêu cầu cụ thể
    if (forceSync) {
      // Sync Firestore ở background, không block UI
      _forceSyncProductsFromFirestore().then((_) {
        if (mounted) _refreshLocalData();
      });
    }

    await _refreshLocalData();
  }

  /// Load dữ liệu từ local DB (nhanh)
  Future<void> _refreshLocalData() async {
    final suppliers = await supplierService.getSuppliers();
    final unsyncedCount = await db.getUnsyncedQuickInputCodesCount();

    // Load repair parts count for category chip
    final parts = await db.getAllParts();
    final partsCount = parts
        .where((p) => _safeToInt(p['quantity']) > 0 || _showOutOfStock)
        .length;

    // ALWAYS load total summary from DB first (for correct totals)
    final summary = await db.getInventorySummary(
      type: _filterType == 'TẤT CẢ' ? null : _filterType,
    );

    if (_needsFullData) {
      // Load all data for filtering
      final data = await db.getAllProducts();
      data.sort((a, b) => (b.updatedAt ?? 0).compareTo(a.updatedAt ?? 0));
      if (!mounted) return;
      setState(() {
        _allLoadedProducts = data;
        _products = data;
        _suppliers = suppliers.map((s) => s.toMap()).toList();
        _unsyncedCount = unsyncedCount;
        _totalQtyFromDB = summary['totalQty'] ?? 0;
        _totalCapitalFromDB = summary['totalCapital'] ?? 0;
        _repairPartsCount = partsCount;
        _isLoading = false;
        _hasMore = false;
      });
    } else {
      // Lazy load first page for better performance
      final firstPage = await db.getProductsPaged(_pageSize, 0);
      if (!mounted) return;
      setState(() {
        _allLoadedProducts = firstPage;
        _products = firstPage;
        _suppliers = suppliers.map((s) => s.toMap()).toList();
        _unsyncedCount = unsyncedCount;
        _totalQtyFromDB = summary['totalQty'] ?? 0;
        _totalCapitalFromDB = summary['totalCapital'] ?? 0;
        _repairPartsCount = partsCount;
        _currentOffset = _pageSize;
        _isLoading = false;
        _hasMore = firstPage.length >= _pageSize;
      });
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;

    final passwordCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.inventoryConfirmDeleteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.inventoryConfirmDeleteContent(_selectedIds.length),
            ),
            const SizedBox(height: 15),
            Text(l10n.inventoryEnterPasswordToDelete),
            const SizedBox(height: 10),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.inventoryAccountPassword,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordCtrl.text.isEmpty) {
                NotificationService.showSnackBar(
                  l10n.inventoryEnterPasswordError,
                  color: Colors.red,
                );
                return;
              }

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user?.email != null) {
                  AuthCredential credential = EmailAuthProvider.credential(
                    email: user!.email!,
                    password: passwordCtrl.text,
                  );
                  await user.reauthenticateWithCredential(credential);

                  Navigator.pop(ctx, true);
                }
              } catch (e) {
                NotificationService.showSnackBar(
                  l10n.inventoryWrongPasswordError,
                  color: Colors.red,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              l10n.inventoryDeleteNow,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        final userName = user?.email?.split('@').first.toUpperCase() ?? "ADMIN";
        for (int id in _selectedIds) {
          final p = _products.firstWhere((element) => element.id == id);
          await db.logAction(
            userId: user?.uid ?? "0",
            userName: userName,
            action: "XÓA KHO",
            type: "PRODUCT",
            targetId: p.imei,
            desc: "Đã xóa ${p.name} (${_terms.specialField1Label}: ${p.imei})",
          );
          await db.deleteProduct(id);

          // Queue delete sync via SyncOrchestrator
          await SyncOrchestrator().enqueue(
            entityType: SyncEntityType.product,
            entityId: id,
            firestoreId: p.firestoreId,
            operation: SyncOperation.delete,
            data: null,
          );
        }
        HapticFeedback.mediumImpact();
        _refresh();
      } catch (e) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleSelection(int id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  // ===== INVENTORY CHECK METHODS =====
  Future<void> _loadOrCreateCurrentCheck() async {
    try {
      // Lọc theo checkType để tránh lấy nhầm check của loại khác
      final checks = await db.getInventoryChecks(checkType: _selectedType);
      final today = DateTime.now();
      final todayKey = DateFormat('yyyy-MM-dd').format(today);

      // Find today's check for this type or create new one
      _currentCheck = checks.cast<InventoryCheck?>().firstWhere(
        (check) =>
            check != null &&
            DateFormat('yyyy-MM-dd').format(
                  DateTime.fromMillisecondsSinceEpoch(check.createdAt),
                ) ==
                todayKey,
        orElse: () => null,
      );

      if (_currentCheck == null) {
        _currentCheck = InventoryCheck(
          checkType: _selectedType,
          checkDate: today.millisecondsSinceEpoch,
          checkedBy: FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
          items: [],
          createdAt: today.millisecondsSinceEpoch,
        );
        await db.insertInventoryCheck(_currentCheck!.toMap());
      }
    } catch (e) {
      debugPrint('Error loading current check: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Kiểm tra quyền truy cập
    if (!_hasInventoryAccess) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: CustomAppBar.build(
          title: l10n.inventoryManageTotalTitle,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory_2, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                l10n.inventoryNoAccessMsg,
                textAlign: TextAlign.center,
                style: AppTextStyles.headline3.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar.build(
        title: l10n.inventoryManageTitle,
        subtitle:
            '${_products.length} ${_terms.productLabel.toLowerCase()}${_unsyncedCount > 0 ? ' • ${l10n.inventoryUnsyncedNote(_unsyncedCount)}' : ''}',
        accentColor: AppBarAccents.inventory,
        centerTitle: false,
        actions: [
          if (_filterType == 'LINH_KIEN')
            IconButton(
              onPressed: () => _partsAddTrigger.value++,
              icon: const Icon(
                Icons.add_rounded,
                color: AppBarAccents.inventory,
                size: 22,
              ),
              tooltip: l10n.inventoryAddPartTooltip,
              splashRadius: 20,
            )
          else ...[
            IconButton(
              onPressed: _showAiStockQuickEntry,
              icon: const Icon(
                Icons.auto_awesome_rounded,
                color: AppBarAccents.inventory,
                size: 22,
              ),
              tooltip: l10n.inventoryStockInAITooltip,
              splashRadius: 20,
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SmartStockInView()),
                ).then((_) => _refresh());
              },
              icon: const Icon(
                Icons.add_box_rounded,
                color: AppBarAccents.inventory,
                size: 22,
              ),
              tooltip: l10n.inventoryStockInTooltip,
              splashRadius: 20,
            ),
          ],
          IconButton(
            onPressed: _openSearchDialog,
            icon: const Icon(
              Icons.search,
              color: AppBarAccents.inventory,
              size: 22,
            ),
            tooltip: _searchQuery.trim().isEmpty
                ? l10n.inventorySearchTooltip
                : l10n.inventorySearchProduct(_searchQuery),
            splashRadius: 20,
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: AppBarAccents.inventory,
              size: 22,
            ),
            tooltip: l10n.more,
            onSelected: (value) async {
              if (value == 'location') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StorageLocationView()),
                ).then((_) => _refresh());
              } else if (value == 'print') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PtyPrintDesignerView()),
                );
              } else if (value == 'excel') {
                if (_filterType == 'LINH_KIEN') {
                  final result = await ExportDateFilterDialog.show(
                    context,
                    title: l10n.inventoryExportParts,
                  );
                  if (result == null || !mounted) return;
                  await ExcelExportHelper.exportRepairParts(
                    context,
                    startMs: result['startMs'],
                    endMs: result['endMs'],
                  );
                } else {
                  final result = await ExportDateFilterDialog.show(
                    context,
                    title: l10n.inventoryExportProducts,
                  );
                  if (result == null || !mounted) return;
                  await ExcelExportHelper.exportProducts(
                    context,
                    startMs: result['startMs'],
                    endMs: result['endMs'],
                  );
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'location',
                child: Row(children: [
                  const Icon(Icons.location_on_rounded, size: 18),
                  const SizedBox(width: 10),
                  Text(l10n.inventoryStorageLocationMenu),
                ]),
              ),
              PopupMenuItem(
                value: 'print',
                child: Row(children: [
                  const Icon(Icons.qr_code_2_rounded, size: 18),
                  const SizedBox(width: 10),
                  Text(l10n.inventoryPrintLabelsMenu),
                ]),
              ),
              PopupMenuItem(
                value: 'excel',
                child: Row(children: [
                  const Icon(Icons.file_download_outlined, size: 18),
                  const SizedBox(width: 10),
                  Text(l10n.inventoryExportExcelMenu),
                ]),
              ),
            ],
          ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppBarAccents.inventory,
              size: 22,
            ),
            tooltip: l10n.refresh,
            splashRadius: 20,
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            // Category filter chips - always visible
            _buildCategoryChips(),
            Expanded(
              child: _filterType == 'LINH_KIEN'
                  ? PartsInventoryViewContent(addTrigger: _partsAddTrigger)
                  : _buildInventoryTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryTab() {
    final l10n = AppLocalizations.of(context)!;
    // Lọc theo search query
    var filteredList = _products
        .where(
          (p) =>
              VietnameseUtils.containsVietnamese(p.name, _searchQuery) ||
              (p.imei ?? "").contains(_searchQuery),
        )
        .toList();

    // Lọc theo loại hàng
    if (_filterType != 'TẤT CẢ') {
      filteredList = filteredList.where((p) => p.type == _filterType).toList();
    }

    // Lọc theo vị trí lưu kho
    if (_filterLocationCode != null) {
      filteredList = filteredList
          .where((p) => p.locationCode == _filterLocationCode)
          .toList();
    }

    // Lọc sản phẩm chưa có giá vốn
    if (_showNoCostOnly) {
      filteredList = filteredList.where((p) => !p.isPending && p.cost == 0).toList();
    }

    // Nếu không bật showOutOfStock, chỉ hiện còn hàng (quantity > 0)
    if (!_showOutOfStock) {
      filteredList = filteredList.where((p) => p.quantity > 0).toList();
    }

    // Sử dụng tổng từ DB (đã tính từ TẤT CẢ sản phẩm, không phụ thuộc pagination)
    final int totalQty = _totalQtyFromDB;
    final int totalCapital = _totalCapitalFromDB;

    return Stack(
      children: [
        Column(
          children: [
            // Selection mode action bar
            if (_isSelectionMode)
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.error),
                      onPressed: () => setState(() {
                        _isSelectionMode = false;
                        _selectedIds.clear();
                      }),
                    ),
                    Text(
                      "ĐÃ CHỌN ${_selectedIds.length}",
                      style: AppTextStyles.headline3.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _deleteSelected,
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.red,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),

            // Summary Section
            if (!_isSelectionMode)
              _buildInventorySummary(
                totalQty,
                totalCapital,
                filteredList.length,
              ),

            // Product List
            Expanded(
              child: _isLoading
                  ? const SkeletonListView(
                      variant: SkeletonVariant.inventoryRow,
                      padding: EdgeInsets.fromLTRB(12, 0, 12, 76),
                    )
                  : filteredList.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () => _refresh(
                        forceSync: true,
                      ), // Kéo refresh = force sync Firestore
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 76),
                        itemCount:
                            filteredList.length +
                            (_isLoadingMore ? 1 : 0) +
                            (!_hasMore && filteredList.isNotEmpty ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i >= filteredList.length) {
                            if (_isLoadingMore) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  l10n.inventoryShownCount(filteredList.length, _terms.productLabel.toLowerCase()),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          }
                          final product = filteredList[i];
                          final itemKey = ValueKey(
                            product.id ??
                                product.firestoreId ??
                                '${product.name}_${product.createdAt}',
                          );
                          return KeyedSubtree(
                            key: itemKey,
                            child: _buildProfessionalCard(product, i + 1),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }
  Widget _buildInventorySummary(int qty, int capital, int shownCount) {
    final l10n = AppLocalizations.of(context)!;
    final isFiltered =
        _searchQuery.isNotEmpty || _filterType != 'TẤT CẢ' || _showOutOfStock;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF2962FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withAlpha(46),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _summaryItemCompact(
            isFiltered ? l10n.inventoryDisplayOrTotal : l10n.inventoryTotalLabel,
            isFiltered ? '$shownCount / $qty' : '$qty',
            Icons.inventory,
          ),
          Container(width: 1, height: 36, color: Colors.white24),
          _summaryItemCompact(
            l10n.inventoryCapitalLabel,
            _canViewCostPrice
                ? "${MoneyUtils.formatCompactCurrency(capital)} đ"
                : l10n.noPermission,
            Icons.account_balance_wallet,
          ),
        ],
      ),
    );
  }

  // Compact summary used in the smaller header
  Widget _summaryItemCompact(String label, String val, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 12),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.overline.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: AppTextStyles.headline4.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  /// Category filter chips - always visible at top
  Widget _buildCategoryChips() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTypeFilterChip('TẤT CẢ', Icons.apps, Colors.blue),
            const SizedBox(width: 8),
            _buildTypeFilterChip('DIEN_THOAI', Icons.smartphone, Colors.indigo),
            const SizedBox(width: 8),
            _buildTypeFilterChip('PHU_KIEN', Icons.headset_mic, Colors.green),
            if (_businessType == 'electronics') ...[
              const SizedBox(width: 8),
              _buildTypeFilterChip(
                'LINH_KIEN',
                Icons.build_circle,
                const Color(0xFF0068FF),
              ),
            ],
            const SizedBox(width: 8),
            _buildLocationFilterChip(),
            const SizedBox(width: 8),
            _buildOutOfStockChip(),
            if (_allowPendingCost && _canViewCostPrice) ...[
              const SizedBox(width: 8),
              _buildNoCostFilterChip(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationFilterChip() {
    final l10n = AppLocalizations.of(context)!;
    final isActive = _filterLocationCode != null;
    return InkWell(
      onTap: isActive
          ? () async {
              setState(() => _filterLocationCode = null);
              await _refreshLocalData();
            }
          : _showLocationFilterSheet,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.indigo.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Colors.indigo : Colors.grey.shade300,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 16,
              color: isActive ? Colors.indigo : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              isActive ? _filterLocationCode! : l10n.inventoryLocationFilter,
              style: AppTextStyles.subtitle1.copyWith(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.indigo : Colors.grey.shade700,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(Icons.close, size: 13, color: Colors.indigo.shade700),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOutOfStockChip() {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: () {
        final wasFullData = _needsFullData;
        setState(() => _showOutOfStock = !_showOutOfStock);
        if (wasFullData != _needsFullData) _refreshLocalData();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _showOutOfStock ? Colors.amber.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _showOutOfStock ? Colors.amber.shade700 : Colors.grey.shade300,
            width: _showOutOfStock ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showOutOfStock ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              size: 16,
              color: _showOutOfStock ? Colors.amber.shade800 : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              l10n.outOfStock,
              style: AppTextStyles.subtitle1.copyWith(
                fontWeight: _showOutOfStock ? FontWeight.bold : FontWeight.normal,
                color: _showOutOfStock ? Colors.amber.shade800 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCostFilterChip() {
    return InkWell(
      onTap: () {
        setState(() => _showNoCostOnly = !_showNoCostOnly);
        _refreshLocalData();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _showNoCostOnly ? Colors.orange.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _showNoCostOnly ? Colors.orange.shade700 : Colors.grey.shade300,
            width: _showNoCostOnly ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: _showNoCostOnly ? Colors.orange.shade800 : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              'Chưa nhập vốn',
              style: AppTextStyles.subtitle1.copyWith(
                fontWeight: _showNoCostOnly ? FontWeight.bold : FontWeight.normal,
                color: _showNoCostOnly ? Colors.orange.shade800 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLocationFilterSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final shopId = await UserService.getCurrentShopId() ?? '';
    final locations = await db.getStorageLocations(shopId, activeOnly: true);
    if (!mounted) return;
    if (locations.isEmpty) {
      NotificationService.showSnackBar(l10n.inventoryNoLocationMsg);
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.inventoryFilterByLocation,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: locations
                  .map(
                    (loc) => ListTile(
                      leading: const Icon(
                        Icons.location_on,
                        color: Colors.indigo,
                      ),
                      title: Text(
                        loc.code,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(loc.name),
                      onTap: () => Navigator.pop(ctx, loc.code),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
    if (selected != null && mounted) {
      setState(() => _filterLocationCode = selected);
      await _refreshLocalData();
    }
  }

  Widget _buildTypeFilterChip(String type, IconData icon, Color color) {
    final l10n = AppLocalizations.of(context)!;
    final isSelected = _filterType == type;
    final label = type == 'DIEN_THOAI'
        ? _terms.category1
        : type == 'PHU_KIEN'
        ? _terms.category2
        : type == 'LINH_KIEN'
        ? _terms.category3
        : l10n.inventoryAllFilter;

    // Đếm số lượng theo type
    int count = type == 'LINH_KIEN'
        ? _repairPartsCount
        : type == 'TẤT CẢ'
        ? _products.where((p) => p.quantity > 0 || _showOutOfStock).length
        : _products
              .where(
                (p) => p.type == type && (p.quantity > 0 || _showOutOfStock),
              )
              .length;

    return InkWell(
      onTap: () async {
        setState(() => _filterType = type);
        // CRITICAL: Phải reload data khi thay đổi filter
        // Vì khi filter != TẤT CẢ, cần load TẤT CẢ products (không paginated)
        // Khi filter = TẤT CẢ, chuyển lại chế độ paginated
        await _refreshLocalData();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.subtitle1.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade700,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalCard(Product p, [int? index]) {
    final l10n = AppLocalizations.of(context)!;
    final bool isSelected = _selectedIds.contains(p.id);
    final bool isPending = p.isPending;
    final bool isOutOfStock = p.quantity <= 0;
    final bool isLowStock = p.quantity > 0 && p.quantity <= 3;
    final canManageProduct =
        widget.role == 'owner' ||
        widget.role == 'admin' ||
        UserService.isCurrentUserSuperAdmin();

    // Màu sắc theo trạng thái
    final Color accentColor;
    final String statusLabel;
    final IconData statusIcon;
    if (isPending) {
      accentColor = Colors.orange.shade700;
      statusLabel = l10n.inventoryStatusPending;
      statusIcon = Icons.hourglass_top_rounded;
    } else if (isOutOfStock) {
      accentColor = Colors.red.shade600;
      statusLabel = l10n.outOfStock;
      statusIcon = Icons.remove_circle_outline;
    } else if (isLowStock) {
      accentColor = Colors.orange.shade500;
      statusLabel = l10n.inventoryStatusLowStock;
      statusIcon = Icons.warning_amber_rounded;
    } else {
      accentColor = const Color(0xFF1565C0);
      statusLabel = '';
      statusIcon = Icons.inventory_2_outlined;
    }

    final Color cardBg = isSelected
        ? accentColor.withValues(alpha: 0.06)
        : Colors.white;
    final Color borderSideColor = isSelected
        ? accentColor
        : accentColor.withValues(
            alpha: isPending || isOutOfStock || isLowStock ? 0.35 : 0.15,
          );

    // Biểu tượng loại
    final String typeIcon = p.type == 'DIEN_THOAI'
        ? '📱'
        : p.type == 'LINH_KIEN'
        ? '🔧'
        : '🎧';

    // Giá bán
    final String priceStr = isPending
        ? l10n.inventoryWaitingPrice
        : '${MoneyUtils.formatCompactCurrency(p.price)}đ';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 2 : 1,
      shadowColor: accentColor.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderSideColor, width: isSelected ? 1.5 : 1),
      ),
      color: cardBg,
      child: InkWell(
        onLongPress: () {
          HapticFeedback.heavyImpact();
          if (canManageProduct) {
            _showProductActionDialog(p);
          } else if (p.id != null) {
            _toggleSelection(p.id!);
          }
        },
        onTap: () => _isSelectionMode && p.id != null
            ? _toggleSelection(p.id!)
            : _showProductDetail(p),
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thanh accent trái
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              // Ảnh sản phẩm (thumbnail nhỏ)
              if ((p.images != null && p.images!.isNotEmpty) ||
                  (p.localImagePath != null && p.localImagePath!.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 6,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child:
                        (p.localImagePath != null &&
                            p.localImagePath!.isNotEmpty)
                        ? Image.file(
                            File(p.localImagePath!),
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          )
                        : AppCachedImage(
                            imageUrl: p.images!,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(8),
                            memCacheWidth: 120,
                            memCacheHeight: 120,
                          ),
                  ),
                ),
              // Nội dung chính
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hàng 1: STT + emoji + tên sản phẩm + giá bán
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (index != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$index',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(typeIcon, style: const TextStyle(fontSize: 15)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              ProductConstants.cleanProductName(p.name),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0D1B2A),
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Badge giá bán
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isPending
                                  ? Colors.grey.shade100
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isPending
                                    ? Colors.grey.shade300
                                    : Colors.green.shade300,
                              ),
                            ),
                            child: Text(
                              priceStr,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isPending
                                    ? Colors.grey.shade600
                                    : Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Hàng 2: meta chips + số lượng
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 5,
                              runSpacing: 4,
                              children: [
                                if (_canViewCostPrice && !isPending && p.cost > 0)
                                  _metaChip(
                                    label: l10n.inventoryCapitalChip(MoneyUtils.formatCompactCurrency(p.cost)),
                                    color: Colors.deepPurple.shade500,
                                    bg: Colors.deepPurple.shade50,
                                    icon: Icons.account_balance_wallet_outlined,
                                  ),
                                if (_allowPendingCost && _canViewCostPrice && !isPending && p.cost == 0)
                                  GestureDetector(
                                    onTap: () => _showInlineCostEdit(p),
                                    child: _metaChip(
                                      label: '⚠ Chưa vốn',
                                      color: Colors.orange.shade700,
                                      bg: Colors.orange.shade50,
                                      icon: Icons.edit_rounded,
                                    ),
                                  ),
                                if (p.imei != null && p.imei!.trim().isNotEmpty)
                                  _metaChip(
                                    label: p.imei!.trim(),
                                    color: Colors.blueGrey.shade600,
                                    bg: Colors.blueGrey.shade50,
                                    icon: Icons.tag_rounded,
                                  ),
                                if (p.supplier != null &&
                                    p.supplier!.trim().isNotEmpty)
                                  _metaChip(
                                    label: p.supplier!.trim(),
                                    color: Colors.teal.shade700,
                                    bg: Colors.teal.shade50,
                                    icon: Icons.storefront_outlined,
                                  ),
                                if (p.createdAt > 0)
                                  _metaChip(
                                    label: DateFormat('dd/MM/yy').format(
                                      DateTime.fromMillisecondsSinceEpoch(
                                        p.createdAt,
                                      ),
                                    ),
                                    color: Colors.grey.shade600,
                                    bg: Colors.grey.shade100,
                                    icon: Icons.calendar_today_outlined,
                                  ),
                                if (p.locationCode != null &&
                                    p.locationCode!.isNotEmpty)
                                  _metaChip(
                                    label: p.locationCode!,
                                    color: Colors.indigo.shade700,
                                    bg: Colors.indigo.shade50,
                                    icon: Icons.location_on_rounded,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Badge số lượng
                          _buildQtyBadge(
                            p.quantity,
                            isOutOfStock,
                            isLowStock,
                            accentColor,
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.check_circle_rounded,
                              color: accentColor,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                      // Hàng 3: tag trạng thái + nút thao tác nhanh
                      if (!_isSelectionMode) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (statusLabel.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.30),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      statusIcon,
                                      size: 10,
                                      color: accentColor,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: accentColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const Spacer(),
                            if (!isPending && p.quantity > 0)
                              _quickActionChip(
                                icon: Icons.shopping_cart_outlined,
                                label: l10n.inventorySellAction,
                                color: Colors.blue.shade700,
                                bgColor: Colors.blue.shade50,
                                onTap: () => _createSaleOrder(p),
                              ),
                            if (canManageProduct) ...[
                              const SizedBox(width: 5),
                              _quickActionChip(
                                icon: Icons.edit_outlined,
                                label: l10n.inventoryEditAction,
                                color: Colors.orange.shade700,
                                bgColor: Colors.orange.shade50,
                                onTap: () => _editProduct(p),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (_enableVariants && p.firestoreId != null) ...[
                        const SizedBox(height: 4),
                        VariantStockWidget(
                          productId: p.firestoreId!,
                          variantService: _variantService,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip({
    required String label,
    required Color color,
    required Color bg,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBadge(
    int qty,
    bool isOutOfStock,
    bool isLowStock,
    Color accentColor,
  ) {
    final Color badgeColor = isOutOfStock
        ? Colors.red.shade600
        : isLowStock
        ? Colors.orange.shade600
        : accentColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$qty',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          Text(
            'còn',
            style: TextStyle(
              fontSize: 8,
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Chip thao tác nhanh hiển thị trong card sản phẩm
  Widget _quickActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog xác nhận giá vốn và chuyển từ Kho Tạm sang Kho Chính
  void _showConfirmCostDialog(Product p) {
    final l10n = AppLocalizations.of(context)!;
    final costC = TextEditingController();
    final priceC = TextEditingController();
    String? selectedSupplier = p.pendingSupplier;
    String selectedPaymentMethod = 'TIỀN MẶT';
    bool isSaving = false;

    final paymentMethods = ['TIỀN MẶT', 'CHUYỂN KHOẢN', 'CÔNG NỢ'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> confirmCost() async {
            CurrencyTextField.finalizeAll();

            final cost = CurrencyTextField.parseValue(costC.text);
            if (cost <= 0 && !_allowPendingCost) {
              NotificationService.showSnackBar(
                l10n.inventoryValidCostError,
                color: Colors.red,
              );
              return;
            }

            if (selectedSupplier == null || selectedSupplier!.isEmpty) {
              NotificationService.showSnackBar(
                l10n.inventorySelectSupplierError,
                color: Colors.red,
              );
              return;
            }

            if (isSaving) return;
            setS(() => isSaving = true);

            try {
              final ts = DateTime.now().millisecondsSinceEpoch;
              final price = CurrencyTextField.parseValue(priceC.text);

              // 1. Cập nhật sản phẩm - chuyển từ kho tạm sang kho chính
              final updatedP = p.copyWith(
                cost: cost,
                price: price > 0 ? price : null,
                isPending: false,
                pendingSupplier: null,
                supplier: selectedSupplier,
                paymentMethod: selectedPaymentMethod,
                updatedAt: ts,
              );

              await db.upsertProduct(updatedP);

              // Queue sync VÀ sync ngay lập tức lên Firestore
              if (p.id != null) {
                await SyncOrchestrator().enqueue(
                  entityType: SyncEntityType.product,
                  entityId: p.id!,
                  firestoreId: p.firestoreId,
                  operation: SyncOperation.update,
                  data: updatedP.toMap(),
                );
              }

              // 2. Lưu lịch sử nhập hàng từ nhà cung cấp
              final supplierData = _suppliers.firstWhere(
                (s) => s['name'] == selectedSupplier,
                orElse: () => {},
              );
              final supplierId = supplierData['id'];
              final shopId = await UserService.getCurrentShopId();
              final user = FirebaseAuth.instance.currentUser;
              final userName =
                  user?.email?.split('@').first.toUpperCase() ?? "NV";

              if ((selectedSupplier?.trim().isNotEmpty ?? false)) {
                final importHistory = {
                  'supplierId': supplierId,
                  'supplierName': selectedSupplier,
                  'productName': p.name,
                  'productBrand': p.brand,
                  'productModel': p.model,
                  'imei': p.imei,
                  'quantity': p.quantity,
                  'costPrice': cost,
                  'totalAmount': cost * p.quantity,
                  'paymentMethod': selectedPaymentMethod,
                  'importDate': ts,
                  'importedBy': userName,
                  'notes': 'Xác nhận giá từ Kho Tạm',
                  'shopId': shopId,
                  'isSynced': 0,
                };
                final importHistoryId = await db.insertSupplierImportHistory(
                  importHistory,
                );
                if (importHistoryId > 0) {
                  await SyncOrchestrator().enqueueSupplierImportHistory(
                    importHistoryId,
                    firestoreId: importHistory['firestoreId'] as String?,
                    operation: SyncOperation.create,
                  );
                }

                // Cập nhật giá nhà cung cấp
                await db.deactivateSupplierProductPrice(
                  supplierId,
                  p.name,
                  p.brand,
                  p.model,
                );
                final supplierPrice = {
                  'supplierId': supplierId,
                  'productName': p.name,
                  'productBrand': p.brand,
                  'productModel': p.model,
                  'costPrice': cost,
                  'lastUpdated': ts,
                  'createdAt': ts,
                  'isActive': 1,
                  'shopId': shopId,
                };
                await db.insertSupplierProductPrice(supplierPrice);

                // Cập nhật thống kê nhà cung cấp khi resolve được supplierId
                if (supplierId != null) {
                  await db.updateSupplierStats(
                    supplierId,
                    cost * p.quantity,
                    p.quantity,
                  );
                }
              }

              // Final sync pass after product + supplier import history are enqueued.
              try {
                await SyncOrchestrator().syncAll();
              } catch (e) {
                debugPrint('Inventory confirmCost sync warning: $e');
              }

              // 3. Xử lý thanh toán
              // NOTE: Direct insertExpense/upsertDebt for staging confirm BLOCKED
              // Payment must go through PaymentIntentService -> UnifiedPaymentPage
              // Product is updated but payment execution is separate flow

              // 4. Log action
              await db.logAction(
                userId: user?.uid ?? "0",
                userName: userName,
                action: "XÁC NHẬN GIÁ KHO TẠM",
                type: "PRODUCT",
                targetId: p.imei,
                desc:
                    "Xác nhận giá ${p.name} - Giá: ${MoneyUtils.formatCurrency(cost)}đ - NCC: $selectedSupplier",
              );

              // 5. Chat notification
              await FirestoreService.sendChat(
                message:
                    "✅ Đã xác nhận giá từ Kho Tạm: ${p.name} (${p.imei}) - Giá: ${MoneyUtils.formatCurrency(cost)}đ - NCC: $selectedSupplier",
                senderId: user?.uid ?? "system",
                senderName: userName,
                linkedType: "PRODUCT",
                linkedKey: p.imei ?? '',
                linkedSummary: p.name,
              );

              EventBus().emit('suppliers_changed');
              EventBus().emit('products_changed');

              if (mounted) {
                Navigator.pop(ctx);
                _refresh();
                NotificationService.showSnackBar(
                  l10n.inventoryConfirmCostSuccess,
                  color: Colors.green,
                );
              }
            } catch (e) {
              setS(() => isSaving = false);
              NotificationService.showSnackBar("Lỗi: $e", color: Colors.red);
            }
          }

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.inventoryConfirmCostTitle,
                    style: AppTextStyles.headline3,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thông tin sản phẩm
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: AppTextStyles.headline4.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_terms.specialField1Label}: ${p.imei ?? "N/A"}',
                          style: AppTextStyles.subtitle1,
                        ),
                        Text(
                          'SL: ${p.quantity}',
                          style: AppTextStyles.subtitle1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Giá vốn - chỉ hiển thị nếu có quyền
                  if (_canViewCostPrice) ...[
                    CurrencyTextField(
                      controller: costC,
                      label: l10n.inventoryCostPriceRequired,
                      icon: Icons.monetization_on,
                      autoMultiply1000: true,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Giá bán (optional)
                  CurrencyTextField(
                    controller: priceC,
                    label: l10n.inventorySalePriceOptional,
                    icon: Icons.sell,
                    autoMultiply1000: true,
                  ),
                  const SizedBox(height: 12),

                  // Nhà cung cấp dropdown
                  DropdownButtonFormField<String>(
                    initialValue:
                        _suppliers.any((s) => s['name'] == selectedSupplier)
                        ? selectedSupplier
                        : null,
                    decoration: InputDecoration(
                      labelText: l10n.inventorySupplierRequired,
                      prefixIcon: const Icon(Icons.business),
                      border: const OutlineInputBorder(),
                    ),
                    items: _suppliers.map((s) {
                      return DropdownMenuItem<String>(
                        value: s['name'] as String,
                        child: Text(s['name'] as String),
                      );
                    }).toList(),
                    onChanged: (v) => setS(() => selectedSupplier = v),
                  ),
                  const SizedBox(height: 12),

                  // Phương thức thanh toán
                  DropdownButtonFormField<String>(
                    initialValue: selectedPaymentMethod,
                    decoration: InputDecoration(
                      labelText: l10n.inventoryPaymentLabel,
                      prefixIcon: const Icon(Icons.payment),
                      border: const OutlineInputBorder(),
                    ),
                    items: paymentMethods.map((m) {
                      return DropdownMenuItem<String>(value: m, child: Text(m));
                    }).toList(),
                    onChanged: (v) =>
                        setS(() => selectedPaymentMethod = v ?? 'TIỀN MẶT'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : confirmCost,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l10n.inventoryConfirmBtn,
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
  void _editProduct(Product p) {
    final l10n = AppLocalizations.of(context)!;
    // Tên máy = chỉ model (VD: "15 PRO MAX")
    final nameC = TextEditingController(text: p.model ?? '');
    final imeiC = TextEditingController(text: p.imei ?? '');
    final costC = TextEditingController(
      text: CurrencyTextField.formatDisplay(p.cost),
    );
    final priceC = TextEditingController(
      text: CurrencyTextField.formatDisplay(p.price),
    );
    // Chi tiết tách riêng: capacity, color, condition - dùng dropdown thay vì text
    final mappedCapacity = ProductConstants.mapCapacity(p.capacity);
    String? selectedCapacity =
        ProductConstants.capacities.contains(mappedCapacity)
        ? mappedCapacity
        : (mappedCapacity.isNotEmpty ? mappedCapacity : null);
    final mappedColor = p.color != null && p.color!.isNotEmpty
        ? ProductConstants.mapColor(p.color)
        : null;
    String? selectedColor =
        mappedColor != null && ProductConstants.colors.contains(mappedColor)
        ? mappedColor
        : null;
    final mappedCondition = p.condition.isNotEmpty
        ? ProductConstants.mapConditionShort(p.condition)
        : null;
    String? selectedCondition =
        mappedCondition != null &&
            ProductConstants.conditionsShort.contains(mappedCondition)
        ? mappedCondition
        : null;

    // Fallback: nếu color/capacity/condition chưa được lưu riêng (sản phẩm cũ),
    // thử parse từ description (= detail trong Firestore), format: "256GB - ĐEN - MỚI"
    if (selectedColor == null &&
        selectedCapacity == null &&
        p.description.isNotEmpty) {
      final parts = p.description.split(' - ');
      for (final part in parts) {
        final trimmed = part.trim().toUpperCase();
        // Parse capacity (kết thúc bằng GB hoặc TB)
        if (selectedCapacity == null &&
            (trimmed.endsWith('GB') || trimmed.endsWith('TB'))) {
          final cap = ProductConstants.mapCapacity(trimmed);
          if (ProductConstants.capacities.contains(cap)) selectedCapacity = cap;
        }
        // Parse color
        if (selectedColor == null &&
            ProductConstants.colors.contains(trimmed)) {
          selectedColor = trimmed;
        }
        // Parse condition
        if (selectedCondition == null &&
            ProductConstants.conditionsShort.contains(trimmed)) {
          selectedCondition = trimmed;
        }
      }
    }
    final labelInfoC = TextEditingController(text: p.labelInfo ?? '');
    final labelNoteC = TextEditingController(text: p.labelNote ?? '');
    // Brand chọn riêng - giữ từ sản phẩm gốc
    String? selectedBrand = ProductConstants.mapBrand(p.brand);

    // Phase 2: Food module - Expiry & Batch fields
    final batchC = TextEditingController(text: p.batchNumber ?? '');
    DateTime? expiryDate = p.expiryDate != null
        ? DateTime.fromMillisecondsSinceEpoch(p.expiryDate!)
        : null;

    String type = p.type;
    String? supplier = p.supplier;
    bool isSaving = false;
    String? editLocalImagePath = p.localImagePath;
    StorageLocation? editSelectedLocation =
        (p.locationCode?.isNotEmpty ?? false)
        ? StorageLocation(
            firestoreId: p.locationId,
            code: p.locationCode!,
            name: p.locationName ?? p.locationCode!,
            createdAt: 0,
          )
        : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> saveProcess() async {
            final capEditLoc = editSelectedLocation;
            final capEditImg = editLocalImagePath;
            // Finalize currency fields trước khi xử lý
            CurrencyTextField.finalizeAll();

            if (supplier == null) {
              NotificationService.showSnackBar(
                l10n.inventorySelectSupplierFirst,
                color: Colors.red,
              );
              return;
            }
            if (isSaving) return;
            setS(() => isSaving = true);
            try {
              final int ts = DateTime.now().millisecondsSinceEpoch;
              final newCost = CurrencyTextField.parseValue(costC.text);

              // Nếu sản phẩm đang ở kho tạm và giờ có giá vốn > 0
              // → Chuyển sang kho chính (isPending = false)
              final shouldTransferToMainInventory = p.isPending && newCost > 0;

              // Tạo tên sản phẩm chuẩn từ các field
              // nameC = model, selectedBrand = brand
              final generatedName = ProductConstants.generateProductName(
                brand: selectedBrand,
                model: nameC.text.trim(), // nameC chứa model
                capacity: selectedCapacity,
                color: selectedColor,
                condition: selectedCondition,
              );

              final updatedP = p.copyWith(
                name: generatedName,
                brand: selectedBrand ?? p.brand,
                model: nameC.text.trim().isNotEmpty ? nameC.text.trim() : null,
                imei: imeiC.text.trim(),
                cost: newCost,
                price: CurrencyTextField.parseValue(priceC.text),
                capacity: selectedCapacity ?? '',
                color: selectedColor ?? '',
                condition: selectedCondition ?? p.condition,
                labelInfo: labelInfoC.text.trim(),
                labelNote: labelNoteC.text.trim().isNotEmpty
                    ? labelNoteC.text.trim().toUpperCase()
                    : null,
                quantity: p.quantity, // SL không thay đổi qua edit — dùng "Nhập thêm"
                type: type,
                supplier: supplier,
                updatedAt: ts,
                isSynced: false,
                // Tự động chuyển kho tạm → kho chính nếu có giá vốn
                isPending: shouldTransferToMainInventory ? false : p.isPending,
                pendingSupplier: shouldTransferToMainInventory
                    ? null
                    : p.pendingSupplier,
                // Phase 2: Food module - Expiry & Batch
                expiryDate: expiryDate?.millisecondsSinceEpoch,
                batchNumber: batchC.text.trim().isNotEmpty
                    ? batchC.text.trim()
                    : null,
                locationId: capEditLoc?.firestoreId,
                locationCode: capEditLoc?.code,
                locationName: capEditLoc?.name,
                localImagePath: capEditImg,
              );
              final user = FirebaseAuth.instance.currentUser;
              final userName =
                  user?.email?.split('@').first.toUpperCase() ?? "NV";
              // Cảnh báo nếu giá vốn thay đổi và sản phẩm đã ở kho chính
              if (newCost != p.cost && !p.isPending) {
                final confirmed = await showPremiumConfirm(
                  context: ctx,
                  icon: Icons.warning_amber_rounded,
                  headerGradient: PopupTheme.headerOrange,
                  title: l10n.inventoryCostChangeTitle,
                  message: l10n.inventoryCostChangeMessage,
                  confirmLabel: l10n.inventoryConfirmBtn,
                  confirmColor: PopupTheme.orange,
                );
                if (confirmed != true) {
                  setS(() => isSaving = false);
                  return;
                }
              }
              await db.logAction(
                userId: user?.uid ?? "0",
                userName: userName,
                action: "CHỈNH SỬA",
                type: "PRODUCT",
                targetId: p.imei,
                desc: "Đã chỉnh sửa máy ${p.name}",
              );
              await db.upsertProduct(updatedP);

              // Get product ID and queue sync
              final savedProduct = await db.getProductByFirestoreId(
                updatedP.firestoreId ?? 'prod_${updatedP.createdAt}',
              );
              if (savedProduct?.id != null) {
                await SyncOrchestrator().enqueue(
                  entityType: SyncEntityType.product,
                  entityId: savedProduct!.id!,
                  firestoreId: updatedP.firestoreId,
                  operation: SyncOperation.update,
                  data: updatedP.toMap(),
                );
              }

              // Background image upload nếu có ảnh local mới
              if (capEditImg != null &&
                  capEditImg != p.images &&
                  savedProduct != null) {
                ProductImageService.uploadAndSaveToProduct(
                  product: savedProduct,
                  localPath: capEditImg,
                );
              }

              HapticFeedback.lightImpact();
              if (mounted) {
                Navigator.of(ctx).pop();
                _refresh();
                NotificationService.showSnackBar(
                  l10n.inventoryUpdateSuccess,
                  color: Colors.green,
                );
              }
            } catch (e) {
              setS(() => isSaving = false);
              NotificationService.showSnackBar("Lỗi: $e", color: Colors.red);
            }
          }

          return AlertDialog(
            titlePadding: EdgeInsets.zero,
            backgroundColor: PopupTheme.bgDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PopupTheme.radiusDialog),
            ),
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: PopupTheme.headerEdit,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(PopupTheme.radiusDialog),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.inventoryEditProductTitle(_terms.productLabel.toUpperCase()),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            content: Theme(
              data: Theme.of(ctx).copyWith(
                inputDecorationTheme: Theme.of(ctx).inputDecorationTheme.copyWith(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              child: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(ctx).size.height * 0.65,
                child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Loại hàng (KHÓA - không cho thay đổi)
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.inventoryProductTypeLocked,
                      labelStyle: const TextStyle(
                        color: PopupTheme.textMuted,
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock,
                        size: 16,
                        color: PopupTheme.textMuted,
                      ),
                      filled: true,
                      fillColor: PopupTheme.cardDark,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                        borderSide: const BorderSide(color: PopupTheme.borderDark),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                        borderSide: const BorderSide(color: PopupTheme.borderDark),
                      ),
                    ),
                    child: Text(
                      type,
                      style: const TextStyle(
                        color: PopupTheme.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  // Hãng - chỉ hiện cho điện thoại
                  if (_businessType == 'electronics') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: ProductConstants.brands.contains(selectedBrand)
                          ? selectedBrand
                          : null,
                      dropdownColor: PopupTheme.surfaceDark,
                      style: const TextStyle(
                        color: PopupTheme.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.inventoryBrandField,
                        labelStyle: const TextStyle(
                          color: PopupTheme.textSecondary,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.business,
                          size: 16,
                          color: PopupTheme.textSecondary,
                        ),
                        filled: true,
                        fillColor: PopupTheme.surfaceDark,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                          borderSide: const BorderSide(color: PopupTheme.borderDark),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                          borderSide: const BorderSide(color: PopupTheme.borderDark),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                          borderSide: const BorderSide(color: PopupTheme.blue, width: 1.5),
                        ),
                      ),
                      items: ProductConstants.brands
                          .map(
                            (b) => DropdownMenuItem(
                              value: b,
                              child: Text(b, style: const TextStyle(fontSize: 13)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setS(() => selectedBrand = v),
                    ),
                  ],

                  // Tên sản phẩm / Model
                  _input(
                    nameC,
                    _isElectronics
                        ? l10n.inventoryModelField
                        : l10n.inventoryProductNameLabel(_terms.productLabel.toLowerCase()),
                    _isElectronics ? Icons.phone_android : Icons.inventory_2,
                    caps: true,
                  ),

                  // Dung lượng/Size + Màu sắc (dropdown)
                  if (_isElectronics || _isFashion)
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: _isFashion
                                ? (ProductConstants.clothingSizes.contains(selectedCapacity) ? selectedCapacity : null)
                                : (ProductConstants.capacities.contains(selectedCapacity) ? selectedCapacity : null),
                            isExpanded: true,
                            dropdownColor: PopupTheme.surfaceDark,
                            style: const TextStyle(color: PopupTheme.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: _isFashion ? l10n.inventorySizeLabel : l10n.inventoryCapacityLabel,
                              labelStyle: const TextStyle(color: PopupTheme.textSecondary, fontSize: 13),
                              prefixIcon: Icon(
                                _isFashion ? Icons.straighten : Icons.storage,
                                size: 16,
                                color: PopupTheme.textSecondary,
                              ),
                              filled: true,
                              fillColor: PopupTheme.surfaceDark,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                                borderSide: const BorderSide(color: PopupTheme.borderDark),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                                borderSide: const BorderSide(color: PopupTheme.borderDark),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                                borderSide: const BorderSide(color: PopupTheme.blue, width: 1.5),
                              ),
                            ),
                            items: (_isFashion ? ProductConstants.clothingSizes : ProductConstants.capacities)
                                .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) => setS(() => selectedCapacity = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: ProductConstants.colors.contains(selectedColor) ? selectedColor : null,
                            isExpanded: true,
                            dropdownColor: PopupTheme.surfaceDark,
                            style: const TextStyle(color: PopupTheme.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: l10n.inventoryColorField,
                        labelStyle: const TextStyle(color: PopupTheme.textSecondary, fontSize: 13),
                        prefixIcon: const Icon(Icons.color_lens, size: 16, color: PopupTheme.textSecondary),
                        filled: true,
                        fillColor: PopupTheme.surfaceDark,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                          borderSide: const BorderSide(color: PopupTheme.borderDark),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                          borderSide: const BorderSide(color: PopupTheme.borderDark),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                          borderSide: const BorderSide(color: PopupTheme.blue, width: 1.5),
                        ),
                      ),
                      items: ProductConstants.colors
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setS(() => selectedColor = v),
                    ),
                        ),
                      ],
                    ),

                  // Tình trạng (MỚI, 99, 98...)
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: selectedCondition,
                    dropdownColor: PopupTheme.surfaceDark,
                    style: const TextStyle(color: PopupTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: l10n.inventoryConditionField,
                      labelStyle: const TextStyle(color: PopupTheme.textSecondary, fontSize: 13),
                      prefixIcon: const Icon(Icons.grade, size: 16, color: PopupTheme.textSecondary),
                      filled: true,
                      fillColor: PopupTheme.surfaceDark,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                        borderSide: const BorderSide(color: PopupTheme.borderDark),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                        borderSide: const BorderSide(color: PopupTheme.borderDark),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                        borderSide: const BorderSide(color: PopupTheme.blue, width: 1.5),
                      ),
                    ),
                    items: ProductConstants.conditionsShort
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setS(() => selectedCondition = v),
                  ),

                  // Thông tin in trên tem
                  _input(
                    labelInfoC,
                    l10n.inventoryLabelInfoField,
                    Icons.local_offer_outlined,
                  ),

                  // Ghi chú sản phẩm
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextFormField(
                      controller: labelNoteC,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(fontSize: 13, color: PopupTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: l10n.note,
                        hintText: l10n.inventoryNoteHint,
                        labelStyle: const TextStyle(color: PopupTheme.textSecondary, fontSize: 13),
                        hintStyle: const TextStyle(color: PopupTheme.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.note_alt_outlined, size: 18, color: PopupTheme.textSecondary),
                        isDense: true,
                        filled: true,
                        fillColor: PopupTheme.surfaceDark,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                          borderSide: const BorderSide(color: PopupTheme.borderDark),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                          borderSide: const BorderSide(color: PopupTheme.borderDark),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                          borderSide: const BorderSide(color: PopupTheme.blue, width: 1.5),
                        ),
                      ),
                    ),
                  ),

                  // IMEI/Serial (read-only) - chỉ hiện nếu enableSerial
                  if (_enableSerial)
                    _input(
                      imeiC,
                      _terms.specialField1Label,
                      Icons.fingerprint,
                      readOnly: true,
                    ),

                  // Giá vốn - KHÓA nếu đã nhập kho chính hoặc đã bán, ẩn nếu không có quyền
                  if (_canViewCostPrice) ...[
                    if (!p.isPending || p.status == 0)
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: l10n.inventoryCostLockedField,
                          labelStyle: const TextStyle(color: PopupTheme.textMuted, fontSize: 13),
                          prefixIcon: const Icon(Icons.lock, size: 16, color: PopupTheme.textMuted),
                          filled: true,
                          fillColor: PopupTheme.cardDark,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                            borderSide: const BorderSide(color: PopupTheme.borderDark),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                            borderSide: const BorderSide(color: PopupTheme.borderDark),
                          ),
                        ),
                        child: Text(
                          CurrencyTextField.formatDisplay(p.cost),
                          style: const TextStyle(color: PopupTheme.textMuted, fontSize: 14),
                        ),
                      )
                    else
                      _input(
                        costC,
                        l10n.inventoryCostField,
                        Icons.money,
                        type: TextInputType.number,
                        suffix: "k",
                      ),
                  ],

                  // Giá bán
                  _input(
                    priceC,
                    l10n.inventoryPriceField,
                    Icons.sell,
                    type: TextInputType.number,
                    suffix: "k",
                  ),

                  // Phase 2: Food module - Expiry & Batch fields
                  if (_enableExpiry || _enableBatch) ...[
                    const Divider(height: 30, thickness: 1),
                    Text(
                      l10n.inventoryExpiry,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: PopupTheme.orange,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (_enableExpiry) ...[
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate:
                                expiryDate ??
                                DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 5),
                            ),
                            helpText: l10n.inventoryChooseExpiry,
                          );
                          if (picked != null) {
                            setS(() => expiryDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: l10n.inventoryExpiryLabel,
                            labelStyle: const TextStyle(color: PopupTheme.textSecondary, fontSize: 13),
                            prefixIcon: const Icon(Icons.event, color: PopupTheme.orange),
                            filled: true,
                            fillColor: PopupTheme.surfaceDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                              borderSide: const BorderSide(color: PopupTheme.borderDark),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                              borderSide: const BorderSide(color: PopupTheme.borderDark),
                            ),
                            suffixIcon: expiryDate != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: PopupTheme.textMuted),
                                    onPressed: () => setS(() => expiryDate = null),
                                  )
                                : null,
                          ),
                          child: Text(
                            expiryDate != null
                                ? DateFormat('dd/MM/yyyy').format(expiryDate!)
                                : l10n.inventoryNotChosen,
                            style: TextStyle(
                              color: expiryDate != null
                                  ? PopupTheme.textPrimary
                                  : PopupTheme.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (_enableBatch) ...[
                      const SizedBox(height: 12),
                      _input(batchC, l10n.inventoryBatchField, Icons.qr_code_2, caps: true),
                    ],
                  ],

                  // Ảnh sản phẩm & vị trí lưu kho
                  const Divider(height: 20, thickness: 1, color: PopupTheme.borderDark),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.inventoryPhotoSection,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: PopupTheme.blue,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ImagePickerWidget(
                    imageUrl: p.images?.isNotEmpty == true ? p.images : null,
                    localPath: editLocalImagePath,
                    onImagePicked: (path) =>
                        setS(() => editLocalImagePath = path),
                    onImageDeleted: () => setS(() => editLocalImagePath = null),
                    size: 72,
                  ),
                  const SizedBox(height: 10),
                  StorageLocationSelector(
                    selectedLocationId: editSelectedLocation?.firestoreId,
                    selectedLocationCode: editSelectedLocation?.code,
                    selectedLocationName: editSelectedLocation?.name,
                    onSelected: (loc) => setS(() => editSelectedLocation = loc),
                  ),
                  const SizedBox(height: 8),

                  // Số lượng (khóa) + Nhà cung cấp (khóa)
                  Row(
                    children: [
                      // SL hiện tại — KHÓA, không cho sửa trực tiếp
                      Expanded(
                        flex: 1,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: l10n.inventoryStockQty,
                            labelStyle: const TextStyle(color: PopupTheme.textMuted, fontSize: 13),
                            prefixIcon: const Icon(Icons.lock, size: 16, color: PopupTheme.textMuted),
                            filled: true,
                            fillColor: PopupTheme.cardDark,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                              borderSide: const BorderSide(color: PopupTheme.borderDark),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                              borderSide: const BorderSide(color: PopupTheme.borderDark),
                            ),
                          ),
                          child: Text(
                            p.quantity.toString(),
                            style: const TextStyle(color: PopupTheme.textMuted, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Nhà cung cấp (KHÓA - không cho thay đổi)
                      Expanded(
                        flex: 2,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: l10n.inventorySupplierLockedField,
                            labelStyle: const TextStyle(color: PopupTheme.textMuted, fontSize: 13),
                            prefixIcon: const Icon(Icons.lock, size: 16, color: PopupTheme.textMuted),
                            filled: true,
                            fillColor: PopupTheme.cardDark,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                              borderSide: const BorderSide(color: PopupTheme.borderDark),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(PopupTheme.radiusField),
                              borderSide: const BorderSide(color: PopupTheme.borderDark),
                            ),
                          ),
                          child: Text(
                            supplier ?? l10n.inventoryNoSupplier,
                            style: const TextStyle(color: PopupTheme.textMuted, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Nút nhập thêm hàng — dòng riêng, full width
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showQuickStockInDialog(p);
                      },
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: Text(l10n.inventoryRestockBtn, style: const TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal,
                        side: const BorderSide(color: Colors.teal),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
                ),
              ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: PopupTheme.secondaryButton(),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSaving ? null : () => saveProcess(),
                      style: PopupTheme.primaryButton(),
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.update),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _getStatusText(BuildContext context, int status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case 1:
        return l10n.inventoryStatusReceived;
      case 2:
        return l10n.inventoryStatusRepairing;
      case 3:
        return l10n.inventoryStatusCompleted;
      case 4:
        return l10n.inventoryStatusDelivered;
      default:
        return l10n.inventoryStatusUnknown;
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 1:
        return AppColors.repairReceived;
      case 2:
        return AppColors.repairRepairing;
      case 3:
        return AppColors.repairDone;
      case 4:
        return AppColors.repairDelivered;
      default:
        return Colors.grey;
    }
  }
}
