import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/responsive_wrapper.dart';
import '../models/product_category_model.dart';
import '../models/shop_settings_model.dart';
import '../services/category_service.dart';
import '../services/business_type_helper.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Màn hình quản lý danh mục sản phẩm
/// Multi-Industry Extension - Phase 1
class CategoryManagementView extends StatefulWidget {
  const CategoryManagementView({super.key});

  @override
  State<CategoryManagementView> createState() => _CategoryManagementViewState();
}

class _CategoryManagementViewState extends State<CategoryManagementView> {
  final CategoryService _categoryService = CategoryService();
  List<ProductCategory> _categories = [];
  bool _isLoading = true;
  ShopSettings? _shopSettings;

  BusinessTerminology get _terms => BusinessTypeHelper.instance.getTerminology(_shopSettings);

  @override
  void initState() {
    super.initState();
    _loadShopSettings();
    _loadCategories();
  }

  Future<void> _loadShopSettings() async {
    try {
      final settings = await CategoryService().getShopSettings();
      if (mounted) {
        setState(() => _shopSettings = settings);
      }
    } catch (e) {
      debugPrint('Error loading shop settings: $e');
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _categoryService.getCategories(forceRefresh: true);
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải danh mục: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Quản lý danh mục',
          style: AppTextStyles.headline3.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(),
            tooltip: 'Thêm danh mục',
          ),
        ],
      ),
      body: ResponsiveCenter(child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? _buildEmptyState()
              : _buildCategoryList()),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 80, color: AppColors.textHint),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Chưa có danh mục nào',
            style: AppTextStyles.headline3.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Thêm danh mục để phân loại sản phẩm',
            style: AppTextStyles.body2.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton.icon(
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Thêm danh mục'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _categories.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final key = category.firestoreId.isNotEmpty
            ? category.firestoreId
            : 'cat_$index';
        return Card(
          key: ValueKey(key),
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _parseColor(category.color).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.md),
              ),
              child: Center(
                child: Text(
                  category.icon ?? '📦',
                  style: AppTextStyles.headline1.copyWith(fontSize: 24),
                ),
              ),
            ),
            title: Text(
              category.name,
              style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _buildSubtitle(category),
              style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showAddEditDialog(category: category),
                ),
                IconButton(
                  icon: Icon(Icons.delete, size: 20, color: AppColors.error),
                  onPressed: () => _confirmDelete(category),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _buildSubtitle(ProductCategory category) {
    final features = <String>[];
    if (category.trackSerial) features.add(_terms.specialField1Label);
    if (category.trackExpiry) features.add('HSD');
    if (category.hasVariants) features.add('Biến thể');
    if (category.hasWarranty) features.add(_terms.specialField2Label);
    if (category.description?.isNotEmpty == true) {
      features.add(category.description!);
    }
    return features.isEmpty ? 'Không có tính năng đặc biệt' : features.join(' • ');
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return AppColors.primary;
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  void _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, item);
    setState(() {});

    // Update order in Firebase cloud
    for (var i = 0; i < _categories.length; i++) {
      await _categoryService.updateCategory(
        _categories[i].copyWith(sortOrder: i),
      );
    }
  }

  void _showAddEditDialog({ProductCategory? category}) {
    final isEdit = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    final descController = TextEditingController(text: category?.description ?? '');
    String selectedIcon = category?.icon ?? '📦';
    bool trackSerial = category?.trackSerial ?? false;
    bool trackExpiry = category?.trackExpiry ?? false;
    bool hasVariants = category?.hasVariants ?? false;
    bool hasWarranty = category?.hasWarranty ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Sửa danh mục' : 'Thêm danh mục'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon selector
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showIconPicker(selectedIcon, (icon) {
                        setDialogState(() => selectedIcon = icon);
                      }),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppSpacing.md),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Center(
                          child: Text(
                            selectedIcon,
                            style: AppTextStyles.headline1.copyWith(fontSize: 32),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Nhấn để chọn icon', style: AppTextStyles.body2),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                // Name
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên danh mục *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Description
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả / Đơn vị tính',
                    hintText: 'Ví dụ: cái, kg, hộp...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.lg),
                // Feature toggles
                Text(
                  'Tính năng',
                  style: AppTextStyles.headline4.copyWith(fontWeight: FontWeight.bold),
                ),
                SwitchListTile(
                  title: Text('Theo dõi ${_terms.specialField1Label}'),
                  subtitle: const Text('Cho sản phẩm cần theo dõi serial'),
                  value: trackSerial,
                  onChanged: (v) => setDialogState(() => trackSerial = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Theo dõi hạn sử dụng'),
                  subtitle: const Text('Cho thực phẩm'),
                  value: trackExpiry,
                  onChanged: (v) => setDialogState(() => trackExpiry = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Có biến thể (size/màu)'),
                  subtitle: const Text('Cho thời trang'),
                  value: hasVariants,
                  onChanged: (v) => setDialogState(() => hasVariants = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: Text('Có ${_terms.specialField2Label.toLowerCase()}'),
                  subtitle: const Text('Cho sản phẩm có thời hạn bảo hành'),
                  value: hasWarranty,
                  onChanged: (v) => setDialogState(() => hasWarranty = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập tên danh mục')),
                  );
                  return;
                }

                Navigator.pop(context);

                final newCategory = ProductCategory(
                  id: category?.id ?? '',
                  firestoreId: category?.firestoreId ?? '',
                  shopId: category?.shopId ?? '',
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  icon: selectedIcon,
                  trackSerial: trackSerial,
                  trackExpiry: trackExpiry,
                  hasVariants: hasVariants,
                  hasWarranty: hasWarranty,
                  sortOrder: category?.sortOrder ?? _categories.length,
                  isActive: true,
                );

                if (isEdit) {
                  await _categoryService.updateCategory(newCategory);
                } else {
                  await _categoryService.addCategory(newCategory);
                }

                _loadCategories();
              },
              child: Text(isEdit ? 'Cập nhật' : 'Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showIconPicker(String current, Function(String) onSelected) {
    final icons = [
      '📦', '📱', '💻', '🎧', '🔧', '⚡', '🔌', '📷',
      '🍎', '🥬', '🍖', '🐟', '🥚', '🍚', '🧃', '🥫',
      '👕', '👖', '👗', '👟', '👜', '🧣', '🧥', '💍',
      '🛋️', '🪑', '🛏️', '🚗', '🏠', '⭐', '🎁', '📋',
    ];

    showAppBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chọn icon',
              style: AppTextStyles.headline3.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: icons.map((icon) => GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onSelected(icon);
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: icon == current ? AppColors.primary : AppColors.background,
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                    border: Border.all(
                      color: icon == current ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      icon,
                      style: AppTextStyles.headline1.copyWith(fontSize: 28),
                    ),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(ProductCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa danh mục'),
        content: Text('Bạn có chắc muốn xóa danh mục "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final catId = category.firestoreId.isNotEmpty
                  ? category.firestoreId
                  : category.id;
              await _categoryService.deleteCategory(catId);
              _loadCategories();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(
              'Xóa',
              style: AppTextStyles.button.copyWith(color: AppColors.surface),
            ),
          ),
        ],
      ),
    );
  }
}
