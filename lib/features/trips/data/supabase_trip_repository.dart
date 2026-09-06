import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/date_column.dart';
import '../../../domain/entities/trip_draft.dart';
import '../../../domain/entities/trip_entry.dart';
import 'trip_repository.dart';

class SupabaseTripRepository implements TripRepository {
  SupabaseTripRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<TripEntry>> forVehicle(String vehicleId) async {
    try {
      final rows = await _client
          .from('trip_entries')
          .select()
          // A drive still under way has no distance yet, and is not a trip
          // until it does. Without this the mapper below meets a null.
          .not('distance_km', 'is', null)
          .eq('vehicle_id', vehicleId)
          .order('entry_date', ascending: false);
      return rows.map(tripEntryFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> add(TripEntry entry) async {
    try {
      await _client.from('trip_entries').insert({
        // The sheet's own id, so a retry after a timeout is the same row.
        if (entry.id.isNotEmpty) 'id': entry.id,
        ...tripEntryToRow(entry),
        'vehicle_id': entry.vehicleId,
        'created_by': _client.auth.currentUser!.id,
      });
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> update(TripEntry entry) async {
    try {
      await _client
          .from('trip_entries')
          .update(tripEntryToRow(entry))
          .eq('id', entry.id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<TripDraft?> openDraft(String vehicleId) async {
    try {
      final rows = await _client
          .from('trip_entries')
          .select()
          .isFilter('distance_km', null)
          .eq('vehicle_id', vehicleId)
          .limit(1);
      if (rows.isEmpty) {
        return null;
      }
      return tripDraftFromRow(rows.first);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> startDraft(TripDraft draft) async {
    try {
      await _client.from('trip_entries').insert({
        if (draft.id.isNotEmpty) 'id': draft.id,
        ...tripDraftToRow(draft),
        'vehicle_id': draft.vehicleId,
        // The day it set off. The row needs a date from the start, and this is
        // the one `finishDraft` will settle on anyway — including its reading
        // of which day a drive begun just after local midnight belongs to.
        'entry_date': dateToColumn(dateOfDrive(draft.startedAt)),
        'created_by': _client.auth.currentUser!.id,
      });
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> discardDraft(String id) => delete(id);

  @override
  Future<void> delete(String id) async {
    try {
      await _client.from('trip_entries').delete().eq('id', id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

/// The columns an edit may change. `vehicle_id` and `created_by` are set once,
/// on insert, and never rewritten.
Map<String, dynamic> tripEntryToRow(TripEntry entry) {
  return {
    'entry_date': dateToColumn(entry.date),
    'title': entry.title,
    'from_place': entry.fromPlace,
    'to_place': entry.toPlace,
    'distance_km': entry.distanceKm,
    'start_odometer_km': entry.startOdometerKm,
    'end_odometer_km': entry.endOdometerKm,
    'minutes': entry.minutes,
    'purpose': entry.purpose.key,
    'notes': entry.notes,
    'driver': entry.driver,
    'route_id': entry.routeId,
    'comparable': entry.comparable,
  };
}

/// The columns that open a drive. Deliberately no `distance_km`: its absence
/// is what marks the row as still under way.
Map<String, dynamic> tripDraftToRow(TripDraft draft) {
  return {
    'started_at': draft.startedAt.toIso8601String(),
    'start_odometer_km': draft.startOdometerKm,
    'driver': draft.driver,
    'from_place': draft.fromPlace,
    'title': draft.title,
    'route_id': draft.routeId,
  };
}

TripDraft tripDraftFromRow(Map<String, dynamic> row) {
  return TripDraft(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String,
    startedAt: DateTime.parse(row['started_at'] as String).toUtc(),
    createdBy: row['created_by'] as String? ?? '',
    startOdometerKm: row['start_odometer_km'] as int?,
    driver: row['driver'] as String?,
    fromPlace: row['from_place'] as String?,
    title: row['title'] as String?,
    routeId: row['route_id'] as String?,
  );
}

TripEntry tripEntryFromRow(Map<String, dynamic> row) {
  final distance = row['distance_km'] as num?;
  if (distance == null) {
    // Reached only if `forVehicle` loses its filter. Saying so here is the
    // difference between a legible failure and a null cast surfacing inside
    // some list builder three layers away.
    throw StateError(
      'trip ${row['id']} is a drive still under way, not a finished journey',
    );
  }
  return TripEntry(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String,
    date: dateFromColumn(row['entry_date'] as String),
    distanceKm: distance.toDouble(),
    purpose: TripPurpose.fromKey(row['purpose'] as String),
    createdBy: row['created_by'] as String? ?? '',
    title: row['title'] as String?,
    fromPlace: row['from_place'] as String?,
    toPlace: row['to_place'] as String?,
    startOdometerKm: row['start_odometer_km'] as int?,
    endOdometerKm: row['end_odometer_km'] as int?,
    minutes: row['minutes'] as int?,
    notes: row['notes'] as String?,
    driver: row['driver'] as String?,
    routeId: row['route_id'] as String?,
    comparable: row['comparable'] as bool? ?? true,
    startedAt: switch (row['started_at'] as String?) {
      null => null,
      final at => DateTime.parse(at).toUtc(),
    },
    createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
  );
}
