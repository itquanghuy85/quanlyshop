import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';

import 'app_cached_image.dart';

/// Reusable image picker widget for product/repair images.
/// Supports: camera capture, gallery pick, delete, full-screen view.
/// Compresses images before returning (max 1600px, JPEG q=78, target <300KB).
class ImagePickerWidget extends StatelessWidget {
  /// Current remote URL (Firebase Storage). Null if no image uploaded yet.
  final String? imageUrl;

  /// Current local file path (pending upload). Null if none.
  final String? localPath;

  /// Called when a new image is picked. Provides compressed local file path.
  final ValueChanged<String> onImagePicked;

  /// Called when user wants to delete the current image.
  final VoidCallback onImageDeleted;

  /// Whether a background upload is in progress.
  final bool isUploading;

  /// Upload progress 0.0–1.0. Null if not uploading.
  final double? uploadProgress;

  final double size;

  const ImagePickerWidget({
    super.key,
    this.imageUrl,
    this.localPath,
    required this.onImagePicked,
    required this.onImageDeleted,
    this.isUploading = false,
    this.uploadProgress,
    this.size = 96,
  });

  bool get _hasImage =>
      (imageUrl != null && imageUrl!.isNotEmpty) ||
      (localPath != null && localPath!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: _hasImage ? () => _showFullScreen(context) : null,
              child: Stack(
                children: [
                  _buildThumbnail(context),
                  if (isUploading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              value: uploadProgress,
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_hasImage && !isUploading)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: onImageDeleted,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD32F2F),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _actionButton(
                  context,
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () => _pick(context, ImageSource.camera),
                ),
                const SizedBox(height: 6),
                _actionButton(
                  context,
                  icon: Icons.photo_library_rounded,
                  label: 'Thư viện',
                  onTap: () => _pick(context, ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
        if (localPath != null && imageUrl == null && !isUploading)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.cloud_upload_outlined, size: 13, color: Colors.orange.shade700),
                const SizedBox(width: 4),
                Text(
                  'Chờ upload...',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    final radius = BorderRadius.circular(12);

    if (localPath != null && localPath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(localPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return AppCachedImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        borderRadius: radius,
        memCacheWidth: 200,
        memCacheHeight: 200,
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 28, color: Colors.grey.shade400),
          const SizedBox(height: 4),
          Text('Ảnh SP', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF1E40AF)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E40AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(
          imageUrl: imageUrl,
          localPath: localPath,
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null) return;

      final compressed = await _compress(picked.path);
      if (compressed != null) {
        onImagePicked(compressed);
      } else {
        onImagePicked(picked.path);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn ảnh: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Compress image: max 1600px, JPEG quality 78, target <300KB
  static Future<String?> _compress(String sourcePath) async {
    try {
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ext = p.extension(sourcePath).toLowerCase();
      final outPath = p.join(dir.path, 'img_$ts${ext.isEmpty ? '.jpg' : ext}');

      final result = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        outPath,
        quality: 78,
        minWidth: 100,
        minHeight: 100,
        keepExif: false,
        format: CompressFormat.jpeg,
      );

      if (result == null) return null;

      // If still >300KB, compress again at lower quality
      final fileSize = await File(result.path).length();
      if (fileSize > 300 * 1024) {
        final outPath2 = p.join(dir.path, 'img_${ts}_2.jpg');
        final result2 = await FlutterImageCompress.compressAndGetFile(
          result.path,
          outPath2,
          quality: 60,
          minWidth: 100,
          minHeight: 100,
          keepExif: false,
          format: CompressFormat.jpeg,
        );
        if (result2 != null) return result2.path;
      }

      return result.path;
    } catch (e) {
      debugPrint('ImagePickerWidget compress error: $e');
      return null;
    }
  }

  /// Static helper: compress a file path (callable from services)
  static Future<String?> compressImage(String sourcePath) => _compress(sourcePath);
}

class _FullScreenImageViewer extends StatelessWidget {
  final String? imageUrl;
  final String? localPath;

  const _FullScreenImageViewer({this.imageUrl, this.localPath});

  @override
  Widget build(BuildContext context) {
    ImageProvider? provider;
    if (localPath != null && localPath!.isNotEmpty) {
      provider = FileImage(File(localPath!));
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      provider = NetworkImage(imageUrl!);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Xem ảnh', style: TextStyle(color: Colors.white)),
      ),
      body: provider == null
          ? const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 64))
          : PhotoView(
              imageProvider: provider,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
    );
  }
}
