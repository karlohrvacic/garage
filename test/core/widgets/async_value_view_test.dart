import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/theme/garage_theme.dart';
import 'package:garage/core/widgets/async_value_view.dart';
import 'package:garage/l10n/app_localizations.dart';

Widget host(Widget child) {
  return MaterialApp(
    theme: GarageTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('shows a spinner while loading', (tester) async {
    await tester.pumpWidget(
      host(
        AsyncValueView<int>(
          value: const AsyncValue.loading(),
          data: (value) => Text('$value'),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the data when loaded', (tester) async {
    await tester.pumpWidget(
      host(
        AsyncValueView<int>(
          value: const AsyncValue.data(42),
          data: (value) => Text('$value'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('shows a localized message and retry on failure', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      host(
        AsyncValueView<int>(
          value: AsyncValue.error(
            const AppFailure(kind: AppFailureKind.network),
            StackTrace.empty,
          ),
          data: (value) => Text('$value'),
          onRetry: () => retried = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No connection. Check your network and retry.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('shows the empty builder for an empty list', (tester) async {
    await tester.pumpWidget(
      host(
        AsyncValueView<List<int>>(
          value: const AsyncValue.data(<int>[]),
          data: (value) => Text('${value.length} items'),
          empty: () => const Text('nothing'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('nothing'), findsOneWidget);
  });

  group('an empty state on a short window at twice the text size', () {
    // Two sentences and a button, on the shortest window the app supports,
    // at the largest text Android offers. It overflowed by 240 pixels.
    const message =
        'Nothing recorded yet. Add the first one and it shows up here, with '
        'the date it runs out and a reminder before it does.';

    Widget atTwiceTheTextSize(Widget child) => MediaQuery(
      data: const MediaQueryData(
        size: Size(320, 640),
        textScaler: TextScaler.linear(2),
      ),
      child: host(child),
    );

    Future<void> pumpShort(WidgetTester tester, Widget child) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(atTwiceTheTextSize(child));
      await tester.pumpAndSettle();
    }

    testWidgets('scrolls rather than overflowing', (tester) async {
      await pumpShort(
        tester,
        AsyncValueView<List<int>>(
          value: const AsyncValue.data(<int>[]),
          data: (value) => const SizedBox(),
          empty: () => EmptyState(
            message: message,
            action: FilledButton(
              onPressed: () {},
              child: const Text('Add the first one'),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Add the first one'), findsOneWidget);
    });

    testWidgets('and still fits a sliver that measures it', (tester) async {
      // The stations screen puts one in a SliverFillRemaining, which asks its
      // child how tall it wants to be. The first attempt at this fix used a
      // LayoutBuilder, which cannot answer.
      await pumpShort(
        tester,
        const CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(message: message),
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
