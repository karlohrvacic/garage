import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/trip_draft.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/features/trips/data/trip_repository.dart';
import 'package:garage/features/trips/providers/fleet_trip_providers.dart';
import 'package:garage/domain/entities/trip_route.dart';
import 'package:garage/features/trips/providers/route_providers.dart';
import 'package:garage/features/trips/providers/trip_providers.dart';
import 'package:garage/features/trips/screens/trip_log_screen.dart';
import 'package:garage/features/trips/widgets/drive_card.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import '../../support/fake_repositories.dart';
import '../../support/pump_screen.dart';

/// Records what the screen asked of it, so a test can assert on the write
/// rather than on a rendering of the write.
class RecordingTripRepository implements TripRepository {
  RecordingTripRepository({this.draft});

  TripDraft? draft;
  final List<String> calls = [];
  TripDraft? started;
  TripEntry? finished;
  Object? failStartWith;

  /// Holds `openDraft` in flight, for the test about what is shown before the
  /// answer is known.
  bool holdOpenDraft = false;

  @override
  Future<List<TripEntry>> forVehicle(String vehicleId) async => const [];

  @override
  Future<void> add(TripEntry entry) async => calls.add('add');

  @override
  Future<void> update(TripEntry entry) async {
    calls.add('update:${entry.id}');
    finished = entry;
  }

  @override
  Future<void> delete(String id) async => calls.add('delete:$id');

  @override
  Future<TripDraft?> openDraft(String vehicleId) {
    calls.add('openDraft:$vehicleId');
    if (holdOpenDraft) {
      return Completer<TripDraft?>().future;
    }
    return Future.value(draft);
  }

  @override
  Future<void> startDraft(TripDraft draft) async {
    calls.add('startDraft:${draft.vehicleId}');
    if (failStartWith != null) {
      throw failStartWith!;
    }
    started = draft;
  }

  @override
  Future<void> discardDraft(String id) async => calls.add('discardDraft:$id');
}

TripDraft openDrive({
  DateTime? startedAt,
  int? startOdometerKm = 142300,
  String? routeId,
}) {
  return TripDraft(
    id: 't-open',
    vehicleId: 'v1',
    startedAt:
        startedAt ??
        DateTime.now().toUtc().subtract(const Duration(minutes: 55)),
    createdBy: 'u1',
    startOdometerKm: startOdometerKm,
    routeId: routeId,
  );
}

Future<void> pumpDriveScreen(
  WidgetTester tester,
  RecordingTripRepository repository, {
  FakeRouteRepository? routes,
  Locale? locale,
  double textScale = 1,
  Size surface = const Size(500, 1600),
}) async {
  await pumpScreen(
    tester,
    const TripLogScreen(),
    initialLocation: '/trips',
    locale: locale,
    textScale: textScale,
    surface: surface,
    vehicles: [testVehicle('v1', nickname: 'Golf')],
    overrides: [
      vehiclesProvider.overrideWith(
        (ref) async => [testVehicle('v1', nickname: 'Golf')],
      ),
      allTripsProvider.overrideWith((ref) async => const []),
      tripRepositoryProvider.overrideWithValue(repository),
      routeRepositoryProvider.overrideWithValue(
        routes ?? FakeRouteRepository(),
      ),
    ],
  );
  await tester.pumpAndSettle();
  // The screen opens on "all vehicles"; a drive belongs to one car.
  await tester.tap(find.byType(DropdownButton<String?>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Golf').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with no drive open, the car offers to start one', (
    tester,
  ) async {
    await pumpDriveScreen(tester, RecordingTripRepository());

    expect(find.byKey(const Key('drive-start')), findsOneWidget);
    expect(find.byKey(const Key('drive-in-progress')), findsNothing);
  });

  testWidgets('the offer survives a garage with nothing logged yet', (
    tester,
  ) async {
    // The empty state used to replace the whole body, so the first drive a
    // person ever took was the one they could not start.
    await pumpDriveScreen(tester, RecordingTripRepository());

    expect(find.text('No trips logged yet.'), findsOneWidget);
    expect(find.byKey(const Key('drive-start')), findsOneWidget);
  });

  testWidgets('starting a drive stamps the clock and sends the odometer', (
    tester,
  ) async {
    final repository = RecordingTripRepository();
    final before = DateTime.now().toUtc();
    await pumpDriveScreen(tester, repository);

    await tester.tap(find.byKey(const Key('drive-start')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('drive-start-odometer')),
      '142300',
    );
    await tester.tap(find.text('Start a drive').last);
    await tester.pumpAndSettle();

    expect(repository.started, isNotNull);
    expect(repository.started!.startOdometerKm, 142300);
    expect(repository.started!.vehicleId, 'v1');
    expect(
      repository.started!.startedAt.isBefore(before),
      isFalse,
      reason:
          'the start time is read when the person says they are setting off',
    );
  });

  testWidgets('a drive can be started without seeing the odometer', (
    tester,
  ) async {
    final repository = RecordingTripRepository();
    await pumpDriveScreen(tester, repository);

    await tester.tap(find.byKey(const Key('drive-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start a drive').last);
    await tester.pumpAndSettle();

    expect(repository.started, isNotNull);
    expect(repository.started!.startOdometerKm, isNull);
  });

  testWidgets('an open drive says when it set off and how long it has run', (
    tester,
  ) async {
    await pumpDriveScreen(tester, RecordingTripRepository(draft: openDrive()));

    expect(find.byKey(const Key('drive-in-progress')), findsOneWidget);
    expect(find.byKey(const Key('drive-start')), findsNothing);
    expect(find.textContaining('55 min'), findsOneWidget);
  });

  testWidgets('an hour reads as an hour, not as sixty-five minutes', (
    tester,
  ) async {
    await pumpDriveScreen(
      tester,
      RecordingTripRepository(
        draft: openDrive(
          startedAt: DateTime.now().toUtc().subtract(
            const Duration(hours: 1, minutes: 5),
          ),
        ),
      ),
    );

    expect(find.textContaining('1 h 05 min'), findsOneWidget);
  });

  testWidgets('finishing writes the journey against the same row', (
    tester,
  ) async {
    final repository = RecordingTripRepository(draft: openDrive());
    await pumpDriveScreen(tester, repository);

    await tester.tap(find.byKey(const Key('drive-finish')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('drive-finish-odometer')),
      '142343',
    );
    await tester.tap(find.text('Finish drive').last);
    await tester.pumpAndSettle();

    expect(repository.finished, isNotNull);
    expect(repository.finished!.id, 't-open');
    expect(repository.finished!.distanceKm, 43);
    expect(repository.finished!.endOdometerKm, 142343);
    expect(
      repository.calls,
      contains('update:t-open'),
      reason: 'finishing updates the drive rather than inserting a second row',
    );
  });

  testWidgets('a finish with nothing to measure is refused, in the form', (
    tester,
  ) async {
    final repository = RecordingTripRepository(
      draft: openDrive(startOdometerKm: null),
    );
    await pumpDriveScreen(tester, repository);

    await tester.tap(find.byKey(const Key('drive-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish drive').last);
    await tester.pumpAndSettle();

    expect(find.text('Enter the odometer now, or a distance.'), findsOneWidget);
    expect(repository.finished, isNull);
  });

  testWidgets('an odometer that went backwards is refused, in the form', (
    tester,
  ) async {
    final repository = RecordingTripRepository(draft: openDrive());
    await pumpDriveScreen(tester, repository);

    await tester.tap(find.byKey(const Key('drive-finish')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('drive-finish-odometer')),
      '142299',
    );
    await tester.tap(find.text('Finish drive').last);
    await tester.pumpAndSettle();

    expect(
      find.text('The end reading cannot be lower than the start.'),
      findsOneWidget,
    );
    expect(repository.finished, isNull);
  });

  testWidgets('a drive with no starting reading finishes on a distance', (
    tester,
  ) async {
    final repository = RecordingTripRepository(
      draft: openDrive(startOdometerKm: null),
    );
    await pumpDriveScreen(tester, repository);

    await tester.tap(find.byKey(const Key('drive-finish')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('drive-finish-distance')),
      '12,5',
    );
    await tester.tap(find.text('Finish drive').last);
    await tester.pumpAndSettle();

    expect(repository.finished!.distanceKm, 12.5);
  });

  testWidgets('discarding asks first, and then logs nothing', (tester) async {
    final repository = RecordingTripRepository(draft: openDrive());
    await pumpDriveScreen(tester, repository);

    await tester.tap(find.byKey(const Key('drive-discard')));
    await tester.pumpAndSettle();
    expect(
      find.text('Discard this drive? Nothing will be logged for it.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Discard').last);
    await tester.pumpAndSettle();

    expect(repository.calls, contains('discardDraft:t-open'));
    expect(repository.finished, isNull);
  });

  testWidgets('backing out of the discard keeps the drive', (tester) async {
    final repository = RecordingTripRepository(draft: openDrive());
    await pumpDriveScreen(tester, repository);

    await tester.tap(find.byKey(const Key('drive-discard')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.calls.where((it) => it.startsWith('discard')), isEmpty);
    expect(find.byKey(const Key('drive-in-progress')), findsOneWidget);
  });

  testWidgets('nothing is offered until the answer is known', (tester) async {
    // A "Start a drive" button that becomes an in-progress card a moment later
    // invites a tap that opens a second drive on a car already out.
    final repository = RecordingTripRepository()..holdOpenDraft = true;
    await pumpDriveScreen(tester, repository);

    expect(find.byType(DriveCard), findsOneWidget);
    expect(find.byKey(const Key('drive-start')), findsNothing);
    expect(find.byKey(const Key('drive-in-progress')), findsNothing);
  });

  testWidgets('a drive can be filed under a route somebody already named', (
    tester,
  ) async {
    final repository = RecordingTripRepository();
    final routes = FakeRouteRepository(
      routes: [
        const TripRoute(id: 'r1', householdId: 'h1', name: 'Home → Work'),
      ],
    );
    await pumpDriveScreen(tester, repository, routes: routes);

    await tester.tap(find.byKey(const Key('drive-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drive-start-route')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home → Work').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start a drive').last);
    await tester.pumpAndSettle();

    expect(repository.started!.routeId, 'r1');
    expect(
      routes.calls.where((call) => call.startsWith('add:')),
      isEmpty,
      reason: 'picking an existing route names nothing new',
    );
  });

  testWidgets('naming a route on the way out creates it and files the drive', (
    tester,
  ) async {
    final repository = RecordingTripRepository();
    final routes = FakeRouteRepository();
    await pumpDriveScreen(tester, repository, routes: routes);

    await tester.tap(find.byKey(const Key('drive-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drive-start-route')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New route…').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('drive-start-route-name')),
      'Home → Work',
    );
    await tester.tap(find.text('Start a drive').last);
    await tester.pumpAndSettle();

    expect(routes.calls, contains('add:Home → Work'));
    expect(repository.started!.routeId, 'r1');
  });

  testWidgets('a drive nobody filed anywhere still starts', (tester) async {
    final repository = RecordingTripRepository();
    await pumpDriveScreen(tester, repository);

    await tester.tap(find.byKey(const Key('drive-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start a drive').last);
    await tester.pumpAndSettle();

    expect(repository.started, isNotNull);
    expect(repository.started!.routeId, isNull);
  });

  testWidgets('a route that could not be saved does not start the drive', (
    tester,
  ) async {
    // Starting anyway would file the journey under nothing, and the person
    // would have no way of telling which of the two happened.
    final repository = RecordingTripRepository();
    final routes = FakeRouteRepository()
      ..conflictsWith = null
      ..failAdd = true;
    await pumpDriveScreen(tester, repository, routes: routes);

    await tester.tap(find.byKey(const Key('drive-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drive-start-route')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New route…').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('drive-start-route-name')),
      'Home → Work',
    );
    await tester.tap(find.text('Start a drive').last);
    await tester.pumpAndSettle();

    expect(repository.started, isNull);
    expect(
      find.text('The route could not be saved, so the drive was not started.'),
      findsOneWidget,
    );
  });

  testWidgets('a drive on a route can be marked as not a normal run', (
    tester,
  ) async {
    final repository = RecordingTripRepository(draft: openDrive(routeId: 'r1'));
    await pumpDriveScreen(tester, repository);

    await tester.tap(find.byKey(const Key('drive-finish')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('drive-finish-odometer')),
      '142343',
    );
    await tester.tap(find.byKey(const Key('drive-finish-not-normal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish drive').last);
    await tester.pumpAndSettle();

    expect(repository.finished!.comparable, isFalse);
    expect(
      repository.finished!.routeId,
      'r1',
      reason: 'an unusual run stays on the route; it is only left out of it',
    );
  });

  testWidgets('a drive on no route is never asked whether it was normal', (
    tester,
  ) async {
    // The switch would have no consequence, and a decision asked for nothing
    // is a decision worth not asking for.
    await pumpDriveScreen(tester, RecordingTripRepository(draft: openDrive()));

    await tester.tap(find.byKey(const Key('drive-finish')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('drive-finish-not-normal')), findsNothing);
  });

  group('in Croatian on a narrow phone', () {
    // The finish sheet carries the longest new sentence in the app —
    // "Zaobilaznica, usputno obavljanje, zatvorena cesta..." — under a switch,
    // and nothing had rendered it. An overflow throws, so the assertion is
    // simply that nothing did.
    testWidgets('the start sheet with a route picker lays out', (tester) async {
      await pumpDriveScreen(
        tester,
        RecordingTripRepository(),
        routes: FakeRouteRepository(
          routes: [
            const TripRoute(
              id: 'r1',
              householdId: 'h1',
              name: 'Doma → Posao svaki radni dan',
            ),
          ],
        ),
        locale: const Locale('hr'),
        textScale: 1.5,
        surface: const Size(320, 2000),
      );

      await tester.tap(find.byKey(const Key('drive-start')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the finish sheet with the unusual-run switch lays out', (
      tester,
    ) async {
      await pumpDriveScreen(
        tester,
        RecordingTripRepository(draft: openDrive(routeId: 'r1')),
        locale: const Locale('hr'),
        textScale: 1.5,
        surface: const Size(320, 2000),
      );

      await tester.tap(find.byKey(const Key('drive-finish')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('drive-finish-not-normal')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
