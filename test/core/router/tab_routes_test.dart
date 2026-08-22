import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/router/app_router.dart';
import 'package:garage/core/widgets/garage_bottom_nav.dart';
import 'package:go_router/go_router.dart';

GoRoute _routeFor(String path) {
  return garageRoutes().whereType<GoRoute>().firstWhere(
    (route) => route.path == path,
    orElse: () => throw StateError('no route registered for $path'),
  );
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
}
