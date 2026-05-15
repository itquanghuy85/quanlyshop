import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/shop_settings_model.dart';
import '../../services/category_service.dart';

/// Wizard chọn ngành kinh doanh cho shop mới
/// Phase 4: General Shop - Onboarding
class BusinessTypeWizard extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Function(ShopSettings) onComplete;

  const BusinessTypeWizard({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.onComplete,
  });

  @override
  State<BusinessTypeWizard> createState() => _BusinessTypeWizardState();
}

class _BusinessTypeWizardState extends State<BusinessTypeWizard> {
  int _currentStep = 0;
  final String _selectedType =
      'electronics'; // Luôn là electronics - không thay đổi
  final Map<String, bool> _selectedModules = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _updateModulesForType(_selectedType);
  }

  void _updateModulesForType(String type) {
    // Luôn cấu hình cho electronics - loại duy nhất được hỗ trợ
    setState(() {
      _selectedModules.clear();
      _selectedModules['enableRepair'] = true;
      _selectedModules['enableSerial'] = true;
      _selectedModules['enableWarranty'] = true;
      _selectedModules['enableExpiry'] = false;
      _selectedModules['enableVariants'] = false;
      _selectedModules['enableBatch'] = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thiết lập cửa hàng'),
        centerTitle: true,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _onStepCancel,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                FilledButton(
                  onPressed: _isLoading ? null : details.onStepContinue,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_currentStep == 1 ? 'Hoàn tất' : 'Tiếp tục'),
                ),
                const SizedBox(width: 12),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Quay lại'),
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Tính năng'),
            subtitle: const Text('Tùy chỉnh tính năng cho cửa hàng điện thoại'),
            content: _buildModuleSelector(),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Xác nhận'),
            subtitle: const Text('Kiểm tra và hoàn tất'),
            content: _buildSummary(),
            isActive: _currentStep >= 1,
            state: StepState.indexed,
          ),
        ],
      ),
    );
  }

  Widget _buildModuleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tùy chỉnh tính năng cho "${_getTypeName(_selectedType)}"',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          'Bạn có thể bật/tắt các tính năng theo nhu cầu',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 16),
        _buildModuleSwitch(
          'enableRepair',
          'Module sửa chữa',
          'Nhận máy, quản lý tiến độ sửa, bàn giao',
          Icons.build,
        ),
        _buildModuleSwitch(
          'enableSerial',
          'Quản lý IMEI/Serial',
          'Theo dõi số IMEI hoặc Serial sản phẩm',
          Icons.numbers,
        ),
        _buildModuleSwitch(
          'enableWarranty',
          'Quản lý bảo hành',
          'Theo dõi tình trạng bảo hành sản phẩm',
          Icons.verified_user,
        ),
        _buildModuleSwitch(
          'enableExpiry',
          'Quản lý hạn sử dụng',
          'Cảnh báo sản phẩm sắp hết hạn',
          Icons.timer,
        ),
        _buildModuleSwitch(
          'enableBatch',
          'Quản lý theo lô',
          'Nhập hàng theo lô, theo dõi từng lô',
          Icons.inventory,
        ),
        _buildModuleSwitch(
          'enableVariants',
          'Biến thể (size/màu)',
          'Quản lý sản phẩm theo size, màu sắc',
          Icons.style,
        ),
      ],
    );
  }

  Widget _buildModuleSwitch(
    String key,
    String title,
    String description,
    IconData icon,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        secondary: Icon(icon),
        title: Text(title),
        subtitle: Text(description, style: const TextStyle(fontSize: 14)),
        value: _selectedModules[key] ?? false,
        onChanged: (v) => setState(() => _selectedModules[key] = v),
      ),
    );
  }

  Widget _buildSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.store, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.shopName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const Divider(),
                _buildSummaryRow(
                  'Loại hình',
                  _getTypeName(_selectedType),
                  _getTypeIcon(_selectedType),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tính năng đã bật:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _selectedModules.entries
                      .where((e) => e.value)
                      .map(
                        (e) => Chip(
                          label: Text(
                            _getModuleName(e.key),
                            style: const TextStyle(fontSize: 13),
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
                if (!_selectedModules.values.any((v) => v))
                  const Text(
                    'Chưa bật tính năng nào',
                    style: TextStyle(
                      color: AppColors.textHint,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bạn có thể thay đổi cài đặt bất cứ lúc nào trong phần Cài đặt cửa hàng',
                  style: TextStyle(color: AppColors.primary, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  String _getTypeName(String type) {
    switch (type) {
      case 'electronics':
        return 'Điện thoại & Điện tử';
      case 'food':
        return 'Thực phẩm & Đồ tươi sống';
      case 'fashion':
        return 'Thời trang & May mặc';
      case 'general':
        return 'Tổng hợp / Tùy chỉnh';
      default:
        return type;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'electronics':
        return Icons.phone_android;
      case 'food':
        return Icons.restaurant;
      case 'fashion':
        return Icons.checkroom;
      case 'general':
        return Icons.store;
      default:
        return Icons.store;
    }
  }

  String _getModuleName(String key) {
    switch (key) {
      case 'enableRepair':
        return 'Sửa chữa';
      case 'enableSerial':
        return 'IMEI/Serial';
      case 'enableWarranty':
        return 'Bảo hành';
      case 'enableExpiry':
        return 'Hạn sử dụng';
      case 'enableBatch':
        return 'Theo lô';
      case 'enableVariants':
        return 'Biến thể';
      default:
        return key;
    }
  }

  void _onStepContinue() async {
    if (_currentStep < 1) {
      setState(() => _currentStep++);
    } else {
      // Save settings
      await _saveSettings();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    try {
      final settings = ShopSettings(
        shopId: widget.shopId,
        firestoreId: 'shop_settings',
        businessType: 'electronics', // Luôn electronics
        businessTypeName: 'Điện thoại & Điện tử',
        enableRepair: _selectedModules['enableRepair'] ?? true,
        enableSerial: _selectedModules['enableSerial'] ?? true,
        enableWarranty: _selectedModules['enableWarranty'] ?? true,
        enableExpiry: false,
        enableBatch: false,
        enableVariants: false,
        defaultUnit: 'cái',
      );

      // Save to Firestore through service
      await CategoryService().saveShopSettings(settings);

      widget.onComplete(settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Dialog chọn nhanh loại hình cho shop đã có - chỉ hiển thị electronics
class BusinessTypeQuickSelector extends StatelessWidget {
  final Function(String) onSelected;

  const BusinessTypeQuickSelector({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Loại hình kinh doanh'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(
            context,
            'electronics',
            '📱 Điện thoại & Điện tử',
            Icons.phone_android,
            AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    String type,
    String label,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.pop(context);
          onSelected(type);
        },
      ),
    );
  }
}

/// Preset configurations - chỉ hỗ trợ electronics
class BusinessTypePresets {
  static Map<String, dynamic> getPreset(String type) {
    // Luôn trả về preset cho electronics
    return {
      'businessType': 'electronics',
      'businessTypeName': 'Điện thoại & Điện tử',
      'enableRepair': true,
      'enableSerial': true,
      'enableWarranty': true,
      'enableExpiry': false,
      'enableBatch': false,
      'enableVariants': false,
      'defaultUnit': 'cái',
      'defaultCategories': [
        {
          'name': 'Điện thoại',
          'icon': '📱',
          'trackSerial': true,
          'hasWarranty': true,
        },
        {
          'name': 'Máy tính bảng',
          'icon': '📱',
          'trackSerial': true,
          'hasWarranty': true,
        },
        {
          'name': 'Laptop',
          'icon': '💻',
          'trackSerial': true,
          'hasWarranty': true,
        },
        {
          'name': 'Phụ kiện',
          'icon': '🎧',
          'trackSerial': false,
          'hasWarranty': false,
        },
        {
          'name': 'Linh kiện',
          'icon': '🔧',
          'trackSerial': false,
          'hasWarranty': false,
        },
      ],
    };
  }

  static List<String> get availableTypes => ['electronics'];

  static String getTypeName(String type) {
    return 'Điện thoại & Điện tử';
  }

  static String getTypeIcon(String type) {
    return '📱';
  }
}
