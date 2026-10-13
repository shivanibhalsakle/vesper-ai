import 'location_type.dart';
import 'session_request.dart';
import 'session_response.dart';

class SimulationRequest {
  final String locationName;
  // Null for a place picked on the map, which has no spot type.
  final LocationType? locationType;
  final SunEvent event;
  final String cloudCoverSummary;
  final double visibilityLikelihood;
  final ColorProbabilities colorProbabilities;

  const SimulationRequest({
    required this.locationName,
    this.locationType,
    required this.event,
    required this.cloudCoverSummary,
    required this.visibilityLikelihood,
    required this.colorProbabilities,
  });

  Map<String, dynamic> toJson() => {
        'location_name': locationName,
        if (locationType != null) 'location_type': locationType!.apiValue,
        'event': event.apiValue,
        'cloud_cover_summary': cloudCoverSummary,
        'visibility_likelihood': visibilityLikelihood,
        'color_probabilities': colorProbabilities.toJson(),
      };
}

class SimulationResponse {
  final String prompt;
  final String? imageUrl;
  final String disclaimer;
  final String providerStatus;
  final int remainingToday;

  /// Set when the image was also kept in the user's Sky previews gallery.
  final String? previewId;
  final bool saved;

  const SimulationResponse({
    required this.prompt,
    required this.imageUrl,
    required this.disclaimer,
    required this.providerStatus,
    required this.remainingToday,
    this.previewId,
    this.saved = false,
  });

  factory SimulationResponse.fromJson(Map<String, dynamic> json) => SimulationResponse(
        prompt: json['prompt'] as String,
        imageUrl: json['image_url'] as String?,
        disclaimer: json['disclaimer'] as String,
        providerStatus: json['provider_status'] as String,
        remainingToday: json['remaining_today'] as int,
        previewId: json['preview_id'] as String?,
        saved: json['saved'] as bool? ?? false,
      );
}

/// How many previews the user can still generate today.
class RemainingPreviews {
  final int remainingToday;
  final int dailyLimit;

  const RemainingPreviews({required this.remainingToday, required this.dailyLimit});

  factory RemainingPreviews.fromJson(Map<String, dynamic> json) => RemainingPreviews(
        remainingToday: json['remaining_today'] as int,
        dailyLimit: json['daily_limit'] as int,
      );
}

/// One image in the user's Sky previews gallery.
class SkyPreviewRecord {
  final String id;

  /// A short-lived link to the stored image; the list is fetched fresh each
  /// time it is opened.
  final String imageUrl;
  final String locationName;
  final LocationType? locationType;
  final SunEvent event;
  final String prompt;
  final String disclaimer;
  final DateTime createdAt;

  const SkyPreviewRecord({
    required this.id,
    required this.imageUrl,
    required this.locationName,
    required this.locationType,
    required this.event,
    required this.prompt,
    required this.disclaimer,
    required this.createdAt,
  });

  factory SkyPreviewRecord.fromJson(Map<String, dynamic> json) => SkyPreviewRecord(
        id: json['id'] as String,
        imageUrl: json['image_url'] as String,
        locationName: json['location_name'] as String,
        locationType: json['location_type'] == null
            ? null
            : LocationType.fromApiValue(json['location_type'] as String),
        event: SunEvent.fromApiValue(json['event'] as String),
        prompt: json['prompt'] as String,
        disclaimer: json['disclaimer'] as String,
        // The server stores UTC without an offset marker.
        createdAt: DateTime.parse(
          (json['created_at'] as String).endsWith('Z')
              ? json['created_at'] as String
              : '${json['created_at']}Z',
        ).toLocal(),
      );
}
