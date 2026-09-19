import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/theme/garage_theme.dart';
import 'package:garage/core/widgets/text_prompt.dart';
import 'package:garage/l10n/app_localizations.dart';

Future<void> pumpPrompt(
  WidgetTester tester, {
  Size size = const Size(400, 800),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: GarageTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showTextPrompt(
              context,
              title: 'New garage',
              label: 'Name',
              confirmLabel: 'Save',
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

/// Where the prompt's surface is. The `AlertDialog` widget itself fills the
/// screen — its render box is the padding that makes room for the keyboard —
/// so the box to measure is the Material it draws inside that.
Rect surface(WidgetTester tester) => tester.getRect(
  find
      .descendant(of: find.byType(AlertDialog), matching: find.byType(Material))
      .first,
);

void main() {
  group('a text prompt on a phone', () {
    testWidgets('sits where the keyboard cannot reach it', (tester) async {
      // Its field takes focus as it opens, so the keyboard always follows.
      // Centred, the prompt appeared and a beat later slid up the screen to
      // make room — two movements for one tap. It sits in the top part of
      // the screen instead, and the keyboard opens underneath it.
      await pumpPrompt(tester);
      final before = surface(tester).top;

      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();

      expect(surface(tester).top, before);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is not pinned to the top edge', (tester) async {
      await pumpPrompt(tester);

      expect(surface(tester).top, greaterThan(80));
    });
  });

  testWidgets('on a wide window it stays centred like every other dialog', (
    tester,
  ) async {
    await pumpPrompt(tester, size: const Size(1000, 800));

    expect(surface(tester).center.dy, closeTo(400, 1));
  });
}
