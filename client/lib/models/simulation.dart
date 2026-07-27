import 'location_type.dart';
import 'session_request.dart';
import 'session_response.dart';

class SimulationRequest {
  final String locationName;
  final LocationType locationType;
  final SunEvent event;
  final String cloudCoverSummary;
  final double visibilityLikelihood;
  final ColorProbabilities colorProbabilities;

  const SimulationRequest({
    required this.locationName,
    required this.locationType,
    required this.event,
    required this.cloudCoverSummary,
    required this.visibilityLikelihood,
    required this.colorProbabilities,
  });

  Map<String, dynamic> toJson() => {
        'location_name': locationName,
        'location_type': locationType.apiValue,
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

  const SimulationResponse({
    required this.prompt,
    required this.imageUrl,
    required this.disclaimer,
    required this.providerStatus,
  });

  factory SimulationResponse.fromJson(Map<String, dynamic> json) => SimulationResponse(
        prompt: json['prompt'] as String,
        imageUrl: json['image_url'] as String?,
        disclaimer: json['disclaimer'] as String,
        providerStatus: json['provider_status'] as String,
      );
}
