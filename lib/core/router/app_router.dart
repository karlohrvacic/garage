import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/auth/screens/sign_up_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/household/providers/household_providers.dart';
import '../../features/household/screens/onboarding_screen.dart';
import '../../features/planner/screens/planner_screen.dart';
import '../../features/fuel/screens/fuel_log_screen.dart';
import '../../features/maintenance/screens/maintenance_screen.dart';
import '../../features/vehicles/screens/vehicle_detail_screen.dart';
import '../../features/vehicles/screens/vehicle_edit_screen.dart';
import '../../features/vehicles/screens/vehicles_screen.dart';
import '../supabase/supabase_client_provider.dart';

/// Routes the user by the two gates they must pass: signed in, then in a
/// household. Anything else is a redirect back to the gate they failed.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final signedIn = ref.read(currentUserProvider) != null;
      final onAuthScreen =
          state.matchedLocation == '/sign-in' || state.matchedLocation == '/sign-up';

      if (!signedIn) {
        return onAuthScreen ? null : '/sign-in';
      }
      if (onAuthScreen) {
        return '/';
      }

      final household = ref.read(currentHouseholdProvider);
      // Wait for the household lookup rather than guessing; the splash route
      // holds the user for the moment it takes.
      if (household.isLoading) {
        return null;
      }
      final needsOnboarding = household.value == null;
      if (needsOnboarding && state.matchedLocation != '/onboarding') {
        return '/onboarding';
      }
      if (!needsOnboarding && state.matchedLocation == '/onboarding') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/sign-up', builder: (_, _) => const SignUpScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/planner', builder: (_, _) => const PlannerScreen()),
      GoRoute(path: '/vehicles', builder: (_, _) => const VehiclesScreen()),
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
      GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
    ],
  );
});

/// Bridges Riverpod's auth and household state into something go_router can
/// listen to, so a sign-out or a freshly created household re-runs the
/// redirect immediately.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(currentUserProvider, (_, _) => notifyListeners());
    ref.listen(currentHouseholdProvider, (_, _) => notifyListeners());
  }
}
