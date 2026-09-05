/// What a trip's distance and time imply about how fast it went, checked at
/// the moment it is typed.
///
/// Distance and time are each plausible alone. Together they are checkable,
/// and the two mistakes this catches are the ordinary ones: an hour typed
/// into a field that counts minutes, and a distance entered in the wrong
/// order of magnitude. Neither shows up anywhere else — a business logbook's
/// totals absorb both silently, which is exactly where they cost something.
library;

/// Average speed in km/h, or null when there is nothing to divide.
double? impliedSpeedKmPerHour({
  required double? distanceKm,
  required int? minutes,
}) {
  if (distanceKm == null || minutes == null || minutes <= 0) {
    return null;
  }
  return distanceKm / (minutes / 60);
}

/// Whether a trip average is outside what a road vehicle does.
///
/// Deliberately wide, like the fill-up check. Door-to-door timing over a
/// school run in traffic really does average single digits, and a night run
/// down an empty motorway really does average 120; both are real and neither
/// should be questioned. What is left outside is arithmetic that cannot
/// describe a journey at all.
///
/// The upper bound is well above any legal limit on purpose: this is not a
/// speeding check, and an app that tutted at 140 would be ignored by the time
/// it had something worth saying.
bool isImplausibleSpeed(double? kmPerHour) {
  if (kmPerHour == null) {
    return false;
  }
  return kmPerHour < 3 || kmPerHour > 200;
}
