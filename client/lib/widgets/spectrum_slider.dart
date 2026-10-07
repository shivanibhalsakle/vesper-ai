import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A thick slider whose track runs through the dawn-to-dusk spectrum. The
/// part past the thumb is faded, and the thumb takes the colour of its
/// position: low is dawn, high is dusk.
class SpectrumSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final int divisions;

  const SpectrumSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.divisions = 10,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 14,
        trackShape: const _SpectrumTrackShape(),
        thumbShape: const _SpectrumThumbShape(),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      ),
      child: Slider(
        value: value,
        min: 0,
        max: 1,
        divisions: divisions,
        label: '${(value * 100).round()}%',
        onChanged: onChanged,
      ),
    );
  }
}

class _SpectrumTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const _SpectrumTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));
    final canvas = context.canvas;

    // The whole track in faded spectrum...
    final faded = LinearGradient(
      colors: [for (final c in AppColors.spectrum) c.withValues(alpha: 0.3)],
      stops: AppColors.spectrumStops,
    );
    canvas.drawRRect(rrect, Paint()..shader = faded.createShader(rect));

    // ...and the part up to the thumb at full strength.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(rect.left, rect.top, thumbCenter.dx, rect.bottom));
    canvas.drawRRect(
      rrect,
      Paint()..shader = AppColors.spectrumGradient.createShader(rect),
    );
    canvas.restore();
  }
}

class _SpectrumThumbShape extends SliderComponentShape {
  const _SpectrumThumbShape();

  static const _radius = 13.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, _radius, Paint()..color = AppColors.white);
    canvas.drawCircle(
      center,
      _radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.outline,
    );
    canvas.drawCircle(center, _radius - 4, Paint()..color = AppColors.spectrumAt(value));
  }
}
