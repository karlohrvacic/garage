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
      // No better anchor than the vehicle's own baseline is known here.
      // ~200 of ~243 days consumed.
      expect(projection.fractionConsumed, closeTo(0.82, 0.02));
    });

    test('a one-time rule anchors on when it was issued, not the vehicle\'s '
        'baseline, whenever it knows one', () {
      // A vignette bought yesterday, on a car added to the app a year ago.
      // The vehicle's baseline is not what started this rule's clock.
      final projection = ReminderProjector.project(
        rule: ReminderRule(
          id: 'r2',
          vehicleId: 'v1',
          serviceTypeKey: 'service_vignette',
          oneTime: true,
          dueDate: DateTime(2026, 7, 26),
          issuedDate: DateTime(2026, 7, 19),
        ),
        lastServiceDate: null,
        lastServiceOdometerKm: null,
        currentOdometerKm: 56000,
        kmPerDay: 40,
        today: today,
        baselineDate: DateTime(2025, 7, 20),
        baselineOdometerKm: 50000,
      )!;

      // 1 of 7 days consumed, not ~365 of ~372.
      expect(projection.fractionConsumed, closeTo(1 / 7, 0.01));
    });

    test('a backdated premium anchors on when it was actually paid, not when '
        'the row was written', () {
      // A premium paid two months ago (issuedDate), entered into the app
      // today — a household typing in last month's insurance is two
      // months into the year it covers, not zero days into it.
      final projection = ReminderProjector.project(
        rule: ReminderRule(
          id: 'r5',
          vehicleId: 'v1',
          serviceTypeKey: 'service_insurance',
          oneTime: true,
          dueDate: DateTime(2027, 5, 20),
          issuedDate: DateTime(2026, 5, 20),
        ),
        lastServiceDate: null,
        lastServiceOdometerKm: null,
        currentOdometerKm: 56000,
        kmPerDay: 40,
        today: today,
        baselineDate: DateTime(2020, 1, 1),
        baselineOdometerKm: 10000,
      )!;

      // ~61 of 365 days consumed (20 May to 20 Jul), not ~0.
      expect(projection.fractionConsumed, closeTo(61 / 365, 0.01));
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

    test('and the calendar wins when it is the one that falls first', () {
      // The mirror of the test above, which only ever exercised distance
      // winning. "30,000 km or 24 months, whichever comes first" has to mean
      // both directions, and a car driven gently is the case where the
      // calendar is the binding half.
      final projection = ReminderProjector.project(
        rule: rule(intervalKm: 30000, intervalMonths: 12),
        lastServiceDate: DateTime(2026, 1, 1),
        lastServiceOdometerKm: 50000,
        currentOdometerKm: 51000,
        kmPerDay: 10,
        today: today,
      )!;

      expect(projection.projectedDueDate, DateTime(2027, 1, 1));
      expect(projection.dateFromTime, DateTime(2027, 1, 1));
      // 29,000 km still to run at 10 km/day is years away.
      expect(
        projection.dateFromDistance!.isAfter(DateTime(2029, 1, 1)),
        isTrue,
      );
    });

    test('the ring follows whichever dimension is further consumed', () {
      // Half the distance used but nearly all the time, so the figure has to
      // come from the time side — the same "whichever comes first" rule the
      // date obeys, applied to the proportion.
      final projection = ReminderProjector.project(
        rule: rule(intervalKm: 30000, intervalMonths: 12),
        lastServiceDate: DateTime(2025, 8, 1),
        lastServiceOdometerKm: 50000,
        currentOdometerKm: 65000,
        kmPerDay: 45,
        today: today,
      )!;

      // 15,000 of 30,000 km is 0.50; 354 of 365 days is 0.97.
      expect(projection.fractionConsumed, closeTo(0.97, 0.01));
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

  group('both dimensions survive the projection', () {
    test('a rule with both keeps each date and still picks the earliest', () {
      // 28,977 km still to run at 68 km/day is 426 days out; the 24-month
      // deadline lands ten months after that. The
      // screen could not say so before: the loser was computed and discarded,
      // so a car that will hit its odometer a year before its calendar date
      // showed one date and no way to tell which dimension produced it.
      final projection = ReminderProjector.project(
        rule: rule(intervalKm: 30000, intervalMonths: 24),
        lastServiceDate: DateTime(2026, 7, 27),
        lastServiceOdometerKm: 47006,
        currentOdometerKm: 48029,
        kmPerDay: 68,
        today: today,
      )!;

      expect(projection.dateFromDistance, DateTime(2027, 9, 19));
      expect(projection.dateFromTime, DateTime(2028, 7, 27));
      expect(projection.projectedDueDate, projection.dateFromDistance);
    });

    test('a distance-only rule has no date from time', () {
      final projection = ReminderProjector.project(
        rule: rule(intervalKm: 10000),
        lastServiceDate: DateTime(2026, 1, 1),
        lastServiceOdometerKm: 50000,
        currentOdometerKm: 56000,
        kmPerDay: 40,
        today: today,
      )!;

      expect(projection.dateFromTime, isNull);
      expect(projection.dateFromDistance, projection.projectedDueDate);
    });

    test('a time-only rule has no date from distance', () {
      final projection = ReminderProjector.project(
        rule: rule(intervalMonths: 12),
        lastServiceDate: DateTime(2026, 3, 1),
        lastServiceOdometerKm: 50000,
        currentOdometerKm: 56000,
        kmPerDay: 40,
        today: today,
      )!;

      expect(projection.dateFromDistance, isNull);
      expect(projection.dateFromTime, projection.projectedDueDate);
    });

    test('a one-time rule carries both when it was given both', () {
      final projection = ReminderProjector.project(
        rule: ReminderRule(
          id: 'r2',
          vehicleId: 'v1',
          serviceTypeKey: 'service_registration',
          oneTime: true,
          dueDate: DateTime(2027, 9, 1),
          dueOdometerKm: 60000,
        ),
        lastServiceDate: null,
        lastServiceOdometerKm: null,
        currentOdometerKm: 56000,
        kmPerDay: 40,
        today: today,
      )!;

      // A one-off's date is fixed and its odometer extrapolates, exactly like
      // a recurring rule's two dimensions.
      expect(projection.dateFromTime, DateTime(2027, 9, 1));
      expect(projection.dateFromDistance, DateTime(2026, 10, 28));
      expect(projection.projectedDueDate, DateTime(2026, 10, 28));
    });
  });
}
