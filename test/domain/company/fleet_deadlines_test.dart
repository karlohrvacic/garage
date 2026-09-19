import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/company/fleet_deadlines.dart';
import 'package:garage/domain/entities/vehicle_document.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';

final today = DateTime.utc(2026, 9, 19);

ReminderProjection due(
  String vehicleId,
  String key,
  DateTime on, {
  ReminderState state = ReminderState.upcoming,
  String? ruleId,
}) {
  return ReminderProjection(
    ruleId: ruleId ?? '$vehicleId-$key',
    vehicleId: vehicleId,
    serviceTypeKey: key,
    projectedDueDate: on,
    state: state,
  );
}

VehicleDocument paper(String vehicleId, DocumentType type, DateTime? expires) {
  return VehicleDocument(
    id: '$vehicleId-${type.key}',
    vehicleId: vehicleId,
    type: type,
    expiresOn: expires,
    createdBy: 'u1',
  );
}

void main() {
  test('statutory items keep their kind; everything else is a service', () {
    final deadlines = FleetDeadlines.of(
      projections: [
        due('v1', 'service_registration', DateTime.utc(2026, 10, 3)),
        due('v1', 'service_technical_inspection', DateTime.utc(2026, 11, 1)),
        due('v1', 'service_periodic_inspection', DateTime.utc(2026, 12, 1)),
        due('v2', 'service_tachograph_calibration', DateTime.utc(2027, 1, 1)),
        due('v2', 'service_tire_swap_seasonal', DateTime.utc(2026, 11, 15)),
        due('v2', 'service_oil_change', DateTime.utc(2026, 10, 20)),
      ],
      documentsByVehicle: const {},
      today: today,
    );

    expect(
      {for (final d in deadlines) d.serviceTypeKey: d.kind},
      {
        'service_registration': DeadlineKind.registration,
        'service_technical_inspection': DeadlineKind.inspection,
        'service_periodic_inspection': DeadlineKind.periodicInspection,
        'service_tachograph_calibration': DeadlineKind.tachograph,
        'service_tire_swap_seasonal': DeadlineKind.tyreSwap,
        'service_oil_change': DeadlineKind.service,
      },
    );
    expect(
      deadlines.map((d) => d.dueOn).toList(),
      [
        DateTime.utc(2026, 10, 3),
        DateTime.utc(2026, 10, 20),
        DateTime.utc(2026, 11, 1),
        DateTime.utc(2026, 11, 15),
        DateTime.utc(2026, 12, 1),
        DateTime.utc(2027, 1, 1),
      ],
      reason: 'soonest first across the fleet',
    );
  });

  test(
    'a service is listed only when it falls before the car\'s next inspection',
    () {
      // The admin's month is about what must happen; an oil change after the
      // inspection is the car page's business until then.
      final deadlines = FleetDeadlines.of(
        projections: [
          due('v1', 'service_technical_inspection', DateTime.utc(2026, 11, 1)),
          due('v1', 'service_oil_change', DateTime.utc(2026, 10, 20)),
          due('v1', 'service_brake_fluid', DateTime.utc(2027, 3, 1)),
          due('v2', 'service_oil_change', DateTime.utc(2027, 6, 1)),
        ],
        documentsByVehicle: const {},
        today: today,
      );

      expect(deadlines.map((d) => '${d.vehicleId}:${d.serviceTypeKey}'), [
        'v1:service_oil_change',
        'v1:service_technical_inspection',
        'v2:service_oil_change',
      ]);
    },
  );

  test('the periodic inspection bounds the services when it comes first', () {
    // A van's periodic inspection is an inspection too; a service that
    // falls between it and the roadworthiness test is after the next one.
    final deadlines = FleetDeadlines.of(
      projections: [
        due('v1', 'service_technical_inspection', DateTime.utc(2026, 12, 1)),
        due('v1', 'service_periodic_inspection', DateTime.utc(2026, 10, 15)),
        due('v1', 'service_oil_change', DateTime.utc(2026, 11, 1)),
        due('v1', 'service_brake_fluid', DateTime.utc(2026, 10, 1)),
      ],
      documentsByVehicle: const {},
      today: today,
    );

    expect(deadlines.map((d) => d.serviceTypeKey), [
      'service_brake_fluid',
      'service_periodic_inspection',
      'service_technical_inspection',
    ]);
  });

  test('a one-off and a recurring rule of one type are two rows', () {
    // A one-off oil change logged for a known date does not replace the
    // recurring rule; each is a thing the car needs by a day.
    final deadlines = FleetDeadlines.of(
      projections: [
        due('v1', 'service_oil_change', DateTime.utc(2027, 4, 20)),
        due(
          'v1',
          'service_oil_change',
          DateTime.utc(2026, 10, 20),
          ruleId: 'one-off',
        ),
      ],
      documentsByVehicle: const {},
      today: today,
    );

    expect(deadlines.map((d) => d.dueOn), [
      DateTime.utc(2026, 10, 20),
      DateTime.utc(2027, 4, 20),
    ]);
  });

  test('the papers count, and a rule and a paper for the same thing are one '
      'date', () {
    final deadlines = FleetDeadlines.of(
      projections: [
        due('v1', 'service_registration', DateTime.utc(2026, 10, 3)),
      ],
      documentsByVehicle: {
        'v1': [
          paper('v1', DocumentType.registration, DateTime.utc(2026, 10, 1)),
          paper('v1', DocumentType.roadworthiness, DateTime.utc(2026, 12, 12)),
          paper('v1', DocumentType.other, DateTime.utc(2026, 9, 30)),
          paper(
            'v1',
            DocumentType.insuranceLiability,
            DateTime.utc(2026, 9, 29),
          ),
          paper('v1', DocumentType.greenCard, DateTime.utc(2026, 9, 28)),
          paper('v1', DocumentType.registration, null),
        ],
      },
      today: today,
    );

    expect(
      deadlines.map((d) => '${d.kind.name}:${d.dueOn.day}'),
      ['registration:1', 'inspection:12'],
      reason:
          'the earlier of the two registrations binds; a paper whose '
          'reminder is not statutory, one with no reminder at all and an '
          'undated one are not deadlines',
    );
    expect(deadlines.first.serviceTypeKey, 'service_registration');
    expect(deadlines.last.serviceTypeKey, 'service_technical_inspection');
  });

  test('overdue is judged by the calendar day', () {
    final deadlines = FleetDeadlines.of(
      projections: [
        due('v1', 'service_registration', DateTime.utc(2026, 9, 18)),
        due('v2', 'service_registration', DateTime.utc(2026, 9, 19)),
      ],
      documentsByVehicle: const {},
      today: today,
    );

    expect(deadlines.map((d) => d.overdue), [true, false]);
  });

  test(
    'a projection dated by the local clock lands on its own calendar day',
    () {
      // The projector writes local midnights and the papers UTC ones; a fleet
      // row is the date written on it either way, never the instant shifted
      // through a time zone into the day before.
      final deadlines = FleetDeadlines.of(
        projections: [due('v1', 'service_registration', DateTime(2026, 9, 30))],
        documentsByVehicle: const {},
        today: DateTime(2026, 9, 30, 23, 30),
      );

      expect(deadlines.single.dueOn, DateTime.utc(2026, 9, 30));
      expect(deadlines.single.overdue, isFalse);
    },
  );

  test('this month is the month plus whatever is already late', () {
    final all = FleetDeadlines.of(
      projections: [
        due('v1', 'service_registration', DateTime.utc(2026, 8, 1)),
        due('v2', 'service_registration', DateTime.utc(2026, 9, 25)),
        due('v3', 'service_registration', DateTime.utc(2026, 10, 2)),
      ],
      documentsByVehicle: const {},
      today: today,
    );

    expect(FleetDeadlines.thisMonth(all, today).map((d) => d.vehicleId), [
      'v1',
      'v2',
    ]);
  });

  test('the last day of the month is still this month, and the first of the '
      'next is not', () {
    final all = FleetDeadlines.of(
      projections: [
        due('v1', 'service_registration', DateTime.utc(2026, 9, 30)),
        due('v2', 'service_registration', DateTime.utc(2026, 10, 1)),
      ],
      documentsByVehicle: const {},
      today: DateTime(2026, 9, 1, 0, 30),
    );

    expect(
      FleetDeadlines.thisMonth(
        all,
        DateTime(2026, 9, 1, 0, 30),
      ).map((d) => d.vehicleId),
      ['v1'],
    );
  });
}
