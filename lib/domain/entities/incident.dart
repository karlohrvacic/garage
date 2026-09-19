/// What happened to the car: the four things a fleet writes down.
enum IncidentKind {
  damage('damage'),
  fault('fault'),
  fine('fine'),
  accident('accident');

  const IncidentKind(this.key);

  final String key;

  /// A kind a newer server knows and this build does not reads as damage:
  /// the row is still shown, with the words the driver wrote.
  static IncidentKind fromKey(String key) {
    for (final kind in values) {
      if (kind.key == key) {
        return kind;
      }
    }
    return IncidentKind.damage;
  }
}

/// Where a report stands. Two of these are open: somebody is still waiting
/// on it. The other three are the ways it stops being anybody's problem.
enum IncidentStatus {
  open('open'),
  atInsurer('at_insurer'),
  repaired('repaired'),
  paid('paid'),
  closed('closed');

  const IncidentStatus(this.key);

  final String key;

  /// The three a report is settled as, in the order the card offers them.
  static const settled = [repaired, paid, closed];

  bool get isSettled => settled.contains(this);

  static IncidentStatus fromKey(String key) {
    for (final status in values) {
      if (status.key == key) {
        return status;
      }
    }
    return IncidentStatus.open;
  }
}

/// A dent reported in the corridor, written down. The driver is whoever the
/// log says had the car on [happenedOn], which is what makes a fine
/// attributable and a repeat offender visible.
class Incident {
  const Incident({
    required this.id,
    required this.vehicleId,
    required this.kind,
    required this.happenedOn,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    this.odometerKm,
    this.amount,
    this.status = IncidentStatus.open,
    this.resolvedOn,
  });

  final String id;
  final String vehicleId;
  final IncidentKind kind;

  /// UTC date-only.
  final DateTime happenedOn;
  final int? odometerKm;
  final String description;

  /// The fine, the excess, the repair.
  final double? amount;
  final IncidentStatus status;

  /// The day it was settled. Written together with a settled [status] and
  /// cleared together with `open`, never one without the other.
  final DateTime? resolvedOn;
  final String createdBy;
  final DateTime createdAt;

  /// The status decides; [resolvedOn] says since when.
  bool get isOpen => !status.isSettled;

  /// Something a mechanic can act on: damage, a fault or an accident that
  /// is still open. A fine is the accountant's.
  bool get needsWork => isOpen && kind != IncidentKind.fine;

  /// The amount and the reading take a wrapper so an edit can clear them,
  /// the way `Household.copyWith` clears a letterhead field: a fine that
  /// was waived has to reach the row as null.
  Incident copyWith({
    IncidentKind? kind,
    DateTime? happenedOn,
    Object? odometerKm = _unset,
    String? description,
    Object? amount = _unset,
    IncidentStatus? status,
    DateTime? resolvedOn,
    bool clearResolved = false,
  }) {
    return Incident(
      id: id,
      vehicleId: vehicleId,
      kind: kind ?? this.kind,
      happenedOn: happenedOn ?? this.happenedOn,
      description: description ?? this.description,
      createdBy: createdBy,
      createdAt: createdAt,
      odometerKm: identical(odometerKm, _unset)
          ? this.odometerKm
          : odometerKm as int?,
      amount: identical(amount, _unset) ? this.amount : amount as double?,
      status: status ?? this.status,
      resolvedOn: clearResolved ? null : (resolvedOn ?? this.resolvedOn),
    );
  }
}

/// A private sentinel so `copyWith` can tell "not passed" from "passed null".
const _unset = Object();

abstract final class Incidents {
  /// Open ones first, newest first — the one reported yesterday is the one
  /// the admin is asked about — then the settled ones by when they settled.
  /// A settled row with no day, which only a client other than this app
  /// can write, sorts by when it happened rather than throwing.
  static List<Incident> forDisplay(List<Incident> incidents) {
    final open = [...incidents.where((it) => it.isOpen)]
      ..sort((a, b) => b.happenedOn.compareTo(a.happenedOn));
    final settled = [...incidents.where((it) => !it.isOpen)]
      ..sort(
        (a, b) => (b.resolvedOn ?? b.happenedOn).compareTo(
          a.resolvedOn ?? a.happenedOn,
        ),
      );
    return [...open, ...settled];
  }

  /// What the handover sheet prints beside the observations: oldest first,
  /// because the thing the car has lived with longest is the thing to
  /// mention at the counter.
  static List<Incident> forMechanic(List<Incident> incidents) {
    return [...incidents.where((it) => it.needsWork)]
      ..sort((a, b) => a.happenedOn.compareTo(b.happenedOn));
  }
}
