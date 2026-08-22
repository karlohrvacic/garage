import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';

ReminderProjection? project(
  ReminderRule rule, {
  DateTime? lastServiceDate,
  int? lastServiceOdometerKm,
  int currentOdometerKm = 50000,
}) {
  return ReminderProjector.project(
    rule: rule,
    lastServiceDate: lastServiceDate ?? DateTime.utc(2026, 1, 1),
    lastServiceOdometerKm: lastServiceOdometerKm ?? 45000,
    currentOdometerKm: currentOdometerKm,
    kmPerDay: 50,
    today: DateTime.utc(2026, 8, 22),
  );
}

void main() {
  // A date extrapolated from km/day and a date fixed by the calendar are
  // different kinds of claim, and the row used to state both as "Due 12 Jun".
  // One of them is a guess that moves every time the car is driven.
  group('whether a due date is a prediction', () {
    test('a distance interval that binds is a prediction', () {
      final projection = project(
        const ReminderRule(
          id: 'r1',
          vehicleId: 'v1',
          serviceTypeKey: 'service_oil_change',
          intervalKm: 10000,
        ),
      )!;

      expect(projection.isPredicted, isTrue);
    });

    test('a month interval is a deadline, not a prediction', () {
      final projection = project(
        const ReminderRule(
          id: 'r1',
          vehicleId: 'v1',
          serviceTypeKey: 'service_oil_change',
          intervalMonths: 12,
        ),
      )!;

      expect(projection.isPredicted, isFalse);
    });

    test('when both are set, whichever binds decides', () {
      // 5,000 km left at 50 km/day is 100 days out; the calendar deadline is
      // 1 January, which is further. So the distance binds and the date shown
      // is the extrapolated one.
      final byDistance = project(
        const ReminderRule(
          id: 'r1',
          vehicleId: 'v1',
          serviceTypeKey: 'service_oil_change',
          intervalKm: 10000,
          intervalMonths: 12,
        ),
      )!;
      expect(byDistance.isPredicted, isTrue);

      // Barely driven, so the odometer target is years away and the calendar
      // deadline arrives first.
      final byCalendar = project(
        const ReminderRule(
          id: 'r1',
          vehicleId: 'v1',
          serviceTypeKey: 'service_oil_change',
          intervalKm: 10000,
          intervalMonths: 12,
        ),
        currentOdometerKm: 45100,
      )!;
      expect(byCalendar.isPredicted, isFalse);
    });

    test('a one-off with a fixed date is never a prediction', () {
      final projection = project(
        ReminderRule(
          id: 'r1',
          vehicleId: 'v1',
          serviceTypeKey: 'service_vignette',
          oneTime: true,
          dueDate: DateTime.utc(2026, 12, 1),
        ),
      )!;

      expect(projection.isPredicted, isFalse);
    });

    test('a one-off due at an odometer reading is a prediction', () {
      final projection = project(
        const ReminderRule(
          id: 'r1',
          vehicleId: 'v1',
          serviceTypeKey: 'service_timing_belt',
          oneTime: true,
          dueOdometerKm: 60000,
        ),
      )!;

      expect(projection.isPredicted, isTrue);
    });

    test('two deadlines on the same day read as the deadline', () {
      // Nothing is gained by hedging a date the calendar also guarantees.
      const rule = ReminderRule(
        id: 'r1',
        vehicleId: 'v1',
        serviceTypeKey: 'service_oil_change',
        intervalKm: 10000,
        intervalMonths: 12,
      );
      final projection = ReminderProjector.project(
        rule: rule,
        lastServiceDate: DateTime.utc(2026, 1, 1),
        lastServiceOdometerKm: 45000,
        currentOdometerKm: 50000,
        kmPerDay: 50,
        today: DateTime.utc(2026, 8, 22),
      )!;
      final sameDay = ReminderProjection(
        ruleId: projection.ruleId,
        vehicleId: projection.vehicleId,
        serviceTypeKey: projection.serviceTypeKey,
        projectedDueDate: projection.projectedDueDate,
        state: projection.state,
        dateFromDistance: projection.projectedDueDate,
        dateFromTime: projection.projectedDueDate,
      );

      expect(sameDay.isPredicted, isFalse);
    });
  });
}
