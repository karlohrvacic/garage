import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every table this app subscribes to has to be in the realtime publication
/// *and* carry `replica identity full`, and nothing enforced the second half.
///
/// `0007_realtime.sql` set it on the three tables published at the time and
/// wrote down why: a DELETE's old tuple otherwise carries only the primary
/// key, so `_vehicleIdFrom` cannot read `vehicle_id` and the callback returns
/// without invalidating anything. Four more entry kinds were published later
/// — costs in `0012`, readings in `0028`, trips and income in `0029` — and
/// none of them repeated it, so deleting one of those on a phone left it on
/// screen on the laptop until the list was reloaded by hand.
///
/// Nothing failed. Inserts and updates worked throughout, which is precisely
/// what made the gap survive: realtime looked like it worked.
///
/// This is a static check over the migrations rather than a query against a
/// running database, because the mistake is made when a migration is written
/// and this is where it can be caught without Docker.
void main() {
  final sync = File('lib/core/sync/realtime_sync.dart').readAsStringSync();

  final migrations = [
    for (final file in Directory('supabase/migrations').listSync())
      if (file is File && file.path.endsWith('.sql')) file.readAsStringSync(),
  ].join('\n');

  /// The table names this app actually opens a subscription for, read out of
  /// the two maps and the hand-written `.onPostgresChanges` calls.
  Set<String> subscribedTables() {
    return {
      for (final match in RegExp(r"'([a-z_]+)':\s*\(").allMatches(sync))
        match.group(1)!,
      for (final match in RegExp(r"table:\s*'([a-z_]+)'").allMatches(sync))
        match.group(1)!,
    };
  }

  Set<String> withFullReplicaIdentity() {
    return {
      for (final match in RegExp(
        r'alter table public\.([a-z_]+) replica identity full',
      ).allMatches(migrations))
        match.group(1)!,
    };
  }

  Set<String> published() {
    return {
      for (final match in RegExp(
        r'alter publication supabase_realtime add table public\.([a-z_]+)',
      ).allMatches(migrations))
        match.group(1)!,
    };
  }

  /// The one table that genuinely does not need it: a delete on `vehicles`
  /// sends the primary key, and the primary key *is* the id the client
  /// refreshes on.
  const identifiedByPrimaryKey = {'vehicles'};

  test('every table the app subscribes to is in the publication', () {
    expect(
      subscribedTables().difference(published()),
      isEmpty,
      reason: 'a subscription to an unpublished table receives nothing',
    );
  });

  test('and carries full replica identity, so deletes are actionable', () {
    expect(
      subscribedTables()
          .difference(withFullReplicaIdentity())
          .difference(identifiedByPrimaryKey),
      isEmpty,
      reason:
          "without it a DELETE's old row is only the primary key, and the "
          'callback cannot tell which household or vehicle it belonged to',
    );
  });

  /// Every table a *second member* can change, and which of them are
  /// deliberately not live.
  ///
  /// The two lists together have to name every table in the schema, so a new
  /// one cannot be added without somebody deciding which it is. Observations
  /// and routes shipped without realtime and nothing noticed: a note recorded
  /// on one phone did not reach the other until the app was reopened, and
  /// every other card on that screen was live.
  const notLive = {
    // Read through the bootstrap, which realtime invalidates via `vehicles`.
    'households': 'refetched with the garage',
    'household_members': 'membership changes route the user anyway',
    'profiles': 'a display name changing mid-session is not worth a channel',
    'service_types': 'presets, effectively static',
    'attachments': 'listed by the sheet that owns them, on open',
    'tyre_sets': 'a seasonal swap is not a live-collaboration moment',
    'tyre_readings': 'same',
    // Looked up once and re-read when the screen opens; a filter number
    // changing on one phone while the other is on that screen is not a
    // moment anybody is waiting for.
    'vehicle_parts': 'a lookup, not a conversation',
    'device_tokens': 'not user-visible',
    'webhook_dispatch_config': 'not user-visible',
    'webhook_outbox': 'read by the dispatcher, never by the app',
  };

  test('every table is either live or knowingly not', () {
    final all = {
      for (final match in RegExp(
        r'create table public\.([a-z_]+)',
      ).allMatches(migrations))
        match.group(1)!,
    };

    expect(all, contains('observations'), reason: 'the pattern still matches');
    expect(
      all.difference(subscribedTables()).difference(notLive.keys.toSet()),
      isEmpty,
      reason:
          'a table a second member can change is either subscribed in '
          'realtime_sync.dart or listed in `notLive` above with a reason',
    );
    expect(
      notLive.keys.toSet().difference(all),
      isEmpty,
      reason: 'this list names a table that no longer exists',
    );
  });

  test('the maps are actually being read, not silently matching nothing', () {
    // A regex that stops matching would make both tests above pass on an
    // empty set, which is the failure mode a parsing test has.
    expect(subscribedTables(), contains('fuel_entries'));
    expect(subscribedTables(), contains('invites'));
    expect(published(), contains('cost_entries'));
    expect(withFullReplicaIdentity(), contains('trip_entries'));
  });
}
