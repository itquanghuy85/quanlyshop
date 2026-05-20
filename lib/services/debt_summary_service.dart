import 'package:flutter/foundation.dart';
import '../data/db_helper.dart';
import '../models/repair_partner_model.dart';
import 'repair_partner_service.dart';

class DebtSummaryService {
  DebtSummaryService({DBHelper? dbHelper, RepairPartnerService? partnerService})
    : _db = dbHelper ?? DBHelper(),
      _partnerService = partnerService ?? RepairPartnerService();

  final DBHelper _db;
  final RepairPartnerService _partnerService;

  static bool isActiveDebt(Map<String, dynamic> debt) {
    final status = debt['status']?.toString().toUpperCase() ?? 'ACTIVE';
    if (status == 'PAID' || status == 'CANCELLED') return false;

    final totalAmount = (debt['totalAmount'] as num?)?.toInt() ?? 0;
    final paidAmount = (debt['paidAmount'] as num?)?.toInt() ?? 0;
    final remaining = (totalAmount - paidAmount).clamp(0, totalAmount);
    return remaining > 0 && totalAmount > 0;
  }

  List<Map<String, dynamic>> filterStandardDebts(
    List<Map<String, dynamic>> debts,
  ) {
    return debts.where((debt) {
      if ((debt['deleted'] ?? 0) == 1) return false;
      if (debt['type'] == 'REPAIR_PARTNER') return false;
      final firestoreId = debt['firestoreId']?.toString() ?? '';
      return !firestoreId.contains('debt_partner');
    }).toList();
  }

  Future<List<Map<String, dynamic>>> loadPartnerDebts({
    List<Map<String, dynamic>>? allDebts,
  }) async {
    final debts = allDebts ?? await _db.getAllDebts();
    final partners = await _partnerService.getRepairPartners();
    final activePartnerIds = partners.map((p) => p.id).whereType<int>().toSet();

    final partnerDebtChunks = await Future.wait(
      partners.map((partner) async {
        final partnerId = partner.id;
        if (partnerId == null) return <Map<String, dynamic>>[];

        final stats = await _partnerService.getPartnerRepairStats(
          partnerId,
          partnerFirestoreId: partner.firestoreId,
          partnerName: partner.name,
        );
        final totalCost = (stats?['totalCost'] as num?)?.toInt() ?? 0;
        final totalPaid = (stats?['totalPaid'] as num?)?.toInt() ?? 0;
        final totalRepairs = (stats?['totalOrders'] as num?)?.toInt() ?? 0;
        final remain = totalCost - totalPaid;

        if (remain <= 0) return <Map<String, dynamic>>[];

        return <Map<String, dynamic>>[
          {
            'id': partnerId,
            'partnerId': partnerId,
            'name': partner.name,
            'partnerName': partner.name,
            'phone': partner.phone,
            'totalCost': totalCost,
            'totalAmount': totalCost,
            'totalPaid': totalPaid,
            'paidAmount': totalPaid,
            'totalRepairs': totalRepairs,
            'remainingDebt': remain,
            'remain': remain,
            'type': 'REPAIR_PARTNER',
            'createdAt': partner.createdAt,
            'source': 'repairs',
            'missingPartner': false,
          },
        ];
      }),
    );
    final partnerDebts = partnerDebtChunks.expand((chunk) => chunk).toList();

    // --- Orphan partners: deleted/deactivated but still have unpaid balances ---
    final allPartnerRows = await _db.getAllRepairPartnersRaw();
    final orphanRows = allPartnerRows.where((row) {
      final id = row['id'] as int?;
      if (id == null) return false;
      if (activePartnerIds.contains(id)) return false; // already handled
      return true; // deleted or deactivated
    }).toList();

    for (final row in orphanRows) {
      final partnerId = row['id'] as int?;
      if (partnerId == null) continue;
      final partnerName = (row['name'] as String? ?? '').trim();
      final firestoreId = row['firestoreId'] as String?;

      final stats = await _partnerService.getPartnerRepairStats(
        partnerId,
        partnerFirestoreId: firestoreId,
        partnerName: partnerName.isNotEmpty ? partnerName : null,
      );
      final totalCost = (stats?['totalCost'] as num?)?.toInt() ?? 0;
      final totalPaid = (stats?['totalPaid'] as num?)?.toInt() ?? 0;
      final totalRepairs = (stats?['totalOrders'] as num?)?.toInt() ?? 0;
      final remain = totalCost - totalPaid;

      if (remain <= 0) continue;

      debugPrint(
        '⚠️ [DebtSummary] Orphan partner debt: id=$partnerId name="$partnerName" remain=$remain',
      );
      partnerDebts.add({
        'id': partnerId,
        'partnerId': partnerId,
        'name': partnerName.isNotEmpty ? partnerName : '[Đối tác đã xóa]',
        'partnerName': partnerName.isNotEmpty ? partnerName : '[Đối tác đã xóa]',
        'phone': row['phone'] ?? '',
        'totalCost': totalCost,
        'totalAmount': totalCost,
        'totalPaid': totalPaid,
        'paidAmount': totalPaid,
        'totalRepairs': totalRepairs,
        'remainingDebt': remain,
        'remain': remain,
        'type': 'REPAIR_PARTNER',
        'createdAt': row['createdAt'],
        'source': 'repairs',
        'missingPartner': true,
      });
    }

    // --- Manual partner debts from the debts table ---
    final manualPartnerDebts = debts.where((debt) {
      final total = (debt['totalAmount'] as num?)?.toInt() ?? 0;
      final paid = (debt['paidAmount'] as num?)?.toInt() ?? 0;
      final firestoreId = debt['firestoreId']?.toString() ?? '';
      if ((debt['deleted'] ?? 0) == 1) return false;
      if ((total - paid) <= 0) return false;
      return debt['type'] == 'REPAIR_PARTNER' ||
          firestoreId.contains('debt_partner');
    });

    for (final debt in manualPartnerDebts) {
      final total = (debt['totalAmount'] as num?)?.toInt() ?? 0;
      final paid = (debt['paidAmount'] as num?)?.toInt() ?? 0;
      final remain = total - paid;
      final debtId = debt['id'];
      final personName = debt['personName'] as String?;

      // Try to find the matching active partner by name to get the real partnerId
      RepairPartner? matchedPartner;
      if (personName != null && personName.isNotEmpty) {
        final upperName = personName.trim().toUpperCase();
        try {
          matchedPartner = partners.firstWhere(
            (p) => p.name.trim().toUpperCase() == upperName,
          );
        } catch (_) {
          matchedPartner = null;
        }
      }

      // Skip if this manual debt is already represented by an auto-detected entry
      if (matchedPartner != null) {
        final alreadyListed = partnerDebts.any(
          (d) => d['partnerId'] == matchedPartner!.id,
        );
        if (alreadyListed) continue;
      }

      if (matchedPartner == null) {
        debugPrint(
          '⚠️ [DebtSummary] Manual debt with no partner: debtId=$debtId name="$personName" remain=$remain',
        );
      }

      partnerDebts.add({
        'id': matchedPartner?.id ?? debtId,
        'partnerId': matchedPartner?.id,
        'name': personName ?? 'Không rõ',
        'partnerName': personName ?? 'Không rõ',
        'phone': debt['phone'] ?? '',
        'totalCost': total,
        'totalAmount': total,
        'totalPaid': paid,
        'paidAmount': paid,
        'totalRepairs': 0,
        'remainingDebt': remain,
        'remain': remain,
        'type': 'REPAIR_PARTNER',
        'createdAt': debt['createdAt'],
        'source': 'manual',
        'firestoreId': debt['firestoreId'],
        'note': debt['note'],
        'missingPartner': matchedPartner == null,
      });
    }

    return partnerDebts;
  }

  Future<Map<String, int>> getDebtOverview() async {
    final allDebts = await _db.getAllDebts();
    final visibleDebts = filterStandardDebts(allDebts);
    final partnerDebts = await loadPartnerDebts(allDebts: allDebts);

    int customerRemain = 0;
    int supplierRemain = 0;
    for (final debt in visibleDebts) {
      if (!isActiveDebt(debt)) continue;

      final debtType = debt['type']?.toString() ?? '';
      final total = (debt['totalAmount'] as num?)?.toInt() ?? 0;
      final paid = (debt['paidAmount'] as num?)?.toInt() ?? 0;
      final remain = (total - paid).clamp(0, total);

      if (debtType == 'CUSTOMER_OWES' ||
          debtType == 'OWE' ||
          debtType == 'OTHER_CUSTOMER_OWES') {
        customerRemain += remain;
      } else if (debtType == 'SHOP_OWES' ||
          debtType == 'OWED' ||
          debtType == 'OTHER_SHOP_OWES') {
        supplierRemain += remain;
      }
    }

    final partnerRemain = partnerDebts.fold<int>(
      0,
      (sum, debt) => sum + ((debt['remainingDebt'] as num?)?.toInt() ?? 0),
    );

    return {
      'customerRemain': customerRemain,
      'supplierRemain': supplierRemain,
      'partnerRemain': partnerRemain,
      'totalRemain': customerRemain + supplierRemain + partnerRemain,
    };
  }
}
