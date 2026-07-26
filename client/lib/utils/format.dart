/// Extracts the clock time from an ISO 8601 datetime string without
/// converting through DateTime (see the comment on LocationResult for why).
String formatClockTime(String isoDateTime) {
  final hour24 = int.parse(isoDateTime.substring(11, 13));
  final minute = isoDateTime.substring(14, 16);
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:$minute $period';
}

String formatArrivalOffset(int offsetMinutes, String eventLabel) {
  if (offsetMinutes < 0) {
    return 'Arrive ~${-offsetMinutes} min before $eventLabel';
  }
  if (offsetMinutes > 0) {
    return 'Arrive ~$offsetMinutes min after $eventLabel — '
        'conditions expected to be more dynamic post-event';
  }
  return 'Arrive right at $eventLabel';
}

String formatPercent(double value) => '${(value * 100).round()}%';
