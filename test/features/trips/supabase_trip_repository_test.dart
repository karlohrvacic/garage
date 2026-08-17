import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/features/trips/data/supabase_trip_repository.dart';

Map<String, dynamic> row({
  Object? distance = 128.4,
  Object? purpose = 'business',
  Object? by = 'u1',
}) {
  return {
    'id': 't1',
    'vehicle_id': 'v1',
    'entry_date': '2026-06-01',
    'title': 'Client visit',
    'from_place': 'Rijeka',
    'to_place': 'Zagreb',
    'distance_km': distance,
    'start_odometer_km': 120000,
    'end_odometer_km': 120128,
    'minutes': 95,
    'purpose': purpose,
    'notes': 'motorway',
    'created_by': ?by,
  };
}

TripEntry trip({
  double distanceKm = 128.4,
  TripPurpose purpose = TripPurpose.business,
}) {
  return TripEntry(
    id: 't1',
    vehicleId: 'v1',
    date: DateTime.utc(2026, 6, 1),
    distanceKm: distanceKm,
    purpose: purpose,
    createdBy: 'u1',
    title: 'Client visit',
    fromPlace: 'Rijeka',
    toPlace: 'Zagreb',
    startOdometerKm: 120000,
    endOdometerKm: 120128,
    minutes: 95,
    notes: 'motorway',
  );
}

void main() {
  group('reading a row', () {
    test('maps every column onto the entity', () {
      expect(tripEntryFromRow(row()), trip());
    });

    test('reads the date-only column as UTC midnight', () {
      final date = tripEntryFromRow(row()).date;

      expect(date.isUtc, isTrue);
      expect(date, DateTime.utc(2026, 6, 1));
    });

    test('widens a whole-number distance to double', () {
      expect(tripEntryFromRow(row(distance: 128)).distanceKm, 128.0);
    });

    test('reads the purpose by its stored key, not the Dart name', () {
      expect(
        tripEntryFromRow(row(purpose: 'private')).purpose,
        TripPurpose.private,
      );
    });

    test('an unrecognised purpose falls back to private, never throws', () {
      // The conservative direction: a row written by a newer build must not
      // crash the trip log, and mislabelling business travel as private is
      // the error that costs a user nothing on a tax return.
      expect(
        tripEntryFromRow(row(purpose: 'commute')).purpose,
        TripPurpose.private,
      );
    });

    test('an entry whose author has since been deleted still reads', () {
      expect(tripEntryFromRow(row(by: null)).createdBy, '');
    });
  });

  group('writing a row', () {
    test('names the columns the table actually has', () {
      expect(tripEntryToRow(trip()).keys, {
        'entry_date',
        'title',
        'from_place',
        'to_place',
        'distance_km',
        'start_odometer_km',
        'end_odometer_km',
        'minutes',
        'purpose',
        'notes',
      });
    });

    test('writes the purpose as its key', () {
      expect(
        tripEntryToRow(trip(purpose: TripPurpose.private))['purpose'],
        'private',
      );
    });

    test('writes the date as a date-only string', () {
      expect(tripEntryToRow(trip())['entry_date'], '2026-06-01');
    });

    test('never sends id or created_by, which the server owns', () {
      final written = tripEntryToRow(trip());

      expect(written.containsKey('id'), isFalse);
      expect(written.containsKey('created_by'), isFalse);
      expect(written.containsKey('vehicle_id'), isFalse);
    });
  });

  test('a row survives the round trip unchanged', () {
    final written = tripEntryToRow(trip());
    final reread = tripEntryFromRow({
      ...written,
      'id': 't1',
      'vehicle_id': 'v1',
      'created_by': 'u1',
    });

    expect(reread, trip());
  });
}
