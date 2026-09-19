import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Merging two garages moves the absorbed garage's rows into the survivor and
/// then deletes it, and every table that belongs to a garage cascades with
/// that delete. So a table added after `merge_households` was written is not
/// merely left out of a merge, it is destroyed by one — silently, in an
/// operation the screen says cannot be undone. Named routes went that way:
/// the function predates them, and a commute's whole trend vanished with the
/// garage that had named it.
///
/// Nothing at runtime can notice a table the function has never heard of, so
/// this reads the migrations instead: every table with a foreign key to
/// `households` has to be handled by the newest `merge_households`, or listed
/// below with the reason it is left to the cascade.
void main() {
  /// Left to the cascade on purpose. The reason is the point of the entry: it
  /// is what the next person has to argue with before adding to this map.
  const leftBehind = {
    'invites':
        'an invite to a garage that no longer exists would admit somebody to '
        'nothing',
    'vehicle_transfers':
        'an offer made from the absorbed garage names a garage that is gone',
    'webhooks':
        'they go the way of the API keys: a hook registered for one garage '
        'would start reporting every car in the combined one',
    'webhook_outbox':
        'events of a garage that is gone, addressed to hooks that go with it; '
        'a merge is not an event either garage is told about',
    'webhook_deliveries':
        'the log of hooks that are not carried, so there is nothing left to '
        'read it under',
  };

  final migrations =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final sources = [
    for (final file in migrations) file.readAsStringSync().toLowerCase(),
  ];

  /// Every spelling of a foreign key to `households`, in lowercased SQL.
  final toGarage = RegExp(r'references\s+(?:public\.)?households\b');
  final createTable = RegExp(
    r'create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?(\w+)\s*\((.*?)\n\);',
    dotAll: true,
  );
  final alterTable = RegExp(
    r'alter\s+table\s+(?:if\s+exists\s+)?(?:only\s+)?(?:public\.)?(\w+)\b([^;]*);',
  );

  Set<String> garageTables() {
    final tables = <String>{};
    for (final sql in sources) {
      for (final match in [
        ...createTable.allMatches(sql),
        ...alterTable.allMatches(sql),
      ]) {
        if (toGarage.hasMatch(match.group(2)!)) {
          tables.add(match.group(1)!);
        }
      }
    }
    return tables;
  }

  /// The body of the newest definition: a later migration replaces the
  /// function whole, so only the last one is what runs. Anchored on `create`,
  /// because a migration that only re-grants the function names it too.
  String mergeFunction() {
    final definition = RegExp(
      r'create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?merge_households\s*\(',
    );
    final sql = sources.lastWhere(definition.hasMatch);
    final start = definition.allMatches(sql).last.start;
    return sql.substring(start, sql.indexOf(r'$$;', start));
  }

  bool mentions(String sql, String table) =>
      RegExp('public\\.$table\\b').hasMatch(sql);

  test('the scan finds the tables a garage owns', () {
    // Guards the guard: a regex that matched nothing would pass everything.
    expect(
      garageTables(),
      containsAll(['vehicles', 'household_members', 'routes']),
    );
  });

  test('and misses no way of pointing a table at a garage', () {
    // The scan reads a foreign key to `households` inside a table definition
    // or an `alter table`, in any case and with or without the schema. One
    // written some other way would hide its table, and a table the scan
    // cannot see is one a merge deletes. So every such reference in the
    // migrations has to be one the scan attributed to a table.
    var references = 0;
    var attributed = 0;
    for (final sql in sources) {
      references += toGarage.allMatches(sql).length;
      for (final match in [
        ...createTable.allMatches(sql),
        ...alterTable.allMatches(sql),
      ]) {
        attributed += toGarage.allMatches(match.group(2)!).length;
      }
    }

    expect(references, greaterThan(0));
    expect(
      attributed,
      references,
      reason:
          'a migration points a table at a garage in a way this cannot read',
    );
  });

  test('a merge handles every table a garage owns, or says why not', () {
    final merge = mergeFunction();

    for (final table in garageTables()) {
      if (leftBehind.containsKey(table)) {
        continue;
      }
      expect(
        mentions(merge, table),
        isTrue,
        reason:
            '$table belongs to a garage and merge_households never mentions '
            'it, so merging deletes every row of it in the absorbed garage. '
            'Move it in a new migration, or add it to leftBehind with a reason',
      );
    }
  });

  test('nothing is excused that is not there to excuse', () {
    final tables = garageTables();
    final merge = mergeFunction();

    for (final table in leftBehind.keys) {
      expect(tables, contains(table), reason: '$table is not a garage table');
      expect(
        mentions(merge, table),
        isFalse,
        reason: '$table is handled by the merge now, so it is not left behind',
      );
    }
  });
}
