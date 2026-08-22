/// A maintenance reminder for one vehicle and one service type.
///
/// Recurring rules carry intervals; whichever dimension falls first wins.
/// One-time rules ([oneTime]) instead carry a fixed [dueDate] and/or
/// [dueOdometerKm] and deactivate once a matching service is logged.
class ReminderRule {
  const ReminderRule({
    required this.id,
    required this.vehicleId,
    required this.serviceTypeKey,
    this.intervalKm,
    this.intervalMonths,
    this.oneTime = false,
    this.dueDate,
    this.dueOdometerKm,
    this.active = true,
    this.issuedDate,
  });

  final String id;
  final String vehicleId;
  final String serviceTypeKey;
  final int? intervalKm;
  final int? intervalMonths;
  final bool oneTime;

  /// UTC date-only, like every domain [DateTime].
  final DateTime? dueDate;
  final int? dueOdometerKm;
  final bool active;

  /// The date this **one-time** rule's own cycle started — the day the
  /// vignette or the premium it came from was actually paid, not the day the
  /// row was written. [ReminderProjector] anchors a one-time rule's progress
  /// here: a vignette or a yearly premium has no "last service" to measure
  /// from, and falling back to the vehicle's own baseline date read a car
  /// added a year ago, and one bought yesterday, as ~100% used up the moment
  /// it was logged.
  ///
  /// Distinct from a database `created_at` on purpose: a premium entered
  /// today for a payment made two months ago is two months into its cycle,
  /// not zero — the day it was typed in has nothing to do with when the
  /// cover actually began.
  final DateTime? issuedDate;

  bool get isProjectable =>
      active &&
      (oneTime
          ? dueDate != null || dueOdometerKm != null
          : intervalKm != null || intervalMonths != null);

  ReminderRule copyWith({
    String? vehicleId,
    int? intervalKm,
    int? intervalMonths,
    bool? oneTime,
    DateTime? dueDate,
    int? dueOdometerKm,
    bool? active,
    DateTime? issuedDate,
  }) {
    return ReminderRule(
      id: id,
      vehicleId: vehicleId ?? this.vehicleId,
      serviceTypeKey: serviceTypeKey,
      intervalKm: intervalKm ?? this.intervalKm,
      intervalMonths: intervalMonths ?? this.intervalMonths,
      oneTime: oneTime ?? this.oneTime,
      dueDate: dueDate ?? this.dueDate,
      dueOdometerKm: dueOdometerKm ?? this.dueOdometerKm,
      active: active ?? this.active,
      issuedDate: issuedDate ?? this.issuedDate,
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
        other.oneTime == oneTime &&
        other.dueDate == dueDate &&
        other.dueOdometerKm == dueOdometerKm &&
        other.active == active &&
        other.issuedDate == issuedDate;
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    serviceTypeKey,
    intervalKm,
    intervalMonths,
    oneTime,
    dueDate,
    dueOdometerKm,
    active,
    issuedDate,
  );

  @override
  String toString() {
    return 'ReminderRule(id: $id, vehicleId: $vehicleId, '
        'serviceTypeKey: $serviceTypeKey, intervalKm: $intervalKm, '
        'intervalMonths: $intervalMonths, oneTime: $oneTime, '
        'dueDate: $dueDate, dueOdometerKm: $dueOdometerKm, active: $active, '
        'issuedDate: $issuedDate)';
  }
}
