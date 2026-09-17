import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/core/supabase/date_column.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/fuel/energy_type.dart';
import 'package:garage/domain/fuel/fuel_economy.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';

/// The full-tank rule exists twice: [FuelEconomy] here, and `economy.ts` in
/// the `dispatch-webhooks` edge function, which puts a consumption figure in
/// the message a webhook sends. One is Flutter and the other is Deno, so
/// neither can import the other.
///
/// They have to agree, and nothing would say so if they did not: the app would
/// show 6.1 on a fill-up and the household's chat would say 5.4 about the same
/// one. So both suites read one file of cases whose answers were worked out by
/// hand — this one, and `economy_test.ts` beside the TypeScript. Changing the
/// rule means changing the fixture, and the fixture then fails whichever side
/// was not changed with it.
///
/// The same arrangement `winter_tyre_twin_test.dart` has, for the same reason.
const _fixturePath = 'test/fixtures/economy_spans.json';

final Map<String, dynamic> _fixture =
    jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> get _spans =>
    (_fixture['spans'] as List).cast<Map<String, dynamic>>();

/// The hand-worked readings, then the ones recorded from the app at a decimal
/// half. Both are asserted here: for the halves this side is the definition,
/// and an `intl` upgrade that rounds differently has to fail somewhere.
List<Map<String, dynamic>> get _readings {
  final readings = _fixture['readings'] as Map<String, dynamic>;
  return [
    ...(readings['cases'] as List).cast<Map<String, dynamic>>(),
    ...(readings['halves'] as List).cast<Map<String, dynamic>>(),
  ];
}

/// A `fuel_entries` row as the repository would read it, less the columns the
/// algorithm never looks at.
FuelEntry _entry(Map<String, dynamic> row) {
  return FuelEntry(
    id: row['id'] as String,
    vehicleId: 'v1',
    date: dateFromColumn(row['entry_date'] as String),
    odometerKm: row['odometer_km'] as int,
    volumeL: (row['volume_l'] as num).toDouble(),
    fullTank: row['full_tank'] as bool,
    missedFill: row['missed_fill'] as bool,
    fuelTypeKey: row['fuel_type_key'] as String?,
    createdBy: 'u1',
  );
}

void main() {
  test('the fixture holds both outcomes', () {
    // Guards the guard: a file that parsed to nothing, or that only ever
    // expected null, would pass every assertion below without checking any
    // arithmetic at all.
    expect(_spans.where((span) => span['expected'] != null), isNotEmpty);
    expect(_spans.where((span) => span['expected'] == null), isNotEmpty);
    expect(_readings, isNotEmpty);
    expect(
      (_fixture['readings'] as Map<String, dynamic>)['halves'],
      isNotEmpty,
      reason:
          'the rounding cases went missing, and with them the only thing '
          'holding the two formatters to the same digit',
    );
  });

  group('the span that closes at an entry', () {
    for (final span in _spans) {
      test(span['name'] as String, () {
        final rows = (span['entries'] as List).cast<Map<String, dynamic>>();
        final closingId = span['closing_id'] as String;
        expect(
          rows.map((row) => row['id']),
          contains(closingId),
          reason: 'the case closes at an entry it does not contain',
        );

        final points = FuelEconomy.compute(
          rows.map(_entry).toList(),
          primaryFuelKey: span['primary_fuel_key'] as String?,
        );
        final anchored = points
            .where((point) => point.entryId == closingId)
            .toList();

        final expected = span['expected'] as Map<String, dynamic>?;
        if (expected == null) {
          expect(anchored, isEmpty, reason: span['working'] as String);
          return;
        }
        expect(anchored, hasLength(1), reason: span['working'] as String);
        expect(
          anchored.single.litersPer100Km,
          closeTo(expected['l_per_100km'] as num, 1e-9),
          reason: span['working'] as String,
        );
        expect(
          anchored.single.distanceKm,
          closeTo(expected['distance_km'] as num, 1e-9),
        );
        expect(
          anchored.single.volumeL,
          closeTo(expected['volume_l'] as num, 1e-9),
        );
      });
    }
  });

  group('how a figure reads in the household units', () {
    for (final reading in _readings) {
      test(reading['name'] as String, () {
        // Through `preferencesFor`, so the stored strings reach the formatter
        // the way they do in the app rather than as enums picked by this test.
        final format = UnitFormat(
          locale: 'en_GB',
          preferences: preferencesFor(
            Household(
              id: 'h1',
              name: 'Household',
              distanceUnit: reading['distance_unit'] as String,
              volumeUnit: reading['volume_unit'] as String,
            ),
          ),
        );

        expect(
          format.formatEconomy(
            (reading['l_per_100km'] as num).toDouble(),
            reading['electric'] as bool
                ? EnergyType.electric
                : EnergyType.liquid,
          ),
          reading['expected'],
        );
      });
    }
  });
}
