import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/adaptive.dart';

/// Pumps [child] in a window of [size] and returns the width it was given.
Future<double> widthAt(
  WidgetTester tester,
  Size size, {
  required Widget child,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
  return tester.getSize(find.byKey(const Key('measured'))).width;
}

const _measured = SizedBox.expand(key: Key('measured'));

void main() {
  group('reading width', () {
    testWidgets('is capped, because a form spanning a monitor is unreadable', (
      tester,
    ) async {
      final width = await widthAt(
        tester,
        const Size(1600, 900),
        child: const AdaptiveContent(child: _measured),
      );

      expect(width, GarageBreakpoints.contentMaxWidth);
    });

    testWidgets('is the whole window on a phone', (tester) async {
      final width = await widthAt(
        tester,
        const Size(400, 900),
        child: const AdaptiveContent(child: _measured),
      );

      expect(width, 400);
    });
  });

  group('wide content', () {
    testWidgets('uses the window a desktop actually has', (tester) async {
      final width = await widthAt(
        tester,
        const Size(1600, 900),
        child: const AdaptiveContent(
          width: ContentWidth.wide,
          child: _measured,
        ),
      );

      expect(
        width,
        greaterThan(GarageBreakpoints.contentMaxWidth),
        reason:
            'a dashboard squeezed into a reading column is the whole '
            'complaint about the desktop layout',
      );
      expect(
        width,
        lessThanOrEqualTo(GarageBreakpoints.wideContentMaxWidth),
        reason:
            'still capped: cards stretched across an ultrawide are no '
            'better than a narrow column',
      );
    });

    testWidgets('is still the whole window on a phone', (tester) async {
      final width = await widthAt(
        tester,
        const Size(400, 900),
        child: const AdaptiveContent(
          width: ContentWidth.wide,
          child: _measured,
        ),
      );

      expect(width, 400);
    });
  });

  group('breakpoints', () {
    test('desktop is wider than the tablet threshold', () {
      expect(
        GarageBreakpoints.desktop,
        greaterThan(GarageBreakpoints.wide),
        reason: 'the labelled sidebar needs more room than the icon rail',
      );
    });
  });
}
