import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/maintenance/date_math.dart';
import '../../../domain/maintenance/reminder_projection.dart';
import '../../maintenance/providers/maintenance_providers.dart';

class RunwayWeek {
  const RunwayWeek({required this.start, required this.items});

  final DateTime start;
  final List<ReminderProjection> items;
}

const int runwayWeeks = 12;

/// A twelve-week view of what is coming.
///
/// Overdue items anchor at the current week rather than their original date:
/// the planner answers "what do I need to do, and when", and something already
/// late needs doing now — showing it in a past week would put it off-screen.
final runwayProvider = FutureProvider<List<RunwayWeek>>((ref) async {
  final projections = await ref.watch(householdProjectionsProvider.future);
  final today = DateMath.dateOnly(ref.watch(todayProvider));
  // Calendar reconstruction rather than Duration arithmetic: adding whole-day
  // Durations across a DST change lands at 23:00 the previous day, drifting
  // the week labels and the horizon.
  final firstWeekStart = DateTime(
    today.year,
    today.month,
    today.day - (today.weekday - 1),
  );

  final weeks = List.generate(
    runwayWeeks,
    (index) => DateTime(
      firstWeekStart.year,
      firstWeekStart.month,
      firstWeekStart.day + 7 * index,
    ),
  );
  final buckets = List.generate(runwayWeeks, (_) => <ReminderProjection>[]);
  final horizon = DateTime(
    firstWeekStart.year,
    firstWeekStart.month,
    firstWeekStart.day + 7 * runwayWeeks,
  );

  for (final projection in projections) {
    final effective = projection.projectedDueDate.isBefore(today)
        ? today
        : DateMath.dateOnly(projection.projectedDueDate);
    if (!effective.isBefore(horizon)) {
      continue;
    }
    final index = DateMath.daysBetween(firstWeekStart, effective) ~/ 7;
    if (index >= 0 && index < runwayWeeks) {
      buckets[index].add(projection);
    }
  }

  return List.generate(
    runwayWeeks,
    (index) => RunwayWeek(start: weeks[index], items: buckets[index]),
  );
});

/// Rule ids the user has waved off in the planner. Excluding one recomputes
/// the bundle it belonged to rather than leaving a stale date on screen.
final plannerExclusionsProvider =
    NotifierProvider<PlannerExclusions, Set<String>>(PlannerExclusions.new);

class PlannerExclusions extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String ruleId) {
    state = state.contains(ruleId)
        ? ({...state}..remove(ruleId))
        : {...state, ruleId};
  }

  void clear() => state = {};
}
