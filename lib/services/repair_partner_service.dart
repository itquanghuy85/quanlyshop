import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/repair_partner_model.dart';
import '../models/partner_repair_history_model.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';

class RepairPartnerService {
  final db = DBHelper();

  // Repair Partner CRUD
  Future<List<RepairPartner>> getRepairPartners() async {
    final shopId = await UserService.getCurrentShopId();
    final data = await db.getRepairPartners();
    return data
        .where((p) => p['shopId'] == shopId)
        .map((p) => RepairPartner.fromMap(p))
        .toList();
  }

  Future<RepairPartner?> addRepairPartner(RepairPartner partner) async {
    final partnerMap = partner.toMap();
    partnerMap['shopId'] = await UserService.getCurrentShopId();
    partnerMap['createdAt'] = DateTime.now().millisecondsSinceEpoch;
    partnerMap['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

    final id = await db.insertRepairPartner(partnerMap);
    if (id > 0) {
      final firestoreId = await FirestoreService.addRepairPartner(partnerMap);
      if (firestoreId != null) {
        await db.updateRepairPartner(id, {'firestoreId': firestoreId});
        return partner.copyWith(id: id);
      }
    }
    return null;
  }

  Future<bool> updateRepairPartner(RepairPartner partner) async {
    final partnerMap = partner.toMap();
    partnerMap['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

    final result = await db.updateRepairPartner(partner.id!, partnerMap);
    if (result > 0) {
      await FirestoreService.updateRepairPartner(partnerMap);
      return true;
    }
    return false;
  }

  Future<bool> deleteRepairPartner(int partnerId) async {
    final result = await db.deleteRepairPartner(partnerId);
    if (result > 0) {
      await FirestoreService.deleteRepairPartner(partnerId);
      return true;
    }
    return false;
  }

  // Partner Repair History
  Future<PartnerRepairHistory?> addPartnerRepairHistory(PartnerRepairHistory history) async {
    final historyMap = history.toMap();
    historyMap['shopId'] = await UserService.getCurrentShopId();
    historyMap['sentAt'] = DateTime.now().millisecondsSinceEpoch;

    final id = await db.insertPartnerRepairHistory(historyMap);
    if (id > 0) {
      final firestoreId = await FirestoreService.addPartnerRepairHistory(historyMap);
      if (firestoreId != null) {
        await db.updatePartnerRepairHistory(id, {'firestoreId': firestoreId});
        return history.copyWith(id: id);
      }
    }
    return null;
  }

  Future<List<PartnerRepairHistory>> getPartnerRepairHistory({int? partnerId, String? repairOrderId}) async {
    final shopId = await UserService.getCurrentShopId();
    final data = await db.getPartnerRepairHistory(partnerId: partnerId, repairOrderId: repairOrderId);
    return data
        .where((h) => h['shopId'] == shopId)
        .map((h) => PartnerRepairHistory.fromMap(h))
        .toList();
  }

  Future<Map<String, dynamic>?> getPartnerRepairStats(int partnerId) async {
    return await db.getPartnerRepairStats(partnerId);
  }

  // Combined operation for repair order with partner
  Future<bool> createPartnerHistoryForRepair({
    required String repairOrderId,
    required int partnerId,
    required int partnerCost,
    required String customerName,
    required String deviceModel,
    required String issue,
    String? repairContent,
  }) async {
    final history = PartnerRepairHistory(
      repairOrderId: repairOrderId,
      partnerId: partnerId,
      customerName: customerName,
      deviceModel: deviceModel,
      issue: issue,
      partnerCost: partnerCost,
      repairContent: repairContent,
      sentAt: DateTime.now().millisecondsSinceEpoch,
      shopId: await UserService.getCurrentShopId() ?? '',
    );

    final result = await addPartnerRepairHistory(history);
    return result != null;
  }
}