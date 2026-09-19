import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps picked images that cannot be uploaded right away (offline session).
///
/// `ImagePicker` hands back files in the app cache directory, which the OS
/// and `StorageService.cleanupOldTempFiles` (24h) may delete — a repair
/// created offline would lose its photos before the account is ever
/// connected. Files copied here live in the documents directory until
/// `BackgroundUploadService.uploadPendingLocalRepairImages` has pushed them.
class LocalImageStore {
  LocalImageStore._();

  static const String _dirName = 'local_images';

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_dirName');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Copy [picked] into the persistent store and return the new path.
  /// Falls back to the original path if the copy fails.
  static Future<String> persist(XFile picked, {String prefix = 'img'}) async {
    if (kIsWeb) return picked.path;
    try {
      final dir = await _dir();
      final ext = picked.path.contains('.')
          ? picked.path.substring(picked.path.lastIndexOf('.'))
          : '.jpg';
      final target =
          '${dir.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}$ext';
      await File(picked.path).copy(target);
      return target;
    } catch (e) {
      debugPrint('LocalImageStore.persist failed: $e');
      return picked.path;
    }
  }

  static Future<List<String>> persistAll(
    Iterable<XFile> picked, {
    String prefix = 'img',
  }) async {
    final out = <String>[];
    for (final f in picked) {
      out.add(await persist(f, prefix: prefix));
    }
    return out;
  }

  static bool isStorePath(String path) =>
      path.contains('/$_dirName/') || path.contains('\\$_dirName\\');

  /// Delete a stored copy once its cloud URL is known.
  static Future<void> remove(String path) async {
    if (!isStorePath(path)) return;
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }
}
