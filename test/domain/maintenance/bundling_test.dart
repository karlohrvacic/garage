import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/maintenance/bundling.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';

final today = DateTime(2026, 7, 20);

ReminderProjection projection({
  required String ruleId,
  required DateTime dueDate,
  int? dueOdometerKm,
  ReminderState state = ReminderState.upcoming,
}) {
  return ReminderProjection(
    ruleId: ruleId,
    vehicleId: 'v1',
    serviceTypeKey: 'service_$ruleId',
    projectedDueDate: dueDate,
    dueOdometerKm: dueOdometerKm,
    state: state,
  );
}

void main() {
  test('two items falling due close together bundle', () {
    final bundles = BundlingEngine.bundle(
      projections: [
        projection(ruleId: 'a', dueDate: DateTime(2026, 8, 1)),
        projection(ruleId: 'b', dueDate: DateTime(2026, 8, 15)),
      ],
      today: today,
    );

    expect(bundles, hasLength(1));
    expect(bundles.single.items, hasLength(2));
  });

  test('items further apart than the window do not bundle', () {
    final bundles = BundlingEngine.bundle(
      projections: [
        projection(ruleId: 'a', dueDate: DateTime(2026, 8, 1)),
        projection(ruleId: 'b', dueDate: DateTime(2026, 11, 1)),
      ],
      today: today,
    );

    expect(bundles, isEmpty);
  });

  test('a lone item is not a bundle', () {
    final bundles = BundlingEngine.bundle(
      projections: [projection(ruleId: 'a', dueDate: DateTime(2026, 8, 1))],
      today: today,
    );

    expect(bundles, isEmpty);
  });

  // critique.json fix 1.
  test('an overdue item is clamped to today so it still bundles', () {
    final bundles = BundlingEngine.bundle(
      projections: [
        projection(
          ruleId: 'late',
          dueDate: DateTime(2026, 7, 6),
          state: ReminderState.overdue,
        ),
        projection(ruleId: 'soon', dueDate: DateTime(2026, 8, 8)),
      ],
      today: today,
    );

    // Raw dates are 33 days apart — outside the 21-day window. Clamping the
    // overdue item to today puts them 19 days apart, so they bundle.
    expect(bundles, hasLength(1));
    expect(bundles.single.items, hasLength(2));
  });

  // critique.json fix 2.
  test('the visit anchors to the earliest due date in the group', () {
    final bundles = BundlingEngine.bundle(
      projections: [
        projection(ruleId: 'a', dueDate: DateTime(2026, 8, 1)),
        projection(ruleId: 'b', dueDate: DateTime(2026, 8, 15)),
      ],
      today: today,
    );

    expect(bundles.single.visitDate, DateTime(2026, 8, 1));
  });

  test('a statutory item is never scheduled past its deadline', () {
    final bundles = BundlingEngine.bundle(
      projections: [
        projection(ruleId: 'registration', dueDate: DateTime(2026, 8, 3)),
        projection(ruleId: 'oil', dueDate: DateTime(2026, 8, 20)),
      ],
      today: today,
    );

    expect(
      bundles.single.visitDate.isAfter(DateTime(2026, 8, 3)),
      isFalse,
      reason: 'the visit must not slip past the earliest deadline',
    );
  });

  test('items near each other by odometer bundle even when dates are far', () {
    final bundles = BundlingEngine.bundle(
      projections: [
        projection(
          ruleId: 'a',
          dueDate: DateTime(2026, 8, 1),
          dueOdometerKm: 60000,
        ),
        projection(
          ruleId: 'b',
          dueDate: DateTime(2026, 12, 1),
          dueOdometerKm: 60300,
        ),
      ],
      today: today,
    );

    expect(bundles, hasLength(1));
  });

  test('the group span never exceeds the window', () {
    final bundles = BundlingEngine.bundle(
      projections: [
        projection(ruleId: 'a', dueDate: DateTime(2026, 8, 1)),
        projection(ruleId: 'b', dueDate: DateTime(2026, 8, 18)),
        // 34 days from 'a': outside the window, so it must start a new group
        // rather than chain-linking off 'b'.
        projection(ruleId: 'c', dueDate: DateTime(2026, 9, 4)),
      ],
      today: today,
    );

    expect(bundles, hasLength(1));
    expect(bundles.single.items.map((i) => i.projection.ruleId), ['a', 'b']);
  });

  test('a custom window widens the grouping', () {
    final bundles = BundlingEngine.bundle(
      projections: [
        projection(ruleId: 'a', dueDate: DateTime(2026, 8, 1)),
        projection(ruleId: 'b', dueDate: DateTime(2026, 9, 20)),
      ],
      today: today,
      window: const BundlingWindow(
        proximity: Duration(days: 60),
        proximityKm: 500,
      ),
    );

    expect(bundles, hasLength(1));
  });

  test('bundles come back ordered by visit date', () {
    final bundles = BundlingEngine.bundle(
      projections: [
        projection(ruleId: 'c', dueDate: DateTime(2026, 11, 1)),
        projection(ruleId: 'd', dueDate: DateTime(2026, 11, 10)),
        projection(ruleId: 'a', dueDate: DateTime(2026, 8, 1)),
        projection(ruleId: 'b', dueDate: DateTime(2026, 8, 10)),
      ],
      today: today,
    );

    expect(bundles, hasLength(2));
    expect(bundles.first.visitDate, DateTime(2026, 8, 1));
    expect(bundles.last.visitDate, DateTime(2026, 11, 1));
  });

  test('items sharing an effective date come out in ruleId order', () {
    // Both items fall due on the same day, so effectiveDate alone leaves their
    // order unspecified. The ruleId tie-break pins it, independent of the
    // caller's input order.
    List<String> orderFrom(List<String> inputRuleIds) {
      return BundlingEngine.bundle(
        projections: [
          for (final ruleId in inputRuleIds)
            projection(ruleId: ruleId, dueDate: DateTime(2026, 8, 1)),
        ],
        today: today,
      ).single.items.map((item) => item.projection.ruleId).toList();
    }

    expect(orderFrom(['b', 'a']), ['a', 'b']);
    expect(orderFrom(['a', 'b']), ['a', 'b']);
  });

  // critique.json fix 3.
  group('exclude', () {
    test('recomputes the visit date and span', () {
      final bundle = BundlingEngine.bundle(
        projections: [
          projection(ruleId: 'a', dueDate: DateTime(2026, 8, 1)),
          projection(ruleId: 'b', dueDate: DateTime(2026, 8, 10)),
          projection(ruleId: 'c', dueDate: DateTime(2026, 8, 18)),
        ],
        today: today,
      ).single;

      expect(bundle.visitDate, DateTime(2026, 8, 1));
      expect(bundle.span, const Duration(days: 17));

      final reduced = bundle.exclude('a')!;

      expect(reduced.items, hasLength(2));
      expect(reduced.visitDate, DateTime(2026, 8, 10));
      expect(reduced.span, const Duration(days: 8));
    });

    test('excluding down to one item leaves no bundle', () {
      final bundle = BundlingEngine.bundle(
        projections: [
          projection(ruleId: 'a', dueDate: DateTime(2026, 8, 1)),
          projection(ruleId: 'b', dueDate: DateTime(2026, 8, 10)),
        ],
        today: today,
      ).single;

      expect(bundle.exclude('a'), isNull);
    });

    test('excluding an absent rule leaves the bundle unchanged', () {
      final bundle = BundlingEngine.bundle(
        projections: [
          projection(ruleId: 'a', dueDate: DateTime(2026, 8, 1)),
          projection(ruleId: 'b', dueDate: DateTime(2026, 8, 10)),
        ],
        today: today,
      ).single;

      final same = bundle.exclude('nope')!;

      expect(same.items, hasLength(2));
      expect(same.visitDate, bundle.visitDate);
    });
  });
}
