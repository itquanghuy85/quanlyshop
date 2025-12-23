import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/repair_model.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';
import 'user_service.dart';
import 'notification_service.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // --- HÀM HELPER GỬI THÔNG BÁO CHUNG ---
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

  // --- QUẢN LÝ NHÀ CUNG CẤP (MỚI) ---
  static Future<bool> upsertSupplier(Map<String, dynamic> s) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      // Dùng shopId + Tên NCC làm ID để tránh trùng giữa các shop
      final String docId = "${shopId}_${s['name']}";
      
      Map<String, dynamic> data = Map<String, dynamic>.from(s);
      data['shopId'] = shopId;
      data.remove('id'); // Xóa ID local
      
      await _db.collection('suppliers').doc(docId).set(data, SetOptions(merge: true));
      return true;
    } catch (_) { return false; }
  }

  static Future<void> deleteSupplier(String firestoreId) async {
    try { await _db.collection('suppliers').doc(firestoreId).update({'deleted': true}); } catch (_) {}
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
      _notifyAll("🔧 MÁY NHẬN MỚI", "${r.createdBy} nhận ${r.model} của khách ${r.customerName}", type: 'repair', id: docRef.id, summary: "${r.customerName} - ${r.model}");
      return docRef.id;
    } catch (e) { return null; }
  }

  static Future<bool> upsertRepair(Repair r) async {
    try {
      if (r.firestoreId == null) return false;
      final shopId = await UserService.getCurrentShopId();
      Map<String, dynamic> data = r.toMap();
      data['shopId'] = shopId;
      data.remove('id');
      await _db.collection('repairs').doc(r.firestoreId!).set(data, SetOptions(merge: true));
      return true;
    } catch (_) { return false; }
  }

  static Future<bool> deleteRepair(String firestoreId) async {
    try { await _db.collection('repairs').doc(firestoreId).update({'deleted': true}); return true; } catch (_) { return false; }
  }

  // --- QUẢN LÝ KHO ---
  static Future<String?> addProduct(Product p) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final docId = p.firestoreId ?? "prod_${p.createdAt}";
      final docRef = _db.collection('products').doc(docId);
      Map<String, dynamic> data = p.toMap();
      data['shopId'] = shopId;
      data['firestoreId'] = docRef.id;
      data.remove('id');
      await docRef.set(data, SetOptions(merge: true));
      _notifyAll("📦 NHẬP KHO MỚI", "Vừa nhập thêm ${p.name} vào kho.", type: 'product', id: docRef.id, summary: p.name);
      return docRef.id;
    } catch (e) { return null; }
  }

  static Future<bool> deleteProduct(String firestoreId) async {
    try { await _db.collection('products').doc(firestoreId).update({'deleted': true}); return true; } catch (_) { return false; }
  }

  // --- QUẢN LÝ BÁN HÀNG ---
  static Future<String?> addSale(SaleOrder s) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final docId = s.firestoreId ?? "sale_${s.soldAt}";
      final docRef = _db.collection('sales').doc(docId);
      Map<String, dynamic> data = s.toMap();
      data['shopId'] = shopId;
      data['firestoreId'] = docRef.id;
      data.remove('id');
      await docRef.set(data, SetOptions(merge: true));
      _notifyAll("🎉 BÁN HÀNG THÀNH CÔNG", "${s.sellerName} vừa bán ${s.productNames} cho ${s.customerName}", type: 'sale', id: docRef.id, summary: "${s.customerName} - ${s.productNames}");
      return docRef.id;
    } catch (e) { return null; }
  }

  static Future<bool> deleteSale(String firestoreId) async {
    try { await _db.collection('sales').doc(firestoreId).update({'deleted': true}); return true; } catch (_) { return false; }
  }

  // --- HỆ THỐNG CHAT ---
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

  // --- THÔNG TIN SHOP ---
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

  static Future<void> deleteCustomer(String firestoreId) async {
    try { await _db.collection('customers').doc(firestoreId).update({'deleted': true}); } catch (_) {}
  }
}
