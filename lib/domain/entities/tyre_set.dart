/// What a set of tyres is for. Stored as the language-neutral key the
/// `tyre_sets.season` column checks against.
enum TyreSeason {
  summer('summer'),
  winter('winter'),
  allSeason('all_season');

  const TyreSeason(this.key);

  final String key;

  /// Anything unrecognised reads as all-season: a set whose season this
  /// version does not know is still a set the household owns.
  static TyreSeason fromKey(String key) {
    for (final season in values) {
      if (season.key == key) {
        return season;
      }
    }
    return TyreSeason.allSeason;
  }
}

/// One measurement of a set's tread, per corner, in millimetres.
class TyreReading {
  const TyreReading({
    required this.id,
    required this.date,
    this.odometerKm,
    this.frontLeftMm,
    this.frontRightMm,
    this.rearLeftMm,
    this.rearRightMm,
  });

  final String id;

  /// UTC date-only, like every domain [DateTime].
  final DateTime date;

  final int? odometerKm;
  final double? frontLeftMm;
  final double? frontRightMm;
  final double? rearLeftMm;
  final double? rearRightMm;

  /// The worst corner, which is the one that decides the set: tyres are
  /// replaced together, and a roadworthiness check reads the shallowest.
  double? get shallowestMm {
    double? worst;
    for (final corner in [frontLeftMm, frontRightMm, rearLeftMm, rearRightMm]) {
      if (corner != null && (worst == null || corner < worst)) {
        worst = corner;
      }
    }
    return worst;
  }

  @override
  bool operator ==(Object other) {
    return other is TyreReading &&
        other.id == id &&
        other.date == date &&
        other.odometerKm == odometerKm &&
        other.frontLeftMm == frontLeftMm &&
        other.frontRightMm == frontRightMm &&
        other.rearLeftMm == rearLeftMm &&
        other.rearRightMm == rearRightMm;
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    odometerKm,
    frontLeftMm,
    frontRightMm,
    rearLeftMm,
    rearRightMm,
  );

  @override
  String toString() =>
      'TyreReading(id: $id, date: $date, shallowestMm: $shallowestMm)';
}

/// A set of tyres a household owns, tracked in its own right.
///
/// A seasonal swap moves a whole set on and off the car, and each set wears on
/// its own schedule — so the set, not the vehicle, is what carries the tread
/// history and the storage location.
class TyreSet {
  const TyreSet({
    required this.id,
    required this.vehicleId,
    required this.name,
    required this.season,
    required this.fitted,
    required this.createdBy,
    this.size,
    this.storageLocation,
    this.fittedAt,
    this.retiredAt,
    this.readings = const [],
  });

  /// The EU minimum tread depth for a passenger tyre. Winter tyres are held to
  /// more in several countries, and this is the floor everywhere.
  static const double legalMinimumMm = 1.6;

  final String id;
  final String vehicleId;
  final String name;
  final TyreSeason season;

  /// On the car right now, rather than in storage.
  final bool fitted;

  final String? size;
  final String? storageLocation;
  final DateTime? fittedAt;
  final DateTime? retiredAt;
  final String createdBy;

  /// Tread measurements, newest last.
  final List<TyreReading> readings;

  bool get isRetired => retiredAt != null;

  TyreReading? get latestReading {
    TyreReading? latest;
    for (final reading in readings) {
      if (latest == null || reading.date.isAfter(latest.date)) {
        latest = reading;
      }
    }
    return latest;
  }

  /// Whether the last measurement puts the set at or under the legal floor. A
  /// set nobody has measured is not flagged — absence of a reading is not
  /// evidence of wear.
  bool get isBelowLegalTread {
    final shallowest = latestReading?.shallowestMm;
    return shallowest != null && shallowest <= legalMinimumMm;
  }

  @override
  bool operator ==(Object other) {
    return other is TyreSet &&
        other.id == id &&
        other.vehicleId == vehicleId &&
        other.name == name &&
        other.season == season &&
        other.fitted == fitted &&
        other.size == size &&
        other.storageLocation == storageLocation &&
        other.fittedAt == fittedAt &&
        other.retiredAt == retiredAt &&
        other.createdBy == createdBy &&
        _sameReadings(other.readings, readings);
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    name,
    season,
    fitted,
    size,
    storageLocation,
    fittedAt,
    retiredAt,
    createdBy,
    Object.hashAll(readings),
  );

  @override
  String toString() =>
      'TyreSet(id: $id, name: $name, season: ${season.key}, fitted: $fitted, '
      'readings: ${readings.length})';
}

/// Lists compare by identity, so two sets carrying the same readings in
/// separate list objects would otherwise come out unequal.
bool _sameReadings(List<TyreReading> a, List<TyreReading> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// Whether a vehicle's tyres are swapped with the seasons.
///
/// A seasonal swap reminder says something about how a car is shod. On
/// all-season tyres there is no swap to do, and the reminder returns twice a
/// year forever with nothing behind it.
abstract final class TyreSeasons {
  /// True unless the household has recorded tyres and none of them are
  /// seasonal.
  ///
  /// Tyre tracking is optional, so an empty list means "not recorded", not
  /// "all-season". Silence is never taken as evidence.
  static bool swapsSeasonally(List<TyreSet> sets) {
    final inUse = sets.where((set) => set.retiredAt == null).toList();
    if (inUse.isEmpty) {
      return true;
    }
    return inUse.any((set) => set.season != TyreSeason.allSeason);
  }
}
