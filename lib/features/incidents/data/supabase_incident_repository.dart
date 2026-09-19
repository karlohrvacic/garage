import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/date_column.dart';
import '../../../core/supabase/refused_if_none.dart';
import '../../../core/sync/read_cache.dart';
import '../../../domain/entities/incident.dart';
import 'incident_repository.dart';

class SupabaseIncidentRepository implements IncidentRepository {
  SupabaseIncidentRepository(this._client, {required this._cache});

  final SupabaseClient _client;
  final ReadCache _cache;

  @override
  Future<List<Incident>> forVehicle(String vehicleId) async {
    try {
      final rows = await _cache.rows(
        'incidents/$vehicleId',
        () => _client
            .from('incidents')
            .select()
            .eq('vehicle_id', vehicleId)
            .order('happened_on', ascending: false)
            .retry(enabled: false),
      );
      return rows.map(incidentFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> add(Incident incident) async {
    try {
      await _client.from('incidents').insert({
        // The sheet's own id, so a retry after a timeout is the same row.
        if (incident.id.isNotEmpty) 'id': incident.id,
        ...incidentToRow(incident),
        'vehicle_id': incident.vehicleId,
        'created_by': _client.auth.currentUser!.id,
      });
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> update(Incident incident) async {
    try {
      final written = await _client
          .from('incidents')
          .update(incidentToRow(incident))
          .eq('id', incident.id)
          .select('id');
      refusedIfNone(
        written,
        table: 'incidents',
        write: 'update',
        id: incident.id,
      );
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      final taken = await _client
          .from('incidents')
          .delete()
          .eq('id', id)
          .select('id');
      refusedIfNone(taken, table: 'incidents', write: 'delete', id: id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

/// The columns an edit may change. `vehicle_id` and `created_by` are set
/// once, on insert, and never rewritten — the trigger from 0080 pins the
/// second.
Map<String, dynamic> incidentToRow(Incident incident) {
  return {
    'kind': incident.kind.key,
    'happened_on': dateToColumn(incident.happenedOn),
    'odometer_km': incident.odometerKm,
    'description': incident.description,
    'amount': incident.amount,
    'status': incident.status.key,
    'resolved_on': switch (incident.resolvedOn) {
      null => null,
      final resolved => dateToColumn(resolved),
    },
  };
}

Incident incidentFromRow(Map<String, dynamic> row) {
  return Incident(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String,
    kind: IncidentKind.fromKey(row['kind'] as String),
    happenedOn: dateFromColumn(row['happened_on'] as String),
    odometerKm: row['odometer_km'] as int?,
    description: row['description'] as String,
    amount: (row['amount'] as num?)?.toDouble(),
    status: IncidentStatus.fromKey(row['status'] as String),
    resolvedOn: switch (row['resolved_on'] as String?) {
      null => null,
      final resolved => dateFromColumn(resolved),
    },
    createdBy: row['created_by'] as String? ?? '',
    createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
  );
}
