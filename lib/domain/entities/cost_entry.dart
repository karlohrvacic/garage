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
  static const toll = 'toll';
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
    wash,
    fine,
    equipment,
    other,
  ];
}
