import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/page_header.dart';

Future<void> pumpHeader(
  WidgetTester tester,
  Size size, {
  List<Widget> actions = const [],
  VoidCallback? onBack,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PageHeader(
          title: 'Fuel',
          actions: actions,
          onBack: onBack,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the title is set as a page heading, not app-bar sized', (
    tester,
  ) async {
    await pumpHeader(tester, const Size(1500, 1000));

    final style = tester.widget<Text>(find.text('Fuel')).style;
    final expected = Theme.of(
      tester.element(find.text('Fuel')),
    ).textTheme.headlineSmall;

    expect(
      style?.fontSize,
      expected?.fontSize,
      reason: 'a desktop page names itself in its content, at content scale, '
          'rather than in a phone app bar',
    );
  });

  testWidgets('actions stay available beside the title', (tester) async {
    await pumpHeader(
      tester,
      const Size(1500, 1000),
      actions: [
        IconButton(
          key: const Key('action'),
          onPressed: () {},
          icon: const Icon(Icons.add),
        ),
      ],
    );

    expect(find.byKey(const Key('action')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('action'))).dx,
      greaterThan(tester.getTopLeft(find.text('Fuel')).dx),
    );
  });

  testWidgets('a screen you can go back from offers a way back', (
    tester,
  ) async {
    var popped = false;
    await pumpHeader(
      tester,
      const Size(1500, 1000),
      onBack: () => popped = true,
    );

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
  });

  testWidgets('a top-level screen shows no back affordance', (tester) async {
    await pumpHeader(tester, const Size(1500, 1000));

    expect(
      find.byTooltip('Back'),
      findsNothing,
      reason: 'the sidebar is the navigation on desktop; a back arrow on a '
          'top-level page is phone chrome with nowhere to go',
    );
  });
}
