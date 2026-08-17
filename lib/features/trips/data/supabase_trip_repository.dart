import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/date_column.dart';
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
  };
}

TripEntry tripEntryFromRow(Map<String, dynamic> row) {
  return TripEntry(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String,
    date: dateFromColumn(row['entry_date'] as String),
    distanceKm: (row['distance_km'] as num).toDouble(),
    purpose: TripPurpose.fromKey(row['purpose'] as String),
    createdBy: row['created_by'] as String? ?? '',
    title: row['title'] as String?,
    fromPlace: row['from_place'] as String?,
    toPlace: row['to_place'] as String?,
    startOdometerKm: row['start_odometer_km'] as int?,
    endOdometerKm: row['end_odometer_km'] as int?,
    minutes: row['minutes'] as int?,
    notes: row['notes'] as String?,
  );
}
