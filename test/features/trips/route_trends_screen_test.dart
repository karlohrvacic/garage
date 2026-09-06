import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/domain/entities/trip_route.dart';
import 'package:garage/features/trips/providers/fleet_trip_providers.dart';
import 'package:garage/features/trips/providers/route_providers.dart';
import 'package:garage/features/trips/screens/route_trends_screen.dart';
import 'package:garage/features/trips/widgets/route_trend_chart.dart';

import '../../support/fake_repositories.dart';
import '../../support/pump_screen.dart';

const commute = TripRoute(id: 'r1', householdId: 'h1', name: 'Home → Work');

TripEntry drive({
  required DateTime date,
  required int? minutes,
  String? routeId = 'r1',
  bool comparable = true,
  String? driver,
  DateTime? startedAt,
}) {
  return TripEntry(
    id: 't${date.millisecondsSinceEpoch}-$minutes',
    vehicleId: 'v1',
    date: date,
    distanceKm: 22,
    purpose: TripPurpose.private,
    createdBy: 'u1',
    minutes: minutes,
    driver: driver,
    routeId: routeId,
    comparable: comparable,
    startedAt: startedAt,
    createdAt: date,
  );
}

/// Five journeys a quarter, so no bucket is drawn as an indication.
List<TripEntry> quarter(DateTime day, int minutes, {String? driver}) {
  return [
    for (var i = 0; i < 5; i++)
      drive(
        date: day.add(Duration(days: i * 7)),
        minutes: minutes + i,
        driver: driver,
        startedAt: DateTime(day.year, day.month, day.day + i * 7, 7, 30),
      ),
  ];
}

Future<void> pumpTrends(
  WidgetTester tester, {
  List<TripRoute> routes = const [commute],
  List<TripEntry> trips = const [],
  Locale? locale,
  double textScale = 1,
  Size surface = const Size(500, 2000),
}) async {
  await pumpScreen(
    tester,
    const RouteTrendsScreen(),
    initialLocation: '/routes',
    locale: locale,
    textScale: textScale,
    surface: surface,
    overrides: [
      routeRepositoryProvider.overrideWithValue(
        FakeRouteRepository(routes: [...routes]),
      ),
      allTripsProvider.overrideWith((ref) async => trips),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a garage with no routes says how one gets named', (
    tester,
  ) async {
    await pumpTrends(tester, routes: const []);

    expect(
      find.textContaining('Name one when you start a drive'),
      findsOneWidget,
    );
  });

  testWidgets('a route nobody has timed says so rather than drawing nothing', (
    tester,
  ) async {
    // Trips typed in afterwards carry no minutes, and a blank chart would
    // read as "no journeys" rather than as "no clock".
    await pumpTrends(
      tester,
      trips: [drive(date: DateTime.utc(2026, 3, 2), minutes: null)],
    );

    expect(find.byKey(const Key('route-trend-nothing')), findsOneWidget);
  });

  testWidgets('the typical duration and the spread are both shown', (
    tester,
  ) async {
    await pumpTrends(tester, trips: quarter(DateTime.utc(2026, 1, 5), 30));

    expect(find.byKey(const Key('route-trend-typical')), findsOneWidget);
    expect(find.text('Usually 32 min'), findsOneWidget);
    expect(find.textContaining('Middle half'), findsOneWidget);
    expect(find.text('5 journeys'), findsOneWidget);
  });

  testWidgets('a commute that got slower says by how much, against when', (
    tester,
  ) async {
    await pumpTrends(
      tester,
      trips: [
        ...quarter(DateTime.utc(2026, 1, 5), 30),
        ...quarter(DateTime.utc(2026, 4, 6), 40),
      ],
    );

    expect(find.text('10 min slower than 2026 Q1'), findsOneWidget);
    expect(find.byType(RouteTrendChart), findsOneWidget);
  });

  testWidgets('a comparison resting on two journeys says it is thin', (
    tester,
  ) async {
    await pumpTrends(
      tester,
      trips: [
        drive(date: DateTime.utc(2026, 1, 5), minutes: 30),
        drive(date: DateTime.utc(2026, 4, 6), minutes: 45),
      ],
    );

    expect(find.byKey(const Key('route-trend-change')), findsOneWidget);
    expect(find.byKey(const Key('route-trend-sparse')), findsOneWidget);
  });

  testWidgets('journeys left out as unusual are counted, not hidden', (
    tester,
  ) async {
    await pumpTrends(
      tester,
      trips: [
        ...quarter(DateTime.utc(2026, 1, 5), 30),
        drive(date: DateTime.utc(2026, 1, 20), minutes: 95, comparable: false),
      ],
    );

    expect(find.text('1 journey left out as not a normal run'), findsOneWidget);
    expect(
      find.text('5 journeys'),
      findsOneWidget,
      reason: 'an unusual run is drawn apart, not counted in the sample',
    );
  });

  testWidgets('the screen never claims to know why a journey got slower', (
    tester,
  ) async {
    await pumpTrends(tester, trips: quarter(DateTime.utc(2026, 1, 5), 30));

    expect(
      find.textContaining('reports what your records say, not why'),
      findsOneWidget,
    );
  });

  testWidgets('a departure filter narrows the sample and says what it lost', (
    tester,
  ) async {
    await pumpTrends(
      tester,
      trips: [
        ...quarter(DateTime.utc(2026, 1, 5), 30),
        // Typed in afterwards: no start time, so no window can place it.
        drive(date: DateTime.utc(2026, 1, 9), minutes: 60),
      ],
    );

    await tester.tap(find.byKey(const Key('route-trend-departure')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morning').last);
    await tester.pumpAndSettle();

    expect(find.text('5 journeys'), findsOneWidget);
    expect(
      find.textContaining('no start time'),
      findsOneWidget,
      reason: 'a sample that shrank silently is a sample nobody can trust',
    );
  });

  testWidgets('one driver on a route is not offered a driver filter', (
    tester,
  ) async {
    await pumpTrends(
      tester,
      trips: quarter(DateTime.utc(2026, 1, 5), 30, driver: 'Karlo'),
    );

    expect(find.byKey(const Key('route-trend-driver')), findsNothing);
  });

  testWidgets('two drivers on a route can be told apart', (tester) async {
    await pumpTrends(
      tester,
      trips: [
        ...quarter(DateTime.utc(2026, 1, 5), 30, driver: 'Karlo'),
        ...quarter(DateTime.utc(2026, 4, 6), 50, driver: 'Ana'),
      ],
    );

    expect(find.byKey(const Key('route-trend-driver')), findsOneWidget);
  });

  testWidgets('filtering to one driver drops the other\'s journeys', (
    tester,
  ) async {
    await pumpTrends(
      tester,
      trips: [
        ...quarter(DateTime.utc(2026, 1, 5), 30, driver: 'Karlo'),
        ...quarter(DateTime.utc(2026, 4, 6), 50, driver: 'Ana'),
      ],
    );

    await tester.tap(find.byKey(const Key('route-trend-driver')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana').last);
    await tester.pumpAndSettle();

    expect(find.text('5 journeys'), findsOneWidget);
    expect(find.text('Usually 52 min'), findsOneWidget);
  });

  testWidgets('and each one is named, so it can be checked', (tester) async {
    // "1 journey left out" invites the question which one. Answering it is
    // what stops the exclusion from being a place data quietly goes.
    await pumpTrends(
      tester,
      trips: [
        ...quarter(DateTime.utc(2026, 1, 5), 30),
        drive(date: DateTime.utc(2026, 1, 20), minutes: 95, comparable: false),
      ],
    );

    expect(find.byKey(const Key('route-trend-excluded-list')), findsOneWidget);
    expect(find.textContaining('95 min'), findsOneWidget);
  });

  testWidgets('a long list of them is summarised rather than unrolled', (
    tester,
  ) async {
    await pumpTrends(
      tester,
      trips: [
        ...quarter(DateTime.utc(2026, 1, 5), 30),
        for (var i = 0; i < 8; i++)
          drive(
            date: DateTime.utc(2026, 2, i + 1),
            minutes: 90 + i,
            comparable: false,
          ),
      ],
    );

    expect(find.textContaining('3 more'), findsOneWidget);
  });

  testWidgets('a single journey is not given a spread it does not have', (
    tester,
  ) async {
    // Seen on a device on the very first drive: "Middle half 1–1 min", which
    // reads as a rendering fault rather than as a sample of one.
    await pumpTrends(
      tester,
      trips: [drive(date: DateTime.utc(2026, 7, 1), minutes: 22)],
    );

    expect(find.text('Usually 22 min'), findsOneWidget);
    expect(find.textContaining('Middle half'), findsNothing);
  });

  testWidgets('a real spread is still shown', (tester) async {
    await pumpTrends(
      tester,
      trips: [
        drive(date: DateTime.utc(2026, 7, 1), minutes: 20),
        drive(date: DateTime.utc(2026, 7, 8), minutes: 40),
      ],
    );

    expect(find.textContaining('Middle half'), findsOneWidget);
  });

  group('in Croatian, and at the font sizes phones ship with', () {
    // The Croatian strings on this screen are the longest in the app — "Ovo
    // govori što piše u vašim zapisima, ne i zašto" — and nothing had ever
    // rendered them. A layout that overflows throws, so this is the cheap
    // half of a device pass and it runs forever.
    final journeys = [
      ...quarter(DateTime.utc(2026, 1, 5), 30, driver: 'Karlo'),
      ...quarter(DateTime.utc(2026, 4, 6), 45, driver: 'Ana'),
      drive(date: DateTime.utc(2026, 2, 2), minutes: 95, comparable: false),
    ];

    testWidgets('the trend lays out', (tester) async {
      await pumpTrends(tester, trips: journeys, locale: const Locale('hr'));

      expect(find.textContaining('Obično'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and on a narrow phone at 1.5x text', (tester) async {
      // 320 px is the narrowest Android ships, and 1.5 is an ordinary
      // accessibility setting rather than an extreme one.
      await pumpTrends(
        tester,
        trips: journeys,
        locale: const Locale('hr'),
        textScale: 1.5,
        surface: const Size(320, 2400),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('the empty state fits too', (tester) async {
      await pumpTrends(
        tester,
        routes: const [],
        locale: const Locale('hr'),
        textScale: 1.5,
        surface: const Size(320, 2400),
      );

      expect(find.textContaining('Još nema ruta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
