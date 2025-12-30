import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/repair_model.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';
import '../models/purchase_order_model.dart';
import '../models/attendance_model.dart';
import 'user_service.dart';
import 'notification_service.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // --- THÔNG BÁO HỆ THỐNG ---
  static Future<void> _notifyAll(String title, String body, {String? type, String? id, String? summary}) async {
    try {
      await NotificationService.sendCloudNotification(title: title, body: body, type: 'system');
      final shopId = await UserService.getCurrentShopId();
      await _db.collection('chats').add({
        'shopId': shopId,
        'message': "$title: $body",
        'senderId': 'SYSTEM',
        'senderName': 'HỆ THỐNG',
        'linkedType': type,
        'linkedKey': id,
        'linkedSummary': summary,
        'readBy': ['SYSTEM'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // --- QUẢN LÝ ĐƠN NHẬP HÀNG (MỚI BỔ SUNG ĐỂ SỬA LỖI BUILD) ---
  static Future<String?> addPurchaseOrder(PurchaseOrder order) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final docId = order.firestoreId ?? "po_${order.createdAt}_${order.orderCode}";
      final docRef = _db.collection('purchase_orders').doc(docId);
      
      Map<String, dynamic> data = order.toMap();
      data['shopId'] = shopId;
      data['firestoreId'] = docId;
      
      await docRef.set(data, SetOptions(merge: true));
      
      _notifyAll(
        "📦 ĐƠN NHẬP MỚI", 
        "Vừa nhập hàng từ NCC: ${order.supplierName} - Mã: ${order.orderCode}",
        type: 'purchase_order',
        id: docId,
        summary: "${order.supplierName} - ${order.orderCode}"
      );
      
      return docId;
    } catch (e) {
      return null;
    }
  }

  // --- CÁC HÀM CỐ LÕI KHÁC (KHÔNG THAY ĐỔI LOGIC) ---
  static Future<String?> addRepair(Repair r) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null && !UserService.isCurrentUserSuperAdmin()) {
        throw Exception('Không tìm thấy thông tin cửa hàng. Vui lòng liên hệ quản trị viên.');
      }
      final docId = r.firestoreId ?? "rep_${r.createdAt}_${r.phone}";
      final docRef = _db.collection('repairs').doc(docId);
      Map<String, dynamic> data = r.toMap();
      data['shopId'] = shopId;
      data['firestoreId'] = docRef.id;
      await docRef.set(data, SetOptions(merge: true));
      _notifyAll("🔧 MÁY NHẬN MỚI", "${r.createdBy} nhận ${r.model} của khách ${r.customerName}", type: 'repair', id: docRef.id, summary: "${r.customerName} - ${r.model}");
      return docRef.id;
    } catch (e) { 
      debugPrint('Firestore addRepair error: $e');
      return null; 
    }
  }

  static Future<void> upsertRepair(Repair r) async {
    if (r.firestoreId == null) return;
    try {
      await _db.collection('repairs').doc(r.firestoreId).set(r.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore upsertRepair error: $e');
    }
  }

  static Future<void> deleteRepair(String firestoreId) async {
    try {
      await _db.collection('repairs').doc(firestoreId).update({'deleted': true});
    } catch (e) {
      debugPrint('Firestore deleteRepair error: $e');
    }
  }

  static Future<String?> addSale(SaleOrder s) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null && !UserService.isCurrentUserSuperAdmin()) {
        throw Exception('Không tìm thấy thông tin cửa hàng. Vui lòng liên hệ quản trị viên.');
      }
      if (s.totalPrice <= 0 || s.totalCost < 0) {
        throw Exception('Số tiền bán hàng không hợp lệ');
      }
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

  static Future<void> updateSaleCloud(SaleOrder s) async {
    if (s.firestoreId == null) return;
    try {
      final shopId = await UserService.getCurrentShopId();
      Map<String, dynamic> data = s.toMap();
      data['shopId'] = shopId;
      await _db.collection('sales').doc(s.firestoreId).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore updateSaleCloud error: $e');
    }
  }

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
    try {
      await _db.collection('products').doc(p.firestoreId).set(p.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore updateProductCloud error: $e');
    }
  }

  static Future<void> deleteProduct(String firestoreId) async {
    try {
      await _db.collection('products').doc(firestoreId).update({'status': 0});
    } catch (e) {
      debugPrint('Firestore deleteProduct error: $e');
    }
  }

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
        'readBy': [senderId],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> chatStream({String? shopId, int limit = 100}) {
    Query<Map<String, dynamic>> q = _db.collection('chats');
    if (shopId != null) q = q.where('shopId', isEqualTo: shopId);
    return q.orderBy('createdAt', descending: true).limit(limit).snapshots();
  }

  static Future<void> addAuditLogCloud(Map<String, dynamic> logData) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      final String docId = "log_${logData['createdAt']}_${logData['userId']}";
      logData['shopId'] = shopId;
      logData['firestoreId'] = docId;
      await _db.collection('audit_logs').doc(docId).set(logData, SetOptions(merge: true));
    } catch (_) {}
  }

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
      if (((expData['amount'] as int?) ?? 0) <= 0) return;
      final shopId = await UserService.getCurrentShopId();
      final String docId = "exp_${expData['date']}_${expData['title'].hashCode}";
      expData['shopId'] = shopId;
      expData['firestoreId'] = docId;
      await _db.collection('expenses').doc(docId).set(expData, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> updateExpenseCloud(Map<String, dynamic> expData) async {
    if (expData['firestoreId'] == null) return;
    try {
      final shopId = await UserService.getCurrentShopId();
      expData['shopId'] = shopId;
      await _db.collection('expenses').doc(expData['firestoreId']).set(expData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore updateExpenseCloud error: $e');
    }
  }

  static Future<void> deleteExpenseCloud(String firestoreId) async {
    try {
      await _db.collection('expenses').doc(firestoreId).update({'deleted': true});
    } catch (e) {
      debugPrint('Firestore deleteExpenseCloud error: $e');
    }
  }

  static Stream<QuerySnapshot> getExpenseStream() async* {
    try {
      final shopId = await UserService.getCurrentShopId();
      Query query = _db.collection('expenses');

      if (shopId != null) {
        query = query.where('shopId', isEqualTo: shopId);
      }

      yield* query.orderBy('date', descending: true).snapshots();
    } catch (e) {
      debugPrint('Firestore getExpenseStream error: $e');
      yield* const Stream.empty();
    }
  }

  // --- ATTENDANCE CRUD METHODS ---
  static Future<String?> addAttendance(Attendance attendance) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null && !UserService.isCurrentUserSuperAdmin()) {
        throw Exception('Không tìm thấy thông tin cửa hàng. Vui lòng liên hệ quản trị viên.');
      }
      final docId = attendance.firestoreId ?? "att_${attendance.dateKey}_${attendance.userId}";
      final docRef = _db.collection('attendance').doc(docId);
      Map<String, dynamic> data = attendance.toMap();
      data['shopId'] = shopId;
      data['firestoreId'] = docId;
      await docRef.set(data, SetOptions(merge: true));
      return docId;
    } catch (e) {
      debugPrint('Firestore addAttendance error: $e');
      return null;
    }
  }

  static Future<void> updateAttendanceCloud(Attendance attendance) async {
    if (attendance.firestoreId == null) return;
    try {
      final shopId = await UserService.getCurrentShopId();
      Map<String, dynamic> data = attendance.toMap();
      data['shopId'] = shopId;
      await _db.collection('attendance').doc(attendance.firestoreId).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore updateAttendanceCloud error: $e');
    }
  }

  static Future<void> deleteAttendance(String firestoreId) async {
    try {
      await _db.collection('attendance').doc(firestoreId).update({'deleted': true});
    } catch (e) {
      debugPrint('Firestore deleteAttendance error: $e');
    }
  }

  static Stream<QuerySnapshot> getAttendanceStream({String? userId, String? dateKey}) async* {
    try {
      final shopId = await UserService.getCurrentShopId();
      Query query = _db.collection('attendance');

      if (shopId != null) {
        query = query.where('shopId', isEqualTo: shopId);
      }

      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      if (dateKey != null) {
        query = query.where('dateKey', isEqualTo: dateKey);
      }

      yield* query.orderBy('createdAt', descending: true).snapshots();
    } catch (e) {
      debugPrint('Firestore getAttendanceStream error: $e');
      yield* const Stream.empty();
    }
  }

  static Future<bool> resetEntireShopData() async {
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null) return false;
      final collections = ['repairs', 'sales', 'products', 'debts', 'expenses', 'audit_logs', 'attendance', 'chats', 'inventory_checks', 'cash_closings', 'purchase_orders'];
      for (var colName in collections) {
        final snapshots = await _db.collection(colName).where('shopId', isEqualTo: shopId).get();
        final batch = _db.batch();
        for (var doc in snapshots.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      return true;
    } catch (e) { return false; }
  }

  static Future<void> deleteCustomer(String firestoreId) async {
    try { await _db.collection('customers').doc(firestoreId).delete(); } catch (_) {}
  }

  static Future<void> deleteSupplier(String firestoreId) async {
    try { await _db.collection('suppliers').doc(firestoreId).delete(); } catch (_) {}
  }
}
