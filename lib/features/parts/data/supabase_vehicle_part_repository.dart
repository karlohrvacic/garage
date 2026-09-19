import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/sync/read_cache.dart';
import '../../../domain/entities/vehicle_part.dart';
import 'vehicle_part_repository.dart';

class SupabaseVehiclePartRepository implements VehiclePartRepository {
  SupabaseVehiclePartRepository(this._client, {required this._cache});

  final SupabaseClient _client;
  final ReadCache _cache;

  @override
  Future<List<VehiclePart>> forVehicle(String vehicleId) async {
    try {
      final rows = await _cache.rows(
        'parts/$vehicleId',
        () => _client
            .from('vehicle_parts')
            .select()
            .eq('vehicle_id', vehicleId)
            .order('service_type_key'),
      );
      return rows.map(vehiclePartFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> save(VehiclePart part) async {
    try {
      if (part.id.isNotEmpty) {
        // An edit, by primary key. Changing the *job* of an existing row is
        // an ordinary update; only a brand-new row can collide with the
        // one-per-job constraint.
        await _client
            .from('vehicle_parts')
            .update(vehiclePartToRow(part))
            .eq('id', part.id);
        return;
      }
      // New, on the constraint rather than the id: the same job typed twice
      // on the same car is a correction, and a plain insert would be refused
      // with an error the person cannot act on.
      await _client.from('vehicle_parts').upsert({
        'vehicle_id': part.vehicleId,
        ...vehiclePartToRow(part),
        'created_by': _client.auth.currentUser!.id,
      }, onConflict: 'vehicle_id,service_type_key');
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _client.from('vehicle_parts').delete().eq('id', id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

/// The columns an edit may change. `vehicle_id` and `created_by` are set once.
Map<String, dynamic> vehiclePartToRow(VehiclePart part) {
  return {
    'service_type_key': part.serviceTypeKey,
    'spec': part.spec.trim(),
    'notes': part.notes,
  };
}

VehiclePart vehiclePartFromRow(Map<String, dynamic> row) {
  return VehiclePart(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String,
    serviceTypeKey: row['service_type_key'] as String,
    spec: row['spec'] as String,
    notes: row['notes'] as String?,
    createdBy: row['created_by'] as String? ?? '',
    createdAt: switch (row['created_at'] as String?) {
      null => null,
      final at => DateTime.parse(at).toUtc(),
    },
  );
}
