import 'package:flutter/material.dart';

import '../models/shared_preview.dart';
import '../services/api_client.dart';
import '../utils/haptics.dart';
import 'shared_previews_sheet.dart';

/// The bottom of a spot card: a "Popular place" label when the place has many
/// previews, and a link to the ones other users made. Shows nothing for a
/// place with no previews, so cards stay as they were until there is something
/// to see.
class SharedPreviewsLink extends StatelessWidget {
  final String placeId;
  final String placeName;
  final PlacePreviewCount? info;
  final ApiClient? apiClient;

  const SharedPreviewsLink({
    super.key,
    required this.placeId,
    required this.placeName,
    required this.info,
    this.apiClient,
  });

  @override
  Widget build(BuildContext context) {
    final info = this.info;
    if (info == null || (info.count == 0 && !info.popular)) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (info.popular) const _PopularLabel(),
          if (info.count > 0)
            InkWell(
              key: Key('shared-previews-link-$placeId'),
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                AppHaptics.select();
                showSharedPreviewsSheet(
                  context,
                  placeId: placeId,
                  placeName: placeName,
                  apiClient: apiClient,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'See previews for this location from other users (${info.count})',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PopularLabel extends StatelessWidget {
  const _PopularLabel();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('popular-place'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_outlined, size: 16, color: colors.onTertiaryContainer),
          const SizedBox(width: 4),
          Text(
            'Popular place',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: colors.onTertiaryContainer),
          ),
        ],
      ),
    );
  }
}

/// For a screen with a single place (the best day): looks up that one place's
/// previews itself and shows the link and label.
class SharedPreviewsForPlace extends StatefulWidget {
  final String placeId;
  final String placeName;
  final ApiClient apiClient;

  const SharedPreviewsForPlace({
    super.key,
    required this.placeId,
    required this.placeName,
    required this.apiClient,
  });

  @override
  State<SharedPreviewsForPlace> createState() => _SharedPreviewsForPlaceState();
}

class _SharedPreviewsForPlaceState extends State<SharedPreviewsForPlace> {
  PlacePreviewCount? _info;

  @override
  void initState() {
    super.initState();
    widget.apiClient.fetchSharedPreviewCounts([widget.placeId]).then((counts) {
      if (mounted) setState(() => _info = counts[widget.placeId]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SharedPreviewsLink(
      placeId: widget.placeId,
      placeName: widget.placeName,
      info: _info,
      apiClient: widget.apiClient,
    );
  }
}
