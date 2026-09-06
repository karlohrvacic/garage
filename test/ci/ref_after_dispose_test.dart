import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `ref` is unusable the moment a widget starts going away.
///
/// Riverpod throws `Bad state: Using "ref" when a widget is about to or has
/// been unmounted is unsafe` — and it throws it from inside `dispose`, where
/// the stack points at cleanup code and not at the read that caused it. This
/// has now bitten twice: `syncNotifications` reading providers after an
/// `await`, and the observation sheet's own attachment cleanup.
///
/// The rule is the same in both places: **capture what you need while the
/// widget is alive.** A `late final` initialiser does not count — if nothing
/// else touches it, it first runs inside `dispose`.
void main() {
  test('nothing reads a provider from dispose', () {
    final offenders = <String>[];

    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) {
        continue;
      }
      final lines = file.readAsLinesSync();
      var inDispose = false;
      var depth = 0;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!inDispose && line.contains('void dispose()')) {
          inDispose = true;
          depth = 0;
        }
        if (!inDispose) {
          continue;
        }
        depth += '{'.allMatches(line).length - '}'.allMatches(line).length;
        if (line.contains('ref.read(') || line.contains('ref.watch(')) {
          offenders.add('${file.path}:${i + 1}: ${line.trim()}');
        }
        if (depth <= 0 && line.contains('}')) {
          inDispose = false;
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'a WidgetRef is already invalid here — read the provider in '
          'initState and keep it in a field',
    );
  });
}
