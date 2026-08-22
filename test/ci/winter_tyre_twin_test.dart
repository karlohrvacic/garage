import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/maintenance/winter_tyre_period.dart';

/// The statutory winter-tyre windows exist twice: once in Dart for the app and
/// once in TypeScript for the push sender, because one is Flutter and the
/// other is Deno and neither can import the other.
///
/// They have to agree, and the failure if they do not is invisible from either
/// side. Wherever push is configured the client stops scheduling dated
/// reminders entirely, so a date changed here and not there means the app
/// shows one day on the maintenance row and the household is notified about a
/// different one — and nothing anywhere would say so.
///
/// The same guard `REMINDER_LEAD_DAYS` already has, for the same reason.
void main() {
  final typescript = File(
    'supabase/functions/push-due-reminders/winter_tyre_period.ts',
  ).readAsStringSync();

  /// Every `XX: { rule: '…', start: [m, d], end: [m, d] },` in the TS table.
  Map<String, String> parseTypescript() {
    final table = RegExp(
      r'WINTER_TYRE_PERIODS[^=]*=\s*\{(.*?)\n\}',
      dotAll: true,
    ).firstMatch(typescript);
    expect(
      table,
      isNotNull,
      reason: 'the TypeScript table moved or was renamed',
    );

    final entries = <String, String>{};
    final row = RegExp(
      r"(\w+):\s*\{\s*rule:\s*'(\w+)'"
      r"(?:,\s*start:\s*\[(\d+),\s*(\d+)\])?"
      r"(?:,\s*end:\s*\[(\d+),\s*(\d+)\])?",
    );
    for (final match in row.allMatches(table!.group(1)!)) {
      final start = match.group(3) == null
          ? 'none'
          : '${match.group(3)}-${match.group(4)}';
      final end = match.group(5) == null
          ? 'none'
          : '${match.group(5)}-${match.group(6)}';
      entries[match.group(1)!] = '${match.group(2)}|$start|$end';
    }
    return entries;
  }

  String describe(WinterTyrePeriod period) {
    String at(MonthDay? when) =>
        when == null ? 'none' : '${when.month}-${when.day}';
    return '${period.rule.name}|${at(period.start)}|${at(period.end)}';
  }

  test('the TypeScript table parses at all', () {
    // Guards the guard: a regex that silently matches nothing would make every
    // assertion below vacuously true.
    expect(parseTypescript(), isNotEmpty);
    expect(parseTypescript().keys, contains('HR'));
  });

  test('every country the server knows, the app knows identically', () {
    final server = parseTypescript();

    for (final entry in server.entries) {
      expect(
        describe(winterTyrePeriodFor(entry.key)),
        entry.value,
        reason:
            '${entry.key} differs between the app and the push sender — the '
            'app would show one date and the household be notified of another',
      );
    }
  });

  test('the app claims no country the server has not been told about', () {
    final server = parseTypescript();

    for (final code in ['HR', 'SI', 'BA', 'RS', 'AT', 'DE']) {
      if (winterTyrePeriodFor(code).rule == WinterTyreRule.none) {
        continue;
      }
      expect(
        server.keys,
        contains(code),
        reason:
            '$code has a window in the app and none on the server, so the '
            'reminder would be pushed from a six-month interval instead',
      );
    }
  });

  test('the seasonal service key is spelled the same on both sides', () {
    expect(
      typescript,
      contains("SEASONAL_SWAP_KEY = 'service_tire_swap_seasonal'"),
      reason: 'a renamed key silently matches no rule and pushes nothing',
    );
  });
}
