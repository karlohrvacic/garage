/// Whether the distance between two odometer readings is one a car could
/// actually have covered.
///
/// The last shape of the mistake the other entry checks already catch
/// (decision 95, roadmap item 9): a digit typed twice, a decimal place lost,
/// a reading copied from the wrong car. Every one of those is plausible on
/// its own — 1,240,000 is a number — and only the *previous* reading makes it
/// checkable, which is why this one needs history where the others need the
/// two fields in front of you.
///
/// A warning, never a refusal. A car really can be driven onto a transporter
/// and unloaded a thousand kilometres away, and the household is the one who
/// knows whether that happened.
library;

/// A single day's allowance, over and above the sustained rate.
///
/// Zagreb to Munich and back is a real day, and two drivers sharing a car
/// have done more. Anything that questioned it would be dismissed before it
/// had something worth saying.
const double _oneLongDayKm = 1500;

/// Sustained kilometres per day. Generous on purpose: a delivery round or a
/// long-haul week really does average several hundred, and the mistakes this
/// exists for are out by a factor of ten, not by a quarter.
const double _sustainedKmPerDay = 800;

/// How far a car may have gone between two readings [days] apart before the
/// figure stops describing driving.
double plausibleDistanceKm(int days) {
  // Two readings taken the same morning have no elapsed time to divide by,
  // and a plain per-day rate would call every one of them impossible.
  final elapsed = days < 1 ? 1 : days;
  return _oneLongDayKm + _sustainedKmPerDay * elapsed;
}

/// Whether the jump from one reading to the next is too large to be driving.
///
/// False whenever there is nothing to compare against, when the reading goes
/// backwards — the sheets refuse that outright, and two sentences about one
/// mistake is worse than one — or when the dates run the wrong way.
bool isImplausibleJump({
  required int? fromKm,
  required DateTime? fromDate,
  required int toKm,
  required DateTime toDate,
}) {
  if (fromKm == null || fromDate == null) {
    return false;
  }
  final days = toDate.difference(fromDate).inDays;
  if (days < 0) {
    return false;
  }
  final travelled = toKm - fromKm;
  if (travelled <= 0) {
    return false;
  }
  return travelled > plausibleDistanceKm(days);
}
