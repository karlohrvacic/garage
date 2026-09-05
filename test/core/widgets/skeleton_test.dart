import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/theme/garage_theme.dart';
import 'package:garage/core/theme/garage_tokens.dart';
import 'package:garage/core/widgets/skeleton.dart';

Color? fillOf(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(SkeletonBox),
      matching: find.byType(Container),
    ),
  );
  return (container.decoration! as BoxDecoration).color;
}

Future<void> pumpBox(
  WidgetTester tester, {
  required bool reducedMotion,
  Brightness brightness = Brightness.dark,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? GarageTheme.dark()
          : GarageTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: const Scaffold(body: SkeletonBox.line(width: 100)),
      ),
    ),
  );
}

void main() {
  testWidgets('the placeholder pulses while it waits', (tester) async {
    await pumpBox(tester, reducedMotion: false);
    final first = fillOf(tester);

    await tester.pump(const Duration(milliseconds: 400));

    expect(
      fillOf(tester),
      isNot(first),
      reason: 'a placeholder that never changes reads as content that failed',
    );
    // The controller repeats forever; without this the test ends with a
    // scheduled frame still pending.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion holds it still', (tester) async {
    await pumpBox(tester, reducedMotion: true);
    final first = fillOf(tester);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(fillOf(tester), first);
  });

  /// WCAG relative luminance, so "visible" is a number rather than an opinion.
  double luminance(Color color) => color.computeLuminance();

  double contrast(Color a, Color b) {
    final light = luminance(a) > luminance(b) ? a : b;
    final dark = identical(light, a) ? b : a;
    return (luminance(light) + 0.05) / (luminance(dark) + 0.05);
  }

  testWidgets('it stays visible against the card it sits on', (tester) async {
    // The first version of this test asserted only that the fill was not
    // *exactly* the surface colour, which a placeholder can satisfy while
    // being invisible: in the dark theme `border` and `surface` are twelve
    // values apart, and a sweep between them passed the assertion and could
    // not be seen. A ratio catches what an inequality does not.
    //
    // 1.2:1 is far below any text threshold on purpose. This is a shape, not
    // a character; the bar is "a person can tell something is there".
    for (final brightness in Brightness.values) {
      for (final reducedMotion in [true, false]) {
        await pumpBox(
          tester,
          reducedMotion: reducedMotion,
          brightness: brightness,
        );
        final tokens =
            (brightness == Brightness.dark
                    ? GarageTheme.dark()
                    : GarageTheme.light())
                .extension<GarageTokens>()!;

        // Both ends of the pulse, not just wherever it happens to rest.
        for (final elapsed in [0, 250, 550, 1100]) {
          await tester.pump(Duration(milliseconds: elapsed));
          expect(
            contrast(fillOf(tester)!, tokens.surface),
            greaterThan(1.2),
            reason:
                'a $brightness placeholder vanished into the card at '
                '${elapsed}ms',
          );
        }
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets('the dashboard outline draws the cards it expects', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GarageTheme.dark(),
        home: const Scaffold(body: DashboardSkeleton(cards: 3)),
      ),
    );
    await tester.pump();

    // Three cards, each with a name, two detail lines and a gauge, plus the
    // garage name and the three figures across the top.
    expect(find.byType(SkeletonBox), findsNWidgets(1 + 6 + 3 * 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the outline is invisible to a screen reader', (tester) async {
    // It has nothing to say. Announcing eleven blank shapes is worse than
    // announcing nothing and then the content.
    await tester.pumpWidget(
      MaterialApp(
        theme: GarageTheme.dark(),
        home: const Scaffold(body: DashboardSkeleton()),
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(DashboardSkeleton),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
