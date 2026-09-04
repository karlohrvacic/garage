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

/// The Monday the runway starts on, and the day it ends before. One place,
/// because the runway and "further out" have to agree to the day on where
/// one stops and the other begins.
({DateTime firstWeekStart, DateTime horizon}) runwayBounds(DateTime today) {
  // Calendar reconstruction rather than Duration arithmetic: adding whole-day
  // Durations across a DST change lands at 23:00 the previous day, drifting
  // the week labels and the horizon.
  final firstWeekStart = DateTime(
    today.year,
    today.month,
    today.day - (today.weekday - 1),
  );
  final horizon = DateTime(
    firstWeekStart.year,
    firstWeekStart.month,
    firstWeekStart.day + 7 * runwayWeeks,
  );
  return (firstWeekStart: firstWeekStart, horizon: horizon);
}

/// A twelve-week view of what is coming.
///
/// Overdue items anchor at the current week rather than their original date:
/// the planner answers "what do I need to do, and when", and something already
/// late needs doing now — showing it in a past week would put it off-screen.
final runwayProvider = FutureProvider<List<RunwayWeek>>((ref) async {
  final projections = await ref.watch(householdProjectionsProvider.future);
  final today = DateMath.dateOnly(ref.watch(todayProvider));
  final (:firstWeekStart, :horizon) = runwayBounds(today);

  final weeks = List.generate(
    runwayWeeks,
    (index) => DateTime(
      firstWeekStart.year,
      firstWeekStart.month,
      firstWeekStart.day + 7 * index,
    ),
  );
  final buckets = List.generate(runwayWeeks, (_) => <ReminderProjection>[]);

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

/// Everything due beyond the runway, soonest first.
///
/// The first reminder most people set is an oil change a year away. The
/// runway said "Nothing due in the next 12 weeks" and nothing else, which
/// read as a failed save. Overdue items are never here: they anchor at today
/// and belong to the runway.
final furtherOutProvider = FutureProvider<List<ReminderProjection>>((
  ref,
) async {
  final projections = await ref.watch(householdProjectionsProvider.future);
  final today = DateMath.dateOnly(ref.watch(todayProvider));
  final horizon = runwayBounds(today).horizon;
  return [
    for (final projection in projections)
      if (!projection.projectedDueDate.isBefore(today) &&
          !DateMath.dateOnly(projection.projectedDueDate).isBefore(horizon))
        projection,
  ]..sort((a, b) => a.projectedDueDate.compareTo(b.projectedDueDate));
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
