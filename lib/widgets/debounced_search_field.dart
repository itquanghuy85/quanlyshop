import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DebouncedSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final Function(String) onSearch;
  final Duration debounceTime;
  final IconData? icon;

  const DebouncedSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSearch,
    this.debounceTime = const Duration(milliseconds: 300),
    this.icon = Icons.search,
  });

  @override
  State<DebouncedSearchField> createState() => _DebouncedSearchFieldState();
}

class _DebouncedSearchFieldState extends State<DebouncedSearchField> {
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceTime, () {
      widget.onSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: widget.icon != null ? Icon(widget.icon, color: AppColors.textHint) : null,
        suffixIcon: widget.controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: AppColors.textHint),
                onPressed: () {
                  widget.controller.clear();
                  widget.onSearch('');
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      style: const TextStyle(fontSize: 16),
    );
  }
}
