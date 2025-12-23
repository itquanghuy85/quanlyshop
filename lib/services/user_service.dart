import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserService {
    // Validate input fields
    static String? validateName(String name) {
      if (name.trim().isEmpty) return 'Tên không được để trống';
      return null;
    }

    static String? validatePhone(String phone) {
      final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (cleaned.length < 9 || cleaned.length > 12) {
        return 'Số điện thoại phải có 9-12 chữ số';
      }
      return null;
    }

    static String? validateAddress(String address) {
      if (address.trim().isEmpty) return 'Địa chỉ không được để trống';
      return null;
    }

  static final _db = FirebaseFirestore.instance;
  static String? _cachedShopId;

  // Method để cập nhật cache shopId từ bên ngoài (dùng cho sync)
  static void updateCachedShopId(String? shopId) {
    _cachedShopId = shopId;
  }

  static bool _isSuperAdmin(User? user) {
    return user?.email == 'admin@huluca.com';
  }

  static bool isCurrentUserSuperAdmin() {
    return _isSuperAdmin(FirebaseAuth.instance.currentUser);
  }

  static Map<String, bool> _defaultPermissionsForRole(String role) {
    final isOwner = role == 'owner';
    final isManager = role == 'manager';
    final isEmployee = role == 'employee';
    final isAdmin = role == 'admin'; // Thêm case cho admin
    
    return {
      // Chủ shop: toàn quyền
      // Quản lý: xem được tất cả, quản lý nhân viên
      // Nhân viên: xem nghiệp vụ cơ bản, không xem tài chính
      // Kỹ thuật: chỉ xem sửa chữa, linh kiện, khách hàng
      // Admin: toàn quyền như owner
      'allowViewSales': isOwner || isManager || isEmployee || isAdmin,
      'allowViewRepairs': true, // Tất cả đều xem được repairs
      'allowViewInventory': isOwner || isManager || isEmployee || isAdmin,
      'allowViewParts': true, // Tất cả đều cần xem linh kiện
      'allowViewSuppliers': isOwner || isManager || isEmployee || isAdmin,
      'allowViewCustomers': true, // Tất cả đều cần xem khách hàng
      'allowViewWarranty': isOwner || isManager || isEmployee || isAdmin,
      'allowViewChat': true,
      'allowViewPrinter': true,
      'allowViewRevenue': isOwner || isManager || isAdmin,
      'allowViewExpenses': isOwner || isManager || isAdmin,
      'allowViewDebts': isOwner || isManager || isAdmin,
      'allowViewSettings': isOwner || isManager || isAdmin,
      'shopAppLocked': false,
      'shopAdminFinanceLocked': false,
    };
  }

  static Future<String?> getCurrentShopId() async {
    if (_cachedShopId != null) {
      debugPrint("getCurrentShopId: trả về cache $_cachedShopId");
      return _cachedShopId;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint("getCurrentShopId: không có currentUser");
      return null;
    }
    if (_isSuperAdmin(currentUser)) {
      debugPrint("getCurrentShopId: super admin, trả về null");
      return null; // Super admin không bị khóa bởi shopId
    }

    try {
      debugPrint("getCurrentShopId: lấy dữ liệu user ${currentUser.uid}");
      final doc = await _db.collection('users').doc(currentUser.uid).get();
      final data = doc.data();
      final shopId = data != null ? data['shopId'] as String? : null;
      _cachedShopId = shopId;
      debugPrint("getCurrentShopId: shopId = $shopId");
      return shopId;
    } catch (e) {
      debugPrint("getCurrentShopId: lỗi $e");
      return null;
    }
  }

  // Lấy quyền của người dùng (Có nhận diện Admin đặc biệt)
  static Future<String> getUserRole(String uid) async {
    // CAO KIẾN: Nhận diện Admin tối cao qua Email
    final currentUser = FirebaseAuth.instance.currentUser;
    debugPrint("getUserRole: currentUser email = ${currentUser?.email}");
    if (currentUser?.email == 'admin@huluca.com') {
      debugPrint("getUserRole: returning admin for super admin");
      return 'admin'; // Luôn là Admin nếu dùng email này
    }

    try {
      final doc = await _db.collection('users').doc(uid).get();
      final role = doc.data()?['role'] ?? 'user';
      debugPrint("getUserRole: role from firestore = $role");
      return role;
    } catch (e) {
      debugPrint("getUserRole: error $e, returning user");
      return 'user';
    }
  }

  static Future<Map<String, dynamic>> getUserInfo(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data() ?? {};
  }

  static Stream<QuerySnapshot> getAllUsersStream() {
    final currentUser = FirebaseAuth.instance.currentUser;

    // Super admin xem được toàn bộ
    if (currentUser != null && _isSuperAdmin(currentUser)) {
      return _db.collection('users').snapshots();
    }

    // Người dùng thường: ưu tiên lọc theo shopId nếu đã có
    final shopId = _cachedShopId;
    if (shopId != null && shopId.trim().isNotEmpty) {
      return _db.collection('users').where('shopId', isEqualTo: shopId).snapshots();
    }

    // Trường hợp chưa đồng bộ shopId, tạm thời trả toàn bộ (sẽ thu hẹp sau khi syncUserInfo chạy)
    return _db.collection('users').snapshots();
  }

  static Future<void> updateUserInfo({
    required String uid,
    required String name,
    required String phone,
    required String address,
    required String role,
    String? photoUrl,
    String? shopId,
  }) async {
    // Validate input
    final nameError = validateName(name);
    final phoneError = validatePhone(phone);
    final addressError = validateAddress(address);
    if (nameError != null || phoneError != null || addressError != null) {
      throw Exception([
        if (nameError != null) nameError,
        if (phoneError != null) phoneError,
        if (addressError != null) addressError
      ].join(' | '));
    }

    // Cập nhật dữ liệu người dùng
    final updateData = {
      'displayName': name.toUpperCase(),
      'phone': phone,
      'address': address.toUpperCase(),
      'role': role,
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (shopId != null) {
      updateData['shopId'] = shopId;
    }
    await _db.collection('users').doc(uid).set(updateData, SetOptions(merge: true));

    // Đồng bộ dữ liệu liên quan (ví dụ: cập nhật tên, số điện thoại ở các bảng khác nếu cần)
    // TODO: Nếu có bảng orders, repair_orders,... thì cập nhật thông tin liên quan ở đó
  }

  static Future<void> syncUserInfo(String uid, String email, {Map<String, dynamic>? extra}) async {
    // Lấy thông tin hiện tại để đồng bộ
    final userRef = _db.collection('users').doc(uid);
    final userDoc = await userRef.get();
    final data = userDoc.data() ?? {};

    final bool isSuperAdmin = email == 'admin@huluca.com';
    String? shopId = data['shopId'];

    // Nếu chưa có shopId và không phải super admin => tạo 1 shop trùng với uid
    if (!isSuperAdmin && (shopId == null || shopId.trim().isEmpty)) {
      shopId = uid;
      await _db.collection('shops').doc(shopId).set({
        'ownerUid': uid,
        'ownerEmail': email,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    _cachedShopId = shopId is String ? shopId : null;

    final userData = {
      'email': email,
      'displayName': data['displayName'] ?? '',
      'phone': data['phone'] ?? '',
      'address': data['address'] ?? '',
      'role': isSuperAdmin ? 'admin' : (data['role'] ?? (shopId == uid ? 'owner' : 'user')),
      'shopId': shopId,
      'lastLogin': FieldValue.serverTimestamp(),
    };
    if (extra != null) {
      userData.addAll(extra);
    }
    await userRef.set(userData, SetOptions(merge: true));

    // Đồng bộ dữ liệu liên quan nếu cần (ví dụ: cập nhật email ở các bảng khác)
    // TODO: Nếu có bảng orders, repair_orders,... thì cập nhật thông tin liên quan ở đó
  }

  /// GÁN một nhân viên vào cùng cửa hàng với user hiện tại
  static Future<void> assignUserToCurrentShop(String targetUid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    if (_isSuperAdmin(currentUser)) {
      // Super admin cố tình gán shop nên vẫn cho phép, nhưng cần có shopId hiện tại
      // Nếu chưa có shopId cache thì không làm gì để tránh gán nhầm.
      final currentShop = _cachedShopId;
      if (currentShop == null || currentShop.trim().isEmpty) return;
      await _db.collection('users').doc(targetUid).set({
        'shopId': currentShop,
      }, SetOptions(merge: true));
      return;
    }

    final shopId = await getCurrentShopId();
    if (shopId == null || shopId.trim().isEmpty) return;

    await _db.collection('users').doc(targetUid).set({
      'shopId': shopId,
    }, SetOptions(merge: true));
  }

  /// Lấy quyền xem các màn hình nhạy cảm (doanh thu, chi phí, công nợ) của tài khoản hiện tại
  static Future<Map<String, bool>> getCurrentUserPermissions() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return _defaultPermissionsForRole('user');
    }

    // Admin tối cao luôn có toàn quyền
    if (_isSuperAdmin(currentUser)) {
      return _defaultPermissionsForRole('admin');
    }

    try {
      final snap = await _db.collection('users').doc(currentUser.uid).get();
      final data = snap.data() ?? {};
      final role = (data['role'] as String?) ?? 'user';
      final defaults = _defaultPermissionsForRole(role);

      // Bắt đầu từ quyền riêng trên tài khoản (nếu chưa cấu hình thì dùng mặc định theo role)
      final perms = <String, bool>{
        'allowViewSales': (data['allowViewSales'] as bool?) ?? defaults['allowViewSales']!,
        'allowViewRepairs': (data['allowViewRepairs'] as bool?) ?? defaults['allowViewRepairs']!,
        'allowViewInventory': (data['allowViewInventory'] as bool?) ?? defaults['allowViewInventory']!,
        'allowViewParts': (data['allowViewParts'] as bool?) ?? defaults['allowViewParts']!,
        'allowViewSuppliers': (data['allowViewSuppliers'] as bool?) ?? defaults['allowViewSuppliers']!,
        'allowViewCustomers': (data['allowViewCustomers'] as bool?) ?? defaults['allowViewCustomers']!,
        'allowViewWarranty': (data['allowViewWarranty'] as bool?) ?? defaults['allowViewWarranty']!,
        'allowViewChat': (data['allowViewChat'] as bool?) ?? defaults['allowViewChat']!,
        'allowViewPrinter': (data['allowViewPrinter'] as bool?) ?? defaults['allowViewPrinter']!,
        'allowViewRevenue': (data['allowViewRevenue'] as bool?) ?? defaults['allowViewRevenue']!,
        'allowViewExpenses': (data['allowViewExpenses'] as bool?) ?? defaults['allowViewExpenses']!,
        'allowViewDebts': (data['allowViewDebts'] as bool?) ?? defaults['allowViewDebts']!,
        'allowViewSettings': (data['allowViewSettings'] as bool?) ?? defaults['allowViewSettings']!,
        'shopAppLocked': false,
        'shopAdminFinanceLocked': false,
      };

      // Áp thêm luật điều khiển ở cấp shop (do Super Admin thiết lập)
      final shopId = (data['shopId'] as String?) ?? _cachedShopId;
      if (shopId != null && shopId.trim().isNotEmpty) {
        try {
          final shopSnap = await _db.collection('shops').doc(shopId).get();
          final shopData = shopSnap.data() ?? {};
          final appLocked = shopData['appLocked'] == true;
          final adminFinanceLocked = shopData['adminFinanceLocked'] == true;

          if (appLocked) {
            // Khóa toàn bộ app cho shop này
            for (final key in perms.keys.toList()) {
              if (key != 'shopAppLocked' && key != 'shopAdminFinanceLocked') {
                perms[key] = false;
              }
            }
            perms['shopAppLocked'] = true;
          }

          if (adminFinanceLocked && role == 'admin') {
            perms['allowViewRevenue'] = false;
            perms['allowViewExpenses'] = false;
            perms['allowViewDebts'] = false;
            perms['shopAdminFinanceLocked'] = true;
          }
        } catch (_) {
          // Nếu lỗi đọc shop thì bỏ qua, chỉ dùng quyền theo tài khoản
        }
      }

      return perms;
    } catch (_) {
      return _defaultPermissionsForRole('user');
    }
  }

  /// Dành riêng cho Super Admin: xem danh sách tất cả shop
  static Stream<QuerySnapshot> getAllShopsStreamForSuperAdmin() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (!_isSuperAdmin(currentUser)) {
      // Người thường không được xem, trả về stream rỗng
      return _db.collection('shops').limit(0).snapshots();
    }
    return _db.collection('shops').orderBy('createdAt', descending: true).snapshots();
  }

  /// Dành riêng cho Super Admin: cập nhật cờ điều khiển ở cấp shop
  static Future<void> updateShopControlFlags({
    required String shopId,
    bool? appLocked,
    bool? adminFinanceLocked,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (!_isSuperAdmin(currentUser)) return;

    final data = <String, dynamic>{};
    if (appLocked != null) data['appLocked'] = appLocked;
    if (adminFinanceLocked != null) data['adminFinanceLocked'] = adminFinanceLocked;
    if (data.isEmpty) return;

    await _db.collection('shops').doc(shopId).set(data, SetOptions(merge: true));
  }

  /// Cập nhật phân quyền ẩn/hiện nội dung cho một nhân viên cụ thể
  static Future<void> updateUserPermissions({
    required String uid,
    required bool allowViewSales,
    required bool allowViewRepairs,
    required bool allowViewInventory,
    required bool allowViewParts,
    required bool allowViewSuppliers,
    required bool allowViewCustomers,
    required bool allowViewWarranty,
    required bool allowViewChat,
    required bool allowViewPrinter,
    required bool allowViewRevenue,
    required bool allowViewExpenses,
    required bool allowViewDebts,
  }) async {
    await _db.collection('users').doc(uid).set({
      'allowViewSales': allowViewSales,
      'allowViewRepairs': allowViewRepairs,
      'allowViewInventory': allowViewInventory,
      'allowViewParts': allowViewParts,
      'allowViewSuppliers': allowViewSuppliers,
      'allowViewCustomers': allowViewCustomers,
      'allowViewWarranty': allowViewWarranty,
      'allowViewChat': allowViewChat,
      'allowViewPrinter': allowViewPrinter,
      'allowViewRevenue': allowViewRevenue,
      'allowViewExpenses': allowViewExpenses,
      'allowViewDebts': allowViewDebts,
    }, SetOptions(merge: true));
  }

  // --- INVITE SYSTEM ---
  static Future<String> createInviteCode(String shopId) async {
    final code = _generateInviteCode();
    await _db.collection('invites').doc(code).set({
      'shopId': shopId,
      'createdBy': FirebaseAuth.instance.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': DateTime.now().add(const Duration(days: 7)).toIso8601String(), // 7 ngày
      'used': false,
    });
    return code;
  }

  static Future<Map<String, dynamic>?> getInvite(String code) async {
    final doc = await _db.collection('invites').doc(code).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    if (data['used'] == true) return null;
    final expiresAt = DateTime.parse(data['expiresAt']);
    if (expiresAt.isBefore(DateTime.now())) return null;
    return data;
  }

  static Future<bool> useInviteCode(String code, String uid) async {
    final invite = await getInvite(code);
    if (invite == null) return false;
    final shopId = invite['shopId'];
    // Update user shopId
    await _db.collection('users').doc(uid).set({
      'shopId': shopId,
    }, SetOptions(merge: true));
    // Mark invite as used
    await _db.collection('invites').doc(code).update({'used': true});
    // Update cache
    _cachedShopId = shopId;
    return true;
  }

  /// Dành riêng cho Super Admin: xóa một user (chỉ xóa từ Firestore, không xóa auth)
  static Future<void> deleteUser(String uid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (!_isSuperAdmin(currentUser)) return;

    await _db.collection('users').doc(uid).delete();
  }

  static String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    for (int i = 0; i < 8; i++) {
      code += chars[random % chars.length];
      // Simple random, not crypto secure but ok for demo
    }
    return code;
  }
}
