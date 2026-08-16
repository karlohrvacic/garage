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
      todayProvider.overrideWithValue(_today),
    ],
  );
}

void main() {
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

  testWidgets('the sheets are reachable from the app bar and the button', (
    tester,
  ) async {
    await pumpMaintenance(tester, projections: [projection()]);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add_task), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
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
}
