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

  group('telling a phone from a desktop', () {
    // Width alone cannot: a Galaxy S23 Ultra in landscape is about 988 by 461
    // logical pixels, wider than the desktop threshold while still being a
    // phone in someone's hands. The shortest side is what separates the two,
    // at Android's own 600dp tablet mark.
    testWidgets('a landscape phone is still a phone', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(988, 461);
      addTearDown(tester.view.reset);

      late bool wide;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              wide = GarageBreakpoints.isWide(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(wide, isFalse);
    });

    testWidgets('a tablet or a desktop window is wide', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.reset);

      late bool wide;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              wide = GarageBreakpoints.isWide(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(wide, isTrue);
    });
  });
}
