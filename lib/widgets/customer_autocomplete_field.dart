import 'dart:async';

import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/customer_model.dart';
import '../services/user_service.dart';

/// Debounced local-SQLite customer search shared by both widgets below:
/// ranked results (exact phone > prefix > substring), falling back to
/// recently-visited customers when the query is empty.
Future<List<Customer>> _rankedCustomerSearch(
  String query,
  String? explicitShopId, {
  int limit = 10,
}) async {
  final shopId = explicitShopId ?? await UserService.getCurrentShopId();
  final rows = await DBHelper().searchCustomersRanked(
    query,
    shopId,
    limit: limit,
  );
  return rows.map(Customer.fromMap).toList();
}

/// Controlled results panel: the caller owns the search text (typically an
/// *existing* form field like SĐT or Tên khách) and just tells this widget
/// what to search for and whether it should be showing at all. Renders
/// inline below the caller's field (not an Overlay/portal) so it drops
/// safely into any scrollable form without route/dependents pitfalls.
///
/// Use this when suggestions should appear as the user types into fields
/// that already exist in the form. For a screen that instead wants a
/// dedicated, self-contained search box, use [CustomerAutocompleteField].
class CustomerSuggestionsPanel extends StatefulWidget {
  final String query;
  final bool active;
  final ValueChanged<Customer> onSelected;
  final String? shopId;

  const CustomerSuggestionsPanel({
    super.key,
    required this.query,
    required this.active,
    required this.onSelected,
    this.shopId,
  });

  @override
  State<CustomerSuggestionsPanel> createState() =>
      _CustomerSuggestionsPanelState();
}

class _CustomerSuggestionsPanelState extends State<CustomerSuggestionsPanel> {
  Timer? _debounce;
  List<Customer> _results = [];
  bool _loading = false;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    if (widget.active) _search(widget.query);
  }

  @override
  void didUpdateWidget(covariant CustomerSuggestionsPanel old) {
    super.didUpdateWidget(old);
    if (!widget.active) return;
    if (!old.active || old.query != widget.query) {
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(milliseconds: 180),
        () => _search(widget.query),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final seq = ++_seq;
    setState(() => _loading = true);
    final results = await _rankedCustomerSearch(q, widget.shopId);
    // A newer keystroke may have started another search while this one was
    // awaiting the DB — drop stale results instead of racing to setState.
    if (!mounted || seq != _seq) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    return _CustomerResultsList(
      loading: _loading,
      results: _results,
      queryEmpty: widget.query.trim().isEmpty,
      onSelected: widget.onSelected,
    );
  }
}

/// Self-contained "tìm khách hàng cũ" search box for screens that don't
/// already have their own phone/name fields to attach suggestions to. Owns
/// its own text field and debounce; purely a picker — it does not touch any
/// TextEditingController belonging to the surrounding form, the caller
/// fills those in [onSelected].
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
    final results = await _rankedCustomerSearch(q, widget.shopId);
    if (!mounted || seq != _searchSeq) return;
    setState(() {
      _results = results;
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
        if (_expanded)
          _CustomerResultsList(
            loading: _loading,
            results: _results,
            queryEmpty: _controller.text.trim().isEmpty,
            onSelected: _select,
          ),
      ],
    );
  }
}

class _CustomerResultsList extends StatelessWidget {
  final bool loading;
  final List<Customer> results;
  final bool queryEmpty;
  final ValueChanged<Customer> onSelected;

  const _CustomerResultsList({
    required this.loading,
    required this.results,
    required this.queryEmpty,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
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
    if (results.isEmpty) {
      if (queryEmpty) return const SizedBox.shrink();
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
        itemCount: results.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final c = results[i];
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
            onTap: () => onSelected(c),
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
