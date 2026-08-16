import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/core/widgets/page_header.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:garage/core/widgets/page_scaffold.dart';

import '../../support/pump_screen.dart';

Future<NavigationLog> pumpPage(
  WidgetTester tester, {
  required Size surface,
  List<Widget> actions = const [],
}) {
  return pumpScreen(
    tester,
    GaragePageScaffold(title: 'Fuel', actions: actions, body: const SizedBox()),
    initialLocation: '/vehicles/v1/fuel',
    surface: surface,
  );
}

void main() {
  testWidgets('a phone gets the app bar it expects', (tester) async {
    await pumpPage(tester, surface: const Size(400, 900));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(PageHeader), findsNothing);
  });

  testWidgets('a desktop window titles the page in its content', (
    tester,
  ) async {
    await pumpPage(tester, surface: const Size(1400, 900));
    await tester.pumpAndSettle();

    expect(find.byType(PageHeader), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('a page pushed onto something keeps a way back', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // The sidebar names the household, so it needs a scope that answers
        // for one rather than reaching for a real Supabase client.
        overrides: [
          currentHouseholdProvider.overrideWith((ref) async => testHousehold),
        ],
        child: MaterialApp(
          // The sidebar is localized, and the real app always has these;
          // without them the rail throws rather than rendering.
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GaragePageScaffold(
                      title: 'Fuel',
                      body: SizedBox(),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('a page opened directly offers no dead back button', (
    tester,
  ) async {
    // On the web a screen can be the whole history, for example someone
    // pasting a link to a vehicle. A back arrow with an empty stack is the
    // phone chrome this layout exists to remove.
    await pumpPage(tester, surface: const Size(1400, 900));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('the title shows at either width', (tester) async {
    for (final surface in [const Size(1400, 900), const Size(400, 900)]) {
      await pumpPage(tester, surface: surface);
      await tester.pumpAndSettle();

      expect(find.text('Fuel'), findsOneWidget);
    }
  });

  testWidgets('actions survive both presentations', (tester) async {
    for (final surface in [const Size(1400, 900), const Size(400, 900)]) {
      await pumpPage(
        tester,
        surface: surface,
        actions: [
          IconButton(
            key: const Key('action'),
            onPressed: () {},
            icon: const Icon(Icons.add),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('action')), findsOneWidget);
    }
  });

  // Statistics, the calculator, the stations and the household screen are all
  // pushed pages. On a desktop window they replaced the whole window with a
  // bare page, so the sidebar vanished and the only way anywhere else was the
  // browser's back button — a phone's navigation model on a screen with room
  // for a sidebar.
  testWidgets('a desktop window keeps the navigation while it is open', (
    tester,
  ) async {
    await pumpPage(tester, surface: const Size(1400, 900));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('and marks no tab as current, because none of them is', (
    tester,
  ) async {
    await pumpPage(tester, surface: const Size(1400, 900));
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));

    expect(rail.selectedIndex, isNull);
  });

  testWidgets('a phone keeps the back arrow instead, having no room', (
    tester,
  ) async {
    await pumpPage(tester, surface: const Size(400, 900));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsNothing);
  });
}
