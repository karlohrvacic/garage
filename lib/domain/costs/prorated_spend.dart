import '../entities/cost_entry.dart';
import '../maintenance/date_math.dart';
import '../maintenance/recurring_costs.dart';

/// The total of [entries] over `[since, until]`, prorating the categories
/// that cover a period rather than a moment.
///
/// Registration and insurance are paid once for a year of cover, not once
/// for the day they were paid: summing them raw means a household two years
/// into owning a car, tracked from day one, sees both years' premiums land
/// on the running total the moment the second is paid — twice a year's cover
/// charged for one year actually driven. Each such entry instead contributes
/// only the slice of its own coverage period that falls inside the window,
/// so a premium half spent and half still ahead reports as half spent.
///
/// Every other category — parking, tolls, a vignette, a wash — is a cost for
/// a moment, not a period, and counts in full on the day it was paid, same
/// as before.
double proratedSpend(
  List<CostEntry> entries, {
  required DateTime since,
  required DateTime until,
}) {
  final windowEndExclusive = DateMath.dateOnly(
    until,
  ).add(const Duration(days: 1));

  var total = 0.0;
  for (final entry in entries) {
    final due = RecurringCosts.nextDue(
      category: entry.category,
      paidOn: entry.date,
    );
    if (due == null) {
      total += entry.amount;
      continue;
    }

    // [entry.date, periodEndExclusive) is the coverage period; [dueDate] is
    // the day cover is next due, not the last day it holds.
    final periodEndExclusive = due.dueDate;
    final periodDays = DateMath.daysBetween(entry.date, periodEndExclusive);
    if (periodDays <= 0) {
      // A malformed period (a due date on or before the day paid) has
      // nothing sensible to prorate against; count it in full rather than
      // silently dropping a real payment.
      total += entry.amount;
      continue;
    }

    final overlapStart = entry.date.isAfter(since) ? entry.date : since;
    final overlapEndExclusive = periodEndExclusive.isBefore(windowEndExclusive)
        ? periodEndExclusive
        : windowEndExclusive;
    final overlapDays = DateMath.daysBetween(overlapStart, overlapEndExclusive);
    if (overlapDays <= 0) {
      continue;
    }
    total += entry.amount * overlapDays.clamp(0, periodDays) / periodDays;
  }
  return total;
}
