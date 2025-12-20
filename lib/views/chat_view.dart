import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

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

  Widget _bubble(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final isMe = data['senderId'] == userId;
    final ts = (data['createdAt'] as Timestamp?)?.toDate();
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMe ? Colors.blueAccent : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['senderName'] ?? '---', style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : Colors.blueGrey)),
            const SizedBox(height: 2),
            Text(data['message'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black)),
            if (ts != null) ...[
              const SizedBox(height: 4),
              Text("${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}", style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey)),
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat nội bộ')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.chatStream(limit: 200),
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
        ],
      ),
    );
  }
}
