/// Where something a driver noticed has got to.
enum ObservationState {
  /// Nobody has been to a garage about it.
  open,

  /// A service addressed it and the symptom has not been declared gone.
  /// The most useful line on a handover sheet.
  stillThere,

  resolved,
}

/// Something noticed and not yet settled: a rattle at the front when the
/// engine is cold, a vibration since a pothole, a warning light that came on
/// once.
///
/// One shape covers what might have been three. A driving event, a symptom and
/// a note for the mechanic are the same thing described differently — something
/// a person noticed, at a date, at a mileage — and the only real difference is
/// whether it is still open. An event is simply one that points at the journey
/// it happened on.
class Observation {
  const Observation({
    required this.id,
    required this.vehicleId,
    required this.noticedOn,
    required this.note,
    required this.createdBy,
    required this.createdAt,
    this.tripId,
    this.odometerKm,
    this.addressedBy,
    this.resolvedOn,
  });

  final String id;
  final String vehicleId;

  /// The journey it happened on, when it happened on one. UTC, like every
  /// [DateTime] in the domain layer.
  final String? tripId;

  final DateTime noticedOn;
  final int? odometerKm;
  final String note;

  /// The service entry that did work about this.
  ///
  /// Deliberately not the same thing as [resolvedOn]: a garage can replace a
  /// part and leave the noise exactly where it was.
  final String? addressedBy;

  /// When the symptom actually stopped.
  final DateTime? resolvedOn;

  final String createdBy;
  final DateTime createdAt;

  bool get isOpen => resolvedOn == null;
  bool get addressed => addressedBy != null;
  bool get happenedOnATrip => tripId != null;

  ObservationState get state {
    if (resolvedOn != null) {
      return ObservationState.resolved;
    }
    return addressed ? ObservationState.stillThere : ObservationState.open;
  }

  /// How long it has been going on: to now while open, to the day it stopped
  /// once resolved.
  ///
  /// Never negative. A date typed wrong should read as "just noticed" rather
  /// than as a negative span nothing can render.
  Duration openForAt(DateTime now) {
    final until = resolvedOn ?? now;
    final span = until.difference(noticedOn);
    return span.isNegative ? Duration.zero : span;
  }

  Observation copyWith({
    /// Set only by a restore, which writes the file's rows against the
    /// vehicle they are being restored into rather than the one they left.
    String? vehicleId,
    String? note,
    DateTime? noticedOn,
    int? odometerKm,
    String? addressedBy,
    DateTime? resolvedOn,
    String? tripId,
    bool clearResolved = false,
    bool clearAddressed = false,
  }) {
    return Observation(
      id: id,
      vehicleId: vehicleId ?? this.vehicleId,
      noticedOn: noticedOn ?? this.noticedOn,
      note: note ?? this.note,
      createdBy: createdBy,
      createdAt: createdAt,
      tripId: tripId ?? this.tripId,
      odometerKm: odometerKm ?? this.odometerKm,
      addressedBy: clearAddressed ? null : (addressedBy ?? this.addressedBy),
      resolvedOn: clearResolved ? null : (resolvedOn ?? this.resolvedOn),
    );
  }
}

abstract final class Observations {
  /// Ordered for a screen: what is still going on, oldest complaint first,
  /// then what has been settled, most recently settled first.
  ///
  /// Oldest-first among the open ones on purpose — the rattle somebody has
  /// lived with for two months is the one to mention at the counter, not the
  /// one noticed yesterday.
  static List<Observation> forDisplay(List<Observation> observations) {
    final open = [...observations.where((it) => it.isOpen)]
      ..sort((a, b) => a.noticedOn.compareTo(b.noticedOn));
    final resolved = [...observations.where((it) => !it.isOpen)]
      ..sort((a, b) => b.resolvedOn!.compareTo(a.resolvedOn!));
    return [...open, ...resolved];
  }

  static List<Observation> open(List<Observation> observations) =>
      forDisplay(observations).where((it) => it.isOpen).toList(growable: false);

  /// Open, and somebody has already tried. What a handover sheet leads with,
  /// because "we did this and it did not help" is the most useful thing a
  /// mechanic can be told.
  static List<Observation> stillThereAfterWork(
    List<Observation> observations,
  ) => forDisplay(observations)
      .where((it) => it.state == ObservationState.stillThere)
      .toList(growable: false);
}
