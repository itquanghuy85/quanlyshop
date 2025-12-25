import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Tự động upload và trả về URL để đồng bộ giữa các máy
  static Future<String?> uploadAndGetUrl(String localPath, String folder) async {
    try {
      if (localPath.startsWith('http')) return localPath; // Đã là link cloud

      File file = File(localPath);
      if (!file.existsSync()) return null;

      // Đặt tên file theo định dạng chuẩn: shopId_timestamp_name
      String fileName = "${DateTime.now().millisecondsSinceEpoch}_${path.basename(localPath)}";
      Reference ref = _storage.ref().child(folder).child(fileName);
      
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask.timeout(const Duration(seconds: 20));
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("STORAGE_ERROR: $e");
      return null;
    }
  }

  /// Xử lý đồng loạt cho danh sách ảnh
  static Future<String> uploadMultipleAndJoin(String localPathsCsv, String folder) async {
    if (localPathsCsv.isEmpty) return "";
    List<String> paths = localPathsCsv.split(',').where((e) => e.isNotEmpty).toList();
    List<String> urls = [];

    for (String p in paths) {
      String? url = await uploadAndGetUrl(p, folder);
      if (url != null) urls.add(url);
    }
    return urls.join(',');
  }
}
