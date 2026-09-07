/// What one car takes for one job: a viscosity, a part number, a size.
///
/// The DIY half of the app's answer to "what does this car need". A reminder
/// says *when* the oil is due; this says what to buy when it is. Keyed by the
/// same `serviceTypeKey` the reminders and service entries use, so the two
/// meet on the service sheet without a second vocabulary to keep in step.
///
/// [spec] is free text and deliberately so: "5W-30 ACEA C3", "W 712/95",
/// "H7 55W" and "600 mm / 400 mm" are four different shapes, and the owner is
/// copying whichever one their car's book gives them, not filling in a form
/// somebody else designed.
class VehiclePart {
  const VehiclePart({
    required this.id,
    required this.vehicleId,
    required this.serviceTypeKey,
    required this.spec,
    required this.createdBy,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String vehicleId;
  final String serviceTypeKey;
  final String spec;
  final String? notes;
  final String createdBy;
  final DateTime? createdAt;

  VehiclePart copyWith({String? serviceTypeKey, String? spec, String? notes}) {
    return VehiclePart(
      id: id,
      vehicleId: vehicleId,
      serviceTypeKey: serviceTypeKey ?? this.serviceTypeKey,
      spec: spec ?? this.spec,
      createdBy: createdBy,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VehiclePart &&
      other.id == id &&
      other.vehicleId == vehicleId &&
      other.serviceTypeKey == serviceTypeKey &&
      other.spec == spec &&
      other.notes == notes &&
      other.createdBy == createdBy &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    serviceTypeKey,
    spec,
    notes,
    createdBy,
    createdAt,
  );
}

abstract final class VehicleParts {
  /// The spec recorded for one job, or null when the car has none.
  ///
  /// Exact on the key rather than fuzzy: a household that typed a spec under
  /// its own service type should see it under that type and nowhere else.
  static VehiclePart? forJob(List<VehiclePart> parts, String serviceTypeKey) {
    for (final part in parts) {
      if (part.serviceTypeKey == serviceTypeKey) {
        return part;
      }
    }
    return null;
  }

  /// Every spec that applies to a visit covering [serviceTypeKeys], in the
  /// order the job keys were given.
  ///
  /// A bundled visit — oil, oil filter and cabin filter in one afternoon —
  /// needs all three numbers, and the sheet asks for them together.
  static List<VehiclePart> forJobs(
    List<VehiclePart> parts,
    List<String> serviceTypeKeys,
  ) {
    return [for (final key in serviceTypeKeys) ?forJob(parts, key)];
  }
}
