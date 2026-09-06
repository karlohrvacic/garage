import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/vehicle_document.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/domain/trips/trip_preparation.dart';

final _today = DateTime.utc(2026, 9, 6);

ReminderProjection due({
  String ruleId = 'r1',
  String key = 'service_oil',
  int? dueOdometerKm,
  DateTime? dueDate,
}) {
  return ReminderProjection(
    ruleId: ruleId,
    vehicleId: 'v1',
    serviceTypeKey: key,
    projectedDueDate: dueDate ?? DateTime.utc(2026, 12, 1),
    dueOdometerKm: dueOdometerKm,
    state: ReminderState.upcoming,
  );
}

VehicleDocument paper({
  String id = 'd1',
  DocumentType type = DocumentType.registration,
  DateTime? expiresOn,
}) {
  return VehicleDocument(
    id: id,
    vehicleId: 'v1',
    type: type,
    expiresOn: expiresOn,
    createdBy: 'u1',
  );
}

void main() {
  group('what a journey runs into', () {
    test('a service due inside the distance is flagged', () {
      // "Due in about 900 km, and this trip is 1,500."
      final plan = prepareForTrip(
        today: _today,
        departOn: DateTime.utc(2026, 9, 10),
        distanceKm: 1500,
        currentOdometerKm: 142300,
        projections: [due(dueOdometerKm: 143200)],
        documents: const [],
      );

      expect(plan.forecast.single.projection.dueOdometerKm, 143200);
      expect(plan.forecast.single.kmAway, 900);
      expect(plan.anything, isTrue);
    });

    test('one comfortably beyond it is not', () {
      final plan = prepareForTrip(
        today: _today,
        departOn: DateTime.utc(2026, 9, 10),
        distanceKm: 500,
        currentOdometerKm: 142300,
        projections: [due(dueOdometerKm: 148000)],
        documents: const [],
      );

      expect(plan.forecast, isEmpty);
      expect(plan.anything, isFalse);
    });

    test('one already overdue is flagged whatever the distance', () {
      final plan = prepareForTrip(
        today: _today,
        departOn: DateTime.utc(2026, 9, 10),
        distanceKm: 10,
        currentOdometerKm: 142300,
        projections: [due(dueOdometerKm: 141000)],
        documents: const [],
      );

      expect(plan.forecast.single.kmAway, lessThanOrEqualTo(0));
    });

    test(
      'a paper that expires before you are back is a deadline, not a guess',
      () {
        // Kept apart from the forecasts on purpose: a registration expiring on
        // the 3rd is a fact, and "you will reach 143,200 km" is a projection
        // from how the car has lately been driven.
        final plan = prepareForTrip(
          today: _today,
          departOn: DateTime.utc(2026, 9, 10),
          returnOn: DateTime.utc(2026, 9, 20),
          distanceKm: 1500,
          currentOdometerKm: 142300,
          projections: const [],
          documents: [paper(expiresOn: DateTime.utc(2026, 9, 15))],
        );

        expect(plan.deadlines.single.document.type, DocumentType.registration);
        expect(plan.forecast, isEmpty);
      },
    );

    test('one expiring after the return is left alone', () {
      final plan = prepareForTrip(
        today: _today,
        departOn: DateTime.utc(2026, 9, 10),
        returnOn: DateTime.utc(2026, 9, 20),
        distanceKm: 100,
        currentOdometerKm: 142300,
        projections: const [],
        documents: [paper(expiresOn: DateTime.utc(2026, 11, 1))],
      );

      expect(plan.deadlines, isEmpty);
    });

    test('a document with no expiry recorded says nothing either way', () {
      final plan = prepareForTrip(
        today: _today,
        departOn: DateTime.utc(2026, 9, 10),
        distanceKm: 100,
        currentOdometerKm: 142300,
        projections: const [],
        documents: [paper(expiresOn: null)],
      );

      expect(plan.deadlines, isEmpty);
    });

    test('with no return date, the departure day is what is checked', () {
      final plan = prepareForTrip(
        today: _today,
        departOn: DateTime.utc(2026, 9, 10),
        distanceKm: 100,
        currentOdometerKm: 142300,
        projections: const [],
        documents: [paper(expiresOn: DateTime.utc(2026, 9, 9))],
      );

      expect(plan.deadlines, hasLength(1));
    });

    test('an unknown odometer forecasts nothing rather than guessing', () {
      // Without a current reading there is no distance to measure against,
      // and inventing one would put a confident number on a screen that has
      // no basis for it.
      final plan = prepareForTrip(
        today: _today,
        departOn: DateTime.utc(2026, 9, 10),
        distanceKm: 1500,
        currentOdometerKm: null,
        projections: [due(dueOdometerKm: 143200)],
        documents: const [],
      );

      expect(plan.forecast, isEmpty);
      expect(plan.odometerUnknown, isTrue);
    });

    test(
      'a rule with no distance interval cannot be measured in kilometres',
      () {
        final plan = prepareForTrip(
          today: _today,
          departOn: DateTime.utc(2026, 9, 10),
          distanceKm: 1500,
          currentOdometerKm: 142300,
          projections: [due(dueOdometerKm: null)],
          documents: const [],
        );

        expect(plan.forecast, isEmpty);
      },
    );

    test('the closest thing comes first', () {
      final plan = prepareForTrip(
        today: _today,
        departOn: DateTime.utc(2026, 9, 10),
        distanceKm: 2000,
        currentOdometerKm: 142300,
        projections: [
          due(ruleId: 'far', dueOdometerKm: 144000),
          due(ruleId: 'near', dueOdometerKm: 142500),
        ],
        documents: const [],
      );

      expect(plan.forecast.map((it) => it.projection.ruleId), ['near', 'far']);
    });

    test('a trip that runs into nothing says so plainly', () {
      final plan = prepareForTrip(
        today: _today,
        departOn: DateTime.utc(2026, 9, 10),
        distanceKm: 50,
        currentOdometerKm: 142300,
        projections: const [],
        documents: const [],
      );

      expect(plan.anything, isFalse);
      expect(plan.deadlines, isEmpty);
      expect(plan.forecast, isEmpty);
    });
  });
}
