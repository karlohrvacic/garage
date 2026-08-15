import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/maintenance/bundling.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/features/dashboard/providers/dashboard_providers.dart';
import 'package:garage/features/planner/providers/planner_providers.dart';
import 'package:garage/features/planner/screens/planner_screen.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import '../../support/pump_screen.dart';

final _monday = DateTime(2026, 8, 10);

ReminderProjection projection({
  String ruleId = 'r1',
  String serviceTypeKey = 'service_oil_change',
  DateTime? due,
  ReminderState state = ReminderState.upcoming,
}) {
  return ReminderProjection(
    ruleId: ruleId,
    vehicleId: 'v1',
    serviceTypeKey: serviceTypeKey,
    projectedDueDate: due ?? _monday,
    state: state,
    dueOdometerKm: 60000,
    fractionConsumed: 0.8,
  );
}

Future<NavigationLog> pumpPlanner(
  WidgetTester tester, {
  List<RunwayWeek> weeks = const [],
  List<MaintenanceBundle> bundles = const [],
}) {
  return pumpScreen(
    tester,
    const PlannerScreen(),
    initialLocation: '/planner',
    overrides: [
      runwayProvider.overrideWith((ref) async => weeks),
      bundlesProvider.overrideWith((ref) async => bundles),
      vehiclesProvider.overrideWith(
        (ref) async => [testVehicle('v1', nickname: 'Golf')],
      ),
    ],
  );
}

void main() {
  testWidgets('an empty runway says nothing is due', (tester) async {
    await pumpPlanner(
      tester,
      weeks: [RunwayWeek(start: _monday, items: const [])],
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing due in the next 12 weeks'), findsOneWidget);
  });

  testWidgets('the runway is titled and explains overdue placement', (
    tester,
  ) async {
    await pumpPlanner(
      tester,
      weeks: [RunwayWeek(start: _monday, items: const [])],
    );
    await tester.pumpAndSettle();

    expect(find.text('Next 12 weeks'), findsOneWidget);
    expect(find.textContaining('Overdue items are shown at today'), findsOne);
  });

  testWidgets('a due item is listed under its week', (tester) async {
    await pumpPlanner(
      tester,
      weeks: [
        RunwayWeek(start: _monday, items: [projection()]),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Oil change'), findsWidgets);
    expect(find.textContaining('Golf'), findsWidgets);
  });

  testWidgets('an overdue item is marked as such', (tester) async {
    await pumpPlanner(
      tester,
      weeks: [
        RunwayWeek(
          start: _monday,
          items: [projection(state: ReminderState.overdue)],
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Overdue'), findsWidgets);
  });

  testWidgets('the planner tab is the selected one', (tester) async {
    await pumpPlanner(
      tester,
      weeks: [RunwayWeek(start: _monday, items: const [])],
    );
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));

    expect(bar.selectedIndex, 3);
  });
}
