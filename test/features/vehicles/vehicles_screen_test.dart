import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/adaptive.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/features/vehicles/screens/vehicles_screen.dart';

import 'vehicle_photo_repository_test.dart' show FakeVehiclePhotoRepository;

import '../../support/pump_screen.dart';

Future<NavigationLog> pumpVehicles(
  WidgetTester tester, {
  List<Vehicle> vehicles = const [],
  Size surface = const Size(400, 900),
}) {
  return pumpScreen(
    tester,
    const VehiclesScreen(),
    initialLocation: '/vehicles',
    surface: surface,
    extraRoutes: const {'/vehicles/new'},
    overrides: [
      vehiclePhotoRepositoryProvider.overrideWithValue(
        FakeVehiclePhotoRepository(),
      ),
      vehiclesProvider.overrideWith((ref) async => vehicles),
      allVehiclesProvider.overrideWith((ref) async => vehicles),
      for (final vehicle in vehicles)
        vehicleProvider(vehicle.id).overrideWith((ref) async => vehicle),
    ],
  );
}

void main() {
  testWidgets('an empty garage invites adding a vehicle', (tester) async {
    await pumpVehicles(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Add'), findsWidgets);
  });

  testWidgets('every vehicle in the household is listed', (tester) async {
    await pumpVehicles(
      tester,
      vehicles: [
        testVehicle('v1', nickname: 'Golf'),
        testVehicle('v2', nickname: 'Passat'),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Golf'), findsOneWidget);
    expect(find.text('Passat'), findsOneWidget);
  });

  testWidgets('searching narrows the list to matching names', (tester) async {
    await pumpVehicles(
      tester,
      vehicles: [
        testVehicle('v1', nickname: 'Golf'),
        testVehicle('v2', nickname: 'Passat'),
      ],
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'pass');
    await tester.pumpAndSettle();

    expect(find.text('Golf'), findsNothing);
    expect(find.text('Passat'), findsOneWidget);
  });

  testWidgets('the search is case-insensitive', (tester) async {
    await pumpVehicles(tester, vehicles: [testVehicle('v1', nickname: 'Golf')]);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'GOLF');
    await tester.pumpAndSettle();

    expect(find.text('Golf'), findsOneWidget);
  });

  testWidgets('the add button opens the new-vehicle screen', (tester) async {
    final log = await pumpVehicles(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(log.visited, contains('/vehicles/new'));
  });

  testWidgets('the vehicles tab is the selected one', (tester) async {
    await pumpVehicles(tester);
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));

    expect(bar.selectedIndex, 2);
  });

  testWidgets('a vehicle with a photo shows it in the list', (tester) async {
    await pumpVehicles(
      tester,
      vehicles: [
        Vehicle(
          id: 'v1',
          householdId: 'h1',
          nickname: 'Golf',
          fuelTypeKey: 'fuel_diesel',
          baselineOdometerKm: 50000,
          baselineDate: DateTime.utc(2026, 1, 1),
          photoUrl: 'h1/v1',
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('a vehicle without one falls back to an icon', (tester) async {
    await pumpVehicles(tester, vehicles: [testVehicle('v1', nickname: 'Golf')]);
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.directions_car_outlined), findsWidgets);
  });

  group('on a desktop window', () {
    // The card, not its nickname: two nicknames of different lengths say
    // nothing about where their cards were laid out.
    Finder card(String id) => find.byKey(Key('vehicle-$id'));

    Future<void> pumpTwo(WidgetTester tester, {Size? surface}) async {
      await pumpVehicles(
        tester,
        surface: surface ?? const Size(400, 900),
        vehicles: [
          testVehicle('v1', nickname: 'Golf'),
          testVehicle('v2', nickname: 'Passat'),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the garage uses the window rather than a reading column', (
      tester,
    ) async {
      await pumpTwo(tester, surface: const Size(1500, 1000));

      expect(
        tester.getSize(find.byType(ListView)).width,
        greaterThan(GarageBreakpoints.contentMaxWidth),
      );
    });

    testWidgets('vehicles pair up two to a row', (tester) async {
      await pumpTwo(tester, surface: const Size(1500, 1000));

      expect(
        tester.getTopLeft(card('v1')).dx,
        isNot(tester.getTopLeft(card('v2')).dx),
        reason:
            'a household of four cars is four short rows down a tall window, '
            'which is the phone list the desktop layout is meant to replace',
      );
    });

    testWidgets('a phone keeps one vehicle per row', (tester) async {
      await pumpTwo(tester);

      expect(
        tester.getTopLeft(card('v1')).dx,
        tester.getTopLeft(card('v2')).dx,
      );
    });
  });
}
