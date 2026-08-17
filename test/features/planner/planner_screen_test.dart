import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/adaptive.dart';
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

MaintenanceBundle bundle() {
  return MaintenanceBundle([
    BundleItem(projection: projection(), effectiveDate: _monday),
    BundleItem(
      projection: projection(
        ruleId: 'r2',
        serviceTypeKey: 'service_brake_pads',
      ),
      effectiveDate: _monday,
    ),
  ]);
}

Future<NavigationLog> pumpPlanner(
  WidgetTester tester, {
  List<RunwayWeek> weeks = const [],
  List<MaintenanceBundle> bundles = const [],
  Size surface = const Size(400, 900),
}) {
  return pumpScreen(
    tester,
    const PlannerScreen(),
    initialLocation: '/planner',
    surface: surface,
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
    expect(find.textContaining('Anything overdue sits under today'), findsOne);
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

  group('acting on a bundle', () {
    // The planner is the screen dedicated to what to group into one visit, and
    // it was the one place that showed a bundle without offering to log it —
    // the dashboard card had that button, the screen you go to for the same
    // answer did not. Reading a plan and then navigating elsewhere to act on
    // it is the trip the bundle exists to save.
    testWidgets('a bundle offers to log the visit it describes', (
      tester,
    ) async {
      await pumpPlanner(tester, bundles: [bundle()]);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('planner-log-visit')), findsOneWidget);
      expect(find.text('Log this visit'), findsOneWidget);
    });

    testWidgets('a bundle across two cars does not offer it', (tester) async {
      // A service entry belongs to one vehicle. Logging several cars' work
      // against whichever came first would be worse than not offering it.
      await pumpPlanner(
        tester,
        bundles: [
          MaintenanceBundle([
            BundleItem(projection: projection(), effectiveDate: _monday),
            BundleItem(
              projection: ReminderProjection(
                ruleId: 'r2',
                vehicleId: 'v2',
                serviceTypeKey: 'service_brake_pads',
                projectedDueDate: _monday,
                state: ReminderState.upcoming,
                dueOdometerKm: 60000,
                fractionConsumed: 0.8,
              ),
              effectiveDate: _monday,
            ),
          ]),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('planner-log-visit')), findsNothing);
      expect(find.textContaining('Log it per vehicle'), findsOneWidget);
    });
  });

  group('on a desktop window', () {
    // Section keys rather than text positions: the runway heading and a bundle
    // title sit inside differently padded parents, so their x differs whatever
    // the layout does.
    Finder section(String name) => find.byKey(Key('planner-$name'));

    Future<void> pumpBoth(WidgetTester tester, {Size? surface}) async {
      await pumpPlanner(
        tester,
        surface: surface ?? const Size(400, 900),
        weeks: [
          RunwayWeek(start: _monday, items: [projection()]),
        ],
        bundles: [bundle()],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the planner uses the window rather than a reading column', (
      tester,
    ) async {
      await pumpBoth(tester, surface: const Size(1500, 1000));

      expect(
        tester.getSize(find.byType(ListView)).width,
        greaterThan(GarageBreakpoints.contentMaxWidth),
      );
    });

    testWidgets('the runway and the bundles sit beside each other', (
      tester,
    ) async {
      await pumpBoth(tester, surface: const Size(1500, 1000));

      expect(
        tester.getTopLeft(section('runway')).dx,
        isNot(tester.getTopLeft(section('bundles')).dx),
        reason:
            'what is coming up and what to group into one visit are two '
            'answers to the same question, and a window has room for both',
      );
    });

    testWidgets('a phone still stacks them', (tester) async {
      await pumpBoth(tester);

      expect(
        tester.getTopLeft(section('runway')).dx,
        tester.getTopLeft(section('bundles')).dx,
      );
    });
  });
}
