import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
    // Validate input fields
    static String? validateName(String name) {
      if (name.trim().isEmpty) return 'Tên không được để trống';
      return null;
    }

    static String? validatePhone(String phone) {
      final phoneReg = RegExp(r'^(0[0-9]{9,10})$');
      if (!phoneReg.hasMatch(phone)) return 'Số điện thoại không hợp lệ';
      return null;
    }

    static String? validateAddress(String address) {
      if (address.trim().isEmpty) return 'Địa chỉ không được để trống';
      return null;
    }
  static final _db = FirebaseFirestore.instance;

  // Lấy quyền của người dùng (Có nhận diện Admin đặc biệt)
  static Future<String> getUserRole(String uid) async {
    // CAO KIẾN: Nhận diện Admin tối cao qua Email
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.email == 'admin@huluca.com') {
      return 'admin'; // Luôn là Admin nếu dùng email này
    }

    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['role'] ?? 'user';
      }
      return 'user';
    } catch (e) {
      return 'user';
    }
  }

  static Future<Map<String, dynamic>> getUserInfo(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data() ?? {};
  }

  static Stream<QuerySnapshot> getAllUsersStream() {
    return _db.collection('users').snapshots();
  }

  static Future<void> updateUserInfo({
    required String uid,
    required String name,
    required String phone,
    required String address,
    required String role,
    String? photoUrl,
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
    await _db.collection('users').doc(uid).set({
      'displayName': name.toUpperCase(),
      'phone': phone,
      'address': address.toUpperCase(),
      'role': role,
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Đồng bộ dữ liệu liên quan (ví dụ: cập nhật tên, số điện thoại ở các bảng khác nếu cần)
    // TODO: Nếu có bảng orders, repair_orders,... thì cập nhật thông tin liên quan ở đó
  }

  static Future<void> syncUserInfo(String uid, String email) async {
    // Lấy thông tin hiện tại để đồng bộ
    final userDoc = await _db.collection('users').doc(uid).get();
    final data = userDoc.data() ?? {};
    await _db.collection('users').doc(uid).set({
      'email': email,
      'displayName': data['displayName'] ?? '',
      'phone': data['phone'] ?? '',
      'address': data['address'] ?? '',
      'role': email == 'admin@huluca.com' ? 'admin' : (data['role'] ?? 'user'),
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Đồng bộ dữ liệu liên quan nếu cần (ví dụ: cập nhật email ở các bảng khác)
    // TODO: Nếu có bảng orders, repair_orders,... thì cập nhật thông tin liên quan ở đó
  }
}
