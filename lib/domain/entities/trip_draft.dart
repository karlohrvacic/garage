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
    date: DateTime.utc(
      draft.startedAt.year,
      draft.startedAt.month,
      draft.startedAt.day,
    ),
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
  );
}
