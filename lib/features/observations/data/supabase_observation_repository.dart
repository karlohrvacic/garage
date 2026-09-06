import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/date_column.dart';
import '../../../domain/entities/observation.dart';
import 'observation_repository.dart';

class SupabaseObservationRepository implements ObservationRepository {
  SupabaseObservationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Observation>> forVehicle(String vehicleId) async {
    try {
      final rows = await _client
          .from('observations')
          .select()
          .eq('vehicle_id', vehicleId)
          .order('noticed_on', ascending: false);
      return rows.map(observationFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> add(Observation observation) async {
    try {
      await _client.from('observations').insert({
        // The sheet's own id, so a retry after a timeout is the same row.
        if (observation.id.isNotEmpty) 'id': observation.id,
        ...observationToRow(observation),
        'vehicle_id': observation.vehicleId,
        'created_by': _client.auth.currentUser!.id,
      });
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> update(Observation observation) async {
    try {
      await _client
          .from('observations')
          .update(observationToRow(observation))
          .eq('id', observation.id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _client.from('observations').delete().eq('id', id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

/// The columns an edit may change. `vehicle_id` and `created_by` are set once,
/// on insert, and never rewritten — the trigger from 0060 enforces the second.
Map<String, dynamic> observationToRow(Observation observation) {
  return {
    'trip_id': observation.tripId,
    'noticed_on': dateToColumn(observation.noticedOn),
    'odometer_km': observation.odometerKm,
    'note': observation.note,
    'addressed_by': observation.addressedBy,
    'resolved_on': switch (observation.resolvedOn) {
      null => null,
      final resolved => dateToColumn(resolved),
    },
  };
}

Observation observationFromRow(Map<String, dynamic> row) {
  return Observation(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String,
    tripId: row['trip_id'] as String?,
    noticedOn: dateFromColumn(row['noticed_on'] as String),
    odometerKm: row['odometer_km'] as int?,
    note: row['note'] as String,
    addressedBy: row['addressed_by'] as String?,
    resolvedOn: switch (row['resolved_on'] as String?) {
      null => null,
      final resolved => dateFromColumn(resolved),
    },
    createdBy: row['created_by'] as String? ?? '',
    createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
  );
}
