import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/router/app_router.dart';
import 'package:garage/core/widgets/garage_bottom_nav.dart';
import 'package:garage/features/maintenance/screens/maintenance_screen.dart';
import 'package:garage/features/stats/screens/stats_screen.dart';
import 'package:go_router/go_router.dart';

GoRoute _routeFor(String path) {
  return garageRoutes().whereType<GoRoute>().firstWhere(
    (route) => route.path == path,
    orElse: () => throw StateError('no route registered for $path'),
  );
}

/// What [path]'s route builds for [location], without building a router, a
/// screen, or anything the screen would ask for.
Future<Widget> _builtFor(
  WidgetTester tester,
  String path,
  String location, {
  Map<String, String> pathParameters = const {},
}) async {
  late BuildContext context;
  await tester.pumpWidget(
    Builder(
      builder: (built) {
        context = built;
        return const SizedBox();
      },
    ),
  );
  final route = _routeFor(path);
  final uri = Uri.parse(location);
  final state = GoRouterState(
    RouteConfiguration(
      ValueNotifier(RoutingConfig(routes: [route])),
      navigatorKey: GlobalKey<NavigatorState>(),
    ),
    uri: uri,
    matchedLocation: uri.path,
    fullPath: path,
    pathParameters: pathParameters,
    pageKey: const ValueKey('page'),
  );
  return route.builder!(context, state);
}

void main() {
  // "More" was registered with a plain builder while the other four tabs used
  // the cross-fading tab page, so tapping it played the platform push
  // transition: a page sliding in sideways over the navigation bar it was
  // launched from, which is the animation a *detail* page gets. Nothing but
  // the route table shows this, which is why the assertion lives here.
  group('every bottom-nav tab', () {
    for (final entry in tabRoutes.entries) {
      test('${entry.key.name} is registered as a cross-fading tab page', () {
        expect(
          _routeFor(entry.value).pageBuilder,
          isNotNull,
          reason:
              '${entry.value} falls back to the platform push transition, '
              'which reads as "forward" between peers',
        );
      });
    }
  });

  // A link that names a tab has to land on it. Nothing else joins the query
  // to the screen, so a misspelt one opens the first tab and looks fine.
  group('a link that names a tab', () {
    testWidgets('opens statistics on costs', (tester) async {
      final screen = await _builtFor(tester, '/stats', '/stats?tab=costs');

      expect(
        screen,
        isA<StatsScreen>().having((s) => s.openOnCosts, 'openOnCosts', isTrue),
      );
    });

    testWidgets('and without one, on the first', (tester) async {
      final screen = await _builtFor(tester, '/stats', '/stats');

      expect(
        screen,
        isA<StatsScreen>().having((s) => s.openOnCosts, 'openOnCosts', isFalse),
      );
    });

    testWidgets('opens maintenance on the calendar', (tester) async {
      final screen = await _builtFor(
        tester,
        '/vehicles/:id/maintenance',
        '/vehicles/v1/maintenance?tab=calendar',
        pathParameters: {'id': 'v1'},
      );

      expect(
        screen,
        isA<MaintenanceScreen>().having(
          (s) => s.openOnCalendar,
          'openOnCalendar',
          isTrue,
        ),
      );
    });
  });
}
