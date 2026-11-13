import 'package:flutter/material.dart';

import '../models/shared_preview.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/haptics.dart';
import 'polaroid_frame.dart';
import 'preview_image.dart';

/// Opens the previews other people made for a place, as a sheet rising from
/// the bottom: it covers three quarters of the page and can be dragged up to
/// fill it. The back arrow, the back gesture, dragging it down or tapping
/// outside all return to the page underneath.
Future<void> showSharedPreviewsSheet(
  BuildContext context, {
  required String placeId,
  required String placeName,
  ApiClient? apiClient,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // The sheet below does its own dragging (to full height).
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => SharedPreviewsSheet(
      placeId: placeId,
      placeName: placeName,
      apiClient: apiClient,
    ),
  );
}

class SharedPreviewsSheet extends StatefulWidget {
  final String placeId;
  final String placeName;
  final ApiClient? apiClient;

  const SharedPreviewsSheet({
    super.key,
    required this.placeId,
    required this.placeName,
    this.apiClient,
  });

  @override
  State<SharedPreviewsSheet> createState() => _SharedPreviewsSheetState();
}

class _SharedPreviewsSheetState extends State<SharedPreviewsSheet> {
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();

  bool _loading = true;
  String? _error;
  List<SharedPreview> _previews = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final previews = await _apiClient.fetchSharedPreviews(widget.placeId);
      if (!mounted) return;
      setState(() => _previews = previews);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const [0.75, 1.0],
      builder: (context, scrollController) {
        return Container(
          key: const Key('shared-previews-sheet'),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _HeaderDelegate(
                  title: widget.placeName,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
              ..._body(context),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _body(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load the previews: $_error', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    if (_previews.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 40, color: AppColors.outline),
                  const SizedBox(height: 12),
                  Text(
                    'No previews from other users yet',
                    key: const Key('shared-previews-empty'),
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 14,
            childAspectRatio: 0.66,
          ),
          itemCount: _previews.length,
          itemBuilder: (context, i) => _SharedTile(preview: _previews[i], index: i),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Text(
            'AI-generated illustrations of expected skies, made by other Vesper '
            'users. Not photographs.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ];
  }
}

/// One shared preview as a small Polaroid, tilted a little like a photo pinned
/// to a board. Tap it to see it larger.
class _SharedTile extends StatelessWidget {
  final SharedPreview preview;
  final int index;

  const _SharedTile({required this.preview, required this.index});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${preview.event.label} preview of ${preview.placeName}, '
          '${formatLongDate(preview.displayDate)}',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('shared-preview-${preview.id}'),
        onTap: () {
          AppHaptics.select();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SharedPreviewDetailScreen(preview: preview)),
          );
        },
        child: Transform.rotate(
          angle: index.isEven ? -0.02 : 0.02,
          child: Hero(
            tag: 'shared-preview-${preview.id}',
            child: PolaroidFrame(
              compact: true,
              photo: SizedBox.expand(
                child: PreviewImage(imageUrl: preview.thumbUrl, cacheWidth: 200),
              ),
              title: preview.placeName,
              captions: [preview.event.label, formatLongDate(preview.displayDate)],
            ),
          ),
        ),
      ),
    );
  }
}

/// One shared preview, large, on its Polaroid with the full-size picture.
class SharedPreviewDetailScreen extends StatelessWidget {
  final SharedPreview preview;

  const SharedPreviewDetailScreen({super.key, required this.preview});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(preview.placeName, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        key: const Key('shared-preview-detail'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Hero(
                tag: 'shared-preview-${preview.id}',
                child: PolaroidFrame(
                  photo: AspectRatio(
                    aspectRatio: 1,
                    child: PreviewImage(
                      key: const Key('shared-preview-image'),
                      imageUrl: preview.imageUrl,
                    ),
                  ),
                  title: preview.placeName,
                  captions: ['${preview.event.label} · ${formatLongDate(preview.displayDate)}'],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            preview.disclaimer,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          Text(
            'Made by another Vesper user.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final VoidCallback onBack;

  _HeaderDelegate({required this.title, required this.onBack});

  static const _height = 84.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                key: const Key('shared-previews-back'),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  'Previews of $title',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_HeaderDelegate old) => old.title != title;
}
