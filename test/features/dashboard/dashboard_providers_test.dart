import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/features/dashboard/providers/dashboard_providers.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';

ReminderProjection due(String id, DateTime date) {
  return ReminderProjection(
    ruleId: id,
    vehicleId: 'v1',
    serviceTypeKey: 'service_$id',
    projectedDueDate: date,
    state: ReminderState.upcoming,
  );
}

ProviderContainer containerWith({
  required List<ReminderProjection> projections,
  Household household = const Household(id: 'h1', name: 'Test'),
}) {
  final container = ProviderContainer(
    overrides: [
      householdProjectionsProvider.overrideWith((ref) async => projections),
      currentHouseholdProvider.overrideWith((ref) async => household),
      todayProvider.overrideWithValue(DateTime(2026, 7, 20)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('nearby items produce a bundle', () async {
    final container = containerWith(
      projections: [
        due('a', DateTime(2026, 8, 1)),
        due('b', DateTime(2026, 8, 12)),
      ],
    );

    final bundles = await container.read(bundlesProvider.future);

    expect(bundles, hasLength(1));
    expect(bundles.single.items, hasLength(2));
  });

  test('the household window widens the grouping', () async {
    final container = containerWith(
      projections: [
        due('a', DateTime(2026, 8, 1)),
        due('b', DateTime(2026, 9, 20)),
      ],
      household: const Household(
        id: 'h1',
        name: 'Test',
        bundlingWindowDays: 60,
      ),
    );

    final bundles = await container.read(bundlesProvider.future);

    expect(bundles, hasLength(1));
  });

  test('the top bundle is the soonest one', () async {
    final container = containerWith(
      projections: [
        due('c', DateTime(2026, 11, 1)),
        due('d', DateTime(2026, 11, 8)),
        due('a', DateTime(2026, 8, 1)),
        due('b', DateTime(2026, 8, 8)),
      ],
    );

    final top = await container.read(topBundleProvider.future);

    expect(top!.visitDate, DateTime(2026, 8, 1));
  });

  test('the top bundle is null when nothing groups', () async {
    final container = containerWith(projections: [due('a', DateTime(2026, 8, 1))]);

    expect(await container.read(topBundleProvider.future), isNull);
  });
}
