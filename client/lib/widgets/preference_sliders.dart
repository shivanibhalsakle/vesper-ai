import 'package:flutter/material.dart';

import '../models/preference_profile.dart';
import 'spectrum_slider.dart';

/// The five "how much do you love this?" sky sliders, shared by Settings and
/// anywhere else a sky preference is edited or compared.
class PreferenceSliders extends StatelessWidget {
  final PreferenceProfile value;
  final ValueChanged<PreferenceProfile> onChanged;

  const PreferenceSliders({super.key, required this.value, required this.onChanged});

  Widget _slider(String label, double current, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        SpectrumSlider(value: current, onChanged: onChanged),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _slider('Clear sky, visible sun', value.clearSky,
            (v) => onChanged(value.copyWith(clearSky: v))),
        _slider('Dramatic clouds', value.dramaticClouds,
            (v) => onChanged(value.copyWith(dramaticClouds: v))),
        _slider('Pink / purple tones', value.pinkPurple,
            (v) => onChanged(value.copyWith(pinkPurple: v))),
        _slider('Golden / orange light', value.goldenOrange,
            (v) => onChanged(value.copyWith(goldenOrange: v))),
        _slider('Red skies', value.redSky, (v) => onChanged(value.copyWith(redSky: v))),
      ],
    );
  }
}
