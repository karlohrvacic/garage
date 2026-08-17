/// Money in, against a vehicle.
///
/// The kind of thing a cost log cannot express: a taxi fare, a share of a lift,
/// an insurance refund, and — the one nearly every owner eventually needs — what
/// the car sold for. Without it "what has this car cost me" can only ever be
/// half an answer.
class IncomeEntry {
  const IncomeEntry({
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

  /// Language-neutral category key. See [IncomeCategories].
  final String category;

  final double amount;
  final int? odometerKm;
  final String? notes;
  final String createdBy;

  IncomeEntry copyWith({
    String? id,
    String? vehicleId,
    DateTime? date,
    String? category,
    double? amount,
    int? odometerKm,
    String? notes,
    String? createdBy,
  }) {
    return IncomeEntry(
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
    return other is IncomeEntry &&
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
    return 'IncomeEntry(id: $id, vehicleId: $vehicleId, date: $date, '
        'category: $category, amount: $amount, notes: $notes)';
  }
}

/// The fixed income category keys. Order is the display order in pickers.
abstract final class IncomeCategories {
  /// A share of a journey somebody else paid for — the ordinary case for a
  /// household car, and the reason this is first.
  static const ride = 'ride';

  /// Work driven through Uber, Bolt and the like, where the platform pays out
  /// rather than the passenger.
  static const transportApp = 'transport_app';

  /// Goods moved for money.
  static const freight = 'freight';

  /// Money coming back: an insurance settlement, an overpaid registration, a
  /// warranty claim.
  static const refund = 'refund';

  /// What the car sold for. The one entry that closes the book on a vehicle,
  /// and the reason running cost can ever be a complete figure.
  static const vehicleSale = 'vehicle_sale';

  static const other = 'other';

  static const all = [ride, transportApp, freight, refund, vehicleSale, other];
}
