import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/repair_model.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';
import 'user_service.dart';
import 'notification_service.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // --- THÔNG BÁO ---
  static Future<void> _notifyAll(String title, String body, {String? type, String? id, String? summary}) async {
    try {
      await NotificationService.sendCloudNotification(title: title, body: body);
      final shopId = await UserService.getCurrentShopId();
      await _db.collection('chats').add({
        'shopId': shopId,
        'message': "$title: $body",
        'senderId': 'SYSTEM',
        'senderName': 'HỆ THỐNG',
        'linkedType': type,
        'linkedKey': id,
        'linkedSummary': summary,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // --- QUẢN LÝ SỬA CHỮA ---
  static Future<String?> addRepair(Repair r) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final docId = r.firestoreId ?? "rep_${r.createdAt}_${r.phone}";
      final docRef = _db.collection('repairs').doc(docId);
      Map<String, dynamic> data = r.toMap();
      data['shopId'] = shopId;
      await docRef.set(data, SetOptions(merge: true));
      _notifyAll("🔧 MÁY NHẬN MỚI", "${r.createdBy} nhận ${r.model}", type: 'repair', id: docId, summary: "${r.customerName} - ${r.model}");
      return docId;
    } catch (e) { return null; }
  }

  static Future<void> upsertRepair(Repair r) async {
    if (r.firestoreId == null) return;
    await _db.collection('repairs').doc(r.firestoreId!).set(r.toMap(), SetOptions(merge: true));
  }

  static Future<void> deleteRepair(String firestoreId) async {
    await _db.collection('repairs').doc(firestoreId).update({'deleted': true});
  }

  // --- QUẢN LÝ BÁN HÀNG ---
  static Future<void> addSale(SaleOrder s) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final docId = s.firestoreId ?? "sale_${s.soldAt}_${s.phone}";
      Map<String, dynamic> data = s.toMap();
      data['shopId'] = shopId;
      await _db.collection('sales').doc(docId).set(data, SetOptions(merge: true));
      _notifyAll("🎉 BÁN HÀNG THÀNH CÔNG", "${s.sellerName} bán ${s.productNames}", type: 'sale', id: docId, summary: "${s.customerName} - ${s.productNames}");
    } catch (_) {}
  }

  static Future<void> deleteSale(String firestoreId) async {
    await _db.collection('sales').doc(firestoreId).update({'deleted': true});
  }

  // --- QUẢN LÝ KHO ---
  static Future<void> addProduct(Product p) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final docId = p.firestoreId ?? "prod_${p.createdAt}";
      Map<String, dynamic> data = p.toMap();
      data['shopId'] = shopId;
      await _db.collection('products').doc(docId).set(data, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> updateProductCloud(Product p) async {
    if (p.firestoreId == null) return;
    await _db.collection('products').doc(p.firestoreId!).set(p.toMap(), SetOptions(merge: true));
  }

  // --- HỆ THỐNG CHAT ---
  static Future<void> sendChat({required String message, required String senderId, required String senderName, String? linkedType, String? linkedKey, String? linkedSummary}) async {
    try {
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
    } catch (_) {}
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> chatStream({String? shopId, int limit = 100}) {
    Query<Map<String, dynamic>> q = _db.collection('chats');
    if (shopId != null) q = q.where('shopId', isEqualTo: shopId);
    return q.orderBy('createdAt', descending: true).limit(limit).snapshots();
  }

  // --- THÔNG TIN SHOP ---
  static Future<Map<String, dynamic>?> getCurrentShopInfo() async {
    final shopId = await UserService.getCurrentShopId();
    if (shopId == null) return null;
    final doc = await _db.collection('shops').doc(shopId).get();
    return doc.data();
  }

  static Future<void> updateCurrentShopInfo(Map<String, dynamic> data) async {
    final shopId = await UserService.getCurrentShopId();
    if (shopId == null) return;
    await _db.collection('shops').doc(shopId).set(data, SetOptions(merge: true));
  }

  static Future<void> deleteCustomer(String firestoreId) async {
    await _db.collection('customers').doc(firestoreId).update({'deleted': true});
  }

  static Future<void> deleteSupplier(String firestoreId) async {
    await _db.collection('suppliers').doc(firestoreId).update({'deleted': true});
  }
}
