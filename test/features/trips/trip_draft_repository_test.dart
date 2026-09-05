import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/trip_draft.dart';
import 'package:garage/features/trips/data/supabase_trip_repository.dart';

Map<String, dynamic> draftRow({
  Object? distance,
  String? startedAt = '2026-09-05T07:12:00Z',
}) {
  return {
    'id': 't1',
    'vehicle_id': 'v1',
    'entry_date': '2026-09-05',
    'distance_km': distance,
    'started_at': startedAt,
    'start_odometer_km': 142300,
    'purpose': 'private',
    'created_by': 'u1',
    'created_at': '2026-09-05T07:12:00Z',
    'driver': 'Ana',
    'from_place': 'Zagreb',
    'title': null,
  };
}

void main() {
  group('a draft row', () {
    test('maps onto the draft, keeping what was known at the start', () {
      final draft = tripDraftFromRow(draftRow());

      expect(draft.id, 't1');
      expect(draft.vehicleId, 'v1');
      expect(draft.startedAt, DateTime.utc(2026, 9, 5, 7, 12));
      expect(draft.startOdometerKm, 142300);
      expect(draft.createdBy, 'u1');
      expect(draft.driver, 'Ana');
      expect(draft.fromPlace, 'Zagreb');
    });

    test('the start time comes back as UTC whatever the column said', () {
      final draft = tripDraftFromRow(
        draftRow(startedAt: '2026-09-05T09:12:00+02:00'),
      );

      expect(draft.startedAt.isUtc, isTrue);
      expect(draft.startedAt, DateTime.utc(2026, 9, 5, 7, 12));
    });

    test('the row it writes carries the start and no distance', () {
      final row = tripDraftToRow(
        TripDraft(
          id: 't1',
          vehicleId: 'v1',
          startedAt: DateTime.utc(2026, 9, 5, 7, 12),
          createdBy: 'u1',
          startOdometerKm: 142300,
          driver: 'Ana',
        ),
      );

      expect(row['started_at'], '2026-09-05T07:12:00.000Z');
      expect(row['start_odometer_km'], 142300);
      expect(row['driver'], 'Ana');
      expect(
        row.containsKey('distance_km'),
        isFalse,
        reason:
            'a null distance is what makes the row a draft; writing one '
            'explicitly would finish the drive the moment it started',
      );
    });
  });

  group('a draft is never mistaken for a finished trip', () {
    test('the trip mapper refuses a row that is still under way', () {
      // `forVehicle` filters drafts out in the query. If that filter is ever
      // dropped, this is the difference between a clear failure and a null
      // cast blowing up somewhere in a list builder.
      expect(() => tripEntryFromRow(draftRow()), throwsA(isA<StateError>()));
    });

    test('and accepts one that has been parked', () {
      final trip = tripEntryFromRow(draftRow(distance: 43.0));

      expect(trip.distanceKm, 43);
    });
  });
}
