import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/theme/garage_theme.dart';
import 'package:garage/core/widgets/confirm_delete.dart';
import 'package:garage/l10n/app_localizations.dart';

/// Pumps a button that runs [ask], on a window [size] at [textScale].
Future<void> _pumpAsking(
  WidgetTester tester,
  Future<void> Function(BuildContext context) ask, {
  Size size = const Size(400, 800),
  double textScale = 1,
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
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ask(context),
                child: const Text('ask'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ask'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('what cannot be undone is confirmed in red', (tester) async {
    bool? answer;
    await _pumpAsking(tester, (context) async {
      answer = await confirmDestructive(
        context,
        body: 'Withdraw this code?',
        confirmLabel: 'Withdraw',
      );
    });

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Withdraw'),
    );
    expect(
      button.style?.backgroundColor?.resolve({}),
      tester.element(find.byType(AlertDialog)).tokens.danger,
    );

    await tester.tap(find.text('Withdraw'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  testWidgets('a question needs no title when the body asks it', (
    tester,
  ) async {
    // Five of the hand-built confirmations had none; the shared one made them
    // choose between a title that repeated the question and no helper.
    await _pumpAsking(tester, (context) async {
      await confirmAction(
        context,
        body: 'Merge into this garage?',
        confirmLabel: 'Merge',
      );
    });

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.title, isNull);
    expect(find.text('Merge into this garage?'), findsOneWidget);
  });

  testWidgets('Cancel is an answer too', (tester) async {
    bool? answer;
    await _pumpAsking(tester, (context) async {
      answer = await confirmDestructive(
        context,
        title: 'Leave garage',
        body: 'You will lose access to its vehicles.',
        confirmLabel: 'Leave garage',
      );
    });

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
  });

  testWidgets('the confirming button can be found by key', (tester) async {
    await _pumpAsking(tester, (context) async {
      await confirmDestructive(
        context,
        body: 'Give this car back?',
        confirmLabel: 'Give the car back',
        confirmKey: const Key('give-back-confirm'),
      );
    });

    expect(find.byKey(const Key('give-back-confirm')), findsOneWidget);
  });

  testWidgets('a long question scrolls at a large font on a small phone', (
    tester,
  ) async {
    await _pumpAsking(
      tester,
      (context) async {
        await confirmDestructive(
          context,
          title: 'Delete all data',
          body: List.filled(12, 'Every vehicle and entry goes.').join(' '),
          confirmLabel: 'Delete everything',
        );
      },
      size: const Size(320, 480),
      textScale: 2,
    );

    // A dialog that does not scroll does not throw either: it clips the
    // question, and the end of it is simply not there to read.
    expect(
      find.ancestor(
        of: find.textContaining('Every vehicle'),
        matching: find.byType(Scrollable),
      ),
      findsOneWidget,
    );
    expect(find.text('Delete everything').hitTestable(), findsOneWidget);
  });

  testWidgets('a notice has one way out and nothing to decide', (tester) async {
    var closed = false;
    await _pumpAsking(tester, (context) async {
      await showNotice(
        context,
        content: const Text('These garages keep different currencies.'),
      );
      closed = true;
    });

    expect(find.text('These garages keep different currencies.'), findsOne);
    expect(find.text('Cancel'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
  });

  testWidgets('and scrolls too', (tester) async {
    await _pumpAsking(
      tester,
      (context) => showNotice(
        context,
        title: 'Invite',
        content: SelectableText(List.filled(30, 'Join my garage.').join(' ')),
      ),
      size: const Size(320, 480),
      textScale: 2,
    );

    expect(
      find.ancestor(
        of: find.textContaining('Join my garage'),
        matching: find.byType(Scrollable),
      ),
      findsWidgets,
    );
    expect(find.text('Close').hitTestable(), findsOneWidget);
  });
}
