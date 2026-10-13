import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/simulation.dart';
import '../services/api_client.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../widgets/preview_image.dart';
import '../widgets/sky_loader.dart';
import '../widgets/sparkle_burst.dart';

const _waitingTips = [
  'A picture takes a few seconds to paint',
  "It's an artist's impression, not a photograph",
  'Previews you make are kept under Saved → Sky previews',
];

/// The full-screen preview: the sky loader while the picture is painted, then
/// the picture "develops" on a Polaroid with a little burst of sparkles.
///
/// Opening this screen is what generates (and spends an allowance), so it is
/// only ever pushed after the person confirmed.
class SkyPreviewScreen extends StatefulWidget {
  final SimulationRequest request;
  final ApiClient? apiClient;

  const SkyPreviewScreen({super.key, required this.request, this.apiClient});

  @override
  State<SkyPreviewScreen> createState() => _SkyPreviewScreenState();
}

class _SkyPreviewScreenState extends State<SkyPreviewScreen> {
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();
  late Future<SimulationResponse> _future = _apiClient.fetchSimulation(widget.request);

  void _retry() => setState(() => _future = _apiClient.fetchSimulation(widget.request));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sky preview')),
      body: FutureBuilder<SimulationResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SkyLoader(message: 'Painting your sky', height: null, tips: _waitingTips);
          }
          if (snapshot.hasError) {
            return _Message(
              icon: Icons.cloud_off_outlined,
              text: '${snapshot.error}',
              action: FilledButton(
                key: const Key('preview-retry'),
                onPressed: _retry,
                child: const Text('Try again'),
              ),
            );
          }
          return _Result(request: widget.request, response: snapshot.data!);
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  final SimulationRequest request;
  final SimulationResponse response;

  const _Result({required this.request, required this.response});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = response.imageUrl;

    if (image == null) {
      return _Message(
        icon: Icons.image_outlined,
        text: response.providerStatus == 'not_configured'
            ? 'Sky previews are not switched on yet.'
            : 'Could not paint a preview right now. It did not use one of your previews — '
                'please try again in a moment.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _Polaroid(
              imageUrl: image,
              title: request.locationName,
              subtitle: request.event.label,
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (response.saved)
          Row(
            key: const Key('preview-saved-note'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bookmark_added_outlined, size: 18, color: AppColors.brown),
              const SizedBox(width: 6),
              Text('Saved to Sky previews', style: theme.textTheme.labelLarge),
            ],
          )
        else
          Text(
            "This one wasn't saved to your gallery.",
            key: const Key('preview-not-saved-note'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: 12),
        Text(
          response.disclaimer,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 8),
        Text(
          '${response.remainingToday} of 5 previews left today',
          key: const Key('preview-remaining'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// A photo that develops: it starts washed out and blurred, tilted, and
/// sharpens while settling straight; sparkles pop when it is done.
class _Polaroid extends StatefulWidget {
  final String imageUrl;
  final String title;
  final String subtitle;

  const _Polaroid({required this.imageUrl, required this.title, required this.subtitle});

  @override
  State<_Polaroid> createState() => _PolaroidState();
}

class _PolaroidState extends State<_Polaroid> with TickerProviderStateMixin {
  late final AnimationController _develop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _sparkle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _develop.value = 1;
      return;
    }
    _develop.forward().whenComplete(() {
      if (!mounted) return;
      AppHaptics.tap();
      _sparkle.forward();
    });
  }

  @override
  void dispose() {
    _develop.dispose();
    _sparkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_develop, _sparkle]),
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_develop.value);
        final blur = 14 * (1 - t);

        Widget photo = AspectRatio(
          aspectRatio: 1,
          child: PreviewImage(key: const Key('preview-image'), imageUrl: widget.imageUrl),
        );
        if (blur > 0.1) {
          photo = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: photo,
          );
        }

        final card = Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: AppColors.brownDark.withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    photo,
                    // The "undeveloped" milky wash fades off as it sharpens.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: AppColors.white.withValues(alpha: 0.85 * (1 - t)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: scriptFont,
                  fontSize: 24,
                  color: AppColors.brownDark,
                ),
              ),
              Text(
                widget.subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Transform.rotate(angle: 0.07 * (1 - t), child: card),
            if (_sparkle.isAnimating)
              Positioned.fill(
                child: IgnorePointer(
                  child: LayoutBuilder(
                    key: const Key('preview-sparkles'),
                    builder: (context, box) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // A pop from each top corner and the bottom edge.
                        for (final origin in [
                          const Offset(8, 8),
                          Offset(box.maxWidth - 8, 8),
                          Offset(box.maxWidth / 2, box.maxHeight),
                        ])
                          Positioned.fill(
                            child: CustomPaint(
                              painter: SparklePainter(
                                origin: origin,
                                t: _sparkle.value,
                                color: AppColors.sun,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
