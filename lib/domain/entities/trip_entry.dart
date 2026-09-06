/// Why a journey was made. A mileage logbook is only useful for tax if it
/// separates the two, and the split is the whole reason to keep one.
enum TripPurpose {
  private('private'),
  business('business');

  const TripPurpose(this.key);

  /// The stored key, deliberately not [name], so renaming the Dart value
  /// cannot reinterpret rows already written.
  final String key;

  static TripPurpose fromKey(String key) {
    for (final purpose in values) {
      if (purpose.key == key) {
        return purpose;
      }
    }
    return TripPurpose.private;
  }
}

/// One journey: where it went, how far, and whether it was work.
///
/// Distance is stored rather than derived from the odometer range, because the
/// two are not the same claim. An odometer range says what the car did between
/// two readings; a trip's distance is what this journey covered, and a day of
/// errands between two readings is several trips.
class TripEntry {
  const TripEntry({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.distanceKm,
    required this.purpose,
    required this.createdBy,
    this.title,
    this.fromPlace,
    this.toPlace,
    this.startOdometerKm,
    this.endOdometerKm,
    this.minutes,
    this.notes,
    this.driver,
    this.createdAt,
    this.routeId,
    this.comparable = true,
    this.startedAt,
  });

  final String id;
  final String vehicleId;

  /// UTC. Every [DateTime] in the domain layer is UTC — the repository layer
  /// converts to UTC on the way in and to local time on the way out.
  final DateTime date;

  final double distanceKm;
  final TripPurpose purpose;
  final String createdBy;

  /// The named journey this is one run of, when it is one.
  ///
  /// A route is what makes "how long does this drive take" answerable: without
  /// it the same commute is recorded as "work", "Work" and "to the office" and
  /// can never be grouped.
  final String? routeId;

  /// Whether this run belongs in a comparison of the route.
  ///
  /// False for the day there was a detour, a shopping stop, or a closed road.
  /// Such a run is kept and drawn, and left out of the median, because hiding
  /// it would let a chart quietly answer a different question.
  final bool comparable;

  /// When the drive began, for the journeys opened as a draft rather than
  /// typed in afterwards. Null on a trip entered later, which is why a
  /// departure-time comparison has to say how many journeys it could not use.
  final DateTime? startedAt;

  final String? title;
  final String? fromPlace;
  final String? toPlace;

  /// Optional: a trip logged from the dashboard rather than from two readings
  /// has none, and a trip that has them still stores its own distance.
  final int? startOdometerKm;
  final int? endOdometerKm;

  /// How long it took. Optional because most people will not time their
  /// errands, and a logbook that demands it stops being kept.
  final int? minutes;

  final String? notes;

  /// Who was driving, as text.
  ///
  /// Not [createdBy], which records who *typed* the row: in a shared garage
  /// one person routinely logs the journey another one made, and a mileage
  /// logbook that names the wrong person is worse than one that names nobody.
  /// Free text rather than a household member, because the driver of a
  /// company van is often not a member of the garage at all.
  final String? driver;

  /// When the entry was logged, not the day the journey happened — [date] is
  /// that. Used to break ties when two entries share a [date] on the
  /// timeline.
  final DateTime? createdAt;

  /// Average speed, or null when the trip was not timed or took no time.
  double? get kmPerHour {
    final duration = minutes;
    if (duration == null || duration <= 0) {
      return null;
    }
    return distanceKm / (duration / 60);
  }

  TripEntry copyWith({
    String? id,
    String? vehicleId,
    DateTime? date,
    double? distanceKm,
    TripPurpose? purpose,
    String? createdBy,
    String? title,
    String? fromPlace,
    String? toPlace,
    int? startOdometerKm,
    int? endOdometerKm,
    int? minutes,
    String? notes,
    String? driver,
    DateTime? createdAt,
    String? routeId,
    bool? comparable,
    DateTime? startedAt,
  }) {
    return TripEntry(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      distanceKm: distanceKm ?? this.distanceKm,
      purpose: purpose ?? this.purpose,
      createdBy: createdBy ?? this.createdBy,
      title: title ?? this.title,
      fromPlace: fromPlace ?? this.fromPlace,
      toPlace: toPlace ?? this.toPlace,
      startOdometerKm: startOdometerKm ?? this.startOdometerKm,
      endOdometerKm: endOdometerKm ?? this.endOdometerKm,
      minutes: minutes ?? this.minutes,
      notes: notes ?? this.notes,
      driver: driver ?? this.driver,
      createdAt: createdAt ?? this.createdAt,
      routeId: routeId ?? this.routeId,
      comparable: comparable ?? this.comparable,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TripEntry &&
        other.id == id &&
        other.vehicleId == vehicleId &&
        other.date == date &&
        other.distanceKm == distanceKm &&
        other.purpose == purpose &&
        other.createdBy == createdBy &&
        other.routeId == routeId &&
        other.comparable == comparable &&
        other.startedAt == startedAt &&
        other.title == title &&
        other.fromPlace == fromPlace &&
        other.toPlace == toPlace &&
        other.startOdometerKm == startOdometerKm &&
        other.endOdometerKm == endOdometerKm &&
        other.minutes == minutes &&
        other.notes == notes &&
        other.driver == driver &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    date,
    distanceKm,
    purpose,
    createdBy,
    title,
    fromPlace,
    toPlace,
    startOdometerKm,
    endOdometerKm,
    minutes,
    notes,
    driver,
    createdAt,
    // Object.hash takes twenty at most; these three matter because a route
    // assignment or a comparability flag changing must not compare equal.
    Object.hash(routeId, comparable, startedAt),
  );

  @override
  String toString() {
    return 'TripEntry(id: $id, vehicleId: $vehicleId, date: $date, '
        'distanceKm: $distanceKm, purpose: $purpose, title: $title, '
        'from: $fromPlace, to: $toPlace, minutes: $minutes)';
  }
}
