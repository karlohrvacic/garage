/// A reading of the odometer with no money attached.
///
/// The point of it is that maintenance projection needs to know how far a car
/// has gone, and until now it could only learn that from something the owner
/// paid for. Somebody who services their car but pays cash at the pump had no
/// way to say "it is on 84,000 now" short of inventing a fill-up.
class OdometerEntry {
  const OdometerEntry({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.odometerKm,
    required this.createdBy,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String vehicleId;

  /// UTC. Every [DateTime] in the domain layer is UTC — the repository layer
  /// converts to UTC on the way in and to local time on the way out.
  final DateTime date;

  final int odometerKm;
  final String? notes;
  final String createdBy;

  /// When the entry was logged, not the day it happened — [date] is that.
  /// Used to break ties when two entries share a [date] on the timeline.
  final DateTime? createdAt;

  OdometerEntry copyWith({
    String? id,
    String? vehicleId,
    DateTime? date,
    int? odometerKm,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return OdometerEntry(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      odometerKm: odometerKm ?? this.odometerKm,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OdometerEntry &&
        other.id == id &&
        other.vehicleId == vehicleId &&
        other.date == date &&
        other.odometerKm == odometerKm &&
        other.notes == notes &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, vehicleId, date, odometerKm, notes, createdBy, createdAt);

  @override
  String toString() {
    return 'OdometerEntry(id: $id, vehicleId: $vehicleId, date: $date, '
        'odometerKm: $odometerKm, notes: $notes, createdBy: $createdBy)';
  }
}
