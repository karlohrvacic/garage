import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/links/url_opener.dart';
import 'package:garage/features/settings/screens/more_screen.dart';

import '../../support/pump_screen.dart';

Future<NavigationLog> pumpMore(WidgetTester tester) {
  return pumpScreen(
    tester,
    const MoreScreen(),
    initialLocation: '/more',
    surface: const Size(420, 1000),
    extraRoutes: const {
      '/household',
      '/stats',
      '/trips',
      '/stations',
      '/calculator',
      '/settings',
      '/data',
      '/about',
    },
    overrides: [urlOpenerProvider.overrideWithValue((url) async {})],
  );
}

void main() {
  // The bottom bar holds five and Material allows no more, so four features —
  // Statistics, the trip log, fuel stations, the calculator — plus the garage
  // itself lived under "Settings". Nobody looks under Settings for the people
  // they share a car with, and for an app whose premise is shared upkeep that
  // was its most consequential misplacement.
  group('the fifth tab', () {
    testWidgets('names every feature that is not a tab', (tester) async {
      await pumpMore(tester);
      await tester.pumpAndSettle();

      for (final route in [
        '/household',
        '/stats',
        '/trips',
        '/stations',
        '/calculator',
      ]) {
        expect(
          find.byKey(Key('more-$route')),
          findsOneWidget,
          reason: '$route has no labelled entry point',
        );
      }
    });

    testWidgets('they are words, not icons alone', (tester) async {
      await pumpMore(tester);
      await tester.pumpAndSettle();

      expect(find.text('Statistics'), findsOneWidget);
      expect(find.text('Trip log'), findsOneWidget);
      expect(find.text('Fuel stations'), findsOneWidget);
      expect(find.text('Calculator'), findsOneWidget);
    });

    testWidgets('the garage leads, since it is what the app is about', (
      tester,
    ) async {
      await pumpMore(tester);
      await tester.pumpAndSettle();

      final rows = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .toList(growable: false);

      expect((rows.first.key as ValueKey<String>).value, 'more-/household');
    });

    testWidgets('the trip log opens before any trip exists', (tester) async {
      // Its only other entry point is a timeline row for a trip already
      // logged, so the feature was reachable only after being used.
      final log = await pumpMore(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('more-/trips')));
      await tester.pumpAndSettle();

      expect(log.visited, contains('/trips'));
    });

    testWidgets('settings is one row here, not the door to everything', (
      tester,
    ) async {
      final log = await pumpMore(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('more-settings')));
      await tester.pumpAndSettle();

      expect(log.visited, contains('/settings'));
    });

    testWidgets('getting data out has its own place', (tester) async {
      // Imports, exports and backups were seven rows inside Settings, and none
      // of them is a setting.
      final log = await pumpMore(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('more-data')));
      await tester.pumpAndSettle();

      expect(log.visited, contains('/data'));
    });
  });
}
