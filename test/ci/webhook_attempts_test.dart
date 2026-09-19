import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/api/api_access.dart';

/// The hook screen says "attempt 2 of 4" and "gave up after 4 attempts" from
/// a constant of its own, because the Flutter suite cannot import Deno. The
/// number is the dispatcher's, `MOST_ATTEMPTS` in `_shared/outbox.ts`, which
/// is one more than the retry waits it lists; a fourth wait added there
/// would leave the app describing a schedule the server no longer runs.
void main() {
  final outbox = File(
    'supabase/functions/_shared/outbox.ts',
  ).readAsStringSync();

  test('the app counts the attempts the dispatcher makes', () {
    final waits = RegExp(
      r'export const RETRY_MINUTES = \[([^\]]*)\]',
    ).firstMatch(outbox);
    final most = RegExp(
      r'export const MOST_ATTEMPTS = RETRY_MINUTES\.length \+ (\d+)',
    ).firstMatch(outbox);
    // A regex that stops matching would pass a comparison of nothing.
    expect(waits, isNotNull, reason: 'RETRY_MINUTES is no longer a literal');
    expect(most, isNotNull, reason: 'MOST_ATTEMPTS is no longer length + n');

    final retries = waits!
        .group(1)!
        .split(',')
        .where((entry) => entry.trim().isNotEmpty)
        .length;
    final attempts = retries + int.parse(most!.group(1)!);

    expect(retries, greaterThan(0), reason: 'the list is actually being read');
    expect(WebhookDelivery.mostAttempts, attempts);
  });
}
