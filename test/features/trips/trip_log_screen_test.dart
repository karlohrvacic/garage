import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/trips/providers/fleet_trip_providers.dart';
import 'package:garage/features/trips/providers/trip_providers.dart';
import 'package:garage/features/trips/screens/trip_log_screen.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import '../../support/pump_screen.dart';

/// The fleet as the test can change it mid-session: a car can be transferred
/// away or deleted by somebody else while this screen is open.
class _Fleet extends Notifier<List<Vehicle>> {
  @override
  List<Vehicle> build() => [
    testVehicle('v1', nickname: 'Golf'),
    testVehicle('v2', nickname: 'Panda'),
  ];

  void keepOnly(List<Vehicle> vehicles) => state = vehicles;
}

final _fleet = NotifierProvider<_Fleet, List<Vehicle>>(_Fleet.new);

TripEntry trip(
  String id, {
  String vehicleId = 'v1',
  double distanceKm = 120,
  TripPurpose purpose = TripPurpose.business,
  int? minutes,
  String? title,
}) {
  return TripEntry(
    id: id,
    vehicleId: vehicleId,
    date: DateTime.utc(2026, 5, 4),
    distanceKm: distanceKm,
    purpose: purpose,
    createdBy: 'u1',
    minutes: minutes,
    title: title,
  );
}

Future<void> pumpTrips(WidgetTester tester, List<TripEntry> trips) async {
  await pumpScreen(
    tester,
    const TripLogScreen(),
    initialLocation: '/trips',
    surface: const Size(500, 1400),
    overrides: [
      vehiclesProvider.overrideWith((ref) async => ref.watch(_fleet)),
      allVehiclesProvider.overrideWith((ref) async => ref.watch(_fleet)),
      allTripsProvider.overrideWith((ref) async => trips),
      for (final id in ['v1', 'v2'])
        tripEntriesProvider(id).overrideWith(
          (ref) async => [
            for (final t in trips)
              if (t.vehicleId == id) t,
          ],
        ),
    ],
  );
  await tester.pumpAndSettle();
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(TripLogScreen)));

void main() {
  testWidgets('the whole fleet adds up, split by what it was for', (
    tester,
  ) async {
    await pumpTrips(tester, [
      trip('t1', distanceKm: 120, minutes: 90),
      trip('t2', vehicleId: 'v2', distanceKm: 30, purpose: TripPurpose.private),
    ]);

    expect(find.text('2'), findsWidgets);
    expect(find.text('150 km'), findsOneWidget);
    expect(find.text('120 km'), findsWidgets);
    expect(find.text('30 km'), findsWidgets);
    // 120 km in 90 minutes, over the timed trip alone.
    expect(find.text('80 km/h'), findsOneWidget);
  });

  testWidgets('an untimed trip leaves the speed unsaid rather than wrong', (
    tester,
  ) async {
    await pumpTrips(tester, [trip('t1', distanceKm: 120)]);

    expect(find.text('—'), findsWidgets);
  });

  testWidgets('picking one car narrows the log to it', (tester) async {
    await pumpTrips(tester, [
      trip('t1', title: 'Zagreb run'),
      trip('t2', vehicleId: 'v2', title: 'School run'),
    ]);

    await tester.tap(find.text('All vehicles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panda').last);
    await tester.pumpAndSettle();

    expect(find.text('School run'), findsOneWidget);
    expect(find.text('Zagreb run'), findsNothing);
  });

  testWidgets('the car you were looking at going away does not break it', (
    tester,
  ) async {
    // Somebody else transfers or deletes the car while this screen is open.
    // A dropdown holding a value its items no longer offer throws.
    await pumpTrips(tester, [trip('t2', vehicleId: 'v2', title: 'School run')]);

    await tester.tap(find.text('All vehicles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panda').last);
    await tester.pumpAndSettle();

    containerOf(
      tester,
    ).read(_fleet.notifier).keepOnly([testVehicle('v1', nickname: 'Golf')]);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
