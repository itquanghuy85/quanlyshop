import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/repair_model.dart';
import '../models/product_model.dart';
import 'user_service.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static Future<String?> addRepair(Repair r) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      // Sử dụng format firestoreId nhất quán
      final String docId = r.firestoreId ?? "repair_${r.createdAt}_${r.phone}_${r.id ?? 0}";
      final docRef = _db.collection('repairs').doc(docId);
      
      Map<String, dynamic> data = r.toMap();
      data['shopId'] = shopId;
      data['firestoreId'] = docRef.id;
      data.remove('id'); // Không đẩy ID local lên Firestore
      
      await docRef.set(data, SetOptions(merge: true));
      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> addProduct(Product p) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final String docId = p.firestoreId ?? "product_${p.createdAt}_${p.imei ?? 'noimei'}_${p.id ?? 0}";
      final docRef = _db.collection('products').doc(docId);
      
      Map<String, dynamic> data = p.toMap();
      data['shopId'] = shopId;
      data['firestoreId'] = docRef.id;
      data.remove('id'); // Không đẩy ID local lên Firestore
      
      await docRef.set(data, SetOptions(merge: true));
      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> upsertRepair(Repair r) async {
    try {
      if (r.firestoreId == null) return false;
      final shopId = await UserService.getCurrentShopId();
      final docRef = _db.collection('repairs').doc(r.firestoreId);
      
      Map<String, dynamic> data = r.toMap();
      data['shopId'] = shopId;
      data.remove('id');
      
      await docRef.set(data, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteRepair(String firestoreId) async {
    try {
      await _db.collection('repairs').doc(firestoreId).update({
        'deleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteSale(String firestoreId) async {
    try {
      await _db.collection('sales').doc(firestoreId).update({
        'deleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteProduct(String firestoreId) async {
    try {
      await _db.collection('products').doc(firestoreId).update({
        'deleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteSupplier(String firestoreId) async {
    try {
      await _db.collection('suppliers').doc(firestoreId).update({
        'deleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteCustomer(String firestoreId) async {
    try {
      await _db.collection('customers').doc(firestoreId).update({
        'deleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- TIN NHẮN CHAT ---
  static Stream<QuerySnapshot<Map<String, dynamic>>> chatStream({String? shopId, int limit = 100}) {
    Query<Map<String, dynamic>> q = _db.collection('chats');
    if (shopId != null) {
      q = q.where('shopId', isEqualTo: shopId);
    }
    q = q.orderBy('createdAt', descending: true).limit(limit);
    return q.snapshots();
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
