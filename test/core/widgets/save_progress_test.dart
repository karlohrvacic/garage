import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/save_progress.dart';
import 'package:garage/l10n/app_localizations.dart';

Future<void> pumpNote(WidgetTester tester, bool busy) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: StillSavingNote(busy: busy)),
    ),
  );
}

void main() {
  testWidgets('says nothing for the first seconds of a save', (tester) async {
    await pumpNote(tester, true);
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Still saving…'), findsNothing);
  });

  testWidgets('and then says it is still saving', (tester) async {
    // A spinner alone is "it is saving" for five seconds and "it is broken"
    // after ten.
    await pumpNote(tester, true);
    await tester.pump(const Duration(seconds: 6));

    expect(find.text('Still saving…'), findsOneWidget);

    await pumpNote(tester, false);
    await tester.pump();
    expect(find.text('Still saving…'), findsNothing);
  });
}
