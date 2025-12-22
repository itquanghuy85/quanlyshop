import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/repair_model.dart';
import 'user_service.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static Future<String?> addRepair(Repair r) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      // Ghi rõ firestoreId vào document để các máy khác nhận ra bản ghi duy nhất
      final docRef = _db.collection('repairs').doc(r.firestoreId ?? "${r.createdAt}_${r.phone}");
      await docRef.set({
        'shopId': shopId,
        'firestoreId': docRef.id,
        'customerName': r.customerName,
        'phone': r.phone,
        'model': r.model,
        'address': r.address,
        'issue': r.issue,
        'accessories': r.accessories,
        'price': r.price,
        'cost': r.cost,
        'paymentMethod': r.paymentMethod,
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
      final shopId = await UserService.getCurrentShopId();
      final docRef = _db.collection('repairs').doc(r.firestoreId ?? "${r.createdAt}_${r.phone}");
      await docRef.set({
        'shopId': shopId,
        'firestoreId': docRef.id,
        'customerName': r.customerName,
        'phone': r.phone,
        'model': r.model,
        'address': r.address,
        'issue': r.issue,
        'accessories': r.accessories,
        'price': r.price,
        'cost': r.cost,
        'paymentMethod': r.paymentMethod,
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
  static Stream<QuerySnapshot<Map<String, dynamic>>> chatStream({String? shopId, int limit = 100}) {
    Query<Map<String, dynamic>> q = _db.collection('chats');
    if (shopId != null) {
      q = q.where('shopId', isEqualTo: shopId);
    }
    q = q.orderBy('createdAt', descending: true).limit(limit);
    return q.snapshots();
  }

  /// Xóa repair trên Firestore (dùng khi xóa từ app để tránh bị sync lại)
  static Future<bool> deleteRepair(String firestoreId) async {
    try {
      await _db.collection('repairs').doc(firestoreId).delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> sendChat({
    required String message,
    required String senderId,
    required String senderName,
    String? linkedType,
    String? linkedKey,
    String? linkedSummary,
  }) async {
    final shopId = await UserService.getCurrentShopId();
    await _db.collection('chats').add({
      'shopId': shopId,
      'message': message,
      'senderId': senderId,
      'senderName': senderName,
      'linkedType': linkedType,
      'linkedKey': linkedKey,
      'linkedSummary': linkedSummary,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
