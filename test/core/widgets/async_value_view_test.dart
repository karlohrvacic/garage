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

    expect(find.text('No connection. Check your network and retry.'),
        findsOneWidget);

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
}
