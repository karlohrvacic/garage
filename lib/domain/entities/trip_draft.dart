import 'trip_entry.dart';

/// A drive that has started and has not finished.
///
/// It is the same row as the trip it will become: a [TripEntry] whose distance
/// is not known yet. Nothing about it is provisional except the figures nobody
/// can have until the car is parked, which is why finishing one is an update
/// rather than an insert — the journey keeps the identity, and the author, it
/// had when it set off.
class TripDraft {
  const TripDraft({
    required this.id,
    required this.vehicleId,
    required this.startedAt,
    required this.createdBy,
    this.startOdometerKm,
    this.driver,
    this.fromPlace,
    this.title,
    this.routeId,
  });

  final String id;
  final String vehicleId;

  /// UTC, like every [DateTime] in the domain layer. Read from the device
  /// clock when the drive was opened, which is the point of opening one.
  final DateTime startedAt;

  final String createdBy;
  final int? startOdometerKm;
  final String? driver;
  final String? fromPlace;
  final String? title;

  /// The named journey this run belongs to, chosen when the drive was opened.
  final String? routeId;

  /// How long the drive has been open at [now].
  ///
  /// Never negative. A phone that crosses a time zone, or a clock that
  /// corrects itself over the network, can put [startedAt] in the future, and
  /// "started in 40 minutes" is worse than "just started".
  Duration elapsedAt(DateTime now) {
    final elapsed = now.difference(startedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }
}

/// Turns a drive that has been parked into the journey it was.
///
/// Throws [ArgumentError] rather than inventing a figure: a trip nobody
/// measured is not a trip of length zero, and a silent 0 would drag down every
/// average that reads it afterwards.
TripEntry finishDraft(
  TripDraft draft, {
  required DateTime endedAt,
  int? endOdometerKm,
  double? distanceKm,
  int? minutes,
  TripPurpose purpose = TripPurpose.private,
  String? toPlace,
  String? notes,
  bool comparable = true,
}) {
  final start = draft.startOdometerKm;
  if (endOdometerKm != null && start != null && endOdometerKm < start) {
    throw ArgumentError.value(
      endOdometerKm,
      'endOdometerKm',
      'an odometer cannot go backwards over a journey',
    );
  }

  // A stated distance wins: the odometer reads whole kilometres, so a driver
  // who says 43.6 has the better figure.
  final distance =
      distanceKm ??
      (endOdometerKm != null && start != null
          ? (endOdometerKm - start).toDouble()
          : null);
  if (distance == null) {
    throw ArgumentError(
      'a finished drive needs either a distance or an odometer at both ends',
    );
  }

  final elapsed = endedAt.difference(draft.startedAt);

  return TripEntry(
    id: draft.id,
    vehicleId: draft.vehicleId,
    // The day it set off, not the day it arrived: a drive over midnight
    // belongs to the evening it began, which is the day its driver will look
    // for it under.
    //
    // The *local* day. [startedAt] is UTC, and reading its calendar fields
    // directly dated a drive begun at half past midnight in Zagreb to the day
    // before — the one night of the year a logbook is most obviously wrong.
    date: dateOfDrive(draft.startedAt),
    distanceKm: distance,
    purpose: purpose,
    createdBy: draft.createdBy,
    title: draft.title,
    fromPlace: draft.fromPlace,
    toPlace: toPlace,
    startOdometerKm: start,
    endOdometerKm: endOdometerKm,
    // Rounded, not truncated: a drive of ten minutes forty seconds is eleven
    // minutes to everyone except an integer division.
    minutes:
        minutes ??
        (elapsed.isNegative ? null : (elapsed.inSeconds / 60).round()),
    notes: notes,
    driver: draft.driver,
    routeId: draft.routeId,
    comparable: comparable,
    // Kept, so a departure-time comparison has something to work with. It is
    // also simply true: the drive did begin then.
    startedAt: draft.startedAt,
  );
}

/// The calendar day a drive belongs to: the local day it began.
///
/// Returned as UTC midnight, which is how every date-only value in the domain
/// is carried.
DateTime dateOfDrive(DateTime startedAt) {
  final local = startedAt.toLocal();
  return DateTime.utc(local.year, local.month, local.day);
}
