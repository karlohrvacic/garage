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

/// Where on the vehicle a tread figure was measured.
///
/// A motorcycle's two tyres are stored as the left of each axle, so a bike
/// reads [frontLeft] as its front and [rearLeft] as its rear.
enum TyreCorner { frontLeft, frontRight, rearLeft, rearRight }

/// One measurement of a set's tread, per corner, in millimetres.
class TyreReading {
  const TyreReading({
    required this.id,
    required this.date,
    this.recordedAt,
    this.odometerKm,
    this.frontLeftMm,
    this.frontRightMm,
    this.rearLeftMm,
    this.rearRightMm,
  });

  final String id;

  /// UTC date-only, like every domain [DateTime].
  final DateTime date;

  /// When the row was written, which is the only thing that separates two
  /// readings measured on the same day — the correction and the figure it
  /// corrects. Null for a reading that came from somewhere without one: a
  /// restored backup, or a test.
  final DateTime? recordedAt;

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

  /// Which corner [shallowestMm] came from, or null when nothing is
  /// measured. The figure alone says a set needs replacing; the position says
  /// whether that is wear or a fault.
  TyreCorner? get shallowestCorner {
    TyreCorner? worst;
    double? depth;
    for (final (corner, value) in [
      (TyreCorner.frontLeft, frontLeftMm),
      (TyreCorner.frontRight, frontRightMm),
      (TyreCorner.rearLeft, rearLeftMm),
      (TyreCorner.rearRight, rearRightMm),
    ]) {
      if (value != null && (depth == null || value < depth)) {
        depth = value;
        worst = corner;
      }
    }
    return worst;
  }

  /// The best corner, which only matters next to [shallowestMm].
  double? get deepestMm {
    double? best;
    for (final corner in [frontLeftMm, frontRightMm, rearLeftMm, rearRightMm]) {
      if (corner != null && (best == null || corner > best)) {
        best = corner;
      }
    }
    return best;
  }

  /// The worst left-against-right difference on a single axle, or null when
  /// no axle has both of its tyres measured.
  ///
  /// This, not [spreadMm], is what points at alignment or suspension. A front
  /// tyre deeper than a rear one is ordinary: a motorcycle wears its rear out
  /// first, so does a front-wheel-drive car's front, and reporting that as a
  /// fault would flag every healthy vehicle. A motorcycle's two readings are
  /// stored as front-left and rear-left, so this is null for a bike, which is
  /// correct — two tyres on two axles cannot disagree with anything.
  double? get axleSpreadMm {
    final axle = worstAxle;
    return axle == null ? null : axle.high - axle.low;
  }

  /// The two readings of the axle that disagrees most, shallower first, so a
  /// screen can print the gap rather than only its size.
  ({double low, double high})? get worstAxle {
    ({double low, double high})? worst;
    for (final axle in [
      (frontLeftMm, frontRightMm),
      (rearLeftMm, rearRightMm),
    ]) {
      final (left, right) = axle;
      if (left == null || right == null) {
        continue;
      }
      final pair = (
        low: left < right ? left : right,
        high: left < right ? right : left,
      );
      if (worst == null || pair.high - pair.low > worst.high - worst.low) {
        worst = pair;
      }
    }
    return worst;
  }

  /// How far apart the corners are, or null when fewer than two were
  /// measured.
  ///
  /// A set worn evenly is a set wearing out; a set with one corner 3 mm
  /// shallower than another is an alignment or suspension problem, and the
  /// single worst figure never says which of the two is happening.
  double? get spreadMm {
    final measured = [
      frontLeftMm,
      frontRightMm,
      rearLeftMm,
      rearRightMm,
    ].whereType<double>().toList();
    if (measured.length < 2) {
      return null;
    }
    return deepestMm! - shallowestMm!;
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
    this.manufacturedOn,
    this.readings = const [],
  });

  /// The EU minimum tread depth for a passenger tyre. Winter tyres are held to
  /// more in several countries, and this is the floor everywhere.
  static const double legalMinimumMm = 1.6;

  /// What the law asks of *this* vehicle's tyres. A motorcycle is held to
  /// 1.0 mm in Croatia and across the EU; 1.6 mm is the car figure, and
  /// printing it on a bike is a specific legal claim that is not true — it
  /// sends a rider to buy tyres they do not need and teaches a number no
  /// roadworthiness test will agree with.
  static double legalMinimumMmFor(String vehicleKind) =>
      vehicleKind == 'motorcycle' ? 1.0 : legalMinimumMm;

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

  /// When the tyres were made, from the DOT code on the sidewall — the Monday
  /// of that week. UTC date-only like every other domain date.
  ///
  /// Null means nobody has read the sidewall, not that the set is new. Rubber
  /// perishes on a schedule of its own, so this is what separates a set that is
  /// legal on tread from one that is past it on age.
  final DateTime? manufacturedOn;

  final String createdBy;

  /// Tread measurements, newest last.
  final List<TyreReading> readings;

  bool get isRetired => retiredAt != null;

  /// Ties are broken by when the row was written, then by list order. Dates
  /// are date-only and the tread sheet stamps the day it was taken, so two
  /// readings measured on one afternoon — which is what happens when somebody
  /// misreads the gauge and measures again — are equal by date. Keeping the
  /// first meant the correction was written, stored, and never shown; keeping
  /// the last of the list meant relying on an order the database does not
  /// promise for an embedded row.
  TyreReading? get latestReading {
    TyreReading? latest;
    for (final reading in readings) {
      if (latest == null || !_isOlderThan(latest, reading)) {
        latest = reading;
      }
    }
    return latest;
  }

  /// Whether [candidate] is the earlier of the two, by date and then by when
  /// it was written. Equal on both — a backup with no timestamps — falls
  /// through to list order, which is the best that is left.
  static bool _isOlderThan(TyreReading latest, TyreReading candidate) {
    if (candidate.date.isBefore(latest.date)) {
      return true;
    }
    if (candidate.date.isAfter(latest.date)) {
      return false;
    }
    final written = candidate.recordedAt;
    final incumbent = latest.recordedAt;
    if (written == null || incumbent == null) {
      return false;
    }
    return written.isBefore(incumbent);
  }

  /// Whether the last measurement puts the set at or under the legal floor. A
  /// set nobody has measured is not flagged — absence of a reading is not
  /// evidence of wear.
  bool get isBelowLegalTread => isBelowLegal(legalMinimumMm);

  /// The same test against the figure this vehicle is actually held to.
  bool isBelowLegal(double minimumMm) {
    final shallowest = latestReading?.shallowestMm;
    return shallowest != null && shallowest <= minimumMm;
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
        other.manufacturedOn == manufacturedOn &&
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
    manufacturedOn,
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
