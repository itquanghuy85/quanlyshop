import 'dart:async';

import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/customer_model.dart';
import '../services/user_service.dart';

/// Reusable "tìm khách hàng cũ" search box: debounced local SQLite search
/// by name/phone with ranked results (exact phone > prefix > substring),
/// falls back to recently-visited customers when the field is empty.
/// Results render inline below the field (not an Overlay/portal) so it is
/// safe to drop into any scrollable form without route/dependents pitfalls.
///
/// Purely a picker — it does not own the phone/name TextEditingControllers
/// of the surrounding form. The caller fills those in [onSelected].
class CustomerAutocompleteField extends StatefulWidget {
  final ValueChanged<Customer> onSelected;
  final String? hintText;
  final String? shopId;

  const CustomerAutocompleteField({
    super.key,
    required this.onSelected,
    this.hintText,
    this.shopId,
  });

  @override
  State<CustomerAutocompleteField> createState() =>
      _CustomerAutocompleteFieldState();
}

class _CustomerAutocompleteFieldState
    extends State<CustomerAutocompleteField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _db = DBHelper();
  Timer? _debounce;
  List<Customer> _results = [];
  bool _loading = false;
  bool _expanded = false;
  int _searchSeq = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _expanded = true);
        _search(_controller.text);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () => _search(q));
  }

  Future<void> _search(String q) async {
    final seq = ++_searchSeq;
    setState(() => _loading = true);
    final shopId = widget.shopId ?? await UserService.getCurrentShopId();
    final rows = await _db.searchCustomersRanked(q, shopId, limit: 10);
    // A newer keystroke may have started another search while this one was
    // awaiting the DB — drop stale results instead of racing to setState.
    if (!mounted || seq != _searchSeq) return;
    setState(() {
      _results = rows.map(Customer.fromMap).toList();
      _loading = false;
    });
  }

  void _select(Customer c) {
    widget.onSelected(c);
    _controller.clear();
    setState(() {
      _results = [];
      _expanded = false;
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 18),
            hintText: widget.hintText ?? 'Tìm khách hàng cũ (SĐT hoặc tên)...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _controller.clear();
                      _search('');
                    },
                  ),
          ),
        ),
        if (_expanded) _buildResults(),
      ],
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      if (_controller.text.trim().isEmpty) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Không tìm thấy khách hàng',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _results.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final c = _results[i];
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const CircleAvatar(
              radius: 14,
              child: Icon(Icons.person, size: 14),
            ),
            title: Text(
              c.name.trim().isEmpty ? '(Chưa có tên)' : c.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(_subtitleFor(c), style: const TextStyle(fontSize: 11)),
            onTap: () => _select(c),
          );
        },
      ),
    );
  }

  String _subtitleFor(Customer c) {
    final parts = <String>[if (c.phone.isNotEmpty) c.phone];
    if (c.lastVisitAt != null) {
      parts.add('Gần nhất: ${_relativeTime(c.lastVisitAt!)}');
    } else if (c.totalRepairs > 0) {
      parts.add('${c.totalRepairs} lần sửa');
    }
    return parts.join(' · ');
  }

  String _relativeTime(int ts) {
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ts),
    );
    if (diff.inDays > 0) return '${diff.inDays} ngày trước';
    if (diff.inHours > 0) return '${diff.inHours} giờ trước';
    if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
    return 'Vừa xong';
  }
}
