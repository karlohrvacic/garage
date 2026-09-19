import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/api/api_access.dart';

/// The event names live in three places that cannot see each other: the
/// triggers in migration 0079 write them, the dispatcher's `builders` turns
/// each into a message, and the app's `WebhookEvent` offers them as
/// switches. A name added to the triggers and not to the app would be
/// written and never subscribable; one added to the app and not to the
/// builders would be subscribable and never sent.
///
/// `reminder.due` is written by the daily reminder run, not by a trigger,
/// and `test.ping` is inserted by the app and sent to every hook, so neither
/// is in the migration's set, and only the ping is outside the app's.
void main() {
  final migration = File(
    'supabase/migrations/0079_webhook_outbox.sql',
  ).readAsStringSync();
  final builders = File(
    'supabase/functions/dispatch-webhooks/events.ts',
  ).readAsStringSync();

  final app = {for (final event in WebhookEvent.values) event.key};

  /// Every `'entry.…'`, `'vehicle.…'` and `'member.…'` literal the triggers
  /// write. The ping is written by the app's insert, matched by a policy
  /// and a trigger condition, and is not an event the triggers write.
  Set<String> writtenByTriggers() {
    return {
      for (final match in RegExp(
        r"'((?:entry|vehicle|member)\.[a-z_]+)'",
      ).allMatches(migration))
        match.group(1)!,
    };
  }

  /// The keys of the dispatcher's `builders` map, read out of the block
  /// between `export const builders` and its closing brace.
  Set<String> builtByDispatcher() {
    final block = RegExp(
      r'export const builders[^{]*\{([\s\S]*?)\n\}',
    ).firstMatch(builders);
    expect(block, isNotNull, reason: 'the builders map is no longer a literal');
    return {
      for (final match in RegExp(
        r"^\s*'([a-z_]+\.[a-z_]+)':",
        multiLine: true,
      ).allMatches(block!.group(1)!))
        match.group(1)!,
    };
  }

  test('what the triggers write is what the app offers, plus the reminder', () {
    final written = writtenByTriggers();
    expect(written, contains('entry.created'), reason: 'the regex still reads');

    expect({...written, 'reminder.due'}, app);
  });

  test('what the dispatcher builds is what the app offers, plus the ping', () {
    final built = builtByDispatcher();
    expect(built, contains('vehicle.lent'), reason: 'the regex still reads');

    expect(built, {...app, 'test.ping'});
  });
}
