import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../services/user_service.dart';

class PartsInventoryView extends StatefulWidget {
  const PartsInventoryView({super.key});

  @override
  State<PartsInventoryView> createState() => _PartsInventoryViewState();
}

class _PartsInventoryViewState extends State<PartsInventoryView> {
  final db = DBHelper();
  List<Map<String, dynamic>> _parts = [];
  bool _isLoading = true;
  final searchCtrl = TextEditingController();
  bool _isAdmin = false;

  // Theme colors cho màn hình phụ tùng
  final Color _primaryColor = Colors.purple; // Màu chính cho phụ tùng
  final Color _accentColor = Colors.purple.shade600;
  final Color _backgroundColor = const Color(0xFFF8FAFF);

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _refreshParts();
  }

  Future<void> _loadPermissions() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() {
      _isAdmin = perms['allowViewParts'] ?? false;
    });
  }

  Future<void> _refreshParts() async {
    setState(() => _isLoading = true);
    final data = await db.getAllParts();
    setState(() {
      _parts = data;
      _isLoading = false;
    });
  }

  void _showAddPartDialog({Map<String, dynamic>? part}) {
    final nameC = TextEditingController(text: part?['partName']);
    final modelC = TextEditingController(text: part?['compatibleModels']);
    final costC = TextEditingController(text: part != null ? (part['cost'] / 1000).toStringAsFixed(0) : "");
    final priceC = TextEditingController(text: part != null ? (part['price'] / 1000).toStringAsFixed(0) : "");
    final qtyC = TextEditingController(text: part != null ? part['quantity'].toString() : "1");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(part == null ? "NHẬP LINH KIỆN MỚI" : "SỬA LINH KIỆN"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: "Tên linh kiện (VD: PIN IPHONE 11)"), textCapitalization: TextCapitalization.characters),
              TextField(controller: modelC, decoration: const InputDecoration(labelText: "Dòng máy tương thích"), textCapitalization: TextCapitalization.characters),
              Row(children: [
                Expanded(child: TextField(controller: costC, decoration: const InputDecoration(labelText: "Giá vốn (.000)", suffixText: "k"), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: priceC, decoration: const InputDecoration(labelText: "Giá bán (.000)", suffixText: "k"), keyboardType: TextInputType.number)),
              ]),
              TextField(controller: qtyC, decoration: const InputDecoration(labelText: "Số lượng nhập"), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
          ElevatedButton(onPressed: () async {
            if (nameC.text.isEmpty) return;
            final data = {
              'partName': nameC.text.toUpperCase(),
              'compatibleModels': modelC.text.toUpperCase(),
              'cost': (int.tryParse(costC.text) ?? 0) * 1000,
              'price': (int.tryParse(priceC.text) ?? 0) * 1000,
              'quantity': int.tryParse(qtyC.text) ?? 0,
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
            };
            if (part == null) {
              await db.insertPart(data);
            } else {
              // Cập nhật linh kiện (giả sử có hàm updatePart trong db_helper)
              await (await db.database).update('repair_parts', data, where: 'id = ?', whereArgs: [part['id']]);
            }
            Navigator.pop(ctx);
            _refreshParts();
          }, child: const Text("XÁC NHẬN")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text("KHO LINH KIỆN SỬA CHỮA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: _primaryColor))
        : ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: _parts.length,
            itemBuilder: (ctx, i) {
              final p = _parts[i];
              final bool isLow = p['quantity'] < 3;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isLow ? Colors.red.withOpacity(0.1) : _primaryColor.withOpacity(0.1),
                    child: Icon(Icons.settings_input_component, color: isLow ? Colors.red : _primaryColor),
                  ),
                  title: Text(p['partName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text("Dùng cho: ${p['compatibleModels']}\nSố lượng: ${p['quantity']}"),
                  trailing: Text("${NumberFormat('#,###').format(p['price'])} đ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  onTap: _isAdmin ? () => _showAddPartDialog(part: p) : null,
                ),
              );
            },
          ),
      floatingActionButton: _isAdmin ? FloatingActionButton.extended(
        onPressed: () => _showAddPartDialog(),
        label: const Text("NHẬP LINH KIỆN"),
        icon: const Icon(Icons.add),
        backgroundColor: _primaryColor,
      ) : null,
    );
  }
}
