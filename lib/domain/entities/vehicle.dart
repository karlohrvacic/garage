/// A vehicle owned by a household. `fuelTypeKey` is a language-neutral key
/// such as `fuel_petrol` or `fuel_electric`, resolved to a localized label at
/// the presentation layer.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.householdId,
    required this.nickname,
    required this.fuelTypeKey,
    required this.baselineOdometerKm,
    required this.baselineDate,
    this.make,
    this.model,
    this.year,
    this.trim,
    this.vin,
    this.plate,
    this.photoUrl,
    this.archived = false,
  });

  final String id;
  final String householdId;
  final String nickname;
  final String fuelTypeKey;

  /// Where the vehicle stood when it was added. Maintenance whose last service
  /// is unknown projects from here, so a brand-new interval on a car with
  /// 180,000 km does not compute as though the car were at zero.
  final int baselineOdometerKm;

  /// UTC. Every [DateTime] in the domain layer is UTC — the repository layer
  /// converts to UTC on the way in and to local time on the way out. Mixing
  /// the two silently breaks equality: `DateTime.==` compares the `isUtc`
  /// flag as well as the instant.
  final DateTime baselineDate;

  final String? make;
  final String? model;
  final int? year;
  final String? trim;
  final String? vin;
  final String? plate;
  final String? photoUrl;
  final bool archived;

  Vehicle copyWith({
    String? nickname,
    String? fuelTypeKey,
    int? baselineOdometerKm,
    DateTime? baselineDate,
    String? make,
    String? model,
    int? year,
    String? trim,
    String? vin,
    String? plate,
    String? photoUrl,
    bool? archived,
  }) {
    return Vehicle(
      id: id,
      householdId: householdId,
      nickname: nickname ?? this.nickname,
      fuelTypeKey: fuelTypeKey ?? this.fuelTypeKey,
      baselineOdometerKm: baselineOdometerKm ?? this.baselineOdometerKm,
      baselineDate: baselineDate ?? this.baselineDate,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      trim: trim ?? this.trim,
      vin: vin ?? this.vin,
      plate: plate ?? this.plate,
      photoUrl: photoUrl ?? this.photoUrl,
      archived: archived ?? this.archived,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Vehicle &&
        other.id == id &&
        other.householdId == householdId &&
        other.nickname == nickname &&
        other.fuelTypeKey == fuelTypeKey &&
        other.baselineOdometerKm == baselineOdometerKm &&
        other.baselineDate == baselineDate &&
        other.make == make &&
        other.model == model &&
        other.year == year &&
        other.trim == trim &&
        other.vin == vin &&
        other.plate == plate &&
        other.photoUrl == photoUrl &&
        other.archived == archived;
  }

  @override
  int get hashCode => Object.hash(
        id,
        householdId,
        nickname,
        fuelTypeKey,
        baselineOdometerKm,
        baselineDate,
        make,
        model,
        year,
        trim,
        vin,
        plate,
        photoUrl,
        archived,
      );

  @override
  String toString() {
    return 'Vehicle(id: $id, householdId: $householdId, nickname: $nickname, '
        'fuelTypeKey: $fuelTypeKey, baselineOdometerKm: $baselineOdometerKm, '
        'baselineDate: $baselineDate, make: $make, model: $model, year: $year, '
        'trim: $trim, vin: $vin, plate: $plate, photoUrl: $photoUrl, '
        'archived: $archived)';
  }
}
