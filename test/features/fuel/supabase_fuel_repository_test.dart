import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/features/fuel/data/supabase_fuel_repository.dart';

/// A row as Postgrest returns it: `entry_date` is a date-only string, numerics
/// arrive as num, and the server-owned columns are always present.
Map<String, dynamic> row({
  Object? pricePerL = 1.55,
  Object? total = 67.27,
  String? station = 'INA',
  String? notes,
}) {
  return {
    'id': 'f1',
    'vehicle_id': 'v1',
    'entry_date': '2026-07-24',
    'odometer_km': 51140,
    'volume_l': 43.4,
    'price_per_l': pricePerL,
    'total': total,
    'full_tank': true,
    'missed_fill': false,
    'station': station,
    'notes': notes,
    'created_by': 'u1',
    'created_at': '2026-07-24T10:00:00Z',
  };
}

FuelEntry entry() {
  return FuelEntry(
    id: 'f1',
    vehicleId: 'v1',
    date: DateTime.utc(2026, 7, 24),
    odometerKm: 51140,
    volumeL: 43.4,
    pricePerL: 1.55,
    total: 67.27,
    fullTank: true,
    missedFill: false,
    station: 'INA',
    createdBy: 'u1',
    createdAt: DateTime.utc(2026, 7, 24, 10),
  );
}

void main() {
  group('reading a row', () {
    test('maps every column onto the entity', () {
      expect(fuelEntryFromRow(row()), entry());
    });

    test('reads the date-only column as UTC midnight', () {
      final date = fuelEntryFromRow(row()).date;

      expect(date.isUtc, isTrue);
      expect(date, DateTime.utc(2026, 7, 24));
    });

    test('widens integer numerics to double', () {
      final read = fuelEntryFromRow(row(pricePerL: 2, total: 80));

      expect(read.pricePerL, 2.0);
      expect(read.total, 80.0);
    });

    test('keeps the optional columns nullable', () {
      final read = fuelEntryFromRow(
        row(pricePerL: null, total: null, station: null),
      );

      expect(read.pricePerL, isNull);
      expect(read.total, isNull);
      expect(read.station, isNull);
      expect(read.notes, isNull);
    });
  });

  group('writing a row', () {
    test('names the columns the table actually has', () {
      expect(fuelEntryToRow(entry()).keys, {
        'vehicle_id',
        'entry_date',
        'odometer_km',
        'volume_l',
        'price_per_l',
        'total',
        'full_tank',
        'missed_fill',
        'fuel_type_key',
        'station',
        'station_ref',
        'notes',
        'cheapest_nearby_price',
        'cheapest_nearby_km',
        'cheapest_nearby_station',
        'prices_seen_on',
      });
    });

    test('writes the date as a date-only string', () {
      expect(fuelEntryToRow(entry())['entry_date'], '2026-07-24');
    });

    test('writes a local date as the calendar day the user picked', () {
      // 23:30 local on the 24th is the 24th, whatever the offset does to it.
      final local = entry().copyWith(date: DateTime(2026, 7, 24, 23, 30));

      expect(fuelEntryToRow(local)['entry_date'], '2026-07-24');
    });

    test('never sends id or created_by, which the server owns', () {
      final written = fuelEntryToRow(entry());

      expect(written.containsKey('id'), isFalse);
      expect(written.containsKey('created_by'), isFalse);
    });
  });

  test('a row survives the round trip unchanged', () {
    final written = fuelEntryToRow(entry());
    final reread = fuelEntryFromRow({
      ...written,
      'id': 'f1',
      'created_by': 'u1',
      'created_at': '2026-07-24T10:00:00Z',
    });

    expect(reread, entry());
  });

  // Which forecourt it was, by the price dataset's own id, beside a station
  // that now says only the brand.
  group('the forecourt', () {
    test('is read off the row', () {
      expect(
        fuelEntryFromRow({...row(), 'station_ref': 1223}).stationRef,
        1223,
      );
    });

    test('is absent on a row written before the column existed', () {
      expect(fuelEntryFromRow(row()).stationRef, isNull);
    });

    test('survives the round trip back to a row', () {
      final written = fuelEntryToRow(entry().copyWith(stationRef: 1223));

      expect(written['station_ref'], 1223);
      expect(
        fuelEntryFromRow({
          ...written,
          'id': 'f1',
          'created_by': 'u1',
          'created_at': '2026-07-24T10:00:00Z',
        }),
        entry().copyWith(stationRef: 1223),
      );
    });

    test('an entry without one writes a null, not a missing key', () {
      final written = fuelEntryToRow(entry());

      expect(written.containsKey('station_ref'), isTrue);
      expect(written['station_ref'], isNull);
    });
  });

  // The dataset these came from is fetched live and kept nowhere, so a column
  // dropped here loses the only record that the comparison was ever possible.
  group('the price snapshot', () {
    Map<String, dynamic> snapshotRow() => {
      ...row(),
      'cheapest_nearby_price': 1.44,
      'cheapest_nearby_km': 3.2,
      'cheapest_nearby_station': 'Petrol Ilica',
      'prices_seen_on': '2026-07-24',
    };

    test('is read off the row', () {
      final read = fuelEntryFromRow(snapshotRow()).priceContext!;

      expect(read.pricePerUnit, 1.44);
      expect(read.distanceKm, 3.2);
      expect(read.station, 'Petrol Ilica');
      expect(read.seenOn, DateTime.utc(2026, 7, 24));
    });

    test('is absent on a row written before the columns existed', () {
      expect(fuelEntryFromRow(row()).priceContext, isNull);
    });

    test('survives the round trip back to a row', () {
      final written = fuelEntryToRow(fuelEntryFromRow(snapshotRow()));

      expect(written['cheapest_nearby_price'], 1.44);
      expect(written['cheapest_nearby_km'], 3.2);
      expect(written['cheapest_nearby_station'], 'Petrol Ilica');
      expect(written['prices_seen_on'], '2026-07-24');
    });

    test('an entry without one writes four nulls, not four missing keys', () {
      final written = fuelEntryToRow(entry());

      expect(written['cheapest_nearby_price'], isNull);
      expect(written['prices_seen_on'], isNull);
    });
  });
}
