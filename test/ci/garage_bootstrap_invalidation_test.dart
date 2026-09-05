import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Startup fetches households and vehicles in one request
/// (`garageBootstrapProvider`), and `myHouseholdsProvider`,
/// `allVehiclesProvider` and everything under them are now *derived* from it.
///
/// That makes one habit dangerous. `ref.invalidate(allVehiclesProvider)` reads
/// exactly as it always did and still compiles, but a derived provider holds
/// no request to repeat: it rebuilds against the bootstrap's cached value and
/// returns the same list it just returned. The car somebody added would not
/// appear, the screen would look merely slow, and nothing would fail.
///
/// There is no type that can catch this, so the source is checked instead.
/// Invalidate `garageBootstrapProvider`; it costs the same single round trip.
void main() {
  const derived = [
    'allVehiclesProvider',
    'vehiclesProvider',
    'archivedVehiclesProvider',
    'myHouseholdsProvider',
  ];

  test('nothing invalidates a provider derived from the bootstrap', () {
    final offenders = <String>[];

    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        for (final provider in derived) {
          // Both spellings Riverpod offers, and the cascade form the codebase
          // uses when it invalidates several at once.
          if (line.contains('invalidate($provider)') ||
              line.contains('refresh($provider)') ||
              line.contains('.invalidate($provider')) {
            offenders.add('${file.path}:${i + 1}: ${line.trim()}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'these providers are derived from garageBootstrapProvider and hold '
          'no request of their own, so invalidating one silently refreshes '
          'nothing — invalidate garageBootstrapProvider instead',
    );
  });
}
