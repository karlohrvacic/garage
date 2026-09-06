import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A reference to `auth.users` added after migration 0033 has to say what
/// happens when that user is deleted.
///
/// `0033` removed the same refusal from every table that existed at the time:
/// a `created_by` referencing `auth.users` with Postgres's default `no action`
/// means the user cannot be deleted while any row points at them, and in-app
/// account deletion is a Play requirement. It only ever failed for a *shared*
/// garage — a solo one cascades away before the reference is checked — so a
/// solo test passes throughout.
///
/// It came back. `vehicle_guest_passes` (0055) was written with
/// `created_by uuid not null references auth.users (id)` and deleting the
/// account of anyone who had lent or borrowed a car failed with "Database
/// error deleting user" until `0059`. That is twice; hence this.
///
/// Migrations up to and including 0033 are exempt: their text still shows the
/// original constraint because 0033 rewrote them in place afterwards.
/// Every `(table, column)` a later migration re-pointed with an explicit
/// delete rule. Migrations are append-only, so a bug fixed forward still reads
/// as a bug in the file that introduced it — the same reason 0033's tables are
/// exempt above.
Set<String> repaired(String sql) {
  final flattened = sql.replaceAll(RegExp(r'\s+'), ' ');
  return {
    for (final match in RegExp(
      r'alter table public\.(\w+) add constraint \w+ '
      r'foreign key \((\w+)\) references auth\.users \(id\) '
      r'on delete (?:set null|cascade)',
      caseSensitive: false,
    ).allMatches(flattened))
      '${match.group(1)}.${match.group(2)}',
  };
}

void main() {
  test('every auth.users reference added after 0033 names its delete rule', () {
    final offenders = <String>[];
    final files = [
      for (final file in Directory('supabase/migrations').listSync())
        if (file is File && file.path.endsWith('.sql')) file,
    ]..sort((a, b) => a.path.compareTo(b.path));

    final fixed = repaired(
      [for (final f in files) f.readAsStringSync()].join('\n'),
    );

    for (final file in files) {
      final number = int.tryParse(
        RegExp(r'(\d{4})_').firstMatch(file.path)?.group(1) ?? '',
      );
      // 0033 is the one-shot pass that fixed everything before it, and its own
      // text quotes the replacement clause.
      if (number == null || number <= 33) {
        continue;
      }
      final lines = file.readAsLinesSync();
      var table = '';
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final created = RegExp(r'create table public\.(\w+)').firstMatch(line);
        if (created != null) {
          table = created.group(1)!;
        }
        if (!line.contains('references auth.users')) {
          continue;
        }
        // The action may sit on the same line or the next one; nothing in
        // this schema spreads it further.
        final statement = '$line ${i + 1 < lines.length ? lines[i + 1] : ''}';
        if (statement.contains('on delete set null') ||
            statement.contains('on delete cascade')) {
          continue;
        }
        final column = RegExp(r'^\s*(\w+)\s+uuid').firstMatch(line)?.group(1);
        if (column != null && fixed.contains('$table.$column')) {
          continue;
        }
        offenders.add('${file.path.split('/').last}:${i + 1}: ${line.trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'a bare reference blocks account deletion for shared garages only, '
          'and reports it as "Database error deleting user". Use '
          '`on delete set null` to keep the row and drop the attribution, or '
          '`on delete cascade` when the row genuinely belongs to the person',
    );
  });
}
