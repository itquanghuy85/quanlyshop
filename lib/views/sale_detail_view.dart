import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_write_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/money_utils.dart';
import '../widgets/currency_text_field.dart';
import '../widgets/keyboard_aware_padding.dart';
import '../models/sale_order_model.dart';
import '../models/product_model.dart';
import '../data/db_helper.dart';
import '../services/firestore_service.dart';
import '../services/sync_orchestrator.dart';
import '../services/event_bus.dart';
import '../services/user_service.dart';
import '../services/audit_service.dart';
import '../services/unified_printer_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/payment_intent_service.dart';
import '../services/category_service.dart';
import '../services/business_type_helper.dart';
import '../services/customer_service.dart';
import '../services/financial_activity_service.dart';
import '../services/notification_service.dart';
import '../services/debt_summary_service.dart';
import 'customer_debt_view.dart';
import 'collect_customer_debt_view.dart';
import '../models/payment_intent_model.dart';
import '../models/shop_settings_model.dart';
import '../models/printer_types.dart';
import '../constants/financial_constants.dart';
import '../constants/product_constants.dart';
import '../widgets/printer_selection_dialog.dart';
import '../widgets/responsive_wrapper.dart';
import '../widgets/bank_transfer_assist.dart';
import '../theme/app_colors.dart';
import 'sale_invoice_template_view.dart';
import 'sale_invoice_preview_view.dart';
import 'create_sales_return_view.dart';
import '../services/sales_return_service.dart';
import '../models/sales_return_model.dart';
import 'dart:convert';
import '../widgets/clickable_customer_header.dart';
import '../widgets/clickable_product_list.dart';
import '../widgets/deep_link_navigator.dart';
import '../widgets/custom_app_bar.dart';
import '../theme/popup_theme.dart';
import '../widgets/app_popup.dart';
import 'staff_public_profile_view.dart';

class SaleDetailView extends StatefulWidget {
  final SaleOrder sale;
  final bool autoOpenPreview;
  const SaleDetailView({
    super.key,
    required this.sale,
    this.autoOpenPreview = false,
  });

  @override
  State<SaleDetailView> createState() => _SaleDetailViewState();
}

class _SaleDetailViewState extends State<SaleDetailView> {
  final db = DBHelper();
  late SaleOrder s;

  String _shopName = "";
  String _shopAddr = "";
  String _shopPhone = "";
  bool get _isInstallmentNH => s.paymentMethod.toUpperCase() == "TRẢ GÓP (NH)";
  bool _managerUnlocked = false;
  bool _canViewCostPrice = false;
  late List<ProductLinkRef> _linkedProducts;

  // Multi-Industry: Shop Settings
  ShopSettings? _shopSettings;
  BusinessTerminology get _terms =>
      BusinessTypeHelper.instance.getTerminology(_shopSettings);

  int get _totalItemLevelDiscount {
    int total = 0;
    for (final ref in _linkedProducts) {
      if (ref.salePrice != null &&
          ref.soldPrice != null &&
          ref.salePrice! > ref.soldPrice!) {
        total += (ref.salePrice! - ref.soldPrice!) * (ref.soldQty ?? 1);
      }
    }
    return total;
  }

  // Chỉ cho phép sửa giá/vốn trong ngày
  bool get _isSameDay {
    final d = DateTime.fromMillisecondsSinceEpoch(s.soldAt);
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  // Phân bổ lại unitCost trong itemSnapshotsJson theo tỉ lệ
  void _applyNewCostToSnapshots(int newTotalCost) {
    if (s.itemSnapshotsJson == null || s.itemSnapshotsJson!.isEmpty) return;
    try {
      final decoded = jsonDecode(s.itemSnapshotsJson!) as List;
      if (decoded.isEmpty) return;
      final oldTotal = decoded.fold<int>(0, (acc, e) {
        final uc = (e['unitCost'] as num?)?.toInt() ?? 0;
        final q = (e['quantity'] as num?)?.toInt() ?? 1;
        return acc + uc * q;
      });
      if (oldTotal <= 0) {
        // Phân bổ đều khi không có unitCost gốc — chia đều cho tất cả items
        final itemCount = decoded.length;
        if (itemCount <= 0) return;
        final perItem = newTotalCost ~/ itemCount;
        final updated = decoded.map((e) {
          final item = Map<String, dynamic>.from(e as Map);
          final q = (item['quantity'] as num?)?.toInt() ?? 1;
          item['unitCost'] = q > 0 ? perItem ~/ q : 0;
          item['lineCostTotal'] = perItem;
          return item;
        }).toList();
        s.itemSnapshotsJson = jsonEncode(updated);
        return;
      }
      final updated = decoded.map((e) {
        final item = Map<String, dynamic>.from(e as Map);
        final uc = (item['unitCost'] as num?)?.toInt() ?? 0;
        final q = (item['quantity'] as num?)?.toInt() ?? 1;
        final newUc =
            ((uc * q) / oldTotal * newTotalCost).round() ~/ (q > 0 ? q : 1);
        item['unitCost'] = newUc;
        item['lineCostTotal'] = newUc * q;
        return item;
      }).toList();
      s.itemSnapshotsJson = jsonEncode(updated);
    } catch (_) {}
  }

  // Theme colors cho màn hình chi tiết đơn bán hàng
  final Color _accentColor = const Color(0xFF388E3C);
  final Color _backgroundColor = const Color(0xFFF4F6FA);

  // Return info
  List<SalesReturn> _allReturns = [];
  int _totalReturnedAmount = 0;
  bool _allItemsReturned = false;

  @override
  void initState() {
    super.initState();
    s = _normalizeSaleForDisplay(widget.sale);
    _linkedProducts = _buildLinkedProducts();
    _enrichLinkedProducts();
    final shopInfoFuture = _loadShopInfo();
    _loadReturnInfo();
    _loadCostPermission();
    final customerDebtFuture = _loadCustomerDebt();
    if (widget.autoOpenPreview) {
      // Chờ đủ cả 2 nguồn dữ liệu (thông tin shop + công nợ khách real-time)
      // trước khi mở xem trước — tránh mở sớm khi state còn rỗng/loading,
      // dẫn tới biên nhận/QR hiện sai số tiền lúc mới tạo đơn.
      Future.wait([shopInfoFuture, customerDebtFuture]).then((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SaleInvoicePreviewView(saleData: _buildSalePrintData()),
          ),
        );
      });
    }
  }

  // Công nợ khách hàng gộp nhiều đơn: toàn bộ đơn CUSTOMER_OWES còn dư của
  // khách (theo phone) — dùng để tách "nợ đơn này" khỏi "tổng công nợ khách".
  final _debtSummary = DebtSummaryService();
  List<Map<String, dynamic>> _customerActiveDebts = [];
  bool _loadingCustomerDebt = true;

  Future<void> _loadCustomerDebt() async {
    final debts = await _debtSummary.getCustomerActiveDebts(s.phone);
    if (!mounted) return;
    setState(() {
      _customerActiveDebts = debts;
      _loadingCustomerDebt = false;
    });
  }

  Map<String, dynamic>? get _linkedDebtForThisOrder => _customerActiveDebts
      .where((d) => d['linkedId'] == s.firestoreId)
      .firstOrNull;

  int get _orderRemainingDebt =>
      _debtSummary.getOrderRemainingDebt(s, linkedDebt: _linkedDebtForThisOrder);

  int get _otherOrdersDebt => _customerActiveDebts
      .where((d) => d['linkedId'] != s.firestoreId)
      .fold<int>(
        0,
        (sum, d) =>
            sum +
            (((d['totalAmount'] as num?)?.toInt() ?? 0) -
                ((d['paidAmount'] as num?)?.toInt() ?? 0)),
      );

  SaleOrder _normalizeSaleForDisplay(SaleOrder sale) {
    return SaleOrder.fromMap({
      'id': sale.id,
      'firestoreId': sale.firestoreId,
      'customerName': sale.customerName,
      'phone': sale.phone,
      'isWalkIn': sale.isWalkIn,
      'walkInName': sale.walkInName,
      'walkInPhone': sale.walkInPhone,
      'address': sale.address,
      'productNames': sale.productNames,
      'productImeis': sale.productImeis,
      'totalPrice': sale.totalPrice,
      'totalCost': sale.totalCost,
      'discount': sale.discount,
      'paymentMethod': sale.paymentMethod,
      'sellerName': sale.sellerName,
      'sellerUid': sale.sellerUid,
      'soldAt': sale.soldAt,
      'notes': sale.notes,
      'gifts': sale.gifts,
      'warranty': sale.warranty,
      'isInstallment': sale.isInstallment,
      'downPayment': sale.downPayment,
      'downPaymentMethod': sale.downPaymentMethod,
      'loanAmount': sale.loanAmount,
      'installmentTerm': sale.installmentTerm,
      'bankName': sale.bankName,
      'bankName2': sale.bankName2,
      'loanAmount2': sale.loanAmount2,
      'settlementPlannedAt': sale.settlementPlannedAt,
      'settlementReceivedAt': sale.settlementReceivedAt,
      'settlementAmount': sale.settlementAmount,
      'settlementFee': sale.settlementFee,
      'settlementNote': sale.settlementNote,
      'settlementCode': sale.settlementCode,
      'cashAmount': sale.cashAmount,
      'transferAmount': sale.transferAmount,
      'isSynced': sale.isSynced,
      'itemSnapshotsJson': sale.itemSnapshotsJson,
    });
  }

  Future<void> _loadCostPermission() async {
    final perms = await UserService.getCurrentUserPermissions();
    final isSuper = UserService.isCurrentUserSuperAdmin();
    if (!mounted) return;
    setState(() {
      _canViewCostPrice = isSuper || (perms['allowViewCostPrice'] ?? false);
    });
  }

  Future<void> _loadReturnInfo() async {
    try {
      final returns = await SalesReturnService.getReturns();
      final matches = returns
          .where(
            (r) =>
                r.salesOrderFirestoreId == s.firestoreId ||
                r.salesOrderId == s.id,
          )
          .toList();
      final totalReturned = matches.fold<int>(
        0,
        (sum, r) => sum + r.totalReturnAmount,
      );

      // Check if all items are fully returned
      bool allReturned = false;
      if (matches.isNotEmpty && s.id != null && s.id! > 0) {
        final returnedMap = await DBHelper().getReturnedQuantitiesForSale(
          s.id!,
        );
        if (returnedMap.isNotEmpty) {
          // Parse original items and compare
          final names = s.productNames.split(RegExp(r',\s*'));
          final imeis = s.productImeis.split(RegExp(r',\s*'));
          allReturned = true;
          for (int i = 0; i < names.length; i++) {
            final name = names[i].trim();
            if (name.isEmpty) continue;
            final imei = i < imeis.length ? imeis[i].trim() : '';
            int origQty = 1;
            final qtyMatch = RegExp(r'^(.+?)\s+[xX](\d+)').firstMatch(name);
            String cleanName = name;
            if (qtyMatch != null) {
              cleanName = qtyMatch.group(1)!.trim();
              origQty = int.tryParse(qtyMatch.group(2)!) ?? 1;
            }
            if (imei.toUpperCase().startsWith('PKX')) {
              origQty =
                  int.tryParse(imei.toUpperCase().replaceAll('PKX', '')) ?? 1;
            }
            final isPhone =
                imei.isNotEmpty &&
                !imei.toUpperCase().startsWith('PKX') &&
                imei != 'NO_IMEI';
            final key = isPhone ? imei.toUpperCase() : cleanName.toUpperCase();
            final returned = returnedMap[key] ?? 0;
            if (returned < origQty) {
              allReturned = false;
              break;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _allReturns = matches;
          _totalReturnedAmount = totalReturned;
          _allItemsReturned = allReturned;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadShopInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = await CategoryService().getShopSettings();
    if (!mounted) return;
    setState(() {
      _shopSettings = settings;
      _shopName = prefs.getString('shop_name') ?? "TEN SHOP";
      _shopAddr = prefs.getString('shop_address') ?? "DIA CHI";
      _shopPhone = prefs.getString('shop_phone') ?? "SDT";
    });
  }

  String _fmtDate(int ms) => DateFormat(
    'HH:mm dd/MM/yyyy',
  ).format(DateTime.fromMillisecondsSinceEpoch(ms));
  String _fmtShort(int? ms) => ms == null
      ? "---"
      : DateFormat(
          'dd/MM/yyyy',
        ).format(DateTime.fromMillisecondsSinceEpoch(ms));
  String _money(int amount) => MoneyUtils.formatCompactCurrency(amount);

  String? _extractImageFromSnapshot(Map<String, dynamic> item) {
    final imageUrl = (item['imageUrl'] ?? item['image'] ?? '')
        .toString()
        .trim();
    if (imageUrl.isNotEmpty) return imageUrl;
    final rawImages = item['images'];
    if (rawImages is List && rawImages.isNotEmpty) {
      final first = rawImages.first.toString().trim();
      if (first.isNotEmpty) return first;
    }
    if (rawImages is String && rawImages.trim().isNotEmpty) {
      final parts = rawImages
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) return parts.first;
    }
    return null;
  }

  List<ProductLinkRef> _buildLinkedProducts() {
    final items = <ProductLinkRef>[];
    final snapshotRaw = (s.itemSnapshotsJson ?? '').trim();
    if (snapshotRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(snapshotRaw);
        if (decoded is List) {
          for (final raw in decoded) {
            if (raw is! Map) continue;
            final item = Map<String, dynamic>.from(raw);
            final name = ProductConstants.cleanProductName(
              (item['name'] ?? item['productName'] ?? '').toString(),
            ).trim();
            if (name.isEmpty) continue;
            // snapshot keys: imei (legacy) | serial | productImei (create_sale_view)
            final rawImei =
                (item['imei'] ?? item['serial'] ?? item['productImei'] ?? '')
                    .toString()
                    .trim();
            // Filter out placeholder values used for non-phone items
            final isPlaceholderImei =
                rawImei.isEmpty ||
                rawImei.toUpperCase() == 'NO_IMEI' ||
                rawImei.toUpperCase().startsWith('PKX');
            final imei = isPlaceholderImei ? '' : rawImei;
            final sku = (item['sku'] ?? '').toString().trim();
            final productId =
                (item['id'] ??
                        item['productId'] ??
                        item['productFirestoreId'] ??
                        item['firestoreId'] ??
                        '')
                    .toString()
                    .trim();
            final qty = (item['quantity'] as num?)?.toInt();
            // snapshot key: price (legacy) | unitPrice (create_sale_view)
            final price = ((item['price'] ?? item['unitPrice']) as num?)
                ?.toInt();
            final sp = (item['salePrice'] as num?)?.toInt();
            items.add(
              ProductLinkRef(
                productId: productId.isEmpty ? null : productId,
                displayName: name,
                imei: imei.isEmpty ? null : imei,
                serial: imei.isEmpty ? null : imei,
                sku: sku.isEmpty ? null : sku,
                imageUrl: _extractImageFromSnapshot(item),
                sourceEvent: 'product_detail_opened_from_sale',
                soldQty: (qty != null && qty > 0) ? qty : null,
                soldPrice: (price != null && price > 0) ? price : null,
                salePrice: (sp != null && sp > 0) ? sp : null,
                soldImei: imei.isEmpty ? null : imei,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('SaleDetailView _buildLinkedProducts parse error: $e');
      }
    }
    if (items.isNotEmpty) return items;
    final names = s.productNames
        .split(RegExp(r'\s*,\s*'))
        .map((e) => ProductConstants.cleanProductName(e).trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final imeis = s.productImeis
        .split(RegExp(r'\s*,\s*'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    for (var i = 0; i < names.length; i++) {
      final imei = i < imeis.length ? imeis[i] : '';
      final isInventoryMarker =
          imei.toUpperCase().startsWith('PKX') ||
          imei.toUpperCase() == 'NO_IMEI';
      items.add(
        ProductLinkRef(
          displayName: names[i],
          imei: (imei.isEmpty || isInventoryMarker) ? null : imei,
          serial: (imei.isEmpty || isInventoryMarker) ? null : imei,
          sourceEvent: 'product_detail_opened_from_sale',
        ),
      );
    }
    return items;
  }

  Future<void> _enrichLinkedProducts() async {
    bool changed = false;
    final enriched = <ProductLinkRef>[];
    for (final ref in _linkedProducts) {
      if (ref.salePrice != null ||
          ref.soldPrice == null ||
          ref.soldPrice! <= 0) {
        enriched.add(ref);
        continue;
      }
      Product? product;
      try {
        final imei = ref.imei ?? ref.serial ?? '';
        if (imei.isNotEmpty) {
          product = await db.getProductByImei(imei);
        } else if (ref.productId != null && ref.productId!.isNotEmpty) {
          product = await db.getProductByFirestoreId(ref.productId!);
        }
      } catch (_) {}
      if (product != null && product.price > ref.soldPrice!) {
        enriched.add(
          ProductLinkRef(
            productId: ref.productId,
            displayName: ref.displayName,
            imei: ref.imei,
            serial: ref.serial,
            sku: ref.sku,
            imageUrl: ref.imageUrl,
            sourceEvent: ref.sourceEvent,
            soldQty: ref.soldQty,
            soldPrice: ref.soldPrice,
            salePrice: product.price,
            soldImei: ref.soldImei,
          ),
        );
        changed = true;
        continue;
      }
      enriched.add(ref);
    }
    if (changed && mounted) {
      setState(() => _linkedProducts = enriched);
    }
  }

  Future<void> _unlockManager() async {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.needManagerLogin)));
      return;
    }
    final perms = await UserService.getCurrentUserPermissions();
    final isSuper = UserService.isCurrentUserSuperAdmin();
    if (!(perms['allowViewSales'] ?? false) && !isSuper) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.onlyManagerCanEdit)));
      return;
    }

    final passCtrl = TextEditingController();
    if (!mounted) return;

    // Dialog CHỈ đóng khi xác thực THÀNH CÔNG — không pop rồi mới await
    // `reauthenticateWithCredential`. Pop một route đang có TextField mật khẩu
    // giữ focus rồi mới chạy tiếp việc async là đúng kiểu đã gây crash
    // `assert(_dependents.isEmpty)` (framework.dart, `InheritedElement`).
    // Đây là cùng khuôn đã áp cho `order_list_view._confirmDelete` và đã hết
    // crash ở đó. Sai mật khẩu -> báo lỗi NGAY TRONG dialog, dialog vẫn mở để
    // nhập lại (trước đây dialog đóng mất rồi mới hiện SnackBar báo sai).
    String? errorText;
    bool submitting = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogL10n = AppLocalizations.of(ctx)!;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(dialogL10n.managerAuthTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  enabled: !submitting,
                  decoration: InputDecoration(
                    labelText: dialogL10n.managerPasswordLabel,
                    errorText: errorText,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx, false),
                child: Text(dialogL10n.cancel),
              ),
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        setDialogState(() {
                          submitting = true;
                          errorText = null;
                        });
                        final authed = await _reauthenticate(
                          user,
                          passCtrl.text,
                        );
                        if (!ctx.mounted) return;
                        if (authed) {
                          Navigator.pop(ctx, true);
                        } else {
                          setDialogState(() {
                            submitting = false;
                            errorText = AppLocalizations.of(
                              ctx,
                            )!.wrongManagerPassword;
                          });
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(dialogL10n.confirmButton),
              ),
            ],
          ),
        );
      },
    );

    passCtrl.dispose();
    if (ok != true || !mounted) return;

    setState(() => _managerUnlocked = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.editUnlocked)),
    );
  }

  /// Xác thực lại mật khẩu quản lý. Trả về false khi sai mật khẩu / lỗi mạng —
  /// không ném ra ngoài để dialog tự hiện lỗi inline và giữ nguyên trạng thái.
  Future<bool> _reauthenticate(User user, String password) async {
    try {
      final cred = EmailAuthProvider.credential(
        email: user.email ?? '',
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _printWifi() async {
    // Show printer selection dialog
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final printerConfig = await showPrinterSelectionDialog(context);
    if (printerConfig == null) return; // User cancelled

    // Extract printer configuration
    final printerType = printerConfig['type'] as PrinterType?;
    final bluetoothPrinter =
        printerConfig['bluetoothPrinter'] as BluetoothPrinterConfig?;
    final wifiIp = printerConfig['wifiIp'] as String?;

    try {
      final saleData = _buildSalePrintData();

      final success = await UnifiedPrinterService.printSaleReceipt(
        saleData,
        PaperSize.mm58,
        printerType: printerType,
        bluetoothPrinter: bluetoothPrinter,
        wifiIp: wifiIp,
      );

      if (success) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.printInvoiceSuccess)),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.printInvoiceFailed)),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.printErrorMsg(e.toString()))),
      );
    }
  }

  String _resolvePricingTierLabel() {
    final names = s.productNamesDisplay.toUpperCase();
    final hasVip = names.contains('[VIP]');
    final hasWholesale = names.contains('[SỈ]') || names.contains('[SI]');
    if (hasVip && hasWholesale) return 'VIP + SỈ';
    if (hasVip) return 'VIP';
    if (hasWholesale) return 'SỈ';
    return 'THƯỜNG';
  }

  Map<String, dynamic> _buildSalePrintData() {
    final discount = s.discount;
    final finalTotal = s.finalPrice;
    final pricingTierLabel = _resolvePricingTierLabel();
    return {
      'customerName': s.customerName,
      'customerPhone': s.phone,
      'customerAddress': s.address,
      'pricingTierLabel': pricingTierLabel,
      'productNames': s.productNamesDisplay,
      'productImeis': s.productImeis,
      'warranty': s.warranty.isNotEmpty ? s.warranty : 'KO BH',
      'sellerName': s.sellerName,
      'soldAt': s.soldAt,
      'totalPrice': s.totalPrice,
      'discount': discount,
      'finalTotal': finalTotal,
      'firestoreId': s.firestoreId ?? s.id.toString(),
      'shopName': _shopName,
      'shopAddr': _shopAddr,
      'shopPhone': _shopPhone,
      'paymentMethod': s.paymentMethod,
      'isInstallment': s.isInstallment,
      'downPayment': s.downPayment,
      'downPaymentMethod': s.downPaymentMethod,
      'loanAmount': s.loanAmount,
      'loanAmount2': s.loanAmount2,
      'installmentTerm': s.installmentTerm,
      'bankName': s.bankName,
      'bankName2': s.bankName2,
      'remainingDebt': _loadingCustomerDebt ? s.remainingDebt : _orderRemainingDebt,
      'customerTotalDebt':
          _loadingCustomerDebt ? s.remainingDebt : (_otherOrdersDebt + _orderRemainingDebt),
    };
  }

  Future<void> _openSettlementDialog() async {
    final formKey = GlobalKey<FormState>();
    final totalLoan = s.loanAmount + s.loanAmount2;
    final amountCtrl = TextEditingController(
      text: CurrencyTextField.formatDisplay(
        s.settlementAmount > 0 ? s.settlementAmount : totalLoan,
      ),
    );
    final feeCtrl = TextEditingController(
      text: CurrencyTextField.formatDisplay(s.settlementFee),
    );
    final noteCtrl = TextEditingController(text: s.settlementNote ?? "");

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => KeyboardAwarePadding(
        child: Container(
          decoration: const BoxDecoration(
            color: PopupTheme.bgDark,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(PopupTheme.radiusSheet),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PopupDragHandle(),
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance,
                      size: 18,
                      color: PopupTheme.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(ctx)!.receiveBankTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: PopupTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CurrencyTextField(
                  controller: amountCtrl,
                  label: AppLocalizations.of(ctx)!.receivedAmountLabel,
                  validator: (v) => MoneyUtils.validateAmount(
                    v ?? '',
                    min: 1,
                    fieldName: AppLocalizations.of(ctx)!.receivedAmountField,
                  ),
                ),
                const SizedBox(height: 10),
                CurrencyTextField(
                  controller: feeCtrl,
                  label: AppLocalizations.of(ctx)!.bankFeeLabel,
                  validator: (v) => MoneyUtils.validateAmount(
                    v ?? '',
                    min: 0,
                    fieldName: AppLocalizations.of(ctx)!.bankFeeField,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(ctx)!.notesFieldLabel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        PopupTheme.radiusField,
                      ),
                    ),
                  ),
                ),
                bankTransferAssistCard(
                  amountController: amountCtrl,
                  direction: BankPayDirection.inbound,
                  counterpartyName: s.bankName ?? s.customerName,
                  refText: 'Tat toan ${s.customerName}',
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(AppLocalizations.of(ctx)!.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PopupTheme.blue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          if (!(formKey.currentState?.validate() ?? false))
                            return;
                          Navigator.pop(ctx, true);
                        },
                        child: Text(AppLocalizations.of(ctx)!.confirmButton),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (ok != true) {
      amountCtrl.dispose();
      feeCtrl.dispose();
      noteCtrl.dispose();
      return;
    }

    // Không nhân 1000 - user đã nhập số đầy đủ với formatter
    final received = MoneyUtils.parseCurrency(amountCtrl.text);
    final fee = MoneyUtils.parseCurrency(feeCtrl.text);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    setState(() {
      s.settlementAmount = received;
      s.settlementFee = fee;
      s.settlementNote = noteCtrl.text;
      s.settlementReceivedAt = nowMs;
      s.isSynced = false;
    });

    await db.updateSale(s);

    // Sync settlement to Firestore
    if (s.firestoreId != null) {
      await SyncOrchestrator().enqueue(
        entityType: SyncEntityType.sale,
        entityId: s.id!,
        firestoreId: s.firestoreId,
        operation: SyncOperation.update,
        data: s.toMap(),
      );
    }

    EventBus().emit('sales_changed');
    EventBus().emit('products_changed');

    // Tạo PaymentIntent cho khoản thu từ ngân hàng tất toán (status = completed vì đã nhận tiền)
    final user = FirebaseAuth.instance.currentUser;
    final intentId = 'pi_settlement_${s.firestoreId ?? s.id}_$nowMs';
    final settlementIntent = PaymentIntent(
      id: intentId,
      type: PaymentIntentType.saleInstallment,
      status: PaymentIntentStatus.completed,
      amount: received,
      personName: [
        s.bankName,
        if (s.bankName2 != null && s.bankName2!.isNotEmpty) s.bankName2,
      ].whereType<String>().join(' + '),
      personPhone: '',
      description:
          'Ngân hàng ${[s.bankName ?? "", if (s.bankName2 != null && s.bankName2!.isNotEmpty) s.bankName2!].join(" + ")} tất toán - KH: ${s.customerName}',
      referenceType: 'sale',
      referenceId: s.firestoreId ?? 'sale_${s.soldAt}',
      createdBy: user?.uid ?? 'unknown',
      createdAt: nowMs,
      paymentMethod: PaymentMethod.bank,
      paidAt: nowMs,
    );
    await PaymentIntentService.createIntent(settlementIntent);
    debugPrint('💳 Created PaymentIntent for bank settlement: $intentId');

    // Ghi chi phí NH nếu có fee > 0
    if (fee > 0) {
      final feeIntentId = 'pi_bank_fee_${s.firestoreId ?? s.id}_$nowMs';
      final feeIntent = PaymentIntent(
        id: feeIntentId,
        type: PaymentIntentType.operatingExpense,
        status: PaymentIntentStatus.completed,
        amount: fee,
        personName: s.bankName ?? 'NGÂN HÀNG',
        personPhone: '',
        description: 'Phí NH ${s.bankName ?? ""} - KH: ${s.customerName}',
        referenceType: 'sale',
        referenceId: s.firestoreId ?? 'sale_${s.soldAt}',
        createdBy: user?.uid ?? 'unknown',
        createdAt: nowMs,
        paymentMethod: PaymentMethod.bank,
        paidAt: nowMs,
      );
      await PaymentIntentService.createIntent(feeIntent);
      debugPrint('💳 Created PaymentIntent for bank fee: $feeIntentId');
    }

    if (!mounted) return;
    AuditService.logAction(
      action: 'SETTLEMENT_RECEIVED',
      entityType: 'sale',
      entityId: s.firestoreId ?? "sale_${s.soldAt}",
      summary: "Nhận ${MoneyUtils.formatCurrency(received)} đ từ NH",
      payload: {
        'fee': fee,
        'bank': s.bankName,
        if (s.bankName2 != null && s.bankName2!.isNotEmpty)
          'bank2': s.bankName2,
      },
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.bankReceivedConfirmed),
      ),
    );
    amountCtrl.dispose();
    feeCtrl.dispose();
    noteCtrl.dispose();
    setState(() {});
  }

  Future<void> _openEditSaleDialog() async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: s.customerName);
    final phone = TextEditingController(text: s.phone);
    final address = TextEditingController(text: s.address);
    final products = TextEditingController(text: s.productNamesDisplay);
    final imeis = TextEditingController(text: s.productImeis);
    final notes = TextEditingController(text: s.notes ?? "");
    final warranties = ["KO BH", "1 THÁNG", "3 THÁNG", "6 THÁNG", "12 THÁNG"];
    String warranty = s.warranty.isNotEmpty ? s.warranty : "KO BH";
    String payment = s.paymentMethod;
    final oldPaymentMethod = s.paymentMethod; // Lưu lại để so sánh

    // Giá bán + giá vốn — chỉ cho sửa trong ngày
    final canEditMoney = _isSameDay;
    final totalPriceCtrl = TextEditingController(
      text: CurrencyTextField.formatDisplay(s.totalPrice),
    );
    final discountCtrl = TextEditingController(
      text: CurrencyTextField.formatDisplay(s.discount),
    );
    final totalCostCtrl = TextEditingController(
      text: CurrencyTextField.formatDisplay(s.totalCost),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogL10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dialogL10n.editSaleTitle),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: dialogL10n.customerNameFieldLabel,
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? dialogL10n.enterCustomerNameHint
                        : null,
                  ),
                  TextFormField(
                    controller: phone,
                    decoration: InputDecoration(
                      labelText: dialogL10n.phoneFieldLabel,
                    ),
                  ),
                  TextFormField(
                    controller: address,
                    decoration: InputDecoration(
                      labelText: dialogL10n.addressFieldLabel,
                    ),
                  ),
                  TextFormField(
                    controller: products,
                    decoration: InputDecoration(labelText: _terms.productLabel),
                  ),
                  TextFormField(
                    controller: imeis,
                    decoration: InputDecoration(
                      labelText: _terms.specialField1Label,
                    ),
                  ),
                  // Giá bán + giá vốn — chỉ mở trong ngày, khóa qua ngày
                  const SizedBox(height: 8),
                  if (canEditMoney) ...[
                    CurrencyTextField(
                      controller: totalPriceCtrl,
                      label: 'Giá bán',
                      validator: (v) => MoneyUtils.validateAmount(
                        v ?? '',
                        min: 1,
                        fieldName: 'Giá bán',
                      ),
                    ),
                    const SizedBox(height: 8),
                    CurrencyTextField(
                      controller: discountCtrl,
                      label: 'Giảm giá',
                    ),
                    if (_canViewCostPrice) ...[
                      const SizedBox(height: 8),
                      CurrencyTextField(
                        controller: totalCostCtrl,
                        label: 'Giá vốn tổng',
                      ),
                    ],
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Giá bán/vốn chỉ sửa được trong ngày',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: warranty,
                    decoration: InputDecoration(
                      labelText: _terms.specialField2Label,
                    ),
                    items: warranties
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => warranty = v ?? warranty,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: payment,
                    decoration: InputDecoration(
                      labelText: dialogL10n.paymentMethodFieldLabel,
                    ),
                    items:
                        const [
                              "TIỀN MẶT",
                              "CHUYỂN KHOẢN",
                              "KẾT HỢP",
                              "CÔNG NỢ",
                              "TRẢ GÓP (NH)",
                            ]
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                    onChanged: (v) => payment = v ?? payment,
                  ),
                  TextField(
                    controller: notes,
                    decoration: InputDecoration(
                      labelText: dialogL10n.notesFieldLabel,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(dialogL10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(ctx, true);
              },
              child: Text(dialogL10n.saveLabel),
            ),
          ],
        );
      },
    );

    if (ok != true) {
      name.dispose();
      phone.dispose();
      address.dispose();
      products.dispose();
      imeis.dispose();
      notes.dispose();
      totalPriceCtrl.dispose();
      discountCtrl.dispose();
      totalCostCtrl.dispose();
      return;
    }

    // Đọc giá mới trước setState để so sánh
    final newTotalPrice = canEditMoney
        ? CurrencyTextField.parseValue(totalPriceCtrl.text)
        : s.totalPrice;
    final newDiscount = canEditMoney
        ? CurrencyTextField.parseValue(discountCtrl.text)
        : s.discount;
    final newTotalCost = (canEditMoney && _canViewCostPrice)
        ? CurrencyTextField.parseValue(totalCostCtrl.text)
        : s.totalCost;

    // Đơn CÔNG NỢ phải có thành tiền > 0 — nếu không, công nợ liên kết sẽ bị
    // ghi `totalAmount = 0` và khoản khách nợ "tàng hình" ở Nợ phải thu.
    final newFinalPrice = (newTotalPrice - newDiscount) > 0
        ? (newTotalPrice - newDiscount)
        : 0;
    if (payment == 'CÔNG NỢ' && newFinalPrice <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đơn công nợ phải có thành tiền lớn hơn 0 (kiểm tra lại giảm giá)',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      name.dispose();
      phone.dispose();
      address.dispose();
      products.dispose();
      imeis.dispose();
      notes.dispose();
      totalPriceCtrl.dispose();
      discountCtrl.dispose();
      totalCostCtrl.dispose();
      return;
    }

    // Cập nhật unitCost trong snapshots nếu giá vốn thay đổi
    if (newTotalCost != s.totalCost) _applyNewCostToSnapshots(newTotalCost);

    setState(() {
      s.customerName = name.text.trim().toUpperCase();
      s.phone = phone.text.trim();
      s.address = address.text.trim().toUpperCase();
      s.productNames = ProductConstants.cleanCompositeProductNames(
        products.text.trim().toUpperCase(),
      );
      s.productImeis = imeis.text.trim().toUpperCase();
      if (canEditMoney) {
        s.totalPrice = newTotalPrice;
        s.discount = newDiscount;
        s.totalCost = newTotalCost;
      }
      s.warranty = warranty;
      s.paymentMethod = payment;
      if (payment != 'TRẢ GÓP (NH)') {
        s.isInstallment = false;
        s.settlementPlannedAt = null;
        s.settlementReceivedAt = null;
        s.settlementAmount = 0;
        s.settlementFee = 0;
        s.settlementNote = null;
        s.settlementCode = null;
      }
      s.notes = notes.text;
      s.isSynced = false;
    });

    await db.updateSale(s);

    // FIX: Sync sale lên Firestore sau khi update
    if (s.firestoreId != null && s.id != null) {
      await SyncOrchestrator().enqueue(
        entityType: SyncEntityType.sale,
        entityId: s.id!,
        firestoreId: s.firestoreId,
        operation: SyncOperation.update,
        data: s.toMap(),
      );
    }

    // Update debt if payment method is debt
    // FIX: Sử dụng finalPrice (đã trừ discount) thay vì totalPrice
    final debtAmount = s.finalPrice;

    if (s.paymentMethod == 'CÔNG NỢ') {
      final linkedDebt = (await db.getDebtsByLinkedId(
        s.firestoreId ?? '',
      )).firstOrNull;
      if (linkedDebt != null) {
        // Update existing debt.
        // Chỉ ghi đè totalAmount khi > 0 — không bao giờ hạ 1 công nợ thật về 0
        // (self-heal: mở/lưu lại đơn CÔNG NỢ cũ sẽ tự khớp totalAmount về
        // finalPrice hiện tại, kể cả khi khóa sửa tiền qua ngày).
        if (debtAmount > 0) {
          linkedDebt['totalAmount'] = debtAmount;
          linkedDebt['status'] =
              (debtAmount - ((linkedDebt['paidAmount'] as int?) ?? 0)) > 0
              ? 'UNPAID'
              : 'PAID';
        }
        linkedDebt['personName'] = s.customerName; // Cập nhật tên khách
        linkedDebt['phone'] = s.phone; // Cập nhật SĐT
        linkedDebt['isSynced'] = 0;
        await db.updateDebt(linkedDebt);

        // Queue sync debt to cloud via SyncOrchestrator
        final debtId = linkedDebt['id'] as int?;
        if (debtId != null) {
          await SyncOrchestrator().enqueue(
            entityType: SyncEntityType.debt,
            entityId: debtId,
            firestoreId: linkedDebt['firestoreId'] as String?,
            operation: SyncOperation.update,
            data: linkedDebt,
          );
        }
        EventBus().emit('debts_changed');
      } else {
        // Create new debt (khi đổi từ hình thức khác sang CÔNG NỢ)
        final debtFId = "debt_${s.soldAt}_${s.phone}";
        final shopId = await UserService.getCurrentShopId() ?? '';
        final newDebt = {
          'firestoreId': debtFId,
          'personName': s.customerName,
          'phone': s.phone,
          'totalAmount': debtAmount,
          'paidAmount': 0,
          'status': 'ACTIVE',
          'createdAt': s.soldAt,
          'note': 'Đơn bán ${s.firestoreId}',
          'linkedId': s.firestoreId,
          'type': 'CUSTOMER_OWES',
          'shopId': shopId,
          'deleted': 0,
          'isSynced': 0,
        };
        final debtId = await db.insertDebt(newDebt);

        // Queue sync debt to cloud via SyncOrchestrator
        await SyncOrchestrator().enqueue(
          entityType: SyncEntityType.debt,
          entityId: debtId,
          firestoreId: debtFId,
          operation: SyncOperation.create,
          data: newDebt,
        );

        // Công nợ đã ghi nhận ở bảng debts - không cần PaymentIntent
        debugPrint('✅ Sale debt recorded: $debtFId');

        EventBus().emit('debts_changed');
      }
    } else if (oldPaymentMethod == 'CÔNG NỢ' && payment != 'CÔNG NỢ') {
      // FIX: Chỉ đánh dấu PAID khi đổi TỪ CÔNG NỢ sang hình thức khác
      final linkedDebt = (await db.getDebtsByLinkedId(
        s.firestoreId ?? '',
      )).firstOrNull;
      if (linkedDebt != null) {
        linkedDebt['status'] = 'PAID';
        linkedDebt['paidAmount'] = linkedDebt['totalAmount'];
        linkedDebt['isSynced'] = 0;
        await db.updateDebt(linkedDebt);

        // Queue sync debt to cloud via SyncOrchestrator
        final debtId = linkedDebt['id'] as int?;
        if (debtId != null) {
          await SyncOrchestrator().enqueue(
            entityType: SyncEntityType.debt,
            entityId: debtId,
            firestoreId: linkedDebt['firestoreId'] as String?,
            operation: SyncOperation.update,
            data: linkedDebt,
          );
        }
        EventBus().emit('debts_changed');
      }
    }

    // Emit event và thông báo
    EventBus().emit('sales_changed');
    EventBus().emit('products_changed');
    name.dispose();
    phone.dispose();
    address.dispose();
    products.dispose();
    imeis.dispose();
    notes.dispose();
    totalPriceCtrl.dispose();
    discountCtrl.dispose();
    totalCostCtrl.dispose();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.saleUpdated),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Sửa giá vốn cho đơn cũ bị mất cost=0 do bug sync
  // Không bị giới hạn _isSameDay vì đây là fix dữ liệu lịch sử
  Future<void> _showFixCostDialog() async {
    final costCtrl = TextEditingController();
    String? errorMsg;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.attach_money_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Sửa giá vốn'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hiện giá bán để tham chiếu
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Text(
                      'Giá bán: ',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${MoneyUtils.formatCurrency(s.totalPrice)}đ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              CurrencyTextField(
                controller: costCtrl,
                label: 'Giá vốn thực tế',
                icon: Icons.monetization_on,
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 6),
                Text(
                  errorMsg!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Thao tác này cập nhật giá vốn vào báo cáo lợi nhuận lịch sử. Không thể hoàn tác.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                CurrencyTextField.finalizeAll();
                final v = CurrencyTextField.parseValue(costCtrl.text);
                if (v <= 0) {
                  setS(() => errorMsg = 'Nhập giá vốn lớn hơn 0');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Lưu', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) {
      costCtrl.dispose();
      return;
    }

    final newCost = CurrencyTextField.parseValue(costCtrl.text);
    costCtrl.dispose();

    // Phân bổ lại unitCost trong itemSnapshotsJson theo tỉ lệ
    _applyNewCostToSnapshots(newCost);

    setState(() {
      s.totalCost = newCost;
      s.isSynced = false;
    });

    await db.updateSale(s);

    if (s.firestoreId != null && s.id != null) {
      await SyncOrchestrator().enqueue(
        entityType: SyncEntityType.sale,
        entityId: s.id!,
        firestoreId: s.firestoreId,
        operation: SyncOperation.update,
        data: s.toMap(),
      );
    }

    EventBus().emit('sales_changed');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật giá vốn'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteSale() async {
    if (s.id == null) return;

    // === BƯỚC 1: XÁC NHẬN TRƯỚC KHI XÓA ===
    final saleRef = s.firestoreId ?? 'sale_${s.soldAt}';
    final finalPrice = s.finalPrice;
    final hasDebt =
        s.paymentMethod == 'CÔNG NỢ' ||
        (s.paymentMethod == 'TRẢ GÓP (NH)' && s.remainingDebt > 0);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogL10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.delete_forever, color: AppColors.error, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  dialogL10n.deleteSaleTitle,
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dialogL10n.saleOrderItem(s.productNamesDisplay),
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                dialogL10n.saleOrderValue(
                  NumberFormat('#,###', 'vi').format(finalPrice),
                ),
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dialogL10n.systemWillAutoLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _infoRow(Icons.inventory, dialogL10n.restoreStockQty),
                    if (hasDebt)
                      _infoRow(
                        Icons.account_balance_wallet,
                        dialogL10n.deleteLinkedDebt,
                      ),
                    _infoRow(
                      Icons.receipt_long,
                      dialogL10n.deletePaymentRecord,
                    ),
                    _infoRow(Icons.person, dialogL10n.updateCustomerSpend),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                dialogL10n.cannotUndoWarning,
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(dialogL10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(dialogL10n.deleteSaleButton),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    // === BƯỚC 2: THỰC HIỆN XÓA (sau khi user xác nhận) ===
    try {
      int restoredCount = 0;
      int debtDeleted = 0;
      int intentDeleted = 0;

      // D-3b: phần tiền THỰC SỰ đã thu — tính TRƯỚC khi soft-delete
      // debt_payments ở bước 2B. SALE_VOID phải đảo đúng phần này, không phải
      // finalPrice (đơn CÔNG NỢ thu 1 phần → nếu ghi cả finalPrice, sổ đối
      // soát dư một khoản OUT ảo).
      final saleReceived = await FinancialActivityService.saleCashReceived(s);

      // 2A: Khôi phục inventory
      final imeis = s.productImeis.split(RegExp(r'\s*,\s*'));
      final names = s.productNames.split(RegExp(r'\s*,\s*'));
      for (int i = 0; i < imeis.length; i++) {
        final imei = imeis[i].trim();
        if (imei.isEmpty) continue;

        Product? product;
        int qtyToRestore = 1;

        if (imei.toUpperCase().startsWith("PKX") || imei == "NO_IMEI") {
          // Phụ kiện (PKxN) hoặc sản phẩm không có IMEI → tìm theo tên
          if (imei.toUpperCase().startsWith("PKX")) {
            qtyToRestore =
                int.tryParse(imei.toUpperCase().replaceAll('PKX', '')) ?? 1;
          }
          // Tách tên sản phẩm từ productNames (bỏ " xN"/" XN", "(Tặng)", "(Giảm ...)")
          if (i < names.length) {
            final nameEntry = names[i].trim();
            // Regex case-insensitive: match "Tên SP x2" hoặc "Tên SP X2"
            final nameMatch = RegExp(r'^(.+?)\s+[xX]\d+').firstMatch(nameEntry);
            var productName = nameMatch != null
                ? nameMatch.group(1)!.trim()
                : nameEntry;
            // Bỏ hậu tố (TẶNG) hoặc (GIẢM ...) nếu còn dính
            productName = productName.replaceAll(
              RegExp(r'\s*\(TẶNG\)\s*$', caseSensitive: false),
              '',
            );
            productName = productName.replaceAll(
              RegExp(r'\s*\(GIẢM\s+[\d,.]+\)\s*$', caseSensitive: false),
              '',
            );
            productName = productName.trim();
            debugPrint(
              '🔍 Tìm sản phẩm theo tên: "$productName" (từ: "$nameEntry")',
            );
            product = await db.getProductByName(productName);
            if (product == null) {
              debugPrint('⚠️ Không tìm thấy sản phẩm theo tên: $productName');
            }
          }
        } else {
          // Điện thoại có IMEI → tìm theo IMEI
          product = await db.getProductByImei(imei);
        }

        if (product != null) {
          await db.addProductQuantity(product.id!, qtyToRestore);
          product.quantity += qtyToRestore;
          if (product.status == 0 && product.quantity > 0) {
            product.status = 1;
            await db.updateProductStatus(product.id!, 1);
          }
          // Sync trực tiếp lên cloud (tránh real-time listener ghi đè)
          if (product.firestoreId != null && product.firestoreId!.isNotEmpty) {
            try {
              await FirebaseFirestore.instance
                  .collection('products')
                  .doc(product.firestoreId)
                  .update({
                    'quantity': product.quantity,
                    'status': product.status,
                    'updatedAt': FirestoreWriteHelper.serverUpdatedAt(),
                  });
              debugPrint(
                '☁️ Synced product quantity to cloud: ${product.firestoreId}',
              );
            } catch (e) {
              debugPrint('⚠️ Cloud sync failed, queueing: $e');
              await SyncOrchestrator().enqueue(
                entityType: SyncEntityType.product,
                entityId: product.id!,
                firestoreId: product.firestoreId,
                operation: SyncOperation.update,
                data: product.toMap(),
              );
            }
          }
          restoredCount += qtyToRestore;
          debugPrint(
            '✅ Khôi phục kho: ${product.name} +$qtyToRestore (tổng: ${product.quantity})',
          );
        }
      }

      // 2B: Xóa công nợ liên quan + các phiếu thu/trả nợ đã ghi cho công nợ đó
      if (s.firestoreId != null) {
        final linkedDebts = await db.getDebtsByLinkedId(s.firestoreId ?? '');
        for (final debt in linkedDebts) {
          final debtFId = debt['firestoreId'] as String?;
          if (debtFId != null) {
            // Soft-delete các debt_payments TRƯỚC khi xóa debt — nếu bỏ sót,
            // phiếu thu nợ mồ côi vẫn được analyze()/FinanceV2 tính là "tiền
            // vào" vĩnh viễn (dialog đã hứa "Xóa phiếu thanh toán").
            final linkedPayments =
                await db.getDebtPaymentsByDebtFirestoreId(debtFId);
            await db.softDeleteDebtPaymentsByDebtFirestoreId(debtFId);
            for (final p in linkedPayments) {
              final pId = p['id'] as int?;
              final pFid = p['firestoreId'] as String?;
              if (pId != null) {
                await SyncOrchestrator().enqueue(
                  entityType: SyncEntityType.debtPayment,
                  entityId: pId,
                  firestoreId: pFid,
                  operation: SyncOperation.delete,
                  data: {...p, 'deleted': true},
                );
              }
            }

            await db.deleteDebtByFirestoreId(debtFId);
            await SyncOrchestrator().enqueue(
              entityType: SyncEntityType.debt,
              entityId: debt['id'] as int,
              firestoreId: debtFId,
              operation: SyncOperation.delete,
              data: {...debt, 'deleted': true},
            );
          }
          debtDeleted++;
        }
      }

      // 2C: Xóa PaymentIntents liên quan
      try {
        intentDeleted = await db.deletePaymentIntentsByReferenceId(saleRef);
        debugPrint(
          '🗑️ Deleted $intentDeleted payment intents for sale $saleRef',
        );
      } catch (e) {
        debugPrint('⚠️ Failed to delete payment intents: $e');
      }

      // 2D: Cập nhật lại chi tiêu khách hàng (trừ đi)
      try {
        final phone = s.walkInPhone ?? s.phone;
        if (phone.isNotEmpty) {
          final customerService = CustomerService();
          final customer = await customerService.getCustomerByPhone(phone);
          if (customer != null && finalPrice > 0) {
            final newTotal = (customer.totalSpent - finalPrice)
                .clamp(0, double.maxFinite)
                .toInt();
            final updated = customer.copyWith(totalSpent: newTotal);
            await customerService.updateCustomer(updated);
            debugPrint(
              '📊 Reverted customer totalSpent: ${customer.totalSpent} → $newTotal',
            );
          }
        }
      } catch (e) {
        debugPrint('⚠️ Failed to revert customer stats: $e');
      }

      // 2E: Log financial reversal — SỐ TIỀN = phần đã thu thật (D-3b), không
      // phải finalPrice. Đơn chưa thu đồng nào → không ghi bút toán (tránh OUT ảo).
      if (saleReceived > 0) {
        try {
          await FinancialActivityService.logCustomActivity(
            activityType: 'SALE_VOID',
            amount: saleReceived,
            direction: 'OUT',
            paymentMethod: s.paymentMethod,
            title: 'HỦY ĐƠN BÁN',
            description:
                'Hủy đơn: ${s.productNamesDisplay}. KH: ${s.customerName}. '
                'Đã thu $saleReceived đ'
                '${saleReceived != finalPrice ? ' / giá đơn $finalPrice đ' : ''}.',
            customerName: s.customerName,
            phone: s.walkInPhone ?? s.phone,
            productInfo: s.productNamesDisplay,
            referenceType: 'sale',
            referenceId: s.firestoreId,
          );
        } catch (e) {
          debugPrint('⚠️ Failed to log financial reversal: $e');
        }
      }

      // 2F: Soft-delete trên cloud TRƯỚC (tránh real-time sync tải lại sale)
      if (s.firestoreId != null) {
        try {
          await FirestoreService.deleteSale(s.firestoreId!);
          debugPrint('✅ Cloud soft-delete sale: ${s.firestoreId}');
        } catch (e) {
          debugPrint('⚠️ Cloud soft-delete failed, queuing: $e');
          // Fallback: queue delete nếu cloud gọi trực tiếp lỗi
          await SyncOrchestrator().enqueue(
            entityType: SyncEntityType.sale,
            entityId: s.id!,
            firestoreId: s.firestoreId,
            operation: SyncOperation.delete,
            data: {'firestoreId': s.firestoreId},
          );
        }
      }

      // 2G: Xóa sale khỏi local DB (sau khi cloud đã soft-delete)
      await db.deleteSale(s.id!);

      // 2H: Audit log
      AuditService.logAction(
        action: 'DELETE_SALE',
        entityType: 'sale',
        entityId: saleRef,
        summary: '${s.customerName} - ${s.productNamesDisplay}',
        payload: {
          'totalPrice': s.totalPrice,
          'finalPrice': finalPrice,
          'inventoryRestored': restoredCount,
          'debtsDeleted': debtDeleted,
          'intentsDeleted': intentDeleted,
          'paymentMethod': s.paymentMethod,
        },
      );

      // 2I: Thông báo thành công
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        NotificationService.showSnackBar(
          l10n.saleDeletedMsg(
            restoredCount > 0 ? ' • Kho +$restoredCount' : '',
            debtDeleted > 0 ? ' • Xóa $debtDeleted nợ' : '',
          ),
          color: Colors.green,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Lỗi xóa đơn bán: $e');
      if (mounted) {
        NotificationService.showSnackBar(
          AppLocalizations.of(context)!.saleDeleteError(e.toString()),
          color: Colors.red,
        );
      }
    }
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.blue.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: CustomAppBar.build(
        title: AppLocalizations.of(context)!.saleDetailTitle,
        subtitle: s.customerName,
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            tooltip: 'Chia sẻ nhanh cho khách',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SaleInvoicePreviewView(
                    saleData: _buildSalePrintData(),
                    paper: PaperSize.mm58,
                    autoShare: true,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.preview_rounded, color: Colors.white),
            tooltip: 'Xem trước biên nhận',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SaleInvoicePreviewView(
                    saleData: _buildSalePrintData(),
                    paper: PaperSize.mm58,
                  ),
                ),
              );
            },
          ),
          // Không còn nhánh spinner trên AppBar: việc xác thực quản lý giờ
          // chạy BÊN TRONG dialog và dialog tự hiện vòng quay ở nút Xác nhận.
            Builder(
              builder: (ctx) {
                final l10n = AppLocalizations.of(ctx)!;
                return PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white,
                  ),
                  onSelected: (value) async {
                    switch (value) {
                      case 'sms':
                        _sendSmsToCustomer();
                      case 'chat':
                        _sendToChat();
                      case 'print':
                        _printWifi();
                      case 'template':
                        if (!mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SaleInvoiceTemplateView(),
                          ),
                        );
                      case 'return':
                        _openReturnView();
                      case 'edit':
                        if (!_managerUnlocked) await _unlockManager();
                        await Future.delayed(Duration.zero);
                        if (_managerUnlocked && mounted) _openEditSaleDialog();
                      case 'fix_cost':
                        if (!_managerUnlocked) await _unlockManager();
                        await Future.delayed(Duration.zero);
                        if (_managerUnlocked && mounted) _showFixCostDialog();
                      case 'delete':
                        if (!_managerUnlocked) await _unlockManager();
                        await Future.delayed(Duration.zero);
                        if (_managerUnlocked && mounted) _deleteSale();
                    }
                  },
                  itemBuilder: (_) => [
                    _menuItem('sms', Icons.sms_rounded, 'SMS'),
                    _menuItem(
                      'chat',
                      Icons.chat_bubble_outline_rounded,
                      'Chat',
                    ),
                    const PopupMenuDivider(),
                    _menuItem(
                      'print',
                      Icons.print_rounded,
                      l10n.printInvoiceLabel,
                    ),
                    _menuItem(
                      'template',
                      Icons.design_services_rounded,
                      l10n.printTemplateLabel,
                    ),
                    const PopupMenuDivider(),
                    _menuItem(
                      'return',
                      Icons.assignment_return_rounded,
                      _allItemsReturned
                          ? l10n.returnAllLabel
                          : l10n.returnGoodsLabel,
                      enabled: !_allItemsReturned,
                      color: _allItemsReturned
                          ? Colors.grey
                          : Colors.orange.shade700,
                    ),
                    const PopupMenuDivider(),
                    if (_canViewCostPrice &&
                        s.totalCost == 0 &&
                        s.totalPrice > 0) ...[
                      _menuItem(
                        'fix_cost',
                        _managerUnlocked
                            ? Icons.attach_money_rounded
                            : Icons.lock_outline_rounded,
                        'Sửa giá vốn (0đ)',
                        color: Colors.orange.shade700,
                      ),
                      const PopupMenuDivider(),
                    ],
                    _menuItem(
                      'edit',
                      _managerUnlocked
                          ? Icons.edit_note_rounded
                          : Icons.lock_outline_rounded,
                      l10n.editSaleTooltip,
                    ),
                    _menuItem(
                      'delete',
                      Icons.delete_forever_rounded,
                      'Xóa đơn',
                      color: Colors.red,
                    ),
                  ],
                );
              },
            ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 800,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_isInstallmentNH &&
                  (s.settlementReceivedAt == null ||
                      s.settlementAmount < s.loanAmount + s.loanAmount2))
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openSettlementDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: Text(
                      s.settlementReceivedAt != null
                          ? AppLocalizations.of(context)!.updateSettlementBtn(
                              _money(
                                s.loanAmount +
                                    s.loanAmount2 -
                                    s.settlementAmount,
                              ),
                            )
                          : AppLocalizations.of(context)!.receiveBankTitle,
                    ),
                  ),
                ),
              if (_isInstallmentNH) const SizedBox(height: 10),

              // Return indicator
              if (_allReturns.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _allItemsReturned
                        ? Colors.grey.shade100
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _allItemsReturned
                          ? Colors.grey.shade400
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.assignment_return,
                        color: _allItemsReturned
                            ? Colors.grey.shade700
                            : Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _allItemsReturned
                                  ? AppLocalizations.of(
                                      context,
                                    )!.returnedFullLabel(
                                      _money(_totalReturnedAmount),
                                    )
                                  : AppLocalizations.of(
                                      context,
                                    )!.returnedPartialLabel(
                                      _money(_totalReturnedAmount),
                                      _allReturns.length,
                                    ),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _allItemsReturned
                                    ? Colors.grey.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                            ..._allReturns.map(
                              (r) => Text(
                                '${r.refundMethod} • ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(r.returnDate))} • ${_money(r.totalReturnAmount)}${r.note != null && r.note!.isNotEmpty ? ' • ${r.note}' : ''}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _allItemsReturned
                                      ? Colors.grey.shade600
                                      : Colors.red.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (!_loadingCustomerDebt && _orderRemainingDebt > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CÒN NỢ ĐƠN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              _money(_orderRemainingDebt),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final changed = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CollectCustomerDebtView(
                                phone: s.phone,
                                personName: s.customerName,
                              ),
                            ),
                          );
                          if (changed == true) _loadCustomerDebt();
                        },
                        style: ElevatedButton.styleFrom(
                          // Ghi đè minimumSize mặc định toàn app (double.infinity
                          // width — AppButtonStyles.elevatedButtonStyle) vì nút
                          // này nằm trong Row cạnh 1 Expanded khác. Nếu không
                          // ghi đè, RenderFlex đo nút này với minWidth=infinity
                          // ở bước layout children không-flex (unbounded), làm
                          // hỏng toàn bộ layout của Row/Container cha (Container
                          // phình to bất thường, nội dung không hiện) — đã tái
                          // hiện + xác nhận nguyên nhân trên thiết bị thật.
                          minimumSize: Size.zero,
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.payments_outlined, size: 18),
                        label: const Text('THU TIỀN'),
                      ),
                    ],
                  ),
                ),

              _card(AppLocalizations.of(context)!.sectionTransaction, [
                ClickableCustomerHeader(
                  customerName: s.customerName,
                  phoneNumber: s.phone,
                  sourceEvent: 'customer_profile_opened_from_sale',
                ),
                if (!_loadingCustomerDebt) _buildCustomerDebtCard(),
                _item(
                  AppLocalizations.of(context)!.itemAddress,
                  s.address.isEmpty ? "---" : s.address,
                ),
                if (_linkedProducts.isEmpty &&
                    (s.notes?.startsWith('KV:') ?? false))
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Text(
                      'Hóa đơn KiotViet — không có chi tiết sản phẩm (nhập lại với "Ghi đè" để lấy dữ liệu)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  ClickableProductList(
                    items: _linkedProducts,
                    tooltip: AppLocalizations.of(
                      context,
                    )!.openProductDetailTooltip,
                  ),
                _item(
                  AppLocalizations.of(context)!.itemWarranty,
                  s.warranty.isNotEmpty ? s.warranty : "KO BH",
                ),
                _staffItem(s.sellerName, s.sellerUid),
                _item(
                  AppLocalizations.of(context)!.itemTime,
                  _fmtDate(s.soldAt),
                ),
                _item(
                  AppLocalizations.of(context)!.itemPaymentMethod,
                  s.paymentMethod,
                ),
                // Hiển thị chi tiết kết hợp thanh toán
                if (s.paymentMethod.toUpperCase() == 'KẾT HỢP' &&
                    (s.cashAmount > 0 || s.transferAmount > 0)) ...[
                  _item(
                    AppLocalizations.of(context)!.itemCash,
                    _money(s.cashAmount),
                    color: Colors.green,
                  ),
                  _item(
                    AppLocalizations.of(context)!.itemTransfer,
                    _money(s.transferAmount),
                    color: Colors.blue,
                  ),
                ],
                if (s.notes != null && s.notes!.isNotEmpty)
                  _item(AppLocalizations.of(context)!.itemNotes, s.notes!),
                Builder(
                  builder: (ctx) {
                    final itemDisc = _totalItemLevelDiscount;
                    final orderDisc = s.discount;
                    final totalDisc = itemDisc + orderDisc;
                    if (totalDisc <= 0) return const SizedBox.shrink();
                    final hasBoth = itemDisc > 0 && orderDisc > 0;
                    return Column(
                      children: [
                        if (hasBoth) ...[
                          _item(
                            'Giảm sản phẩm',
                            '-${_money(itemDisc)}',
                            color: Colors.orange,
                          ),
                          _item(
                            'Giảm đơn',
                            '-${_money(orderDisc)}',
                            color: Colors.orange,
                          ),
                        ],
                        _item(
                          'Tổng giảm giá',
                          '-${_money(totalDisc)}',
                          color: Colors.deepOrange,
                        ),
                      ],
                    );
                  },
                ),
                _item(
                  AppLocalizations.of(context)!.itemTotal,
                  _money(s.finalPrice),
                  color: Colors.red,
                ),
                if (!_loadingCustomerDebt)
                  _item(
                    'Tổng đã thu',
                    _money((s.finalPrice - _orderRemainingDebt).clamp(0, s.finalPrice)),
                    color: Colors.green.shade700,
                  ),
                if (_canViewCostPrice && s.totalCost > 0) ...[
                  _item(
                    AppLocalizations.of(context)!.itemCostPrice,
                    _money(s.totalCost),
                    color: Colors.orange.shade700,
                  ),
                  _item(
                    AppLocalizations.of(context)!.itemProfit,
                    '${s.finalPrice - s.totalCost >= 0 ? '+' : ''}${_money(s.finalPrice - s.totalCost)}',
                    color: s.finalPrice - s.totalCost >= 0
                        ? Colors.green.shade700
                        : Colors.red,
                  ),
                ],
              ]),
              if (_isInstallmentNH)
                _card(AppLocalizations.of(context)!.sectionInstallment, [
                  _item(
                    AppLocalizations.of(context)!.installmentDownPayment,
                    _money(s.downPayment),
                  ),
                  _item(
                    AppLocalizations.of(context)!.installmentBank1,
                    s.bankName ?? "---",
                  ),
                  _item(
                    AppLocalizations.of(context)!.installmentAmount1,
                    _money(s.loanAmount),
                  ),
                  if (s.bankName2 != null && s.bankName2!.isNotEmpty) ...[
                    _item(
                      AppLocalizations.of(context)!.installmentBank2,
                      s.bankName2!,
                    ),
                    _item(
                      AppLocalizations.of(context)!.installmentAmount2,
                      _money(s.loanAmount2),
                    ),
                  ],
                  _item(
                    AppLocalizations.of(context)!.installmentTotalLoan,
                    _money(s.loanAmount + s.loanAmount2),
                  ),
                  _item(
                    AppLocalizations.of(context)!.installmentExpectedDate,
                    _fmtShort(s.settlementPlannedAt),
                  ),
                  _item(
                    AppLocalizations.of(context)!.installmentFileCode,
                    s.settlementCode ?? "---",
                  ),
                  _item(
                    AppLocalizations.of(context)!.installmentNotes,
                    s.settlementNote ?? "---",
                  ),
                  _item(
                    AppLocalizations.of(context)!.installmentSettlement,
                    s.settlementReceivedAt == null
                        ? AppLocalizations.of(context)!.settlementNotReceived
                        : s.settlementAmount >= s.loanAmount + s.loanAmount2
                        ? AppLocalizations.of(context)!.settlementFullyReceived(
                            _fmtShort(s.settlementReceivedAt),
                          )
                        : AppLocalizations.of(
                            context,
                          )!.settlementPartialReceived(
                            _money(s.settlementAmount),
                            _money(s.loanAmount + s.loanAmount2),
                          ),
                  ),
                  if (s.settlementFee > 0)
                    _item(
                      AppLocalizations.of(context)!.installmentBankFee,
                      _money(s.settlementFee),
                      color: Colors.orange,
                    ),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  // CÔNG NỢ KHÁCH HÀNG: tách rõ "nợ đơn này" khỏi "tổng công nợ khách qua
  // nhiều đơn" — không được hiển thị công nợ khách như thể là nợ của riêng
  // đơn này. Nợ trước đơn tính real-time (tổng nợ các đơn KHÁC hiện tại),
  // không lưu snapshot lịch sử.
  Widget _buildCustomerDebtCard() {
    final before = _otherOrdersDebt;
    final thisOrder = _orderRemainingDebt;
    final after = before + thisOrder;
    if (before == 0 && thisOrder == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CÔNG NỢ KHÁCH HÀNG',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF92400E),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _debtColumn('Nợ trước đơn', _money(before)),
              ),
              const Text('+', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: _debtColumn('Nợ phát sinh từ đơn', _money(thisOrder)),
              ),
              const Text('=', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: _debtColumn(
                  'Công nợ sau đơn',
                  _money(after),
                  bold: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CustomerDebtView(
                  phone: s.phone,
                  customerName: s.customerName,
                ),
              ),
            ).then((_) => _loadCustomerDebt()),
            child: const Text(
              'Xem công nợ khách >',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _debtColumn(String label, String value, {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10.5, color: Colors.grey),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 14 : 12.5,
            fontWeight: FontWeight.bold,
            color: bold ? const Color(0xFF92400E) : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _card(String t, List<Widget> c) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            border: Border(left: BorderSide(color: _accentColor, width: 4)),
          ),
          child: Text(
            t,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: _accentColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: c,
          ),
        ),
      ],
    ),
  );
  Widget _item(String l, String v, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l, style: const TextStyle(color: Colors.grey)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            v,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.end,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  Widget _staffItem(String name, String? uid) {
    final tappable = uid != null && uid.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.staffItemLabel,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: tappable
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StaffPublicProfileView(
                        userId: uid,
                        fallbackName: name,
                      ),
                    ),
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.isNotEmpty ? name : '--',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: tappable ? const Color(0xFF4F46E5) : null,
                    decoration: tappable ? TextDecoration.underline : null,
                    decorationColor: const Color(0xFF4F46E5),
                  ),
                ),
                if (tappable) ...[
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Color(0xFF4F46E5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openReturnView() async {
    if (_allItemsReturned) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateSalesReturnView(sale: s)),
    );
    if (result == true && mounted) {
      _loadReturnInfo();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.returnSuccessMsg),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    Color? color,
    bool enabled = true,
  }) {
    final c = color ?? const Color(0xFF0068FF);
    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, size: 18, color: enabled ? c : Colors.grey),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: enabled ? c : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendToChat() async {
    final user = FirebaseAuth.instance.currentUser;
    final senderId = user?.uid ?? 'guest';
    final senderName = user?.email?.split('@').first.toUpperCase() ?? 'KHACH';
    final key = s.firestoreId ?? "sale_${s.soldAt}";
    final summary =
        "ĐƠN BÁN - ${s.customerName} - ${s.phone} - ${MoneyUtils.formatCurrency(s.finalPrice)} đ";
    final msg = "Trao đổi về $summary";

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    await FirestoreService.sendChat(
      message: msg,
      senderId: senderId,
      senderName: senderName,
      linkedType: 'sale',
      linkedKey: key,
      linkedSummary: summary,
    );

    messenger.showSnackBar(SnackBar(content: Text(l10n.chatPinnedSale)));
  }

  Future<void> _sendSmsToCustomer() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final phone = s.phone.trim();
    if (phone.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.noCustomerPhone)));
      return;
    }

    final customer = s.customerName.isNotEmpty ? s.customerName : phone;
    final body =
        "SHOP $_shopName xin chào $customer, cảm ơn anh/chị đã mua ${s.productNamesDisplay}. Tổng thanh toán ${MoneyUtils.formatCurrency(s.finalPrice)}đ. Khi cần bảo hành vui lòng liên hệ $_shopPhone.";

    await Clipboard.setData(ClipboardData(text: body));

    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': body},
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        messenger.showSnackBar(SnackBar(content: Text(l10n.smsAppOpened)));
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l10n.smsAppCannotOpen)));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.smsSendError)));
    }
  }
}
