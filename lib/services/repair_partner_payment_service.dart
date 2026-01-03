import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/db_helper.dart';
import '../models/repair_partner_payment_model.dart';
import '../services/user_service.dart';

class RepairPartnerPaymentService {
  final DBHelper _db = DBHelper();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<RepairPartnerPayment>> getPartnerPayments(int partnerId) async {
    final shopId = await UserService.getCurrentShopId();
    final maps = await _db.database.then((db) => db.query(
      'repair_partner_payments',
      where: 'partnerId = ? AND shopId = ? AND deleted = 0',
      whereArgs: [partnerId, shopId],
      orderBy: 'paidAt DESC',
    ));
    return maps.map((map) => RepairPartnerPayment.fromMap(map)).toList();
  }

  Future<int> addPartnerPayment(RepairPartnerPayment payment) async {
    final id = await _db.database.then((db) => db.insert('repair_partner_payments', payment.toMap()));
    payment.id = id;
    await _syncToCloud(payment);
    return id;
  }

  Future<void> updatePartnerPayment(RepairPartnerPayment payment) async {
    await _db.database.then((db) => db.update(
      'repair_partner_payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    ));
    await _syncToCloud(payment);
  }

  Future<void> deletePartnerPayment(int id) async {
    await _db.database.then((db) => db.update(
      'repair_partner_payments',
      {'deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    ));
    // Soft delete in cloud
    final shopId = await UserService.getCurrentShopId();
    final docId = 'part_pay_${DateTime.now().millisecondsSinceEpoch}';
    await _firestore.collection('repair_partner_payments').doc(docId).set({
      'partnerId': id,
      'deleted': true,
      'shopId': shopId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _syncToCloud(RepairPartnerPayment payment) async {
    final shopId = await UserService.getCurrentShopId();
    final docId = payment.firestoreId ?? 'part_pay_${DateTime.now().millisecondsSinceEpoch}';
    payment.firestoreId = docId;
    await _db.database.then((db) => db.update(
      'repair_partner_payments',
      {'firestoreId': docId, 'isSynced': 1},
      where: 'id = ?',
      whereArgs: [payment.id],
    ));
    await _firestore.collection('repair_partner_payments').doc(docId).set({
      ...payment.toMap(),
      'shopId': shopId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, int>> getPaymentStats(int partnerId) async {
    final payments = await getPartnerPayments(partnerId);
    final stats = <String, int>{};
    for (var payment in payments) {
      stats[payment.paymentMethod] = (stats[payment.paymentMethod] ?? 0) + payment.amount;
    }
    return stats;
  }
}