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

      expect(first.single.id, again.single.id);
    });

    test('a different vehicle, item, or date is a different notification', () {
      final oil = notificationId(
        vehicleId: 'v1',
        serviceTypeKeys: const ['service_oil_change'],
        dueDate: DateTime.utc(2026, 9, 1),
      );

      expect(
        oil,
        isNot(
          notificationId(
            vehicleId: 'v2',
            serviceTypeKeys: const ['service_oil_change'],
            dueDate: DateTime.utc(2026, 9, 1),
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
        ),
        notificationId(
          vehicleId: 'v1',
          serviceTypeKeys: const ['service_brakes', 'service_oil_change'],
          dueDate: DateTime.utc(2026, 9, 1),
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
      );

      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThan(1 << 31));
    });
  });

  test('a loose item is scheduled ahead of its due date', () {
    final planned = plan(
      bundles: const [],
      loose: [due('a', DateTime(2026, 9, 1))],
      today: today,
    );

    expect(planned, hasLength(1));
    expect(planned.single.when, DateTime(2026, 8, 25));
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

    expect(planned, hasLength(1));
    expect(planned.single.itemCount, 2);
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

    expect(planned, hasLength(1));
  });

  test('a lead time that would land in the past fires today instead', () {
    final planned = plan(
      bundles: const [],
      loose: [due('a', DateTime(2026, 7, 22))],
      today: today,
    );

    expect(planned.single.when, today);
  });

  test('nothing due schedules nothing', () {
    expect(plan(bundles: const [], loose: const [], today: today), isEmpty);
  });
}
