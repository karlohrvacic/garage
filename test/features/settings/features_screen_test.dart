import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/features/settings/screens/features_screen.dart';

import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import '../../support/pump_screen.dart';

Future<NavigationLog> pumpFeatures(WidgetTester tester) {
  return pumpScreen(
    tester,
    const FeaturesScreen(),
    initialLocation: '/tour',
    // Tall enough that every row is laid out: a list builds only what is in
    // view, and the point of the first test is that every row exists. Raised
    // when the tour learned routes, observations, the trip check and the
    // offline queue — four more rows is four more screens' worth of height.
    surface: const Size(420, 4200),
    extraRoutes: const {
      '/vehicles/new',
      '/household',
      '/trips',
      '/data',
      '/api',
    },
  );
}

void main() {
  // The getting-started card says how to add a car. Nothing said what the
  // app can do once one is there: someone who never tapped "More" had no way
  // to learn the planner, the stations or the calculator exist.
  testWidgets('every feature is named with what it is for', (tester) async {
    await pumpFeatures(tester);
    await tester.pumpAndSettle();

    for (final id in [
      '/vehicles/new',
      // The fuel log row: named for the log it opens, no longer keyed by the
      // dashboard it used to land on.
      'fuel',
      '/planner',
      '/timeline',
      '/stats',
      '/stations',
      '/trips',
      '/calculator',
      // The tyres row: named rather than keyed by the list it used to
      // land on.
      'tyres',
      '/household',
      'lend',
      '/data',
      '/api',
      'receipts',
      '/routes',
      'observations',
      'trip-prep',
      '/pending',
    ]) {
      expect(
        find.byKey(Key('feature-$id')),
        findsOneWidget,
        reason: '$id has no row',
      );
    }
    expect(find.text('Planner'), findsOneWidget);
    expect(find.textContaining('one visit'), findsOneWidget);
  });

  testWidgets('a row opens the thing it names', (tester) async {
    final log = await pumpFeatures(tester);
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('feature-/stations'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(log.visited, contains('/stations'));
  });

  testWidgets('reads naturally in Croatian too', (tester) async {
    await pumpScreen(
      tester,
      const FeaturesScreen(),
      initialLocation: '/tour',
      locale: const Locale('hr'),
      surface: const Size(420, 2800),
    );
    await tester.pumpAndSettle();

    expect(find.text('Što Garage može'), findsOneWidget);
    expect(find.text('Planer'), findsOneWidget);
  });

  testWidgets('with one car, the tyres row opens that car\'s tyres', (
    tester,
  ) async {
    // The screen's own subtitle promises where each thing lives, and this row
    // stopped two taps short: the vehicle list, then the car, then the row.
    final log = await pumpScreen(
      tester,
      const FeaturesScreen(),
      initialLocation: '/tour',
      extraRoutes: const {'/vehicles/v1/tyres'},
      overrides: [
        vehiclesProvider.overrideWith((ref) async => [testVehicle('v1')]),
      ],
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('feature-tyres'));
    await tester.scrollUntilVisible(row, 200);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(log.visited, contains('/vehicles/v1/tyres'));
  });

  testWidgets('with one car, the fuel log row opens that car\'s fuel log', (
    tester,
  ) async {
    // Named "Fuel log", it opened the dashboard: the one row on a tour that
    // promises "where each one lives" pointing somewhere else.
    final log = await pumpScreen(
      tester,
      const FeaturesScreen(),
      initialLocation: '/tour',
      extraRoutes: const {'/vehicles/v1/fuel'},
      overrides: [
        vehiclesProvider.overrideWith((ref) async => [testVehicle('v1')]),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('feature-fuel')));
    await tester.pumpAndSettle();

    expect(log.visited, contains('/vehicles/v1/fuel'));
  });

  testWidgets('with one car, the lending row opens that car\'s lending page', (
    tester,
  ) async {
    final log = await pumpScreen(
      tester,
      const FeaturesScreen(),
      initialLocation: '/tour',
      extraRoutes: const {'/vehicles/v1/lending'},
      overrides: [
        vehiclesProvider.overrideWith((ref) async => [testVehicle('v1')]),
      ],
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('feature-lend'));
    await tester.scrollUntilVisible(row, 200);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(log.visited, contains('/vehicles/v1/lending'));
  });
}
