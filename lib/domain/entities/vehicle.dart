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
    this.tankCapacityL,
    this.secondaryFuelTypeKey,
    this.archived = false,
    this.purchasePrice,
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

  /// Usable tank size in litres, canonical like every other volume. Optional:
  /// it only powers the "more than the tank holds" check on a fill-up, so a
  /// vehicle without it behaves exactly as before.
  final double? tankCapacityL;

  /// A second fuel this car also takes — LPG beside petrol, most often. Null
  /// for the overwhelming majority, where naming a fuel on every fill-up would
  /// be a field with one possible answer.
  final String? secondaryFuelTypeKey;

  /// Whether the car runs on more than one fuel, which is what decides whether
  /// a fill-up is asked which one went in.
  bool get isBiFuel => secondaryFuelTypeKey != null;

  final bool archived;

  /// What the household paid for the car, if they said. Kept off
  /// [RunningCost] on purpose: a one-time capital cost folded into a
  /// per-kilometre running figure would answer a different question under
  /// the same name.
  final double? purchasePrice;

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
    double? tankCapacityL,
    String? secondaryFuelTypeKey,
    bool? archived,
    double? purchasePrice,
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
      tankCapacityL: tankCapacityL ?? this.tankCapacityL,
      secondaryFuelTypeKey: secondaryFuelTypeKey ?? this.secondaryFuelTypeKey,
      archived: archived ?? this.archived,
      purchasePrice: purchasePrice ?? this.purchasePrice,
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
        other.tankCapacityL == tankCapacityL &&
        other.secondaryFuelTypeKey == secondaryFuelTypeKey &&
        other.archived == archived &&
        other.purchasePrice == purchasePrice;
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
    tankCapacityL,
    secondaryFuelTypeKey,
    archived,
    purchasePrice,
  );

  @override
  String toString() {
    return 'Vehicle(id: $id, householdId: $householdId, nickname: $nickname, '
        'fuelTypeKey: $fuelTypeKey, baselineOdometerKm: $baselineOdometerKm, '
        'baselineDate: $baselineDate, make: $make, model: $model, year: $year, '
        'trim: $trim, vin: $vin, plate: $plate, photoUrl: $photoUrl, '
        'tankCapacityL: $tankCapacityL, '
        'secondaryFuelTypeKey: $secondaryFuelTypeKey, archived: $archived, '
        'purchasePrice: $purchasePrice)';
  }
}
