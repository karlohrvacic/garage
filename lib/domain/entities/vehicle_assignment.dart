/// Who had a car, from when until when.
///
/// A log rather than a field on the vehicle: "who had the car on 3 May" is
/// what a fine, a scratch or a speeding ticket asks, and a field only ever
/// knows who has it now. One driver per car at a time — the database's
/// exclusion constraint (migration 0080) — and any number of cars per driver.
class VehicleAssignment {
  const VehicleAssignment({
    required this.id,
    required this.vehicleId,
    required this.userId,
    required this.fromDate,
    this.toDate,
    this.handoverOdometerKm,
    this.returnOdometerKm,
    this.note,
    this.confirmedAt,
    this.confirmedBy,
    this.createdBy = '',
    this.createdAt,
  });

  final String id;
  final String vehicleId;

  /// Null once the account behind it is deleted. The window stays in the
  /// log, like an entry keeps its place when its author goes, and resolves
  /// to nobody.
  final String? userId;

  /// UTC date-only, both ends inclusive. [toDate] null means open.
  final DateTime fromDate;
  final DateTime? toDate;

  /// The reading when the driver took the car, and when they gave it back.
  /// Both are also odometer entries, written by the same call.
  final int? handoverOdometerKm;
  final int? returnOdometerKm;

  final String? note;

  /// The driver's sign-off from the phone, the sign the paper putni blok
  /// had. Null until they confirm; the assignment holds either way.
  final DateTime? confirmedAt;
  final String? confirmedBy;

  final String createdBy;
  final DateTime? createdAt;

  bool get isOpen => toDate == null;

  bool get isConfirmed => confirmedAt != null;

  /// Whether [day] falls inside the window. Judged by calendar day, so a
  /// local evening is still its own date — and so are the window's own
  /// ends, which a row reads as UTC days but a date picker hands over as a
  /// local instant.
  bool covers(DateTime day) {
    final date = _calendarDay(day);
    if (date.isBefore(_calendarDay(fromDate))) {
      return false;
    }
    final end = toDate;
    return end == null || !date.isAfter(_calendarDay(end));
  }

  static DateTime _calendarDay(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  /// [clearToDate] reopens a window: a nullable parameter alone could never
  /// tell "leave it" from "clear it".
  VehicleAssignment copyWith({
    DateTime? toDate,
    int? returnOdometerKm,
    String? note,
    DateTime? confirmedAt,
    String? confirmedBy,
    bool clearToDate = false,
  }) {
    return VehicleAssignment(
      id: id,
      vehicleId: vehicleId,
      userId: userId,
      fromDate: fromDate,
      toDate: clearToDate ? null : (toDate ?? this.toDate),
      handoverOdometerKm: handoverOdometerKm,
      returnOdometerKm: returnOdometerKm ?? this.returnOdometerKm,
      note: note ?? this.note,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is VehicleAssignment &&
        other.id == id &&
        other.vehicleId == vehicleId &&
        other.userId == userId &&
        other.fromDate == fromDate &&
        other.toDate == toDate &&
        other.handoverOdometerKm == handoverOdometerKm &&
        other.returnOdometerKm == returnOdometerKm &&
        other.note == note &&
        other.confirmedAt == confirmedAt &&
        other.confirmedBy == confirmedBy &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    userId,
    fromDate,
    toDate,
    handoverOdometerKm,
    returnOdometerKm,
    note,
    confirmedAt,
    confirmedBy,
    createdBy,
    createdAt,
  );

  @override
  String toString() {
    return 'VehicleAssignment(id: $id, vehicleId: $vehicleId, '
        'userId: $userId, fromDate: $fromDate, toDate: $toDate, '
        'handoverOdometerKm: $handoverOdometerKm, '
        'returnOdometerKm: $returnOdometerKm, confirmedAt: $confirmedAt)';
  }
}
