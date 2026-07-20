/// One shop visit or DIY job. A visit that covered several service types —
/// a completed bundle — carries several keys in [serviceTypeKeys].
class ServiceEntry {
  const ServiceEntry({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.odometerKm,
    required this.serviceTypeKeys,
    required this.createdBy,
    this.cost,
    this.shop,
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

  /// Language-neutral service type keys, e.g. `service_oil_change`.
  final List<String> serviceTypeKeys;

  final double? cost;
  final String? shop;
  final String? notes;
  final String createdBy;

  @override
  bool operator ==(Object other) {
    return other is ServiceEntry &&
        other.id == id &&
        other.vehicleId == vehicleId &&
        other.date == date &&
        other.odometerKm == odometerKm &&
        _sameKeys(other.serviceTypeKeys, serviceTypeKeys) &&
        other.cost == cost &&
        other.shop == shop &&
        other.notes == notes &&
        other.createdBy == createdBy;
  }

  @override
  int get hashCode => Object.hash(
        id,
        vehicleId,
        date,
        odometerKm,
        Object.hashAll(serviceTypeKeys),
        cost,
        shop,
        notes,
        createdBy,
      );

  @override
  String toString() {
    return 'ServiceEntry(id: $id, vehicleId: $vehicleId, date: $date, '
        'odometerKm: $odometerKm, serviceTypeKeys: $serviceTypeKeys, '
        'cost: $cost, shop: $shop, notes: $notes, createdBy: $createdBy)';
  }
}

/// Element-wise, order-sensitive comparison. `List.==` is identity, so two
/// entries carrying the same keys in separate list objects would otherwise
/// compare unequal.
bool _sameKeys(List<String> a, List<String> b) {
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
