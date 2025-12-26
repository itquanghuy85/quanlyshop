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
    String digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isNotEmpty) {
      int baseAmount = int.tryParse(digitsOnly) ?? 0;
      if (baseAmount > 0) {
        int actualAmount = baseAmount * 1000;
        String formatted = _formatNumber(baseAmount);
        widget.controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
        widget.onChanged?.call(actualAmount.toString());
      } else {
        widget.controller.value = const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
        widget.onChanged?.call('0');
      }
    } else {
      widget.controller.value = const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
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
      if (count % 3 == 0 && i > 0) result = '.' + result;
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
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: widget.required ? '${widget.label} *' : widget.label,
            hintText: widget.hint ?? 'Nhập số tiền',
            prefixIcon: widget.icon != null ? Icon(widget.icon) : null,
            suffixText: 'x1k',
            suffixStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            errorText: _errorText,
            filled: true,
            fillColor: widget.enabled ? Colors.white : Colors.grey.shade100,
          ),
          style: TextStyle(fontSize: 16, color: widget.enabled ? Colors.black87 : Colors.grey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
