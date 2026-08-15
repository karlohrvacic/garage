import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/garage_bottom_nav.dart';
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
}
