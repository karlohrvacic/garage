import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every query handed to the read cache turns the client's own retries off.
/// postgrest retries a GET that threw three times, pausing 1, 2 and 4 seconds
/// between attempts, so without this a list opened with no signal shows a
/// spinner for seven seconds before its copy. A cached read added later
/// cannot forget it: the closure has to end in `.retry(enabled: false)`.
void main() {
  test('every cached read turns the client retries off', () {
    final missing = <String>[];
    var sites = 0;
    final files = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) {
          final name = file.uri.pathSegments.last;
          return name.startsWith('supabase_') &&
              name.endsWith('_repository.dart');
        });
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      // A comment inside the closure may hold a bracket; the call cannot.
      final source = file.readAsStringSync().replaceAll(
        RegExp(r'//[^\n]*'),
        '',
      );
      for (final match in '_cache.rows('.allMatches(source)) {
        sites++;
        final call = source.substring(match.start, _callEnd(source, match));
        if (!call.contains('.retry(enabled: false)')) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length;
          missing.add('$name:${line + 1}');
        }
      }
    }
    expect(sites, greaterThan(0), reason: 'no cached read found; regex rot?');
    expect(
      missing,
      isEmpty,
      reason:
          'end the query handed to _cache.rows with .retry(enabled: false): '
          'the client would otherwise retry for seven seconds before the '
          'copy is served',
    );
  });
}

/// The index just past the bracket that closes the call opened at [match].
int _callEnd(String source, Match match) {
  var depth = 0;
  for (var i = match.end - 1; i < source.length; i++) {
    switch (source[i]) {
      case '(':
        depth++;
      case ')':
        depth--;
        if (depth == 0) {
          return i + 1;
        }
    }
  }
  fail('unbalanced brackets after ${match.group(0)} at ${match.start}');
}
