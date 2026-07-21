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
    final bundles =
        BundlingEngine.bundle(projections: projections, today: today);

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
