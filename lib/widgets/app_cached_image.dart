import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Reusable cached network image widget.
/// Automatically caches images on disk + memory, shows placeholder & error.
class AppCachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Memory cache dimensions — decode at this size instead of full resolution.
  /// Dramatically reduces memory for thumbnails in lists.
  final int? memCacheWidth;
  final int? memCacheHeight;

  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      placeholder: (_, __) => Container(
        width: width,
        height: height,
        color: AppColors.outline,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textHint,
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        width: width,
        height: height,
        color: AppColors.outline,
        child: Icon(Icons.broken_image, color: AppColors.textHint, size: 24),
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}
