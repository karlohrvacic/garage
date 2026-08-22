import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/auth/screens/confirm_email_screen.dart';
import '../../features/auth/screens/sign_up_screen.dart';
import '../../features/api/screens/api_access_screen.dart';
import '../../features/calculator/screens/calculator_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/household/providers/household_providers.dart';
import '../../features/household/screens/household_screen.dart';
import '../../features/household/screens/join_screen.dart';
import '../../features/household/providers/pending_invite.dart';
import '../../features/household/screens/onboarding_screen.dart';
import '../../features/planner/screens/planner_screen.dart';
import '../../features/settings/screens/more_screen.dart';
import '../../features/settings/screens/data_screen.dart';
import '../../features/settings/screens/about_screen.dart';
import '../../features/settings/screens/diagnostics_screen.dart';
import '../../features/settings/screens/csv_import_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/stations/screens/stations_screen.dart';
import '../../features/timeline/screens/timeline_screen.dart';
import '../../features/trips/screens/trip_log_screen.dart';
import '../../features/tyres/screens/tyres_screen.dart';
import '../../features/stats/screens/stats_screen.dart';
import '../../features/fuel/screens/fuel_log_screen.dart';
import '../../features/fuel/screens/quick_fuel_screen.dart';
import '../../features/maintenance/screens/maintenance_screen.dart';
import '../../features/vehicles/screens/vehicle_detail_screen.dart';
import '../../features/vehicles/screens/vehicle_edit_screen.dart';
import '../../features/vehicles/screens/vehicle_transfer_screen.dart';
import '../../features/vehicles/screens/vehicles_screen.dart';
import '../../domain/auth/email_link.dart';
import '../supabase/supabase_client_provider.dart';
import 'app_redirect.dart';
import '../theme/garage_tokens.dart';

/// Root navigator handle, for the rare UI that must show above whatever route
/// is current (e.g. the password-recovery prompt in main.dart).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Routes the user by the two gates they must pass: signed in, then in a
/// household. Anything else is a redirect back to the gate they failed.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) => garageRedirect(
      location: state.matchedLocation,
      signedIn: ref.read(currentUserProvider) != null,
      household: ref.read(currentHouseholdProvider),
      pendingInvite: ref.read(pendingInviteProvider),
    ),
    routes: garageRoutes(),
  );
});

/// Every route the app has, apart from the two gates' redirect logic.
///
/// A function rather than a field on the provider so a test can look at the
/// route table itself — which is where a tab route silently registered like a
/// pushed detail page is visible and nowhere else.
List<RouteBase> garageRoutes() {
  return [
    GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
    GoRoute(path: '/sign-up', builder: (_, _) => const SignUpScreen()),
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
    // Outside both gates on purpose; see [garageRedirect].
    GoRoute(
      path: '$joinRoute/:code',
      builder: (_, state) => JoinScreen(code: state.pathParameters['code']!),
    ),
    // Also outside both gates: whoever follows a confirmation link is by
    // definition not signed in yet, and the sign-in gate would swallow the
    // token before it could be spent.
    GoRoute(
      path: confirmEmailRoute,
      builder: (_, state) => ConfirmEmailScreen(
        link: EmailLink.fromQuery(state.uri.queryParameters),
      ),
    ),
    // Inside both gates, unlike the two above: this is where the Android
    // launcher's fill-up shortcut and home-screen widget land, and they are
    // tapped on a phone the app is already set up on.
    GoRoute(path: quickFuelRoute, builder: (_, _) => const QuickFuelScreen()),
    GoRoute(
      path: '/planner',
      pageBuilder: (_, state) => _tabPage(state, const PlannerScreen()),
    ),
    GoRoute(path: '/household', builder: (_, _) => const HouseholdScreen()),
    GoRoute(path: '/api', builder: (_, _) => const ApiAccessScreen()),
    GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
    GoRoute(path: '/diagnostics', builder: (_, _) => const DiagnosticsScreen()),
    GoRoute(path: '/stats', builder: (_, _) => const StatsScreen()),
    GoRoute(path: '/trips', builder: (_, _) => const TripLogScreen()),
    GoRoute(path: '/import', builder: (_, _) => const CsvImportScreen()),
    GoRoute(
      path: '/transfer',
      builder: (_, state) =>
          VehicleTransferScreen(vehicleId: state.uri.queryParameters['v']),
    ),
    GoRoute(path: '/calculator', builder: (_, _) => const CalculatorScreen()),
    GoRoute(path: '/stations', builder: (_, _) => const StationsScreen()),
    GoRoute(
      path: '/timeline',
      pageBuilder: (_, state) => _tabPage(state, const TimelineScreen()),
    ),
    // A tab, so it cross-fades like its peers. Registered with a plain
    // builder it took the platform push transition instead, and tapping
    // "More" slid a new page in over the very navigation bar that was still
    // sitting there — the one animation in the bar that went sideways.
    GoRoute(
      path: '/more',
      pageBuilder: (_, state) => _tabPage(state, const MoreScreen()),
    ),
    GoRoute(path: '/data', builder: (_, _) => const DataScreen()),
    GoRoute(
      path: '/settings',
      pageBuilder: (_, state) => _tabPage(state, const SettingsScreen()),
    ),
    GoRoute(
      path: '/vehicles',
      pageBuilder: (_, state) => _tabPage(state, const VehiclesScreen()),
    ),
    GoRoute(
      path: '/vehicles/new',
      builder: (_, _) => const VehicleEditScreen(),
    ),
    GoRoute(
      path: '/vehicles/:id/edit',
      builder: (_, state) =>
          VehicleEditScreen(vehicleId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/vehicles/:id/fuel',
      builder: (_, state) =>
          FuelLogScreen(vehicleId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/vehicles/:id/tyres',
      builder: (_, state) =>
          TyresScreen(vehicleId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/vehicles/:id/maintenance',
      builder: (_, state) =>
          MaintenanceScreen(vehicleId: state.pathParameters['id']!),
    ),
    // Declared last of the /vehicles/* group: the literal /vehicles/new above
    // must win over this :id pattern, or "new" would be read as a vehicle id.
    GoRoute(
      path: '/vehicles/:id',
      builder: (_, state) =>
          VehicleDetailScreen(vehicleId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/',
      pageBuilder: (_, state) => _tabPage(state, const DashboardScreen()),
    ),
  ];
}

/// Bottom-nav destinations are peers, not a hierarchy: switching tabs cross-
/// fades instead of playing the directional push transition, which read as
/// "forward" no matter which way the user moved. Pushed detail routes keep the
/// platform default.
CustomTransitionPage<void> _tabPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: GarageTokens.motionBase,
    reverseTransitionDuration: GarageTokens.motionBase,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(
          curve: GarageTokens.easeStandard,
        ).animate(animation),
        child: child,
      );
    },
  );
}

/// Bridges Riverpod's auth and household state into something go_router can
/// listen to, so a sign-out or a freshly created household re-runs the
/// redirect immediately.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(currentUserProvider, (_, _) => notifyListeners());
    ref.listen(currentHouseholdProvider, (_, _) => notifyListeners());
  }
}
