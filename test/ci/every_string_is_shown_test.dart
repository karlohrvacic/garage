import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every message in `app_en.arb` is rendered by something in `lib/`.
///
/// A string is the cheapest half of a feature and the half that gets written
/// first, so a message nobody renders is usually a feature nobody finished. A
/// sweep found sixteen at once, and behind them: two route-trend dropdowns
/// filtering by departure and driver with no labels on them, a borrowed car
/// that never said when it goes back, a drive in progress that never said who
/// started it, an observation that knew which journey it happened on and never
/// showed it, a tank that knew the date it runs dry, and an admin hand-over
/// that happened silently because the sentence explaining it was never shown.
///
/// The other half were leftovers — a message for a state the UI now prevents,
/// a heading for a section that was built somewhere else — and those were
/// deleted. Both outcomes are fine. What is not fine is a third state where
/// nobody knows which it is.
///
/// This cannot see a string that *is* referenced but never reaches a screen.
/// It is the floor, not the ceiling.
void main() {
  test('no message is written and never shown', () {
    final arb =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final keys = arb.keys.where((key) => !key.startsWith('@'));

    final source = StringBuffer();
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      // The generated delegates name every key by definition.
      if (file.path.contains('/l10n/')) continue;
      source.writeln(file.readAsStringSync());
    }
    final code = source.toString();

    final unused = [
      for (final key in keys)
        if (!RegExp('\\b${RegExp.escape(key)}\\b').hasMatch(code)) key,
    ];

    expect(
      unused,
      isEmpty,
      reason:
          'these messages exist in three languages and nothing renders them: '
          '$unused. Either wire up the feature they were written for, or '
          'delete them from every app_*.arb.',
    );
  });
}
