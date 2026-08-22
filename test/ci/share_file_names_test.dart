import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every file the app hands to the share sheet must carry an explicit
/// `fileNameOverrides`.
///
/// `XFile.fromData` takes a `name` and then **drops it on every platform
/// except web** — share_plus says so in its own doc comment for
/// `fileNameOverrides` — after which share_plus falls back to
/// `Uuid().v1()`. So a call site that passes only `name:` looks completely
/// correct in review, compiles, runs, and produces `3f9a1c-8e21.pdf` on the
/// device. All three exports did exactly that for the app's whole life.
///
/// Nothing in the type system catches it and no widget test can see it, since
/// the name is only decided inside the plugin. A source check is crude and it
/// is the only thing here that would have noticed.
void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => (path: file.path, text: file.readAsStringSync()))
      .toList();

  test('every share of a generated file names it explicitly', () {
    final offenders = <String>[];
    for (final source in sources) {
      if (!source.text.contains('XFile.fromData')) {
        continue;
      }
      if (!source.text.contains('SharePlus.instance.share')) {
        continue;
      }
      final shares = 'SharePlus.instance.share'.allMatches(source.text).length;
      final overrides = 'fileNameOverrides'.allMatches(source.text).length;
      if (overrides < shares) {
        offenders.add(
          '${source.path}: $shares share(s), $overrides override(s)',
        );
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'a shared XFile.fromData without fileNameOverrides reaches the '
          'device with a UUID for a name',
    );
  });

  test('no export hard-codes a name that carries no date', () {
    // The names come from `exportFileName`, which puts the day in. A literal
    // like 'garage-backup.json' means somebody has gone back to a name that
    // collides with every previous export in the same folder.
    for (final source in sources) {
      for (final literal in const [
        "'garage-backup.json'",
        "'garage-export.csv'",
        "'garage-report.pdf'",
      ]) {
        expect(
          source.text,
          isNot(contains(literal)),
          reason: '${source.path} names an export without a date',
        );
      }
    }
  });
}
