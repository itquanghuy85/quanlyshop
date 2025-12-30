import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/db_helper.dart';

class DebtAnalysisView extends StatelessWidget {
  const DebtAnalysisView({super.key});

  Future<String> _analyzeDebts() async {
    final db = DBHelper();
    final debts = await db.getAllDebts();

    StringBuffer analysis = StringBuffer();
    analysis.writeln('=== PHÂN TÍCH DỮ LIỆU NỢ ===\n');
    analysis.writeln('Tổng số records: ${debts.length}\n');

    // Logic Home View (tất cả nợ còn lại > 0)
    int homeTotal = 0;
    analysis.writeln('--- LOGIC HOME VIEW (tất cả nợ) ---');
    for (var d in debts) {
      final int total = d['totalAmount'] ?? 0;
      final int paid = d['paidAmount'] ?? 0;
      final int remain = total - paid;
      if (remain > 0) {
        homeTotal += remain;
        analysis.writeln('ID ${d['id']}: ${d['personName']} - Total: $total, Paid: $paid, Remain: $remain');
      }
    }
    analysis.writeln('TỔNG HOME VIEW: $homeTotal đ\n');

    // Logic Debt View (theo loại)
    final customerOwes = debts.where((d) => d['type'] == 'CUSTOMER_OWES' && (d['status'] != 'paid')).toList();
    final shopOwes = debts.where((d) => d['type'] == 'SHOP_OWES' && (d['status'] != 'paid')).toList();

    analysis.writeln('--- LOGIC DEBT VIEW (theo loại, status != paid) ---');
    analysis.writeln('Khách nợ (${customerOwes.length} records):');
    int customerTotal = 0;
    for (var d in customerOwes) {
      final int total = d['totalAmount'] as int;
      final int paid = d['paidAmount'] as int? ?? 0;
      final int remain = total - paid;
      if (remain > 0) {
        customerTotal += remain;
        analysis.writeln('  ID ${d['id']}: ${d['personName']} - Total: $total, Paid: $paid, Remain: $remain, Status: ${d['status']}');
      }
    }

    analysis.writeln('Shop nợ NCC (${shopOwes.length} records):');
    int shopTotal = 0;
    for (var d in shopOwes) {
      final int total = d['totalAmount'] as int;
      final int paid = d['paidAmount'] as int? ?? 0;
      final int remain = total - paid;
      if (remain > 0) {
        shopTotal += remain;
        analysis.writeln('  ID ${d['id']}: ${d['personName']} - Total: $total, Paid: $paid, Remain: $remain, Status: ${d['status']}');
      }
    }

    analysis.writeln('TỔNG DEBT VIEW: ${customerTotal + shopTotal} đ (Khách: $customerTotal + Shop: $shopTotal)\n');

    // Chi tiết tất cả records
    analysis.writeln('--- TẤT CẢ RECORDS ---');
    for (var d in debts) {
      analysis.writeln('ID ${d['id']}: ${d['personName']} (${d['type']}) - Total: ${d['totalAmount']}, Paid: ${d['paidAmount'] ?? 0}, Status: ${d['status']}, Phone: ${d['phone']}');
    }

    return analysis.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phân tích dữ liệu nợ')),
      body: FutureBuilder<String>(
        future: _analyzeDebts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              snapshot.data ?? 'Không có dữ liệu',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          );
        },
      ),
    );
  }
}