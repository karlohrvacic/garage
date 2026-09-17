import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A borrower reads a lent car through `guest_vehicles`, never through the
/// table, because the row carries what the owner paid for the car and a
/// policy cannot hide a column (migration 0072). The function lists the
/// columns it hands out, so a column added later is withheld from borrowers
/// by default — which is safe, and also silent: a borrower's app would miss a
/// field nobody decided about.
///
/// So every column of `vehicles` has to be either handed out by the newest
/// `guest_vehicles`, or listed below with the reason it is withheld.
void main() {
  /// Withheld from borrowers. The reason is what the next person has to argue
  /// with before moving a column out of this map.
  const withheld = {
    'purchase_price': 'what the owner paid for the car',
    'current_value': "the owner's own estimate of what it is worth",
    'valued_on': 'when the owner made that estimate',
    'photo_path':
        "the photo is under the owner's storage prefix, which a borrower "
        'cannot read, so the path is only a broken image',
    'created_by': 'who in the garage added the car is the garage\'s business',
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

  test('the scan reads the columns the table has', () {
    // Guards the guard: a scan that found nothing would pass everything.
    expect(
      vehicleColumns(sources),
      containsAll([
        'id',
        'nickname',
        'purchase_price',
        'current_value',
        'tank_capacity_l',
        'transmission',
        'final_drive',
      ]),
    );
    expect(vehicleColumns(sources), isNot(contains('vehicles_second_fuel')));
    expect(
      handedOut(guestVehiclesBody(sources)),
      containsAll(['id', 'nickname', 'fuel_type_key']),
    );
  });

  test('and every way Postgres has of changing them', () {
    final columns = vehicleColumns([
      '''
create table if not exists vehicles (
  id uuid primary key,
  -- a comment, with a comma and a car's apostrophe
  plate text check (plate in ('a', 'b')),
  constraint plate_short check (char_length(plate) < 20)
);
''',
      '''
ALTER TABLE ONLY public.vehicles
  ADD owner_note text,
  ADD COLUMN IF NOT EXISTS colour text check (colour <> ''),
  ADD CONSTRAINT colour_known CHECK (colour IS NOT NULL);
alter table vehicles rename column plate to registration;
alter table if exists public.vehicles drop column if exists colour;
alter table public.guest_vehicles add column unrelated text;
'''
          .toLowerCase(),
    ]);

    expect(columns, {'id', 'owner_note', 'registration'});
  });

  test('every column is handed to borrowers or withheld on purpose', () {
    final given = handedOut(guestVehiclesBody(sources));

    for (final column in vehicleColumns(sources)) {
      expect(
        given.contains(column) || withheld.containsKey(column),
        isTrue,
        reason:
            'vehicles.$column is new and nobody has decided whether a '
            'borrower sees it. Add it to guest_vehicles in a new migration, '
            'or to `withheld` here with the reason',
      );
    }
  });

  test('nothing withheld is handed out anyway', () {
    final body = guestVehiclesBody(sources);
    final columns = vehicleColumns(sources);

    for (final column in withheld.keys) {
      expect(columns, contains(column), reason: '$column is not a column');
      // Not merely absent from the pairs: under another key, or in a filter
      // that lets a borrower probe it, it is handed out all the same.
      expect(
        RegExp('\\b$column\\b').hasMatch(body),
        isFalse,
        reason: 'guest_vehicles mentions $column',
      );
    }
  });

  test('each key names the column it hands out', () {
    final body = guestVehiclesBody(sources);

    for (final pair in RegExp(r"'(\w+)',\s*v\.(\w+)").allMatches(body)) {
      expect(
        pair.group(1),
        pair.group(2),
        reason:
            'guest_vehicles hands out v.${pair.group(2)} as '
            '${pair.group(1)}, which this test cannot hold to account',
      );
    }
  });

  test('and the row is never handed out whole', () {
    final body = guestVehiclesBody(sources);

    for (final whole in [
      RegExp(r'\bto_jsonb?\s*\('),
      RegExp(r'\brow_to_json\s*\('),
      RegExp(r'\bjsonb?_populate_record'),
      RegExp(r'\bhstore\s*\('),
      RegExp(r'\bv\s*\.\s*\*'),
      RegExp(r'\bselect\s+\*'),
      // The alias on its own, as a value: `jsonb_build_object('car', v)`.
      RegExp(r'[,(]\s*v\s*[,)]'),
    ]) {
      expect(
        whole.hasMatch(body),
        isFalse,
        reason: 'guest_vehicles hands out the whole row (${whole.pattern})',
      );
    }
  });
}

/// The words a table definition or an `alter table` action can start with
/// that do not name a column.
const _notColumns = {
  'constraint',
  'primary',
  'unique',
  'check',
  'foreign',
  'exclude',
  'like',
};

/// Every column `vehicles` has once [sources] have run, in order. Each source
/// is a migration, lowercased.
Set<String> vehicleColumns(List<String> sources) {
  const table = r'(?:public\.)?vehicles\b';
  final create = RegExp(
    r'create\s+table\s+(?:if\s+not\s+exists\s+)?' + table + r'\s*\((.*?)\n\);',
    dotAll: true,
  );
  final alter = RegExp(
    r'alter\s+table\s+(?:if\s+exists\s+)?(?:only\s+)?' + table + r'([^;]*);',
  );
  final add = RegExp(r'^add\s+(?:column\s+)?(?:if\s+not\s+exists\s+)?(\w+)');
  final drop = RegExp(r'^drop\s+(?:column\s+)?(?:if\s+exists\s+)?(\w+)');
  final rename = RegExp(r'^rename\s+(?:column\s+)?(\w+)\s+to\s+(\w+)');

  final columns = <String>{};
  for (final sql in sources) {
    final statements = [
      for (final match in create.allMatches(sql)) (match.start, match, true),
      for (final match in alter.allMatches(sql)) (match.start, match, false),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    for (final (_, match, creating) in statements) {
      for (final item in _topLevelItems(match.group(1)!)) {
        if (creating) {
          final name = RegExp(r'^\w+').stringMatch(item);
          if (name != null && !_notColumns.contains(name)) {
            columns.add(name);
          }
        } else if (add.firstMatch(item) case final added?) {
          if (!_notColumns.contains(added.group(1))) {
            columns.add(added.group(1)!);
          }
        } else if (drop.firstMatch(item) case final dropped?) {
          if (dropped.group(1) != 'constraint') {
            columns.remove(dropped.group(1));
          }
        } else if (rename.firstMatch(item) case final renamed?) {
          if (columns.remove(renamed.group(1))) {
            columns.add(renamed.group(2)!);
          }
        }
      }
    }
  }
  return columns;
}

/// The body of the newest `guest_vehicles`: a later migration replaces the
/// function whole, so only the last one is what runs.
String guestVehiclesBody(List<String> sources) {
  final definition = RegExp(
    r'create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?guest_vehicles\s*\(',
  );
  final sql = sources.lastWhere(definition.hasMatch);
  final start = definition.allMatches(sql).last.start;
  return sql.substring(start, sql.indexOf(r'$$;', start));
}

/// The columns [body] hands out, as `'column', v.column` pairs.
Set<String> handedOut(String body) => {
  for (final pair in RegExp(r"'(\w+)',\s*v\.(\w+)").allMatches(body))
    if (pair.group(1) == pair.group(2)) pair.group(1)!,
};

/// [sql] split on the commas that separate its items, with comments dropped
/// and each item trimmed: a comma inside a check, a type's precision or a
/// string separates nothing.
List<String> _topLevelItems(String sql) {
  final text = sql.replaceAll(RegExp(r'--[^\n]*'), '');
  final items = <String>[];
  var depth = 0;
  var quoted = false;
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == "'") {
      quoted = !quoted;
    } else if (quoted) {
      continue;
    } else if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
    } else if (char == ',' && depth == 0) {
      items.add(text.substring(start, i).trim());
      start = i + 1;
    }
  }
  items.add(text.substring(start).trim());
  return [
    for (final item in items)
      if (item.isNotEmpty) item,
  ];
}
