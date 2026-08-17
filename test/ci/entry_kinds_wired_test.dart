import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every table that holds entries hanging off a vehicle.
///
/// The one place this list is written down. Adding a seventh kind means adding
/// it here and then making the tests below pass, which is the point: each of
/// those wirings fails *silently* when it is forgotten — a webhook receiver
/// simply stops hearing about a third of the log, and a second device stops
/// updating — so nothing else would tell you.
const entryTables = {
  'fuel_entries',
  'service_entries',
  'cost_entries',
  'odometer_entries',
  'trip_entries',
  'income_entries',
};

String read(String path) => File(path).readAsStringSync();

/// Every `add table public.X` across the migrations, which is append-only, so
/// reading them all is the only way to know the publication's final shape.
Set<String> publishedTables() {
  final published = <String>{};
  for (final file in Directory('supabase/migrations').listSync()) {
    if (file is! File || !file.path.endsWith('.sql')) {
      continue;
    }
    for (final match in RegExp(
      r'supabase_realtime add table public\.(\w+)',
    ).allMatches(file.readAsStringSync())) {
      published.add(match.group(1)!);
    }
  }
  return published;
}

Set<String> webhookTriggerTables() {
  final tables = <String>{};
  for (final file in Directory('supabase/migrations').listSync()) {
    if (file is! File || !file.path.endsWith('.sql')) {
      continue;
    }
    for (final match in RegExp(
      r'after insert on public\.(\w+)\s+for each row execute function\s+'
      r'public\.dispatch_entry_webhook',
    ).allMatches(file.readAsStringSync())) {
      tables.add(match.group(1)!);
    }
  }
  return tables;
}

void main() {
  test('every entry kind streams to the other devices in the household', () {
    // Without this, a trip logged on a phone does not appear on the laptop
    // until that screen is revisited, and nothing reports it.
    expect(publishedTables(), containsAll(entryTables));
  });

  test('every entry kind is invalidated when its change arrives', () {
    final sync = read('lib/core/sync/realtime_sync.dart');

    for (final table in entryTables) {
      expect(
        sync,
        contains("'$table'"),
        reason: '$table is published but nothing listens for it',
      );
    }
  });

  test('every entry kind fires a webhook', () {
    expect(webhookTriggerTables(), containsAll(entryTables));
  });

  test('the webhook dispatcher recognises every entry kind', () {
    // A table missing from the map is dropped without an error, which is the
    // quietest of all these failures.
    final dispatcher = read('supabase/functions/dispatch-webhooks/index.ts');
    final map = RegExp(
      r'const entryKinds[^}]*}',
      dotAll: true,
    ).firstMatch(dispatcher)!.group(0)!;

    for (final table in entryTables) {
      expect(
        map,
        contains(table),
        reason: '$table fires a webhook the dispatcher will throw away',
      );
    }
  });

  test('every entry kind is readable through the public API', () {
    final api = read('supabase/functions/public-api/index.ts');

    for (final table in entryTables) {
      expect(
        api,
        contains("'$table'"),
        reason: '$table is in the schema but not in the API',
      );
    }
  });

  test('every entry kind can be imported from a CSV', () {
    // The importer is keyed by its own enum rather than by table name, so this
    // checks the count instead: six kinds, six importable kinds.
    final schema = read('lib/domain/import/csv_import.dart');
    final kinds = RegExp(r'enum CsvEntryKind \{([^}]*)\}')
        .firstMatch(schema)!
        .group(1)!
        .split(',')
        .where((k) => k.trim().isNotEmpty);

    expect(kinds, hasLength(entryTables.length));
  });

  test('every entry kind is carried by a backup', () {
    final backup = read('lib/domain/export/garage_backup.dart');

    for (final key in [
      'fuel',
      'services',
      'costs',
      'readings',
      'trips',
      'income',
    ]) {
      expect(
        backup,
        contains("'$key':"),
        reason: 'a backup that drops $key cannot restore what it exported',
      );
    }
  });

  test('every entry kind can be overridden in one call in a test', () {
    // The shared harness is what makes a forgotten kind fail loudly in the
    // rest of the suite rather than reaching for a real Supabase client.
    final helper = read('test/support/vehicle_entries.dart');

    for (final provider in [
      'rawFuelEntriesProvider',
      'serviceEntriesProvider',
      'costEntriesProvider',
      'odometerEntriesProvider',
      'tripEntriesProvider',
      'incomeEntriesProvider',
    ]) {
      expect(helper, contains(provider));
    }
  });

  test('the device and the server agree on how much notice to give', () {
    // Two copies of the same decision, in two languages, and nothing else
    // relates them: a household would otherwise be told about the same oil
    // change twice, on different days, by two halves of one feature.
    final dart = read('lib/core/notifications/notification_scheduler.dart');
    final push = read('supabase/functions/push-due-reminders/index.ts');

    final local = RegExp(
      r'notificationLeadTime = Duration\(days: (\d+)\)',
    ).firstMatch(dart);
    final server = RegExp(r'REMINDER_LEAD_DAYS = (\d+)').firstMatch(push);

    expect(
      local,
      isNotNull,
      reason: 'the local lead time moved or was renamed',
    );
    expect(
      server,
      isNotNull,
      reason: 'the server lead time moved or was renamed',
    );
    expect(server!.group(1), local!.group(1));
  });

  test('a reminder due by distance reads every odometer there is', () {
    // The push function used the newest *fuel* entry as the current
    // odometer. A household that records readings without buying fuel — an
    // EV, or anyone who stopped logging fill-ups — would have its
    // distance-based reminders projected from a number that stopped moving,
    // which is the coupling the app itself was fixed to remove.
    final push = read('supabase/functions/push-due-reminders/index.ts');

    for (final table in entryTables) {
      expect(
        push,
        contains(table),
        reason:
            '$table carries an odometer and has to count toward the '
            'current reading',
      );
    }
  });
}
