import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/page_header.dart';
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
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const GaragePageScaffold(title: 'Fuel', body: SizedBox()),
                ),
              ),
              child: const Text('open'),
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
}
