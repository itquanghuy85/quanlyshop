import 'package:flutter/foundation.dart';

import 'finance_v2_data_service.dart';

/// Các "mảng" số liệu của một [FinanceV2Snapshot]. Dùng để invalidate CHỌN LỌC:
/// ghi một khoản thu chỉ làm bẩn [cash] + [transactions], không đụng [debt].
///
/// Snapshot hiện là MỘT object tính trọn gói (20 query SQLite song song), nên
/// "invalidate một mảng" không tính lại riêng mảng đó được — nó chỉ đánh dấu
/// bản cache **không còn tin được cho mảng ấy**. Màn hình đang mở tab không
/// bị ảnh hưởng thì tiếp tục dùng bản cũ, tới khi chuyển sang tab bị ảnh
/// hưởng mới tải lại. Đó là toàn bộ lợi ích: bớt được các lần tải lại vô ích.
enum FinanceSection { cash, profit, debt, transactions }

class _Entry {
  _Entry(this.snapshot, this.at);
  final FinanceV2Snapshot snapshot;
  final DateTime at;
  final Set<FinanceSection> stale = <FinanceSection>{};
}

/// Memory cache cho snapshot tài chính — key theo `shopId` + khoảng kỳ.
///
/// Mục tiêu (spec refactor 2026-09-18, PHẦN 4/5/10): mở Tiền → Lãi → Tiền →
/// đổi lọc → Lãi không được chạy lại 20 query SQLite mỗi bước. TTL ngắn
/// ([ttl]) chỉ là lưới an toàn cuối; nguồn invalidate CHÍNH là các sự kiện
/// nghiệp vụ qua [invalidate] — vừa ghi giao dịch thì không đợi TTL.
///
/// KHÔNG cache xuyên shop: [clear] được gọi khi đổi shop, và key luôn chứa
/// `shopId`. Khi không xác định được shop (chưa đăng nhập / test không có
/// Firebase) thì [key] trả `null` ⇒ không cache.
class FinanceV2Cache {
  FinanceV2Cache._();

  static const Duration ttl = Duration(seconds: 60);

  static final Map<String, _Entry> _entries = <String, _Entry>{};

  /// Số lần cache TRẢ LỜI ĐƯỢC (không phải tải lại) — để đo trong test/debug.
  @visibleForTesting
  static int hits = 0;

  @visibleForTesting
  static int misses = 0;

  static String? key({
    required String? shopId,
    required int startMs,
    required int endMs,
    required int previousStartMs,
    required int previousEndMs,
  }) {
    if (shopId == null || shopId.isEmpty) return null;
    return '$shopId|$startMs|$endMs|$previousStartMs|$previousEndMs';
  }

  /// Trả snapshot còn dùng được cho mọi mảng trong [needs] (mặc định: tất cả).
  static FinanceV2Snapshot? get(
    String? key, {
    Set<FinanceSection> needs = const {
      FinanceSection.cash,
      FinanceSection.profit,
      FinanceSection.debt,
      FinanceSection.transactions,
    },
  }) {
    if (key == null) return null;
    final e = _entries[key];
    if (e == null) {
      misses++;
      return null;
    }
    if (DateTime.now().difference(e.at) > ttl) {
      _entries.remove(key);
      misses++;
      return null;
    }
    if (e.stale.any(needs.contains)) {
      misses++;
      return null;
    }
    hits++;
    return e.snapshot;
  }

  static void put(String? key, FinanceV2Snapshot snapshot) {
    if (key == null) return;
    _entries[key] = _Entry(snapshot, DateTime.now());
  }

  /// Đánh dấu bẩn các mảng [sections] trên MỌI khoảng kỳ của mọi shop đang
  /// cache. `null` = bẩn toàn bộ (tương đương [clear] nhưng giữ lại bản cũ để
  /// màn hình còn cái mà vẽ trong lúc tải).
  static void invalidate([Set<FinanceSection>? sections]) {
    if (sections == null) {
      for (final e in _entries.values) {
        e.stale.addAll(FinanceSection.values);
      }
      return;
    }
    for (final e in _entries.values) {
      e.stale.addAll(sections);
    }
  }

  static void clear() => _entries.clear();

  @visibleForTesting
  static int get length => _entries.length;

  @visibleForTesting
  static void resetCounters() {
    hits = 0;
    misses = 0;
  }

  /// Tên sự kiện `EventBus` → các mảng bị ảnh hưởng. Là nguồn sự thật duy
  /// nhất cho cả `FinanceV2View` lẫn service; sự kiện không có trong bảng
  /// ⇒ không đụng tới cache.
  static Set<FinanceSection>? sectionsForEvent(String event) {
    switch (event) {
      case 'sales_changed':
      case 'sales_returns_changed':
      case 'repairs_changed':
        return const {
          FinanceSection.cash,
          FinanceSection.profit,
          FinanceSection.transactions,
        };
      case 'expenses_changed':
      case 'supplier_import_history_changed':
      case 'stock_entries_changed':
        return const {
          FinanceSection.cash,
          FinanceSection.profit,
          FinanceSection.transactions,
        };
      case 'debts_changed':
        return const {FinanceSection.debt};
      case 'debt_payments_changed':
      case 'repair_partner_payments_changed':
      case 'supplier_payments_changed':
      // Phát tại nguồn bởi PaymentIntentService.executePayment (BUG-06):
      // mọi thu/chi/thu nợ/trả NCC đều đi qua đây ⇒ Tiền + Giao dịch + Nợ.
      case 'payment_intents_changed':
        return const {
          FinanceSection.cash,
          FinanceSection.debt,
          FinanceSection.transactions,
        };
      case 'financial_activities_changed':
      case 'financial_activity_changed':
        return const {FinanceSection.transactions};
      case 'financial_changed':
      case 'SYNC_COMPLETE':
      case 'DATA_REFRESH':
        return null; // toàn bộ
      default:
        return const <FinanceSection>{};
    }
  }
}
