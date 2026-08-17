import '../entities/fuel_entry.dart';
import 'odometer_history.dart';

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

  /// The window for an entry dated [date], measured against **every** kind of
  /// reading rather than fill-ups alone.
  ///
  /// [forDate] saw only the fuel log, so a household that logs services or
  /// bare readings and pays cash at the pump could type any number into a
  /// fill-up and be told nothing — which is the household odometer entries
  /// exist for. Same rule as before, wider evidence.
  ///
  /// [excluding] drops the reading the entry being edited contributes, so a
  /// fill-up is never measured against its own stored figure. Matched by value
  /// because a sample carries no id; two readings that agree on both day and
  /// distance are interchangeable for this purpose anyway.
  static OdometerBounds forSamples(
    Iterable<OdometerSample> samples, {
    required DateTime date,
    OdometerSample? excluding,
  }) {
    final day = _dayOf(date);
    int? previous;
    int? next;
    var skippedOwn = false;

    for (final sample in samples) {
      if (!skippedOwn && excluding != null && sample == excluding) {
        skippedOwn = true;
        continue;
      }
      final sampleDay = _dayOf(sample.date);
      if (sampleDay.isBefore(day)) {
        if (previous == null || sample.km > previous) {
          previous = sample.km;
        }
      } else if (sampleDay.isAfter(day)) {
        if (next == null || sample.km < next) {
          next = sample.km;
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
