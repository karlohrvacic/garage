import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/adaptive.dart';
import 'package:garage/core/widgets/discard_guard.dart';
import 'package:garage/l10n/app_localizations.dart';

Future<TextEditingController> pumpGuarded(WidgetTester tester) async {
  final controller = TextEditingController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: Column(
                    children: [
                      DiscardGuard(controllers: [controller]),
                      TextField(controller: controller),
                      const Text('sheet'),
                    ],
                  ),
                ),
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
  return controller;
}

void main() {
  testWidgets('an entry sheet cannot be flicked shut past the guard', (
    tester,
  ) async {
    // Drag-to-close pops without asking the route; Escape, the barrier and
    // Back all ask. The sheets turn the drag off.
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAdaptiveEntrySheet<void>(
                context,
                (_) => SizedBox(
                  height: 600,
                  child: Column(
                    children: [
                      DiscardGuard(controllers: [controller]),
                      TextField(controller: controller),
                      const Text('sheet'),
                    ],
                  ),
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
    await tester.enterText(find.byType(TextField), '45200');
    await tester.pump();

    await tester.fling(find.text('sheet'), const Offset(0, 400), 1500);
    await tester.pumpAndSettle();

    expect(find.text('sheet'), findsOneWidget);
    expect(find.text('45200'), findsOneWidget);
  });

  testWidgets('an untouched sheet closes without a word', (tester) async {
    await pumpGuarded(tester);
    await Navigator.of(tester.element(find.text('sheet'))).maybePop();
    await tester.pumpAndSettle();

    expect(find.text('sheet'), findsNothing);
    expect(find.text('Discard what you typed?'), findsNothing);
  });

  testWidgets('tapping into a prefilled field is not typing', (tester) async {
    // Selecting the prefill on focus notifies the controller; a guard that
    // counted any notification asked about a sheet nobody had typed in.
    final controller = await pumpGuarded(tester);
    controller.text = '1.45';
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
    await tester.pump();

    await Navigator.of(tester.element(find.text('sheet'))).maybePop();
    await tester.pumpAndSettle();

    expect(find.text('sheet'), findsNothing);
    expect(find.text('Discard what you typed?'), findsNothing);
  });

  testWidgets('a field the sheet filled in itself does not count', (
    tester,
  ) async {
    final controller = await pumpGuarded(tester);
    controller.text = 'prefilled';
    await tester.pump();
    await Navigator.of(tester.element(find.text('sheet'))).maybePop();
    await tester.pumpAndSettle();

    expect(find.text('sheet'), findsNothing);
  });

  testWidgets('typed text asks first, and Keep editing keeps it', (
    tester,
  ) async {
    await pumpGuarded(tester);
    await tester.enterText(find.byType(TextField), '45200');
    await tester.pump();
    await Navigator.of(tester.element(find.text('sheet'))).maybePop();
    await tester.pumpAndSettle();

    expect(find.text('Discard what you typed?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('sheet'), findsOneWidget);
    expect(find.text('45200'), findsOneWidget);
  });

  testWidgets('and Discard lets it go', (tester) async {
    await pumpGuarded(tester);
    await tester.enterText(find.byType(TextField), '45200');
    await tester.pump();
    await Navigator.of(tester.element(find.text('sheet'))).maybePop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('discard-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('sheet'), findsNothing);
  });
}
