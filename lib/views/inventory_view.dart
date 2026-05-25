import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_write_helper.dart';
import '../utils/money_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/db_helper.dart';
import '../constants/product_constants.dart';
import '../utils/vietnamese_utils.dart';
import '../models/product_model.dart';
import '../models/inventory_check_model.dart';
import '../models/payment_intent_model.dart';
import '../constants/financial_constants.dart';
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
import '../services/payment_intent_service.dart';
import '../services/variant_service.dart';
import '../utils/sku_generator.dart';
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
import '../theme/app_button_styles.dart';
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
  bool _isAdmin = false; // Used in _init for permission check
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
      _filterLocationCode != null;

  final Set<int> _selectedIds = {};
  bool _isSelectionMode = false;

  // Tab controller
  late TabController _tabController;

  // Inventory check variables
  String _selectedType = 'DIEN_THOAI';
  List<Map<String, dynamic>> _items = [];
  List<InventoryCheckItem> _checkItems = [];
  bool _isCheckingLoading = false;
  bool _isScanning = false;
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 1000,
    formats: [BarcodeFormat.all],
  );
  InventoryCheck? _currentCheck;

  // Layout sizing constants (iconSize, smallFontSize, btnMinHeight are in use)
  final double _iconSize = 20.0;
  final double _smallFontSize = 11.0;
  final double _btnMinHeight = 44.0;

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
                'Tìm ${_terms.productLabel.toLowerCase()}',
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
                  hintText:
                      'Nhập ${_terms.productLabel.toLowerCase()}, ${_terms.category2.toLowerCase()} hoặc ${_terms.specialField1Label}...',
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
                    child: const Text('Xóa'),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Hủy'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, controller.text),
                    child: const Text('Tìm'),
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
    FocusNode? f,
    FocusNode? next,
    TextInputType type = TextInputType.text,
    String? suffix,
    bool caps = false,
    bool isBig = false,
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

  /// Auto-fix paymentMethod cho sản phẩm cũ thiếu thông tin
  Future<void> _autoFixProductPaymentMethod(Product p) async {
    try {
      String paymentMethod = 'TIỀN MẶT'; // Default

      // Lấy từ Firestore để kiểm tra stockEntryId
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(p.firestoreId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final stockEntryId = data['stockEntryId'] as String?;

        if (stockEntryId != null) {
          // Lấy paymentMethod từ stock_entries
          final entryDoc = await FirebaseFirestore.instance
              .collection('stock_entries')
              .doc(stockEntryId)
              .get();
          if (entryDoc.exists) {
            paymentMethod = entryDoc.data()?['paymentMethod'] ?? 'TIỀN MẶT';
          }
        } else if (data['supplierId'] != null) {
          // Nếu có supplierId, kiểm tra có debt không
          final debtSnap = await FirebaseFirestore.instance
              .collection('supplier_debts')
              .where('supplierId', isEqualTo: data['supplierId'])
              .limit(1)
              .get();
          if (debtSnap.docs.isNotEmpty) {
            paymentMethod = 'CÔNG NỢ';
          }
        }

        // Cập nhật Firestore
        await FirebaseFirestore.instance
            .collection('products')
            .doc(p.firestoreId)
            .update({
              'paymentMethod': paymentMethod,
              'updatedAt': FirestoreWriteHelper.serverUpdatedAt(),
            });

        // Cập nhật local
        p.paymentMethod = paymentMethod;
        await db.upsertProduct(p);

        debugPrint('✅ Auto-fixed paymentMethod for ${p.name}: $paymentMethod');
      }
    } catch (e) {
      debugPrint('⚠️ Error auto-fixing paymentMethod: $e');
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
                      const PopupBadge(
                        label: 'KHO TẠM',
                        color: PopupTheme.yellow,
                        icon: Icons.hourglass_bottom_rounded,
                      )
                    else
                      PopupBadge(
                        label: displayProduct.quantity > 0 ? 'CÒN HÀNG' : 'HẾT HÀNG',
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
                                  const Text(
                                    'KHO TẠM – Chờ xác nhận giá',
                                    style: TextStyle(
                                      color: PopupTheme.yellow,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (displayProduct.pendingSupplier != null)
                                    Text(
                                      'NCC dự kiến: ${displayProduct.pendingSupplier}',
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
                            label: 'SL tồn kho',
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
                              label: 'Giá nhập',
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
                            label: 'Giá bán',
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
                              label: profit >= 0 ? 'Lợi nhuận' : 'Lỗ',
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
                              label: 'Dung lượng',
                              value: displayProduct.capacity ?? '',
                            ),
                          ] else if (_isFashion &&
                              (displayProduct.capacity?.isNotEmpty ?? false)) ...[
                            const Divider(
                                height: 1, color: PopupTheme.borderDark),
                            PopupInfoRow(
                              icon: Icons.straighten,
                              iconColor: PopupTheme.blue,
                              label: 'Kích thước',
                              value: displayProduct.capacity!,
                            ),
                          ],
                          const Divider(height: 1, color: PopupTheme.borderDark),
                          PopupInfoRow(
                            icon: Icons.business_outlined,
                            iconColor: PopupTheme.teal,
                            label: 'Nhà cung cấp',
                            value: displayProduct.isPending
                                ? (displayProduct.pendingSupplier ??
                                    'Chưa xác nhận')
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
                              label: 'Giá nhập',
                              value: displayProduct.isPending
                                  ? 'Chờ xác nhận'
                                  : '${MoneyUtils.formatCurrency(displayProduct.cost)} đ',
                              valueColor: PopupTheme.yellow,
                              bold: true,
                            ),
                          ],
                          const Divider(height: 1, color: PopupTheme.borderDark),
                          PopupInfoRow(
                            icon: Icons.arrow_upward_rounded,
                            iconColor: PopupTheme.green,
                            label: 'Giá bán',
                            value: displayProduct.isPending
                                ? 'Chờ xác nhận'
                                : '${MoneyUtils.formatCurrency(displayProduct.price)} đ',
                            valueColor: PopupTheme.green,
                            bold: true,
                          ),
                          const Divider(height: 1, color: PopupTheme.borderDark),
                          PopupInfoRow(
                            icon: Icons.payment_outlined,
                            iconColor: PopupTheme.blue,
                            label: 'Thanh toán',
                            value: displayProduct.isPending
                                ? 'Chờ xác nhận'
                                : (displayProduct.paymentMethod ?? 'N/A'),
                          ),
                          if (displayProduct.labelNote != null &&
                              displayProduct.labelNote!.isNotEmpty) ...[
                            const Divider(
                                height: 1, color: PopupTheme.borderDark),
                            PopupInfoRow(
                              icon: Icons.notes_rounded,
                              iconColor: PopupTheme.textSecondary,
                              label: 'Ghi chú',
                              value: displayProduct.labelNote!,
                            ),
                          ],
                          if (hasLocation) ...[
                            const Divider(
                                height: 1, color: PopupTheme.borderDark),
                            PopupInfoRow(
                              icon: Icons.location_on_rounded,
                              iconColor: PopupTheme.teal,
                              label: 'Vị trí kho',
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
                            label: 'Cập nhật cuối',
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
                      const PopupSectionDivider(title: 'LỊCH SỬ SỬA CHỮA'),
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
                                      _getStatusText(r.status),
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
                          label: const Text('XÁC NHẬN GIÁ – CHUYỂN KHO CHÍNH'),
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
                                'Đang in tem...', color: Colors.teal);
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
                                ok ? 'In tem thành công' : 'Lỗi khi in tem',
                                color: ok ? Colors.green : Colors.red,
                              );
                            }
                          },
                          icon: const Icon(Icons.qr_code_2, size: 15),
                          label: const Text('IN TEM'),
                          style: _compactOutlineBtn(PopupTheme.blue),
                        ),
                        // SỬA
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _editProduct(p);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('SỬA'),
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
                          label: const Text('BÁN'),
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
                            label: Text('NHẬP THÊM (${p.quantity})'),
                            style: _compactOutlineBtn(PopupTheme.teal),
                          ),
                        // XÓA
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showDeleteConfirmation(p);
                          },
                          icon: const Icon(Icons.delete_outline, size: 15),
                          label: const Text('XÓA'),
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
                        'NHẬP THÊM',
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
                                'Tồn kho hiện tại: ${p.quantity}',
                                style: AppTextStyles.subtitle1.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                'Giá vốn hiện tại: ${MoneyUtils.formatCurrency(p.cost)}đ',
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
                      labelText: 'Số lượng nhập thêm',
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
                    label: 'Giá nhập (VNĐ)',
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
                          'Giá vốn sau nhập: ${MoneyUtils.formatCurrency(weightedCost)}đ',
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
                      labelText: 'Phương thức thanh toán',
                      prefixIcon: const Icon(Icons.payment),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          PopupTheme.radiusField,
                        ),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'TIỀN MẶT',
                        child: Text('Tiền mặt'),
                      ),
                      DropdownMenuItem(
                        value: 'CHUYỂN KHOẢN',
                        child: Text('Chuyển khoản'),
                      ),
                      DropdownMenuItem(
                        value: 'CÔNG NỢ',
                        child: Text('Công nợ'),
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
                          child: const Text('HỦY'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text(
                            'NHẬP KHO',
                            style: TextStyle(
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
                                'Vui lòng nhập số lượng hợp lệ',
                                color: Colors.red,
                              );
                              return;
                            }
                            final cost = CurrencyTextField.parseValue(
                              costCtrl.text,
                            );
                            if (cost <= 0) {
                              NotificationService.showSnackBar(
                                'Vui lòng nhập giá nhập hợp lệ',
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
    try {
      NotificationService.showSnackBar('Đang nhập kho...', color: Colors.blue);
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
          'Không tìm thấy nhà cung cấp hợp lệ cho sản phẩm này. Vui lòng cập nhật NCC rồi nhập lại.',
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
          'Lỗi tạo phiếu nhập kho',
          color: Colors.red,
        );
        return;
      }

      // Auto-confirm entry to update stock + financial records
      final confirmed = await service.confirmEntry(created.firestoreId!);
      if (confirmed) {
        NotificationService.showSnackBar(
          '✅ Đã nhập thêm $qty ${p.name} vào kho',
          color: Colors.green,
        );
        // Force sync to reflect new quantities
        await SyncOrchestrator().syncAll();
        _refresh();
      } else {
        NotificationService.showSnackBar(
          'Lỗi xác nhận phiếu nhập kho',
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

  void _createSaleOrder(Product p) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateSaleView(preSelectedProduct: p)),
    ).then((_) => _refresh());
  }

  void _showEditProductDialog(Product p) {
    // Tách model riêng, brand riêng
    String? selectedBrand = ProductConstants.mapBrand(p.brand);
    final modelCtrl = TextEditingController(text: p.model ?? '');
    final capacityCtrl = TextEditingController(
      text: ProductConstants.mapCapacity(p.capacity),
    );
    final colorCtrl = TextEditingController(
      text: ProductConstants.mapColor(p.color),
    );
    final imeiCtrl = TextEditingController(text: p.imei ?? '');
    final supplierCtrl = TextEditingController(text: p.supplier ?? '');
    final costCtrl = TextEditingController(
      text: MoneyUtils.formatCurrency(p.cost),
    );
    final priceCtrl = TextEditingController(
      text: MoneyUtils.formatCurrency(p.price),
    );
    final quantityCtrl = TextEditingController(text: p.quantity.toString());

    // Kiểm tra xem có được sửa giá vốn/NCC không
    // Chỉ được sửa nếu: còn trong kho tạm (isPending) VÀ chưa bán (status == 1)
    final canEditFinancialInfo = p.isPending && p.status == 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Chỉnh sửa ${_terms.productLabel.toLowerCase()}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hãng
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: ProductConstants.brands.contains(selectedBrand)
                      ? selectedBrand
                      : null,
                  decoration: const InputDecoration(
                    labelText: "Hãng *",
                    prefixIcon: Icon(Icons.business, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  items: ProductConstants.brands
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setS(() => selectedBrand = v),
                ),
                const SizedBox(height: 12),
                // Model
                ValidatedTextField(
                  controller: modelCtrl,
                  label: 'Model (VD: 15 PRO MAX)',
                  uppercase: true,
                  customValidator: (val) =>
                      val.isEmpty ? 'Vui lòng nhập model' : null,
                ),
                const SizedBox(height: 12),
                // Dung lượng/Size - chỉ hiển thị cho electronics hoặc fashion
                if (_isElectronics || _isFashion)
                  ValidatedTextField(
                    controller: capacityCtrl,
                    label: _isFashion ? 'Size' : 'Dung lượng (VD: 256GB)',
                    uppercase: true,
                  ),
                if (_isElectronics || _isFashion) const SizedBox(height: 12),
                ValidatedTextField(
                  controller: colorCtrl,
                  label: 'Màu sắc',
                  uppercase: true,
                ),
                const SizedBox(height: 12),
                if (_enableSerial) ...[
                  ValidatedTextField(
                    controller: imeiCtrl,
                    label: _terms.specialField1Label,
                  ),
                  const SizedBox(height: 12),
                ],
                // Nhà cung cấp - KHÓA nếu đã nhập kho chính
                if (canEditFinancialInfo)
                  ValidatedTextField(
                    controller: supplierCtrl,
                    label: 'Nhà cung cấp',
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Nhà cung cấp (không đổi)',
                      prefixIcon: Icon(
                        Icons.lock,
                        size: 16,
                        color: Colors.grey,
                      ),
                      filled: true,
                      fillColor: Color(0xFFF5F5F5),
                    ),
                    child: Text(
                      p.supplier ?? 'N/A',
                      style: AppTextStyles.headline4.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                // Giá nhập - KHÓA nếu đã nhập kho chính hoặc không có quyền xem giá vốn
                if (_canViewCostPrice) ...[
                  if (canEditFinancialInfo)
                    CurrencyTextField(
                      controller: costCtrl,
                      label: 'Giá nhập (VNĐ)',
                    )
                  else
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Giá nhập (không đổi)',
                        prefixIcon: Icon(
                          Icons.lock,
                          size: 16,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Color(0xFFF5F5F5),
                      ),
                      child: Text(
                        MoneyUtils.formatCurrency(p.cost),
                        style: AppTextStyles.headline4.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
                CurrencyTextField(
                  controller: priceCtrl,
                  label: 'Giá bán (VNĐ)',
                ),
                const SizedBox(height: 12),
                ValidatedTextField(
                  controller: quantityCtrl,
                  label: 'Số lượng',
                  keyboardType: TextInputType.number,
                  customValidator: (val) {
                    final qty = int.tryParse(val);
                    if (qty == null || qty < 0) {
                      return 'Số lượng phải là số không âm';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate form
                final qty = int.tryParse(quantityCtrl.text);
                if (qty == null || qty < 0) {
                  NotificationService.showSnackBar(
                    'Số lượng không hợp lệ',
                    color: Colors.red,
                  );
                  return;
                }

                try {
                  final oldCost = p.cost;
                  final oldPrice = p.price;
                  // Chỉ lấy giá mới nếu được phép sửa
                  final newCost = canEditFinancialInfo
                      ? CurrencyTextField.getValueWithMultiply(costCtrl)
                      : p.cost;

                  // Nếu sản phẩm đang ở kho tạm và giờ có giá vốn > 0
                  // → Chuyển sang kho chính (isPending = false)
                  final shouldTransferToMainInventory =
                      p.isPending && newCost > 0;

                  // Tạo tên sản phẩm chuẩn từ các field
                  final generatedName = ProductConstants.generateProductName(
                    brand: selectedBrand ?? '',
                    model: modelCtrl.text.trim(),
                    capacity: capacityCtrl.text.trim(),
                    color: colorCtrl.text.trim(),
                    condition: p.condition, // Giữ nguyên condition
                  );

                  final updatedProduct = p.copyWith(
                    name: generatedName,
                    brand: selectedBrand,
                    model: modelCtrl.text.trim(),
                    capacity: ProductConstants.mapCapacity(
                      capacityCtrl.text.trim(),
                    ),
                    color: ProductConstants.mapColor(colorCtrl.text.trim()),
                    imei: imeiCtrl.text.trim(),
                    supplier: canEditFinancialInfo
                        ? supplierCtrl.text.trim()
                        : p.supplier,
                    cost: newCost,
                    price: CurrencyTextField.getValueWithMultiply(priceCtrl),
                    quantity: qty,
                    updatedAt: DateTime.now().millisecondsSinceEpoch,
                    isSynced: false,
                    // Tự động chuyển kho tạm → kho chính nếu có giá vốn
                    isPending: shouldTransferToMainInventory
                        ? false
                        : p.isPending,
                    pendingSupplier: shouldTransferToMainInventory
                        ? null
                        : p.pendingSupplier,
                  );

                  // Kiểm tra nếu giá thay đổi
                  final priceChanged =
                      oldCost != updatedProduct.cost ||
                      oldPrice != updatedProduct.price;

                  // Cập nhật local database
                  await db.updateProduct(updatedProduct);

                  // Queue sync to cloud via SyncOrchestrator
                  if (updatedProduct.id != null) {
                    await SyncOrchestrator().enqueue(
                      entityType: SyncEntityType.product,
                      entityId: updatedProduct.id!,
                      firestoreId: updatedProduct.firestoreId,
                      operation: SyncOperation.update,
                      data: updatedProduct.toMap(),
                    );
                  }

                  await _refresh();
                  Navigator.pop(ctx);

                  // CẬP NHẬT BẢNG GIÁ NHÀ CUNG CẤP NẾU CÓ THAY ĐỔI GIÁ NHẬP
                  if (oldCost != updatedProduct.cost &&
                      updatedProduct.supplier?.isNotEmpty == true) {
                    try {
                      // Tìm supplier ID từ tên supplier
                      final suppliers = await supplierService.getSuppliers();
                      final supplier = suppliers
                          .where((s) => s.name == updatedProduct.supplier)
                          .firstOrNull;

                      if (supplier != null) {
                        // Cập nhật hoặc tạo mới giá trong bảng supplier_product_prices
                        final priceData = {
                          'supplierId': supplier.id,
                          'productName': updatedProduct.name,
                          'productBrand': updatedProduct.brand,
                          'productModel': updatedProduct.capacity ?? '',
                          'costPrice': updatedProduct.cost,
                          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
                          'createdAt': DateTime.now().millisecondsSinceEpoch,
                          'isActive': 1,
                        };

                        await db.insertSupplierProductPrice(priceData);
                        debugPrint(
                          'Updated supplier price for ${updatedProduct.name}: ${updatedProduct.cost}',
                        );
                      }
                    } catch (e) {
                      debugPrint('Error updating supplier product price: $e');
                    }
                  }

                  if (priceChanged) {
                    // Hiển thị cảnh báo về việc giá thay đổi
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('⚠️ Lưu ý quan trọng'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Bạn vừa thay đổi giá của ${_terms.productLabel.toLowerCase()}. Điều này sẽ ảnh hưởng đến:',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.warning.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _warningItem(
                                    '❌ Các đơn hàng bán đã tạo: GIÁ KHÔNG ĐƯỢC CẬP NHẬT',
                                  ),
                                  _warningItem(
                                    '❌ Công nợ khách hàng: SỐ TIỀN KHÔNG THAY ĐỔI',
                                  ),
                                  _warningItem('❌ Báo cáo lợi nhuận: TÍNH SAI'),
                                  _warningItem(
                                    '❌ Đơn hàng nhập: GIÁ KHÔNG ẢNH HƯỞNG',
                                  ),
                                  _warningItem(
                                    '✅ Bảng giá nhà cung cấp: ĐƯỢC CẬP NHẬT TỰ ĐỘNG',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Để cập nhật chính xác, bạn cần sửa lại từng đơn hàng đã tạo.',
                              style: AppTextStyles.headline5.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('ĐÃ HIỂU'),
                          ),
                        ],
                      ),
                    );
                  }

                  NotificationService.showSnackBar(
                    'Đã cập nhật ${_terms.productLabel.toLowerCase()}',
                    color: Colors.green,
                  );
                } catch (e) {
                  NotificationService.showSnackBar(
                    'Lỗi cập nhật ${_terms.productLabel.toLowerCase()}: $e',
                    color: Colors.red,
                  );
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductActionDialog(Product p) {
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
              title: const Text('Chỉnh sửa'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              onTap: () {
                Navigator.pop(ctx);
                _editProduct(p);
              },
            ),
            ListTile(
              leading: Icon(Icons.visibility_off_rounded, color: Colors.red.shade700),
              title: const Text('Ẩn khỏi kho'),
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
                  'ẨN ${_terms.productLabel.toUpperCase()} (KHO)',
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
                          'Giá vốn: ${MoneyUtils.formatCurrency(p.cost)}đ',
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
                        '⚠️ LƯU Ý QUAN TRỌNG:',
                        style: AppTextStyles.subtitle1.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Đây là XÓA MỀM – chỉ ẩn khỏi danh sách kho\n'
                        '• KHÔNG ảnh hưởng doanh thu, công nợ, lịch sử nhập\n'
                        '• Mọi số liệu tài chính khác GIỮ NGUYÊN',
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
                    labelText: 'Lý do xóa (tùy chọn)',
                    hintText: 'VD: Nhập sai, trả hàng NCC...',
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
                    labelText: 'Mật khẩu tài khoản *',
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
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (passwordCtrl.text.isEmpty) {
                  NotificationService.showSnackBar(
                    'Vui lòng nhập mật khẩu',
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
                    'Mật khẩu không đúng',
                    color: AppColors.error,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('ẨN KHỎI KHO'),
            ),
          ],
        ),
      ),
    );
  }

  /// Xóa sản phẩm với các options liên quan
  Future<void> _deleteProductWithOptions(Product p, {String? reason}) async {
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
        'Đã ẩn ${_terms.productLabel.toLowerCase()} khỏi kho: ${p.name}',
        color: Colors.green,
      );
    } catch (e) {
      NotificationService.showSnackBar(
        'Lỗi xóa ${_terms.productLabel.toLowerCase()}: $e',
        color: Colors.red,
      );
    }
  }


  Color _getBrandColor(String name) {
    String n = name.toUpperCase();
    if (n.startsWith("IP-")) return Colors.blueGrey; // iPhone
    if (n.startsWith("SS-")) return Colors.blue; // Samsung
    if (n.startsWith("PIN-")) return Colors.green; // Pin/Linh kiện
    if (n.startsWith("MH-")) return Colors.orange; // Máy khác
    if (n.startsWith("PK-")) return Colors.blue; // Phụ kiện
    // Fallback cho tên cũ
    if (n.contains("IPHONE")) return Colors.blueGrey;
    if (n.contains("SAMSUNG")) return Colors.blue;
    if (n.contains("OPPO")) return Colors.green;
    if (n.contains("XIAOMI") || n.contains("REDMI")) return Colors.orange;
    return const Color(0xFF2962FF);
  }

  Widget _buildEmptyState() {
    final isFiltered = _searchQuery.isNotEmpty ||
        _filterType != 'TẤT CẢ' ||
        _filterLocationCode != null;
    return EmptyStateWidget(
      icon: isFiltered
          ? Icons.search_off_rounded
          : Icons.inventory_2_outlined,
      title: isFiltered ? 'Không tìm thấy sản phẩm' : 'Kho hàng đang trống',
      subtitle: isFiltered
          ? 'Thử bỏ bộ lọc hoặc tìm từ khóa khác'
          : _showOutOfStock
              ? null
              : 'Bật "Hết hàng" để xem sản phẩm đã hết',
    );
  }

  Future<void> _init() async {
    final perms = await UserService.getCurrentUserPermissions();
    // Load shop settings for multi-industry features
    final settings = await CategoryService().getShopSettings();
    if (!mounted) return;
    setState(() {
      _isAdmin = perms['allowViewInventory'] ?? false;
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

  /// Build inventory type dropdown items based on business type
  List<DropdownMenuItem<String>> _buildInventoryTypeItems() {
    switch (_businessType) {
      case 'food':
        return [
          DropdownMenuItem(
            value: 'THUC_PHAM',
            child: Text('🥗 ${_terms.category1}'),
          ),
          DropdownMenuItem(
            value: 'DO_UONG',
            child: Text('🥤 ${_terms.category2}'),
          ),
          DropdownMenuItem(
            value: 'NGUYEN_LIEU',
            child: Text('🌾 ${_terms.category3}'),
          ),
        ];
      case 'fashion':
        return [
          DropdownMenuItem(
            value: 'THOI_TRANG',
            child: Text('👕 ${_terms.category1}'),
          ),
          DropdownMenuItem(
            value: 'GIAY_DEP',
            child: Text('👟 ${_terms.category2}'),
          ),
          DropdownMenuItem(
            value: 'PHU_KIEN_TT',
            child: Text('👜 ${_terms.category3}'),
          ),
        ];
      case 'general':
        return [
          DropdownMenuItem(
            value: 'SAN_PHAM',
            child: Text('📦 ${_terms.productLabel}'),
          ),
          DropdownMenuItem(value: 'DICH_VU', child: Text('🛠️ Dịch vụ')),
        ];
      case 'electronics':
      default:
        return [
          DropdownMenuItem(
            value: 'DIEN_THOAI',
            child: Text('📱 ${_terms.category1}'),
          ),
          DropdownMenuItem(
            value: 'PHU_KIEN',
            child: Text('🔧 ${_terms.category2} (Kho sửa chữa)'),
          ),
        ];
    }
  }

  Future<void> _initCheckData() async {
    await _loadOrCreateCurrentCheck();
    await _loadCheckItems();
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

    final passwordCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÁC NHẬN XÓA"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Bạn có chắc chắn muốn xóa ${_selectedIds.length} mặt hàng đã chọn không?",
            ),
            const SizedBox(height: 15),
            const Text('Nhập mật khẩu tài khoản để xóa:'),
            const SizedBox(height: 10),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu tài khoản',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("HỦY"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordCtrl.text.isEmpty) {
                NotificationService.showSnackBar(
                  'Vui lòng nhập mật khẩu',
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
                  'Mật khẩu không đúng',
                  color: Colors.red,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              "XÓA NGAY",
              style: TextStyle(color: Colors.white),
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

  Future<void> _loadCheckItems() async {
    setState(() => _isCheckingLoading = true);
    try {
      _items = await db.getItemsForInventoryCheck(_selectedType);
      _updateCheckItems();
    } catch (e) {
      debugPrint('Lỗi tải kiểm kho: $e');
      NotificationService.showSnackBar(
        'Lỗi tải danh sách: $e',
        color: Colors.red,
      );
    } finally {
      setState(() => _isCheckingLoading = false);
    }
  }

  void _updateCheckItems() {
    _checkItems = _items.map((item) {
      final existingItem = _currentCheck?.items.firstWhere(
        (checkItem) => checkItem.itemId == item['id'].toString(),
        orElse: () => InventoryCheckItem(
          itemId: item['id'].toString(),
          itemName: item['name'] ?? '',
          itemType: _selectedType,
          imei: item['imei'],
          quantity: item['quantity'] ?? 0,
        ),
      );
      return existingItem ??
          InventoryCheckItem(
            itemId: item['id'].toString(),
            itemName: item['name'] ?? '',
            itemType: _selectedType,
            imei: item['imei'],
            quantity: item['quantity'] ?? 0,
          );
    }).toList();
  }

  void _updateItemQuantity(String itemId, int quantity) {
    quantity = quantity < 0 ? 0 : quantity;
    setState(() {
      final index = _checkItems.indexWhere((item) => item.itemId == itemId);
      if (index != -1) {
        _checkItems[index] = InventoryCheckItem(
          itemId: _checkItems[index].itemId,
          itemName: _checkItems[index].itemName,
          itemType: _checkItems[index].itemType,
          imei: _checkItems[index].imei,
          color: _checkItems[index].color,
          quantity: quantity,
          isChecked: quantity > 0,
          checkedAt: quantity > 0 ? DateTime.now().millisecondsSinceEpoch : 0,
        );
      }
    });
  }

  Future<void> _saveCheck() async {
    if (_currentCheck == null) return;

    setState(() => _isCheckingLoading = true);
    try {
      _currentCheck = InventoryCheck(
        id: _currentCheck!.id,
        firestoreId: _currentCheck!.firestoreId,
        checkType: _currentCheck!.checkType,
        checkDate: _currentCheck!.checkDate,
        checkedBy: _currentCheck!.checkedBy,
        items: _checkItems,
        isCompleted: true,
        isSynced: _currentCheck!.isSynced,
        createdAt: _currentCheck!.createdAt,
      );

      await db.updateInventoryCheck(_currentCheck!.toMap());
      NotificationService.showSnackBar(
        'Đã lưu kiểm kho thành công!',
        color: Colors.green,
      );
    } catch (e) {
      NotificationService.showSnackBar(
        'Lỗi lưu kiểm kho: $e',
        color: Colors.red,
      );
    } finally {
      setState(() => _isCheckingLoading = false);
    }
  }

  // Debounce variables for QR scanning
  DateTime? _lastQRScanTime;
  String? _lastQRCode;
  bool _isQRProcessing = false;
  static const Duration _qrScanDelay = Duration(seconds: 2); // 2-3s delay

  void _onQRDetected(BarcodeCapture capture) {
    // Prevent processing while already handling a scan
    if (_isQRProcessing) return;

    final barcode = capture.barcodes.first;
    if (barcode.rawValue == null || barcode.rawValue!.isEmpty) return;

    final imei = barcode.rawValue!.trim();
    final now = DateTime.now();

    // Check if this is a duplicate scan within the delay period
    if (_lastQRScanTime != null && _lastQRCode == imei) {
      final elapsed = now.difference(_lastQRScanTime!);
      if (elapsed < _qrScanDelay) {
        // Ignore duplicate scan within delay period
        return;
      }
    }

    // Set processing flag and update last scan time
    _isQRProcessing = true;
    _lastQRScanTime = now;
    _lastQRCode = imei;

    final item = _checkItems.firstWhere(
      (item) => item.imei == imei,
      orElse: () => InventoryCheckItem(
        itemId: imei,
        itemName: '${_terms.productLabel} quét: $imei',
        itemType: _selectedType,
        quantity: 1,
        isChecked: true,
        checkedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    if (!item.isChecked) {
      _updateItemQuantity(item.itemId, item.quantity + 1);
      HapticFeedback.vibrate();
      NotificationService.showSnackBar('Đã quét: ${item.itemName}');
    }

    // Reset processing flag after delay
    Future.delayed(_qrScanDelay, () {
      _isQRProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Kiểm tra quyền truy cập
    if (!_hasInventoryAccess) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: CustomAppBar.build(
          title: 'QUẢN LÝ KHO TỔNG',
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory_2, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                "Bạn không có quyền truy cập\nmàn hình quản lý kho",
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
        title: 'QUẢN LÝ KHO',
        subtitle:
            '${_products.length} ${_terms.productLabel.toLowerCase()}${_unsyncedCount > 0 ? ' • $_unsyncedCount chưa đồng bộ' : ''}',
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
              tooltip: 'Thêm linh kiện',
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
              tooltip: 'Nhập kho nhanh (AI)',
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
              tooltip: 'Nhập kho',
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
                ? 'Tìm kiếm'
                : 'Tìm kiếm: "$_searchQuery"',
            splashRadius: 20,
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: AppBarAccents.inventory,
              size: 22,
            ),
            tooltip: 'Thêm',
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
                    title: 'Xuất kho linh kiện',
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
                    title: 'Xuất kho hàng',
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
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'location',
                child: Row(children: [
                  Icon(Icons.location_on_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Vị trí lưu kho'),
                ]),
              ),
              PopupMenuItem(
                value: 'print',
                child: Row(children: [
                  Icon(Icons.qr_code_2_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('In tem'),
                ]),
              ),
              PopupMenuItem(
                value: 'excel',
                child: Row(children: [
                  Icon(Icons.file_download_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Xuất Excel'),
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
            tooltip: 'Làm mới',
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
                                  'Đã hiển thị ${filteredList.length} ${_terms.productLabel.toLowerCase()}',
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

  Widget _buildInventoryCheckTab() {
    return Column(
      children: [
        // Type selector and Scanner Controls
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 8),
            ],
          ),
          child: Column(
            children: [
              // Type selector - dynamic based on business type
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _selectedType,
                decoration: InputDecoration(
                  labelText:
                      "Loại ${_terms.productLabel.toLowerCase()} kiểm kho",
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _buildInventoryTypeItems(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                    _initCheckData();
                  }
                },
              ),

              const SizedBox(height: 16),

              // Scanner Controls
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _isScanning = !_isScanning);
                        if (_isScanning) {
                          _scannerController.start();
                        } else {
                          _scannerController.stop();
                        }
                      },
                      icon: Icon(
                        _isScanning ? Icons.stop : Icons.play_arrow,
                        size: _iconSize,
                      ),
                      label: Text(
                        _isScanning ? "DỪNG SCAN" : "BẮT ĐẦU SCAN",
                        style: AppTextStyles.body1,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isScanning
                            ? Colors.red
                            : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size(double.infinity, _btnMinHeight),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () => _scannerController.toggleTorch(),
                    icon: const Icon(Icons.flashlight_on),
                    tooltip: "Bật/tắt đèn flash",
                  ),
                ],
              ),
            ],
          ),
        ),

        // QR Scanner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _isScanning ? Colors.transparent : Colors.black,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _isScanning
                ? MobileScanner(
                    controller: _scannerController,
                    onDetect: (capture) => _onQRDetected(capture),
                  )
                : Container(
                    color: Colors.black,
                    child: const Center(
                      child: Text(
                        "Camera chưa được khởi động",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
          ),
        ),

        // Progress Summary
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 8),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _progressItem(
                "Tổng ${_terms.productLabel.toLowerCase()}",
                _checkItems.length.toString(),
                Icons.inventory,
              ),
              _progressItem(
                "Đã kiểm",
                _checkItems.where((item) => item.isChecked).length.toString(),
                Icons.check_circle,
                Colors.green,
              ),
              _progressItem(
                "Chưa kiểm",
                _checkItems.where((item) => !item.isChecked).length.toString(),
                Icons.radio_button_unchecked,
                Colors.orange,
              ),
            ],
          ),
        ),

        // Check items list
        Expanded(
          child: _isCheckingLoading
              ? const Center(child: CircularProgressIndicator())
              : _checkItems.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Chưa có dữ liệu kiểm kho",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _checkItems.length,
                  itemBuilder: (context, index) {
                    final item = _checkItems[index];
                    final isComplete = item.isChecked;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(
                          item.itemName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.imei != null && item.imei!.isNotEmpty)
                              Text("${_terms.specialField1Label}: ${item.imei}")
                            else
                              Text(
                                _selectedType == 'PHU_KIEN'
                                    ? "${_terms.category2} sửa chữa"
                                    : _selectedType == 'LINH_KIEN'
                                    ? "${_terms.category3} (không ${_terms.specialField1Label})"
                                    : "Mã SP: ${item.itemId}",
                                style: AppTextStyles.subtitle1.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            Text(
                              "SL hiện tại: ${item.quantity}",
                              style: TextStyle(
                                color: isComplete
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: item.quantity > 0
                                  ? () => _updateItemQuantity(
                                      item.itemId,
                                      item.quantity - 1,
                                    )
                                  : null,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isComplete
                                    ? Colors.green.withAlpha(25)
                                    : Colors.grey.withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "${item.quantity}",
                                style: AppTextStyles.headline3.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isComplete
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => _updateItemQuantity(
                                item.itemId,
                                item.quantity + 1,
                              ),
                            ),
                          ],
                        ),
                        leading: Icon(
                          isComplete
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isComplete ? Colors.green : Colors.grey,
                          size: _iconSize,
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Save button
        Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _saveCheck,
            icon: const Icon(Icons.save),
            label: const Text("LƯU KIỂM KHO"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2962FF),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInventorySummary(int qty, int capital, int shownCount) {
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
            isFiltered ? 'HIỂN THỊ / TỔNG' : 'TỔNG KHO',
            isFiltered ? '$shownCount / $qty' : '$qty',
            Icons.inventory,
          ),
          Container(width: 1, height: 36, color: Colors.white24),
          _summaryItemCompact(
            "VỐN TỒN KHO",
            _canViewCostPrice
                ? "${MoneyUtils.formatCompactCurrency(capital)} đ"
                : "Không có quyền",
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

  Widget _progressItem(
    String label,
    String val,
    IconData icon, [
    Color? color,
  ]) {
    return Column(
      children: [
        Icon(icon, color: color ?? const Color(0xFF2962FF), size: 24),
        const SizedBox(height: 4),
        Text(
          val,
          style: AppTextStyles.headline1.copyWith(
            color: color ?? const Color(0xFF2962FF),
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.subtitle1.copyWith(color: Colors.grey.shade600),
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
          ],
        ),
      ),
    );
  }

  Widget _buildLocationFilterChip() {
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
              isActive ? _filterLocationCode! : 'Vị trí',
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
              'Hết hàng',
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

  Future<void> _showLocationFilterSheet() async {
    final shopId = await UserService.getCurrentShopId() ?? '';
    final locations = await db.getStorageLocations(shopId, activeOnly: true);
    if (!mounted) return;
    if (locations.isEmpty) {
      NotificationService.showSnackBar('Chưa có vị trí nào được tạo.');
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Lọc theo vị trí',
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
    final isSelected = _filterType == type;
    final label = type == 'DIEN_THOAI'
        ? _terms.category1
        : type == 'PHU_KIEN'
        ? _terms.category2
        : type == 'LINH_KIEN'
        ? _terms.category3
        : 'Tất cả';

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
      statusLabel = 'Kho tạm';
      statusIcon = Icons.hourglass_top_rounded;
    } else if (isOutOfStock) {
      accentColor = Colors.red.shade600;
      statusLabel = 'Hết hàng';
      statusIcon = Icons.remove_circle_outline;
    } else if (isLowStock) {
      accentColor = Colors.orange.shade500;
      statusLabel = 'Sắp hết';
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
        ? 'Chờ giá'
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
                                if (_canViewCostPrice &&
                                    !isPending &&
                                    p.cost > 0)
                                  _metaChip(
                                    label:
                                        'Vốn ${MoneyUtils.formatCompactCurrency(p.cost)}đ',
                                    color: Colors.deepPurple.shade500,
                                    bg: Colors.deepPurple.shade50,
                                    icon: Icons.account_balance_wallet_outlined,
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
                                label: 'Bán',
                                color: Colors.blue.shade700,
                                bgColor: Colors.blue.shade50,
                                onTap: () => _createSaleOrder(p),
                              ),
                            if (canManageProduct) ...[
                              const SizedBox(width: 5),
                              _quickActionChip(
                                icon: Icons.edit_outlined,
                                label: 'Sửa',
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

  String _buildCompactMetaLine(Product p, bool isPending) {
    final parts = <String>[];
    if (_canViewCostPrice && !isPending && p.cost > 0) {
      parts.add('Vốn ${MoneyUtils.formatCompactCurrency(p.cost)}đ');
    }
    if (!isPending) {
      parts.add('Bán ${MoneyUtils.formatCompactCurrency(p.price)}đ');
    }
    if (p.supplier != null && p.supplier!.trim().isNotEmpty) {
      parts.add('NCC: ${p.supplier!.trim()}');
    }
    // Ngày nhập kho
    if (p.createdAt > 0) {
      final ngayNhap = DateFormat(
        'dd/MM/yy',
      ).format(DateTime.fromMillisecondsSinceEpoch(p.createdAt));
      parts.add('Nhập: $ngayNhap');
    }
    if (isPending) {
      parts.add('Chờ giá');
    }
    return parts.join(' • ');
  }

  void _showAddProductDialog() {
    final nameC = TextEditingController();
    final imeiC = TextEditingController();
    final costC = TextEditingController();
    final priceC = TextEditingController();
    final detailC = TextEditingController();
    final qtyC = TextEditingController(text: "1");
    final nameF = FocusNode();
    final imeiF = FocusNode();
    final costF = FocusNode();
    final priceF = FocusNode();
    final qtyF = FocusNode();

    // Phase 2: Food module - Expiry & Batch fields
    final batchC = TextEditingController();
    DateTime? expiryDate;

    // SKU fields
    String selectedNhom = 'IP'; // Default nhóm
    final modelC = TextEditingController();
    final thongtinC = TextEditingController();
    final skuC = TextEditingController(); // Generated SKU display/edit
    final skuF = FocusNode();

    String type = "DIEN_THOAI";
    String payMethod = "TIỀN MẶT";
    String? supplier = _suppliers.isNotEmpty
        ? _suppliers.first['name'] as String
        : null;
    bool isSaving = false;
    StorageLocation? selectedLocation;
    String? localImagePath;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> generateSKU() async {
            if (selectedNhom.isEmpty) {
              NotificationService.showSnackBar(
                "Vui lòng chọn nhóm ${_terms.productLabel.toLowerCase()}!",
                color: Colors.red,
              );
              return;
            }

            try {
              final generatedSKU = await SKUGenerator.generateSKU(
                nhom: selectedNhom,
                model: modelC.text.trim().isNotEmpty
                    ? modelC.text.trim()
                    : null,
                thongtin: thongtinC.text.trim().isNotEmpty
                    ? thongtinC.text.trim()
                    : null,
                dbHelper: db,
                firestoreService: null,
              );

              setS(() => skuC.text = generatedSKU);
              NotificationService.showSnackBar(
                "Đã tạo mã hàng: $generatedSKU",
                color: Colors.blue,
              );
            } catch (e) {
              NotificationService.showSnackBar(
                "Lỗi tạo mã hàng: $e",
                color: Colors.red,
              );
            }
          }

          Future<void> saveProcess({bool next = false}) async {
            // Capture outer-scope variables before async gaps
            final capLoc = selectedLocation;
            final capImg = localImagePath;
            // Finalize currency fields trước khi xử lý
            CurrencyTextField.finalizeAll();

            if (skuC.text.isEmpty) {
              NotificationService.showSnackBar(
                "Vui lòng tạo mã hàng trước!",
                color: Colors.red,
              );
              return;
            }
            if (supplier == null) {
              NotificationService.showSnackBar(
                "Vui lòng chọn Nhà cung cấp!",
                color: Colors.red,
              );
              return;
            }
            if (isSaving) return;
            setS(() => isSaving = true);
            try {
              final int ts = DateTime.now().millisecondsSinceEpoch;
              final String imei = imeiC.text.trim();
              final String fId = "prod_${ts}_${imei.isNotEmpty ? imei : ts}";
              final p = Product(
                firestoreId: fId,
                name: skuC.text.toUpperCase(),
                model: modelC.text.trim().isNotEmpty
                    ? modelC.text.trim()
                    : null,
                imei: imei,
                cost: CurrencyTextField.parseValueWithMultiply(costC.text),
                price: CurrencyTextField.parseValueWithMultiply(priceC.text),
                capacity: detailC.text.toUpperCase(),
                quantity: int.tryParse(qtyC.text) ?? 1,
                type: type,
                createdAt: ts,
                supplier: supplier,
                status: 1,
                sku: skuC.text.toUpperCase(),
                expiryDate: expiryDate?.millisecondsSinceEpoch,
                batchNumber: batchC.text.trim().isNotEmpty
                    ? batchC.text.trim()
                    : null,
                unit: _shopSettings?.defaultUnit,
                locationId: capLoc?.firestoreId,
                locationCode: capLoc?.code,
                locationName: capLoc?.name,
                localImagePath: capImg,
              );
              final user = FirebaseAuth.instance.currentUser;
              final userName =
                  user?.email?.split('@').first.toUpperCase() ?? "NV";
              await db.logAction(
                userId: user?.uid ?? "0",
                userName: userName,
                action: "NHẬP KHO",
                type: "PRODUCT",
                targetId: p.imei,
                desc: "Đã nhập máy ${p.name}",
              );

              await db.upsertProduct(p);

              // Get product ID and queue sync
              final savedProduct = await db.getProductByFirestoreId(
                p.firestoreId ?? 'prod_${p.createdAt}',
              );

              // Background image upload nếu có ảnh local
              if (capImg != null && savedProduct != null) {
                ProductImageService.uploadAndSaveToProduct(
                  product: savedProduct,
                  localPath: capImg,
                );
              }

              // === XỬ LÝ PAYMENT METHOD ===
              final totalCost = p.cost * p.quantity;
              if (totalCost > 0 && supplier != null && supplier!.isNotEmpty) {
                final shopId = await UserService.getCurrentShopId() ?? '';
                final nowTs = DateTime.now().millisecondsSinceEpoch;

                // Lấy supplier ID
                final suppliers = await supplierService.getSuppliers();
                final supplierData = suppliers
                    .where((s) => s.name == supplier)
                    .firstOrNull;
                final supplierId = supplierData?.id;

                if (payMethod == 'CÔNG NỢ') {
                  // Tạo debt record - Shop nợ NCC
                  final debtFId = 'debt_stockin_${nowTs}_${supplierId ?? 0}';
                  final debtData = {
                    'firestoreId': debtFId,
                    'type': 'SHOP_OWES',
                    'debtType': 'SHOP_OWES',
                    'personName': supplier,
                    'phone': '',
                    'totalAmount': totalCost,
                    'paidAmount': 0,
                    'note': 'Nhập kho: ${p.name} x${p.quantity}',
                    'status': 'ACTIVE',
                    'createdAt': nowTs,
                    'shopId': shopId,
                    'linkedId': p.firestoreId ?? '',
                    'relatedPartId': supplierId?.toString() ?? '',
                    'deleted': 0,
                    'isSynced': 0,
                  };
                  final debtId = await db.insertDebt(debtData);

                  if (debtId > 0) {
                    await SyncOrchestrator().enqueue(
                      entityType: SyncEntityType.debt,
                      entityId: debtId,
                      firestoreId: debtFId,
                      operation: SyncOperation.create,
                      data: debtData,
                    );
                  }

                  // Công nợ đã ghi nhận ở bảng debts - không cần PaymentIntent
                  debugPrint('✅ Inventory debt recorded: $debtFId');
                  EventBus().emit('debts_changed');
                } else {
                  // TIỀN MẶT / CHUYỂN KHOẢN - ghi nhận thanh toán trực tiếp
                  final payResult =
                      await PaymentIntentService.executePaymentDirect(
                        type: PaymentIntentType.inventoryPurchase,
                        amount: totalCost,
                        paymentMethod: PaymentMethod.fromCode(payMethod),
                        description:
                            'Nhập kho: $supplier - ${p.name} x${p.quantity}',
                        executedBy: user?.uid ?? 'unknown',
                        referenceId: p.firestoreId,
                        referenceType: 'inventory_stockin',
                        personName: supplier,
                        idempotencyKey: p.firestoreId,
                        metadata: {
                          'productId': savedProduct?.id,
                          'productName': p.name,
                          'quantity': p.quantity,
                          'supplierId': supplierId,
                          'paymentMethod': payMethod,
                        },
                      );
                  debugPrint(
                    '💳 Inventory payment ${payResult.success ? "OK" : "FAILED"}: ${totalCost}đ',
                  );
                }
              }
              if (savedProduct?.id != null) {
                await SyncOrchestrator().enqueue(
                  entityType: SyncEntityType.product,
                  entityId: savedProduct!.id!,
                  firestoreId: p.firestoreId,
                  operation: SyncOperation.create,
                  data: p.toMap(),
                );
              }

              // Lưu lịch sử nhập hàng từ nhà cung cấp
              if (supplier?.isNotEmpty == true) {
                final suppliers = await supplierService.getSuppliers();
                final supplierData = suppliers
                    .where((s) => s.name == supplier)
                    .firstOrNull;
                final supplierId = supplierData?.id;
                final shopId = await UserService.getCurrentShopId();
                if (supplier?.trim().isNotEmpty == true) {
                  final importHistory = {
                    'supplierId': supplierId,
                    'supplierName': supplier,
                    'productName': p.name,
                    'productBrand': p.brand,
                    'productModel': p.model,
                    'imei': p.imei,
                    'quantity': p.quantity,
                    'costPrice': p.cost,
                    'totalAmount': p.cost * p.quantity,
                    'paymentMethod': payMethod,
                    'importDate': ts,
                    'importedBy': userName,
                    'notes': 'Nhập từ Inventory View',
                    'shopId': shopId,
                    'isSynced': 0,
                  };
                  final importHistoryId = await db.insertSupplierImportHistory(
                    importHistory,
                  );

                  // FIX BUG-001: Enqueue để sync lên Firestore
                  if (importHistoryId > 0) {
                    await SyncOrchestrator().enqueueSupplierImportHistory(
                      importHistoryId,
                      firestoreId: importHistory['firestoreId'] as String?,
                      operation: SyncOperation.create,
                    );
                  }

                  // Chỉ cập nhật dữ liệu NCC khi resolve được supplierId
                  if (supplierId != null) {
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
                      'costPrice': p.cost,
                      'lastUpdated': ts,
                      'createdAt': ts,
                      'isActive': 1,
                      'shopId': shopId,
                    };
                    await db.insertSupplierProductPrice(supplierPrice);

                    await db.updateSupplierStats(
                      supplierId,
                      p.cost * p.quantity,
                      p.quantity,
                    );
                  }
                }
              }

              // Final sync pass after all related records are enqueued.
              try {
                await SyncOrchestrator().syncAll();
              } catch (e) {
                debugPrint('Inventory saveProcess sync warning: $e');
              }

              HapticFeedback.lightImpact();
              if (next) {
                imeiC.clear();
                setS(() => isSaving = false);
                if (mounted) {
                  FocusScope.of(context).requestFocus(imeiF);
                  NotificationService.showSnackBar(
                    "ĐÃ THÊM MÁY",
                    color: Colors.blue,
                  );
                }
              } else {
                if (mounted) {
                  EventBus().emit('suppliers_changed');
                  EventBus().emit('products_changed');
                  Navigator.of(context).pop();
                  _refresh();
                  NotificationService.showSnackBar(
                    "NHẬP KHO THÀNH CÔNG",
                    color: Colors.green,
                  );
                }
              }
            } catch (e) {
              setS(() => isSaving = false);
            }
          }

          return AlertDialog(
            title: const Text(
              "NHẬP KHO SIÊU TỐC",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF2962FF),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Loại hàng
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: [
                      DropdownMenuItem(
                        value: "DIEN_THOAI",
                        child: Text(_terms.category1),
                      ),
                      DropdownMenuItem(
                        value: "PHỤ KIỆN",
                        child: Text(_terms.category2),
                      ),
                    ],
                    onChanged: (v) => setS(() => type = v!),
                    decoration: const InputDecoration(labelText: "Loại hàng"),
                  ),

                  // Tên máy
                  _input(
                    nameC,
                    _isFashion ? "Tên sản phẩm *" : "Tên máy *",
                    _isFashion ? Icons.checkroom : Icons.phone_android,
                    f: nameF,
                    next: imeiF,
                    caps: true,
                  ),

                  // Chi tiết
                  if (_isElectronics || _isFashion)
                    _input(
                      detailC,
                      _isFashion
                          ? "Size - Màu sắc"
                          : "Chi tiết (Dung lượng - Màu...)",
                      _isFashion ? Icons.straighten : Icons.info_outline,
                      caps: true,
                    ),

                  // IMEI/Serial - chỉ hiển thị cho electronics
                  if (_enableSerial)
                    _input(
                      imeiC,
                      "Số IMEI / Serial",
                      Icons.fingerprint,
                      f: imeiF,
                      next: _canViewCostPrice ? costF : priceF,
                      type: TextInputType.number,
                    ),

                  // Giá vốn - chỉ hiển thị nếu có quyền
                  if (_canViewCostPrice)
                    _input(
                      costC,
                      "Giá vốn (k)",
                      Icons.money,
                      f: costF,
                      next: priceF,
                      type: TextInputType.number,
                      suffix: "k",
                    ),

                  // Giá bán
                  _input(
                    priceC,
                    "Giá bán (k)",
                    Icons.sell,
                    f: priceF,
                    next: qtyF,
                    type: TextInputType.number,
                    suffix: "k",
                  ),

                  // Số lượng và Nhà cung cấp
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: _input(
                          qtyC,
                          "SL",
                          Icons.add_box,
                          f: qtyF,
                          isBig: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: supplier,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: "Nhà cung cấp *",
                          ),
                          items: _suppliers
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s['name'] as String,
                                  child: Text(s['name']),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setS(() => supplier = v),
                        ),
                      ),
                    ],
                  ),

                  // Phase 2: Food module - Expiry & Batch fields
                  if (_enableExpiry || _enableBatch) ...[
                    const Divider(height: 30, thickness: 1),
                    Text(
                      "HẠN SỬ DỤNG",
                      style: AppTextStyles.headline4.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
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
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 5),
                            ),
                            helpText: 'Chọn ngày hết hạn',
                          );
                          if (picked != null) {
                            setS(() => expiryDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Ngày hết hạn',
                            prefixIcon: Icon(
                              Icons.event,
                              color: Colors.orange.shade600,
                            ),
                            suffixIcon: expiryDate != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () =>
                                        setS(() => expiryDate = null),
                                  )
                                : null,
                          ),
                          child: Text(
                            expiryDate != null
                                ? DateFormat('dd/MM/yyyy').format(expiryDate!)
                                : 'Chưa chọn',
                            style: TextStyle(
                              color: expiryDate != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (_enableBatch) ...[
                      const SizedBox(height: 12),
                      _input(batchC, "Số lô hàng", Icons.qr_code_2, caps: true),
                    ],
                  ],

                  // SKU Section
                  const Divider(height: 30, thickness: 1),
                  Text(
                    "MÃ HÀNG",
                    style: AppTextStyles.headline4.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2962FF),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Nhóm
                  DropdownButtonFormField<String>(
                    initialValue: selectedNhom,
                    decoration: const InputDecoration(
                      labelText: "Nhóm *",
                      prefixIcon: Icon(Icons.category, size: 18),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: "IP",
                        child: Text("IP - iPhone"),
                      ),
                      const DropdownMenuItem(
                        value: "SS",
                        child: Text("SS - Samsung"),
                      ),
                      const DropdownMenuItem(
                        value: "PIN",
                        child: Text("PIN - Pin sạc"),
                      ),
                      const DropdownMenuItem(
                        value: "MH",
                        child: Text("MH - Màn hình"),
                      ),
                      DropdownMenuItem(
                        value: "PK",
                        child: Text("PK - ${_terms.category2}"),
                      ),
                    ],
                    onChanged: (v) => setS(() => selectedNhom = v!),
                  ),

                  // Model
                  _input(
                    modelC,
                    "Model (vd: IP12PM)",
                    Icons.smartphone,
                    caps: true,
                  ),

                  // Thông tin
                  _input(
                    thongtinC,
                    "Thông tin (vd: 256GB)",
                    Icons.info,
                    caps: true,
                  ),

                  // Mã hàng và nút tạo
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _input(
                          skuC,
                          "Mã hàng được tạo",
                          Icons.qr_code,
                          f: skuF,
                          caps: true,
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: ElevatedButton.icon(
                          onPressed: () => generateSKU(),
                          icon: const Icon(Icons.auto_fix_high, size: 16),
                          label: const Text("TẠO MÃ"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2962FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 8,
                    children: ["TIỀN MẶT", "CHUYỂN KHOẢN", "CÔNG NỢ"]
                        .map(
                          (m) => ChoiceChip(
                            label: Text(m, style: AppTextStyles.body1),
                            selected: payMethod == m,
                            onSelected: (v) => setS(() => payMethod = m),
                            selectedColor: Colors.blueAccent,
                          ),
                        )
                        .toList(),
                  ),

                  // Ảnh sản phẩm & vị trí lưu kho
                  const Divider(height: 24, thickness: 1),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ẢNH & VỊ TRÍ LƯU KHO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ImagePickerWidget(
                    localPath: localImagePath,
                    onImagePicked: (path) => setS(() => localImagePath = path),
                    onImageDeleted: () => setS(() => localImagePath = null),
                    size: 72,
                  ),
                  const SizedBox(height: 10),
                  StorageLocationSelector(
                    selectedLocationId: selectedLocation?.firestoreId,
                    selectedLocationCode: selectedLocation?.code,
                    selectedLocationName: selectedLocation?.name,
                    onSelected: (loc) => setS(() => selectedLocation = loc),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("HỦY"),
              ),
              OutlinedButton(
                onPressed: isSaving ? null : () => saveProcess(next: true),
                child: const Text("NHẬP TIẾP"),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : () => saveProcess(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2962FF),
                ),
                child: const Text(
                  "HOÀN TẤT",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Dialog xác nhận giá vốn và chuyển từ Kho Tạm sang Kho Chính
  void _showConfirmCostDialog(Product p) {
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
            if (cost <= 0) {
              NotificationService.showSnackBar(
                "Vui lòng nhập giá vốn hợp lệ!",
                color: Colors.red,
              );
              return;
            }

            if (selectedSupplier == null || selectedSupplier!.isEmpty) {
              NotificationService.showSnackBar(
                "Vui lòng chọn nhà cung cấp!",
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
                  "Đã xác nhận giá và chuyển sang Kho Chính!",
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
                    'Xác nhận giá - Chuyển Kho Chính',
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
                      label: 'GIÁ VỐN (*)',
                      icon: Icons.monetization_on,
                      autoMultiply1000: true,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Giá bán (optional)
                  CurrencyTextField(
                    controller: priceC,
                    label: 'GIÁ BÁN (tùy chọn)',
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
                    decoration: const InputDecoration(
                      labelText: 'NHÀ CUNG CẤP (*)',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      labelText: 'THANH TOÁN',
                      prefixIcon: Icon(Icons.payment),
                      border: OutlineInputBorder(),
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
                child: const Text('HỦY'),
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
                    : const Text(
                        'XÁC NHẬN',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editProduct(Product p) {
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
                "Vui lòng chọn Nhà cung cấp!",
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
                  title: 'Cảnh báo thay đổi giá vốn',
                  message: 'Sản phẩm này đã được lưu vào kho. Sửa giá vốn sẽ không ảnh hưởng các đơn cũ nhưng có thể làm sai báo cáo lãi gộp. Bạn có chắc muốn tiếp tục?',
                  confirmLabel: 'Xác nhận',
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
                  "CẬP NHẬT THÀNH CÔNG",
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
                      "CHỈNH SỬA ${_terms.productLabel.toUpperCase()}",
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
                      labelText: "Loại hàng (không đổi)",
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
                        labelText: "Hãng *",
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
                        ? "Model (VD: 15 PRO MAX)"
                        : "Tên ${_terms.productLabel.toLowerCase()}",
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
                              labelText: _isFashion ? 'Kích thước' : 'Dung lượng',
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
                              labelText: 'Màu sắc',
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
                                .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) => setS(() => selectedColor = v),
                          ),
                        ),
                      ],
                    ),
                  if (!_isElectronics && !_isFashion)
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: ProductConstants.colors.contains(selectedColor) ? selectedColor : null,
                      isExpanded: true,
                      dropdownColor: PopupTheme.surfaceDark,
                      style: const TextStyle(color: PopupTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Màu sắc',
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

                  // Tình trạng (MỚI, 99, 98...)
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: selectedCondition,
                    dropdownColor: PopupTheme.surfaceDark,
                    style: const TextStyle(color: PopupTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Tình trạng',
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
                    "Thông tin in trên tem",
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
                        labelText: 'Ghi chú',
                        hintText: 'Ghi chú thêm về sản phẩm...',
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
                          labelText: "Giá vốn (đã nhập kho - không đổi)",
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
                        "Giá vốn (k)",
                        Icons.money,
                        type: TextInputType.number,
                        suffix: "k",
                      ),
                  ],

                  // Giá bán
                  _input(
                    priceC,
                    "Giá bán (k)",
                    Icons.sell,
                    type: TextInputType.number,
                    suffix: "k",
                  ),

                  // Phase 2: Food module - Expiry & Batch fields
                  if (_enableExpiry || _enableBatch) ...[
                    const Divider(height: 30, thickness: 1),
                    const Text(
                      "HẠN SỬ DỤNG",
                      style: TextStyle(
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
                            helpText: 'Chọn ngày hết hạn',
                          );
                          if (picked != null) {
                            setS(() => expiryDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Ngày hết hạn',
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
                                : 'Chưa chọn',
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
                      _input(batchC, "Số lô hàng", Icons.qr_code_2, caps: true),
                    ],
                  ],

                  // Ảnh sản phẩm & vị trí lưu kho
                  const Divider(height: 20, thickness: 1, color: PopupTheme.borderDark),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ẢNH & VỊ TRÍ LƯU KHO',
                      style: TextStyle(
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
                            labelText: "SL tồn kho",
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
                            labelText: "Nhà cung cấp (không đổi)",
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
                            supplier ?? 'Không có',
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
                      label: const Text('Nhập thêm hàng vào kho', style: TextStyle(fontSize: 13)),
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
                      child: const Text("HỦY"),
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
                          : const Text("CẬP NHẬT"),
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

  String _getStatusText(int status) {
    switch (status) {
      case 1:
        return "Đã nhận";
      case 2:
        return "Đang sửa";
      case 3:
        return "Hoàn thành";
      case 4:
        return "Đã giao";
      default:
        return "Không rõ";
    }
  }

  Widget _warningItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: AppTextStyles.subtitle1.copyWith(
          color: AppColors.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
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
