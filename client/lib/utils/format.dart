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

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "Wednesday, October 7"
String formatLongDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}';

/// "Wed"
String formatShortWeekday(DateTime date) => _weekdays[date.weekday - 1].substring(0, 3);
