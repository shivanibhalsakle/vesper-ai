import 'package:flutter/material.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _weekdayInitials = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Key used to find a day cell, e.g. `cal-day-2026-10-07`.
Key calendarDayKey(DateTime d) => Key(
    'cal-day-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');

/// A month grid that marks the days the user has saved. Tapping a day
/// selects it (tap again to clear), so the list below can filter to it.
class SavedDatesCalendar extends StatefulWidget {
  final Set<DateTime> markedDates;

  /// Optional colour for each marked day's dot (e.g. by match score);
  /// days not listed use the primary colour.
  final Map<DateTime, Color> dotColors;
  final DateTime? selected;
  final ValueChanged<DateTime?> onSelected;
  final DateTime? today;

  const SavedDatesCalendar({
    super.key,
    required this.markedDates,
    this.dotColors = const {},
    required this.selected,
    required this.onSelected,
    this.today,
  });

  @override
  State<SavedDatesCalendar> createState() => _SavedDatesCalendarState();
}

class _SavedDatesCalendarState extends State<SavedDatesCalendar> {
  late DateTime _month = _initialMonth();

  DateTime get _today => _dayOnly(widget.today ?? DateTime.now());

  DateTime _initialMonth() {
    final base = widget.today ?? DateTime.now();
    return DateTime(base.year, base.month);
  }

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final marked = widget.markedDates.map(_dayOnly).toSet();
    final selected = widget.selected == null ? null : _dayOnly(widget.selected!);

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // Sunday-first: DateTime.sunday is 7, so % 7 puts Sunday in column 0.
    final leadingBlanks = DateTime(_month.year, _month.month, 1).weekday % 7;

    final cells = <Widget>[
      for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _dayCell(theme, DateTime(_month.year, _month.month, day), marked, selected),
    ];

    // Cells are square, so on a wide screen (web) an unbounded grid would
    // make them huge; keep the calendar phone-sized.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: _grid(theme, cells),
      ),
    );
  }

  Widget _grid(ThemeData theme, List<Widget> cells) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous month',
              onPressed: () => _shiftMonth(-1),
            ),
            Expanded(
              child: Text(
                '${_monthNames[_month.month - 1]} ${_month.year}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next month',
              onPressed: () => _shiftMonth(1),
            ),
          ],
        ),
        Row(
          children: [
            for (final initial in _weekdayInitials)
              Expanded(
                child: Center(child: Text(initial, style: theme.textTheme.bodySmall)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cells,
        ),
      ],
    );
  }

  Widget _dayCell(ThemeData theme, DateTime day, Set<DateTime> marked, DateTime? selected) {
    final isMarked = marked.contains(day);
    final isSelected = selected == day;
    final isToday = day == _today;
    final scheme = theme.colorScheme;

    return InkWell(
      key: calendarDayKey(day),
      customBorder: const CircleBorder(),
      onTap: () => widget.onSelected(isSelected ? null : day),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? scheme.primary : null,
          border: isToday && !isSelected ? Border.all(color: scheme.primary) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(color: isSelected ? scheme.onPrimary : null),
            ),
            SizedBox(
              height: 6,
              child: isMarked
                  ? Container(
                      key: const Key('saved-dot'),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? scheme.onPrimary
                            : (widget.dotColors[day] ?? scheme.primary),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
