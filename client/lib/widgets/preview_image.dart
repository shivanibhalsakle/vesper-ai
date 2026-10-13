import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A generated sky: either the image bytes inline (a `data:` URI, straight
/// after generating and when it couldn't be saved) or a link to the stored
/// copy.
class PreviewImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;

  /// Decode width in logical pixels, to keep a grid of previews light.
  final double? cacheWidth;

  const PreviewImage({super.key, required this.imageUrl, this.fit = BoxFit.cover, this.cacheWidth});

  @override
  Widget build(BuildContext context) {
    final width = cacheWidth == null
        ? null
        : (cacheWidth! * MediaQuery.devicePixelRatioOf(context)).round();

    if (imageUrl.startsWith('data:')) {
      try {
        return Image.memory(
          base64Decode(imageUrl.split(',').last),
          fit: fit,
          cacheWidth: width,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const _MissingImage(),
        );
      } catch (_) {
        return const _MissingImage();
      }
    }
    return Image.network(
      imageUrl,
      fit: fit,
      cacheWidth: width,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const ColoredBox(color: AppColors.sand),
      errorBuilder: (_, _, _) => const _MissingImage(),
    );
  }
}

class _MissingImage extends StatelessWidget {
  const _MissingImage();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.sand,
      child: Center(child: Icon(Icons.image_not_supported_outlined, color: AppColors.textSecondary)),
    );
  }
}
