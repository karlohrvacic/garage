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

void main() {
  final english = messages('en');
  final croatian = messages('hr');

  test('every English message has a Croatian one', () {
    expect(croatian.keys.toSet(), containsAll(english.keys.toSet()));
  });

  test('Croatian carries no messages English has dropped', () {
    expect(english.keys.toSet(), containsAll(croatian.keys.toSet()));
  });

  test('a translation never quietly drops a placeholder', () {
    for (final entry in english.entries) {
      final translated = croatian[entry.key];
      if (translated == null) {
        continue;
      }
      expect(
        placeholders(translated),
        placeholders(entry.value),
        reason: '${entry.key} does not interpolate the same values',
      );
    }
  });

  test('no message is left empty', () {
    for (final map in [english, croatian]) {
      for (final entry in map.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      }
    }
  });

  test('a counted Croatian message uses plural forms', () {
    // Croatian inflects the noun for 1, 2–4, and 5+; a bare "{count} stavki"
    // reads wrong for two of those three.
    for (final entry in croatian.entries) {
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
