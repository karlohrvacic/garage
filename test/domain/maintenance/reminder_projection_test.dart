import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';

final today = DateTime(2026, 7, 20);

ReminderRule rule({int? intervalKm, int? intervalMonths, bool active = true}) {
  return ReminderRule(
    id: 'r1',
    vehicleId: 'v1',
    serviceTypeKey: 'service_oil_change',
    intervalKm: intervalKm,
    intervalMonths: intervalMonths,
    active: active,
  );
}

void main() {
  group('kmPerDay', () {
    test('is the average daily distance across the readings', () {
      final result = ReminderProjector.kmPerDay(
        odometerReadings: [10000, 11000],
        dates: [DateTime(2026, 1, 1), DateTime(2026, 1, 51)],
      );

      expect(result, closeTo(20, 0.001));
    });

    test('falls back when there are fewer than two readings', () {
      expect(
        ReminderProjector.kmPerDay(
          odometerReadings: [10000],
          dates: [DateTime(2026, 1, 1)],
        ),
        ReminderProjector.fallbackKmPerDay,
      );
    });

    test('falls back when the readings span no time', () {
      expect(
        ReminderProjector.kmPerDay(
          odometerReadings: [10000, 11000],
          dates: [DateTime(2026, 1, 1), DateTime(2026, 1, 1)],
        ),
        ReminderProjector.fallbackKmPerDay,
      );
    });
  });

  group('project', () {
    test('a distance rule projects a due odometer and a date', () {
      final projection = ReminderProjector.project(
        rule: rule(intervalKm: 10000),
        lastServiceDate: DateTime(2026, 1, 1),
        lastServiceOdometerKm: 50000,
        currentOdometerKm: 56000,
        kmPerDay: 40,
        today: today,
      )!;

      expect(projection.dueOdometerKm, 60000);
      // 4000 km remaining at 40 km/day == 100 days out.
      expect(projection.projectedDueDate, DateTime(2026, 10, 28));
      expect(projection.state, ReminderState.upcoming);
    });

    test('a time rule projects from the last service date', () {
      final projection = ReminderProjector.project(
        rule: rule(intervalMonths: 12),
        lastServiceDate: DateTime(2026, 3, 1),
        lastServiceOdometerKm: 50000,
        currentOdometerKm: 56000,
        kmPerDay: 40,
        today: today,
      )!;

      expect(projection.projectedDueDate, DateTime(2027, 3, 1));
      expect(projection.dueOdometerKm, isNull);
    });

    test('a distance rule reports the consumed fraction of the interval', () {
      final projection = ReminderProjector.project(
        rule: rule(intervalKm: 10000),
        lastServiceDate: DateTime(2026, 1, 1),
        lastServiceOdometerKm: 50000,
        currentOdometerKm: 56000,
        kmPerDay: 40,
        today: today,
      )!;

      expect(projection.fractionConsumed, closeTo(0.6, 0.001));
    });

    test('a combined rule reports the more-consumed dimension', () {
      // Distance: 6000 of 10000 km = 0.6. Time: ~200 of ~365 days ≈ 0.55.
      final projection = ReminderProjector.project(
        rule: rule(intervalKm: 10000, intervalMonths: 12),
        lastServiceDate: DateTime(2026, 1, 1),
        lastServiceOdometerKm: 50000,
        currentOdometerKm: 56000,
        kmPerDay: 40,
        today: today,
      )!;

      expect(projection.fractionConsumed, closeTo(0.6, 0.01));
    });

    test('a one-time rule projects its fixed date', () {
      final projection = ReminderProjector.project(
        rule: ReminderRule(
          id: 'r2',
          vehicleId: 'v1',
          serviceTypeKey: 'service_registration',
          oneTime: true,
          dueDate: DateTime(2026, 9, 1),
        ),
        lastServiceDate: null,
        lastServiceOdometerKm: null,
        currentOdometerKm: 56000,
        kmPerDay: 40,
        today: today,
        baselineDate: DateTime(2026, 1, 1),
        baselineOdometerKm: 50000,
      )!;

      expect(projection.projectedDueDate, DateTime(2026, 9, 1));
      expect(projection.state, ReminderState.upcoming);
      // ~200 of ~243 days consumed.
      expect(projection.fractionConsumed, closeTo(0.82, 0.02));
    });

    test('a one-time due odometer extrapolates through the driving rate', () {
      final projection = ReminderProjector.project(
        rule: ReminderRule(
          id: 'r3',
          vehicleId: 'v1',
          serviceTypeKey: 'service_tire_swap_seasonal',
          oneTime: true,
          dueOdometerKm: 58000,
        ),
        lastServiceDate: null,
        lastServiceOdometerKm: null,
        currentOdometerKm: 56000,
        kmPerDay: 40,
        today: today,
      )!;

      // 2000 km at 40 km/day == 50 days out.
      expect(projection.projectedDueDate, DateTime(2026, 9, 8));
      expect(projection.dueOdometerKm, 58000);
    });

    test('an inactive or targetless one-time rule does not project', () {
      expect(
        ReminderProjector.project(
          rule: ReminderRule(
            id: 'r4',
            vehicleId: 'v1',
            serviceTypeKey: 'service_registration',
            oneTime: true,
          ),
          lastServiceDate: null,
          lastServiceOdometerKm: null,
          currentOdometerKm: 56000,
          kmPerDay: 40,
          today: today,
        ),
        isNull,
      );
    });

    test('the consumed fraction clamps at one when overdue', () {
      final projection = ReminderProjector.project(
        rule: rule(intervalKm: 10000),
        lastServiceDate: DateTime(2026, 1, 1),
        lastServiceOdometerKm: 50000,
        currentOdometerKm: 62000,
        kmPerDay: 40,
        today: today,
      )!;

      expect(projection.fractionConsumed, 1.0);
    });

    test('whichever interval falls first wins', () {
      final projection = ReminderProjector.project(
        rule: rule(intervalKm: 10000, intervalMonths: 12),
        lastServiceDate: DateTime(2026, 1, 1),
        lastServiceOdometerKm: 50000,
        // 9500 km already driven, so the distance limit arrives far sooner
        // than the January 2027 date limit.
        currentOdometerKm: 59500,
        kmPerDay: 50,
        today: today,
      )!;

      // 500 km remaining at 50 km/day == 10 days out.
      expect(projection.projectedDueDate, DateTime(2026, 7, 30));
    });

    test('an item past its odometer limit is overdue', () {
      final projection = ReminderProjector.project(
        rule: rule(intervalKm: 10000),
        lastServiceDate: DateTime(2026, 1, 1),
        lastServiceOdometerKm: 50000,
        currentOdometerKm: 61000,
        kmPerDay: 40,
        today: today,
      )!;

      expect(projection.state, ReminderState.overdue);
      expect(projection.projectedDueDate.isBefore(today), isTrue);
    });

    test('an item past its date limit is overdue', () {
      final projection = ReminderProjector.project(
        rule: rule(intervalMonths: 6),
        lastServiceDate: DateTime(2025, 1, 1),
        lastServiceOdometerKm: 50000,
        currentOdometerKm: 51000,
        kmPerDay: 40,
        today: today,
      )!;

      expect(projection.state, ReminderState.overdue);
    });

    test('an item projected exactly at the due-window edge reads as due '
        'when the window crosses a DST fall-back', () {
      // today + 14 calendar days lands on 29 October 2026; the window crosses
      // Europe's late-October fall-back, so Duration-based arithmetic would
      // land at 28 October 23:00 and misclassify this exact-edge item as
      // upcoming. Calendar reconstruction keeps it due.
      final projection = ReminderProjector.project(
        rule: rule(intervalMonths: 1),
        lastServiceDate: DateTime(2026, 9, 29),
        lastServiceOdometerKm: 50000,
        currentOdometerKm: 51000,
        kmPerDay: 40,
        today: DateTime(2026, 10, 15),
      )!;

      expect(projection.projectedDueDate, DateTime(2026, 10, 29));
      expect(projection.state, ReminderState.due);
    });

    test('an item projected exactly at the due-window edge reads as due '
        'when the window does not cross a DST boundary', () {
      // today + 14 calendar days lands on 15 June 2026, a window with no DST
      // transition, pinning the inclusive-edge semantics.
      final projection = ReminderProjector.project(
        rule: rule(intervalMonths: 1),
        lastServiceDate: DateTime(2026, 5, 15),
        lastServiceOdometerKm: 50000,
        currentOdometerKm: 51000,
        kmPerDay: 40,
        today: DateTime(2026, 6, 1),
      )!;

      expect(projection.projectedDueDate, DateTime(2026, 6, 15));
      expect(projection.state, ReminderState.due);
    });

    test('an item inside the due window reads as due', () {
      final projection = ReminderProjector.project(
        rule: rule(intervalMonths: 6),
        lastServiceDate: DateTime(2026, 1, 25),
        lastServiceOdometerKm: 50000,
        currentOdometerKm: 51000,
        kmPerDay: 40,
        today: today,
      )!;

      // Due 25 July 2026, five days after "today".
      expect(projection.state, ReminderState.due);
    });

    test('a rule with no interval projects nothing', () {
      expect(
        ReminderProjector.project(
          rule: rule(),
          lastServiceDate: DateTime(2026, 1, 1),
          lastServiceOdometerKm: 50000,
          currentOdometerKm: 51000,
          kmPerDay: 40,
          today: today,
        ),
        isNull,
      );
    });

    test('an inactive rule projects nothing', () {
      expect(
        ReminderProjector.project(
          rule: rule(intervalKm: 10000, active: false),
          lastServiceDate: DateTime(2026, 1, 1),
          lastServiceOdometerKm: 50000,
          currentOdometerKm: 51000,
          kmPerDay: 40,
          today: today,
        ),
        isNull,
      );
    });

    test('a never-serviced item projects from the vehicle baseline', () {
      final projection = ReminderProjector.project(
        rule: rule(intervalKm: 10000),
        lastServiceDate: null,
        lastServiceOdometerKm: null,
        currentOdometerKm: 56000,
        kmPerDay: 40,
        today: today,
        baselineDate: DateTime(2026, 1, 1),
        baselineOdometerKm: 50000,
      )!;

      expect(projection.dueOdometerKm, 60000);
    });
  });
}
