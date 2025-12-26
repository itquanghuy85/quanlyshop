import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CurrencyTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool required;
  final bool enabled;
  final VoidCallback? onSubmitted;
  final Function(String)? onChanged;

  const CurrencyTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.required = false,
    this.enabled = true,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  State<CurrencyTextField> createState() => _CurrencyTextFieldState();
}

class _CurrencyTextFieldState extends State<CurrencyTextField> {
  String? _errorText;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_validate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validate);
    super.dispose();
  }

  void _validate() {
    final value = widget.controller.text;
    String? error;

    if (widget.required && value.trim().isEmpty) {
      error = '${widget.label} không được để trống';
    }

    setState(() => _errorText = error);
  }

  void _onChanged(String value) {
    // Remove all non-digit characters
    String digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isNotEmpty) {
      // Parse the input as the base amount (user enters 220 for 220,000 VND)
      int baseAmount = int.tryParse(digitsOnly) ?? 0;

      if (baseAmount > 0) {
        // Store the actual VND value (multiply by 1000)
        int actualAmount = baseAmount * 1000;

        // Format the display value with dots as thousand separators
        String formatted = _formatNumber(baseAmount);
        widget.controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );

        // Pass the actual VND amount to onChanged callback
        widget.onChanged?.call(actualAmount.toString());
      } else {
        widget.controller.value = TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );
        widget.onChanged?.call('0');
      }
    } else {
      widget.controller.value = TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      widget.onChanged?.call('0');
    }

    _validate();
  }

  String _formatNumber(int number) {
    String str = number.toString();
    String result = '';
    int count = 0;

    for (int i = str.length - 1; i >= 0; i--) {
      result = str[i] + result;
      count++;
      if (count % 3 == 0 && i > 0) {
        result = '.' + result;
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          keyboardType: TextInputType.number,
          enabled: widget.enabled,
          onChanged: _onChanged,
          onSubmitted: widget.onSubmitted != null ? (_) => widget.onSubmitted!() : null,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            labelText: widget.required ? '${widget.label} *' : widget.label,
            hintText: widget.hint ?? 'Nhập số tiền (x1k)',
            prefixIcon: widget.icon != null ? Icon(widget.icon) : null,
            suffixText: 'x1k',
            suffixStyle: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _errorText != null ? Colors.red : Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _errorText != null ? Colors.red : Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _errorText != null ? Colors.red : Theme.of(context).primaryColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            errorText: _errorText,
            errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
            filled: true,
            fillColor: widget.enabled ? Colors.white : Colors.grey.shade100,
          ),
          style: TextStyle(
            fontSize: 16,
            color: widget.enabled ? Colors.black87 : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        // Helper text to explain the convention
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 12),
          child: Text(
            '💡 Nhập 220 → lưu 220.000 VNĐ',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

// Enhanced Currency Input Widget - Tối ưu hơn cho UX
class EnhancedCurrencyInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool required;
  final bool enabled;
  final VoidCallback? onSubmitted;
  final Function(String)? onChanged;
  final List<int>? quickAmounts; // Preset amounts for quick selection

  const EnhancedCurrencyInput({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.required = false,
    this.enabled = true,
    this.onSubmitted,
    this.onChanged,
    this.quickAmounts, // Default presets: 100k, 200k, 500k, 1M, 2M, 5M
  });

  @override
  State<EnhancedCurrencyInput> createState() => _EnhancedCurrencyInputState();
}

class _EnhancedCurrencyInputState extends State<EnhancedCurrencyInput> {
  String? _errorText;
  bool _showQuickAmounts = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_validate);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validate);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _showQuickAmounts = _focusNode.hasFocus && (widget.quickAmounts?.isNotEmpty ?? false);
    });
  }

  void _validate() {
    final value = widget.controller.text;
    String? error;

    if (widget.required && value.trim().isEmpty) {
      error = '${widget.label} không được để trống';
    }

    setState(() => _errorText = error);
  }

  void _onChanged(String value) {
    // Allow direct input of full VND amounts
    String digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isNotEmpty) {
      int amount = int.tryParse(digitsOnly) ?? 0;

      if (amount > 0) {
        // Format with thousand separators
        String formatted = _formatCurrency(amount);
        widget.controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );

        // Pass the actual VND amount
        widget.onChanged?.call(amount.toString());
      } else {
        widget.controller.clear();
        widget.onChanged?.call('0');
      }
    } else {
      widget.controller.clear();
      widget.onChanged?.call('0');
    }

    _validate();
  }

  void _selectQuickAmount(int amount) {
    String formatted = _formatCurrency(amount);
    widget.controller.text = formatted;
    widget.onChanged?.call(amount.toString());
    _focusNode.unfocus();
    _validate();
  }

  String _formatCurrency(int amount) {
    String str = amount.toString();
    String result = '';
    int count = 0;

    for (int i = str.length - 1; i >= 0; i--) {
      result = str[i] + result;
      count++;
      if (count % 3 == 0 && i > 0) {
        result = '.' + result;
      }
    }

    return result;
  }

  String _formatQuickAmount(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(0)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    final defaultQuickAmounts = widget.quickAmounts ?? [100000, 200000, 500000, 1000000, 2000000, 5000000];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Input Field
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          keyboardType: TextInputType.number,
          enabled: widget.enabled,
          onChanged: _onChanged,
          onSubmitted: widget.onSubmitted != null ? (_) => widget.onSubmitted!() : null,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            labelText: widget.required ? '${widget.label} *' : widget.label,
            hintText: widget.hint ?? 'Nhập số tiền (VNĐ)',
            prefixIcon: widget.icon != null ? Icon(widget.icon) : null,
            suffixText: 'VNĐ',
            suffixIcon: widget.quickAmounts != null || widget.quickAmounts == null
                ? IconButton(
                    icon: Icon(_showQuickAmounts ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                    onPressed: () {
                      setState(() {
                        _showQuickAmounts = !_showQuickAmounts;
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _errorText != null ? Colors.red : Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _errorText != null ? Colors.red : Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _errorText != null ? Colors.red : Theme.of(context).primaryColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            errorText: _errorText,
            errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
            filled: true,
            fillColor: widget.enabled ? Colors.white : Colors.grey.shade100,
          ),
          style: TextStyle(
            fontSize: 16,
            color: widget.enabled ? Colors.black87 : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),

        // Quick Amount Buttons
        if (_showQuickAmounts) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn nhanh:',
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: defaultQuickAmounts.map((amount) {
                    return InkWell(
                      onTap: () => _selectQuickAmount(amount),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _formatQuickAmount(amount),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
