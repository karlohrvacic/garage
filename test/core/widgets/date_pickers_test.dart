import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/date_pickers.dart';
import 'package:garage/l10n/app_localizations.dart';

Future<void> openPicker(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showGarageDatePicker(
              context: context,
              initialDate: DateTime(2026, 9, 4),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            ),
            child: const Text('pick'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('pick'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the week starts on Monday in English, like the planner', (
    tester,
  ) async {
    await openPicker(tester, const Locale('en'));

    // M is the leftmost weekday header; Sunday-first would put an S there.
    final m = tester.getTopLeft(find.text('M').first).dx;
    final firstS = tester.getTopLeft(find.text('S').first).dx;
    expect(m, lessThan(firstS));
  });

  testWidgets(
    'and keeps American formats, so a typed date means what it says',
    (tester) async {
      await openPicker(tester, const Locale('en'));
      // The header of the American picker: "Fri, Sep 4", not "Fri 4 Sept".
      expect(find.text('Fri, Sep 4'), findsOneWidget);
    },
  );

  group('the last date something already logged may carry', () {
    test('is today, because a fill-up next week is a typo', () {
      final now = DateTime(2026, 9, 4, 22, 30);
      expect(
        lastLoggableDate(DateTime(2026, 9, 1), now: now),
        DateTime(2026, 9, 4),
      );
    });

    test('the earliest is 2000, stretched by an older entry', () {
      // A classic car's service history, or a bad import, sits before 2000.
      // The picker asserts if its initial date falls outside its bounds.
      expect(firstLoggableDate(DateTime(2015, 3, 2)), DateTime(2000));
      final old = DateTime(1974, 6, 1);
      expect(firstLoggableDate(old), old);
    });

    test('stretches to an entry that is already dated ahead', () {
      // Imported data has carried future dates. Refusing to open the picker
      // on one would leave the household unable to correct it.
      final now = DateTime(2026, 9, 4, 22, 30);
      final ahead = DateTime(2026, 12, 1);
      expect(lastLoggableDate(ahead, now: now), ahead);
    });
  });
}
