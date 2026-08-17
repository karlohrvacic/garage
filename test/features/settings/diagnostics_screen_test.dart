import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/errors/failure_log.dart';
import 'package:garage/features/settings/screens/diagnostics_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/pump_screen.dart';

/// Records what the app tried to hand to the share sheet.
class SharedTexts {
  final List<String> texts = [];

  Future<void> call(String text) async => texts.add(text);
}

Future<SharedTexts> pumpDiagnostics(
  WidgetTester tester, {
  Locale? locale,
}) async {
  final shared = SharedTexts();
  await pumpScreen(
    tester,
    const DiagnosticsScreen(),
    initialLocation: '/diagnostics',
    locale: locale,
    overrides: [diagnosticsShareProvider.overrideWithValue(shared.call)],
  );
  await tester.pumpAndSettle();
  return shared;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await clearRecordedFailures();
  });

  testWidgets('shows what went wrong, cause and all', (tester) async {
    reportFailure(
      const AppFailure(
        kind: AppFailureKind.permission,
        debugMessage: '42501: new row violates row-level security policy',
      ),
    );

    await pumpDiagnostics(tester);

    expect(
      find.textContaining('42501: new row violates row-level security policy'),
      findsOneWidget,
      reason:
          'the generic sentence the user already saw is the thing this screen '
          'exists to go behind',
    );
  });

  testWidgets('says so plainly when nothing has gone wrong', (tester) async {
    await pumpDiagnostics(tester);

    expect(find.text('Nothing has gone wrong on this device.'), findsOneWidget);
  });

  testWidgets('the newest failure is the one you see first', (tester) async {
    reportFailure(
      const AppFailure(kind: AppFailureKind.network, debugMessage: 'older'),
    );
    reportFailure(
      const AppFailure(kind: AppFailureKind.network, debugMessage: 'newer'),
    );

    await pumpDiagnostics(tester);

    final newest = tester.getTopLeft(find.textContaining('newer')).dy;
    final oldest = tester.getTopLeft(find.textContaining('older')).dy;
    expect(
      newest,
      lessThan(oldest),
      reason: 'a report is written about the thing that just happened',
    );
  });

  testWidgets('hands the whole log to the share sheet, which is the point', (
    tester,
  ) async {
    reportFailure(
      const AppFailure(
        kind: AppFailureKind.auth,
        debugMessage: 'audience mismatch',
      ),
    );

    final shared = await pumpDiagnostics(tester);
    await tester.tap(find.byIcon(Icons.ios_share_outlined));
    await tester.pumpAndSettle();

    expect(shared.texts, hasLength(1));
    expect(
      shared.texts.single,
      contains('audience mismatch'),
      reason:
          'a tester who cannot get the text out is back to "it said something '
          'went wrong", which is where this whole exercise started',
    );
  });

  testWidgets('the shared text names the version it came from', (tester) async {
    reportFailure(const AppFailure(kind: AppFailureKind.network));

    final shared = await pumpDiagnostics(tester);
    await tester.tap(find.byIcon(Icons.ios_share_outlined));
    await tester.pumpAndSettle();

    expect(
      shared.texts.single,
      contains('Garage'),
      reason: 'a log that does not say which build produced it dates badly',
    );
  });

  testWidgets('clearing empties the screen', (tester) async {
    reportFailure(
      const AppFailure(kind: AppFailureKind.network, debugMessage: 'timed out'),
    );

    await pumpDiagnostics(tester);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.textContaining('timed out'), findsNothing);
    expect(find.text('Nothing has gone wrong on this device.'), findsOneWidget);
  });

  testWidgets('says the log stays on the device, because people will ask', (
    tester,
  ) async {
    reportFailure(const AppFailure(kind: AppFailureKind.network));

    await pumpDiagnostics(tester);

    expect(
      find.textContaining('only on this device'),
      findsOneWidget,
      reason:
          'an app that promises no tracking has to say what a list of errors '
          'is doing on it',
    );
  });

  testWidgets('reads naturally in Croatian too', (tester) async {
    await pumpDiagnostics(tester, locale: const Locale('hr'));

    expect(find.text('Dijagnostika'), findsOneWidget);
  });

  testWidgets('a long failure line does not overflow a narrow phone', (
    tester,
  ) async {
    reportFailure(
      AppFailure(
        kind: AppFailureKind.unknown,
        debugMessage: 'PostgrestException ${'very long detail ' * 20}',
      ),
    );

    final shared = SharedTexts();
    await pumpScreen(
      tester,
      const DiagnosticsScreen(),
      initialLocation: '/diagnostics',
      surface: const Size(320, 640),
      overrides: [diagnosticsShareProvider.overrideWithValue(shared.call)],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
