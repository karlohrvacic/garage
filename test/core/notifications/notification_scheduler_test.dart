import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/notifications/notification_scheduler.dart';
import 'package:garage/domain/maintenance/bundling.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';

final today = DateTime(2026, 7, 20);

ReminderProjection due(String id, DateTime date) {
  return ReminderProjection(
    ruleId: id,
    vehicleId: 'v1',
    serviceTypeKey: 'service_$id',
    projectedDueDate: date,
    state: ReminderState.upcoming,
  );
}

ReminderProjection dueAtKm(String id, int km, {String vehicleId = 'v1'}) {
  return ReminderProjection(
    ruleId: id,
    vehicleId: vehicleId,
    serviceTypeKey: 'service_$id',
    // Far enough away by date that nothing here is a dated nudge in disguise.
    projectedDueDate: DateTime(2026, 12, 1),
    state: ReminderState.upcoming,
    dueOdometerKm: km,
  );
}

void main() {
  group('what makes two notifications the same notification', () {
    test('the same reminder keeps its id across a resync', () {
      final first = plan(
        bundles: const [],
        loose: [due('a', DateTime(2026, 9, 1))],
        today: today,
      );
      final again = plan(
        bundles: const [],
        loose: [due('a', DateTime(2026, 9, 1))],
        today: DateTime(2026, 7, 21),
      );

      expect(first.map((r) => r.id), again.map((r) => r.id));
    });

    test('a different vehicle, item, or date is a different notification', () {
      final oil = notificationId(
        vehicleId: 'v1',
        serviceTypeKeys: const ['service_oil_change'],
        dueDate: DateTime.utc(2026, 9, 1),
        leadDays: 7,
      );

      expect(
        oil,
        isNot(
          notificationId(
            vehicleId: 'v2',
            serviceTypeKeys: const ['service_oil_change'],
            dueDate: DateTime.utc(2026, 9, 1),
            leadDays: 7,
          ),
        ),
      );
      expect(
        oil,
        isNot(
          notificationId(
            vehicleId: 'v1',
            serviceTypeKeys: const ['service_brakes'],
            dueDate: DateTime.utc(2026, 9, 1),
            leadDays: 7,
          ),
        ),
      );
      expect(
        oil,
        isNot(
          notificationId(
            vehicleId: 'v1',
            serviceTypeKeys: const ['service_oil_change'],
            dueDate: DateTime.utc(2026, 9, 2),
            leadDays: 7,
          ),
        ),
      );
    });

    test('the order the items arrive in does not change the id', () {
      // The app bundles in its own order and a push lists them in another;
      // the same visit has to come out as one notification either way.
      expect(
        notificationId(
          vehicleId: 'v1',
          serviceTypeKeys: const ['service_oil_change', 'service_brakes'],
          dueDate: DateTime.utc(2026, 9, 1),
          leadDays: 7,
        ),
        notificationId(
          vehicleId: 'v1',
          serviceTypeKeys: const ['service_brakes', 'service_oil_change'],
          dueDate: DateTime.utc(2026, 9, 1),
          leadDays: 7,
        ),
      );
    });

    test('an id is something Android will accept', () {
      // The plugin takes a 32-bit signed int; a hash that overflows it throws
      // at the platform channel, where nothing in this suite would see it.
      final id = notificationId(
        vehicleId: 'a-uuid-that-is-quite-long-indeed-0000',
        serviceTypeKeys: const ['service_oil_change'],
        dueDate: DateTime.utc(2026, 9, 1),
        leadDays: 7,
      );

      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThan(1 << 31));
    });
  });

  group('two nudges, because they answer different questions', () {
    test('one to book the visit, one to make it', () {
      // Seven days was one number doing two jobs and failing the first: a
      // service centre rarely has an appointment inside a week.
      final planned = plan(
        bundles: const [],
        loose: [due('a', DateTime(2026, 12, 1))],
        today: today,
      );

      expect(planned.map((r) => r.when), [
        DateTime(2026, 11, 1, 9),
        DateTime(2026, 11, 24, 9),
      ]);
      expect(planned.map((r) => r.leadDays), [30, 7]);
    });

    test('they are two notifications, not one that overwrote the other', () {
      // Both describe the same visit, so everything but the lead is equal;
      // sharing an id would mean the later one silently replaced the earlier
      // pending one and only a single nudge ever fired.
      final planned = plan(
        bundles: const [],
        loose: [due('a', DateTime(2026, 12, 1))],
        today: today,
      );

      expect(planned.map((r) => r.id).toSet(), hasLength(2));
    });

    test('a lead already behind us is not fired late', () {
      // Something due in a fortnight missed its month's notice; announcing it
      // now as "due in 30 days" would be a lie, and firing both at once is
      // just noise.
      final planned = plan(
        bundles: const [],
        loose: [due('a', today.add(const Duration(days: 14)))],
        today: today,
      );

      expect(planned.single.leadDays, 7);
      expect(planned.single.when, DateTime(2026, 7, 27, 9));
    });

    test('every lead behind us still leaves one nudge, today', () {
      final planned = plan(
        bundles: const [],
        loose: [due('a', today.add(const Duration(days: 2)))],
        today: today,
      );

      expect(planned, hasLength(1));
      expect(planned.single.when, DateTime(2026, 7, 20, 9));
    });

    test('a nudge lands at a civil hour, not at midnight', () {
      final planned = plan(
        bundles: const [],
        loose: [due('a', DateTime(2026, 12, 1))],
        today: today,
      );

      for (final reminder in planned) {
        expect(reminder.when.hour, 9);
      }
    });
  });

  test('a bundle is one notification, not one per item', () {
    final bundles = BundlingEngine.bundle(
      projections: [
        due('a', DateTime(2026, 9, 1)),
        due('b', DateTime(2026, 9, 10)),
      ],
      today: today,
    );

    final planned = plan(bundles: bundles, loose: const [], today: today);

    // One visit, announced at each lead — never one nudge per item in it.
    expect(planned, hasLength(notificationLeadDays.length));
    for (final reminder in planned) {
      expect(reminder.itemCount, 2);
    }
  });

  test('an item already in a bundle is not also scheduled loose', () {
    final projections = [
      due('a', DateTime(2026, 9, 1)),
      due('b', DateTime(2026, 9, 10)),
    ];
    final bundles = BundlingEngine.bundle(
      projections: projections,
      today: today,
    );

    final planned = plan(bundles: bundles, loose: projections, today: today);

    expect(planned, hasLength(notificationLeadDays.length));
  });

  test('a lead time that would land in the past fires today instead', () {
    final planned = plan(
      bundles: const [],
      loose: [due('a', DateTime(2026, 7, 22))],
      today: today,
    );

    expect(planned.single.when, DateTime(2026, 7, 20, notificationHour));
  });

  test('nothing due schedules nothing', () {
    expect(plan(bundles: const [], loose: const [], today: today), isEmpty);
  });

  group('a reading is news, not just a date moving', () {
    // A service due at 60000 km is not a calendar event. The projector turns
    // it into one by guessing a driving rate, and a household that drives more
    // than the guess reaches the odometer long before the date says so. The
    // moment somebody logs a reading, the truth is known exactly.
    test('coming within range of a distance rule is worth saying', () {
      final planned = planByDistance(
        projections: [dueAtKm('oil', 60000)],
        currentKm: const {'v1': 59700},
        today: today,
      );

      expect(planned.single.remainingKm, 300);
      expect(planned.single.serviceTypeKeys, ['service_oil']);
    });

    test('still far off is not worth saying', () {
      final planned = planByDistance(
        projections: [dueAtKm('oil', 60000)],
        currentKm: const {'v1': 55000},
        today: today,
      );

      expect(planned, isEmpty);
    });

    test('past the odometer it was due at counts as news too', () {
      final planned = planByDistance(
        projections: [dueAtKm('oil', 60000)],
        currentKm: const {'v1': 60400},
        today: today,
      );

      expect(planned.single.remainingKm, -400);
    });

    test('a rule with no distance to it is left to the calendar', () {
      final planned = planByDistance(
        projections: [due('registration', DateTime(2026, 9, 1))],
        currentKm: const {'v1': 59900},
        today: today,
      );

      expect(planned, isEmpty);
    });

    test('a vehicle nobody has a reading for says nothing', () {
      final planned = planByDistance(
        projections: [dueAtKm('oil', 60000, vehicleId: 'v9')],
        currentKm: const {'v1': 59900},
        today: today,
      );

      expect(planned, isEmpty);
    });

    test('it keeps one identity as the reading moves toward it', () {
      // Every fill-up recomputes this. A new id each time would stack a fresh
      // notification per reading; the same id updates the one already there.
      final far = planByDistance(
        projections: [dueAtKm('oil', 60000)],
        currentKm: const {'v1': 59600},
        today: today,
      ).single;
      final near = planByDistance(
        projections: [dueAtKm('oil', 60000)],
        currentKm: const {'v1': 59900},
        today: today,
      ).single;

      expect(far.id, near.id);
    });

    test('it is not the same notification as the dated one', () {
      final byDistance = planByDistance(
        projections: [dueAtKm('oil', 60000)],
        currentKm: const {'v1': 59900},
        today: today,
      ).single;
      final byDate = plan(
        bundles: const [],
        loose: [dueAtKm('oil', 60000)],
        today: today,
      );

      expect(byDate.map((r) => r.id), isNot(contains(byDistance.id)));
    });
  });
}
