enum LocationType {
  beach,
  park,
  waterfront,
  promenade,
  elevatedViewpoint;

  String get apiValue => switch (this) {
        LocationType.beach => 'beach',
        LocationType.park => 'park',
        LocationType.waterfront => 'waterfront',
        LocationType.promenade => 'promenade',
        LocationType.elevatedViewpoint => 'elevated_viewpoint',
      };

  String get label => switch (this) {
        LocationType.beach => 'Beach',
        LocationType.park => 'Park',
        LocationType.waterfront => 'Waterfront',
        LocationType.promenade => 'Promenade',
        LocationType.elevatedViewpoint => 'Elevated viewpoint',
      };

  static LocationType fromApiValue(String value) => LocationType.values.firstWhere(
        (t) => t.apiValue == value,
      );
}
