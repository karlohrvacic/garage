import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/theme/garage_theme.dart';
import 'package:garage/core/widgets/async_value_view.dart';
import 'package:garage/core/widgets/empty_state_art.dart';

Future<void> pumpEmpty(
  WidgetTester tester, {
  EmptyStateMotif? motif = EmptyStateMotif.document,
  Size surface = const Size(400, 900),
  double textScale = 1,
  Brightness brightness = Brightness.dark,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = surface;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? GarageTheme.dark()
          : GarageTheme.light(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Center(
              child: EmptyState(motif: motif, message: 'Nothing here yet'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a motif draws above the sentence', (tester) async {
    await pumpEmpty(tester);

    expect(find.byType(EmptyStateArt), findsOneWidget);
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  testWidgets('an empty state without one is unchanged', (tester) async {
    // Nine screens had an empty state before this existed and keep it.
    await pumpEmpty(tester, motif: null);

    expect(find.byType(EmptyStateArt), findsNothing);
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  group('the art yields to the words', () {
    testWidgets('a short window drops it', (tester) async {
      // A landscape phone: the sentence and its button are what the person
      // came for, and a drawing on top is what pushes them off the screen.
      await pumpEmpty(tester, surface: const Size(800, 400));

      expect(find.byType(EmptyStateArt), findsNothing);
      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    testWidgets('and so does large text', (tester) async {
      await pumpEmpty(tester, textScale: 2);

      expect(find.byType(EmptyStateArt), findsNothing);
    });

    testWidgets('but an ordinary phone keeps it', (tester) async {
      await pumpEmpty(tester, surface: const Size(400, 800), textScale: 1.2);

      expect(find.byType(EmptyStateArt), findsOneWidget);
    });
  });

  group('every motif', () {
    for (final motif in EmptyStateMotif.values) {
      testWidgets('${motif.name} paints without an exception', (tester) async {
        await pumpEmpty(tester, motif: motif);

        expect(find.byType(EmptyStateArt), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('${motif.name} paints in the light theme too', (
        tester,
      ) async {
        // The colours come from the tokens rather than from a second copy of
        // the drawing, which is the whole reason it is painted and not an
        // imported asset.
        await pumpEmpty(tester, motif: motif, brightness: Brightness.light);

        expect(tester.takeException(), isNull);
      });
    }
  });

  test('the art carries no hex of its own', () {
    // `garage_tokens.dart` is the only file allowed raw colour literals, and
    // a drawing is exactly where a stray #FFB020 would look reasonable.
    final source = const LineSplitter().convert(
      File('lib/core/widgets/empty_state_art.dart').readAsStringSync(),
    );

    expect(
      source.where(
        (line) => RegExp(r'0x[fF][fF][0-9a-fA-F]{6}').hasMatch(line),
      ),
      isEmpty,
    );
  });
}
