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

  // A tall entry form opens as a scroll-controlled sheet, which is laid out
  // over the whole screen. The route strips the top inset from the MediaQuery
  // it hands down, so the sheet's own SafeArea could not see it and the form's
  // title came to rest against the clock and the battery icon.
  group('an entry form on a phone', () {
    const statusBar = 48.0;

    Future<void> openSheet(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: const EdgeInsets.only(top: statusBar)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAdaptiveEntrySheet<void>(
                  context,
                  (_) => const SizedBox(
                    height: 2000,
                    child: Text('Add fill-up', key: Key('sheet-title')),
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
    }

    testWidgets('opens clear of the status bar', (tester) async {
      await openSheet(tester);

      expect(
        tester.getTopLeft(find.byKey(const Key('sheet-title'))).dy,
        greaterThanOrEqualTo(statusBar),
      );
    });
  });
}
