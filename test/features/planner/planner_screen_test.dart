import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/adaptive.dart';
import 'package:garage/domain/maintenance/bundling.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/features/maintenance/data/maintenance_repository.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/maintenance/widgets/maintenance_calendar.dart';
import 'package:garage/features/maintenance/widgets/reminder_rule_sheet.dart';
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
  List<ReminderProjection> furtherOut = const [],
  List<ReminderProjection> projections = const [],
  List<Vehicle>? vehicles,
  Size surface = const Size(400, 900),
}) {
  return pumpScreen(
    tester,
    const PlannerScreen(),
    initialLocation: '/planner',
    extraRoutes: const ['/vehicles/:id/maintenance'],
    surface: surface,
    overrides: [
      todayProvider.overrideWithValue(_monday),
      runwayProvider.overrideWith((ref) async => weeks),
      bundlesProvider.overrideWith((ref) async => bundles),
      furtherOutProvider.overrideWith((ref) async => furtherOut),
      householdProjectionsProvider.overrideWith((ref) async => projections),
      vehiclesProvider.overrideWith(
        (ref) async => vehicles ?? [testVehicle('v1', nickname: 'Golf')],
      ),
      allVehiclesProvider.overrideWith(
        (ref) async => vehicles ?? [testVehicle('v1', nickname: 'Golf')],
      ),
      availableServiceTypesProvider.overrideWith(
        (ref, vehicleId) async => const [
          ServiceType(key: 'service_oil_change'),
        ],
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
      weeks: [
        RunwayWeek(start: _monday, items: [projection()]),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Next 12 weeks'), findsOneWidget);
    expect(find.textContaining('Anything overdue sits under today'), findsOne);
  });

  testWidgets('an empty runway does not explain where overdue items go', (
    tester,
  ) async {
    // A sentence about overdue placement above "Nothing due" describes a
    // list that is not there.
    await pumpPlanner(
      tester,
      weeks: [RunwayWeek(start: _monday, items: const [])],
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing due in the next 12 weeks'), findsOneWidget);
    expect(
      find.textContaining('Anything overdue sits under today'),
      findsNothing,
    );
  });

  testWidgets('an empty runway over further-out items offers no button', (
    tester,
  ) async {
    // The filled "Add reminder" above a "Further out" card made two
    // primaries on a page that was not empty.
    await pumpPlanner(
      tester,
      weeks: [RunwayWeek(start: _monday, items: const [])],
      furtherOut: [projection(due: DateTime(2027, 9, 4))],
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing due in the next 12 weeks'), findsOneWidget);
    expect(find.byKey(const Key('planner-add-rule-empty')), findsNothing);
    expect(find.text('FURTHER OUT'), findsOneWidget);
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

    // The dashboard card learned this and the planner did not: as a word beside
    // the row, the control read like a decision about the service rather than
    // about the suggestion — and in Croatian it read "Preskoči", Skip, next to
    // a brake fluid change nobody meant to skip.
    testWidgets('trimming an item is the same icon the dashboard uses', (
      tester,
    ) async {
      await pumpPlanner(tester, bundles: [bundle()]);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.remove_circle_outline), findsWidgets);
      expect(find.widgetWithText(TextButton, 'Skip'), findsNothing);
    });

    testWidgets('and says what trimming did once something is trimmed', (
      tester,
    ) async {
      // Three items, because trimming a pair down to one leaves no bundle at
      // all and takes the card — and the note — with it.
      final three = MaintenanceBundle([
        ...bundle().items,
        BundleItem(
          projection: projection(
            ruleId: 'r3',
            serviceTypeKey: 'service_cabin_filter',
          ),
          effectiveDate: _monday,
        ),
      ]);
      await pumpPlanner(tester, bundles: [three]);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('nothing is logged or cancelled'),
        findsNothing,
      );

      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('nothing is logged or cancelled'),
        findsOneWidget,
      );
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

  group('adding a reminder from the planner', () {
    // The planner answers "what is coming up", and the only way to change
    // that answer was to leave for a vehicle's maintenance screen. Somebody
    // reading an empty runway is exactly the person about to add a rule.
    testWidgets('with one vehicle the rule sheet opens directly', (
      tester,
    ) async {
      await pumpPlanner(
        tester,
        weeks: [RunwayWeek(start: _monday, items: const [])],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('planner-add-rule')));
      await tester.pumpAndSettle();

      final sheet = tester.widget<ReminderRuleSheet>(
        find.byType(ReminderRuleSheet),
      );
      expect(sheet.vehicleId, 'v1');
    });

    testWidgets('with several vehicles it asks which one first', (
      tester,
    ) async {
      await pumpPlanner(
        tester,
        weeks: [RunwayWeek(start: _monday, items: const [])],
        vehicles: [
          testVehicle('v1', nickname: 'Golf'),
          testVehicle('v2', nickname: 'Clio'),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('planner-add-rule')));
      await tester.pumpAndSettle();

      expect(find.text('Which vehicle?'), findsOneWidget);
      await tester.tap(find.text('Clio'));
      await tester.pumpAndSettle();

      final sheet = tester.widget<ReminderRuleSheet>(
        find.byType(ReminderRuleSheet),
      );
      expect(sheet.vehicleId, 'v2');
    });

    testWidgets('an empty runway offers it in place', (tester) async {
      await pumpPlanner(
        tester,
        weeks: [RunwayWeek(start: _monday, items: const [])],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('planner-add-rule-empty')), findsOneWidget);
    });

    testWidgets('a garage with no vehicles is not offered it', (tester) async {
      await pumpPlanner(
        tester,
        weeks: [RunwayWeek(start: _monday, items: const [])],
        vehicles: const [],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('planner-add-rule')), findsNothing);
      expect(find.byKey(const Key('planner-add-rule-empty')), findsNothing);
    });
  });

  group('further out', () {
    // The first reminder most people set is an oil change a year away. The
    // runway said "Nothing due in the next 12 weeks" and nothing else, which
    // read as a failed save.
    testWidgets('what is due beyond the runway is listed by month', (
      tester,
    ) async {
      await pumpPlanner(
        tester,
        weeks: [RunwayWeek(start: _monday, items: const [])],
        furtherOut: [
          projection(due: DateTime(2027, 9, 3)),
          projection(
            ruleId: 'r2',
            serviceTypeKey: 'service_brake_fluid',
            due: DateTime(2027, 2, 10),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Nothing due in the next 12 weeks'), findsOneWidget);
      expect(find.text('FURTHER OUT'), findsOneWidget);
      expect(find.textContaining('Oil change'), findsOneWidget);
      expect(find.textContaining('Brake fluid'), findsOneWidget);
    });

    testWidgets('nothing further out shows no section', (tester) async {
      await pumpPlanner(
        tester,
        weeks: [RunwayWeek(start: _monday, items: const [])],
      );
      await tester.pumpAndSettle();

      expect(find.text('FURTHER OUT'), findsNothing);
    });
  });

  testWidgets('a planned item opens the car it belongs to', (tester) async {
    // The rows named a car and a job and led nowhere.
    final log = await pumpPlanner(
      tester,
      weeks: [
        RunwayWeek(start: _monday, items: [projection()]),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Oil change').first);
    await tester.pumpAndSettle();

    expect(log.visited, contains('/vehicles/v1/maintenance'));
  });

  group('the calendar', () {
    // A month calendar of what is due existed only per vehicle, four taps
    // deep behind the vehicle page's overflow menu. The planner is where
    // someone looks for "what is coming", so the calendar lives here too.
    testWidgets('is one tap away and covers the whole garage', (tester) async {
      await pumpPlanner(
        tester,
        weeks: [RunwayWeek(start: _monday, items: const [])],
        projections: [projection(due: DateTime(2026, 8, 20))],
      );
      await tester.pumpAndSettle();

      expect(find.byType(MaintenanceCalendar), findsNothing);
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      expect(find.byType(MaintenanceCalendar), findsOneWidget);
    });

    testWidgets('names the vehicle on each day, being garage-wide', (
      tester,
    ) async {
      // Per vehicle, "Oil change" was enough; across two cars it is not.
      await pumpPlanner(
        tester,
        weeks: [RunwayWeek(start: _monday, items: const [])],
        projections: [projection(due: DateTime(2026, 8, 20))],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      expect(find.text('Oil change'), findsOneWidget);
      expect(find.text('Golf'), findsOneWidget);
    });

    testWidgets('keeps its grid to a phone width on a desktop pane', (
      tester,
    ) async {
      // Seven square cells across a thousand pixels made six rows overrun
      // the screen.
      await pumpPlanner(
        tester,
        weeks: [RunwayWeek(start: _monday, items: const [])],
        projections: [projection(due: DateTime(2026, 8, 20))],
        surface: const Size(1280, 800),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(GridView)).width,
        lessThanOrEqualTo(448),
      );
    });

    testWidgets('marks today and says what a tap does', (tester) async {
      await pumpPlanner(
        tester,
        weeks: [RunwayWeek(start: _monday, items: const [])],
        projections: [projection(due: DateTime(2026, 8, 20))],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calendar-today')), findsOneWidget);
      expect(find.text('Tap a day to see what is due'), findsOneWidget);

      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      expect(find.text('Tap a day to see what is due'), findsNothing);
    });
  });
}
