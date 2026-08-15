import '../entities/fuel_entry.dart';

/// The window an odometer reading has to fall in to be consistent with the
/// rest of the log.
///
/// A reading is only suspect relative to the fills that bracket it in time:
/// nothing logged before it may read higher, nothing logged after it may read
/// lower. Fills sharing a date impose no order on each other — the stored date
/// has no time of day, so their sequence within the day is unknowable.
class OdometerBounds {
  const OdometerBounds({this.previousKm, this.nextKm});

  /// The highest reading logged before the date in question, if any.
  final int? previousKm;

  /// The lowest reading logged after the date in question, if any.
  final int? nextKm;

  bool isTooLow(int odometerKm) =>
      previousKm != null && odometerKm < previousKm!;

  bool isTooHigh(int odometerKm) => nextKm != null && odometerKm > nextKm!;

  /// The window for an entry dated [date].
  ///
  /// [excludingId] drops the entry being edited, so an existing fill-up is
  /// never measured against its own stored reading — the reason a plain
  /// "must beat the newest reading" rule cannot be used for edits, nor for a
  /// fill-up backdated into the middle of the log.
  static OdometerBounds forDate(
    List<FuelEntry> entries, {
    required DateTime date,
    String? excludingId,
  }) {
    final day = _dayOf(date);
    int? previous;
    int? next;

    for (final entry in entries) {
      if (entry.id == excludingId) {
        continue;
      }
      final entryDay = _dayOf(entry.date);
      if (entryDay.isBefore(day)) {
        if (previous == null || entry.odometerKm > previous) {
          previous = entry.odometerKm;
        }
      } else if (entryDay.isAfter(day)) {
        if (next == null || entry.odometerKm < next) {
          next = entry.odometerKm;
        }
      }
    }

    return OdometerBounds(previousKm: previous, nextKm: next);
  }

  /// Calendar day, so a local form date and a stored UTC-midnight date compare
  /// as the day the user picked rather than by instant.
  static DateTime _dayOf(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
}
