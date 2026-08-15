import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/tyre_set.dart';
import 'package:garage/features/tyres/data/supabase_tyre_repository.dart';

Map<String, dynamic> setRow({
  bool fitted = true,
  Object? retiredAt,
  List<dynamic>? readings,
}) {
  return {
    'id': 't1',
    'vehicle_id': 'v1',
    'name': 'Winter — studded',
    'season': 'winter',
    'size': '205/55 R16',
    'storage_location': 'Cellar',
    'fitted': fitted,
    'fitted_at': '2026-11-01',
    'retired_at': retiredAt,
    'created_by': 'u1',
    'tyre_readings': readings,
  };
}

Map<String, dynamic> readingRow({Object? frontLeft = 6.5}) {
  return {
    'id': 'r1',
    'reading_date': '2026-10-01',
    'odometer_km': 51000,
    'front_left_mm': frontLeft,
    'front_right_mm': 6.4,
    'rear_left_mm': 7.0,
    'rear_right_mm': 7.1,
  };
}

void main() {
  group('reading a set', () {
    test('maps every column onto the entity', () {
      final set = tyreSetFromRow(setRow());

      expect(set.id, 't1');
      expect(set.name, 'Winter — studded');
      expect(set.season, TyreSeason.winter);
      expect(set.size, '205/55 R16');
      expect(set.storageLocation, 'Cellar');
      expect(set.fitted, isTrue);
      expect(set.fittedAt, DateTime.utc(2026, 11, 1));
      expect(set.isRetired, isFalse);
    });

    test('a retired set carries when it was retired', () {
      final set = tyreSetFromRow(setRow(retiredAt: '2027-03-01'));

      expect(set.retiredAt, DateTime.utc(2027, 3, 1));
      expect(set.isRetired, isTrue);
    });

    test('its readings come along when the query joined them', () {
      final set = tyreSetFromRow(setRow(readings: [readingRow()]));

      expect(set.readings, hasLength(1));
      expect(set.readings.single.date, DateTime.utc(2026, 10, 1));
      expect(set.readings.single.frontLeftMm, 6.5);
      expect(set.latestReading?.shallowestMm, 6.4);
    });

    test('a set queried without readings simply has none', () {
      expect(tyreSetFromRow(setRow()).readings, isEmpty);
    });

    test('a corner nobody measured stays null', () {
      final set = tyreSetFromRow(
        setRow(readings: [readingRow(frontLeft: null)]),
      );

      expect(set.readings.single.frontLeftMm, isNull);
      expect(set.readings.single.shallowestMm, 6.4);
    });
  });

  group('writing a set', () {
    test('names the columns the table has', () {
      final row = tyreSetToRow(
        vehicleId: 'v1',
        name: 'Winter',
        season: TyreSeason.winter,
        size: '205/55 R16',
        storageLocation: 'Cellar',
      );

      expect(row.keys, {
        'vehicle_id',
        'name',
        'season',
        'size',
        'storage_location',
      });
      expect(row['season'], 'winter');
    });
  });

  group('writing a reading', () {
    test('names the columns the table has', () {
      final row = tyreReadingToRow(
        tyreSetId: 't1',
        date: DateTime.utc(2026, 10, 1),
        odometerKm: 51000,
        frontLeftMm: 6.5,
        frontRightMm: null,
        rearLeftMm: null,
        rearRightMm: null,
      );

      expect(row.keys, {
        'tyre_set_id',
        'reading_date',
        'odometer_km',
        'front_left_mm',
        'front_right_mm',
        'rear_left_mm',
        'rear_right_mm',
      });
      expect(row['reading_date'], '2026-10-01');
      expect(row['front_right_mm'], isNull);
    });
  });
}
