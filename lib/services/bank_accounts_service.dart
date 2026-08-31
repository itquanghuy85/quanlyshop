// BankAccountsService - đọc tài khoản ngân hàng NHẬN chuyển khoản của shop.
//
// MỤC ĐÍCH:
// - Cung cấp thông tin TK ngân hàng cho widget "Thanh toán qua ngân hàng"
//   (mã QR VietQR + nút mở app ngân hàng) trong các sheet thanh toán.
// - KHÔNG đụng logic tiền. Chỉ đọc cấu hình.
//
// NGUỒN DỮ LIỆU (tái dùng cấu hình sẵn có ở `bank_qr_settings_view.dart`):
// - SharedPreferences: bank_qr_bin / bank_qr_name / bank_qr_account /
//   bank_qr_holder  (mirror offline, ghi bởi màn cài đặt).
// - Firestore: shops/{shopId}/settings/bank_qr  (bankBin/bankName/
//   accountNumber/accountHolder). Nếu doc có mảng `accounts` (mở rộng sau)
//   thì đọc luôn — tương thích ngược.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_service.dart';
import '../utils/vietqr_builder.dart';

/// 1 tài khoản ngân hàng nhận chuyển khoản.
class BankAccount {
  final String bankBin;
  final String bankName;
  final String accountNumber;
  final String accountHolder;

  const BankAccount({
    required this.bankBin,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
  });

  bool get isComplete =>
      bankBin.trim().isNotEmpty && accountNumber.trim().isNotEmpty;

  /// Tên NH hiển thị — ưu tiên tên đã lưu, fallback tra theo BIN.
  String get displayBankName {
    if (bankName.trim().isNotEmpty) return bankName.trim();
    final b = vietQrBanks.where((x) => x.bin == bankBin).firstOrNull;
    return b?.shortName ?? 'Ngân hàng';
  }

  Map<String, dynamic> toJson() => {
        'bankBin': bankBin,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountHolder': accountHolder,
      };

  static BankAccount? fromJson(Map<String, dynamic>? m) {
    if (m == null) return null;
    final acc = BankAccount(
      bankBin: (m['bankBin'] ?? '').toString().trim(),
      bankName: (m['bankName'] ?? '').toString().trim(),
      accountNumber: (m['accountNumber'] ?? '').toString().trim(),
      accountHolder: (m['accountHolder'] ?? '').toString().trim(),
    );
    return acc.isComplete ? acc : null;
  }
}

class BankAccountsService {
  BankAccountsService._();
  static final BankAccountsService instance = BankAccountsService._();

  /// TK mặc định hiện tại (null nếu shop chưa cấu hình). Widget lắng nghe để
  /// tự cập nhật sau khi người dùng lưu ở màn cài đặt.
  final ValueNotifier<BankAccount?> defaultAccount = ValueNotifier<BankAccount?>(null);

  bool _prefsLoaded = false;

  /// Đọc nhanh từ SharedPreferences (offline). Gọi sớm, không chặn UI.
  Future<BankAccount?> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final acc = BankAccount(
        bankBin: (prefs.getString('bank_qr_bin') ?? '').trim(),
        bankName: (prefs.getString('bank_qr_name') ?? '').trim(),
        accountNumber: (prefs.getString('bank_qr_account') ?? '').trim(),
        accountHolder: (prefs.getString('bank_qr_holder') ?? '').trim(),
      );
      _prefsLoaded = true;
      if (acc.isComplete) {
        defaultAccount.value = acc;
        return acc;
      }
    } catch (e) {
      debugPrint('BankAccountsService.loadFromPrefs: $e');
    }
    return null;
  }

  /// Làm mới từ Firestore (khi mở sheet thanh toán / màn cài đặt).
  Future<BankAccount?> refreshFromCloud() async {
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null || shopId.isEmpty) {
        return defaultAccount.value;
      }
      final doc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('settings')
          .doc('bank_qr')
          .get();
      if (!doc.exists) return defaultAccount.value;
      final data = doc.data() ?? {};

      // Ưu tiên mảng `accounts` (mở rộng đa TK về sau), nếu có.
      final rawList = data['accounts'];
      BankAccount? picked;
      if (rawList is List && rawList.isNotEmpty) {
        BankAccount? firstOk;
        for (final e in rawList) {
          final a = BankAccount.fromJson(
            e is Map ? Map<String, dynamic>.from(e) : null,
          );
          if (a == null) continue;
          firstOk ??= a;
          if (e is Map && (e['isDefault'] == true || e['isDefault'] == 1)) {
            picked = a;
            break;
          }
        }
        picked ??= firstOk;
      }
      // Fallback field phẳng cũ.
      picked ??= BankAccount.fromJson({
        'bankBin': data['bankBin'],
        'bankName': data['bankName'],
        'accountNumber': data['accountNumber'],
        'accountHolder': data['accountHolder'],
      });

      if (picked != null && picked.isComplete) {
        defaultAccount.value = picked;
      }
      return defaultAccount.value;
    } catch (e) {
      debugPrint('BankAccountsService.refreshFromCloud: $e');
      return defaultAccount.value;
    }
  }

  /// Đảm bảo đã có dữ liệu (prefs) + kích hoạt refresh cloud nền.
  Future<BankAccount?> ensureLoaded() async {
    if (!_prefsLoaded) {
      await loadFromPrefs();
    }
    // Refresh cloud không chặn — cập nhật notifier khi xong.
    unawaited(refreshFromCloud());
    return defaultAccount.value;
  }
}
