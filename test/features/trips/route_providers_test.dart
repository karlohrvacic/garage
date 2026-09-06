import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/domain/entities/trip_route.dart';
import 'package:garage/domain/trips/route_trend.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/trips/providers/fleet_trip_providers.dart';
import 'package:garage/features/trips/providers/route_providers.dart';
import 'package:garage/features/trips/providers/trip_providers.dart';

import '../../support/fake_repositories.dart';

TripEntry trip({
  String? routeId = 'r1',
  int? minutes = 40,
  String? driver,
  bool comparable = true,
  DateTime? date,
}) {
  return TripEntry(
    id: 't${DateTime.now().microsecondsSinceEpoch}',
    vehicleId: 'v1',
    date: date ?? DateTime.utc(2026, 3, 2),
    distanceKm: 22,
    purpose: TripPurpose.private,
    createdBy: 'u1',
    minutes: minutes,
    driver: driver,
    routeId: routeId,
    comparable: comparable,
    createdAt: DateTime.utc(2026, 3, 2),
  );
}

ProviderContainer containerWith(
  FakeRouteRepository repository, {
  List<TripEntry> trips = const [],
  Household? household = const Household(id: 'h1', name: 'Test'),
}) {
  final container = ProviderContainer(
    overrides: [
      routeRepositoryProvider.overrideWithValue(repository),
      currentHouseholdProvider.overrideWith((ref) async => household),
      allTripsProvider.overrideWith((ref) async => trips),
      tripEntriesProvider('v1').overrideWith((ref) async => trips),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('naming a route', () {
    test('a name nobody has used yet is created', () async {
      final repository = FakeRouteRepository();
      final container = containerWith(repository);

      final route = await container
          .read(routeControllerProvider.notifier)
          .ensure('Home → Work');

      expect(route?.name, 'Home → Work');
      expect(repository.calls, contains('add:Home → Work'));
    });

    test('the same name in another case reuses the route, not a new one', () {
      // The whole point of routes. A second "home → work" would split the
      // history the feature exists to join up — and the unique index would
      // refuse it anyway.
      final repository = FakeRouteRepository(
        routes: [
          const TripRoute(id: 'r1', householdId: 'h1', name: 'Home → Work'),
        ],
      );
      final container = containerWith(repository);

      return expectLater(
        container
            .read(routeControllerProvider.notifier)
            .ensure('  home → WORK '),
        completion(
          isA<TripRoute>()
              .having((route) => route.id, 'id', 'r1')
              .having((route) => route.name, 'name', 'Home → Work'),
        ),
      ).then((_) {
        expect(
          repository.calls.where((call) => call.startsWith('add:')),
          isEmpty,
        );
      });
    });

    test(
      'losing the race to another phone yields that phone\'s route',
      () async {
        final repository = FakeRouteRepository()
          ..conflictsWith = const TripRoute(
            id: 'r-theirs',
            householdId: 'h1',
            name: 'Home → Work',
          );
        final container = containerWith(repository);

        final route = await container
            .read(routeControllerProvider.notifier)
            .ensure('Home → Work');

        expect(
          route?.id,
          'r-theirs',
          reason: 'a route that already exists is an answer, not a failure',
        );
      },
    );

    test('an empty name names nothing', () async {
      final repository = FakeRouteRepository();
      final container = containerWith(repository);

      expect(
        await container.read(routeControllerProvider.notifier).ensure('   '),
        isNull,
      );
      expect(repository.calls, isEmpty);
    });

    test('before a garage exists, nothing is written', () async {
      final repository = FakeRouteRepository();
      final container = containerWith(repository, household: null);

      expect(
        await container.read(routeControllerProvider.notifier).ensure('Work'),
        isNull,
      );
      expect(repository.calls, isEmpty);
    });
  });

  group('what a route knows', () {
    test('lists only the journeys filed under it, across every car', () async {
      final container = containerWith(
        FakeRouteRepository(),
        trips: [
          trip(),
          trip(routeId: 'r2'),
          trip(routeId: null),
        ],
      );

      final trips = await container.read(routeTripsProvider('r1').future);

      expect(trips, hasLength(1));
    });

    test('offers each driver once, and skips a blank name', () async {
      final container = containerWith(
        FakeRouteRepository(),
        trips: [
          trip(driver: 'Karlo'),
          trip(driver: 'Karlo'),
          trip(driver: ' '),
          trip(driver: 'Ana'),
          trip(),
        ],
      );

      expect(await container.read(routeDriversProvider('r1').future), [
        'Ana',
        'Karlo',
      ]);
    });

    test('the trend answers the question it was asked', () async {
      final container = containerWith(
        FakeRouteRepository(),
        trips: [
          trip(minutes: 30, date: DateTime.utc(2026, 3, 2)),
          trip(minutes: 90, comparable: false, date: DateTime.utc(2026, 3, 3)),
          trip(minutes: 40, date: DateTime.utc(2026, 6, 2)),
        ],
      );

      final trend = await container.read(
        routeTrendProvider(
          const RouteTrendQuery(routeId: 'r1', grouping: RouteGrouping.quarter),
        ).future,
      );

      expect(trend.sampleCount, 2);
      expect(trend.excluded, hasLength(1));
      expect(trend.changeInMinutes, 10);
    });

    test('a filter is part of the question, so it caches separately', () async {
      final container = containerWith(
        FakeRouteRepository(),
        trips: [
          trip(minutes: 30, driver: 'Karlo'),
          trip(minutes: 60, driver: 'Ana'),
        ],
      );

      final all = await container.read(
        routeTrendProvider(const RouteTrendQuery(routeId: 'r1')).future,
      );
      final hers = await container.read(
        routeTrendProvider(
          const RouteTrendQuery(routeId: 'r1', driver: 'Ana'),
        ).future,
      );

      expect(all.sampleCount, 2);
      expect(hers.sampleCount, 1);
      expect(hers.overallMedian, 60);
    });
  });

  group('the order a picker offers them in', () {
    final routes = [
      const TripRoute(id: 'r1', householdId: 'h1', name: 'Airport'),
      const TripRoute(id: 'r2', householdId: 'h1', name: 'Home → Work'),
      const TripRoute(id: 'r3', householdId: 'h1', name: 'School'),
    ];

    test('the one this car took last comes first', () async {
      // At the car, the route somebody wants is the one they drove yesterday,
      // not the one that starts with A.
      final container = containerWith(
        FakeRouteRepository(routes: [...routes]),
        trips: [
          trip(routeId: 'r3', date: DateTime.utc(2026, 3, 1)),
          trip(routeId: 'r2', date: DateTime.utc(2026, 6, 1)),
        ],
      );

      final offered = await container.read(
        routesForVehicleProvider('v1').future,
      );

      expect([for (final route in offered) route.id], ['r2', 'r3', 'r1']);
    });

    test('a route this car has never taken keeps its place by name', () async {
      final container = containerWith(
        FakeRouteRepository(routes: [...routes]),
        trips: [trip(routeId: 'r3', date: DateTime.utc(2026, 3, 1))],
      );

      final offered = await container.read(
        routesForVehicleProvider('v1').future,
      );

      expect([for (final route in offered) route.id], ['r3', 'r1', 'r2']);
    });

    test('with nothing driven yet they are simply alphabetical', () async {
      final container = containerWith(FakeRouteRepository(routes: [...routes]));

      final offered = await container.read(
        routesForVehicleProvider('v1').future,
      );

      expect([for (final route in offered) route.id], ['r1', 'r2', 'r3']);
    });
  });
}
