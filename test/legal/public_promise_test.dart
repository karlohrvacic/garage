import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app makes promises in public: on the About screen, on the features
/// page, in the README and in the tester invitation. Decision 155 retired the
/// one that said there would never be a paid tier, and kept the ones that
/// hold whatever a tier looks like. This is what stops the old wording coming
/// back through a translation or a copy-paste.
void main() {
  final surfaces = <String, String>{
    for (final file in Directory('lib/l10n').listSync().whereType<File>())
      if (file.path.endsWith('.arb')) file.path: file.readAsStringSync(),
    for (final file in Directory('web').listSync().whereType<File>())
      if (file.path.endsWith('.html')) file.path: file.readAsStringSync(),
    'README.md': File('README.md').readAsStringSync(),
    'docs/RUNBOOK-closed-testing.md': File(
      'docs/RUNBOOK-closed-testing.md',
    ).readAsStringSync(),
  };

  // The retired promise, in every language it was made in.
  const retired = [
    'no subscription',
    'no locked features',
    'is the whole app',
    'bez pretplate',
    'bez oglasa i pretplate',
    'zaključanih funkcija',
    'je cijela aplikacija',
    'niente abbonamento',
    'funzioni bloccate',
    "è tutta l'app",
  ];

  for (final entry in surfaces.entries) {
    test('${entry.key} does not promise there will never be a paid tier', () {
      // Prose wraps, so "no\nsubscription" has to read as "no subscription".
      final text = entry.value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      expect(retired.where(text.contains), isEmpty);
    });
  }

  // Positive control: the promise still exists and still rules out ads, so
  // the checks above cannot be passed by deleting the promise altogether.
  const noAds = {
    'lib/l10n/app_en.arb': 'ads',
    'lib/l10n/app_hr.arb': 'oglas',
    'lib/l10n/app_it.arb': 'pubblicità',
  };

  for (final entry in noAds.entries) {
    test('${entry.key} still promises no ads', () {
      final arb = jsonDecode(surfaces[entry.key]!) as Map<String, dynamic>;
      final promise = (arb['aboutPromiseFree'] as String).toLowerCase();
      expect(promise, contains(entry.value));
    });
  }
}
