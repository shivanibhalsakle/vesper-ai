import 'session_request.dart';

String _formatApiDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class SavedDateRequest {
  final DateTime eventDate;
  final SunEvent event;
  final double lat;
  final double lon;
  final String label;
  final double? savedScore;
  final String? fcmToken;

  const SavedDateRequest({
    required this.eventDate,
    required this.event,
    required this.lat,
    required this.lon,
    required this.label,
    this.savedScore,
    this.fcmToken,
  });

  Map<String, dynamic> toJson() => {
        'event_date': _formatApiDate(eventDate),
        'event': event.apiValue,
        'lat': lat,
        'lon': lon,
        'label': label,
        'saved_score': savedScore,
        'fcm_token': fcmToken,
      };
}

class SavedDate {
  final String id;
  final DateTime eventDate;
  final SunEvent event;
  final double lat;
  final double lon;
  final String label;
  final double? savedScore;
  final bool notificationEnabled;

  const SavedDate({
    required this.id,
    required this.eventDate,
    required this.event,
    required this.lat,
    required this.lon,
    required this.label,
    required this.savedScore,
    required this.notificationEnabled,
  });

  SavedDate copyWith({bool? notificationEnabled}) => SavedDate(
        id: id,
        eventDate: eventDate,
        event: event,
        lat: lat,
        lon: lon,
        label: label,
        savedScore: savedScore,
        notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      );

  factory SavedDate.fromJson(Map<String, dynamic> json) => SavedDate(
        id: json['id'] as String,
        eventDate: DateTime.parse(json['event_date'] as String),
        event: SunEvent.fromApiValue(json['event'] as String),
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        label: json['label'] as String,
        savedScore: (json['saved_score'] as num?)?.toDouble(),
        notificationEnabled: json['notification_enabled'] as bool,
      );
}
