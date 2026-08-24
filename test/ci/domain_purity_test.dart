import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `lib/domain/` is entities and pure logic, and the rule that keeps it that
/// way was stated in CLAUDE.md and enforced by nothing.
///
/// The cost of losing it is not stylistic. Domain code is where the economy,
/// due-date projection, bundling, settlement and tyre-wear rules live, and it
/// is testable in milliseconds precisely because it needs no widget tree, no
/// binding and no pumping. One `package:flutter` import is enough to require
/// `TestWidgetsFlutterBinding` for a function that only does arithmetic, and
/// the erosion is one convenient import at a time — `debugPrint` here, a
/// `Color` there — never a decision anybody makes on purpose.
void main() {
  test('lib/domain imports no Flutter', () {
    final offenders = <String>[];
    for (final file in Directory('lib/domain').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) {
        continue;
      }
      for (final line in file.readAsLinesSync()) {
        // Import lines only: the word may legitimately appear in prose, and
        // this exists to catch a dependency, not a mention of one.
        final directive = line.trimLeft();
        if (!directive.startsWith('import ') &&
            !directive.startsWith('export ')) {
          continue;
        }
        if (directive.contains('package:flutter/') ||
            directive.contains('package:flutter_')) {
          offenders.add('${file.path}: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'the domain layer must stay runnable without a widget binding; '
          'move whatever needs Flutter to lib/core or lib/features',
    );
  });
}
