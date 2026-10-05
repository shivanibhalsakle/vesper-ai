class PreferenceProfile {
  final double clearSky;
  final double dramaticClouds;
  final double pinkPurple;
  final double goldenOrange;
  final double redSky;
  final double silhouettes;
  final double waterReflection;
  final double cityScape;
  final double unobstructedHorizon;

  const PreferenceProfile({
    this.clearSky = 0.0,
    this.dramaticClouds = 0.0,
    this.pinkPurple = 0.0,
    this.goldenOrange = 0.0,
    this.redSky = 0.0,
    this.silhouettes = 0.0,
    this.waterReflection = 0.0,
    this.cityScape = 0.0,
    this.unobstructedHorizon = 0.0,
  });

  PreferenceProfile copyWith({
    double? clearSky,
    double? dramaticClouds,
    double? pinkPurple,
    double? goldenOrange,
    double? redSky,
    double? silhouettes,
    double? waterReflection,
    double? cityScape,
    double? unobstructedHorizon,
  }) {
    return PreferenceProfile(
      clearSky: clearSky ?? this.clearSky,
      dramaticClouds: dramaticClouds ?? this.dramaticClouds,
      pinkPurple: pinkPurple ?? this.pinkPurple,
      goldenOrange: goldenOrange ?? this.goldenOrange,
      redSky: redSky ?? this.redSky,
      silhouettes: silhouettes ?? this.silhouettes,
      waterReflection: waterReflection ?? this.waterReflection,
      cityScape: cityScape ?? this.cityScape,
      unobstructedHorizon: unobstructedHorizon ?? this.unobstructedHorizon,
    );
  }

  factory PreferenceProfile.fromJson(Map<String, dynamic> json) {
    double weight(String key) => (json[key] as num?)?.toDouble() ?? 0.0;
    return PreferenceProfile(
      clearSky: weight('clear_sky'),
      dramaticClouds: weight('dramatic_clouds'),
      pinkPurple: weight('pink_purple'),
      goldenOrange: weight('golden_orange'),
      redSky: weight('red_sky'),
      silhouettes: weight('silhouettes'),
      waterReflection: weight('water_reflection'),
      cityScape: weight('city_skyline'),
      unobstructedHorizon: weight('unobstructed_horizon'),
    );
  }

  Map<String, dynamic> toJson() => {
        'clear_sky': clearSky,
        'dramatic_clouds': dramaticClouds,
        'pink_purple': pinkPurple,
        'golden_orange': goldenOrange,
        'red_sky': redSky,
        'silhouettes': silhouettes,
        'water_reflection': waterReflection,
        'city_skyline': cityScape,
        'unobstructed_horizon': unobstructedHorizon,
      };
}
