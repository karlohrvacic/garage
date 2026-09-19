import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/clock.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/errors/failure_log.dart';
import 'package:garage/features/company/providers/company_providers.dart';
import 'package:garage/features/vehicles/providers/guest_pass_providers.dart';
import 'package:garage/domain/entities/guest_pass.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/vehicle_assignment.dart';
import 'package:garage/core/widgets/adaptive.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/features/vehicles/screens/vehicles_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vehicle_photo_repository_test.dart' show FakeVehiclePhotoRepository;

import '../../support/pump_screen.dart';
import '../company/company_providers_test.dart' show RecordingCompanyRepository;

Future<NavigationLog> pumpVehicles(
  WidgetTester tester, {
  List<Vehicle> vehicles = const [],
  List<Vehicle> archived = const [],
  Size surface = const Size(400, 900),
  List<GuestPass> passes = const [],
  Locale? locale,
  double textScale = 1,
  Household? household = testHousehold,
}) {
  return pumpScreen(
    tester,
    const VehiclesScreen(),
    initialLocation: '/vehicles',
    surface: surface,
    locale: locale,
    textScale: textScale,
    household: household,
    extraRoutes: const {'/vehicles/new'},
    overrides: [
      garagePassesProvider.overrideWith((ref) async => passes),
      vehiclePhotoRepositoryProvider.overrideWithValue(
        FakeVehiclePhotoRepository(),
      ),
      vehiclesProvider.overrideWith((ref) async => vehicles),
      allVehiclesProvider.overrideWith((ref) async => vehicles),
      archivedVehiclesProvider.overrideWith((ref) async => archived),
      for (final vehicle in vehicles)
        vehicleProvider(vehicle.id).overrideWith((ref) async => vehicle),
    ],
  );
}

void main() {
  group('a car out on loan', () {
    // Only its own page said so; from the garage it looked like any other.
    final now = DateTime.now().toUtc();
    GuestPass pass({DateTime? expiresAt, DateTime? revokedAt}) => GuestPass(
      id: 'p1',
      vehicleId: 'v1',
      code: 'ABCD2345',
      createdBy: 'u1',
      createdAt: now.subtract(const Duration(days: 1)),
      expiresAt: expiresAt ?? DateTime.utc(now.year + 1, 10, 3),
      redeemedBy: 'g1',
      redeemedAt: now.subtract(const Duration(hours: 2)),
      revokedAt: revokedAt,
    );

    testWidgets('says so on its card, and until when', (tester) async {
      await pumpVehicles(
        tester,
        vehicles: [
          testVehicle('v1', nickname: 'Golf'),
          testVehicle('v2', nickname: 'Passat'),
        ],
        passes: [pass()],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('On loan until'), findsOneWidget);
      expect(find.textContaining('Oct 3'), findsOneWidget);
    });

    testWidgets('and not once the loan is over', (tester) async {
      await pumpVehicles(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        passes: [pass(revokedAt: now.subtract(const Duration(minutes: 5)))],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('On loan'), findsNothing);
    });

    testWidgets('in Croatian on a narrow phone at a large font', (
      tester,
    ) async {
      await pumpVehicles(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        passes: [pass()],
        surface: const Size(320, 700),
        locale: const Locale('hr'),
        textScale: 1.5,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

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

  testWidgets('the only car, archived, is still reachable', (tester) async {
    // "No vehicles yet" with no archived section made archiving the last
    // car a one-way trip.
    await pumpVehicles(
      tester,
      vehicles: const [],
      archived: [testVehicle('v1', nickname: 'Golf', archived: true)],
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Add your first vehicle to start logging'),
      findsOneWidget,
    );
    expect(find.text('Golf'), findsOneWidget);
  });

  testWidgets('a short list needs no search box', (tester) async {
    await pumpVehicles(tester, vehicles: [testVehicle('v1', nickname: 'Golf')]);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.text('Golf'), findsOneWidget);
  });

  testWidgets('searching narrows the list to matching names', (tester) async {
    await pumpVehicles(
      tester,
      vehicles: [
        testVehicle('v1', nickname: 'Golf'),
        testVehicle('v2', nickname: 'Passat'),
        testVehicle('v3', nickname: 'Astra'),
        testVehicle('v4', nickname: 'Clio'),
      ],
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'pass');
    await tester.pumpAndSettle();

    expect(find.text('Golf'), findsNothing);
    expect(find.text('Passat'), findsOneWidget);
  });

  testWidgets('the search is case-insensitive', (tester) async {
    await pumpVehicles(
      tester,
      vehicles: [
        testVehicle('v1', nickname: 'Golf'),
        testVehicle('v2', nickname: 'Passat'),
        testVehicle('v3', nickname: 'Astra'),
        testVehicle('v4', nickname: 'Clio'),
      ],
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'GOLF');
    await tester.pumpAndSettle();

    expect(find.text('Golf'), findsOneWidget);
  });

  testWidgets('the add button opens the new-vehicle screen', (tester) async {
    final log = await pumpVehicles(
      tester,
      vehicles: [testVehicle('v1', nickname: 'Golf')],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(log.visited, contains('/vehicles/new'));
  });

  testWidgets('an empty list offers one Add vehicle, not two', (tester) async {
    // The empty state's button and a floating one with the same label were
    // two of the same thing on one screen.
    final log = await pumpVehicles(tester);
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Add vehicle'));
    await tester.pumpAndSettle();
    expect(log.visited, contains('/vehicles/new'));
  });

  group('the free plan\'s five cars', () {
    // The insert policy refuses a sixth with a bare permission error
    // (migration 0080), which is not what a full garage needs to hear. The
    // screen asks first and says what to do about it.
    List<Vehicle> cars(int count) => [
      for (var i = 0; i < count; i++) testVehicle('v$i', nickname: 'Car $i'),
    ];

    testWidgets('a full free garage is told the cap instead of the form', (
      tester,
    ) async {
      final log = await pumpVehicles(tester, vehicles: cars(5));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(log.visited, isNot(contains('/vehicles/new')));
      expect(find.textContaining('five cars'), findsOneWidget);
    });

    testWidgets('a lapsed company garage is told the plan ended', (
      tester,
    ) async {
      final log = await pumpVehicles(
        tester,
        vehicles: cars(7),
        household: Household(
          id: 'h1',
          name: 'Prijevoz',
          plan: 'company',
          planUntil: DateTime.utc(2026, 9, 1),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(log.visited, isNot(contains('/vehicles/new')));
      expect(find.textContaining('company plan ended'), findsOneWidget);
    });

    testWidgets('on the plan the form opens whatever the count', (
      tester,
    ) async {
      final log = await pumpVehicles(
        tester,
        vehicles: cars(7),
        household: const Household(id: 'h1', name: 'Prijevoz', plan: 'company'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(log.visited, contains('/vehicles/new'));
    });

    testWidgets('a garage with room still opens the form', (tester) async {
      final log = await pumpVehicles(tester, vehicles: cars(4));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(log.visited, contains('/vehicles/new'));
    });
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

  group('a driver', () {
    const company = Household(id: 'h1', name: 'Prijevoz', plan: 'company');

    VehicleAssignment handover(String id, {String vehicleId = 'v1'}) =>
        VehicleAssignment(
          id: id,
          vehicleId: vehicleId,
          userId: 'u1',
          fromDate: DateTime.utc(2026, 9, 1),
        );

    Future<RecordingCompanyRepository> pumpMine(
      WidgetTester tester, {
      List<Vehicle> vehicles = const [],
      List<VehicleAssignment> own = const [],
      AppFailure? failWith,
      AppFailure? readFailsWith,
      bool noticeSeen = true,

      /// Something other than a bool under the key: a store this app did
      /// not write, which the read cannot make sense of.
      bool noticeUnreadable = false,
      Locale? locale,
      double textScale = 1,
      Size surface = const Size(400, 900),
    }) async {
      SharedPreferences.setMockInitialValues({
        'company.driver_notice.seen': noticeUnreadable ? 'yes' : noticeSeen,
      });
      final repository = RecordingCompanyRepository(
        own: own,
        failWith: failWith,
        readFailsWith: readFailsWith,
      );
      // The role is read off the startup fetch, so the screen is pumped past
      // it before anything is asserted: the first frame is a member's.
      await pumpScreen(
        tester,
        const VehiclesScreen(),
        initialLocation: '/vehicles',
        surface: surface,
        locale: locale,
        textScale: textScale,
        household: company,
        role: 'driver',
        vehicles: vehicles,
        overrides: [
          companyRepositoryProvider.overrideWithValue(repository),
          garagePassesProvider.overrideWith((ref) async => const []),
          vehiclePhotoRepositoryProvider.overrideWithValue(
            FakeVehiclePhotoRepository(),
          ),
          for (final vehicle in vehicles)
            currentOdometerProvider(
              vehicle.id,
            ).overrideWith((ref) async => 60000),
          // Pinned: the windows above are dated against this day.
          todayProvider.overrideWithValue(DateTime(2026, 9, 19)),
        ],
      );
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets('sees "My cars" and no way to add one', (tester) async {
      await pumpMine(tester, vehicles: [testVehicle('v1', nickname: 'Golf')]);

      expect(find.text('My cars'), findsOneWidget);
      // The tab below keeps its name; the page is what is theirs.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Vehicles'),
        ),
        findsNothing,
      );
      expect(find.text('Golf'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('with nothing today is told who hands a car over', (
      tester,
    ) async {
      await pumpMine(tester);

      expect(find.textContaining('No car is assigned'), findsOneWidget);
      expect(find.text('Add vehicle'), findsNothing);
    });

    testWidgets('is not shown the archived section', (tester) async {
      await pumpMine(
        tester,
        vehicles: [
          testVehicle('v1', nickname: 'Golf'),
          testVehicle('v2', nickname: 'Passat', archived: true),
        ],
      );

      expect(find.text('Golf'), findsOneWidget);
      expect(find.text('Passat'), findsNothing);
      expect(find.text('ARCHIVED'), findsNothing);
    });

    testWidgets('is told what the administrator sees, once', (tester) async {
      await pumpMine(tester, vehicles: [testVehicle('v1')], noticeSeen: false);

      expect(find.byKey(const Key('driver-notice')), findsOneWidget);
      await tester.tap(find.byKey(const Key('driver-notice-dismiss')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('driver-notice')), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'company.driver_notice.seen',
        ),
        isTrue,
      );
    });

    testWidgets('and not again once dismissed', (tester) async {
      await pumpMine(tester, vehicles: [testVehicle('v1')]);

      expect(find.byKey(const Key('driver-notice')), findsNothing);
    });

    testWidgets('a device that cannot say whether it showed it shows it', (
      tester,
    ) async {
      // The sentence is a promise the privacy policy makes; a store that
      // fails to answer must not be read as "already shown", and the failure
      // leaves a trace.
      await clearRecordedFailures();
      await pumpMine(
        tester,
        vehicles: [testVehicle('v1')],
        noticeUnreadable: true,
      );

      expect(find.byKey(const Key('driver-notice')), findsOneWidget);
      expect(recordedFailures.single, contains('bool'));
    });

    testWidgets('confirms a handover from the list', (tester) async {
      final repository = await pumpMine(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        own: [handover('a1')],
      );

      expect(find.textContaining('You took over Golf'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-handover-a1')));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('confirm:a1'));
      expect(find.text('Confirmed'), findsOneWidget);
      // Read again after the sign-off, and signed, so the card has gone.
      expect(find.byKey(const Key('confirm-handover-a1')), findsNothing);
    });

    testWidgets('a refused confirmation keeps the card and says why', (
      tester,
    ) async {
      final repository = await pumpMine(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        own: [handover('a1')],
        failWith: const AppFailure(kind: AppFailureKind.permission),
      );

      await tester.tap(find.byKey(const Key('confirm-handover-a1')));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('confirm:a1'));
      expect(find.byKey(const Key('confirm-handover-a1')), findsOneWidget);
      expect(find.text('Confirmed'), findsNothing);
      expect(find.textContaining('You do not have access'), findsOneWidget);
    });

    testWidgets('a sign-off list that failed to load says so', (tester) async {
      // Nothing where the card should be would read as nothing to sign,
      // which is a wrong answer with the cause unlogged.
      await pumpMine(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        readFailsWith: const AppFailure(
          kind: AppFailureKind.permission,
          debugMessage:
              '42501: permission denied for table vehicle_assignments',
        ),
      );

      expect(find.textContaining('You do not have access'), findsOneWidget);
      expect(find.text('Golf'), findsOneWidget);
    });

    testWidgets('a handover in another garage is not on this list', (
      tester,
    ) async {
      // The driver's windows come back from every garage they drive for;
      // the other company's car is not in this one's startup fetch.
      await pumpMine(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        own: [
          handover('a1'),
          handover('a2', vehicleId: 'elsewhere'),
        ],
      );

      expect(find.byKey(const Key('confirm-handover-a1')), findsOneWidget);
      expect(find.byKey(const Key('confirm-handover-a2')), findsNothing);
    });

    testWidgets('in Croatian on a narrow phone at a large font', (
      tester,
    ) async {
      await pumpMine(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        own: [handover('a1')],
        noticeSeen: false,
        locale: const Locale('hr'),
        textScale: 1.5,
        surface: const Size(320, 1600),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Moja vozila'), findsOneWidget);
    });
  });
}
