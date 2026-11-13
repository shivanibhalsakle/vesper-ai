import 'session_request.dart';

/// A preview of a place that someone else generated. Nothing here says who.
class SharedPreview {
  final String id;

  /// Short-lived links, fetched fresh each time the collection is opened.
  final String imageUrl;
  final String thumbUrl;
  final String placeName;
  final SunEvent event;

  /// The day of the sky it shows (older previews may not have one).
  final DateTime? eventDate;
  final String disclaimer;
  final DateTime createdAt;

  const SharedPreview({
    required this.id,
    required this.imageUrl,
    required this.thumbUrl,
    required this.placeName,
    required this.event,
    required this.eventDate,
    required this.disclaimer,
    required this.createdAt,
  });

  factory SharedPreview.fromJson(Map<String, dynamic> json) => SharedPreview(
        id: json['id'] as String,
        imageUrl: json['image_url'] as String,
        thumbUrl: json['thumb_url'] as String,
        placeName: json['place_name'] as String,
        event: SunEvent.fromApiValue(json['event'] as String),
        eventDate:
            json['event_date'] == null ? null : DateTime.parse(json['event_date'] as String),
        disclaimer: json['disclaimer'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  /// The day to write on it: the sky's day, else the day it was made.
  DateTime get displayDate => eventDate ?? createdAt;
}

/// What the app needs to know about a place's shared previews to decide what
/// to show on its card.
class PlacePreviewCount {
  final String placeId;

  /// How many previews by other people can be opened.
  final int count;

  /// The place has a large number of previews overall.
  final bool popular;

  const PlacePreviewCount({required this.placeId, required this.count, required this.popular});

  factory PlacePreviewCount.fromJson(Map<String, dynamic> json) => PlacePreviewCount(
        placeId: json['place_id'] as String,
        count: json['count'] as int,
        popular: json['popular'] as bool,
      );
}
