import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/core/supabase/supabase_client_provider.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/domain/account/account_identity.dart';
import 'package:garage/features/auth/providers/auth_providers.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/misc.dart' show Override;

/// Metric, EUR — the defaults every screen test starts from unless it is
/// specifically about unit conversion.
const metricPreferences = UnitPreferences(
  distance: DistanceUnit.km,
  volume: VolumeUnit.liter,
  currencyCode: 'EUR',
);

const testHousehold = Household(id: 'h1', name: 'Test');

Vehicle testVehicle(
  String id, {
  String? nickname,
  bool archived = false,
  int baselineOdometerKm = 50000,
  double? tankCapacityL,
}) {
  return Vehicle(
    id: id,
    householdId: 'h1',
    nickname: nickname ?? id,
    fuelTypeKey: 'fuel_diesel',
    baselineOdometerKm: baselineOdometerKm,
    baselineDate: DateTime.utc(2026, 1, 1),
    tankCapacityL: tankCapacityL,
    archived: archived,
  );
}

/// Where a tab-bar tap or a `context.go` landed, so navigation can be asserted
/// without standing up the real router.
class NavigationLog {
  final List<String> visited = [];

  String get last => visited.last;
}

/// Pumps [screen] inside the app's localizations, a Riverpod scope carrying
/// [overrides], and a router whose other routes are stubs — enough for the
/// bottom navigation, `context.go`, and `context.push` to work.
///
/// Screens are rendered in a phone-sized window by default: the tab scaffold
/// switches to a navigation rail above the wide breakpoint, and every screen
/// test would otherwise depend on the test surface's default size.
Future<NavigationLog> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  String initialLocation = '/',
  Size surface = const Size(400, 900),
  Iterable<String> extraRoutes = const [],
  Locale? locale,
  Household? household = testHousehold,
  String? userId = 'u1',
  AccountIdentity? identity = const AccountIdentity(
    name: 'Karlo',
    email: 'karlo@example.com',
  ),
}) async {
  final log = NavigationLog();
  // One physical pixel per logical pixel, so [surface] means what it says: the
  // test view otherwise reports a ratio of 3, and a "400px" phone would lay
  // out at 133 logical pixels.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = surface;
  addTearDown(tester.view.reset);

  GoRoute stub(String path) {
    return GoRoute(
      path: path,
      builder: (context, state) {
        log.visited.add(state.uri.toString());
        return Scaffold(body: Text('stub:$path'));
      },
    );
  }

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: initialLocation,
        builder: (context, state) {
          log.visited.add(state.uri.toString());
          return screen;
        },
      ),
      for (final path in {
        '/',
        '/timeline',
        '/vehicles',
        '/planner',
        '/settings',
        '/stations',
        '/calculator',
        '/stats',
        ...extraRoutes,
      }.where((path) => path != initialLocation))
        stub(path),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        unitPreferencesProvider.overrideWithValue(metricPreferences),
        currentHouseholdProvider.overrideWith((ref) async => household),
        currentUserIdProvider.overrideWithValue(userId),
        // Screens that name the signed-in account would otherwise reach for a
        // real Supabase client, which no widget test has.
        accountIdentityProvider.overrideWithValue(identity),
        ...overrides,
      ],
      child: MaterialApp.router(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  return log;
}
