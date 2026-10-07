import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _tips = [
  'Golden hour starts about an hour before sunset',
  'Thin high clouds often catch the most colour',
  'Arrive 20 minutes early and stay 20 minutes after',
  'Clear skies are lovely, a few clouds are dramatic',
];

/// The loading screen: a sun travelling across a sky that drifts from dawn to
/// dusk, clouds sliding by, rotating tips, and a carousel of sunset colours.
/// Tap the sun and it pops and throws sparkles.
///
/// With a [height] it is a rounded card that sits in a page; without one it
/// fills the space it is given. Every animation stops when the system asks
/// for reduced motion, leaving a still mid-afternoon sky.
class SkyLoader extends StatefulWidget {
  final String message;
  final double? height;
  final bool showWordmark;
  final List<String> tips;

  const SkyLoader({
    super.key,
    required this.message,
    this.height = 340,
    this.showWordmark = false,
    this.tips = _tips,
  });

  @override
  State<SkyLoader> createState() => _SkyLoaderState();
}

class _SkyLoaderState extends State<SkyLoader> with TickerProviderStateMixin {
  static const _stepEvery = Duration(milliseconds: 2400);
  static const _slides = 5;

  // Sun and sky share one slow back-and-forth; clouds and dots loop on their
  // own clocks; the pop is a one-shot.
  late final AnimationController _sun =
      AnimationController(vsync: this, duration: const Duration(seconds: 12));
  late final AnimationController _clouds =
      AnimationController(vsync: this, duration: const Duration(seconds: 20));
  late final AnimationController _dots =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  late final AnimationController _pop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final Animation<double> _sunCurve =
      CurvedAnimation(parent: _sun, curve: Curves.easeInOut);

  Timer? _timer;
  int _step = 0;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _applyMotionPreference();
  }

  void _applyMotionPreference() {
    if (_reduced) {
      _sun
        ..stop()
        ..value = 0.5;
      _clouds
        ..stop()
        ..value = 0.3;
      _dots
        ..stop()
        ..value = 0.1;
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (!_sun.isAnimating) _sun.repeat(reverse: true);
    if (!_clouds.isAnimating) _clouds.repeat();
    if (!_dots.isAnimating) _dots.repeat();
    _timer ??= Timer.periodic(_stepEvery, (_) {
      if (mounted) setState(() => _step++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sun.dispose();
    _clouds.dispose();
    _dots.dispose();
    _pop.dispose();
    super.dispose();
  }

  void _tapSun() {
    if (_reduced) return;
    _pop.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: widget.message,
      liveRegion: true,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = widget.height ?? constraints.maxHeight;
              final sky = _scene(theme, w, h);
              final framed = widget.height == null
                  ? sky
                  : ClipRRect(borderRadius: BorderRadius.circular(20), child: sky);
              return SizedBox(width: w, height: h, child: framed);
            },
          ),
        ),
      ),
    );
  }

  Widget _scene(ThemeData theme, double w, double h) {
    // The hill must fit the message, a tip that may wrap to two lines on a
    // narrow phone, and the carousel (about 170px with padding); in a short
    // card that means a lower hill, i.e. a higher horizon line.
    final horizon = widget.height == null
        ? h * 0.55
        : math.max(h * 0.35, math.min(h * 0.55, h - 170));
    final radius = math.min(w * 0.40, horizon - 44);
    final centre = Offset(w / 2, horizon);
    final tip = widget.tips[_step % widget.tips.length];

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // Dawn sky, with the dusk sky fading in over it as the sun travels.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFBFD4F2), Color(0xFFF6C7B6), Color(0xFFFCE9C8)],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: FadeTransition(
            opacity: _sunCurve,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2E2A5E), Color(0xFFB04F86), Color(0xFFF2A65A)],
                ),
              ),
            ),
          ),
        ),
        _cloud(w, h * 0.12, 74, 0.0, 0.7),
        _cloud(w, h * 0.26, 52, 0.5, 0.55),
        // The sun, on a half-circle path over the horizon.
        AnimatedBuilder(
          animation: Listenable.merge([_sunCurve, _pop]),
          builder: (context, _) {
            final p = 0.08 + 0.84 * _sunCurve.value;
            final angle = math.pi * (1 - p);
            final pos = centre + Offset(math.cos(angle), -math.sin(angle)) * radius;
            final pop = math.sin(math.pi * _pop.value);
            final colour = Color.lerp(
              const Color(0xFFFFD27A),
              const Color(0xFFE5736B),
              _sunCurve.value,
            )!;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: pos.dx - 32,
                  top: pos.dy - 32,
                  child: GestureDetector(
                    key: const Key('sky-loader-sun'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _tapSun,
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: Center(
                        child: Transform.rotate(
                          angle: 0.25 * pop,
                          child: Transform.scale(
                            scale: 1 + 0.35 * pop,
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colour,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_pop.isAnimating)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        key: const Key('sky-loader-sparkles'),
                        painter: _SparklePainter(origin: pos, t: _pop.value),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        // The hill the text and carousel sit on.
        Positioned(
          left: -w * 0.1,
          right: -w * 0.1,
          top: horizon,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.brownDark.withValues(alpha: 0.92),
              borderRadius: BorderRadius.only(
                topLeft: Radius.elliptical(w * 0.7, 56),
                topRight: Radius.elliptical(w * 0.7, 56),
              ),
            ),
          ),
        ),
        if (widget.showWordmark)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Vesper',
                style: theme.textTheme.displaySmall?.copyWith(fontSize: 34, color: Colors.white),
              ),
            ),
          ),
        // Message, tip and carousel as one group, centred on the hill.
        Positioned(
          top: horizon + 12,
          bottom: 8,
          left: 20,
          right: 20,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.message,
                      style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(width: 2),
                    _dotsRow(theme),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    tip,
                    key: ValueKey(tip),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [for (var i = 0; i < _slides; i++) _slide(i)],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cloud(double w, double top, double width, double phase, double alpha) {
    return AnimatedBuilder(
      animation: _clouds,
      builder: (context, child) {
        final v = (_clouds.value + phase) % 1.0;
        return Positioned(left: -width + (w + width) * v, top: top, child: child!);
      },
      child: Container(
        width: width,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: alpha),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _dotsRow(ThemeData theme) {
    return AnimatedBuilder(
      animation: _dots,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Opacity(
              opacity: ((_dots.value - i / 3) % 1.0) < 1 / 3 ? 1.0 : 0.25,
              child: Text(
                '.',
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _slide(int index) {
    final active = _step % _slides == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        width: active ? 46 : 30,
        height: active ? 58 : 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 2),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.spectrum[index], AppColors.spectrum[index + 1]],
          ),
        ),
        foregroundDecoration: active
            ? null
            : BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.brownDark.withValues(alpha: 0.35),
              ),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Offset origin;
  final double t;

  _SparklePainter({required this.origin, required this.t});

  static const _count = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeOut.transform(t);
    for (var i = 0; i < _count; i++) {
      final angle = i / _count * 2 * math.pi;
      final distance = 30 + 40 * eased;
      final at = origin + Offset(math.cos(angle), math.sin(angle)) * distance;
      canvas.drawCircle(
        at,
        2 + 4 * (1 - t),
        Paint()..color = Colors.white.withValues(alpha: (1 - t).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.t != t || old.origin != origin;
}
