/// One area (a US state, say) the backend has place data for.
class CoverageRegion {
  final String slug;
  final String name;
  final double south;
  final double west;
  final double north;
  final double east;

  const CoverageRegion({
    required this.slug,
    required this.name,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  factory CoverageRegion.fromJson(Map<String, dynamic> json) => CoverageRegion(
        slug: json['slug'] as String,
        name: json['name'] as String,
        south: (json['south'] as num).toDouble(),
        west: (json['west'] as num).toDouble(),
        north: (json['north'] as num).toDouble(),
        east: (json['east'] as num).toDouble(),
      );

  bool contains(double lat, double lon) =>
      lat >= south && lat <= north && lon >= west && lon <= east;
}

/// Where Vesper has place data, from GET /coverage. Mirrors the backend's own
/// check, so the app can warn before a search that would be refused.
class Coverage {
  final List<CoverageRegion> regions;

  const Coverage(this.regions);

  factory Coverage.fromJson(Map<String, dynamic> json) => Coverage([
        for (final region in json['regions'] as List)
          CoverageRegion.fromJson(region as Map<String, dynamic>),
      ]);

  /// True/false when we know, null when nothing is loaded (the backend then
  /// doesn't refuse anyone, so neither do we).
  bool? covers(double lat, double lon) {
    if (regions.isEmpty) return null;
    return regions.any((region) => region.contains(lat, lon));
  }

  /// Short enough for one caption: the names, or a count once there are many.
  String get summary {
    if (regions.length > 8) return '${regions.length} US states and regions';
    return regions.map((region) => region.name).join(', ');
  }
}
