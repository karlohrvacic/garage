import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/attachment.dart';

/// The kinds the database accepts and the kinds the app can produce.
///
/// These drifted apart once already and nothing noticed: migration 0060 widened
/// `attachments_entry_kind_check` to allow `observation`, the Dart enum was not
/// widened with it, and the observation sheet therefore could not attach the
/// photo the decision log said it took. A value the database allows and no code
/// can write is a feature somebody believes exists.
///
/// The other direction is worse and louder: a kind the app writes and the
/// constraint refuses is a save that fails at the moment somebody attaches a
/// receipt.
void main() {
  test('the app and the database agree on what an attachment can hang off', () {
    final migrations =
        Directory('supabase/migrations')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.sql'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    // The last migration that states the constraint wins, the way the applied
    // database is the last one to have run. Each statement of it is read
    // against the table it sits in: `receipt_reminders` (0080) has an
    // `entry_kind` of its own, naming the three money tables a receipt can
    // be asked for, and it is not the attachments constraint.
    final pattern = RegExp(r"entry_kind in \(([^)]*)\)", multiLine: true);
    final statement = RegExp(r'(?:create|alter) table public\.(\w+)');
    String? latest;
    for (final file in migrations) {
      final sql = file.readAsStringSync();
      for (final match in pattern.allMatches(sql)) {
        final table = statement
            .allMatches(sql.substring(0, match.start))
            .last
            .group(1);
        if (table == 'attachments') {
          latest = match.group(1);
        }
      }
    }

    expect(
      latest,
      isNotNull,
      reason: 'no migration states the attachment kinds any more',
    );
    final inDatabase = RegExp(
      "'([a-z_]+)'",
    ).allMatches(latest!).map((match) => match.group(1)!).toSet();

    expect({
      for (final kind in AttachmentEntryKind.values) kind.key,
    }, inDatabase);
  });
}
