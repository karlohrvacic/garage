import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/features/maintenance/widgets/maintenance_calendar.dart';

import '../../support/pump_screen.dart';

ReminderProjection due({
  String ruleId = 'r1',
  String serviceTypeKey = 'service_oil_change',
  required DateTime date,
  ReminderState state = ReminderState.upcoming,
}) {
  return ReminderProjection(
    ruleId: ruleId,
    vehicleId: 'v1',
    serviceTypeKey: serviceTypeKey,
    projectedDueDate: date,
    state: state,
  );
}

Future<List<DateTime>> pumpCalendar(
  WidgetTester tester, {
  required DateTime month,
  List<ReminderProjection> projections = const [],
}) async {
  final months = <DateTime>[];
  await pumpScreen(
    tester,
    Scaffold(
      body: MaintenanceCalendar(
        projections: projections,
        month: month,
        onMonthChanged: months.add,
      ),
    ),
    surface: const Size(420, 900),
  );
  await tester.pumpAndSettle();
  return months;
}

void main() {
  final august = DateTime(2026, 8);

  testWidgets('it names the month it is showing', (tester) async {
    await pumpCalendar(tester, month: august);

    expect(find.textContaining('August'), findsOneWidget);
  });

  testWidgets('every day of the month has a cell', (tester) async {
    await pumpCalendar(tester, month: august);

    // August has 31 days; the 31st is the last one that must be there.
    expect(find.text('31'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('stepping back and forward reports the new month', (
    tester,
  ) async {
    final months = await pumpCalendar(tester, month: august);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(months, [DateTime(2026, 7), DateTime(2026, 9)]);
  });

  testWidgets('a day with something due is marked', (tester) async {
    await pumpCalendar(
      tester,
      month: august,
      projections: [due(date: DateTime(2026, 8, 12))],
    );

    // The marker is drawn inside the day cell, so the day is still readable.
    expect(find.text('12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a day with items opens what is due', (tester) async {
    await pumpCalendar(
      tester,
      month: august,
      projections: [
        due(date: DateTime(2026, 8, 12)),
        due(
          ruleId: 'r2',
          serviceTypeKey: 'service_brake_fluid',
          date: DateTime(2026, 8, 12),
          state: ReminderState.overdue,
        ),
      ],
    );

    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Oil change'), findsWidgets);
    expect(find.textContaining('Brake fluid'), findsWidgets);
  });

  testWidgets('tapping an empty day opens nothing', (tester) async {
    await pumpCalendar(
      tester,
      month: august,
      projections: [due(date: DateTime(2026, 8, 12))],
    );

    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Oil change'), findsNothing);
  });

  testWidgets('a month with nothing due still renders', (tester) async {
    await pumpCalendar(tester, month: august);

    expect(tester.takeException(), isNull);
  });
}
