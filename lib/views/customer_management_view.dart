import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/customer_model.dart';
import '../services/customer_service.dart';
import '../services/first_time_guide_service.dart';
import '../services/sync_service.dart';
import '../services/event_bus.dart';
import '../services/storage_service.dart';
import '../core/utils/money_utils.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/global_search_bar.dart';
import '../widgets/entity_avatar.dart';
import '../widgets/responsive_wrapper.dart';
import '../l10n/app_localizations.dart';
import '../utils/vietnamese_utils.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/skeleton_list.dart';
import '../expansion/safe_mode/expansion_feature_flags.dart';
import 'expansion/crm/customer_loyalty_view.dart';
import 'customer_profile_view.dart';

class CustomerManagementView extends StatefulWidget {
  const CustomerManagementView({super.key});

  @override
  State<CustomerManagementView> createState() => _CustomerManagementViewState();
}

class _CustomerManagementViewState extends State<CustomerManagementView> {
  final CustomerService _customerService = CustomerService();
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  List<Customer> _displayedCustomers = []; // Danh sách hiển thị (phân trang)
  bool _isLoading = true;
  String _searchQuery = '';
  static const int _pageSize = 50;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _customerEventSub;
  Timer? _customerRefreshDebounce;
  final Set<String> _customerRefreshEvents = {
    'customers_changed',
    EventBus.dataRefresh,
    EventBus.shopChanged,
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _bindCustomerRefreshEvents();
    _loadCustomers();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstTimeGuide());
  }

  Future<void> _showFirstTimeGuide() async {
    await FirstTimeGuideService.showGuideIfNeeded(
      context: context,
      screenKey: FirstTimeGuideService.keyCustomerManagement,
      title: 'Quản Lý Khách Hàng',
      icon: Icons.people_rounded,
      color: Colors.blueAccent,
      steps: [
        const GuideStep(
          title: '👥 Danh sách khách hàng',
          description: 'Lưu trữ thông tin đầy đủ: họ tên, số điện thoại, địa chỉ và ghi chú của từng khách.',
          icon: Icons.contact_phone_rounded,
          iconColor: Colors.blueAccent,
        ),
        const GuideStep(
          title: '📞 Liên hệ nhanh',
          description: 'Nhấn vào số điện thoại để gọi điện hoặc nhắn tin cho khách hàng trực tiếp.',
          icon: Icons.call_rounded,
          iconColor: Colors.green,
        ),
        const GuideStep(
          title: '📊 Lịch sử giao dịch',
          description: 'Xem toàn bộ đơn sửa chữa, hóa đơn mua hàng và công nợ của từng khách.',
          icon: Icons.history_rounded,
          iconColor: Colors.orange,
        ),
        const GuideStep(
          title: '⭐ Khách hàng thân thiết',
          description: 'Hệ thống tự nhận diện khách VIP dựa trên tần suất và giá trị giao dịch.',
          icon: Icons.star_rounded,
          iconColor: Colors.amber,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _customerRefreshDebounce?.cancel();
    _customerEventSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _bindCustomerRefreshEvents() {
    _customerEventSub?.cancel();
    _customerEventSub = EventBus().stream
        .where((event) => _customerRefreshEvents.contains(event))
        .listen((event) {
          _customerRefreshDebounce?.cancel();
          _customerRefreshDebounce = Timer(
            const Duration(milliseconds: 280),
            () {
              if (!mounted) return;
              _reloadCustomersQuiet();
            },
          );
        });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _hasMore &&
        !_isLoading) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    final currentLen = _displayedCustomers.length;
    if (currentLen >= _filteredCustomers.length) {
      setState(() => _hasMore = false);
      return;
    }
    final nextBatch = _filteredCustomers
        .skip(currentLen)
        .take(_pageSize)
        .toList();
    setState(() {
      _displayedCustomers.addAll(nextBatch);
      _hasMore = _displayedCustomers.length < _filteredCustomers.length;
    });
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      // Sync customers from cloud (non-blocking, chạy nền)
      SyncService.syncCustomersFromCloud()
          .catchError((e) {
            debugPrint('Sync customers error (ignored): $e');
          })
          .then((_) {
            // Sau khi sync xong, reload lại nếu có data mới
            if (mounted) _reloadCustomersQuiet();
          });

      final customers = await _customerService.getCustomers();
      setState(() {
        _customers = customers;
        _filteredCustomers = customers;
        _displayedCustomers = customers.take(_pageSize).toList();
        _hasMore = customers.length > _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorLoadingCustomers(e.toString()),
            ),
          ),
        );
      }
    }
  }

  /// Reload khi sync xong (không hiển loading)
  Future<void> _reloadCustomersQuiet() async {
    try {
      final customers = await _customerService.getCustomers();
      if (mounted && _hasCustomerListChanged(customers)) {
        _customers = customers;
        _filterCustomers(_searchQuery);
      }
    } catch (_) {}
  }

  bool _hasCustomerListChanged(List<Customer> next) {
    if (next.length != _customers.length) return true;

    Map<String, String> fingerprint(List<Customer> items) {
      return {
        for (final c in items)
          (c.firestoreId ?? 'local_${c.id ?? 0}'):
              '${c.updatedAt ?? c.createdAt}|${c.name}|${c.phone}|${c.address ?? ''}|${c.totalSpent}|${c.totalRepairs}|${c.totalRepairCost}|${c.deleted ? 1 : 0}',
      };
    }

    final oldMap = fingerprint(_customers);
    final newMap = fingerprint(next);
    if (oldMap.length != newMap.length) return true;

    for (final entry in newMap.entries) {
      if (oldMap[entry.key] != entry.value) return true;
    }
    return false;
  }

  void _filterCustomers(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredCustomers = _customers;
      } else {
        _filteredCustomers = _customers.where((customer) {
          return VietnameseUtils.containsVietnamese(customer.name, query) ||
              customer.phone.contains(query) ||
              VietnameseUtils.containsVietnamese(customer.address ?? '', query);
        }).toList();
      }
      _displayedCustomers = _filteredCustomers.take(_pageSize).toList();
      _hasMore = _displayedCustomers.length < _filteredCustomers.length;
    });
  }

  Future<void> _addCustomer() async {
    final result = await showDialog<Customer>(
      context: context,
      builder: (context) => const CustomerFormDialog(),
    );

    if (result != null) {
      await _customerService.addCustomer(result);
      _loadCustomers();
    }
  }

  Future<void> _editCustomer(Customer customer) async {
    // Verify owner password first
    if (!await _verifyOwnerPassword(
      AppLocalizations.of(context)!.editCustomerAction,
    ))
      return;

    final result = await showDialog<Customer>(
      context: context,
      builder: (context) => CustomerFormDialog(customer: customer),
    );

    if (result != null) {
      await _customerService.updateCustomer(result);
      _loadCustomers();
    }
  }

  Future<void> _deleteCustomer(Customer customer) async {
    // Verify owner password first
    if (!await _verifyOwnerPassword(
      AppLocalizations.of(context)!.deleteCustomerAction,
    ))
      return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.confirmDeleteTitle),
        content: Text(
          AppLocalizations.of(context)!.confirmDeleteCustomer(customer.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.deleteButton),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _customerService.deleteCustomer(customer.id!);
      _loadCustomers();
    }
  }

  // ============ PASSWORD VERIFICATION ============
  Future<String?> _showPasswordDialog(String action) async {
    String password = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.confirmActionTitle(action)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)!.ownerPasswordRequired),
            const SizedBox(height: 10),
            TextField(
              obscureText: true,
              onChanged: (value) => password = value,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.password,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { FocusScope.of(ctx).unfocus(); Navigator.pop(ctx); },
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () { FocusScope.of(ctx).unfocus(); Navigator.pop(ctx, password); },
            child: Text(AppLocalizations.of(context)!.confirmBtn),
          ),
        ],
      ),
    );
  }

  Future<bool> _verifyOwnerPassword(String action) async {
    final password = await _showPasswordDialog(action);
    if (password == null || password.isEmpty) return false;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseLoginAgain)),
      );
      return false;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: password,
      );
      await currentUser.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.incorrectPassword),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _viewCustomerHistory(Customer customer) async {
    final history = await _customerService.getCustomerHistory(customer.phone);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) =>
          CustomerHistoryDialog(customer: customer, history: history),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar.build(
        title: AppLocalizations.of(context)!.customerManagement,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addCustomer,
            tooltip: AppLocalizations.of(context)!.addCustomer,
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: GlobalSearchBar(
                hintText: AppLocalizations.of(context)!.searchCustomers,
                onSearch: _filterCustomers,
              ),
            ),

            // Customer list
            Expanded(
              child: _isLoading
                  ? const SkeletonListView(
                      variant: SkeletonVariant.listTile,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    )
                  : _filteredCustomers.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.people_outline,
                      title: _searchQuery.isEmpty
                          ? AppLocalizations.of(context)!.noCustomersYet
                          : AppLocalizations.of(context)!.customerNotFound,
                      subtitle: _searchQuery.isNotEmpty ? 'Thử tìm với từ khóa khác' : null,
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount:
                          _displayedCustomers.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _displayedCustomers.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final customer = _displayedCustomers[index];
                        return CustomerListItem(
                          customer: customer,
                          onEdit: () => _editCustomer(customer),
                          onDelete: () => _deleteCustomer(customer),
                          onViewHistory: () => _viewCustomerHistory(customer),
                          onOpenProfile: () async {
                            final result = await Navigator.push<dynamic>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CustomerProfileView(customer: customer),
                              ),
                            );
                            if (result != null) {
                              await _loadCustomers();
                            }
                          },
                          onViewLoyalty: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerLoyaltyView(
                                customerId:
                                    customer.firestoreId ??
                                    customer.id?.toString() ??
                                    customer.phone,
                                customerIdAliases: <String>[
                                  if ((customer.firestoreId ?? '').isNotEmpty)
                                    customer.firestoreId!,
                                  if (customer.id != null)
                                    customer.id.toString(),
                                  customer.phone,
                                ],
                                customerName: customer.name,
                                initialTotalSpent: customer.totalSpent,
                                flags: const ExpansionFeatureFlags(
                                  enableCRM: true,
                                ),
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
}

class CustomerListItem extends StatelessWidget {
  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewHistory;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onViewLoyalty;

  const CustomerListItem({
    super.key,
    required this.customer,
    required this.onEdit,
    required this.onDelete,
    required this.onViewHistory,
    this.onOpenProfile,
    this.onViewLoyalty,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          child: EntityAvatar(
            imageUrl: customer.avatarUrl,
            name: customer.name,
            radius: 18,
            heroTag:
                'hero_customer_avatar_${customer.id ?? customer.phone}',
          ),
        ),
        title: Text(
          customer.name,
          style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customer.phone, style: AppTextStyles.caption),
            if (customer.address?.isNotEmpty == true)
              Text(
                customer.address!,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (customer.notes?.isNotEmpty == true)
              Text(
                'Ghi chú: ${customer.notes!}',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.blue.shade600,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(
                  'Đã mua: ${MoneyUtils.formatCompact(customer.totalSpent)}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.success,
                  ),
                ),
                Text(
                  'Sửa: ${customer.totalRepairs} lần',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: onOpenProfile ?? onViewHistory,
      ),
    );
  }
}

class CustomerFormDialog extends StatefulWidget {
  final Customer? customer;

  const CustomerFormDialog({super.key, this.customer});

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  String? _avatarUrl;
  XFile? _pendingAvatar;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      _nameController.text = widget.customer!.name;
      _phoneController.text = widget.customer!.phone;
      _emailController.text = widget.customer!.email ?? '';
      _addressController.text = widget.customer!.address ?? '';
      _notesController.text = widget.customer!.notes ?? '';
      _avatarUrl = widget.customer!.avatarUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.customer == null ? 'Thêm khách hàng' : 'Chỉnh sửa khách hàng',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar khách hàng
              Center(
                child: Column(
                  children: [
                    EntityAvatar(
                      imageUrl: _pendingAvatar != null ? _pendingAvatar!.path : _avatarUrl,
                      name: _nameController.text.trim().isEmpty ? 'KH' : _nameController.text.trim(),
                      radius: 38,
                      showEditButton: true,
                      onEditTap: _pickAvatar,
                      tappableToView: _pendingAvatar != null || (_avatarUrl?.isNotEmpty == true),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: _pickAvatar,
                      icon: const Icon(Icons.camera_alt, size: 16),
                      label: const Text('Chọn ảnh đại diện', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên khách hàng *',
                  hintText: 'Nhập tên khách hàng',
                ),
                validator: (value) {
                  if (value?.trim().isEmpty == true) {
                    return 'Vui lòng nhập tên khách hàng';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại *',
                  hintText: 'Nhập số điện thoại',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value?.trim().isEmpty == true) {
                    return 'Vui lòng nhập số điện thoại';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Nhập email (tùy chọn)',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ',
                  hintText: 'Nhập địa chỉ (tùy chọn)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú',
                  hintText: 'Nhập ghi chú (tùy chọn)',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _uploadingAvatar ? null : _saveCustomer,
          child: _uploadingAvatar
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Lưu'),
        ),
      ],
    );
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 600);
    if (picked != null && mounted) {
      setState(() => _pendingAvatar = picked);
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    String? finalAvatarUrl = _avatarUrl;
    if (_pendingAvatar != null) {
      setState(() => _uploadingAvatar = true);
      finalAvatarUrl = await StorageService.uploadXFileAndGetUrl(
        _pendingAvatar!,
        'entity_photos/customers',
      );
      if (mounted) setState(() => _uploadingAvatar = false);
    }

    final customer = Customer(
      id: widget.customer?.id,
      firestoreId: widget.customer?.firestoreId,
      avatarUrl: finalAvatarUrl,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt:
          widget.customer?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      totalSpent: widget.customer?.totalSpent ?? 0,
      totalRepairs: widget.customer?.totalRepairs ?? 0,
      totalRepairCost: widget.customer?.totalRepairCost ?? 0,
      isSynced: widget.customer?.isSynced ?? false,
      deleted: widget.customer?.deleted ?? false,
    );

    Navigator.pop(context, customer);
  }
}

class CustomerHistoryDialog extends StatelessWidget {
  final Customer customer;
  final Map<String, dynamic> history;

  const CustomerHistoryDialog({
    super.key,
    required this.customer,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final historyList = history['history'] as List<dynamic>;
    final totalSales = history['totalSales'] as int;
    final totalRepairs = history['totalRepairs'] as int;
    final totalPayments = (history['totalPayments'] as int?) ?? 0;
    final totalSpent = history['totalSpent'] as int;
    final totalRepairCost = history['totalRepairCost'] as int;
    final totalPaymentAmount = (history['totalPaymentAmount'] as int?) ?? 0;

    return Dialog(
      child: Container(
        width: responsiveDialogWidth(context),
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                EntityAvatar(
                  imageUrl: customer.avatarUrl,
                  name: customer.name,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.name, style: AppTextStyles.headline6),
                      Text(customer.phone, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const Divider(),

            // Summary stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Mua hàng',
                    '${NumberFormat('#,###').format(totalSpent)}đ',
                    '$totalSales đơn',
                    AppColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Sửa chữa',
                    '${NumberFormat('#,###').format(totalRepairCost)}đ',
                    '$totalRepairs lần',
                    AppColors.warning,
                  ),
                ),
                if (totalPayments > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'Đóng tiền',
                      '${NumberFormat('#,###').format(totalPaymentAmount)}đ',
                      '$totalPayments lần',
                      Colors.blue,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),

            // History list
            Expanded(
              child: historyList.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.history_rounded,
                      title: 'Chưa có lịch sử',
                      subtitle: 'Các đơn sửa và mua hàng sẽ hiển thị tại đây',
                    )
                  : ListView.builder(
                      itemCount: historyList.length,
                      itemBuilder: (context, index) {
                        final item = historyList[index] as Map<String, dynamic>;
                        return _buildHistoryItem(item);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String amount,
    String count,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: AppTextStyles.body2.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(count, style: AppTextStyles.caption.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final type = item['type'] as String;
    final date = DateTime.fromMillisecondsSinceEpoch(item['date'] as int);
    final amount = item['amount'] as int;
    final description = item['description'] as String;

    final bool isSale = type == 'sale';
    final bool isPayment = type == 'payment';
    final Color color = isPayment
        ? Colors.blue
        : (isSale ? AppColors.success : AppColors.warning);
    final IconData icon = isPayment
        ? Icons.receipt_long
        : (isSale ? Icons.shopping_cart : Icons.build);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          description,
          style: AppTextStyles.body2,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          DateFormat('dd/MM/yyyy HH:mm').format(date),
          style: AppTextStyles.caption,
        ),
        trailing: Text(
          '${NumberFormat('#,###').format(amount)}đ',
          style: AppTextStyles.body2.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
