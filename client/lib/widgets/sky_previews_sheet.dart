import 'package:flutter/material.dart';

import '../models/simulation.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/haptics.dart';
import 'preview_image.dart';

/// Opens the Sky previews gallery as a sheet rising from the bottom: it
/// covers three quarters of the page and can be dragged up to fill it. The
/// back arrow, the back gesture, dragging it down or tapping outside all
/// return to the page underneath.
Future<void> showSkyPreviewsSheet(BuildContext context, {ApiClient? apiClient}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // The sheet below does its own dragging (to full height).
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => SkyPreviewsSheet(apiClient: apiClient),
  );
}

class SkyPreviewsSheet extends StatefulWidget {
  final ApiClient? apiClient;

  const SkyPreviewsSheet({super.key, this.apiClient});

  @override
  State<SkyPreviewsSheet> createState() => _SkyPreviewsSheetState();
}

class _SkyPreviewsSheetState extends State<SkyPreviewsSheet> {
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();

  bool _loading = true;
  String? _error;
  List<SkyPreviewRecord> _previews = const [];

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
      final previews = await _apiClient.fetchPreviews();
      if (!mounted) return;
      // Newest first.
      previews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() => _previews = previews);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(SkyPreviewRecord record) async {
    AppHaptics.select();
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SkyPreviewDetailScreen(record: record, apiClient: _apiClient),
      ),
    );
    if (removed == true && mounted) {
      setState(() => _previews = _previews.where((p) => p.id != record.id).toList());
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
          key: const Key('sky-previews-sheet'),
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
                  count: _loading || _error != null ? null : _previews.length,
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
                  Text('Could not load your previews: $_error', textAlign: TextAlign.center),
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
                    'No previews yet',
                    key: const Key('sky-previews-empty'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap "Preview this sky" on any forecast and the picture will be kept here.',
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
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: _previews.length,
          itemBuilder: (context, i) {
            final record = _previews[i];
            return _Tile(record: record, onTap: () => _open(record));
          },
        ),
      ),
    ];
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final int? count;
  final VoidCallback onBack;

  _HeaderDelegate({required this.count, required this.onBack});

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
                key: const Key('sky-previews-back'),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: onBack,
              ),
              Expanded(child: Text('Sky previews', style: theme.textTheme.titleLarge)),
              if (count != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text('$count', style: theme.textTheme.bodyMedium),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_HeaderDelegate old) => old.count != count;
}

class _Tile extends StatelessWidget {
  final SkyPreviewRecord record;
  final VoidCallback onTap;

  const _Tile({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${record.event.label} preview of ${record.locationName}',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('preview-tile-${record.id}'),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.brownDark.withValues(alpha: 0.16),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: PreviewImage(imageUrl: record.imageUrl, cacheWidth: 200),
          ),
        ),
      ),
    );
  }
}

/// One saved preview, large, with its details. Pops with true when the
/// preview was deleted.
class SkyPreviewDetailScreen extends StatefulWidget {
  final SkyPreviewRecord record;
  final ApiClient? apiClient;

  const SkyPreviewDetailScreen({super.key, required this.record, this.apiClient});

  @override
  State<SkyPreviewDetailScreen> createState() => _SkyPreviewDetailScreenState();
}

class _SkyPreviewDetailScreenState extends State<SkyPreviewDetailScreen> {
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();
  bool _deleting = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this preview?'),
        content: const Text('It will be removed from your Sky previews.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-delete-preview'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _deleting = true);
    try {
      await _apiClient.deletePreview(widget.record.id);
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not delete it: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sky preview')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: InteractiveViewer(
                    child: PreviewImage(
                      key: const Key('preview-detail-image'),
                      imageUrl: record.imageUrl,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            record.locationName,
            style: const TextStyle(
              fontFamily: scriptFont,
              fontSize: 26,
              color: AppColors.brownDark,
            ),
          ),
          Text(
            '${record.event.label} · made ${formatLongDate(record.createdAt)}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            record.disclaimer,
            style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('delete-preview'),
              onPressed: _deleting ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ),
        ],
      ),
    );
  }
}
