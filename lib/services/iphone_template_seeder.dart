import '../data/db_helper.dart';
import '../models/quick_input_code_model.dart';

/// Seeder tạo mã nhập nhanh cho dòng iPhone X → 17 ProMax.
/// Format: code=13PROMAX128GXANH99  name=IPHONE 13PROMAX 128G XANH 99%
/// Idempotent — chạy lại không tạo duplicate (kiểm tra theo trường code).
class IphoneTemplateSeeder {
  // ─── Colors ───────────────────────────────────────────────────────────────
  static const _den        = _IColor('ĐEN',         'DEN');
  static const _trang      = _IColor('TRẮNG',       'TRANG');
  static const _xanh       = _IColor('XANH',        'XANH');
  static const _hong       = _IColor('HỒNG',        'HONG');
  static const _vang       = _IColor('VÀNG',        'VANG');
  static const _do         = _IColor('ĐỎ',          'DO');
  static const _tim        = _IColor('TÍM',         'TIM');
  static const _bac        = _IColor('BẠC',         'BAC');
  static const _xanhLa     = _IColor('XANH LÁ',     'XANHLA');
  static const _xanhDem    = _IColor('XANH ĐÊM',    'XANHDEM');
  static const _xanhDuong  = _IColor('XANH DƯƠNG',  'XANHDUONG');
  static const _xanhSierra = _IColor('XANH SIERRA', 'XANHSIERRA');
  static const _timDam     = _IColor('TÍM ĐẬM',     'TIMDAM');
  static const _denTitan   = _IColor('ĐEN TITAN',   'DENTITAN');
  static const _trangTitan = _IColor('TRẮNG TITAN', 'TRANGTITAN');
  static const _tuNhien    = _IColor('TỰ NHIÊN',    'TUNHIEN');
  static const _saMac      = _IColor('SA MẠC',      'SAMAC');
  static const _xanhTitan  = _IColor('XANH TITAN',  'XANHTITAN');

  // ─── Conditions ───────────────────────────────────────────────────────────
  static const _c99  = _ICond('99%', '99');
  static const _cNew = _ICond('NEW', 'NEW');

  // ─── Storages ─────────────────────────────────────────────────────────────
  static const _s64  = '64G';
  static const _s128 = '128G';
  static const _s256 = '256G';
  static const _s512 = '512G';
  static const _s1T  = '1T';

  // ─── Model definitions ────────────────────────────────────────────────────
  static List<_IModel> get _models => [
    _IModel('X',        'iPhone X',         [_den, _bac],                                 [_s64, _s256],             [_c99]),
    _IModel('XS',       'iPhone XS',        [_den, _bac, _vang],                          [_s64, _s256, _s512],      [_c99]),
    _IModel('XSMAX',    'iPhone XS Max',    [_den, _bac, _vang],                          [_s64, _s256, _s512],      [_c99]),
    _IModel('XR',       'iPhone XR',        [_den, _trang, _xanh, _vang, _do],            [_s64, _s128, _s256],      [_c99]),
    _IModel('11',       'iPhone 11',        [_den, _trang, _xanh, _vang, _do, _tim],      [_s64, _s128, _s256],      [_c99]),
    _IModel('11PRO',    'iPhone 11 Pro',    [_den, _bac, _vang, _xanhDem],                [_s64, _s256, _s512],      [_c99]),
    _IModel('11PROMAX', 'iPhone 11 Pro Max',[_den, _bac, _vang, _xanhDem],                [_s64, _s256, _s512],      [_c99]),
    _IModel('12MINI',   'iPhone 12 Mini',   [_den, _trang, _xanh, _do, _tim, _hong],      [_s64, _s128, _s256],      [_c99]),
    _IModel('12',       'iPhone 12',        [_den, _trang, _xanh, _do, _tim, _hong],      [_s64, _s128, _s256],      [_c99]),
    _IModel('12PRO',    'iPhone 12 Pro',    [_den, _bac, _vang, _xanhDuong],              [_s128, _s256, _s512],     [_c99]),
    _IModel('12PROMAX', 'iPhone 12 Pro Max',[_den, _bac, _vang, _xanhDuong],              [_s128, _s256, _s512],     [_c99]),
    _IModel('13MINI',   'iPhone 13 Mini',   [_den, _trang, _xanh, _hong, _xanhLa, _do],  [_s128, _s256, _s512],     [_c99]),
    _IModel('13',       'iPhone 13',        [_den, _trang, _xanh, _hong, _xanhLa, _do],  [_s128, _s256, _s512],     [_c99]),
    _IModel('13PRO',    'iPhone 13 Pro',    [_den, _bac, _vang, _xanhSierra, _xanhLa],   [_s128, _s256, _s512, _s1T],[_c99]),
    _IModel('13PROMAX', 'iPhone 13 Pro Max',[_den, _bac, _vang, _xanhSierra, _xanhLa],   [_s128, _s256, _s512, _s1T],[_c99]),
    _IModel('14',       'iPhone 14',        [_den, _trang, _xanh, _tim, _do, _vang],      [_s128, _s256, _s512],     [_c99]),
    _IModel('14PLUS',   'iPhone 14 Plus',   [_den, _trang, _xanh, _tim, _do, _vang],      [_s128, _s256, _s512],     [_c99]),
    _IModel('14PRO',    'iPhone 14 Pro',    [_den, _bac, _vang, _timDam],                 [_s128, _s256, _s512, _s1T],[_c99]),
    _IModel('14PROMAX', 'iPhone 14 Pro Max',[_den, _bac, _vang, _timDam],                 [_s128, _s256, _s512, _s1T],[_c99]),
    _IModel('15',       'iPhone 15',        [_den, _xanh, _xanhLa, _hong, _vang],         [_s128, _s256, _s512],     [_c99]),
    _IModel('15PLUS',   'iPhone 15 Plus',   [_den, _xanh, _xanhLa, _hong, _vang],         [_s128, _s256, _s512],     [_c99]),
    _IModel('15PRO',    'iPhone 15 Pro',    [_denTitan, _trangTitan, _tuNhien, _xanhTitan],[_s128, _s256, _s512, _s1T],[_c99]),
    _IModel('15PROMAX', 'iPhone 15 Pro Max',[_denTitan, _trangTitan, _tuNhien, _xanhTitan],[_s256, _s512, _s1T],      [_c99]),
    _IModel('16',       'iPhone 16',        [_den, _trang, _xanh, _hong, _xanhLa, _tim],  [_s128, _s256, _s512],     [_c99, _cNew]),
    _IModel('16PLUS',   'iPhone 16 Plus',   [_den, _trang, _xanh, _hong, _xanhLa, _tim],  [_s128, _s256, _s512],     [_c99, _cNew]),
    _IModel('16PRO',    'iPhone 16 Pro',    [_denTitan, _trangTitan, _tuNhien, _saMac],    [_s128, _s256, _s512, _s1T],[_c99, _cNew]),
    _IModel('16PROMAX', 'iPhone 16 Pro Max',[_denTitan, _trangTitan, _tuNhien, _saMac],    [_s256, _s512, _s1T],      [_c99, _cNew]),
    _IModel('17',       'iPhone 17',        [_den, _trang, _xanh, _hong, _xanhLa],        [_s128, _s256, _s512],     [_c99, _cNew]),
    _IModel('17AIR',    'iPhone 17 Air',    [_den, _trang, _xanh, _hong],                 [_s128, _s256, _s512],     [_c99, _cNew]),
    _IModel('17PRO',    'iPhone 17 Pro',    [_denTitan, _trangTitan, _tuNhien, _saMac],    [_s256, _s512, _s1T],      [_c99, _cNew]),
    _IModel('17PROMAX', 'iPhone 17 Pro Max',[_denTitan, _trangTitan, _tuNhien, _saMac],    [_s256, _s512, _s1T],      [_c99, _cNew]),
  ];

  /// Seed tất cả mã iPhone. Trả về số record mới tạo.
  static Future<int> seed(DBHelper db, String shopId) async {
    final existing = await db.getQuickInputCodes();
    final existingCodes = existing.map((e) => e.code ?? '').toSet();

    final now = DateTime.now().millisecondsSinceEpoch;
    int created = 0;

    for (final m in _models) {
      for (final color in m.colors) {
        for (final storage in m.storages) {
          for (final cond in m.conds) {
            final code = '${m.code}${storage}${color.code}${cond.code}';
            if (existingCodes.contains(code)) continue;

            final name = 'IPHONE ${m.code} $storage ${color.name} ${cond.name}';
            final entry = QuickInputCode(
              code:          code,
              name:          name,
              type:          'DIEN_THOAI',
              brand:         'Apple',
              model:         m.displayName,
              capacity:      storage == _s1T ? '1TB' : '${storage.replaceAll('G', '')}GB',
              color:         color.name,
              condition:     cond.name,
              cost:          null,
              price:         null,
              description:   null,
              labelInfo:     null,
              supplier:      null,
              paymentMethod: null,
              shopId:        shopId,
              isActive:      true,
              createdAt:     now + created,
              isSynced:      false,
              firestoreId:   'iph_seed_${code.toLowerCase()}',
            );
            await db.insertQuickInputCode(entry);
            created++;
          }
        }
      }
    }
    return created;
  }
}

// ─── Private data classes ─────────────────────────────────────────────────────
class _IColor {
  final String name; // Có dấu, dùng trong name display
  final String code; // Không dấu, không khoảng cách, dùng trong code lookup
  const _IColor(this.name, this.code);
}

class _ICond {
  final String name; // 99% hoặc NEW
  final String code; // 99 hoặc NEW
  const _ICond(this.name, this.code);
}

class _IModel {
  final String code;
  final String displayName;
  final List<_IColor> colors;
  final List<String> storages;
  final List<_ICond> conds;
  const _IModel(this.code, this.displayName, this.colors, this.storages, this.conds);
}
