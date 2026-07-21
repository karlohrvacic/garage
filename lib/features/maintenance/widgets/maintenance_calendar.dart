import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../domain/maintenance/date_math.dart';
import '../../../domain/maintenance/reminder_projection.dart';
import '../service_type_labels.dart';

/// Collapses projections onto calendar days, ignoring time of day, so a month
/// grid can render one marker per day.
Map<DateTime, List<ReminderProjection>> groupByDay(
  List<ReminderProjection> projections,
) {
  final grouped = <DateTime, List<ReminderProjection>>{};
  for (final projection in projections) {
    final day = DateMath.dateOnly(projection.projectedDueDate);
    grouped.putIfAbsent(day, () => []).add(projection);
  }
  return grouped;
}

/// Severity ordering: overdue outranks due outranks upcoming. A day inherits
/// the colour of its most urgent item.
ReminderState _mostSevere(List<ReminderProjection> items) {
  if (items.any((p) => p.state == ReminderState.overdue)) {
    return ReminderState.overdue;
  }
  if (items.any((p) => p.state == ReminderState.due)) {
    return ReminderState.due;
  }
  return ReminderState.upcoming;
}

class MaintenanceCalendar extends StatelessWidget {
  const MaintenanceCalendar({
    required this.projections,
    required this.month,
    required this.onMonthChanged,
    super.key,
  });

  final List<ReminderProjection> projections;
  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;

  Color _stateColor(GarageTokens tokens, ReminderState state) {
    return switch (state) {
      ReminderState.overdue => tokens.danger,
      ReminderState.due => tokens.warn,
      ReminderState.upcoming => tokens.muted,
    };
  }

  void _showDay(
    BuildContext context,
    DateTime day,
    List<ReminderProjection> items,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(GarageTokens.space4),
          children: [
            for (final projection in items)
              ListTile(
                title: Text(serviceTypeLabel(l10n, projection.serviceTypeKey)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final locale = Localizations.localeOf(context).languageCode;
    final grouped = groupByDay(projections);

    final firstOfMonth = DateTime(month.year, month.month);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    // Monday-first grid: Dart weekday is 1 (Mon)…7 (Sun).
    final leadingBlanks = firstOfMonth.weekday - 1;
    final totalCells = leadingBlanks + daysInMonth;

    final weekdayLabels = [
      for (var i = 0; i < 7; i++)
        DateFormat.E(locale).format(DateTime(2024, 1, 1 + i)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: GarageTokens.space4,
            vertical: GarageTokens.space2,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    onMonthChanged(DateTime(month.year, month.month - 1)),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM(locale).format(firstOfMonth),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    onMonthChanged(DateTime(month.year, month.month + 1)),
              ),
            ],
          ),
        ),
        Row(
          children: [
            for (final label in weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: tokens.muted),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: GarageTokens.space2),
        Expanded(
          child: GridView.count(
            crossAxisCount: 7,
            padding: const EdgeInsets.symmetric(
              horizontal: GarageTokens.space2,
            ),
            children: [
              for (var i = 0; i < totalCells; i++)
                if (i < leadingBlanks)
                  const SizedBox.shrink()
                else
                  _DayCell(
                    day: DateTime(month.year, month.month, i - leadingBlanks + 1),
                    items: grouped[DateTime(
                          month.year,
                          month.month,
                          i - leadingBlanks + 1,
                        )] ??
                        const [],
                    dotColor: (items) => _stateColor(tokens, _mostSevere(items)),
                    onTap: _showDay,
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.items,
    required this.dotColor,
    required this.onTap,
  });

  final DateTime day;
  final List<ReminderProjection> items;
  final Color Function(List<ReminderProjection>) dotColor;
  final void Function(BuildContext, DateTime, List<ReminderProjection>) onTap;

  @override
  Widget build(BuildContext context) {
    final numeric = GarageTheme.numeric(
      Theme.of(context).textTheme.bodySmall!,
    );
    return InkWell(
      onTap: items.isEmpty ? null : () => onTap(context, day, items),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${day.day}', style: numeric),
          const SizedBox(height: 2),
          if (items.isNotEmpty)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor(items),
                shape: BoxShape.circle,
              ),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}
