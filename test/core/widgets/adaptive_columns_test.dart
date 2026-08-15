import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/adaptive.dart';

Future<void> pumpColumns(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: AdaptiveColumns(
          children: [
            SizedBox(key: Key('a'), height: 100),
            SizedBox(key: Key('b'), height: 100),
            SizedBox(key: Key('c'), height: 100),
            SizedBox(key: Key('d'), height: 100),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double xOf(WidgetTester tester, String key) =>
    tester.getTopLeft(find.byKey(Key(key))).dx;

void main() {
  testWidgets('a phone stacks everything in one column', (tester) async {
    await pumpColumns(tester, const Size(400, 900));

    expect(xOf(tester, 'a'), xOf(tester, 'b'));
    expect(xOf(tester, 'a'), xOf(tester, 'c'));
  });

  testWidgets('a desktop lays sections beside each other', (tester) async {
    await pumpColumns(tester, const Size(1400, 900));

    expect(
      xOf(tester, 'b'),
      greaterThan(xOf(tester, 'a')),
      reason:
          'stacking cards down a narrow column on a wide monitor is what '
          'made the web build read as a phone app',
    );
  });

  testWidgets('sections alternate, so both columns fill', (tester) async {
    await pumpColumns(tester, const Size(1400, 900));

    // a, c on the left; b, d on the right.
    expect(xOf(tester, 'c'), xOf(tester, 'a'));
    expect(xOf(tester, 'd'), xOf(tester, 'b'));
  });

  testWidgets('a tablet-width window still stacks', (tester) async {
    await pumpColumns(tester, const Size(1000, 900));

    expect(
      xOf(tester, 'b'),
      xOf(tester, 'a'),
      reason:
          'two columns need the desktop breakpoint, not merely more than a '
          'phone: a rail plus two columns at 1000px leaves neither readable',
    );
  });
}
