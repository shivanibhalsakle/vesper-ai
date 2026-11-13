import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The white Polaroid card: a photo with the place written under it in the
/// script font, then a line or two of small print. The card is drawn here, so
/// the picture files themselves stay plain images.
///
/// Full size it sits in a scrolling page and is as tall as its content. With
/// [compact] it fills a grid cell and the photo takes whatever height is left
/// after the writing, so nothing overflows.
class PolaroidFrame extends StatelessWidget {
  final Widget photo;
  final String title;

  /// Small print under the title, one line each.
  final List<String> captions;
  final bool compact;

  const PolaroidFrame({
    super.key,
    required this.photo,
    required this.title,
    this.captions = const [],
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final picture = ClipRRect(borderRadius: BorderRadius.circular(2), child: photo);

    return Container(
      padding: compact
          ? const EdgeInsets.fromLTRB(8, 8, 8, 10)
          : const EdgeInsets.fromLTRB(14, 14, 14, 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: AppColors.brownDark.withValues(alpha: compact ? 0.16 : 0.22),
            blurRadius: compact ? 8 : 22,
            offset: Offset(0, compact ? 3 : 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact) Expanded(child: picture) else picture,
          SizedBox(height: compact ? 8 : 14),
          Text(
            title,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: scriptFont,
              fontSize: compact ? 16 : 24,
              color: AppColors.brownDark,
            ),
          ),
          for (final caption in captions)
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
