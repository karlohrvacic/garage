/// One non-fuel, non-service expense: registration, insurance, parking, and
/// the like. Category is a fixed language-neutral key localized client-side.
class CostEntry {
  const CostEntry({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.category,
    required this.amount,
    required this.createdBy,
    this.odometerKm,
    this.notes,
  });

  final String id;
  final String vehicleId;

  /// UTC. Every [DateTime] in the domain layer is UTC — the repository layer
  /// converts to UTC on the way in and to local time on the way out.
  final DateTime date;

  /// Language-neutral category key, e.g. `insurance`. See [CostCategories].
  final String category;

  final double amount;
  final int? odometerKm;
  final String? notes;
  final String createdBy;

  CostEntry copyWith({
    String? id,
    String? vehicleId,
    DateTime? date,
    String? category,
    double? amount,
    int? odometerKm,
    String? notes,
    String? createdBy,
  }) {
    return CostEntry(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      odometerKm: odometerKm ?? this.odometerKm,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CostEntry &&
        other.id == id &&
        other.vehicleId == vehicleId &&
        other.date == date &&
        other.category == category &&
        other.amount == amount &&
        other.odometerKm == odometerKm &&
        other.notes == notes &&
        other.createdBy == createdBy;
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    date,
    category,
    amount,
    odometerKm,
    notes,
    createdBy,
  );

  @override
  String toString() {
    return 'CostEntry(id: $id, vehicleId: $vehicleId, date: $date, '
        'category: $category, amount: $amount, odometerKm: $odometerKm, '
        'notes: $notes, createdBy: $createdBy)';
  }
}

/// The fixed category keys. Order is the display order in pickers and charts.
abstract final class CostCategories {
  static const registration = 'registration';
  static const insurance = 'insurance';

  /// Comprehensive cover, bought separately from the mandatory policy in
  /// Croatia and often from a different insurer on a different date. Folding
  /// the two into one line hides which of them a household is paying.
  static const insuranceComprehensive = 'insurance_comprehensive';
  static const parking = 'parking';

  /// A journey paid for at the barrier: Croatian motorways charge by the
  /// stretch driven, so this is spending that is over when the trip is.
  static const toll = 'toll';

  /// Road use bought in advance for a period, the way Slovenia, Austria and
  /// Switzerland sell it. Unlike a toll it has a date it stops being valid,
  /// which is the part worth being reminded about.
  static const vignette = 'vignette';
  static const wash = 'wash';
  static const fine = 'fine';
  static const equipment = 'equipment';
  static const other = 'other';

  static const all = [
    registration,
    insurance,
    insuranceComprehensive,
    parking,
    toll,
    vignette,
    wash,
    fine,
    equipment,
    other,
  ];
}
