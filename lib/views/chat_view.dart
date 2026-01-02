import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import 'repair_detail_view.dart';
import 'sale_detail_view.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final DBHelper _db = DBHelper();
  String? _shopId;
  bool _loadingShop = true;

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    _loadShop().then((_) {
      UserService.markChatAsRead(FirebaseAuth.instance.currentUser!.uid);
    });
=======
    _loadShop();
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  }

  Future<void> _loadShop() async {
    final id = await UserService.getCurrentShopId();
    if (!mounted) return;
    setState(() {
      _shopId = id;
      _loadingShop = false;
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    final senderId = user?.uid ?? 'guest';
    final senderName = user?.email?.split('@').first.toUpperCase() ?? 'KHACH';
    await FirestoreService.sendChat(message: text, senderId: senderId, senderName: senderName);
    _msgCtrl.clear();
  }

<<<<<<< HEAD
  Future<void> _pinRepairOrder() async {
    if (_shopId == null) return;

    try {
      // Lấy danh sách đơn sửa chữa gần đây
      final repairs = await _db.getAllRepairs();
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chọn đơn sửa chữa để gim'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: repairs.length,
              itemBuilder: (context, index) {
                final repair = repairs[index];
                return ListTile(
                  leading: const Icon(Icons.build, color: Colors.orange),
                  title: Text('Đơn #${repair.id} - ${repair.customerName}'),
                  subtitle: Text('${repair.model} - ${repair.issue}'),
                  onTap: () {
                    Navigator.pop(context);
                    _sendRepairOrderMessage(repair);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error loading repair orders: $e');
    }
  }

  Future<void> _sendRepairOrderMessage(Repair repair) async {
    String getStatusText(int status) {
      switch (status) {
        case 1: return 'Đã nhận';
        case 2: return 'Đang sửa';
        case 3: return 'Hoàn thành';
        case 4: return 'Đã giao';
        default: return 'Không xác định';
      }
    }

    final message = '''
🛠️ ĐƠN SỬA CHỮA #${repair.id}

👤 Khách hàng: ${repair.customerName}
📱 Model: ${repair.model}
🔧 Vấn đề: ${repair.issue}
📍 Địa chỉ: ${repair.address ?? 'N/A'}
📞 SĐT: ${repair.phone}
💰 Giá: ${repair.price != null && repair.price > 0 ? '${repair.price}đ' : 'Chưa báo giá'}
📊 Trạng thái: ${getStatusText(repair.status)}
📝 Ghi chú: ${repair.accessories ?? 'Không có'}
''';

    final user = FirebaseAuth.instance.currentUser;
    final senderId = user?.uid ?? 'guest';
    final senderName = user?.email?.split('@').first.toUpperCase() ?? 'KHACH';
    
    await FirestoreService.sendChat(
      message: message.trim(),
      senderId: senderId,
      senderName: senderName,
      linkedType: 'repair',
      linkedKey: repair.id.toString(),
      linkedSummary: 'Đơn sửa chữa #${repair.id} - ${repair.customerName}',
    );
  }

=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  Widget _bubble(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final isMe = data['senderId'] == userId;
    final ts = (data['createdAt'] as Timestamp?)?.toDate();
    final linkedType = data['linkedType'] as String?;
    final linkedSummary = data['linkedSummary'] as String?;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(data['senderName'] ?? '---', style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : Colors.blueGrey)),
        const SizedBox(height: 2),
        Text(data['message'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black)),
        if (linkedType != null && linkedSummary != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isMe ? Colors.white24 : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  linkedType == 'repair' ? Icons.build_circle_rounded : Icons.shopping_cart_rounded,
                  size: 18,
                  color: isMe ? Colors.yellowAccent : Colors.deepPurple,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    linkedSummary,
                    style: TextStyle(fontSize: 11, color: isMe ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (ts != null) ...[
          const SizedBox(height: 4),
          Text("${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}", style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey)),
        ]
      ],
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => _onBubbleTap(data),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: isMe ? Colors.blueAccent : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: content,
        ),
      ),
    );
  }

  Future<void> _onBubbleTap(Map<String, dynamic> data) async {
    final type = data['linkedType'] as String?;
    final key = data['linkedKey'] as String?;
    if (type == null || key == null || key.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      if (type == 'repair') {
        final Repair? r = await _db.getRepairByFirestoreId(key);
        if (r == null) {
          messenger.showSnackBar(const SnackBar(content: Text('Không tìm thấy đơn sửa tương ứng')));
          return;
        }
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RepairDetailView(repair: r)),
        );
      } else if (type == 'sale') {
        final SaleOrder? s = await _db.getSaleByFirestoreId(key);
        if (s == null) {
          messenger.showSnackBar(const SnackBar(content: Text('Không tìm thấy đơn bán tương ứng')));
          return;
        }
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SaleDetailView(sale: s)),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Lỗi khi mở đơn: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
<<<<<<< HEAD
      appBar: AppBar(title: const Text('Chat nội bộ'), automaticallyImplyLeading: true),
=======
      appBar: AppBar(title: const Text('Chat nội bộ')),
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
      body: Column(
        children: [
          if (_loadingShop)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else ...[
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.chatStream(shopId: _shopId, limit: 200),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) => _bubble(docs[i]),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
<<<<<<< HEAD
                    backgroundColor: Colors.orangeAccent,
                    child: IconButton(
                      icon: const Icon(Icons.build, color: Colors.white),
                      tooltip: 'Gim đơn sửa chữa',
                      onPressed: _pinRepairOrder,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
                    backgroundColor: Colors.blueAccent,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _send,
                    ),
                  )
                ],
              ),
            ),
          )
          ]
        ],
      ),
    );
  }
}
