import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/repair_model.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static Future<String?> addRepair(Repair r) async {
    try {
      // Ghi rõ firestoreId vào document để các máy khác nhận ra bản ghi duy nhất
      final docRef = _db.collection('repairs').doc(r.firestoreId ?? "${r.createdAt}_${r.phone}");
      await docRef.set({
        'firestoreId': docRef.id,
        'customerName': r.customerName,
        'phone': r.phone,
        'model': r.model,
        'address': r.address,
        'issue': r.issue,
        'accessories': r.accessories,
        'price': r.price,
        'cost': r.cost,
        'status': r.status,
        'warranty': r.warranty,
        'createdAt': r.createdAt,
        'startedAt': r.startedAt,
        'finishedAt': r.finishedAt,
        'deliveredAt': r.deliveredAt,
        'createdBy': r.createdBy,
        'repairedBy': r.repairedBy,
        'deliveredBy': r.deliveredBy,
      }, SetOptions(merge: true));
      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  // Upsert dùng chung cho cập nhật trạng thái và chỉnh sửa
  static Future<bool> upsertRepair(Repair r) async {
    try {
      final docRef = _db.collection('repairs').doc(r.firestoreId ?? "${r.createdAt}_${r.phone}");
      await docRef.set({
        'firestoreId': docRef.id,
        'customerName': r.customerName,
        'phone': r.phone,
        'model': r.model,
        'address': r.address,
        'issue': r.issue,
        'accessories': r.accessories,
        'price': r.price,
        'cost': r.cost,
        'status': r.status,
        'warranty': r.warranty,
        'createdAt': r.createdAt,
        'startedAt': r.startedAt,
        'finishedAt': r.finishedAt,
        'deliveredAt': r.deliveredAt,
        'createdBy': r.createdBy,
        'repairedBy': r.repairedBy,
        'deliveredBy': r.deliveredBy,
        'partsUsed': r.partsUsed,
        'lastCaredAt': r.lastCaredAt,
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- CHAT ---
  static Stream<QuerySnapshot<Map<String, dynamic>>> chatStream({int limit = 100}) {
    return _db.collection('chats').orderBy('createdAt', descending: true).limit(limit).snapshots();
  }

  static Future<void> sendChat({required String message, required String senderId, required String senderName}) async {
    await _db.collection('chats').add({
      'message': message,
      'senderId': senderId,
      'senderName': senderName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
