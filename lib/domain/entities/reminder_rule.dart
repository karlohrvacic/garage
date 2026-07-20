/// A recurring maintenance interval for one vehicle and one service type.
///
/// When both intervals are set, whichever falls first wins. At least one must
/// be non-null for the rule to project a due point.
class ReminderRule {
  const ReminderRule({
    required this.id,
    required this.vehicleId,
    required this.serviceTypeKey,
    this.intervalKm,
    this.intervalMonths,
    this.active = true,
  });

  final String id;
  final String vehicleId;
  final String serviceTypeKey;
  final int? intervalKm;
  final int? intervalMonths;
  final bool active;

  bool get isProjectable =>
      active && (intervalKm != null || intervalMonths != null);

  ReminderRule copyWith({
    int? intervalKm,
    int? intervalMonths,
    bool? active,
  }) {
    return ReminderRule(
      id: id,
      vehicleId: vehicleId,
      serviceTypeKey: serviceTypeKey,
      intervalKm: intervalKm ?? this.intervalKm,
      intervalMonths: intervalMonths ?? this.intervalMonths,
      active: active ?? this.active,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReminderRule &&
        other.id == id &&
        other.vehicleId == vehicleId &&
        other.serviceTypeKey == serviceTypeKey &&
        other.intervalKm == intervalKm &&
        other.intervalMonths == intervalMonths &&
        other.active == active;
  }

  @override
  int get hashCode => Object.hash(
        id,
        vehicleId,
        serviceTypeKey,
        intervalKm,
        intervalMonths,
        active,
      );

  @override
  String toString() {
    return 'ReminderRule(id: $id, vehicleId: $vehicleId, '
        'serviceTypeKey: $serviceTypeKey, intervalKm: $intervalKm, '
        'intervalMonths: $intervalMonths, active: $active)';
  }
}
