import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload một file ảnh lên Firebase Storage và trả về URL Cloud
  static Future<String?> uploadImage(String localPath, String folder) async {
    try {
      File file = File(localPath);
      if (!file.existsSync()) {
        print("Lỗi: File ảnh local không tồn tại tại $localPath");
        return null;
      }

      // Kiểm tra kích thước file
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) { // 10MB limit
        print("Lỗi: File quá lớn (${fileSize} bytes)");
        return null;
      }

      // Đặt tên file duy nhất để không bị trùng
      String fileName = "${DateTime.now().millisecondsSinceEpoch}_${path.basename(localPath)}";
      Reference ref = _storage.ref().child(folder).child(fileName);
      
      // Thực hiện upload với timeout
      UploadTask uploadTask = ref.putFile(file);
      
      // Lấy kết quả trả về với timeout
      TaskSnapshot snapshot = await uploadTask.timeout(const Duration(seconds: 30), onTimeout: () {
        throw TimeoutException('Upload ảnh quá thời gian cho phép (30 giây)');
      });
      
      String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print("Upload thành công: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      print("Lỗi upload ảnh lên Storage: $e");
      return null;
    }
  }

  /// Upload nhiều ảnh cùng lúc
  static Future<List<String>> uploadMultipleImages(List<String> localPaths, String folder) async {
    List<String> urls = [];
    for (String p in localPaths) {
      if (p.startsWith('http')) {
        // Nếu ảnh đã là link Cloud rồi thì không upload nữa
        urls.add(p);
        continue;
      }
      String? url = await uploadImage(p, folder);
      if (url != null) urls.add(url);
    }
    return urls;
  }
}
