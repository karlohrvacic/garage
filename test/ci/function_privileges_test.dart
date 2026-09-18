import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What a function in `public` ends up as once every migration has run, read
/// statically the way `rls_enabled_test.dart` reads the tables.
///
/// The production linter found both of these the day after decision 171
/// closed every function to `anon`: one function with no `search_path` of
/// its own, and eight trigger functions still granted to `authenticated`.
/// Neither is a hole today, and both are the shape a new function takes when
/// its author copies the wrong neighbour, which is why the check is here and
/// not in the linter alone.
///
/// A `create or replace` replaces a function's settings along with its body,
/// so what counts is the *last* definition, and an `alter ... set search_path`
/// only if it comes after that.
void main() {
  final files =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final sql = files.map((file) => file.readAsStringSync()).join('\n');

  /// Each function's latest definition, with everything up to the `;` that
  /// ends the statement: the body is dollar-quoted, so the `;` after the
  /// closing quote is the one that counts.
  final definitions = <String, String>{};
  for (final match in RegExp(
    r'create (?:or replace )?function public\.(\w+)\s*\(',
    caseSensitive: false,
  ).allMatches(sql)) {
    final name = match.group(1)!;
    final quote = RegExp(r'\$\w*\$').firstMatch(sql.substring(match.end));
    final bodyStart = match.end + quote!.end;
    final bodyEnd = sql.indexOf(quote.group(0)!, bodyStart);
    final end = sql.indexOf(';', bodyEnd + quote.group(0)!.length);
    definitions[name] = sql.substring(match.start, end);
  }

  for (final match in RegExp(
    r'alter function public\.(\w+)\s*\([^)]*\)\s+set search_path',
    caseSensitive: false,
  ).allMatches(sql)) {
    if (_after(sql, match.start, definitions, match.group(1)!)) {
      _alteredSearchPath.add(match.group(1)!);
    }
  }
  for (final match in RegExp(
    r'revoke execute on function public\.(\w+)\s*\([^)]*\)\s+from ([^;]+);',
    caseSensitive: false,
  ).allMatches(sql)) {
    if (match.group(2)!.contains('authenticated') &&
        _after(sql, match.start, definitions, match.group(1)!)) {
      _revokedFromAuthenticated.add(match.group(1)!);
    }
  }

  test('the migrations are actually being read', () {
    expect(definitions.keys, contains('create_household'));
    expect(definitions.length, greaterThan(20));
  });

  test('every function pins its search_path', () {
    // Without one, a function resolves unqualified names through the caller's
    // search_path, which the caller controls: the classic way to make a
    // security-definer function run somebody else's code. The convention
    // here is `set search_path = public`.
    final unpinned = [
      for (final MapEntry(key: name, value: definition) in definitions.entries)
        if (!definition.contains('search_path') &&
            !_alteredSearchPath.contains(name))
          name,
    ];

    expect(unpinned, isEmpty);
  });

  test('a trigger function is granted to nobody who could call it', () {
    // Postgres checks EXECUTE on a trigger function when the trigger is
    // created, not when a write fires it, so the grant does nothing for the
    // app and leaves the function callable through the API by name. The
    // linter lists every one still granted to `authenticated`.
    final triggers = [
      for (final MapEntry(key: name, value: definition) in definitions.entries)
        if (RegExp(
          r'returns\s+trigger',
          caseSensitive: false,
        ).hasMatch(definition))
          name,
    ];
    expect(triggers, contains('pin_created_by'));

    expect(
      triggers.where((name) => !_revokedFromAuthenticated.contains(name)),
      isEmpty,
      reason:
          'revoke execute ... from authenticated (and anon, public) after '
          'the latest definition',
    );
  });
}

final _alteredSearchPath = <String>{};
final _revokedFromAuthenticated = <String>{};

/// Whether [offset] lies after the latest definition of [name].
bool _after(
  String sql,
  int offset,
  Map<String, String> definitions,
  String name,
) {
  final definition = definitions[name];
  return definition != null && sql.lastIndexOf(definition) < offset;
}
