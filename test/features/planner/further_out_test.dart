import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/planner/providers/planner_providers.dart';

ReminderProjection at(String id, DateTime due) => ReminderProjection(
  ruleId: id,
  vehicleId: 'v1',
  serviceTypeKey: 'service_oil_change',
  projectedDueDate: due,
  state: ReminderState.upcoming,
  dueOdometerKm: 60000,
  fractionConsumed: 0.1,
);

void main() {
  final today = DateTime(2026, 8, 12);

  test(
    'further out is everything past the twelve-week horizon, soonest first',
    () async {
      final container = ProviderContainer(
        overrides: [
          todayProvider.overrideWithValue(today),
          householdProjectionsProvider.overrideWith(
            (ref) async => [
              at('far', DateTime(2027, 9, 3)),
              at('soon', DateTime(2026, 9, 1)),
              at('near-far', DateTime(2026, 12, 20)),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final further = await container.read(furtherOutProvider.future);

      expect(further.map((p) => p.ruleId), ['near-far', 'far']);
    },
  );

  test('an overdue item is never further out', () async {
    final container = ProviderContainer(
      overrides: [
        todayProvider.overrideWithValue(today),
        householdProjectionsProvider.overrideWith(
          (ref) async => [at('late', DateTime(2025, 1, 1))],
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(furtherOutProvider.future), isEmpty);
  });
}
