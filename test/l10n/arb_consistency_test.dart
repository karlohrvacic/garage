import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The ARB files as maps of key → value, metadata (`@…`) stripped.
Map<String, String> messages(String locale) {
  final raw = jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync());
  return {
    for (final entry in (raw as Map<String, dynamic>).entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value as String,
  };
}

/// Placeholder names used by a message, e.g. `{previous}` → `previous`.
/// ICU machinery — `plural`, `select`, and exact-match selectors like `=1` —
/// is not a placeholder.
Set<String> placeholders(String message) {
  return {
    // A value interpolated on its own: {previous}
    for (final match in RegExp(r'\{(\w+)\}').allMatches(message))
      match.group(1)!,
    // The argument a plural or select switches on: {count, plural, …}
    for (final match in RegExp(
      r'\{(\w+)\s*,\s*(?:plural|select)',
    ).allMatches(message))
      match.group(1)!,
  }..removeWhere((name) => int.tryParse(name) != null);
}

/// Every locale in `lib/l10n/`, read from the directory rather than listed
/// here: a language whose ARB ships but which nobody added to a hand-kept list
/// would be checked by nothing at all, which is the worst of both.
List<String> get locales {
  return Directory('lib/l10n')
      .listSync()
      .map((file) => RegExp(r'app_(\w+)\.arb$').firstMatch(file.path))
      .nonNulls
      .map((match) => match.group(1)!)
      .toList()
    ..sort();
}

void main() {
  final english = messages('en');
  final translations = {
    for (final locale in locales)
      if (locale != 'en') locale: messages(locale),
  };

  test('there is more than one language, and English is one of them', () {
    // Guards the guard: a listing that silently came back empty would make
    // every loop below pass without checking anything.
    expect(locales, contains('en'));
    expect(translations, isNotEmpty);
  });

  test('no key is declared twice', () {
    // JSON decoding keeps the last one, so a duplicate silently discards a
    // translation and leaves the file disagreeing with itself.
    for (final locale in locales) {
      final lines = File('lib/l10n/app_$locale.arb').readAsLinesSync();
      final keys = <String>[];
      for (final line in lines) {
        final match = RegExp(r'^  "(@?[A-Za-z0-9_]+)": ').firstMatch(line);
        if (match != null) {
          keys.add(match.group(1)!);
        }
      }
      final duplicates = <String>{
        for (final key in keys)
          if (keys.where((k) => k == key).length > 1) key,
      };
      expect(duplicates, isEmpty, reason: 'app_$locale.arb');
    }
  });

  test('every English message is translated everywhere', () {
    for (final entry in translations.entries) {
      expect(
        entry.value.keys.toSet(),
        containsAll(english.keys.toSet()),
        reason: 'app_${entry.key}.arb is missing messages',
      );
    }
  });

  test('a translation carries no message English has dropped', () {
    for (final entry in translations.entries) {
      expect(
        english.keys.toSet(),
        containsAll(entry.value.keys.toSet()),
        reason: 'app_${entry.key}.arb has messages English does not',
      );
    }
  });

  test('a translation never quietly drops a placeholder', () {
    for (final locale in translations.entries) {
      for (final entry in english.entries) {
        final translated = locale.value[entry.key];
        if (translated == null) {
          continue;
        }
        expect(
          placeholders(translated),
          placeholders(entry.value),
          reason:
              '${entry.key} does not interpolate the same values in '
              'app_${locale.key}.arb',
        );
      }
    }
  });

  test('no message is left empty', () {
    for (final locale in [MapEntry('en', english), ...translations.entries]) {
      for (final entry in locale.value.entries) {
        expect(
          entry.value.trim(),
          isNotEmpty,
          reason: '${entry.key} in app_${locale.key}.arb',
        );
      }
    }
  });

  test('no translation punctuates with a dash', () {
    // English uses the em dash for its asides and keeps them. In Croatian and
    // in Italian the same dash reads as English punctuation borrowed whole:
    // both languages have a colon, a comma, a full stop and a parenthesis
    // that say the thing properly, and the owner of this app asked for them.
    // Ranges included — "od {from} do {to}" is how a Croatian says it.
    for (final locale in translations.entries) {
      for (final entry in locale.value.entries) {
        expect(
          entry.value.contains('—') || entry.value.contains('–'),
          isFalse,
          reason:
              '${entry.key} in app_${locale.key}.arb punctuates with a dash: '
              '"${entry.value}"',
        );
      }
    }
  });

  test('a counted message uses plural forms in every language', () {
    // Croatian inflects the noun for 1, 2–4 and 5+; a bare "{count} stavki"
    // reads wrong for two of those three. Italian only splits one from the
    // rest, but "1 voci" is still wrong, so the rule is the same everywhere.
    for (final entry in translations.values.expand((map) => map.entries)) {
      if (!placeholders(entry.value).contains('count') &&
          !placeholders(entry.value).contains('days')) {
        continue;
      }
      expect(
        entry.value,
        contains('plural,'),
        reason: '${entry.key} interpolates a number without plural forms',
      );
    }
  });
}
