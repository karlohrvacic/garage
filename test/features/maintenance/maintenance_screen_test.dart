import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/adaptive.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/features/maintenance/data/maintenance_repository.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/maintenance/screens/maintenance_screen.dart';
import 'package:garage/features/maintenance/widgets/maintenance_calendar.dart';

import '../../support/pump_screen.dart';

final _today = DateTime(2026, 8, 15);

ReminderProjection projection({
  String ruleId = 'r1',
  String serviceTypeKey = 'service_oil_change',
  ReminderState state = ReminderState.upcoming,
  DateTime? due,
}) {
  return ReminderProjection(
    ruleId: ruleId,
    vehicleId: 'v1',
    serviceTypeKey: serviceTypeKey,
    projectedDueDate: due ?? _today.add(const Duration(days: 20)),
    state: state,
    dueOdometerKm: 60000,
    fractionConsumed: 0.6,
  );
}

Future<NavigationLog> pumpMaintenance(
  WidgetTester tester, {
  List<ReminderProjection> projections = const [],
  List<ServiceEntry> services = const [],
  double? drivingRate,
  Size surface = const Size(400, 1200),
}) {
  return pumpScreen(
    tester,
    const MaintenanceScreen(vehicleId: 'v1'),
    initialLocation: '/vehicles/v1/maintenance',
    surface: surface,
    overrides: [
      vehicleProjectionsProvider('v1').overrideWith((ref) async => projections),
      serviceEntriesProvider('v1').overrideWith((ref) async => services),
      serviceTypesProvider.overrideWith(
        (ref) async => const [ServiceType(key: 'service_oil_change')],
      ),
      drivingRateProvider('v1').overrideWith((ref) async => drivingRate),
      todayProvider.overrideWithValue(_today),
    ],
  );
}

void main() {
  // "Log service → Vignette expires" read as nonsense because it was: a
  // vignette is bought, not performed, and the reminder it raises could only
  // be cleared by recording a service against it. The menu now offers to
  // settle a reminder, and sends a cost-born one to the cost sheet.
  group('settling a reminder', () {
    testWidgets('a cost-born reminder offers to log the payment', (
      tester,
    ) async {
      await pumpMaintenance(
        tester,
        projections: [
          projection(ruleId: 'r1', serviceTypeKey: 'service_vignette'),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      expect(find.text('Log it as done'), findsOneWidget);
    });
  });

  testWidgets('a vehicle with no rules yet is invited to add one', (
    tester,
  ) async {
    await pumpMaintenance(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Add an interval to start tracking what is due'),
      findsOneWidget,
    );
  });

  testWidgets('the list and calendar are both offered', (tester) async {
    await pumpMaintenance(tester, projections: [projection()]);
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
  });

  testWidgets('a projected item names its service', (tester) async {
    await pumpMaintenance(tester, projections: [projection()]);
    await tester.pumpAndSettle();

    expect(find.textContaining('Oil change'), findsWidgets);
  });

  testWidgets('overdue items are called out', (tester) async {
    await pumpMaintenance(
      tester,
      projections: [
        projection(
          state: ReminderState.overdue,
          due: _today.subtract(const Duration(days: 5)),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Overdue'), findsWidgets);
  });

  testWidgets('switching to the calendar tab shows the month grid', (
    tester,
  ) async {
    await pumpMaintenance(tester, projections: [projection()]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(find.byType(MaintenanceCalendar), findsOneWidget);
  });

  testWidgets('one button offers both things this screen can add', (
    tester,
  ) async {
    // They were split across an app-bar icon and a FAB — "log what I just had
    // done" and "set up what should happen again" in different corners of the
    // same screen, with nothing to say why.
    await pumpMaintenance(tester, projections: [projection()]);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add_task), findsNothing);

    await tester.tap(find.byKey(const Key('maintenance-add')));
    await tester.pumpAndSettle();

    expect(find.text('Log service'), findsOneWidget);
    expect(find.text('Add interval'), findsOneWidget);
  });

  testWidgets('and says which is which, since the words are close', (
    tester,
  ) async {
    await pumpMaintenance(tester, projections: [projection()]);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('maintenance-add')));
    await tester.pumpAndSettle();

    expect(find.text('Something that has been done'), findsOneWidget);
    expect(find.text('Something that should come round again'), findsOneWidget);
  });

  testWidgets('a desktop window keeps both tabs in a reading column', (
    tester,
  ) async {
    await pumpMaintenance(
      tester,
      projections: [projection()],
      surface: const Size(1500, 1000),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(TabBarView)).width,
      GarageBreakpoints.contentMaxWidth,
      reason:
          'the calendar is seven square cells across, so every pixel of '
          'width inflates a day into a bigger empty box',
    );
  });

  testWidgets('the percentage is the one the dashboard gauge shows', (
    tester,
  ) async {
    // Two screens showed the same item as 100% and 26% because one measured
    // time left and the other interval used. Both now read `dueness`, and this
    // fails if either grows its own idea of the number again.
    final subject = projection();
    await pumpMaintenance(tester, projections: [subject]);
    await tester.pumpAndSettle();

    final shown = (subject.dueness(_today) * 100).round();

    expect(find.text('$shown%'), findsOneWidget);
  });

  testWidgets('a one-off with only a date still shows how close it is', (
    tester,
  ) async {
    final dated = ReminderProjection(
      ruleId: 'r-oneoff',
      vehicleId: 'v1',
      serviceTypeKey: 'service_tire_swap_seasonal',
      projectedDueDate: _today.add(const Duration(days: 7)),
      state: ReminderState.due,
    );

    await pumpMaintenance(tester, projections: [dated]);
    await tester.pumpAndSettle();

    // No interval to consume, so this used to render no bar and no figure.
    expect(
      find.text('${(dated.dueness(_today) * 100).round()}%'),
      findsOneWidget,
    );
  });

  // The month grid filled the top half and left the bottom empty, while what
  // each dot meant sat behind a tap in a sheet that covered the month you were
  // reading. A calendar shows the day's items under the grid.
  testWidgets('the calendar lists the chosen day under the grid', (
    tester,
  ) async {
    await pumpMaintenance(
      tester,
      projections: [projection(due: DateTime(2026, 8, 20))],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Oil change'), findsWidgets);
  });

  testWidgets('and says so for a day with nothing on it', (tester) async {
    await pumpMaintenance(
      tester,
      projections: [projection(due: DateTime(2026, 8, 20))],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('21'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing due'), findsOneWidget);
  });

  group('what a row says about the visit behind it', () {
    ServiceEntry visit({required List<String> types, double? cost = 200}) {
      return ServiceEntry(
        id: 's1',
        vehicleId: 'v1',
        date: DateTime.utc(2026, 7, 27),
        odometerKm: 47006,
        serviceTypeKeys: types,
        createdBy: 'u1',
        cost: cost,
      );
    }

    testWidgets('a visit covering one item quotes its cost plainly', (
      tester,
    ) async {
      await pumpMaintenance(
        tester,
        projections: [projection()],
        services: [
          visit(types: const ['service_oil_change']),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('€200.00'), findsOneWidget);
      expect(find.textContaining('for 1 item'), findsNothing);
    });

    testWidgets('a visit covering several says the cost was for all of them', (
      tester,
    ) async {
      // One 200 € visit covering four items printed "200,00 €" against each of
      // the four. Nothing summed it, so no total was wrong — but four
      // identical amounts invite exactly the wrong arithmetic.
      await pumpMaintenance(
        tester,
        projections: [projection()],
        services: [
          visit(
            types: const [
              'service_oil_change',
              'service_oil_filter',
              'service_cabin_filter',
              'service_brake_fluid',
            ],
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('€200.00 for 4 items'), findsOneWidget);
    });

    testWidgets('a visit with no cost recorded says nothing about money', (
      tester,
    ) async {
      await pumpMaintenance(
        tester,
        projections: [projection()],
        services: [
          visit(
            types: const ['service_oil_change', 'service_oil_filter'],
            cost: null,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('for 2 items'), findsNothing);
      expect(find.textContaining('Previously:'), findsOneWidget);
    });

    testWidgets('the due line names the date and the odometer once each', (
      tester,
    ) async {
      // It read "Due 4 Sep 2026 · Due at 60,000 km" — the verb twice, in both
      // languages, because two whole sentences were joined with a separator.
      await pumpMaintenance(tester, projections: [projection()]);
      await tester.pumpAndSettle();

      expect(find.textContaining('Due at 60,000 km'), findsNothing);
      expect(find.textContaining('· at 60,000 km'), findsOneWidget);
    });
  });

  group('both deadlines, when a rule has two', () {
    ReminderProjection twoDimensional({
      required DateTime distance,
      required DateTime time,
    }) {
      final earliest = distance.isBefore(time) ? distance : time;
      return ReminderProjection(
        ruleId: 'r1',
        vehicleId: 'v1',
        serviceTypeKey: 'service_oil_change',
        projectedDueDate: earliest,
        state: ReminderState.upcoming,
        dueOdometerKm: 77006,
        fractionConsumed: 0.03,
        dateFromDistance: distance,
        dateFromTime: time,
      );
    }

    testWidgets('says when the calendar deadline lands, if km binds first', (
      tester,
    ) async {
      // The prediction the odometer history exists to make: you will be at
      // 77,006 km in autumn 2027, ten months before the calendar asks.
      await pumpMaintenance(
        tester,
        projections: [
          twoDimensional(
            distance: DateTime(2027, 9, 19),
            time: DateTime(2028, 7, 27),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('By date not until'), findsOneWidget);
      expect(find.textContaining('Jul 27, 2028'), findsOneWidget);
    });

    testWidgets('says when the odometer lands, if the calendar binds first', (
      tester,
    ) async {
      await pumpMaintenance(
        tester,
        projections: [
          twoDimensional(
            distance: DateTime(2029, 3, 4),
            time: DateTime(2027, 1, 10),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('By distance not until'), findsOneWidget);
    });

    testWidgets('stays quiet when a rule has only one dimension', (
      tester,
    ) async {
      await pumpMaintenance(tester, projections: [projection()]);
      await tester.pumpAndSettle();

      expect(find.textContaining('not until'), findsNothing);
    });

    testWidgets('stays quiet when both deadlines fall on the same day', (
      tester,
    ) async {
      // Two deadlines that agree are one deadline, and saying it twice is
      // noise on a row that already carries four lines.
      await pumpMaintenance(
        tester,
        projections: [
          twoDimensional(
            distance: DateTime(2027, 5, 5),
            time: DateTime(2027, 5, 5),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('not until'), findsNothing);
    });
  });

  group('the rate every distance projection rests on', () {
    testWidgets('is stated when it was measured', (tester) async {
      await pumpMaintenance(
        tester,
        projections: [projection()],
        drivingRate: 68,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('68 km'), findsOneWidget);
    });

    testWidgets('says so when it is assumed rather than measured', (
      tester,
    ) async {
      // A projection built on the fallback looked exactly like one built on
      // real history, which made a wrong date impossible to account for.
      await pumpMaintenance(tester, projections: [projection()]);
      await tester.pumpAndSettle();

      expect(find.textContaining('Assuming'), findsOneWidget);
      expect(find.textContaining('30 km'), findsOneWidget);
    });
  });
}
