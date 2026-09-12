import 'package:shared_preferences/shared_preferences.dart';

/// App ngân hàng người dùng chọn để mở bằng deeplink VietQR.
///
/// `https://dl.vietqr.io/pay` BẮT BUỘC có `app=<mã app>` — thiếu là VietQR
/// trả `{"message":"Missing parameter app"}` (lỗi chủ shop gặp trên iPhone
/// 2026-09-12 khi bấm "Mở app ngân hàng"). Mã app lấy từ danh sách chính thức
/// `https://api.vietqr.io/v2/android-app-deeplinks` (37 app, 2026-09); ở đây
/// giữ sẵn các app phổ biến để không phải gọi mạng, người dùng chọn một lần
/// rồi nhớ theo máy.
class BankAppOption {
  final String id;
  final String name;
  const BankAppOption(this.id, this.name);
}

class BankAppDeeplinkService {
  BankAppDeeplinkService._();

  static const String _prefKey = 'bank_app_deeplink_id';

  /// Thứ tự = mức phổ biến (ưu tiên hiện đầu danh sách).
  static const List<BankAppOption> apps = [
    BankAppOption('mb', 'MB Bank'),
    BankAppOption('vcb', 'Vietcombank'),
    BankAppOption('tcb', 'Techcombank'),
    BankAppOption('bidv', 'BIDV SmartBanking'),
    BankAppOption('icb', 'VietinBank iPay'),
    BankAppOption('vba', 'Agribank E-Mobile'),
    BankAppOption('acb', 'ACB One'),
    BankAppOption('tpb', 'TPBank'),
    BankAppOption('vpb', 'VPBank NEO'),
    BankAppOption('vib-2', 'MyVIB 2.0'),
    BankAppOption('shb', 'SHB Mobile'),
    BankAppOption('hdb', 'HDBank'),
    BankAppOption('ocb', 'OCB OMNI'),
    BankAppOption('lpb', 'LPBank (Liên Việt 24h)'),
    BankAppOption('seab', 'SeAMobile'),
    BankAppOption('scb', 'SCB Mobile'),
    BankAppOption('nab', 'Nam A Bank'),
    BankAppOption('eib', 'Eximbank'),
    BankAppOption('cake', 'CAKE by VPBank'),
    BankAppOption('timo', 'Timo'),
    BankAppOption('bvb', 'BAOVIET Smart'),
    BankAppOption('klb', 'KienlongBank Plus'),
    BankAppOption('ncb', 'NCB iziMobile'),
    BankAppOption('pvcb', 'PVcomBank'),
    BankAppOption('vab', 'VietABank'),
    BankAppOption('abb', 'ABBank (AB Ditizen)'),
    BankAppOption('vietbank', 'Vietbank Digital'),
    BankAppOption('sgicb', 'SAIGONBANK'),
    BankAppOption('shbvn', 'Shinhan Bank'),
    BankAppOption('wvn', 'Woori WON'),
    BankAppOption('cimb', 'OCTO by CIMB'),
    BankAppOption('pbvn', 'Public Bank'),
    BankAppOption('coopbank', 'Co-opBank'),
    BankAppOption('oceanbank', 'OceanBank'),
  ];

  static BankAppOption? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final a in apps) {
      if (a.id == id) return a;
    }
    return null;
  }

  static Future<BankAppOption?> getSelected() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return byId(prefs.getString(_prefKey));
    } catch (_) {
      return null;
    }
  }

  static Future<void> setSelected(BankAppOption? app) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (app == null) {
        await prefs.remove(_prefKey);
      } else {
        await prefs.setString(_prefKey, app.id);
      }
    } catch (_) {}
  }

  /// Link mở app. `ba/am/tn` là tham số VietQR (số TK@BIN, số tiền, nội dung)
  /// — hiện VietQR chỉ mở app, chưa điền sẵn, nhưng gửi kèm để sau này có.
  static Uri buildPayUri({
    required BankAppOption app,
    String? bankBin,
    String? accountNumber,
    int amount = 0,
    String addInfo = '',
  }) {
    final q = <String, String>{'app': app.id};
    if ((bankBin ?? '').isNotEmpty && (accountNumber ?? '').isNotEmpty) {
      q['ba'] = '$accountNumber@$bankBin';
    }
    if (amount > 0) q['am'] = amount.toString();
    if (addInfo.isNotEmpty) q['tn'] = addInfo;
    return Uri.https('dl.vietqr.io', '/pay', q);
  }
}
