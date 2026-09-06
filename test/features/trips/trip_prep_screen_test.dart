import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/vehicle_document.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/features/documents/providers/document_providers.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/trips/screens/trip_prep_screen.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/pump_screen.dart';

ReminderProjection due({
  String ruleId = 'r1',
  String key = 'service_oil',
  int? dueOdometerKm,
}) {
  return ReminderProjection(
    ruleId: ruleId,
    vehicleId: 'v1',
    serviceTypeKey: key,
    projectedDueDate: DateTime.utc(2026, 12, 1),
    dueOdometerKm: dueOdometerKm,
    state: ReminderState.upcoming,
  );
}

Future<void> pumpPrep(
  WidgetTester tester, {
  List<ReminderProjection> projections = const [],
  List<VehicleDocument> documents = const [],
  int? odometer = 142300,
}) async {
  await pumpScreen(
    tester,
    const TripPrepScreen(vehicleId: 'v1'),
    initialLocation: '/vehicles/v1/trip',
    surface: const Size(420, 1600),
    overrides: [
      vehicleProjectionsProvider('v1').overrideWith((ref) async => projections),
      vehicleDocumentsProvider('v1').overrideWith((ref) async => documents),
      currentOdometerProvider('v1').overrideWith((ref) async => odometer),
    ],
  );
  await tester.pumpAndSettle();
}

Future<void> checkFor(WidgetTester tester, String distance) async {
  await tester.enterText(find.byKey(const Key('prep-distance')), distance);
  await tester.tap(find.byKey(const Key('prep-check')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('it says what it is and is not, before anything else', (
    tester,
  ) async {
    // The screen must never read as a roadworthiness check.
    await pumpPrep(tester);

    expect(find.textContaining('not a roadworthiness check'), findsOneWidget);
  });

  testWidgets('a service inside the distance is reported with how far off', (
    tester,
  ) async {
    await pumpPrep(tester, projections: [due(dueOdometerKm: 143200)]);

    await checkFor(tester, '1500');

    expect(find.textContaining('in about 900 km'), findsOneWidget);
  });

  testWidgets('and one beyond it is not mentioned', (tester) async {
    await pumpPrep(tester, projections: [due(dueOdometerKm: 148000)]);

    await checkFor(tester, '500');

    expect(
      find.text('Nothing in your records falls due over this journey.'),
      findsOneWidget,
    );
  });

  testWidgets('a forecast is labelled as a forecast', (tester) async {
    // The distinction the screen turns on: a projection from observed driving
    // is not a date somebody wrote down.
    await pumpPrep(tester, projections: [due(dueOdometerKm: 142500)]);

    await checkFor(tester, '1000');

    expect(
      find.textContaining('not a date anybody wrote down'),
      findsOneWidget,
    );
  });

  testWidgets('a paper already out of date is flagged before you set off', (
    tester,
  ) async {
    // The case worth catching: about to drive a long way on an expired
    // registration. Kept under its own heading, apart from the forecasts,
    // because this is a date somebody wrote down rather than a projection.
    await pumpPrep(
      tester,
      documents: [
        VehicleDocument(
          id: 'd1',
          vehicleId: 'v1',
          type: DocumentType.registration,
          expiresOn: DateTime.now().toUtc().subtract(const Duration(days: 1)),
          createdBy: 'u1',
        ),
      ],
    );

    await checkFor(tester, '100');

    expect(find.text('RUNS OUT WHILE YOU ARE AWAY'), findsOneWidget);
  });

  testWidgets('with no return date, only the departure day is checked', (
    tester,
  ) async {
    // A limitation worth stating rather than papering over: without knowing
    // how long the car is away, the honest question is "is this valid when you
    // set off". Guessing a duration from the distance would invent a fact.
    await pumpPrep(
      tester,
      documents: [
        VehicleDocument(
          id: 'd1',
          vehicleId: 'v1',
          type: DocumentType.registration,
          expiresOn: DateTime.now().toUtc().add(const Duration(days: 3)),
          createdBy: 'u1',
        ),
      ],
    );

    await checkFor(tester, '100');

    expect(find.text('RUNS OUT WHILE YOU ARE AWAY'), findsNothing);
    expect(
      find.text('Nothing in your records falls due over this journey.'),
      findsOneWidget,
    );
  });

  testWidgets('without an odometer it says so rather than showing nothing', (
    tester,
  ) async {
    // An empty result would read as "nothing is due", which is a different
    // claim from "I could not check".
    await pumpPrep(
      tester,
      odometer: null,
      projections: [due(dueOdometerKm: 142500)],
    );

    await checkFor(tester, '1500');

    expect(find.textContaining('No recent odometer reading'), findsOneWidget);
  });

  testWidgets('your own items persist on the device', (tester) async {
    await pumpPrep(tester);

    await tester.enterText(
      find.byKey(const Key('prep-new-item')),
      'Take the roof box down',
    );
    await tester.tap(find.byKey(const Key('prep-add-item')));
    await tester.pumpAndSettle();

    expect(find.text('Take the roof box down'), findsOneWidget);
    expect(
      SharedPreferences.getInstance().then(
        (p) => p.getStringList('trip_checklist_v1'),
      ),
      completion(contains('Take the roof box down')),
    );
  });

  testWidgets('an empty item is not added', (tester) async {
    await pumpPrep(tester);

    await tester.enterText(find.byKey(const Key('prep-new-item')), '   ');
    await tester.tap(find.byKey(const Key('prep-add-item')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('prep-item-0')), findsNothing);
  });
}
