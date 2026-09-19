import '../entities/vehicle_document.dart';
import '../maintenance/reminder_projection.dart';

/// What kind of deadline a fleet row is. The kind is what the fold reasons
/// about: one date per statutory kind per car, and the inspection kinds
/// bound which services are listed. The label comes from the service type
/// key and the grouping from the month.
enum DeadlineKind {
  registration,
  inspection,
  periodicInspection,
  tachograph,
  tyreSwap,
  service,
}

/// One thing one car needs by one day.
class FleetDeadline {
  const FleetDeadline({
    required this.vehicleId,
    required this.kind,
    required this.serviceTypeKey,
    required this.dueOn,
    required this.overdue,
  });

  final String vehicleId;
  final DeadlineKind kind;

  /// The key the label comes from: the rule's service type, or the one a
  /// paper stands in for (a registration document is `service_registration`).
  final String serviceTypeKey;

  /// UTC date-only.
  final DateTime dueOn;
  final bool overdue;
}

/// Every car's deadlines as one list: what the projection puts on the
/// calendar, and the papers' expiry dates.
///
/// The admin's month is about what must happen, so the statutory items —
/// registration, inspections, the tachograph, the tyre window — always
/// appear, and an ordinary service only when it falls before the car's
/// next inspection; the rest is the car page's business until then. A
/// registration written both as a paper and as a rule is one date, the
/// earlier of the two, because that is the one that binds.
abstract final class FleetDeadlines {
  static const _statutory = {
    'service_registration': DeadlineKind.registration,
    'service_technical_inspection': DeadlineKind.inspection,
    'service_periodic_inspection': DeadlineKind.periodicInspection,
    'service_tachograph_calibration': DeadlineKind.tachograph,
    'service_tire_swap_seasonal': DeadlineKind.tyreSwap,
  };

  static List<FleetDeadline> of({
    required Iterable<ReminderProjection> projections,
    required Map<String, List<VehicleDocument>> documentsByVehicle,
    required DateTime today,
  }) {
    final day = _day(today);
    final byVehicle = <String, List<FleetDeadline>>{};
    void add(String vehicleId, DeadlineKind kind, String key, DateTime on) {
      final due = _day(on);
      byVehicle
          .putIfAbsent(vehicleId, () => [])
          .add(
            FleetDeadline(
              vehicleId: vehicleId,
              kind: kind,
              serviceTypeKey: key,
              dueOn: due,
              overdue: due.isBefore(day),
            ),
          );
    }

    for (final projection in projections) {
      add(
        projection.vehicleId,
        _statutory[projection.serviceTypeKey] ?? DeadlineKind.service,
        projection.serviceTypeKey,
        projection.projectedDueDate,
      );
    }
    for (final MapEntry(key: vehicleId, value: documents)
        in documentsByVehicle.entries) {
      for (final document in documents) {
        final expires = document.expiresOn;
        // A paper is read through the one seam that makes it a reminder.
        // Only a statutory one is a fleet row in its own right: an insurance
        // paper's expiry still arrives, as the one-off rule the document
        // sheet syncs at that date, filed among the ordinary services.
        final key = document.type.serviceTypeKey;
        if (expires == null || key == null) {
          continue;
        }
        if (_statutory[key] case final kind?) {
          add(vehicleId, kind, key, expires);
        }
      }
    }

    final result = <FleetDeadline>[];
    for (final deadlines in byVehicle.values) {
      final statutory = <DeadlineKind, FleetDeadline>{};
      final services = <FleetDeadline>[];
      for (final deadline in deadlines) {
        if (deadline.kind == DeadlineKind.service) {
          services.add(deadline);
          continue;
        }
        final held = statutory[deadline.kind];
        if (held == null || deadline.dueOn.isBefore(held.dueOn)) {
          statutory[deadline.kind] = deadline;
        }
      }
      DateTime? inspection;
      for (final kind in [
        DeadlineKind.inspection,
        DeadlineKind.periodicInspection,
      ]) {
        final due = statutory[kind]?.dueOn;
        if (due != null && (inspection == null || due.isBefore(inspection))) {
          inspection = due;
        }
      }
      result
        ..addAll(statutory.values)
        ..addAll(
          services.where(
            (deadline) =>
                inspection == null || !deadline.dueOn.isAfter(inspection),
          ),
        );
    }
    return result..sort((a, b) {
      final byDate = a.dueOn.compareTo(b.dueOn);
      return byDate != 0 ? byDate : a.vehicleId.compareTo(b.vehicleId);
    });
  }

  /// The month's view: what falls due this month, and anything already
  /// late, which is the most actionable thing on the screen.
  static List<FleetDeadline> thisMonth(
    Iterable<FleetDeadline> deadlines,
    DateTime today,
  ) {
    return [
      for (final deadline in deadlines)
        if (deadline.overdue ||
            (deadline.dueOn.year == today.year &&
                deadline.dueOn.month == today.month))
          deadline,
    ];
  }

  /// The calendar day written on [date], whichever clock wrote it: the
  /// projector dates by the local one and the papers by UTC, and shifting
  /// either through a time zone would move a midnight into the day before.
  static DateTime _day(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
}
