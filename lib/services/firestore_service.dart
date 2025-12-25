import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/repair_model.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';
import '../models/debt_model.dart';
import '../models/expense_model.dart';
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
      data['firestoreId'] = docRef.id;
      await docRef.set(data, SetOptions(merge: true));
      _notifyAll("🔧 MÁY NHẬN MỚI", "${r.createdBy} nhận ${r.model} của khách ${r.customerName}", type: 'repair', id: docRef.id, summary: "${r.customerName} - ${r.model}");
      return docRef.id;
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
  static Future<String?> addSale(SaleOrder s) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final docId = s.firestoreId ?? "sale_${s.soldAt}";
      final docRef = _db.collection('sales').doc(docId);
      Map<String, dynamic> data = s.toMap();
      data['shopId'] = shopId;
      data['firestoreId'] = docRef.id;
      await docRef.set(data, SetOptions(merge: true));
      _notifyAll("🎉 BÁN HÀNG THÀNH CÔNG", "${s.sellerName} vừa bán ${s.productNames} cho ${s.customerName}", type: 'sale', id: docRef.id, summary: "${s.customerName} - ${s.productNames}");
      return docRef.id;
    } catch (e) { return null; }
  }

  static Future<void> deleteSale(String firestoreId) async {
    await _db.collection('sales').doc(firestoreId).delete();
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
      await docRef.set(data, SetOptions(merge: true));
      return docRef.id;
    } catch (e) { return null; }
  }

  static Future<void> updateProductCloud(Product p) async {
    if (p.firestoreId == null) return;
    await _db.collection('products').doc(p.firestoreId!).set(p.toMap(), SetOptions(merge: true));
  }

  static Future<void> deleteProduct(String firestoreId) async {
    await _db.collection('products').doc(firestoreId).update({'status': 0});
  }

  // --- NHẬT KÝ HOẠT ĐỘNG (CLOULD SYNC) ---
  static Future<void> addAuditLogCloud(Map<String, dynamic> logData) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final String docId = "log_${logData['createdAt']}_${logData['userId']}";
      logData['shopId'] = shopId;
      logData['firestoreId'] = docId;
      await _db.collection('audit_logs').doc(docId).set(logData, SetOptions(merge: true));
    } catch (_) {}
  }

  // --- QUẢN LÝ CÔNG NỢ & CHI PHÍ ---
  static Future<void> addDebtCloud(Map<String, dynamic> debtData) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final String docId = debtData['firestoreId'] ?? "debt_${debtData['createdAt']}_${debtData['phone'] ?? 'ncc'}";
      debtData['shopId'] = shopId;
      debtData['firestoreId'] = docId;
      await _db.collection('debts').doc(docId).set(debtData, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> addExpenseCloud(Map<String, dynamic> expData) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final String docId = "exp_${expData['date']}_${expData['title'].hashCode}";
      expData['shopId'] = shopId;
      expData['firestoreId'] = docId;
      await _db.collection('expenses').doc(docId).set(expData, SetOptions(merge: true));
    } catch (_) {}
  }

  // --- CHAT NỘI BỘ ---
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

  // --- KHÁCH HÀNG & NHÀ CUNG CẤP ---
  static Future<void> deleteCustomer(String firestoreId) async {
    try { await _db.collection('customers').doc(firestoreId).delete(); } catch (_) {}
  }

  static Future<void> upsertSupplier(Map<String, dynamic> s) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final docId = "${shopId}_${s['name']}";
      Map<String, dynamic> data = Map<String, dynamic>.from(s);
      data['shopId'] = shopId;
      await _db.collection('suppliers').doc(docId).set(data, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> deleteSupplier(String firestoreId) async {
    try { await _db.collection('suppliers').doc(firestoreId).delete(); } catch (_) {}
  }
}
