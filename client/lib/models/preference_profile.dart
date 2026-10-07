class PreferenceProfile {
  final double clearSky;
  final double dramaticClouds;
  final double pinkPurple;
  final double goldenOrange;
  final double redSky;

  const PreferenceProfile({
    this.clearSky = 0.0,
    this.dramaticClouds = 0.0,
    this.pinkPurple = 0.0,
    this.goldenOrange = 0.0,
    this.redSky = 0.0,
  });

  /// Whether any of the sky-condition sliders is set.
  bool get hasSkyPreference =>
      clearSky + dramaticClouds + pinkPurple + goldenOrange + redSky > 0;

  PreferenceProfile copyWith({
    double? clearSky,
    double? dramaticClouds,
    double? pinkPurple,
    double? goldenOrange,
    double? redSky,
  }) {
    return PreferenceProfile(
      clearSky: clearSky ?? this.clearSky,
      dramaticClouds: dramaticClouds ?? this.dramaticClouds,
      pinkPurple: pinkPurple ?? this.pinkPurple,
      goldenOrange: goldenOrange ?? this.goldenOrange,
      redSky: redSky ?? this.redSky,
    );
  }

  /// Keys the backend still sends for the retired location-composition
  /// sliders are simply ignored.
  factory PreferenceProfile.fromJson(Map<String, dynamic> json) {
    double weight(String key) => (json[key] as num?)?.toDouble() ?? 0.0;
    return PreferenceProfile(
      clearSky: weight('clear_sky'),
      dramaticClouds: weight('dramatic_clouds'),
      pinkPurple: weight('pink_purple'),
      goldenOrange: weight('golden_orange'),
      redSky: weight('red_sky'),
    );
  }

  Map<String, dynamic> toJson() => {
        'clear_sky': clearSky,
        'dramatic_clouds': dramaticClouds,
        'pink_purple': pinkPurple,
        'golden_orange': goldenOrange,
        'red_sky': redSky,
      };
}
