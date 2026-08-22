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
    this.diy = false,
    this.partsCost,
    this.laborCost,
    this.partsDetail,
    this.warrantyUntil,
    this.measurements = const {},
    this.faultCodes,
    this.createdAt,
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

  // The fields below are only asked for at the deeper tracking levels; a
  // household that never turns those on simply leaves them empty.

  /// Done at home rather than at a shop.
  final bool diy;

  /// What the parts cost and what the labour did, where the household split
  /// them out. [cost] stays the figure every screen totals.
  final double? partsCost;
  final double? laborCost;

  /// What was actually fitted — "Castrol 5W-30, filter W712/95" — so the next
  /// visit does not start with a web search.
  final String? partsDetail;

  /// UTC date-only. When the work or the part is covered until.
  final DateTime? warrantyUntil;

  /// Readings taken during the visit, keyed by measurement id. Only meaningful
  /// as a series: one pad thickness says little, three say when to buy pads.
  final Map<String, double> measurements;

  /// Diagnostic trouble codes read at this visit, as the household typed them.
  /// Free text on purpose: the codes a scanner reports include
  /// manufacturer-specific ones no fixed list would accept.
  final String? faultCodes;

  /// When the entry was logged, not the day the work happened — [date] is
  /// that. Used to break ties when two entries share a [date] on the
  /// timeline.
  final DateTime? createdAt;

  /// Only the vehicle is ever changed on a stored entry — a restore writing
  /// into a car that was created a moment ago — so this takes that one field
  /// rather than every field it has.
  ServiceEntry copyWith({String? vehicleId}) {
    return ServiceEntry(
      id: id,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date,
      odometerKm: odometerKm,
      serviceTypeKeys: serviceTypeKeys,
      createdBy: createdBy,
      cost: cost,
      shop: shop,
      notes: notes,
      diy: diy,
      partsCost: partsCost,
      laborCost: laborCost,
      partsDetail: partsDetail,
      warrantyUntil: warrantyUntil,
      measurements: measurements,
      faultCodes: faultCodes,
      createdAt: createdAt,
    );
  }

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
        other.createdBy == createdBy &&
        other.diy == diy &&
        other.partsCost == partsCost &&
        other.laborCost == laborCost &&
        other.partsDetail == partsDetail &&
        other.warrantyUntil == warrantyUntil &&
        _sameReadings(other.measurements, measurements) &&
        other.faultCodes == faultCodes &&
        other.createdAt == createdAt;
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
    diy,
    partsCost,
    laborCost,
    partsDetail,
    warrantyUntil,
    Object.hashAllUnordered([
      for (final entry in measurements.entries) '${entry.key}:${entry.value}',
    ]),
    faultCodes,
    createdAt,
  );

  @override
  String toString() {
    return 'ServiceEntry(id: $id, vehicleId: $vehicleId, date: $date, '
        'odometerKm: $odometerKm, serviceTypeKeys: $serviceTypeKeys, '
        'cost: $cost, shop: $shop, notes: $notes, createdBy: $createdBy, '
        'diy: $diy, partsCost: $partsCost, laborCost: $laborCost, '
        'partsDetail: $partsDetail, warrantyUntil: $warrantyUntil, '
        'measurements: $measurements, faultCodes: $faultCodes)';
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

/// Maps compare by identity, so two entries carrying the same readings in
/// separate map objects would otherwise come out unequal.
bool _sameReadings(Map<String, double> a, Map<String, double> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
