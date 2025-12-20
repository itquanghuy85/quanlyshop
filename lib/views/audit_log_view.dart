import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/user_service.dart';

class AuditLogView extends StatefulWidget {
  const AuditLogView({super.key});

  @override
  State<AuditLogView> createState() => _AuditLogViewState();
}

class _AuditLogViewState extends State<AuditLogView> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  bool _loading = false;
  bool _hasMore = true;
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    final shopId = await UserService.getCurrentShopId();
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('audit_logs')
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true)
        .limit(50);
    if (_lastDoc != null) q = q.startAfterDocument(_lastDoc!);
    final snap = await q.get();
    if (snap.docs.isNotEmpty) {
      _lastDoc = snap.docs.last;
      _docs.addAll(snap.docs);
    }
    if (snap.docs.length < 50) _hasMore = false;
    if (mounted) setState(() => _loading = false);
  }

  String _fmtTime(Timestamp? ts) {
    if (ts == null) return '--:--';
    return DateFormat('HH:mm dd/MM/yyyy').format(ts.toDate());
  }

  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> get _filteredDocs {
    if (_filter.isEmpty) return _docs;
    final f = _filter.toLowerCase();
    return _docs.where((d) {
      final m = d.data();
      return (m['action'] ?? '').toString().toLowerCase().contains(f) ||
          (m['email'] ?? '').toString().toLowerCase().contains(f) ||
          (m['summary'] ?? '').toString().toLowerCase().contains(f) ||
          (m['entityType'] ?? '').toString().toLowerCase().contains(f);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NHẬT KÝ HOẠT ĐỘNG'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Tìm theo action, email, tóm tắt',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _filter = v.trim()),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _docs.clear();
                _lastDoc = null;
                _hasMore = true;
                await _loadMore();
              },
              child: ListView.builder(
                itemCount: _filteredDocs.length + 1,
                itemBuilder: (ctx, i) {
                  final items = _filteredDocs.toList();
                  if (i >= items.length) {
                    if (_hasMore) _loadMore();
                    return _loading
                        ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                        : const SizedBox.shrink();
                  }
                  final doc = items[i];
                  final data = doc.data();
                  final payload = (data['payload'] ?? {}) as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text('${data['action'] ?? ''} • ${data['entityType'] ?? ''}/${data['entityId'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_fmtTime(data['createdAt'] as Timestamp?)),
                          Text('${data['email'] ?? '---'} (${data['role'] ?? ''})'),
                          if ((data['summary'] ?? '').toString().isNotEmpty) Text(data['summary']),
                          if (payload.isNotEmpty)
                            Text(payload.entries.map((e) => '${e.key}: ${e.value}').join(' | '), style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
