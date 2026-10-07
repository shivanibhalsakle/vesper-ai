import 'package:flutter/material.dart';

import '../models/best_date.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'animated_reveal.dart';

/// The coming days as a bar chart of their match scores, so the best day
/// stands out at a glance. The best day's bar takes its spectrum colour.
///
/// When first shown the bars grow up from the baseline one after another,
/// each percentage riding on top of its bar. The chart's size never changes
/// while this happens, so nothing around it moves.
class WeekChart extends StatelessWidget {
  final List<DayScore> days;
  final DateTime bestDate;

  const WeekChart({super.key, required this.days, required this.bestDate});

  static const _minBar = 14.0;
  static const _maxBar = 84.0;
  // Room above the tallest bar for its percentage label.
  static const _labelRoom = 22.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(child: _column(theme, days[i], i, isBest: days[i].date == bestDate)),
      ],
    );
  }

  Widget _column(ThemeData theme, DayScore day, int index, {required bool isBest}) {
    final target = _minBar + (_maxBar - _minBar) * day.score.clamp(0.0, 1.0);
    final accent = AppColors.spectrumAt(day.score);

    return Column(
      key: isBest ? const Key('best-day-tile') : null,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _maxBar + _labelRoom,
          child: AnimatedReveal(
            delay: AppMotion.dataDelay + AppMotion.barStagger * index,
            duration: AppMotion.barDuration,
            builder: (context, t) {
              final barHeight = _minBar + (target - _minBar) * t;
              return Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    key: Key('week-bar-${day.date.day}'),
                    width: 26,
                    height: barHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      color: isBest ? null : AppColors.sand,
                      gradient: isBest
                          ? LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [accent, AppColors.blush],
                            )
                          : null,
                      border: isBest ? Border.all(color: AppColors.brown, width: 1.5) : null,
                    ),
                  ),
                  Positioned(
                    bottom: barHeight + 4,
                    child: Text(
                      formatPercent(day.score),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: isBest ? FontWeight.w700 : FontWeight.w500,
                        color: isBest ? AppColors.brown : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          formatShortWeekday(day.date),
          style: theme.textTheme.labelSmall?.copyWith(
            color: isBest ? AppColors.brown : AppColors.textSecondary,
            fontWeight: isBest ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          '${day.date.day}',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: isBest ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
