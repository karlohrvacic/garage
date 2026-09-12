import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/links/url_opener.dart';
import 'package:garage/core/sync/pending_write.dart';
import 'package:garage/core/sync/sync_providers.dart';
import 'package:garage/features/settings/screens/more_screen.dart';

import '../../support/pump_screen.dart';

Future<NavigationLog> pumpMore(
  WidgetTester tester, {
  List<PendingWrite> pending = const [],
  Locale? locale,
  double textScale = 1,
  Size surface = const Size(420, 1000),
}) {
  return pumpScreen(
    tester,
    const MoreScreen(),
    initialLocation: '/more',
    locale: locale,
    textScale: textScale,
    surface: surface,
    extraRoutes: const {
      '/household',
      '/stats',
      '/trips',
      '/stations',
      '/calculator',
      '/settings',
      '/data',
      '/about',
      '/tour',
      '/pending',
    },
    overrides: [
      urlOpenerProvider.overrideWithValue((url) async {}),
      pendingWritesProvider.overrideWith((ref) async => pending),
    ],
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

      // Hand-maintained, and that is the weakness: `/routes` shipped with an
      // unlabelled toolbar icon as its only way in and this list did not
      // notice. Add the route here when you add the destination.
      for (final route in [
        '/household',
        '/stats',
        '/trips',
        '/routes',
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
      expect(find.text('Trips'), findsOneWidget);
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

  // The privacy policy tells a reader they can see what is still on their
  // phone at More \u2192 Waiting to sync. It was reachable only from a banner
  // that appears when the queue is not empty \u2014 so the one person most
  // likely to look, the one who wants to check nothing is being held, found
  // nothing there. A promise in a legal document is a specification.
  group('what is still on this phone', () {
    testWidgets('is a row here even when the queue is empty', (tester) async {
      final log = await pumpMore(tester);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('more-pending')),
        200,
      );

      expect(find.text('Everything has been sent.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('more-pending')));
      await tester.pumpAndSettle();

      expect(log.visited, contains('/pending'));
    });

    testWidgets('counts what is waiting', (tester) async {
      await pumpMore(
        tester,
        pending: [
          PendingWrite(
            id: 'p1',
            kind: PendingWriteKind.fuel,
            vehicleId: 'v1',
            row: const {},
            queuedAt: DateTime.utc(2026, 9, 5),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('more-pending')),
        200,
      );

      expect(find.text('1 entry is waiting to sync'), findsOneWidget);
    });
  });

  testWidgets('in Croatian on a narrow phone at a large font it lays out', (
    tester,
  ) async {
    // Croatian runs a fifth longer, and every row here is a title over a
    // subtitle inside a card — the shape that overflowed seven times elsewhere.
    await pumpMore(
      tester,
      locale: const Locale('hr'),
      textScale: 1.5,
      surface: const Size(320, 3000),
      pending: [
        PendingWrite(
          id: 'p1',
          kind: PendingWriteKind.fuel,
          vehicleId: 'v1',
          row: const {},
          queuedAt: DateTime.utc(2026, 9, 5),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('in Italian on a narrow phone at a large font it lays out', (
    tester,
  ) async {
    // Croatian runs a fifth longer, and every row here is a title over a
    // subtitle inside a card — the shape that overflowed seven times elsewhere.
    await pumpMore(
      tester,
      locale: const Locale('it'),
      textScale: 1.5,
      surface: const Size(320, 3000),
      pending: [
        PendingWrite(
          id: 'p1',
          kind: PendingWriteKind.fuel,
          vehicleId: 'v1',
          row: const {},
          queuedAt: DateTime.utc(2026, 9, 5),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('offers the tour of what the app can do', (tester) async {
    final log = await pumpMore(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('more-/features')));
    await tester.pumpAndSettle();

    expect(log.visited, contains('/tour'));
  });
}
