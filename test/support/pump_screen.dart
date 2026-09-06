import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/core/supabase/supabase_client_provider.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/household/data/garage_bootstrap_cache.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/domain/account/account_identity.dart';
import 'package:garage/features/auth/providers/auth_providers.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/features/attachments/data/attachment_repository.dart';
import 'package:garage/features/attachments/providers/attachment_providers.dart';
import 'package:garage/l10n/app_localizations.dart';

import 'fake_attachments.dart';
import 'fake_repositories.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:garage/core/sync/sync_providers.dart';
import 'package:garage/core/sync/write_queue.dart';
import 'package:garage/features/household/data/garage_bootstrap.dart';

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

  /// The garage it belongs to. A borrowed car's is one the caller is not in.
  String householdId = 'h1',
  bool archived = false,
  int baselineOdometerKm = 50000,
  double? tankCapacityL,
  String? secondaryFuelTypeKey,
  String kind = 'car',
}) {
  return Vehicle(
    id: id,
    householdId: householdId,
    nickname: nickname ?? id,
    fuelTypeKey: 'fuel_diesel',
    baselineOdometerKm: baselineOdometerKm,
    secondaryFuelTypeKey: secondaryFuelTypeKey,
    kind: kind,
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
  UnitPreferences preferences = metricPreferences,

  /// The system font scale. Phones ship anywhere from 0.85 to 2.0, and a
  /// label that fits at 1.0 is not a label that fits.
  double textScale = 1,
  Household? household = testHousehold,

  /// Holds the household in its loading state, for the screens that show
  /// something different while it arrives. Wins over [household].
  Future<Household?>? householdFuture,
  String? userId = 'u1',
  AccountIdentity? identity = const AccountIdentity(
    name: 'Karlo',
    email: 'karlo@example.com',
  ),

  /// The attachment store, for a test that asserts on what was uploaded.
  /// Passed here rather than through [overrides] because the harness always
  /// supplies one and Riverpod refuses a provider overridden twice.
  AttachmentRepository? attachments,

  /// What startup's single fetch returns. `allVehiclesProvider` and everything
  /// under it are derived from it, so a screen showing vehicles gets them from
  /// here rather than from a vehicle-repository override.
  List<Vehicle> vehicles = const [],

  /// Cars a guest pass opens: visible to the user, in nobody's garage.
  List<Vehicle> borrowedVehicles = const [],

  /// The offline write queue, for a test that asserts on what is waiting.
  PendingWriteStore? pendingWrites,

  /// Startup's fetch. Passed here rather than through [overrides] for the same
  /// reason as [attachments]: the harness always supplies one and Riverpod
  /// refuses a provider overridden twice. A test that drives the real provider
  /// graph passes its own so it can add a car and invalidate.
  GarageBootstrapRepository? bootstrap,
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
        '/more',
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
        unitPreferencesProvider.overrideWithValue(preferences),
        currentHouseholdProvider.overrideWith(
          (ref) => householdFuture ?? Future.value(household),
        ),
        currentUserIdProvider.overrideWithValue(userId),
        // Screens that name the signed-in account would otherwise reach for a
        // real Supabase client, which no widget test has.
        accountIdentityProvider.overrideWithValue(identity),
        // Entry sheets show their attachments from the first keystroke now,
        // so any screen that opens one reaches this repository. Passed rather
        // than overridden by the caller: Riverpod refuses the same provider
        // twice in one container.
        attachmentRepositoryProvider.overrideWithValue(
          attachments ?? FakeAttachmentRepository(),
        ),
        // The offline queue lives in SharedPreferences, which hangs in a test
        // with no mock values set — a save would then never return and the
        // failure reads as "pumpAndSettle timed out" rather than as anything
        // to do with syncing. A test about queueing overrides this itself.
        pendingWriteStoreProvider.overrideWithValue(
          pendingWrites ?? InMemoryPendingWriteStore(),
        ),
        // The startup cache lives in SharedPreferences, which hangs in a test
        // with no mock values set — and it is awaited before the first frame,
        // so the failure would read as "pumpAndSettle timed out" rather than
        // as anything to do with caching.
        garageBootstrapCacheProvider.overrideWithValue(
          const NoGarageBootstrapCache(),
        ),
        // Without this the vehicle list reaches for a real Supabase client and
        // the test fails on an uninitialised instance rather than on what it
        // set out to check.
        garageBootstrapRepositoryProvider.overrideWithValue(
          bootstrap ??
              FakeGarageBootstrapRepository(
                households: [?household],
                vehicles: vehicles,
                borrowed: borrowedVehicles,
              ),
        ),
        ...overrides,
      ],
      child: MaterialApp.router(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
      ),
    ),
  );
  return log;
}
