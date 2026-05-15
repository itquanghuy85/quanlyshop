import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final Map<String, String> _resolvedUrlCache = {};
  static String? _lastUploadErrorMessage;
  static bool _lastUploadPermissionDenied = false;
  static bool _lastUploadBillingDisabled = false;
  static const Set<String> _storageRoots = {
    'repairs',
    'attendance',
    'shop_logos',
    'user_photos',
    'chat_images',
    'payment_requests',
    'products',
  };
  static const String _pendingUploadsKey = 'storage_pending_uploads_v1';
  static bool _retryingPendingUploads = false;

  static String? get lastUploadErrorMessage => _lastUploadErrorMessage;
  static bool get lastUploadPermissionDenied => _lastUploadPermissionDenied;
  static bool get lastUploadBillingDisabled => _lastUploadBillingDisabled;

  static void _clearLastUploadError() {
    _lastUploadErrorMessage = null;
    _lastUploadPermissionDenied = false;
    _lastUploadBillingDisabled = false;
  }

  static void _setLastUploadError(Object error) {
    if (_isBillingDisabledStorageError(error)) {
      _lastUploadErrorMessage =
          'Không thể tải ảnh lên Firebase Storage: billing của dự án đang bị khóa (delinquent). Vui lòng cập nhật thanh toán trên Firebase/Google Cloud.';
    } else {
      _lastUploadErrorMessage = _describeStorageError(error);
    }
    _lastUploadPermissionDenied = _isUnauthorizedStorageError(error);
    _lastUploadBillingDisabled = _isBillingDisabledStorageError(error);
  }

  static String _pendingEntryKey(String localPath, String folder) {
    return '${folder.trim()}||${localPath.trim()}';
  }

  static Future<void> _enqueuePendingUpload(
    String localPath,
    String folder,
  ) async {
    final normalizedPath = localPath.trim();
    final normalizedFolder = folder.trim();
    if (normalizedPath.isEmpty || normalizedFolder.isEmpty) return;
    final key = _pendingEntryKey(normalizedPath, normalizedFolder);
    try {
      final prefs = await SharedPreferences.getInstance();
      final current =
          prefs.getStringList(_pendingUploadsKey) ?? const <String>[];
      if (current.contains(key)) return;
      await prefs.setStringList(_pendingUploadsKey, [...current, key]);
    } catch (_) {}
  }

  static Future<void> _removePendingUpload(
    String localPath,
    String folder,
  ) async {
    final key = _pendingEntryKey(localPath, folder);
    try {
      final prefs = await SharedPreferences.getInstance();
      final current =
          prefs.getStringList(_pendingUploadsKey) ?? const <String>[];
      if (!current.contains(key)) return;
      final updated = current.where((e) => e != key).toList();
      await prefs.setStringList(_pendingUploadsKey, updated);
    } catch (_) {}
  }

  static Future<void> retryPendingUploads({int maxItems = 8}) async {
    if (_retryingPendingUploads) return;
    _retryingPendingUploads = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = List<String>.from(
        prefs.getStringList(_pendingUploadsKey) ?? const <String>[],
      );
      if (entries.isEmpty) return;

      for (final entry in entries.take(maxItems)) {
        final parts = entry.split('||');
        if (parts.length != 2) continue;
        final folder = parts[0].trim();
        final localPath = parts[1].trim();
        if (folder.isEmpty || localPath.isEmpty) continue;
        final url = await uploadAndGetUrl(localPath, folder);
        if (url != null && url.trim().isNotEmpty) {
          await _removePendingUpload(localPath, folder);
          continue;
        }

        // Billing disabled (HTTP 402) is not recoverable by retrying now.
        // Stop current retry cycle to avoid noisy repeated failures.
        if (_lastUploadBillingDisabled) {
          debugPrint(
            'StorageService.retryPendingUploads: stop retry cycle because Firebase Storage billing is disabled (HTTP 402).',
          );
          break;
        }
      }
    } catch (e) {
      debugPrint('StorageService.retryPendingUploads error: $e');
    } finally {
      _retryingPendingUploads = false;
    }
  }

  /// Clean up old temporary files (older than 24 hours) - Fix #4
  static Future<void> cleanupOldTempFiles({
    Duration maxAge = const Duration(hours: 24),
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      int deletedCount = 0;
      int errorCount = 0;

      // List all files in temp directory
      if (!tempDir.existsSync()) return;

      for (final entity in tempDir.listSync()) {
        if (entity is! File) continue;

        try {
          final stat = entity.statSync();
          final age = now.difference(stat.modified);

          // Delete files older than maxAge that look like compressed images
          if (age > maxAge &&
              (entity.path.contains('compressed_') ||
                  entity.path.endsWith('.jpg') ||
                  entity.path.endsWith('.png'))) {
            entity.deleteSync();
            deletedCount++;
          }
        } catch (e) {
          debugPrint('⚠️ Error deleting temp file ${entity.path}: $e');
          errorCount++;
        }
      }

      if (deletedCount > 0 || errorCount > 0) {
        debugPrint(
          '🧹 Temp file cleanup: deleted $deletedCount, errors $errorCount',
        );
      }
    } catch (e) {
      debugPrint('⚠️ cleanupOldTempFiles error: $e');
    }
  }

  /// Normalize upload folder to match deployed storage.rules.
  /// Most roots only allow one segment (e.g. repairs/{fileName}),
  /// while chat_images/payment_requests require a shopId segment.
  static String _normalizeUploadFolderForRules(String folder) {
    final normalized = folder.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) return 'products';

    final clean = normalized.startsWith('/')
        ? normalized.substring(1)
        : normalized;
    final parts = clean.split('/').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'products';

    final root = parts.first;
    if (root == 'chat_images' || root == 'payment_requests') {
      if (parts.length >= 2 && parts[1].isNotEmpty) {
        return '$root/${parts[1]}';
      }
      return root;
    }

    if (root == 'user_photos') {
      if (parts.length >= 2 && parts[1].isNotEmpty) {
        return '$root/${parts[1]}';
      }
      return root;
    }

    if (_storageRoots.contains(root)) {
      return root;
    }

    return clean;
  }

  static bool _isUnauthorizedStorageError(Object error) {
    if (error is FirebaseException) {
      return error.code == 'unauthorized' || error.code == 'permission-denied';
    }
    final message = error.toString().toLowerCase();
    return message.contains('firebase_storage/unauthorized') ||
        message.contains('permission denied');
  }

  static bool _isBillingDisabledStorageError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('httpresult: 402') ||
        message.contains('"code": 402') ||
        (message.contains('billing account') && message.contains('delinquent'));
  }

  static String _describeStorageError(Object error) {
    if (error is FirebaseException) {
      final message = error.message?.trim();
      return 'code=${error.code}, plugin=${error.plugin}, message=${message?.isNotEmpty == true ? message : error.toString()}';
    }
    return error.toString();
  }

  static Future<String?> _getCurrentUserShopIdClaim() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      final tokenResult = await user.getIdTokenResult();
      final claim = tokenResult.claims?['shopId'];
      if (claim is String && claim.trim().isNotEmpty) {
        return claim.trim();
      }
    } catch (_) {
      // Fallback handled by caller.
    }
    return null;
  }

  static String? _getCurrentUid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return null;
    return uid.trim();
  }

  static Future<List<String>> _buildUploadFolderCandidates(
    String uploadFolder,
  ) async {
    final candidates = <String>[];
    void addCandidate(String value) {
      final normalized = value.trim().replaceAll('\\', '/');
      if (normalized.isEmpty || candidates.contains(normalized)) return;
      candidates.add(normalized);
    }

    final parts = uploadFolder
        .split('/')
        .where((e) => e.trim().isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      addCandidate('products');
      return candidates;
    }

    final root = parts.first;
    final shopId = await _getCurrentUserShopIdClaim();
    final uid = _getCurrentUid();

    if (root == 'chat_images' || root == 'payment_requests') {
      if (parts.length >= 2) {
        addCandidate('$root/${parts[1]}');
      }
      if (shopId != null && shopId.isNotEmpty) {
        addCandidate('$root/$shopId');
      }
      addCandidate(uploadFolder);
      return candidates;
    }

    if (root == 'user_photos') {
      if (parts.length >= 2 && parts[1].isNotEmpty) {
        addCandidate('$root/${parts[1]}');
      }
      if (uid != null && uid.isNotEmpty) {
        addCandidate('$root/$uid');
      }
      addCandidate(root);
      return candidates;
    }

    // Ưu tiên path theo shop cho repair images để tránh unauthorized trên bucket đang enforce scope.
    if (parts.length == 1 && root == 'repairs') {
      if (shopId != null && shopId.isNotEmpty) {
        addCandidate('$root/$shopId');
      }
      addCandidate(root);
      return candidates;
    }

    addCandidate(uploadFolder);
    return candidates;
  }

  static Future<TaskSnapshot> _uploadFileWithFolderFallback({
    required File file,
    required String fileName,
    required String uploadFolder,
    required SettableMetadata metadata,
  }) async {
    final candidates = await _buildUploadFolderCandidates(uploadFolder);
    Object? lastError;

    for (var i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      final isLast = i == candidates.length - 1;
      final ref = _storage.ref().child(candidate).child(fileName);
      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint(
        'StorageService: uploading ${path.basename(file.path)} to "$candidate" mime=${metadata.contentType} uid=${currentUser?.uid ?? 'null'}',
      );
      try {
        return await ref
            .putFile(file, metadata)
            .timeout(const Duration(seconds: 30));
      } catch (e) {
        lastError = e;
        debugPrint(
          'StorageService: putFile failed at "$candidate": ${_describeStorageError(e)}',
        );
        if (!isLast && _isUnauthorizedStorageError(e)) {
          debugPrint(
            'StorageService: unauthorized at "$candidate", retrying next fallback folder...',
          );
          continue;
        }
        rethrow;
      }
    }

    throw lastError ?? Exception('Unknown storage upload failure');
  }

  static Future<TaskSnapshot> _uploadBytesWithFolderFallback({
    required Uint8List bytes,
    required String fileName,
    required String uploadFolder,
    required SettableMetadata metadata,
  }) async {
    final candidates = await _buildUploadFolderCandidates(uploadFolder);
    Object? lastError;

    for (var i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      final isLast = i == candidates.length - 1;
      final ref = _storage.ref().child(candidate).child(fileName);
      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint(
        'StorageService: uploading bytes to "$candidate" mime=${metadata.contentType} uid=${currentUser?.uid ?? 'null'}',
      );
      try {
        return await ref
            .putData(bytes, metadata)
            .timeout(const Duration(seconds: 30));
      } catch (e) {
        lastError = e;
        debugPrint(
          'StorageService: putData failed at "$candidate": ${_describeStorageError(e)}',
        );
        if (!isLast && _isUnauthorizedStorageError(e)) {
          debugPrint(
            'StorageService: unauthorized at "$candidate", retrying next fallback folder...',
          );
          continue;
        }
        rethrow;
      }
    }

    throw lastError ?? Exception('Unknown storage upload failure');
  }

  /// Các extension hình ảnh được hỗ trợ nén
  static const List<String> _imageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
    '.heif',
  ];

  /// Kiểm tra file có phải là hình ảnh không
  static bool _isImageFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return _imageExtensions.contains(ext);
  }

  /// Nén hình ảnh trước khi upload.
  /// Tối ưu trải nghiệm: file nhỏ thì bỏ qua nén, file lớn dùng profile theo folder.
  static Future<File?> _compressImage(
    File file, {
    String? uploadFolderHint,
  }) async {
    try {
      final filePath = file.path;
      final ext = path.extension(filePath).toLowerCase();

      // Lấy kích thước file gốc
      final originalSize = await file.length();
      const smallFileThreshold = 350 * 1024; // 350KB
      if (originalSize <= smallFileThreshold) {
        debugPrint('⚡ Bỏ qua nén (file nhỏ): ${path.basename(filePath)}');
        return file;
      }

      final folder = (uploadFolderHint ?? '').toLowerCase();
      int quality = 82;
      int targetSize = 1600;
      if (folder.startsWith('user_photos')) {
        quality = 76;
        targetSize = 720;
      } else if (folder.startsWith('chat_images') ||
          folder.startsWith('payment_requests') ||
          folder.startsWith('attendance')) {
        quality = 78;
        targetSize = 1280;
      }

      debugPrint(
        '📸 Nén ảnh: ${path.basename(filePath)} - Size gốc: ${(originalSize / 1024).toStringAsFixed(1)} KB',
      );

      // Tạo đường dẫn file tạm để lưu ảnh nén
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = '${tempDir.path}/compressed_$timestamp.jpg';

      // Xác định format output
      CompressFormat format = CompressFormat.jpeg;
      if (ext == '.png') {
        format = CompressFormat.png;
      } else if (ext == '.webp') {
        format = CompressFormat.webp;
      }

      // Nén ảnh
      final XFile? compressedXFile =
          await FlutterImageCompress.compressAndGetFile(
            filePath,
            targetPath,
            quality: quality,
            minWidth: targetSize,
            minHeight: targetSize,
            format: format,
            keepExif: false,
          ).timeout(const Duration(seconds: 12));

      if (compressedXFile == null) {
        debugPrint('⚠️ Không thể nén ảnh, sử dụng file gốc');
        return file;
      }

      final compressedFile = File(compressedXFile.path);
      final compressedSize = await compressedFile.length();
      final savedPercent =
          ((originalSize - compressedSize) / originalSize * 100)
              .toStringAsFixed(1);

      debugPrint(
        '✅ Nén xong: ${(compressedSize / 1024).toStringAsFixed(1)} KB (giảm $savedPercent%)',
      );

      // Nếu file nén lớn hơn file gốc, dùng file gốc
      if (compressedSize >= originalSize) {
        debugPrint('⚠️ File nén lớn hơn gốc, sử dụng file gốc');
        await compressedFile.delete();
        return file;
      }

      return compressedFile;
    } catch (e) {
      debugPrint('❌ Lỗi nén ảnh: $e');
      return file; // Trả về file gốc nếu nén lỗi
    }
  }

  /// Tự động upload và trả về URL để đồng bộ giữa các máy
  static Future<String?> uploadAndGetUrl(
    String localPath,
    String folder,
  ) async {
    _clearLastUploadError();
    if (!_retryingPendingUploads) {
      unawaited(retryPendingUploads());
    }
    try {
      if (localPath.startsWith('http')) return localPath; // Đã là link cloud

      final uploadFolder = _normalizeUploadFolderForRules(folder);
      if (uploadFolder != folder) {
        debugPrint(
          'StorageService: normalized folder "$folder" -> "$uploadFolder"',
        );
      }

      if (kIsWeb) {
        // Web/mobile-browser: localPath thường là blob URL, upload theo bytes.
        final picked = XFile(localPath);
        return await uploadXFileAndGetUrl(picked, uploadFolder);
      }

      File file = File(localPath);
      if (!file.existsSync()) return null;

      // Nén ảnh nếu là file hình ảnh
      File fileToUpload = file;
      if (_isImageFile(localPath)) {
        final compressedFile = await _compressImage(
          file,
          uploadFolderHint: uploadFolder,
        );
        if (compressedFile != null) {
          fileToUpload = compressedFile;
        }
      }

      // Đặt tên file theo định dạng chuẩn: shopId_timestamp_name
      String fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${path.basename(localPath)}";

      final ext = path.extension(fileToUpload.path).toLowerCase();
      final normalizedExt = ext.isEmpty ? '.jpg' : ext;
      final metadata = SettableMetadata(
        contentType: _guessImageMimeType(normalizedExt),
      );
      TaskSnapshot snapshot = await _uploadFileWithFolderFallback(
        file: fileToUpload,
        fileName: fileName,
        uploadFolder: uploadFolder,
        metadata: metadata,
      );

      // Xóa file nén tạm nếu có
      if (fileToUpload.path != file.path && fileToUpload.existsSync()) {
        try {
          await fileToUpload.delete();
        } catch (_) {}
      }

      final url = await snapshot.ref.getDownloadURL();
      _clearLastUploadError();
      await _removePendingUpload(localPath, uploadFolder);
      return url;
    } catch (e) {
      _setLastUploadError(e);
      await _enqueuePendingUpload(localPath, folder);
      debugPrint(
        'STORAGE_ERROR: folder=$folder, localPath=$localPath, detail=${_describeStorageError(e)}',
      );
      return null;
    }
  }

  /// Upload trực tiếp từ XFile (an toàn cho web vì dùng bytes).
  static Future<String?> uploadXFileAndGetUrl(
    XFile picked,
    String folder,
  ) async {
    _clearLastUploadError();
    if (!_retryingPendingUploads) {
      unawaited(retryPendingUploads());
    }
    try {
      if (picked.path.startsWith('http')) return picked.path;

      final uploadFolder = _normalizeUploadFolderForRules(folder);
      if (uploadFolder != folder) {
        debugPrint(
          'StorageService: normalized folder "$folder" -> "$uploadFolder"',
        );
      }

      final ext = path.extension(picked.path).toLowerCase();
      final normalizedExt = ext.isEmpty ? '.jpg' : ext;
      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${path.basenameWithoutExtension(picked.name.isEmpty ? 'image' : picked.name)}$normalizedExt";

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        if (bytes.isEmpty) return null;
        final metadata = SettableMetadata(
          contentType: _guessImageMimeType(normalizedExt),
        );
        final snapshot = await _uploadBytesWithFolderFallback(
          bytes: bytes,
          fileName: fileName,
          uploadFolder: uploadFolder,
          metadata: metadata,
        );
        final url = await snapshot.ref.getDownloadURL();
        _clearLastUploadError();
        await _removePendingUpload(picked.path, uploadFolder);
        return url;
      }

      final file = File(picked.path);
      if (!file.existsSync()) return null;

      // Compress image if applicable (attendance, repair photos)
      File fileToUpload = file;
      if (_isImageFile(picked.path)) {
        final compressed = await _compressImage(
          file,
          uploadFolderHint: uploadFolder,
        );
        if (compressed != null) fileToUpload = compressed;
      }

      final nativeExt = path.extension(fileToUpload.path).toLowerCase();
      final nativeNormalizedExt = nativeExt.isEmpty ? '.jpg' : nativeExt;
      final nativeMetadata = SettableMetadata(
        contentType: _guessImageMimeType(nativeNormalizedExt),
      );

      final snapshot = await _uploadFileWithFolderFallback(
        file: fileToUpload,
        fileName: fileName,
        uploadFolder: uploadFolder,
        metadata: nativeMetadata,
      );

      // Clean up temp compressed file
      if (fileToUpload.path != file.path && fileToUpload.existsSync()) {
        try {
          await fileToUpload.delete();
        } catch (_) {}
      }

      final url = await snapshot.ref.getDownloadURL();
      _clearLastUploadError();
      await _removePendingUpload(picked.path, uploadFolder);
      return url;
    } catch (e) {
      _setLastUploadError(e);
      await _enqueuePendingUpload(picked.path, folder);
      debugPrint(
        'STORAGE_XFILE_ERROR: folder=$folder, xfilePath=${picked.path}, detail=${_describeStorageError(e)}',
      );
      return null;
    }
  }

  static String _guessImageMimeType(String ext) {
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.heic':
      case '.heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  static bool isGsStoragePath(String filePath) {
    return filePath.trim().toLowerCase().startsWith('gs://');
  }

  static bool isStorageRelativePath(String filePath) {
    final normalized = filePath.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    if (normalized.contains('://') ||
        normalized.startsWith('blob:') ||
        normalized.startsWith('data:')) {
      return false;
    }

    final cleanPath = normalized.startsWith('/')
        ? normalized.substring(1)
        : normalized;
    if (!cleanPath.contains('/')) return false;

    return _storageRoots.contains(cleanPath.split('/').first);
  }

  static bool isDisplayableCloudPath(String filePath) {
    final normalized = filePath.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://') ||
        normalized.startsWith('blob:') ||
        normalized.startsWith('data:') ||
        isGsStoragePath(normalized) ||
        isStorageRelativePath(normalized);
  }

  static bool isResolvableDisplayPath(String filePath) {
    return isDisplayableCloudPath(filePath);
  }

  static Future<String?> resolveDisplayUrl(String filePath) async {
    final normalized = filePath.trim();
    if (normalized.isEmpty) return null;

    final lower = normalized.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('blob:') ||
        lower.startsWith('data:')) {
      return normalized;
    }

    if (!isGsStoragePath(normalized) && !isStorageRelativePath(normalized)) {
      return kIsWeb ? null : normalized;
    }

    final cached = _resolvedUrlCache[normalized];
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final ref = isGsStoragePath(normalized)
          ? _storage.refFromURL(normalized)
          : _storage.ref(
              normalized.startsWith('/') ? normalized.substring(1) : normalized,
            );
      final url = await ref.getDownloadURL();
      _resolvedUrlCache[normalized] = url;
      return url;
    } catch (e) {
      debugPrint(
        'StorageService: failed to resolve image path $normalized: $e',
      );
      return null;
    }
  }

  /// Xử lý đồng loạt cho danh sách ảnh
  static Future<String> uploadMultipleAndJoin(
    String localPathsCsv,
    String folder,
  ) async {
    if (localPathsCsv.isEmpty) return "";
    List<String> paths = localPathsCsv
        .split(',')
        .where((e) => e.trim().isNotEmpty)
        .toList();
    List<String> urls = [];

    for (String p in paths) {
      String trimmed = p.trim();
      if (trimmed.isEmpty) continue;
      if (!kIsWeb && !File(trimmed).existsSync()) continue;
      String? url = await uploadAndGetUrl(trimmed, folder);
      if (url != null) urls.add(url);
    }
    return urls.join(',');
  }

  /// Upload multiple images and return list of URLs
  static Future<List<String>> uploadMultipleImages(
    List<String> localPaths,
    String folder,
  ) async {
    List<String> urls = [];
    for (String path in localPaths) {
      String? url = await uploadAndGetUrl(path, folder);
      if (url != null) urls.add(url);
    }
    return urls;
  }
}
