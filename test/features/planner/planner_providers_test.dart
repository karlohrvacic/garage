import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/planner/providers/planner_providers.dart';

ReminderProjection due(
  String id,
  DateTime date, {
  ReminderState state = ReminderState.upcoming,
}) {
  return ReminderProjection(
    ruleId: id,
    vehicleId: 'v1',
    serviceTypeKey: 'service_$id',
    projectedDueDate: date,
    state: state,
  );
}

ProviderContainer containerWith(List<ReminderProjection> projections) {
  final container = ProviderContainer(
    overrides: [
      householdProjectionsProvider.overrideWith((ref) async => projections),
      // A Monday, so week boundaries are unambiguous.
      todayProvider.overrideWithValue(DateTime(2026, 7, 20)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('the runway is exactly 12 weeks', () async {
    final container = containerWith([]);

    final runway = await container.read(runwayProvider.future);

    expect(runway, hasLength(12));
  });

  test('the runway starts at the current week', () async {
    final container = containerWith([]);

    final runway = await container.read(runwayProvider.future);

    expect(runway.first.start, DateTime(2026, 7, 20));
  });

  test('an item lands in the week containing its due date', () async {
    final container = containerWith([due('a', DateTime(2026, 7, 29))]);

    final runway = await container.read(runwayProvider.future);

    expect(runway[1].items.map((i) => i.ruleId), ['a']);
    expect(runway[0].items, isEmpty);
  });

  test('an overdue item anchors at the current week, not in the past',
      () async {
    final container = containerWith([
      due('late', DateTime(2026, 6, 1), state: ReminderState.overdue),
    ]);

    final runway = await container.read(runwayProvider.future);

    expect(runway.first.items.map((i) => i.ruleId), ['late']);
  });

  test('items beyond the runway are not shown', () async {
    final container = containerWith([due('far', DateTime(2027, 6, 1))]);

    final runway = await container.read(runwayProvider.future);

    expect(runway.every((week) => week.items.isEmpty), isTrue);
  });
}
