/// A single fill-up. Volumes are litres and odometer readings kilometres —
/// the canonical units used everywhere below the presentation layer.
class FuelEntry {
  const FuelEntry({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.odometerKm,
    required this.volumeL,
    required this.fullTank,
    required this.missedFill,
    required this.createdBy,
    this.pricePerL,
    this.total,
    this.station,
    this.notes,
  });

  final String id;
  final String vehicleId;

  /// UTC. Every [DateTime] in the domain layer is UTC — the repository layer
  /// converts to UTC on the way in and to local time on the way out. Mixing
  /// the two silently breaks equality: `DateTime.==` compares the `isUtc`
  /// flag as well as the instant.
  final DateTime date;

  final int odometerKm;
  final double volumeL;
  final double? pricePerL;
  final double? total;

  /// Whether the tank was filled to full. Economy is only computable between
  /// consecutive full tanks.
  final bool fullTank;

  /// Set when the driver knows a previous fill went unlogged. Breaks the
  /// economy chain so no figure is reported across the gap.
  final bool missedFill;

  final String? station;
  final String? notes;
  final String createdBy;

  /// Given exactly two of {volume, price per litre, total}, returns the third.
  /// Returns null when fewer than two — or all three — are known, or when the
  /// arithmetic would divide by zero.
  static double? deriveThird({
    required double? volumeL,
    required double? pricePerL,
    required double? total,
  }) {
    final known = [volumeL, pricePerL, total].where((v) => v != null).length;
    if (known != 2) {
      return null;
    }
    if (total == null) {
      return volumeL! * pricePerL!;
    }
    if (pricePerL == null) {
      return volumeL! == 0 ? null : total / volumeL;
    }
    return pricePerL == 0 ? null : total / pricePerL;
  }

  FuelEntry copyWith({
    String? id,
    String? vehicleId,
    DateTime? date,
    int? odometerKm,
    double? volumeL,
    double? pricePerL,
    double? total,
    bool? fullTank,
    bool? missedFill,
    String? station,
    String? notes,
    String? createdBy,
  }) {
    return FuelEntry(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      odometerKm: odometerKm ?? this.odometerKm,
      volumeL: volumeL ?? this.volumeL,
      pricePerL: pricePerL ?? this.pricePerL,
      total: total ?? this.total,
      fullTank: fullTank ?? this.fullTank,
      missedFill: missedFill ?? this.missedFill,
      station: station ?? this.station,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FuelEntry &&
        other.id == id &&
        other.vehicleId == vehicleId &&
        other.date == date &&
        other.odometerKm == odometerKm &&
        other.volumeL == volumeL &&
        other.pricePerL == pricePerL &&
        other.total == total &&
        other.fullTank == fullTank &&
        other.missedFill == missedFill &&
        other.station == station &&
        other.notes == notes &&
        other.createdBy == createdBy;
  }

  @override
  int get hashCode => Object.hash(
        id,
        vehicleId,
        date,
        odometerKm,
        volumeL,
        pricePerL,
        total,
        fullTank,
        missedFill,
        station,
        notes,
        createdBy,
      );

  @override
  String toString() {
    return 'FuelEntry(id: $id, vehicleId: $vehicleId, date: $date, '
        'odometerKm: $odometerKm, volumeL: $volumeL, pricePerL: $pricePerL, '
        'total: $total, fullTank: $fullTank, missedFill: $missedFill, '
        'station: $station, notes: $notes, createdBy: $createdBy)';
  }
}
