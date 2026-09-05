/// Whether an entry about to be saved repeats one already logged.
///
/// The moment of entry is the only moment a mistake is cheap to fix. A save
/// that timed out and was tried again, a second tap on a slow button, or a
/// bill paid once and logged twice a week apart all produce the same shape:
/// two rows nothing distinguishes. Weeks later they are indistinguishable
/// from two real payments, and the totals they inflate are believed.
///
/// A warning, never a refusal — the same rule the implied-consumption check
/// follows. Two identical parking charges on one day are ordinary, and so is
/// filling the same tyre twice; the household is the one who knows.
library;

import '../entities/cost_entry.dart';
import '../entities/service_entry.dart';

/// Whether two instants fall on the same UTC day. Entry dates are date-only
/// in every screen but carry a time in storage, so comparing the instants
/// would miss a duplicate typed at a different hour.
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Money compared as money. A total the person retyped can land a fraction of
/// a cent away when it came through the calculator, and a hundredth of a
/// euro is not a different payment.
bool _sameAmount(double a, double b) => (a - b).abs() < 0.005;

/// Whether a cost repeats one already on this vehicle: same day, same
/// category, same amount.
///
/// All three have to match. Two costs of the same size on one day are common
/// enough — two tanks of AdBlue, two parking sessions — that category alone
/// would cry wolf, and a category repeats monthly by design.
///
/// [editingId] is the entry being edited, which is never a duplicate of
/// itself: without it, opening a saved cost and changing its notes would
/// accuse it of repeating the row it *is*.
bool duplicatesExistingCost({
  required Iterable<CostEntry> existing,
  required DateTime date,
  required String category,
  required double amount,
  String? editingId,
}) {
  return existing.any(
    (entry) =>
        entry.id != editingId &&
        entry.category == category &&
        _sameAmount(entry.amount, amount) &&
        _sameDay(entry.date, date),
  );
}

/// Whether a service repeats one already on this vehicle: same day, same
/// odometer, and at least one job in common.
///
/// Sharing one job is enough, and needing *every* job to match would miss the
/// case this exists for — a save retried after a timeout, where the second
/// attempt is often trimmed. Sharing none is not a duplicate at all: logging
/// one visit as an entry per job is how some households keep a record, and
/// warning about that would be wrong.
bool duplicatesExistingService({
  required Iterable<ServiceEntry> existing,
  required DateTime date,
  required int odometerKm,
  required List<String> serviceTypeKeys,
  String? editingId,
}) {
  if (serviceTypeKeys.isEmpty) {
    return false;
  }
  final keys = serviceTypeKeys.toSet();
  return existing.any(
    (entry) =>
        entry.id != editingId &&
        entry.odometerKm == odometerKm &&
        _sameDay(entry.date, date) &&
        entry.serviceTypeKeys.any(keys.contains),
  );
}
