import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/date_column.dart';
import '../../../core/sync/read_cache.dart';
import '../../../domain/entities/odometer_entry.dart';
import 'odometer_repository.dart';

class SupabaseOdometerRepository implements OdometerRepository {
  SupabaseOdometerRepository(this._client, {required this._cache});

  final SupabaseClient _client;
  final ReadCache _cache;

  @override
  Future<List<OdometerEntry>> forVehicle(String vehicleId) async {
    try {
      final rows = await _cache.rows(
        'odometer/$vehicleId',
        () => _client
            .from('odometer_entries')
            .select()
            .eq('vehicle_id', vehicleId)
            .order('entry_date', ascending: false)
            .retry(enabled: false),
      );
      return rows.map(odometerEntryFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> add(OdometerEntry entry) async {
    try {
      await _client.from('odometer_entries').insert({
        // The sheet's own id, so a retry after a timeout is the same row.
        if (entry.id.isNotEmpty) 'id': entry.id,
        ...odometerEntryToRow(entry),
        'vehicle_id': entry.vehicleId,
        'created_by': _client.auth.currentUser!.id,
      });
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> update(OdometerEntry entry) async {
    try {
      await _client
          .from('odometer_entries')
          .update(odometerEntryToRow(entry))
          .eq('id', entry.id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _client.from('odometer_entries').delete().eq('id', id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

/// The columns an edit may change. `vehicle_id` and `created_by` are set once,
/// on insert, and never rewritten.
Map<String, dynamic> odometerEntryToRow(OdometerEntry entry) {
  return {
    'entry_date': dateToColumn(entry.date),
    'odometer_km': entry.odometerKm,
    'notes': entry.notes,
  };
}

OdometerEntry odometerEntryFromRow(Map<String, dynamic> row) {
  return OdometerEntry(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String,
    date: dateFromColumn(row['entry_date'] as String),
    odometerKm: row['odometer_km'] as int,
    notes: row['notes'] as String?,
    createdBy: row['created_by'] as String? ?? '',
    createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
  );
}
