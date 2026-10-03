import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/localization/garage_localizations.dart';
import 'package:garage/l10n/app_localizations.dart';

Future<BuildContext> pumpIn(WidgetTester tester, Locale locale) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: garageLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return captured;
}

void main() {
  for (final (code, material, cupertino) in [
    ('en', MaterialLocalizationEn, CupertinoLocalizationEn),
    ('hr', MaterialLocalizationHr, CupertinoLocalizationHr),
    ('it', MaterialLocalizationIt, CupertinoLocalizationIt),
  ]) {
    testWidgets('$code gets Material\'s and Cupertino\'s own $code', (
      tester,
    ) async {
      final context = await pumpIn(tester, Locale(code));

      expect(MaterialLocalizations.of(context).runtimeType, material);
      expect(CupertinoLocalizations.of(context).runtimeType, cupertino);
      expect(AppLocalizations.of(context)!.localeName, code);
    });
  }

  testWidgets('a date in Croatian is written the Croatian way', (tester) async {
    final context = await pumpIn(tester, const Locale('hr'));

    expect(
      MaterialLocalizations.of(
        context,
      ).formatCompactDate(DateTime(2026, 9, 19)),
      '19. 09. 2026.',
    );
  });

  // Flutter's global delegates choose among every language it translates at
  // run time, so all of them are compiled in; the app's own list is the only
  // one the app may hand to MaterialApp (decision 189).
  test('the app builds with its own delegates, not Flutter\'s global ones', () {
    final offenders = [
      for (final entity in Directory('lib').listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            !entity.path.contains('/l10n/') &&
            RegExp(
              r'AppLocalizations\.localizationsDelegates|'
              r'Global(Material|Cupertino)Localizations\.delegate',
            ).hasMatch(entity.readAsStringSync()))
          entity.path,
    ];
    expect(offenders, isEmpty);
  });

  // gen-l10n adds a language to supportedLocales with its ARB file, while the
  // delegates name theirs by hand. A language they leave out has no Material
  // words, and every Material widget in it fails; one missing from a
  // delegate's switch is quietly given English.
  test(
    'every language the app ships in gets Material\'s and Cupertino\'s words',
    () async {
      final material = garageLocalizationsDelegates
          .whereType<LocalizationsDelegate<MaterialLocalizations>>()
          .single;
      final cupertino = garageLocalizationsDelegates
          .whereType<LocalizationsDelegate<CupertinoLocalizations>>()
          .single;
      for (final locale in AppLocalizations.supportedLocales) {
        for (final delegate in garageLocalizationsDelegates) {
          expect(
            delegate.isSupported(locale),
            isTrue,
            reason: '${delegate.runtimeType} does not support $locale',
          );
        }
        if (locale.languageCode == 'en') {
          continue;
        }
        expect(
          await material.load(locale),
          isNot(isA<MaterialLocalizationEn>()),
          reason: 'Material gives $locale English words',
        );
        expect(
          await cupertino.load(locale),
          isNot(isA<CupertinoLocalizationEn>()),
          reason: 'Cupertino gives $locale English words',
        );
      }
    },
  );
}
