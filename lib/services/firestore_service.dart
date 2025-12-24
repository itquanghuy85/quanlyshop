import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/repair_model.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';
import 'user_service.dart';
import 'notification_service.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // --- THÔNG BÁO HỆ THỐNG ---
  static Future<void> _notifyAll(String title, String body, {String? type, String? id, String? summary}) async {
    try {
      await NotificationService.sendCloudNotification(title: title, body: body);
      final shopId = await UserService.getCurrentShopId();
      await _db.collection('chats').add({
        'shopId': shopId, 'message': "$title: $body", 'senderId': 'SYSTEM', 'senderName': 'HỆ THỐNG', 'linkedType': type, 'linkedKey': id, 'linkedSummary': summary, 'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // --- QUẢN LÝ SỬA CHỮA ---
  static Future<String?> addRepair(Repair r) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final docId = r.firestoreId ?? "${r.createdAt}_${r.phone}";
      final docRef = _db.collection('repairs').doc(docId);
      Map<String, dynamic> data = r.toMap();
      data['shopId'] = shopId;
      data['firestoreId'] = docRef.id;
      data.remove('id');
      await docRef.set(data, SetOptions(merge: true));
      return docRef.id;
    } catch (e) { return null; }
  }

  static Future<bool> upsertRepair(Repair r) async {
    try {
      if (r.firestoreId == null) return false;
      Map<String, dynamic> data = r.toMap();
      data.remove('id');
      await _db.collection('repairs').doc(r.firestoreId!).set(data, SetOptions(merge: true));
      return true;
    } catch (_) { return false; }
  }

  static Future<void> deleteRepair(String firestoreId) async {
    try { await _db.collection('repairs').doc(firestoreId).update({'deleted': true}); } catch (_) {}
  }

  // --- QUẢN LÝ BÁN HÀNG ---
  static Future<String?> addSale(SaleOrder s) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final docId = s.firestoreId ?? "sale_${s.soldAt}";
      Map<String, dynamic> data = s.toMap();
      data['shopId'] = shopId;
      await _db.collection('sales').doc(docId).set(data, SetOptions(merge: true));
      _notifyAll("🎉 BÁN HÀNG", "${s.sellerName} vừa bán ${s.productNames}", type: 'sale', id: docId, summary: "${s.customerName} - ${s.productNames}");
      return docId;
    } catch (e) { return null; }
  }

  static Future<void> deleteSale(String firestoreId) async {
    try { await _db.collection('sales').doc(firestoreId).delete(); } catch (_) {}
  }

  // --- QUẢN LÝ KHO ---
  static Future<String?> addProduct(Product p) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final docId = p.firestoreId ?? "prod_${p.createdAt}";
      Map<String, dynamic> data = p.toMap();
      data['shopId'] = shopId;
      await _db.collection('products').doc(docId).set(data, SetOptions(merge: true));
      return docId;
    } catch (e) { return null; }
  }

  // HÀM CẬP NHẬT TRẠNG THÁI TRỪ KHO CLOUD
  static Future<void> updateProductCloud(Product p) async {
    try {
      if (p.firestoreId == null) return;
      Map<String, dynamic> data = p.toMap();
      data.remove('id');
      await _db.collection('products').doc(p.firestoreId!).set(data, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> deleteProduct(String firestoreId) async {
    try { await _db.collection('products').doc(firestoreId).update({'status': 0}); } catch (_) {}
  }

  // --- NHÀ CUNG CẤP & KHÁCH HÀNG (SỬA LỖI MẤT HÀM) ---
  static Future<void> deleteCustomer(String firestoreId) async {
    try { await _db.collection('customers').doc(firestoreId).delete(); } catch (_) {}
  }

  static Future<void> deleteSupplier(String firestoreId) async {
    try { await _db.collection('suppliers').doc(firestoreId).delete(); } catch (_) {}
  }

  static Future<void> upsertSupplier(Map<String, dynamic> s) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final docId = "${shopId}_${s['name']}";
      Map<String, dynamic> data = Map<String, dynamic>.from(s);
      data['shopId'] = shopId;
      data.remove('id');
      await _db.collection('suppliers').doc(docId).set(data, SetOptions(merge: true));
    } catch (_) {}
  }

  // --- THÔNG TIN SHOP & CHAT ---
  static Future<void> sendChat({required String message, required String senderId, required String senderName, String? linkedType, String? linkedKey, String? linkedSummary}) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      await _db.collection('chats').add({
        'shopId': shopId, 'message': message, 'senderId': senderId, 'senderName': senderName, 'linkedType': linkedType, 'linkedKey': linkedKey, 'linkedSummary': linkedSummary, 'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> chatStream({String? shopId, int limit = 100}) {
    Query<Map<String, dynamic>> q = _db.collection('chats');
    if (shopId != null) q = q.where('shopId', isEqualTo: shopId);
    return q.orderBy('createdAt', descending: true).limit(limit).snapshots();
  }

  static Future<Map<String, dynamic>?> getCurrentShopInfo() async {
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null) return null;
      final doc = await _db.collection('shops').doc(shopId).get();
      return doc.data();
    } catch (_) { return null; }
  }

  static Future<void> updateCurrentShopInfo(Map<String, dynamic> data) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null) return;
      await _db.collection('shops').doc(shopId).set(data, SetOptions(merge: true));
    } catch (_) {}
  }
}
