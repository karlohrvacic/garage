import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/garage_bottom_nav.dart';
import 'package:garage/core/widgets/page_header.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../support/pump_screen.dart';

Future<NavigationLog> pumpNav(
  WidgetTester tester, {
  Locale? locale,
  Size surface = const Size(360, 800),
  GarageTab current = GarageTab.dashboard,
}) {
  return pumpScreen(
    tester,
    GarageTabScaffold(
      current: current,
      appBar: AppBar(title: const Text('Screen')),
      body: const SizedBox(),
    ),
    surface: surface,
    locale: locale,
  );
}

List<String> tabLabels(AppLocalizations l10n) => [
  l10n.dashboardTitle,
  l10n.timelineTitle,
  l10n.vehiclesTitle,
  l10n.plannerTitle,
  l10n.settingsTitle,
];

void main() {
  testWidgets('every tab is offered', (tester) async {
    await pumpNav(tester);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(5));
  });

  testWidgets('the current tab is the selected one', (tester) async {
    await pumpNav(tester, current: GarageTab.planner);
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));

    expect(bar.selectedIndex, 3);
  });

  testWidgets('a phone-width window uses the bottom bar', (tester) async {
    await pumpNav(tester, surface: const Size(400, 900));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('a desktop-width window uses the rail instead', (tester) async {
    await pumpNav(tester, surface: const Size(1400, 900));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('tapping a tab navigates to it', (tester) async {
    final log = await pumpNav(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.event_note_outlined));
    await tester.pumpAndSettle();

    expect(log.visited, contains('/planner'));
  });

  testWidgets('tapping the current tab navigates nowhere', (tester) async {
    final log = await pumpNav(tester, current: GarageTab.dashboard);
    await tester.pumpAndSettle();
    final before = log.visited.length;

    await tester.tap(find.byIcon(Icons.dashboard));
    await tester.pumpAndSettle();

    expect(log.visited, hasLength(before));
  });

  // A tab slot is barely wider than one word. A label containing a space wraps
  // onto a second line, making that one destination taller than its
  // neighbours — the Croatian timeline label used to do exactly this.
  group('tab labels stay on one line', () {
    for (final locale in AppLocalizations.supportedLocales) {
      test('in ${locale.languageCode}', () {
        final l10n = lookupAppLocalizations(locale);

        for (final label in tabLabels(l10n)) {
          expect(
            label.trim(),
            isNot(contains(' ')),
            reason:
                '"$label" is more than one word, so it wraps in the tab bar',
          );
        }
      });
    }
  });

  group('the desktop sidebar', () {
    testWidgets('carries labels, not bare icons', (tester) async {
      await pumpNav(tester, surface: const Size(1400, 900));
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));

      expect(
        rail.extended,
        isTrue,
        reason:
            'an icon strip beside a narrow column is what made the web '
            'build read as a phone app',
      );
    });

    testWidgets('names the garage you are looking at', (tester) async {
      await pumpNav(tester, surface: const Size(1400, 900));
      await tester.pumpAndSettle();

      // The garage's own name. Which one you are in is the question a second
      // garage makes worth answering at a glance.
      expect(find.text(testHousehold.name), findsOneWidget);
    });

    testWidgets('offers what is otherwise buried in settings', (tester) async {
      await pumpNav(tester, surface: const Size(1400, 900));
      await tester.pumpAndSettle();

      // Room a phone does not have is room to stop hiding things.
      expect(find.text('Garage'), findsOneWidget);
      expect(find.text('Statistics'), findsOneWidget);
    });

    testWidgets('a tablet-width window keeps the compact rail', (tester) async {
      await pumpNav(tester, surface: const Size(1000, 900));
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));

      expect(rail.extended, isFalse);
      expect(find.text('Garage'), findsNothing);
    });
  });

  group('page chrome', () {
    Future<void> pumpTitled(WidgetTester tester, Size surface) {
      return pumpScreen(
        tester,
        const GarageTabScaffold(
          current: GarageTab.dashboard,
          title: 'Fuel',
          body: SizedBox(),
        ),
        surface: surface,
      );
    }

    testWidgets('a desktop window titles the page in its content', (
      tester,
    ) async {
      await pumpTitled(tester, const Size(1400, 900));
      await tester.pumpAndSettle();

      expect(find.byType(PageHeader), findsOneWidget);
      expect(
        find.byType(AppBar),
        findsNothing,
        reason: 'a top bar above a sidebar is phone chrome on a desktop window',
      );
    });

    testWidgets('a phone keeps the app bar', (tester) async {
      await pumpTitled(tester, const Size(400, 900));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(PageHeader), findsNothing);
    });

    testWidgets('the title is shown either way', (tester) async {
      for (final surface in [const Size(1400, 900), const Size(400, 900)]) {
        await pumpTitled(tester, surface);
        await tester.pumpAndSettle();

        expect(find.text('Fuel'), findsOneWidget);
      }
    });
  });
}
