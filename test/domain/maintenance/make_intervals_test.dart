import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/maintenance/make_intervals.dart';

void main() {
  test('every row has a number', () {
    for (final row in makeIntervals) {
      expect(
        row.km != null || row.months != null,
        isTrue,
        reason: '${row.make}/${row.serviceTypeKey} has neither km nor months',
      );
    }
  });

  test('no make has two rows for one type', () {
    final seen = <String>{};
    for (final row in makeIntervals) {
      expect(seen.add('${row.make}/${row.serviceTypeKey}'), isTrue);
    }
  });

  test('only the four overlayable types appear', () {
    const allowed = {
      'service_oil_change',
      'service_coolant',
      'service_cabin_filter',
      'service_air_filter',
    };
    for (final row in makeIntervals) {
      expect(allowed, contains(row.serviceTypeKey), reason: row.make);
    }
  });

  test('every row cites a make that has a row in the spike', () {
    // A number without a source is a guess. The spike's §2 table is the
    // source; its first column is the make in bold.
    final spike = File(
      'docs/research/2026-09-02-service-interval-presets-spike.md',
    ).readAsStringSync();
    for (final row in makeIntervals) {
      expect(
        spike,
        contains('| **${row.spikeRow}**'),
        reason:
            '${row.make} cites "${row.spikeRow}", which is not in the spike',
      );
    }
  });
}
