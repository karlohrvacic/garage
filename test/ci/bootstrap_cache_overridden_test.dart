import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Startup now reads a cached garage before it fetches one, and that cache
/// lives in `SharedPreferences`.
///
/// In a widget test with no mock values set, `SharedPreferences.getInstance()`
/// never returns. The bootstrap awaits it, so the provider stays loading
/// forever and the test fails as "pumpAndSettle timed out" — a message that
/// points at everything except the cause. Every scope that stands the
/// bootstrap up must therefore hand it a cache that answers.
void main() {
  test('a test that overrides the bootstrap also overrides its cache', () {
    final offenders = <String>[];

    for (final file in Directory('test').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) {
        continue;
      }
      final source = file.readAsStringSync();
      if (source.contains('garageBootstrapRepositoryProvider.overrideWith') &&
          !source.contains('garageBootstrapCacheProvider.overrideWith')) {
        offenders.add(file.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'add garageBootstrapCacheProvider.overrideWithValue('
          'const NoGarageBootstrapCache()) to these scopes, or pump through '
          'test/support/pump_screen.dart, which does it for you',
    );
  });
}
